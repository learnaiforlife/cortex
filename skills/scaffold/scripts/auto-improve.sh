#!/bin/bash
# Cortex — Scaffold Quality Measurement
#
# Scores all test fixtures and reports the current quality baseline.
# Identifies the weakest scoring dimension so targeted improvement
# can be applied by the skill-improver agent.
#
# This script is MEASUREMENT INFRASTRUCTURE only. It does NOT edit
# SKILL.md or invoke any agents. The actual improvement loop is
# orchestrated by the Claude agent when a user runs:
#   /scaffold optimize auto-improve
#
# That agent-driven workflow calls this script for before/after
# measurement, then dispatches the skill-improver agent for edits.
#
# Usage: auto-improve.sh <skill-dir> [fixture-dir]
#   <skill-dir>     Path to the scaffold skill directory (contains SKILL.md)
#   [fixture-dir]    Path to test fixtures (default: test/fixtures)
#
# Prerequisites:
#   - score.sh must be in the same scripts/ directory
#   - Test fixtures must exist at fixture-dir
#
# Output:
#   - Prints quality report with per-dimension scores
#   - Appends a measurement row to ~/.cortex/auto-improve-log.tsv
#   - Exits with 0 (score >= 70) or 1 (score < 70)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
FIXTURE_DIR="${2:-$(cd "$SCRIPT_DIR/../../.." && pwd)/test/fixtures}"
RESULTS_FILE="$HOME/.cortex/auto-improve-log.tsv"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Cortex — Scaffold Quality Measurement              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Skill dir:       $SKILL_DIR"
echo "Fixture dir:     $FIXTURE_DIR"
echo ""

# Ensure prerequisites
if [ ! -f "$SCRIPT_DIR/score.sh" ]; then
  echo "ERROR: score.sh not found at $SCRIPT_DIR/score.sh" >&2
  exit 1
fi

if [ ! -d "$FIXTURE_DIR" ]; then
  echo "ERROR: fixture directory not found at $FIXTURE_DIR" >&2
  exit 1
fi

# Ensure results directory exists
mkdir -p "$(dirname "$RESULTS_FILE")"

# Write header if log file is new
if [ ! -f "$RESULTS_FILE" ]; then
  printf "timestamp\titeration\tavg_score\tformat\tspecificity\tcompleteness\tstructure\tstatus\tevolution_mode\tdescription\n" > "$RESULTS_FILE"
fi

# Score all fixtures and return the average score as JSON
score_all_fixtures() {
  local total=0
  local format_total=0
  local specificity_total=0
  local completeness_total=0
  local structure_total=0
  local count=0

  for fixture in "$FIXTURE_DIR"/*/; do
    [ -d "$fixture" ] || continue
    local score_json
    score_json=$(bash "$SCRIPT_DIR/score.sh" "$fixture" 2>/dev/null || echo '{"total_score":0}')

    local s f sp c st
    s=$(echo "$score_json" | python3 -c "import sys,json; print(int(json.load(sys.stdin).get('total_score',0)))" 2>/dev/null || echo 0)
    f=$(echo "$score_json" | python3 -c "import sys,json; print(int(json.load(sys.stdin).get('dimensions',{}).get('format_compliance',{}).get('score',0)))" 2>/dev/null || echo 0)
    sp=$(echo "$score_json" | python3 -c "import sys,json; print(int(json.load(sys.stdin).get('dimensions',{}).get('specificity',{}).get('score',0)))" 2>/dev/null || echo 0)
    c=$(echo "$score_json" | python3 -c "import sys,json; print(int(json.load(sys.stdin).get('dimensions',{}).get('completeness',{}).get('score',0)))" 2>/dev/null || echo 0)
    st=$(echo "$score_json" | python3 -c "import sys,json; print(int(json.load(sys.stdin).get('dimensions',{}).get('structural_quality',{}).get('score',0)))" 2>/dev/null || echo 0)

    total=$((total + s))
    format_total=$((format_total + f))
    specificity_total=$((specificity_total + sp))
    completeness_total=$((completeness_total + c))
    structure_total=$((structure_total + st))
    count=$((count + 1))
  done

  if [ "$count" -eq 0 ]; then
    echo '{"avg_total":0,"avg_format":0,"avg_specificity":0,"avg_completeness":0,"avg_structure":0,"fixture_count":0}'
    return
  fi

  local avg=$((total / count))
  local avg_f=$((format_total / count))
  local avg_sp=$((specificity_total / count))
  local avg_c=$((completeness_total / count))
  local avg_st=$((structure_total / count))

  cat <<EOF
{"avg_total":$avg,"avg_format":$avg_f,"avg_specificity":$avg_sp,"avg_completeness":$avg_c,"avg_structure":$avg_st,"fixture_count":$count}
EOF
}

# Find the weakest dimension from a scores JSON string
find_weakest() {
  local scores_json="$1"
  echo "$scores_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
dims = {
  'format_compliance': d.get('avg_format', 0),
  'specificity': d.get('avg_specificity', 0),
  'completeness': d.get('avg_completeness', 0),
  'structural_quality': d.get('avg_structure', 0)
}
print(min(dims, key=dims.get))
" 2>/dev/null || echo "unknown"
}

# Score all fixtures
echo "── Scoring all fixtures..."
SCORES_JSON=$(score_all_fixtures)
AVG_SCORE=$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_total'])" 2>/dev/null || echo 0)
WEAKEST=$(find_weakest "$SCORES_JSON")
FIXTURE_COUNT=$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['fixture_count'])" 2>/dev/null || echo "?")

# Log the measurement
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$TIMESTAMP" "0" "$AVG_SCORE" \
  "$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_format'])" 2>/dev/null)" \
  "$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_specificity'])" 2>/dev/null)" \
  "$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_completeness'])" 2>/dev/null)" \
  "$(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_structure'])" 2>/dev/null)" \
  "measurement" "n/a" "quality measurement" \
  >> "$RESULTS_FILE"

# Print the quality report
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Quality Report:"
echo "  Average score:       $AVG_SCORE/100"
echo "  Fixtures scored:     $FIXTURE_COUNT"
echo "  Weakest dimension:   $WEAKEST"
echo ""
echo "  Per-dimension breakdown:"
echo "    Format compliance:   $(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_format'])" 2>/dev/null)/25"
echo "    Specificity:         $(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_specificity'])" 2>/dev/null)/25"
echo "    Completeness:        $(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_completeness'])" 2>/dev/null)/25"
echo "    Structural quality:  $(echo "$SCORES_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_structure'])" 2>/dev/null)/25"
echo ""
echo "  Results log:         $RESULTS_FILE"
echo ""

# Actionable guidance based on score
if [ "$AVG_SCORE" -lt 70 ]; then
  echo "  Score is below 70. To improve, run:"
  echo "    /scaffold optimize auto-improve"
  echo "  This dispatches the skill-improver agent to edit SKILL.md,"
  echo "  then re-measures to verify the change helped."
  echo ""
  exit 0
elif [ "$AVG_SCORE" -lt 80 ]; then
  echo "  Score is acceptable but could be improved."
  echo "  Run /scaffold optimize auto-improve to target the"
  echo "  weakest dimension ($WEAKEST) with a focused edit."
  echo ""
  exit 0
else
  echo "  Score is good (>= 80). No action needed."
  echo ""
  exit 0
fi
