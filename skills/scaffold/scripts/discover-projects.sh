#!/bin/bash
# Cortex Discover — Project Scanner
# Finds all git repositories in specified directories and builds a heuristic profile for each.
# Uses parallel scanning (xargs -P 8) for performance.
#
# Usage: discover-projects.sh [dir1] [dir2] ...
#   Defaults to: ~/Documents ~/workspace ~/projects ~/code ~/Desktop
#
# Output: JSON array of project objects to stdout
# Performance: ~2s per repo, 100 repos in ~25s with parallelism

set -uo pipefail

# Default scan directories
if [ $# -eq 0 ]; then
  SCAN_DIRS="$HOME/Documents $HOME/workspace $HOME/projects $HOME/code $HOME/Desktop"
else
  SCAN_DIRS="$*"
fi

# Scan a single repo and output a JSON object
scan_single_repo() {
  local repo_dir="$1"
  local git_dir="$repo_dir/.git"

  # Skip if not a valid git repo
  [ -d "$git_dir" ] || return

  python3 -c "
import json, subprocess, os, sys
from datetime import datetime, timezone, timedelta

repo_dir = sys.argv[1]

def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=repo_dir)
        return r.stdout.strip() if r.returncode == 0 else ''
    except:
        return ''

# Basic info
name = os.path.basename(os.path.abspath(repo_dir))
remote = run(['git', 'remote', 'get-url', 'origin'])
last_commit = run(['git', 'log', '-1', '--format=%cI'])

# Activity classification
activity = 'stale'
if last_commit:
    try:
        # Handle timezone offset format
        commit_date = last_commit[:19]  # Trim timezone
        dt = datetime.fromisoformat(commit_date)
        now = datetime.now()
        days = (now - dt).days
        if days <= 30:
            activity = 'active'
        elif days <= 90:
            activity = 'recent'
    except:
        pass

# Language detection by file extension count
lang_counts = {}
skip_dirs = {'node_modules', '.git', 'vendor', 'dist', '__pycache__', '.venv', 'target', 'build', '.next'}
for root, dirs, files in os.walk(repo_dir):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    # Limit depth to avoid very deep traversals
    depth = root[len(repo_dir):].count(os.sep)
    if depth > 5:
        dirs.clear()
        continue
    for f in files:
        ext = f.rsplit('.', 1)[-1] if '.' in f else ''
        if ext in ('ts', 'tsx', 'js', 'jsx', 'py', 'go', 'rs', 'java', 'kt', 'rb', 'php', 'dart', 'cs', 'swift', 'vue', 'svelte'):
            lang_counts[ext] = lang_counts.get(ext, 0) + 1

# Primary language
primary_lang = max(lang_counts, key=lang_counts.get) if lang_counts else 'unknown'

# Framework detection
framework = None
key_files = []
checks = {
    'package.json': 'package.json', 'pyproject.toml': 'pyproject.toml',
    'go.mod': 'go.mod', 'Cargo.toml': 'Cargo.toml', 'pom.xml': 'pom.xml',
    'docker-compose.yml': 'docker-compose.yml', 'docker-compose.yaml': 'docker-compose.yaml',
    'Dockerfile': 'Dockerfile', 'tsconfig.json': 'tsconfig.json',
    'next.config.js': 'next.config.js', 'next.config.ts': 'next.config.ts',
    'next.config.mjs': 'next.config.mjs',
    'vite.config.ts': 'vite.config.ts', 'vite.config.js': 'vite.config.js',
    'turbo.json': 'turbo.json', 'nx.json': 'nx.json', 'lerna.json': 'lerna.json',
    'pnpm-workspace.yaml': 'pnpm-workspace.yaml',
    'CLAUDE.md': 'CLAUDE.md', 'AGENTS.md': 'AGENTS.md',
}
for name_check, fname in checks.items():
    fpath = os.path.join(repo_dir, fname)
    if os.path.exists(fpath):
        key_files.append(fname)

# Detect framework from key files
if any(f.startswith('next.config') for f in key_files):
    framework = 'nextjs'
elif 'vite.config.ts' in key_files or 'vite.config.js' in key_files:
    framework = 'vite'
elif 'pyproject.toml' in key_files:
    try:
        with open(os.path.join(repo_dir, 'pyproject.toml')) as pf:
            content = pf.read()
            if 'fastapi' in content.lower():
                framework = 'fastapi'
            elif 'django' in content.lower():
                framework = 'django'
            elif 'flask' in content.lower():
                framework = 'flask'
            else:
                framework = 'python'
    except:
        framework = 'python'
elif 'go.mod' in key_files:
    framework = 'go'
elif 'Cargo.toml' in key_files:
    framework = 'rust'
elif 'pom.xml' in key_files:
    framework = 'java-maven'
elif 'package.json' in key_files:
    framework = 'node'

# Package manager detection
pkg_mgr = None
if os.path.exists(os.path.join(repo_dir, 'pnpm-lock.yaml')):
    pkg_mgr = 'pnpm'
elif os.path.exists(os.path.join(repo_dir, 'yarn.lock')):
    pkg_mgr = 'yarn'
elif os.path.exists(os.path.join(repo_dir, 'package-lock.json')):
    pkg_mgr = 'npm'
elif os.path.exists(os.path.join(repo_dir, 'poetry.lock')):
    pkg_mgr = 'poetry'
elif os.path.exists(os.path.join(repo_dir, 'Pipfile.lock')):
    pkg_mgr = 'pipenv'
elif os.path.exists(os.path.join(repo_dir, 'requirements.txt')):
    pkg_mgr = 'pip'

# Test framework detection
test_fw = None
if os.path.exists(os.path.join(repo_dir, 'package.json')):
    try:
        with open(os.path.join(repo_dir, 'package.json')) as pf:
            pkg = json.load(pf)
            all_deps = {**pkg.get('dependencies', {}), **pkg.get('devDependencies', {})}
            if 'vitest' in all_deps:
                test_fw = 'vitest'
            elif 'jest' in all_deps:
                test_fw = 'jest'
            elif 'mocha' in all_deps:
                test_fw = 'mocha'
    except:
        pass
elif os.path.exists(os.path.join(repo_dir, 'pyproject.toml')):
    try:
        with open(os.path.join(repo_dir, 'pyproject.toml')) as pf:
            if 'pytest' in pf.read():
                test_fw = 'pytest'
    except:
        pass

# Services from docker-compose
services = []
for dc_name in ('docker-compose.yml', 'docker-compose.yaml'):
    dc_path = os.path.join(repo_dir, dc_name)
    if os.path.exists(dc_path):
        try:
            with open(dc_path) as dcf:
                content = dcf.read().lower()
                for svc in ('postgres', 'mysql', 'mongo', 'redis', 'rabbitmq', 'kafka', 'elasticsearch'):
                    if svc in content:
                        services.append(svc)
        except:
            pass

# CI detection
ci_platform = None
has_ci = False
if os.path.isdir(os.path.join(repo_dir, '.github', 'workflows')):
    ci_platform = 'github-actions'
    has_ci = True
elif os.path.exists(os.path.join(repo_dir, '.gitlab-ci.yml')):
    ci_platform = 'gitlab-ci'
    has_ci = True
elif os.path.exists(os.path.join(repo_dir, 'Jenkinsfile')):
    ci_platform = 'jenkins'
    has_ci = True

# Existing AI setup
existing = {
    'claudeMd': os.path.exists(os.path.join(repo_dir, 'CLAUDE.md')),
    'agentsMd': os.path.exists(os.path.join(repo_dir, 'AGENTS.md')),
    'claudeDir': os.path.isdir(os.path.join(repo_dir, '.claude')),
    'cursorDir': os.path.isdir(os.path.join(repo_dir, '.cursor')),
    'mcpJson': os.path.exists(os.path.join(repo_dir, '.mcp.json')),
}

# Monorepo detection
is_monorepo = any(f in key_files for f in ('turbo.json', 'nx.json', 'lerna.json', 'pnpm-workspace.yaml'))

# Branch convention (from recent remote branches)
branch_convention = None
branches = run(['git', 'branch', '-r', '--format=%(refname:short)'], timeout=3)
if branches:
    branch_list = branches.split('\n')[:20]
    jira_count = sum(1 for b in branch_list if 'jira' in b.lower() or any(c.isdigit() for c in b.split('/')[-1].split('-')[0:2] if c))
    # Simple heuristic: check for common patterns
    import re
    patterns = {'feature/': 0, 'feat/': 0, 'fix/': 0, 'bugfix/': 0}
    for b in branch_list:
        for p in patterns:
            if p in b.lower():
                patterns[p] += 1
    dominant = max(patterns, key=patterns.get) if any(v > 0 for v in patterns.values()) else None
    if dominant and patterns[dominant] >= 2:
        branch_convention = f'{dominant}*'

# Commit convention
commit_convention = None
commits = run(['git', 'log', '--oneline', '-10', '--format=%s'], timeout=3)
if commits:
    commit_list = commits.split('\n')
    import re
    conventional = sum(1 for c in commit_list if re.match(r'^(feat|fix|chore|docs|style|refactor|perf|test|ci|build)\b', c))
    if conventional >= 5:
        commit_convention = 'conventional'

# Key dependencies (from package.json)
key_deps = []
if os.path.exists(os.path.join(repo_dir, 'package.json')):
    try:
        with open(os.path.join(repo_dir, 'package.json')) as pf:
            pkg = json.load(pf)
            all_deps = list(pkg.get('dependencies', {}).keys()) + list(pkg.get('devDependencies', {}).keys())
            # Filter to interesting deps
            interesting = {'express', 'fastify', 'koa', 'next', 'react', 'vue', 'svelte', 'angular',
                          '@prisma/client', 'prisma', 'drizzle-orm', 'typeorm', 'sequelize',
                          'zod', 'yup', 'joi', 'vitest', 'jest', 'mocha', 'playwright', 'cypress',
                          'tailwindcss', 'styled-components', '@emotion/react',
                          'eslint', 'prettier', 'biome', 'typescript',
                          '@sentry/node', '@sentry/react', 'datadog-metrics',
                          'axios', 'trpc', '@trpc/server', 'graphql', '@apollo/client'}
            key_deps = [d for d in all_deps if d in interesting]
    except:
        pass

# Estimate size
total_files = sum(lang_counts.values())
size = 'small' if total_files < 50 else 'medium' if total_files < 500 else 'large'

project = {
    'path': os.path.abspath(repo_dir),
    'name': name,
    'gitRemote': remote or None,
    'lastCommitDate': last_commit or None,
    'activityLevel': activity,
    'languages': lang_counts,
    'primaryLanguage': primary_lang,
    'framework': framework,
    'packageManager': pkg_mgr,
    'testFramework': test_fw,
    'services': services,
    'hasDockerCompose': 'docker-compose.yml' in key_files or 'docker-compose.yaml' in key_files,
    'hasCI': has_ci,
    'ciPlatform': ci_platform,
    'existingSetup': existing,
    'branchConvention': branch_convention,
    'commitConvention': commit_convention,
    'keyDependencies': key_deps,
    'monorepo': is_monorepo,
    'estimatedSize': size,
}

print(json.dumps(project))
" "$repo_dir"
}

