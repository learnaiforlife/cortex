#!/bin/bash
# Cortex — Append-Only Scaffold Results Logger
# Inspired by autoresearch's results.tsv: a lab notebook for every scaffold run.
#
# Logs one row per scaffold invocation with quality scores and metadata.
# The log file is append-only — never truncated, never overwritten.
#
# Usage: log-result.sh <repo-dir> <status> <description> [log-file] [qr-verdict] [qr-score] [improver-ran] [improver-helped] [subagent-timeouts]
#   <repo-dir>           The scaffolded repository directory
#   <status>             One of: success, partial, fail, crash
#   <description>        Short description of what was scaffolded
#   [log-file]           Optional path to results log (default: ~/.cortex/scaffold-results.tsv)
#   [qr-verdict]         Quality-reviewer first-pass verdict: PASS or FAIL (default: unknown)
#   [qr-score]           Quality-reviewer numeric score on first pass (default: 0)
#   [improver-ran]       Whether Step 6B ran: true or false (default: false)
#   [improver-helped]    Whether the improver raised the score: true or false (default: false)
#   [subagent-timeouts]  Count of subagents that timed out (default: 0)
#
# Output: appends one TSV row to the log file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${1:-.}"
STATUS="${2:-unknown}"
DESCRIPTION="${3:-}"
LOG_FILE="${4:-$HOME/.cortex/scaffold-results.tsv}"
QR_VERDICT="${5:-unknown}"
QR_SCORE="${6:-0}"
IMPROVER_RAN="${7:-false}"
IMPROVER_HELPED="${8:-false}"
SUBAGENT_TIMEOUTS="${9:-0}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Write header if log file is new
if [ ! -f "$LOG_FILE" ]; then
  printf "timestamp\trepo\tscore\tformat\tspecificity\tcompleteness\tstructure\tfiles_generated\tqr_verdict\tqr_score\timprover_ran\timprover_helped\tsubagent_timeouts\tstatus\tdescription\n" > "$LOG_FILE"
fi

# Get scaffold score
SCORE_TOTAL=0
SCORE_FORMAT=0
SCORE_SPECIFICITY=0
SCORE_COMPLETENESS=0
SCORE_STRUCTURE=0

if [ -f "$SCRIPT_DIR/score.sh" ]; then
  SCORE_JSON=$(bash "$SCRIPT_DIR/score.sh" "$REPO_DIR" 2>/dev/null || echo "{}")
  if [ -n "$SCORE_JSON" ]; then
    SCORE_TOTAL=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_score', 0))" 2>/dev/null || echo 0)
    SCORE_FORMAT=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('format_compliance',{}).get('score', 0))" 2>/dev/null || echo 0)
    SCORE_SPECIFICITY=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('specificity',{}).get('score', 0))" 2>/dev/null || echo 0)
    SCORE_COMPLETENESS=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('completeness',{}).get('score', 0))" 2>/dev/null || echo 0)
    SCORE_STRUCTURE=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('structural_quality',{}).get('score', 0))" 2>/dev/null || echo 0)
  fi
fi

# Count generated files
FILES_COUNT=0
[ -f "$REPO_DIR/CLAUDE.md" ] && FILES_COUNT=$((FILES_COUNT + 1))
[ -f "$REPO_DIR/AGENTS.md" ] && FILES_COUNT=$((FILES_COUNT + 1))
[ -f "$REPO_DIR/.mcp.json" ] && FILES_COUNT=$((FILES_COUNT + 1))
EXTRA=0
if [ -d "$REPO_DIR/.claude" ] || [ -d "$REPO_DIR/.cursor" ]; then
  EXTRA=$(find "$REPO_DIR/.claude" "$REPO_DIR/.cursor" -type f 2>/dev/null | wc -l | tr -d ' ')
fi
FILES_COUNT=$((FILES_COUNT + EXTRA))

# Derive repo identifier (basename or URL)
REPO_ID=$(basename "$REPO_DIR")
if [ "$REPO_ID" = "repo" ] || [ "$REPO_ID" = "." ]; then
  REPO_ID=$(cd "$REPO_DIR" 2>/dev/null && basename "$(pwd)")
fi

# Timestamp in ISO 8601
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Append row
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$TIMESTAMP" \
  "$REPO_ID" \
  "$SCORE_TOTAL" \
  "$SCORE_FORMAT" \
  "$SCORE_SPECIFICITY" \
  "$SCORE_COMPLETENESS" \
  "$SCORE_STRUCTURE" \
  "$FILES_COUNT" \
  "$QR_VERDICT" \
  "$QR_SCORE" \
  "$IMPROVER_RAN" \
  "$IMPROVER_HELPED" \
  "$SUBAGENT_TIMEOUTS" \
  "$STATUS" \
  "$DESCRIPTION" \
  >> "$LOG_FILE"

# Write score to single-value file for hooks (Stop hook reads this)
echo "$SCORE_TOTAL" > "$HOME/.cortex/last-scaffold-score.txt"

echo "Logged: $REPO_ID score=$SCORE_TOTAL status=$STATUS ($LOG_FILE)"
