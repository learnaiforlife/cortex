#!/bin/bash
# Validate generated scaffold files
# Checks YAML frontmatter, file structure, and basic format compliance

set -euo pipefail

REPO_DIR="${1:-.}"
ERRORS=0
WARNINGS=0

echo "Validating scaffold files in $REPO_DIR..."

# Check CLAUDE.md exists and is not empty
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/CLAUDE.md")
  if [ "$SIZE" -lt 100 ]; then
    echo "WARNING: CLAUDE.md is very short ($SIZE bytes) - likely too generic"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "OK: CLAUDE.md ($SIZE bytes)"
  fi
fi

# Check agent files have YAML frontmatter
for f in "$REPO_DIR"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    echo "ERROR: $f missing YAML frontmatter"
    ERRORS=$((ERRORS + 1))
  elif ! grep -q '^name:' "$f"; then
    echo "ERROR: $f missing 'name' in frontmatter"
    ERRORS=$((ERRORS + 1))
  elif ! grep -q '^description:' "$f"; then
    echo "ERROR: $f missing 'description' in frontmatter"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: $f"
  fi
done

# Check skill files
for f in "$REPO_DIR"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    echo "ERROR: $f missing YAML frontmatter"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: $f"
  fi
done

# Check .cursor/rules have .mdc extension and frontmatter
for f in "$REPO_DIR"/.cursor/rules/*.mdc; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    echo "ERROR: $f missing YAML frontmatter"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: $f"
  fi
done

# Check JSON files are valid
for f in "$REPO_DIR/.mcp.json" "$REPO_DIR/.claude/settings.json" "$REPO_DIR/.cursor/mcp.json"; do
  [ -f "$f" ] || continue
  if command -v python3 &>/dev/null; then
    if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
      echo "OK: $f (valid JSON)"
    else
      echo "ERROR: $f is not valid JSON"
      ERRORS=$((ERRORS + 1))
    fi
  elif command -v node &>/dev/null; then
    if node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null; then
      echo "OK: $f (valid JSON)"
    else
      echo "ERROR: $f is not valid JSON"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "SKIP: $f (no JSON validator available — install python3 or node)"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# Check AGENTS.md
if [ -f "$REPO_DIR/AGENTS.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/AGENTS.md")
  if [ "$SIZE" -lt 200 ]; then
    echo "WARNING: AGENTS.md is very short ($SIZE bytes)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "OK: AGENTS.md ($SIZE bytes)"
  fi
fi

echo ""
echo "Validation complete: $ERRORS errors, $WARNINGS warnings"
[ "$ERRORS" -eq 0 ] && exit 0 || exit 1
