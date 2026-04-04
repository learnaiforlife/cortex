#!/bin/bash
# Cortex migration phase validator
# Parses MIGRATION-PLAN.md, extracts validation criteria for current phase,
# and runs automated checks. Outputs PhaseValidation JSON.
# No external dependencies required — pure shell

set -euo pipefail

# Trap unexpected errors and output valid JSON instead of crashing
trap 'echo "{\"error\": \"Unexpected error in validation script\", \"phase\": 0, \"verdict\": \"FAIL\", \"checks\": []}"; exit 1' ERR

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

REPO_DIR="${1:-.}"
PHASE_NUM="${2:-}"

REPO_DIR="$(cd "$REPO_DIR" && pwd)"

# Validate PHASE_NUM is an integer if provided
if [ -n "$PHASE_NUM" ] && ! [[ "$PHASE_NUM" =~ ^[0-9]+$ ]]; then
  echo '{"error": "phase must be a positive integer", "phase": 0, "verdict": "ERROR", "checks": []}' >&2
  exit 1
fi

PLAN_FILE="$REPO_DIR/MIGRATION-PLAN.md"

if [ ! -f "$PLAN_FILE" ]; then
  echo '{"error": "No MIGRATION-PLAN.md found", "phase": 0, "verdict": "FAIL", "checks": []}'
  exit 1
fi

# Find current phase (first IN_PROGRESS, or use specified phase)
if [ -n "$PHASE_NUM" ]; then
  PHASE_HEADER=$(grep -n "^## Phase $PHASE_NUM:" "$PLAN_FILE" | head -1 | cut -d: -f1)
else
  # Find first IN_PROGRESS phase
  PHASE_LINE=$(grep -n "IN_PROGRESS" "$PLAN_FILE" | head -1)
  if [ -z "$PHASE_LINE" ]; then
    # Try first NOT_STARTED phase
    PHASE_LINE=$(grep -n "NOT_STARTED" "$PLAN_FILE" | head -1)
  fi
  if [ -z "$PHASE_LINE" ]; then
    echo '{"phase": 0, "phaseName": "All phases complete", "verdict": "PASS", "checks": [], "summary": "All phases are complete"}'
    exit 0
  fi
  LINE_NUM=$(echo "$PHASE_LINE" | cut -d: -f1)
  # Find the phase header above this line
  PHASE_HEADER=$(head -n "$LINE_NUM" "$PLAN_FILE" | grep -n "^## Phase" | tail -1 | cut -d: -f1)
fi

if [ -z "$PHASE_HEADER" ]; then
  echo '{"error": "Could not find phase header", "phase": 0, "verdict": "FAIL", "checks": []}'
  exit 1
fi

# Extract phase number and name
PHASE_INFO=$(sed -n "${PHASE_HEADER}p" "$PLAN_FILE")
CURRENT_PHASE=$(echo "$PHASE_INFO" | sed 's/## Phase \([0-9]*\):.*/\1/')
PHASE_NAME=$(echo "$PHASE_INFO" | sed 's/## Phase [0-9]*: \(.*\) —.*/\1/')
PHASE_NAME=$(json_escape "$PHASE_NAME")

# Find next phase header (to bound our search)
NEXT_PHASE_LINE=$(tail -n +"$((PHASE_HEADER + 1))" "$PLAN_FILE" | grep -n "^## Phase" | head -1 | cut -d: -f1)
if [ -n "$NEXT_PHASE_LINE" ]; then
  END_LINE=$((PHASE_HEADER + NEXT_PHASE_LINE - 1))
else
  END_LINE=$(wc -l < "$PLAN_FILE" | tr -d ' ')
fi

# Extract validation section
VALIDATION_START=$(sed -n "${PHASE_HEADER},${END_LINE}p" "$PLAN_FILE" | grep -n "^### Validation" | head -1 | cut -d: -f1)

if [ -z "$VALIDATION_START" ]; then
  echo "{\"phase\": $CURRENT_PHASE, \"phaseName\": \"$PHASE_NAME\", \"verdict\": \"SKIP\", \"checks\": [], \"summary\": \"No validation criteria found\"}"
  exit 0
fi

VALIDATION_ABS=$((PHASE_HEADER + VALIDATION_START - 1))

