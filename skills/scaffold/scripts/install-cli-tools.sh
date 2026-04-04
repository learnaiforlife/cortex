#!/bin/bash
# Cortex CLI tool installer — safe, cross-platform tool installation
# NEVER runs without explicit user confirmation
# Only installs from official package managers
#
# Usage: ./install-cli-tools.sh <manifest-json-file> [--dry-run] [--yes]
#
# Input: JSON file with array of {id, installCommand, verifyCommand} objects
# Output: JSON report to stdout
#
# Security:
#   - Only uses official package managers (allowlist enforced)
#   - Never runs curl | sh or wget | bash
#   - Never installs from URLs or random registries
#   - All install commands validated against allowlist
#   - Dry-run mode shows exactly what will happen
#   - Logs everything to ~/.cortex/logs/
#
# Requirements: bash, python3, jq (recommended but not required)

# NOTE: set -e is intentionally omitted. Individual tool install failures should
# not abort the entire run — the script reports per-tool status (INSTALLED,
# FAILED, SKIPPED, REJECTED) and continues to the next tool gracefully.
set -uo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

MANIFEST_FILE="${1:-}"
DRY_RUN=true
AUTO_YES=false

shift || true
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --yes)     DRY_RUN=false; AUTO_YES=true ;;
    *)         echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ -z "$MANIFEST_FILE" ] || [ ! -f "$MANIFEST_FILE" ]; then
  echo "Usage: install-cli-tools.sh <manifest.json> [--dry-run] [--yes]" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Security: Command allowlist
# ---------------------------------------------------------------------------

ALLOWED_PREFIXES=(
  "brew install"
  "brew install --cask"
  "sudo apt install"
  "sudo dnf install"
  "npm install -g"
  "pip install"
  "pipx install"
  "cargo install"
  "rustup component add"
  "go install"
)

