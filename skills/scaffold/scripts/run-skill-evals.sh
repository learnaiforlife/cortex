#!/bin/bash
# Cortex — Run skill-creator evals on a skill
# Usage: run-skill-evals.sh [skill-name]
# Requires: skill-creator plugin installed in Claude Code

SKILL_NAME="${1:-scaffold}"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"

if [ ! -d "$SKILL_DIR" ]; then
  echo "ERROR: Skill '$SKILL_NAME' not found at $SKILL_DIR" >&2
  exit 1
fi

if [ ! -f "$SKILL_DIR/evals/evals.json" ]; then
  echo "WARNING: No evals found for skill '$SKILL_NAME'" >&2
  echo "To generate evals, run: skill-creator create-evals $SKILL_DIR/SKILL.md" >&2
  exit 1
fi

echo "=== Running evals for skill: $SKILL_NAME ==="
echo ""
echo "Eval file: $SKILL_DIR/evals/evals.json"
echo ""

# Count evals
EVAL_COUNT=$(python3 -c "import json; print(len(json.load(open('$SKILL_DIR/evals/evals.json'))['evals']))" 2>/dev/null || echo "?")
echo "Total evals: $EVAL_COUNT"
echo ""

# List eval IDs
echo "Eval cases:"
python3 -c "
import json
data = json.load(open('$SKILL_DIR/evals/evals.json'))
for e in data['evals']:
    expectations = len(e.get('expectations', []))
    print(f\"  - {e['id']} ({expectations} expectations)\")
" 2>/dev/null || echo "  (install python3 to list evals)"

echo ""
echo "To run evals in Claude Code, use:"
echo "  skill-creator eval $SKILL_NAME"
echo ""
echo "To improve a skill based on eval results:"
echo "  skill-creator improve $SKILL_NAME"
echo ""
echo "To benchmark with variance analysis:"
echo "  skill-creator benchmark $SKILL_NAME"