# Write the scan function to a temp script so xargs can invoke it
# (avoids export -f which is unreliable on macOS bash 3.2)
TMPDIR_DISCOVER=$(mktemp -d)
trap 'rm -rf "$TMPDIR_DISCOVER"' EXIT

# Extract the function body into a standalone script
declare -f scan_single_repo > "$TMPDIR_DISCOVER/scan_func.sh"
echo 'scan_single_repo "$1"' >> "$TMPDIR_DISCOVER/scan_func.sh"

# Collect repo paths, excluding common non-project directories
for dir in $SCAN_DIRS; do
  dir="${dir/#\~/$HOME}"  # Safe tilde expansion (no eval)
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 4 -name ".git" -type d \
    -not -path "*/node_modules/*" \
    -not -path "*/vendor/*" \
    -not -path "*/.venv/*" \
    -not -path "*/target/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.cache/*" \
    -not -path "*/Library/*" \
    2>/dev/null | sed 's|/\.git$||'
done | sort -u > "$TMPDIR_DISCOVER/repos.txt"

REPO_COUNT=$(wc -l < "$TMPDIR_DISCOVER/repos.txt" | tr -d ' ')

# Scan repos in parallel, collect JSON objects
echo "Scanning $REPO_COUNT repositories..." >&2

cat "$TMPDIR_DISCOVER/repos.txt" | \
  xargs -P 8 -I {} bash "$TMPDIR_DISCOVER/scan_func.sh" {} 2>/dev/null | \
  grep -v '^$' > "$TMPDIR_DISCOVER/results.jsonl"

# Merge JSONL into a JSON array with proper sorting
python3 - "$TMPDIR_DISCOVER/results.jsonl" <<'PYTHON_MERGE'
import json, sys
from datetime import datetime

results = []
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                results.append(json.loads(line))
            except json.JSONDecodeError:
                pass

# Sort: active first, then by last commit date (newest first) within each group
activity_order = {'active': 0, 'recent': 1, 'stale': 2}

def sort_key(r):
    activity = activity_order.get(r.get('activityLevel', 'stale'), 3)
    # Parse date for descending sort within activity group
    date_str = r.get('lastCommitDate', '') or ''
    try:
        ts = datetime.fromisoformat(date_str[:19]).timestamp()
    except Exception:
        ts = 0
    return (activity, -ts)  # Negative timestamp for newest-first

results.sort(key=sort_key)

print(json.dumps(results, indent=2))
PYTHON_MERGE

echo "Discovered $REPO_COUNT repositories" >&2
