#!/bin/bash
# Cortex Discover — Company Signal Detector
# Detects internal registries, conventions, branch patterns, and shared organization.
# Aggregates patterns across all discovered projects to infer company context.
#
# Usage: discover-company.sh [projects-json-file]
#   projects-json-file: Path to JSON array from discover-projects.sh output
#                       If omitted, reads from stdin
#
# Output: JSON object with company signals to stdout
# Privacy: Reads local config files only to detect registry hosts and always redacts credentials

set -uo pipefail

PROJECTS_FILE="${1:-}"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

# If no file arg and stdin is piped, save stdin to a temp file
if [ -z "$PROJECTS_FILE" ] || [ ! -f "$PROJECTS_FILE" ]; then
  if [ ! -t 0 ]; then
    PROJECTS_FILE=$(mktemp)
    cat > "$PROJECTS_FILE"
    CLEANUP_TMPFILE="$PROJECTS_FILE"
  else
    echo '{"internalRegistries":[],"internalClis":[],"branchConventions":{"dominant":null,"frequency":0},"commitConventions":{"dominant":null,"frequency":0},"prTemplateExists":false,"commonOrg":null}'
    exit 0
  fi
fi

python3 - "$PROJECTS_FILE" <<'PYTHON_EOF'
import json, logging, os, sys, re
from collections import Counter
from urllib.parse import urlsplit, urlunsplit

logging.basicConfig(level=logging.WARNING, format='%(levelname)s: %(message)s', stream=sys.stderr)

# Read projects from file argument (always file-based, never shell interpolation)
projects_file = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] and os.path.exists(sys.argv[1]) else None
if projects_file:
    try:
        with open(projects_file) as f:
            projects = json.load(f)
    except Exception as e:
        logging.warning('Failed to load projects file %s: %s', projects_file, e)
        projects = []
else:
    projects = []

def sanitize_registry_url(url):
    if not url:
        return url
    try:
        if url.startswith('//'):
            parts = urlsplit(f'https:{url}')
            netloc = parts.hostname or ''
            if parts.port:
                netloc = f'{netloc}:{parts.port}'
            return f'//{netloc}{parts.path}'
        if '://' in url:
            parts = urlsplit(url)
            netloc = parts.hostname or ''
            if parts.port:
                netloc = f'{netloc}:{parts.port}'
            return urlunsplit((parts.scheme, netloc, parts.path, '', ''))
    except Exception:
        pass
    return url

# --- Internal Registries ---
internal_registries = []

# Check npm registry
npmrc_path = os.path.expanduser('~/.npmrc')
if os.path.exists(npmrc_path):
    try:
        with open(npmrc_path) as f:
            for line in f:
                line = line.strip()
                if 'registry=' in line and 'registry.npmjs.org' not in line and not line.startswith('#'):
                    url = sanitize_registry_url(line.split('registry=')[-1].strip())
                    if url and '.' in url:
                        internal_registries.append({'type': 'npm', 'url': url})
                elif line.startswith('@') and ':registry=' in line:
                    scope = line.split(':')[0]
                    url = sanitize_registry_url(line.split('registry=')[-1].strip())
                    if url and 'registry.npmjs.org' not in url:
                        internal_registries.append({'type': 'npm-scoped', 'scope': scope, 'url': url})
    except Exception as e:
        logging.warning('Failed to parse ~/.npmrc: %s', e)

# Check pip config
for pip_conf in [os.path.expanduser('~/.pip/pip.conf'), os.path.expanduser('~/.config/pip/pip.conf')]:
    if os.path.exists(pip_conf):
        try:
            with open(pip_conf) as f:
                content = f.read()
                if 'index-url' in content:
                    for line in content.split('\n'):
                        if 'index-url' in line and 'pypi.org' not in line and not line.strip().startswith('#'):
                            url = sanitize_registry_url(line.split('=')[-1].strip())
                            if url and '.' in url:
                                internal_registries.append({'type': 'pip', 'url': url})
        except Exception as e:
            logging.warning('Failed to parse %s: %s', pip_conf, e)

