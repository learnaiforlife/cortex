#!/bin/bash
# Cortex migration progress tracker
# Parses MIGRATION-PLAN.md and outputs progress metrics as JSON
# No external dependencies required — pure shell

set -euo pipefail

REPO_DIR="${1:-.}"

REPO_DIR="$(cd "$REPO_DIR" && pwd)"
PLAN_FILE="$REPO_DIR/MIGRATION-PLAN.md"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

if [ ! -f "$PLAN_FILE" ]; then
  echo '{"error": "No MIGRATION-PLAN.md found. Run /scaffold migrate to create one."}'
  exit 1
fi

# Count phases by status
TOTAL_PHASES=$(grep -c "^## Phase [0-9]" "$PLAN_FILE" || echo "0")
COMPLETED=$(grep -c "COMPLETE" "$PLAN_FILE" || echo "0")
IN_PROGRESS=$(grep -c "IN_PROGRESS" "$PLAN_FILE" || echo "0")
BLOCKED=$(grep -c "BLOCKED" "$PLAN_FILE" || echo "0")
NOT_STARTED=$(grep -c "NOT_STARTED" "$PLAN_FILE" || echo "0")

# Count checkboxes
TOTAL_CHECKS=$(grep -c "^\- \[" "$PLAN_FILE" || echo "0")
COMPLETED_CHECKS=$(grep -c "^\- \[x\]" "$PLAN_FILE" || echo "0")

# Calculate percentage
if [ "$TOTAL_PHASES" -gt 0 ]; then
  PERCENT=$(( (COMPLETED * 100) / TOTAL_PHASES ))
else
  PERCENT=0
fi

if [ "$TOTAL_CHECKS" -gt 0 ]; then
  CHECK_PERCENT=$(( (COMPLETED_CHECKS * 100) / TOTAL_CHECKS ))
else
  CHECK_PERCENT=0
fi

# Extract migration type from title
MIGRATION_TITLE=$(grep "^# Migration Plan:" "$PLAN_FILE" | head -1 | sed 's/# Migration Plan: //' || echo "Unknown")
MIGRATION_TITLE=$(json_escape "$MIGRATION_TITLE")

# Extract strategy and risk from overview
STRATEGY=$(grep "^\*\*Strategy\*\*:" "$PLAN_FILE" | head -1 | sed 's/.*: //' || echo "Unknown")
STRATEGY=$(json_escape "$STRATEGY")
RISK_LEVEL=$(grep "^\*\*Risk Level\*\*:" "$PLAN_FILE" | head -1 | sed 's/.*: //' || echo "Unknown")
RISK_LEVEL=$(json_escape "$RISK_LEVEL")

# Find current phase
CURRENT_PHASE_LINE=$(grep "IN_PROGRESS" "$PLAN_FILE" | head -1 || echo "")
CURRENT_PHASE="none"
if [ -n "$CURRENT_PHASE_LINE" ]; then
  CURRENT_PHASE=$(echo "$CURRENT_PHASE_LINE" | sed 's/## Phase [0-9]*: \(.*\) —.*/\1/')
  CURRENT_PHASE=$(json_escape "$CURRENT_PHASE")
fi

# Find blockers
BLOCKER_LIST=""
BLOCKER_FIRST=true
while IFS= read -r line; do
  [ -z "$line" ] && continue
  BLOCKER_DESC=$(echo "$line" | sed 's/- \[ \] //')
  BLOCKER_DESC=$(json_escape "$BLOCKER_DESC")
  if [ "$BLOCKER_FIRST" = true ]; then
    BLOCKER_FIRST=false
  else
    BLOCKER_LIST="${BLOCKER_LIST},"
  fi
  BLOCKER_LIST="${BLOCKER_LIST}\"$BLOCKER_DESC\""
done < <(grep -A 20 "BLOCKED" "$PLAN_FILE" | grep "^\- \[ \]" | head -5 2>/dev/null || true)

cat <<EOF
{
  "migration": "$MIGRATION_TITLE",
  "strategy": "$STRATEGY",
  "riskLevel": "$RISK_LEVEL",
  "totalPhases": $TOTAL_PHASES,
  "completedPhases": $COMPLETED,
  "inProgressPhases": $IN_PROGRESS,
  "blockedPhases": $BLOCKED,
  "notStartedPhases": $NOT_STARTED,
  "percentComplete": $PERCENT,
  "checkboxes": {
    "total": $TOTAL_CHECKS,
    "completed": $COMPLETED_CHECKS,
    "percent": $CHECK_PERCENT
  },
  "currentPhase": "$CURRENT_PHASE",
  "lastUpdated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "blockers": [$BLOCKER_LIST]
}
EOF
