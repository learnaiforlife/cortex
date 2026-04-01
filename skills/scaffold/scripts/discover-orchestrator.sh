#!/bin/bash
# Cortex Discover — Master Orchestrator
# Runs all discovery scripts in parallel and merges results into a single DeveloperDNA JSON.
#
# Usage: discover-orchestrator.sh [dir1 dir2 ...]
#   Defaults: ~/Documents ~/workspace ~/projects ~/code ~/Desktop
#
# Output: DeveloperDNA JSON to stdout
# Performance: < 60 seconds for typical machine (100 repos)
#
# Privacy: All scanning is local. Nothing leaves the machine.
# No environment variable VALUES are read — only existence is checked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_TIME=$(date +%s)

# Default directories
if [ $# -eq 0 ]; then
  SCAN_DIRS="$HOME/Documents $HOME/workspace $HOME/projects $HOME/code $HOME/Desktop"
else
  SCAN_DIRS="$*"
fi

# Filter to directories that actually exist
VALID_DIRS=""
for d in $SCAN_DIRS; do
  d="${d/#\~/$HOME}"  # Safe tilde expansion (no eval)
  if [ -d "$d" ]; then
    VALID_DIRS="$VALID_DIRS $d"
  fi
done

if [ -z "$VALID_DIRS" ]; then
  echo "ERROR: No valid directories found to scan" >&2
  echo '{"error": "No valid directories"}'
  exit 1
fi

echo "Cortex Discover — Scanning your development environment..." >&2
echo "Directories: $VALID_DIRS" >&2
echo "" >&2

# Create temp directory for intermediate results
TMPDIR_DISCOVER=$(mktemp -d)
trap 'rm -rf "$TMPDIR_DISCOVER"' EXIT

# --- Phase 1: Run independent discovery scripts in parallel ---
echo "Phase 1: Running discovery scripts in parallel..." >&2

bash "$SCRIPT_DIR/discover-projects.sh" $VALID_DIRS > "$TMPDIR_DISCOVER/projects.json" 2>"$TMPDIR_DISCOVER/projects.err" &
PID_PROJECTS=$!

bash "$SCRIPT_DIR/discover-tools.sh" > "$TMPDIR_DISCOVER/tools.json" 2>"$TMPDIR_DISCOVER/tools.err" &
PID_TOOLS=$!

bash "$SCRIPT_DIR/discover-services.sh" > "$TMPDIR_DISCOVER/services.json" 2>"$TMPDIR_DISCOVER/services.err" &
PID_SERVICES=$!

bash "$SCRIPT_DIR/discover-integrations.sh" > "$TMPDIR_DISCOVER/integrations.json" 2>"$TMPDIR_DISCOVER/integrations.err" &
PID_INTEGRATIONS=$!

# Wait for all parallel jobs
wait $PID_PROJECTS 2>/dev/null
echo "  Projects:     done" >&2
wait $PID_TOOLS 2>/dev/null
echo "  Tools:        done" >&2
wait $PID_SERVICES 2>/dev/null
echo "  Services:     done" >&2
wait $PID_INTEGRATIONS 2>/dev/null
echo "  Integrations: done" >&2

# --- Phase 2: Run company detection (depends on projects output) ---
echo "Phase 2: Analyzing company signals..." >&2

bash "$SCRIPT_DIR/discover-company.sh" "$TMPDIR_DISCOVER/projects.json" > "$TMPDIR_DISCOVER/company.json" 2>"$TMPDIR_DISCOVER/company.err"
echo "  Company:      done" >&2

# --- Phase 3: Merge everything into DeveloperDNA ---
echo "Phase 3: Synthesizing DeveloperDNA..." >&2

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

python3 - "$TMPDIR_DISCOVER" "$DURATION" "$VALID_DIRS" <<'PYTHON_DNA'
import json, os, sys
from collections import Counter
from datetime import datetime, timezone

tmpdir = sys.argv[1]
duration = int(sys.argv[2])
scan_dirs = sys.argv[3].split()

# Load all discovery results
def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default

projects = load_json(os.path.join(tmpdir, 'projects.json'), [])
tools = load_json(os.path.join(tmpdir, 'tools.json'), {})
services = load_json(os.path.join(tmpdir, 'services.json'), {})
integrations = load_json(os.path.join(tmpdir, 'integrations.json'), {})
company = load_json(os.path.join(tmpdir, 'company.json'), {})

# --- Compute cross-project patterns ---
active_projects = [p for p in projects if p.get('activityLevel') in ('active', 'recent')]
total_active = len(active_projects) or 1

# Shared dependencies
dep_counter = Counter()
for p in active_projects:
    for dep in p.get('keyDependencies', []):
        dep_counter[dep] += 1

shared_deps = []
for dep, count in dep_counter.most_common():
    freq = count / total_active
    level = 'user' if freq >= 0.5 else 'candidate' if freq >= 0.2 else 'project'
    shared_deps.append({
        'name': dep,
        'count': count,
        'totalProjects': total_active,
        'frequency': round(freq, 2),
        'level': level,
    })

# Service relationships (basic: projects sharing the same service)
service_groups = {}
for p in active_projects:
    for svc in p.get('services', []):
        if svc not in service_groups:
            service_groups[svc] = []
        service_groups[svc].append(p['name'])

service_relationships = []
for svc, users in service_groups.items():
    if len(users) > 1:
        service_relationships.append({
            'service': svc,
            'sharedBy': users,
            'type': 'shared-service',
        })

# Common test framework
test_counter = Counter()
for p in active_projects:
    tf = p.get('testFramework')
    if tf:
        test_counter[tf] += 1
common_test = test_counter.most_common(1)[0] if test_counter else (None, 0)

# Common linter (from key dependencies)
linter_counter = Counter()
for p in active_projects:
    for dep in p.get('keyDependencies', []):
        if dep in ('eslint', 'prettier', 'biome', 'ruff'):
            linter_counter[dep] += 1
common_linter = linter_counter.most_common(1)[0] if linter_counter else (None, 0)

cross_project = {
    'sharedDependencies': shared_deps,
    'serviceRelationships': service_relationships,
    'commonTestFramework': {
        'name': common_test[0],
        'frequency': round(common_test[1] / total_active, 2) if common_test[0] else 0,
    },
    'commonLinter': {
        'name': common_linter[0],
        'frequency': round(common_linter[1] / total_active, 2) if common_linter[0] else 0,
    },
}

# --- Compute summary ---
lang_counter = Counter()
for p in active_projects:
    pl = p.get('primaryLanguage', 'unknown')
    if pl != 'unknown':
        lang_counter[pl] += 1
dominant_lang = lang_counter.most_common(1)[0][0] if lang_counter else 'unknown'

framework_counter = Counter()
for p in active_projects:
    fw = p.get('framework')
    if fw:
        framework_counter[fw] += 1

# Infer role
has_frontend = any(p.get('framework') in ('nextjs', 'vite', 'react', 'vue', 'svelte', 'angular') for p in active_projects)
has_backend = any(p.get('framework') in ('express', 'fastapi', 'django', 'flask', 'node', 'go', 'rust', 'java-maven') for p in active_projects)
has_infra = any('terraform' in str(p.get('keyDependencies', [])) or p.get('framework') == 'terraform' for p in active_projects)
has_mobile = any(p.get('primaryLanguage') in ('swift', 'dart', 'kt') for p in active_projects)

if has_frontend and has_backend:
    role = 'fullstack-engineer'
elif has_frontend:
    role = 'frontend-engineer'
elif has_backend:
    role = 'backend-engineer'
elif has_infra:
    role = 'platform-engineer'
elif has_mobile:
    role = 'mobile-engineer'
else:
    role = 'software-engineer'

stale_count = sum(1 for p in projects if p.get('activityLevel') == 'stale')

summary = {
    'totalProjects': len(projects),
    'activeProjects': len([p for p in projects if p.get('activityLevel') == 'active']),
    'recentProjects': len([p for p in projects if p.get('activityLevel') == 'recent']),
    'staleProjects': stale_count,
    'dominantLanguage': dominant_lang,
    'topFrameworks': dict(framework_counter.most_common(5)),
    'role': role,
}

# --- Build final DeveloperDNA ---
dna = {
    '$schema': 'DeveloperDNA v1.0',
    'discoveredAt': datetime.now(timezone.utc).isoformat(timespec='seconds'),
    'scanDuration': duration,
    'scanDirectories': scan_dirs,
    'projects': projects,
    'tools': tools,
    'services': services,
    'integrations': integrations,
    'companySignals': company,
    'crossProjectPatterns': cross_project,
    'summary': summary,
}

print(json.dumps(dna, indent=2))
PYTHON_DNA

# --- Save to ~/.cortex/ ---
mkdir -p "$HOME/.cortex"
# The caller can pipe stdout to save: discover-orchestrator.sh > ~/.cortex/developer-dna.json

echo "" >&2
echo "Discovery complete in ${DURATION}s" >&2
echo "Use: discover-orchestrator.sh > ~/.cortex/developer-dna.json  to save" >&2
