#!/bin/bash
# Cortex Discover — Results Logger
# Append-only TSV log for discover runs, parallel to scaffold-results.tsv.
# Referenced by: AGENTS.md (documented as DeveloperDNA logger)
# Called by: discover workflow (invoked by subagent, not directly by other scripts)
#
# Usage: log-discover.sh <scan_dirs> <total_projects> <active_projects> \
#          <integrations_found> <user_level_files> <project_level_files> \
#          <status> <description> [log-file]
#
# Output: appends one TSV row to the discover log file

set -uo pipefail

SCAN_DIRS="${1:-}"
TOTAL_PROJECTS="${2:-0}"
ACTIVE_PROJECTS="${3:-0}"
INTEGRATIONS_FOUND="${4:-0}"
USER_LEVEL_FILES="${5:-0}"
PROJECT_LEVEL_FILES="${6:-0}"
STATUS="${7:-unknown}"
DESCRIPTION="${8:-}"
LOG_FILE="${9:-$HOME/.cortex/discover-results.tsv}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Write header if log file is new
if [ ! -f "$LOG_FILE" ]; then
  printf "timestamp\tscan_dirs\ttotal_projects\tactive_projects\tintegrations_found\tuser_level_files\tproject_level_files\tstatus\tdescription\n" > "$LOG_FILE"
fi

# Timestamp in ISO 8601
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Sanitize description (no tabs/newlines)
SAFE_DESC=$(echo "$DESCRIPTION" | tr '\t\n' '  ' | head -c 200)

# Append row
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$TIMESTAMP" \
  "$SCAN_DIRS" \
  "$TOTAL_PROJECTS" \
  "$ACTIVE_PROJECTS" \
  "$INTEGRATIONS_FOUND" \
  "$USER_LEVEL_FILES" \
  "$PROJECT_LEVEL_FILES" \
  "$STATUS" \
  "$SAFE_DESC" \
  >> "$LOG_FILE"

echo "Logged discover run: $TOTAL_PROJECTS projects, $INTEGRATIONS_FOUND integrations, status=$STATUS ($LOG_FILE)"