# --- Internal CLIs ---
# Known public CLIs to exclude from internal detection
KNOWN_PUBLIC = {
    'git', 'docker', 'kubectl', 'terraform', 'aws', 'gcloud', 'az', 'gh', 'glab',
    'node', 'npm', 'npx', 'yarn', 'pnpm', 'pip', 'pip3', 'python', 'python3',
    'go', 'cargo', 'rustc', 'ruby', 'bundle', 'composer', 'mvn', 'gradle',
    'make', 'cmake', 'gcc', 'g++', 'clang', 'java', 'javac',
    'curl', 'wget', 'ssh', 'scp', 'rsync',
    'vercel', 'netlify', 'fly', 'heroku', 'supabase', 'firebase',
    'code', 'cursor', 'vim', 'nvim', 'nano', 'emacs',
    'jq', 'yq', 'fzf', 'rg', 'fd', 'bat', 'exa', 'eza',
    'brew', 'apt', 'yum', 'snap', 'flatpak',
    'tmux', 'screen', 'zsh', 'bash', 'fish',
    'helm', 'ansible', 'pulumi', 'vagrant', 'packer',
    'linear', 'jira', 'datadog-ci', 'sentry-cli',
    'claude', 'copilot', 'aider',
}

internal_clis = []

# Scan PATH for binaries not in known-public list
# This is intentionally conservative — only flags tools with company-like prefixes
path_dirs = os.environ.get('PATH', '').split(':')
for pdir in path_dirs:
    if '/usr/' in pdir or '/bin' == pdir or '/sbin' in pdir or 'homebrew' in pdir or 'nix' in pdir:
        continue  # Skip system dirs
    if os.path.isdir(pdir):
        try:
            for f in os.listdir(pdir):
                full = os.path.join(pdir, f)
                if os.path.isfile(full) and os.access(full, os.X_OK):
                    if f not in KNOWN_PUBLIC and not f.startswith('.') and not f.startswith('_'):
                        # Only report if it has a company-prefix pattern (e.g., acme-deploy)
                        if '-' in f and len(f.split('-')[0]) >= 3:
                            prefix = f.split('-')[0]
                            # Check if prefix appears in multiple tools
                            internal_clis.append(f)
        except Exception as e:
            logging.warning('Failed to scan PATH dir %s: %s', pdir, e)

# Deduplicate and limit
internal_clis = sorted(set(internal_clis))[:20]

# --- Branch Conventions ---
branch_counts = Counter()
total_with_branches = 0
for p in projects:
    bc = p.get('branchConvention')
    if bc:
        branch_counts[bc] += 1
        total_with_branches += 1

dominant_branch = branch_counts.most_common(1)[0] if branch_counts else (None, 0)
branch_conventions = {
    'dominant': dominant_branch[0],
    'frequency': round(dominant_branch[1] / max(len(projects), 1), 2)
}

# --- Commit Conventions ---
commit_counts = Counter()
for p in projects:
    cc = p.get('commitConvention')
    if cc:
        commit_counts[cc] += 1

dominant_commit = commit_counts.most_common(1)[0] if commit_counts else (None, 0)
commit_conventions = {
    'dominant': dominant_commit[0],
    'frequency': round(dominant_commit[1] / max(len(projects), 1), 2)
}

# --- PR Template ---
pr_template_exists = False
for p in projects:
    pr_path = os.path.join(p['path'], '.github', 'pull_request_template.md')
    pr_path2 = os.path.join(p['path'], '.github', 'PULL_REQUEST_TEMPLATE.md')
    if os.path.exists(pr_path) or os.path.exists(pr_path2):
        pr_template_exists = True
        break

# --- Common Organization ---
org_counter = Counter()
for p in projects:
    remote = p.get('gitRemote') or ''
    # Extract org from GitHub/GitLab remote URL
    match = re.search(r'[:/]([^/]+)/[^/]+(?:\.git)?$', remote)
    if match:
        org = match.group(1)
        if org not in ('git', 'github', 'gitlab'):
            org_counter[org] += 1

common_org = None
if org_counter:
    top_org, top_count = org_counter.most_common(1)[0]
    if top_count >= len(projects) * 0.3:  # At least 30% of projects share this org
        common_org = top_org

result = {
    'internalRegistries': internal_registries,
    'internalClis': internal_clis,
    'branchConventions': branch_conventions,
    'commitConventions': commit_conventions,
    'prTemplateExists': pr_template_exists,
    'commonOrg': common_org,
}

print(json.dumps(result, indent=2))
PYTHON_EOF

# Clean up temp file if we created one from stdin
if [ -n "${CLEANUP_TMPFILE:-}" ] && [ -f "$CLEANUP_TMPFILE" ]; then
  rm -f "$CLEANUP_TMPFILE"
fi
