#!/bin/bash
# Quick scan of existing AI setup files
# Outputs a JSON summary of what exists

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
AGENT_COUNT=$(ls "$REPO_DIR"/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "    \"agents\": $AGENT_COUNT,"

# Skills
SKILL_COUNT=$(ls "$REPO_DIR"/.claude/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
echo "    \"skills\": $SKILL_COUNT,"

# Rules
RULE_COUNT=$(ls "$REPO_DIR"/.claude/rules/*.md 2>/dev/null | wc -l | tr -d ' ')
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
CURSOR_RULE_COUNT=$(ls "$REPO_DIR"/.cursor/rules/*.mdc 2>/dev/null | wc -l | tr -d ' ')
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
