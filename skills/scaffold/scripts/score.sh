#!/bin/bash
# Cortex — Quantitative Scaffold Scoring
# Produces a 0-100 quality score from four weighted dimensions.
# Inspired by autoresearch's val_bpb: a single comparable number per run.
#
# Dimensions (25 points each, 100 total):
#   1. Format compliance  — YAML frontmatter, valid JSON, correct extensions
#   2. Specificity         — no placeholders, real commands, real frameworks
#   3. Completeness        — all 3 tools covered, required sections present
#   4. Structural quality  — agents have bodies, skills have steps, no duplicates
#
# Usage: score.sh <repo-dir>
# Output: JSON with total score and per-dimension breakdown

REPO_DIR="${1:-.}"

# Accumulators for each dimension (out of 25)
FORMAT_SCORE=0
SPECIFICITY_SCORE=0
COMPLETENESS_SCORE=0
STRUCTURE_SCORE=0

FORMAT_MAX=25
SPECIFICITY_MAX=25
COMPLETENESS_MAX=25
STRUCTURE_MAX=25

# Helper: award points to a dimension variable
# Usage: award FORMAT 5
award() {
  local var="$1_SCORE"
  local pts="$2"
  local current=$(eval echo \$$var)
  local max_var="$1_MAX"
  local max=$(eval echo \$$max_var)
  local new=$((current + pts))
  # Cap at max
  if [ "$new" -gt "$max" ]; then
    new=$max
  fi
  eval "$var=$new"
}

# ─── Dimension 1: Format Compliance (25 pts) ───

# CLAUDE.md has valid markdown with frontmatter-free structure (5 pts)
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/CLAUDE.md" | tr -d ' ')
  if [ "$SIZE" -gt 100 ]; then
    award FORMAT 5
  fi
fi

# Agent files have valid YAML frontmatter (5 pts)
AGENT_OK=true
for f in "$REPO_DIR"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    AGENT_OK=false
  elif ! grep -q '^name:' "$f"; then
    AGENT_OK=false
  elif ! grep -q '^description:' "$f"; then
    AGENT_OK=false
  fi
done
if $AGENT_OK; then
  award FORMAT 5
fi

# Skill files have valid frontmatter (5 pts)
SKILL_OK=true
for f in "$REPO_DIR"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    SKILL_OK=false
  fi
done
if $SKILL_OK; then
  award FORMAT 5
fi

