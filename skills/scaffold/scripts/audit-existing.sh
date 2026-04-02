#!/bin/bash
# Quick scan of existing AI setup files
# Outputs a JSON summary of what exists

set -euo pipefail

REPO_DIR="${1:-.}"

echo "{"
echo "  \"claude_code\": {"

# CLAUDE.md
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/CLAUDE.md")
  echo "    \"claude_md\": { \"exists\": true, \"size\": $SIZE },"
else
  echo "    \"claude_md\": { \"exists\": false },"
fi

# Agents
AGENT_COUNT=$(find "$REPO_DIR/.claude/agents" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "    \"agents\": $AGENT_COUNT,"

# Skills
SKILL_COUNT=$(find "$REPO_DIR/.claude/skills" -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "    \"skills\": $SKILL_COUNT,"

# Rules
RULE_COUNT=$(find "$REPO_DIR/.claude/rules" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "    \"rules\": $RULE_COUNT,"

# Settings
if [ -f "$REPO_DIR/.claude/settings.json" ]; then
  echo "    \"settings\": true,"
else
  echo "    \"settings\": false,"
fi

# MCP
if [ -f "$REPO_DIR/.mcp.json" ]; then
  echo "    \"mcp\": true"
else
  echo "    \"mcp\": false"
fi
echo "  },"

echo "  \"cursor\": {"
CURSOR_RULE_COUNT=$(find "$REPO_DIR/.cursor/rules" -maxdepth 1 -name "*.mdc" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "    \"rules\": $CURSOR_RULE_COUNT,"
if [ -f "$REPO_DIR/.cursor/mcp.json" ]; then
  echo "    \"mcp\": true"
else
  echo "    \"mcp\": false"
fi
echo "  },"

echo "  \"codex\": {"
if [ -f "$REPO_DIR/AGENTS.md" ]; then
  SIZE=$(wc -c < "$REPO_DIR/AGENTS.md")
  echo "    \"agents_md\": { \"exists\": true, \"size\": $SIZE }"
else
  echo "    \"agents_md\": { \"exists\": false }"
fi
echo "  }"

echo "}"