validate_command() {
  local cmd="$1"
  # Reject shell metacharacters that could chain or inject commands
  if [[ "$cmd" =~ [\;\&\|\$\`\>\<\(\)] ]] || [[ "$cmd" == *$'\n'* ]]; then
    return 1
  fi
  for prefix in "${ALLOWED_PREFIXES[@]}"; do
    if [[ "$cmd" == "$prefix"* ]]; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

LOG_DIR="$HOME/.cortex/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/toolbox-install-$(date +%Y%m%d-%H%M%S).log"

log() {
  echo "[$(date +%H:%M:%S)] $*" >> "$LOG_FILE"
}

log "Cortex CLI tool installer started"
log "Manifest: $MANIFEST_FILE"
log "Mode: $([ "$DRY_RUN" = true ] && echo 'dry-run' || echo 'install')"

# ---------------------------------------------------------------------------
# Parse manifest
# ---------------------------------------------------------------------------

# Use python3 to parse JSON (jq may not be installed yet — that's what we're installing!)
# Pass manifest path via sys.argv to avoid shell injection
# Uses __EMPTY__ sentinel to distinguish "valid JSON with 0 tools" from "parse failure"
TOOLS_JSON=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
tools = data if isinstance(data, list) else data.get('tools', data.get('recommended', []))
if not tools:
    print('__EMPTY__')
else:
    for t in tools:
        print(json.dumps(t))
" "$MANIFEST_FILE" 2>/dev/null)

if [ -z "$TOOLS_JSON" ]; then
  echo '{"error": "Failed to parse manifest JSON"}'
  exit 1
fi

if [ "$TOOLS_JSON" = "__EMPTY__" ]; then
  echo '{"dryRun": true, "results": [], "summary": {"installed": 0, "failed": 0, "skipped": 0, "rejected": 0, "total": 0}, "logFile": "'"$LOG_FILE"'"}'
  exit 0
fi

TOOL_COUNT=$(echo "$TOOLS_JSON" | wc -l | tr -d ' ')
log "Tools to process: $TOOL_COUNT"

# ---------------------------------------------------------------------------
# Process tools
# ---------------------------------------------------------------------------

INSTALLED_JSON="[]"
FAILED_JSON="[]"
SKIPPED_JSON="[]"

process_tool() {
  local tool_json="$1"
  local id install_cmd verify_cmd

  id=$(echo "$tool_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  install_cmd=$(echo "$tool_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['installCommand'])" 2>/dev/null)
  verify_cmd=$(echo "$tool_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('verifyCommand',''))" 2>/dev/null)

  if [ -z "$id" ] || [ -z "$install_cmd" ]; then
    log "SKIP: invalid tool entry (missing id or installCommand)"
    return 1
  fi

  # Security: validate command against allowlist
  if ! validate_command "$install_cmd"; then
    log "REJECTED: $id — command not in allowlist: $install_cmd"
    echo "REJECTED" "$id" "command not in allowlist"
    return 2
  fi

  # Check if already installed (extract binary from verify command)
  local binary
  binary=$(echo "$verify_cmd" | awk '{print $1}')
  if [ -n "$binary" ] && command -v "$binary" >/dev/null 2>&1; then
    log "SKIP: $id already installed"
    echo "SKIPPED" "$id" "already installed"
    return 3
  fi

  if [ "$DRY_RUN" = true ]; then
    log "DRY-RUN: would run: $install_cmd"
    echo "DRYRUN" "$id" "$install_cmd"
    return 0
  fi

  # Execute installation
  log "INSTALLING: $id via: $install_cmd"
  echo "  Installing $id..." >&2

  local install_output
  local install_exit
  install_output=$(eval "$install_cmd" 2>&1)
  install_exit=$?

  log "  Exit code: $install_exit"
  log "  Output: $install_output"

  if [ $install_exit -ne 0 ]; then
    log "FAILED: $id (exit $install_exit)"
    echo "FAILED" "$id" "$install_output"
    return 4
  fi

  # Verify installation (reject metacharacters in verify_cmd too)
  if [ -n "$verify_cmd" ] && ! [[ "$verify_cmd" =~ [\;\&\|\$\`\>\<\(\)] ]]; then
    local version
    version=$(eval "$verify_cmd" 2>&1 | head -1)
    log "INSTALLED: $id — $version"
    echo "INSTALLED" "$id" "$version"
  else
    log "INSTALLED: $id (no verify command)"
    echo "INSTALLED" "$id" "unknown version"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

RESULTS=()
INSTALL_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
REJECT_COUNT=0

if [ "$DRY_RUN" = true ]; then
  echo "" >&2
  echo "=== DRY RUN — No changes will be made ===" >&2
  echo "" >&2
fi

while IFS= read -r tool_json; do
  [ -z "$tool_json" ] && continue

  result=$(process_tool "$tool_json")
  status=$(echo "$result" | awk '{print $1}')

  case "$status" in
    INSTALLED) INSTALL_COUNT=$((INSTALL_COUNT + 1)) ;;
    FAILED)    FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    SKIPPED)   SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
    REJECTED)  REJECT_COUNT=$((REJECT_COUNT + 1)) ;;
    DRYRUN)
      id=$(echo "$result" | awk '{print $2}')
      cmd=$(echo "$result" | cut -d' ' -f3-)
      echo "  Would install: $id → $cmd" >&2
      ;;
  esac

  RESULTS+=("$result")
done <<< "$TOOLS_JSON"

# ---------------------------------------------------------------------------
# Output JSON report
# ---------------------------------------------------------------------------

if [ "$DRY_RUN" = true ]; then
  echo "" >&2
  echo "Run with --yes to install. Example:" >&2
  echo "  bash install-cli-tools.sh $MANIFEST_FILE --yes" >&2
  echo "" >&2
fi

log "Complete: installed=$INSTALL_COUNT failed=$FAIL_COUNT skipped=$SKIP_COUNT rejected=$REJECT_COUNT"

# Build JSON report using python3 — pass results via temp file to avoid injection
RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT
# Guard: empty RESULTS array causes "unbound variable" in bash < 4.4
if [ ${#RESULTS[@]} -gt 0 ]; then
  printf '%s\n' "${RESULTS[@]}" > "$RESULTS_FILE"
else
  : > "$RESULTS_FILE"
fi

DRY_RUN_PY=$( [ "$DRY_RUN" = true ] && echo 'True' || echo 'False' )

python3 -c "
import json, sys

results_file, dry_run_str, installed, failed, skipped, rejected, total, log_file = sys.argv[1:]

results = []
with open(results_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 2)
        if len(parts) >= 2:
            entry = {'status': parts[0], 'id': parts[1]}
            if len(parts) >= 3:
                entry['detail'] = parts[2]
            results.append(entry)

report = {
    'dryRun': dry_run_str == 'True',
    'results': results,
    'summary': {
        'installed': int(installed),
        'failed': int(failed),
        'skipped': int(skipped),
        'rejected': int(rejected),
        'total': int(total)
    },
    'logFile': log_file
}

print(json.dumps(report, indent=2))
" "$RESULTS_FILE" "$DRY_RUN_PY" "$INSTALL_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$REJECT_COUNT" "$TOOL_COUNT" "$LOG_FILE" 2>/dev/null

exit 0