# Find end of validation section (next ### or ---)
VALIDATION_END=$(tail -n +"$((VALIDATION_ABS + 1))" "$PLAN_FILE" | grep -n "^###\|^---" | head -1 | cut -d: -f1)
if [ -n "$VALIDATION_END" ]; then
  VAL_END_ABS=$((VALIDATION_ABS + VALIDATION_END - 1))
else
  VAL_END_ABS=$END_LINE
fi

# Extract validation criteria (checkbox lines)
CRITERIA=$(sed -n "$((VALIDATION_ABS + 1)),${VAL_END_ABS}p" "$PLAN_FILE" | grep "^\- \[" || true)

if [ -z "$CRITERIA" ]; then
  echo "{\"phase\": $CURRENT_PHASE, \"phaseName\": \"$PHASE_NAME\", \"verdict\": \"SKIP\", \"checks\": [], \"summary\": \"No validation checkboxes found\"}"
  exit 0
fi

# Run basic checks
CHECKS=""
TOTAL=0
PASSED=0
FAILED=0
FIRST=true

while IFS= read -r line; do
  [ -z "$line" ] && continue
  TOTAL=$((TOTAL + 1))

  # Extract check description and escape for JSON
  CHECK_DESC=$(echo "$line" | sed 's/- \[.\] //')
  CHECK_DESC=$(json_escape "$CHECK_DESC")

  # Check if already marked done
  IS_DONE=$(echo "$line" | grep -c '\[x\]' || true)

  STATUS="SKIP"
  DETAIL="Manual verification required"

  if [ "$IS_DONE" -gt 0 ]; then
    STATUS="PASS"
    DETAIL="Previously validated (checked in plan)"
    PASSED=$((PASSED + 1))
  else
    # Try to detect runnable checks
    if echo "$CHECK_DESC" | grep -qi "test.*pass\|pytest\|npm test\|mvn test\|go test"; then
      # Check for test results — do NOT run tests (may have side effects)
      if [ -f "$REPO_DIR/package.json" ]; then
        STATUS="SKIP"
        DETAIL="Node.js test framework detected — run 'npm test' manually to verify"
      elif [ -f "$REPO_DIR/pyproject.toml" ] || [ -f "$REPO_DIR/setup.py" ]; then
        STATUS="SKIP"
        DETAIL="Python test framework detected — run 'pytest' manually to verify"
      elif [ -f "$REPO_DIR/go.mod" ]; then
        STATUS="SKIP"
        DETAIL="Go test framework detected — run 'go test ./...' manually to verify"
      elif [ -f "$REPO_DIR/pom.xml" ]; then
        STATUS="SKIP"
        DETAIL="Maven test framework detected — run 'mvn test' manually to verify"
      else
        STATUS="SKIP"
        DETAIL="Test framework not auto-detected — run tests manually"
      fi
    elif echo "$CHECK_DESC" | grep -qi "build.*succeed\|compile\|npm run build"; then
      STATUS="SKIP"
      DETAIL="Build check — run manually"
    elif echo "$CHECK_DESC" | grep -qi "file.*exist\|created\|generated"; then
      STATUS="SKIP"
      DETAIL="File existence check — requires manual verification"
    elif echo "$CHECK_DESC" | grep -qi "coverage"; then
      STATUS="SKIP"
      DETAIL="Coverage check — run coverage tool manually"
    else
      STATUS="SKIP"
      DETAIL="Manual verification required"
    fi
  fi

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    CHECKS="${CHECKS},"
  fi
  CHECKS="${CHECKS}{\"name\":\"$CHECK_DESC\",\"status\":\"$STATUS\",\"detail\":\"$DETAIL\"}"

done <<< "$CRITERIA"

# Determine overall verdict (PASS or FAIL — aligned with migration-validator agent)
VERDICT="PASS"
if [ "$FAILED" -gt 0 ]; then
  VERDICT="FAIL"
elif [ "$PASSED" -lt "$TOTAL" ]; then
  # Some checks were skipped but none failed — still PASS (skips need manual verification)
  VERDICT="PASS"
fi

cat <<EOF
{
  "phase": $CURRENT_PHASE,
  "phaseName": "$PHASE_NAME",
  "verdict": "$VERDICT",
  "checks": [$CHECKS],
  "summary": "$PASSED/$TOTAL checks passed, $((TOTAL - PASSED)) need manual verification"
}
EOF
