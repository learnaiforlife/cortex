#!/bin/bash
# Cortex — Automated Eval Runner
# Checks machine-verifiable assertions from evals.json against scaffold output.
# Inspired by autoresearch's evaluate_bpb: a fixed, immutable evaluation contract.
#
# Usage: run-skill-evals.sh <repo-dir> [eval-id]
#   <repo-dir>  Directory with scaffold output to verify
#   [eval-id]   Optional: run only this eval (default: all matching evals)
#
# Assertions check structural properties of generated files (existence, content,
# size, score thresholds). They do NOT run the scaffold — they verify its output.
#
# Exit code: 0 if all assertions pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${1:-.}"
FILTER_EVAL="${2:-}"
EVALS_FILE="$SCRIPT_DIR/../evals/evals.json"

if [ ! -f "$EVALS_FILE" ]; then
  echo "ERROR: evals.json not found at $EVALS_FILE" >&2
  exit 1
fi

TOTAL_ASSERTIONS=0
PASSED_ASSERTIONS=0
FAILED_ASSERTIONS=0
SKIPPED_ASSERTIONS=0
EVAL_RESULTS=""

# Get scaffold score once (reused by score_min assertions)
SCORE_JSON=""
if [ -f "$SCRIPT_DIR/score.sh" ]; then
  SCORE_JSON=$(bash "$SCRIPT_DIR/score.sh" "$REPO_DIR" 2>/dev/null || echo "{}")
fi