# Cursor rule files have .mdc extension and frontmatter (5 pts)
MDC_OK=true
for f in "$REPO_DIR"/.cursor/rules/*.mdc; do
  [ -f "$f" ] || continue
  if ! head -1 "$f" | grep -q '^---$'; then
    MDC_OK=false
  fi
done
if $MDC_OK; then
  award FORMAT 5
fi

# JSON files are valid (5 pts)
JSON_OK=true
for f in "$REPO_DIR/.mcp.json" "$REPO_DIR/.claude/settings.json" "$REPO_DIR/.cursor/mcp.json"; do
  [ -f "$f" ] || continue
  if command -v python3 &>/dev/null; then
    if ! python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
      JSON_OK=false
    fi
  elif command -v node &>/dev/null; then
    if ! node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null; then
      JSON_OK=false
    fi
  fi
done
if $JSON_OK; then
  award FORMAT 5
fi

# ─── Dimension 2: Specificity (25 pts) ───

# CLAUDE.md has no placeholder text (7 pts)
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  PLACEHOLDERS=$(grep -ciE '\[PROJECT_NAME\]|\{\{framework\}\}|TODO:|Add your .* here|PLACEHOLDER' "$REPO_DIR/CLAUDE.md" 2>/dev/null || true)
  PLACEHOLDERS=${PLACEHOLDERS:-0}
  if [ "$PLACEHOLDERS" -eq 0 ]; then
    award SPECIFICITY 7
  fi
fi

# CLAUDE.md contains code blocks with real commands (6 pts)
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  CMD_BLOCKS=$(grep -c '```' "$REPO_DIR/CLAUDE.md" 2>/dev/null || true)
  CMD_BLOCKS=${CMD_BLOCKS:-0}
  if [ "$CMD_BLOCKS" -ge 2 ]; then
    award SPECIFICITY 6
  fi
fi

# Skills reference actual commands, not generic ones (6 pts)
SKILL_SPECIFIC=true
for f in "$REPO_DIR"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  if grep -qiE 'PLACEHOLDER|TODO:|your-command-here' "$f" 2>/dev/null; then
    SKILL_SPECIFIC=false
  fi
done
if $SKILL_SPECIFIC; then
  award SPECIFICITY 6
fi

# AGENTS.md has no Claude-Code-specific references (6 pts)
if [ -f "$REPO_DIR/AGENTS.md" ]; then
  CLAUDE_REFS=$(grep -ciE 'CLAUDE\.md|\.claude/|claude code' "$REPO_DIR/AGENTS.md" 2>/dev/null || true)
  CLAUDE_REFS=${CLAUDE_REFS:-0}
  if [ "$CLAUDE_REFS" -eq 0 ]; then
    award SPECIFICITY 6
  fi
fi

# ─── Dimension 3: Completeness (25 pts) ───

# Claude Code files exist: CLAUDE.md (5 pts)
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  award COMPLETENESS 5
fi

# Claude Code rules or agents exist (5 pts)
if [ -d "$REPO_DIR/.claude/rules" ] || [ -d "$REPO_DIR/.claude/agents" ]; then
  CLAUDE_FILES=$(find "$REPO_DIR/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CLAUDE_FILES" -gt 0 ]; then
    award COMPLETENESS 5
  fi
fi

# Cursor files exist (5 pts)
if [ -d "$REPO_DIR/.cursor/rules" ]; then
  CURSOR_FILES=$(find "$REPO_DIR/.cursor/rules" -name "*.mdc" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CURSOR_FILES" -gt 0 ]; then
    award COMPLETENESS 5
  fi
fi

# AGENTS.md exists for Codex (5 pts)
if [ -f "$REPO_DIR/AGENTS.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/AGENTS.md" | tr -d ' ')
  if [ "$SIZE" -gt 200 ]; then
    award COMPLETENESS 5
  fi
fi

# CLAUDE.md has at least 3 markdown sections (5 pts)
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  SECTIONS=$(grep -c '^##' "$REPO_DIR/CLAUDE.md" 2>/dev/null || true)
  SECTIONS=${SECTIONS:-0}
  if [ "$SECTIONS" -ge 3 ]; then
    award COMPLETENESS 5
  fi
fi

# ─── Dimension 4: Structural Quality (25 pts) ───

# Agent files have body content after frontmatter (7 pts)
AGENTS_HAVE_BODY=true
for f in "$REPO_DIR"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  # Count lines after second --- delimiter
  BODY_LINES=$(awk '/^---$/{n++; if(n==2){found=1; next}} found{count++} END{print count+0}' "$f")
  if [ "$BODY_LINES" -lt 3 ]; then
    AGENTS_HAVE_BODY=false
  fi
done
if $AGENTS_HAVE_BODY; then
  award STRUCTURE 7
fi

# Skill files have workflow steps (6 pts)
SKILLS_HAVE_STEPS=true
for f in "$REPO_DIR"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  STEP_COUNT=$(grep -ciE '^#{1,3} step|^[0-9]+\.' "$f" 2>/dev/null || echo "0")
  if [ "$STEP_COUNT" -lt 1 ]; then
    SKILLS_HAVE_STEPS=false
  fi
done
if $SKILLS_HAVE_STEPS; then
  award STRUCTURE 6
fi

# No overly short files that suggest incomplete generation (6 pts)
SHORT_FILES=0
for f in "$REPO_DIR"/.claude/agents/*.md "$REPO_DIR"/.claude/rules/*.md "$REPO_DIR"/.cursor/rules/*.mdc; do
  [ -f "$f" ] || continue
  SIZE=$(wc -c < "$f" | tr -d ' ')
  if [ "$SIZE" -lt 50 ]; then
    SHORT_FILES=$((SHORT_FILES + 1))
  fi
done
if [ "$SHORT_FILES" -eq 0 ]; then
  award STRUCTURE 6
fi

# Total generated files is reasonable: not 0, not excessive (6 pts)
TOTAL_FILES=$(find "$REPO_DIR/.claude" "$REPO_DIR/.cursor" -type f 2>/dev/null | wc -l | tr -d ' ')
TOTAL_FILES=$((TOTAL_FILES + $([ -f "$REPO_DIR/CLAUDE.md" ] && echo 1 || echo 0)))
TOTAL_FILES=$((TOTAL_FILES + $([ -f "$REPO_DIR/AGENTS.md" ] && echo 1 || echo 0)))
TOTAL_FILES=$((TOTAL_FILES + $([ -f "$REPO_DIR/.mcp.json" ] && echo 1 || echo 0)))
if [ "$TOTAL_FILES" -ge 3 ] && [ "$TOTAL_FILES" -le 30 ]; then
  award STRUCTURE 6
fi

# ─── Compute Total ───

TOTAL=$((FORMAT_SCORE + SPECIFICITY_SCORE + COMPLETENESS_SCORE + STRUCTURE_SCORE))

# ─── Output as JSON ───

cat <<EOF
{
  "total_score": $TOTAL,
  "max_score": 100,
  "dimensions": {
    "format_compliance": { "score": $FORMAT_SCORE, "max": $FORMAT_MAX },
    "specificity": { "score": $SPECIFICITY_SCORE, "max": $SPECIFICITY_MAX },
    "completeness": { "score": $COMPLETENESS_SCORE, "max": $COMPLETENESS_MAX },
    "structural_quality": { "score": $STRUCTURE_SCORE, "max": $STRUCTURE_MAX }
  },
  "repo_dir": "$REPO_DIR",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
