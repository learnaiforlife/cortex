#!/bin/bash
# Cortex — Autoresearch-Style Self-Improvement Loop
#
# The core autoresearch pattern applied to prompt engineering:
#   1. Run scaffold on all fixtures -> collect baseline scores
#   2. Agent proposes a SKILL.md edit
#   3. Re-run scaffold on all fixtures -> collect new scores
#   4. If avg score improves: keep commit. If not: revert.
#   5. Repeat.
#
# This script handles steps 1, 3-5. Step 2 is done by the skill-improver agent
# invoked from SKILL.md's optimize mode.
#
# Usage: auto-improve.sh <skill-dir> [max-iterations] [fixture-dir]
#   <skill-dir>     Path to the scaffold skill directory (contains SKILL.md)
#   [max-iterations] Maximum improvement iterations (default: 5)
#   [fixture-dir]    Path to test fixtures (default: test/fixtures)
#
# Prerequisites:
#   - score.sh must be in the same scripts/ directory
#   - Test fixtures must exist at fixture-dir
#   - Git repo must be clean (uncommitted changes will be stashed)
#
# Output: prints iteration log and final summary

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
MAX_ITERATIONS="${2:-5}"
FIXTURE_DIR="${3:-$(cd "$SCRIPT_DIR/../../.." && pwd)/test/fixtures}"
RESULTS_FILE="$HOME/.cortex/auto-improve-log.tsv"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Cortex Auto-Improve — Autoresearch for Skills        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Skill dir:       $SKILL_DIR"
echo "Fixture dir:     $FIXTURE_DIR"
echo "Max iterations:  $MAX_ITERATIONS"
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
    s=$(echo "$score_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_score',0))" 2>/dev/null || echo 0)
    f=$(echo "$score_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('format_compliance',{}).get('score',0))" 2>/dev/null || echo 0)
    sp=$(echo "$score_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('specificity',{}).get('score',0))" 2>/dev/null || echo 0)
    c=$(echo "$score_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('completeness',{}).get('score',0))" 2>/dev/null || echo 0)
    st=$(echo "$score_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dimensions',{}).get('structural_quality',{}).get('score',0))" 2>/dev/null || echo 0)

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

# Collect baseline scores
echo "── Baseline scoring..."
BASELINE_JSON=$(score_all_fixtures)
BASELINE_AVG=$(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_total'])" 2>/dev/null || echo 0)
BASELINE_WEAKEST=$(find_weakest "$BASELINE_JSON")

echo "   Baseline avg score: $BASELINE_AVG/100"
echo "   Weakest dimension:  $BASELINE_WEAKEST"
echo "   Fixtures scored:    $(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['fixture_count'])" 2>/dev/null || echo "?")"
echo ""

# Log baseline
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$TIMESTAMP" "0" "$BASELINE_AVG" \
  "$(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_format'])" 2>/dev/null)" \
  "$(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_specificity'])" 2>/dev/null)" \
  "$(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_completeness'])" 2>/dev/null)" \
  "$(echo "$BASELINE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_structure'])" 2>/dev/null)" \
  "baseline" "n/a" "initial measurement" \
  >> "$RESULTS_FILE"

PREV_AVG=$BASELINE_AVG
PREV_JSON=$BASELINE_JSON

echo "── Starting improvement loop (max $MAX_ITERATIONS iterations)..."
echo ""

for i in $(seq 1 "$MAX_ITERATIONS"); do
  WEAKEST=$(find_weakest "$PREV_JSON")
  echo "── Iteration $i: targeting $WEAKEST (prev avg=$PREV_AVG)"

  # The actual SKILL.md edit would be done by the skill-improver agent.
  # This script provides the measurement infrastructure around it.
  # When run standalone, it reports what the agent should target.
  echo "   ACTION REQUIRED: Dispatch skill-improver agent with:"
  echo "     - SKILL.md path: $SKILL_DIR/SKILL.md"
  echo "     - Weakest dimension: $WEAKEST"
  echo "     - Current scores: $PREV_JSON"
  echo "     - Evals path: $SKILL_DIR/evals/evals.json"
  echo ""
  echo "   After the agent edits SKILL.md, re-run scaffold on fixtures,"
  echo "   then call this script with --measure-only to compare scores."
  echo ""

  # Re-score after (hypothetical) agent edit
  NEW_JSON=$(score_all_fixtures)
  NEW_AVG=$(echo "$NEW_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_total'])" 2>/dev/null || echo 0)

  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [ "$NEW_AVG" -gt "$PREV_AVG" ]; then
    echo "   Score: $PREV_AVG -> $NEW_AVG [IMPROVED — KEEP]"
    STATUS="keep"
    PREV_AVG=$NEW_AVG
    PREV_JSON=$NEW_JSON
  else
    echo "   Score: $PREV_AVG -> $NEW_AVG [NO IMPROVEMENT — REVERT]"
    STATUS="revert"
  fi

  # Log iteration (evolution_mode is filled by the skill-improver agent; default to "unknown" here)
  EVOLUTION_MODE="${EVOLUTION_MODE:-unknown}"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$TIMESTAMP" "$i" "$NEW_AVG" \
    "$(echo "$NEW_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_format'])" 2>/dev/null)" \
    "$(echo "$NEW_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_specificity'])" 2>/dev/null)" \
    "$(echo "$NEW_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_completeness'])" 2>/dev/null)" \
    "$(echo "$NEW_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['avg_structure'])" 2>/dev/null)" \
    "$STATUS" "$EVOLUTION_MODE" "targeted $WEAKEST" \
    >> "$RESULTS_FILE"

  # Stop if no improvement (further iterations unlikely to help without new edits)
  if [ "$STATUS" = "revert" ]; then
    echo ""
    echo "   Stopping: no improvement detected. Further iterations need"
    echo "   the skill-improver agent to make a new SKILL.md edit first."
    break
  fi

  # Stop if score is already good
  if [ "$NEW_AVG" -ge 80 ]; then
    echo ""
    echo "   Stopping: score >= 80 (good enough)."
    break
  fi

  echo ""
done

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Auto-Improve Summary:"
echo "  Baseline score:    $BASELINE_AVG/100"
echo "  Final score:       $PREV_AVG/100"
echo "  Improvement:       +$((PREV_AVG - BASELINE_AVG)) points"
echo "  Results log:       $RESULTS_FILE"
echo ""
echo "To continue improving, dispatch the skill-improver agent to edit"
echo "SKILL.md, then re-run this script."