# Run a single assertion. Returns 0=pass, 1=fail, 2=skip.
run_assertion() {
  local type="$1"
  local json="$2"

  case "$type" in
    file_exists)
      local path
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      if [ -f "$REPO_DIR/$path" ]; then
        echo "$path exists"; return 0
      else
        echo "$path missing"; return 1
      fi
      ;;

    dir_exists)
      local path
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      if [ -d "$REPO_DIR/$path" ]; then
        echo "$path/ exists"; return 0
      else
        echo "$path/ missing"; return 1
      fi
      ;;

    file_contains)
      local path pattern
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      pattern=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pattern'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path missing (cannot check content)"; return 1
      fi
      if grep -qE "$pattern" "$REPO_DIR/$path" 2>/dev/null; then
        echo "$path matches /$pattern/"; return 0
      else
        echo "$path does not match /$pattern/"; return 1
      fi
      ;;

    file_not_contains)
      local path pattern
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      pattern=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pattern'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path missing (vacuously passes)"; return 0
      fi
      if grep -qE "$pattern" "$REPO_DIR/$path" 2>/dev/null; then
        echo "$path unexpectedly contains /$pattern/"; return 1
      else
        echo "$path clean of /$pattern/"; return 0
      fi
      ;;

    file_min_size)
      local path min_bytes
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      min_bytes=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_bytes'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path missing"; return 1
      fi
      local size
      size=$(wc -c < "$REPO_DIR/$path" | tr -d ' ')
      if [ "$size" -ge "$min_bytes" ]; then
        echo "$path is ${size}B (>= ${min_bytes}B)"; return 0
      else
        echo "$path is ${size}B (< ${min_bytes}B)"; return 1
      fi
      ;;

    max_file_count)
      local max_files
      max_files=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['max_files'])")
      local count=0
      [ -f "$REPO_DIR/CLAUDE.md" ] && count=$((count + 1))
      [ -f "$REPO_DIR/AGENTS.md" ] && count=$((count + 1))
      [ -f "$REPO_DIR/.mcp.json" ] && count=$((count + 1))
      local extra
      extra=$(find "$REPO_DIR/.claude" "$REPO_DIR/.cursor" -type f 2>/dev/null | wc -l | tr -d ' ')
      count=$((count + extra))
      if [ "$count" -le "$max_files" ]; then
        echo "$count files (<= $max_files)"; return 0
      else
        echo "$count files (> $max_files)"; return 1
      fi
      ;;

    frontmatter_absent)
      local path
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path missing"; return 1
      fi
      if head -1 "$REPO_DIR/$path" | grep -q '^---$'; then
        echo "$path has YAML frontmatter (should not)"; return 1
      else
        echo "$path has no frontmatter"; return 0
      fi
      ;;

    no_skill_named)
      local pattern
      pattern=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pattern'])")
      local bad_skills=""
      for d in "$REPO_DIR"/.claude/skills/*/; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        if echo "$name" | grep -qiE "$pattern"; then
          bad_skills="$bad_skills $name"
        fi
      done
      if [ -z "$bad_skills" ]; then
        echo "no skills matching /$pattern/"; return 0
      else
        echo "found disallowed skills:$bad_skills"; return 1
      fi
      ;;

    no_placeholder_in_dir)
      local dir
      dir=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['dir'])")
      if [ ! -d "$REPO_DIR/$dir" ]; then
        echo "$dir/ does not exist (vacuously passes)"; return 0
      fi
      local hits
      hits=$(grep -rlE '\[PROJECT_NAME\]|PLACEHOLDER|TODO:|your-command-here' "$REPO_DIR/$dir" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$hits" -eq 0 ]; then
        echo "$dir/ has no placeholder text"; return 0
      else
        echo "$dir/ has $hits files with placeholder text"; return 1
      fi
      ;;

    score_min)
      local dimension min_value
      dimension=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['dimension'])")
      min_value=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_value'])")
      if [ -z "$SCORE_JSON" ]; then
        echo "score.sh unavailable (skipped)"; return 2
      fi
      local actual
      if [ "$dimension" = "total_score" ]; then
        actual=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_score'])")
      else
        actual=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['dimensions']['$dimension']['score'])")
      fi
      if [ "$actual" -ge "$min_value" ]; then
        echo "$dimension=$actual (>= $min_value)"; return 0
      else
        echo "$dimension=$actual (< $min_value)"; return 1
      fi
      ;;

    frontmatter_field)
      local path field expected
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      field=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['field'])")
      expected=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['expected'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path missing"; return 1
      fi
      # Extract YAML frontmatter field value
      local actual
      actual=$(sed -n '/^---$/,/^---$/p' "$REPO_DIR/$path" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"' | tr -d "'" | tr -d ' ')
      if [ "$actual" = "$expected" ]; then
        echo "$path frontmatter $field=$actual (matches $expected)"; return 0
      else
        echo "$path frontmatter $field=$actual (expected $expected)"; return 1
      fi
      ;;

    script_output_valid_json)
      local script args_val
      script=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['script'])")
      args_val=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('args', ''))")
      local script_path="$SCRIPT_DIR/$script"
      if [ ! -f "$script_path" ]; then
        echo "$script not found at $script_path"; return 1
      fi
      local target_dir
      if [ -n "$args_val" ]; then
        # args is relative to project root (SAVED_REPO_DIR), not the overridden REPO_DIR
        target_dir="$SAVED_REPO_DIR/$args_val"
      else
        target_dir="$REPO_DIR"
      fi
      local output
      output=$(bash "$script_path" "$target_dir" 2>/dev/null)
      if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "$script produces valid JSON"; return 0
      else
        echo "$script output is not valid JSON"; return 1
      fi
      ;;

    no_placeholders)
      local hits=0
      if [ -d "$REPO_DIR/.claude" ]; then
        hits=$(grep -rlE '\{\{[A-Z_]+\}\}' "$REPO_DIR/.claude" 2>/dev/null | wc -l | tr -d ' ')
      fi
      if [ "$hits" -eq 0 ]; then
        echo "no unfilled {{PLACEHOLDER}} values found"; return 0
      else
        echo "$hits files have unfilled {{PLACEHOLDER}} values"; return 1
      fi
      ;;

    file_not_exists)
      local path
      path=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
      if [ ! -f "$REPO_DIR/$path" ]; then
        echo "$path correctly absent"; return 0
      else
        echo "$path unexpectedly exists"; return 1
      fi
      ;;

    output_contains)
      echo "output assertion (requires live run, skipped)"; return 2
      ;;

    *)
      echo "unknown assertion type: $type"; return 2
      ;;
  esac
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║             Cortex Eval Runner — Assertion Mode             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Repo dir:   $REPO_DIR"
echo "Evals file: $EVALS_FILE"
[ -n "$FILTER_EVAL" ] && echo "Filter:     $FILTER_EVAL"
echo ""

# Parse and iterate evals
EVAL_COUNT=$(python3 -c "import json; print(len(json.load(open('$EVALS_FILE'))['evals']))")

for i in $(seq 0 $((EVAL_COUNT - 1))); do
  EVAL_ID=$(python3 -c "import json; print(json.load(open('$EVALS_FILE'))['evals'][$i]['id'])")

  # Skip if filtering and this isn't the target
  if [ -n "$FILTER_EVAL" ] && [ "$EVAL_ID" != "$FILTER_EVAL" ]; then
    continue
  fi

  # Use per-eval fixture directory if specified, otherwise use global REPO_DIR
  EVAL_FIXTURE=$(python3 -c "import json; print(json.load(open('$EVALS_FILE'))['evals'][$i].get('fixture', ''))" 2>/dev/null || echo "")
  if [ -n "$EVAL_FIXTURE" ]; then
    EVAL_DIR="$REPO_DIR/$EVAL_FIXTURE"
  else
    EVAL_DIR="$REPO_DIR"
  fi

  ASSERTION_COUNT=$(python3 -c "
import json
e = json.load(open('$EVALS_FILE'))['evals'][$i]
print(len(e.get('assertions', [])))
" 2>/dev/null || echo "0")

  if [ "$ASSERTION_COUNT" -eq 0 ]; then
    echo "── $EVAL_ID: no assertions defined (skipped)"
    continue
  fi

  echo "── $EVAL_ID ($ASSERTION_COUNT assertions) [dir: $EVAL_DIR]"
  EVAL_PASS=0
  EVAL_FAIL=0
  EVAL_SKIP=0

  # Score the eval-specific directory for score_min assertions
  EVAL_SCORE_JSON=""
  if [ -f "$SCRIPT_DIR/score.sh" ]; then
    EVAL_SCORE_JSON=$(bash "$SCRIPT_DIR/score.sh" "$EVAL_DIR" 2>/dev/null || echo "{}")
  fi

  # Override REPO_DIR for this eval's assertions
  SAVED_REPO_DIR="$REPO_DIR"
  SAVED_SCORE_JSON="$SCORE_JSON"
  REPO_DIR="$EVAL_DIR"
  SCORE_JSON="$EVAL_SCORE_JSON"

  for j in $(seq 0 $((ASSERTION_COUNT - 1))); do
    ASSERTION_JSON=$(python3 -c "
import json, sys
a = json.load(open('$EVALS_FILE'))['evals'][$i]['assertions'][$j]
json.dump(a, sys.stdout)
")
    ASSERTION_TYPE=$(echo "$ASSERTION_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['type'])")

    TOTAL_ASSERTIONS=$((TOTAL_ASSERTIONS + 1))

    # Run the assertion and capture exit code
    set +e
    DETAIL=$(run_assertion "$ASSERTION_TYPE" "$ASSERTION_JSON" 2>&1)
    RESULT=$?
    set -e

    case $RESULT in
      0)
        echo "   ✓ $ASSERTION_TYPE: $DETAIL"
        PASSED_ASSERTIONS=$((PASSED_ASSERTIONS + 1))
        EVAL_PASS=$((EVAL_PASS + 1))
        ;;
      1)
        echo "   ✗ $ASSERTION_TYPE: $DETAIL"
        FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
        EVAL_FAIL=$((EVAL_FAIL + 1))
        ;;
      2)
        echo "   ~ $ASSERTION_TYPE: $DETAIL"
        SKIPPED_ASSERTIONS=$((SKIPPED_ASSERTIONS + 1))
        EVAL_SKIP=$((EVAL_SKIP + 1))
        ;;
    esac
  done

  # Restore global REPO_DIR
  REPO_DIR="$SAVED_REPO_DIR"
  SCORE_JSON="$SAVED_SCORE_JSON"

  STATUS="PASS"
  [ "$EVAL_FAIL" -gt 0 ] && STATUS="FAIL"
  echo "   Result: $STATUS ($EVAL_PASS passed, $EVAL_FAIL failed, $EVAL_SKIP skipped)"
  echo ""

  EVAL_RESULTS="$EVAL_RESULTS$EVAL_ID\t$STATUS\t$EVAL_PASS\t$EVAL_FAIL\t$EVAL_SKIP\n"
done

# Summary
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  Total assertions: $TOTAL_ASSERTIONS"
echo "  Passed:           $PASSED_ASSERTIONS"
echo "  Failed:           $FAILED_ASSERTIONS"
echo "  Skipped:          $SKIPPED_ASSERTIONS"

if [ "$TOTAL_ASSERTIONS" -gt 0 ]; then
  CHECKABLE=$((TOTAL_ASSERTIONS - SKIPPED_ASSERTIONS))
  if [ "$CHECKABLE" -gt 0 ]; then
    PASS_RATE=$((PASSED_ASSERTIONS * 100 / CHECKABLE))
    echo "  Pass rate:        ${PASS_RATE}%"
  fi
fi

echo ""

# Include scaffold score if available
if [ -n "$SCORE_JSON" ]; then
  TOTAL_SCORE=$(echo "$SCORE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_score'])" 2>/dev/null || echo "?")
  echo "  Scaffold score:   $TOTAL_SCORE/100"
fi

echo ""

if [ "$FAILED_ASSERTIONS" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
