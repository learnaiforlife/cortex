#!/bin/bash
# Cortex — Install as Claude Code plugin
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/scaffold"
COMMANDS_DIR="$HOME/.claude/commands"

echo "=== Installing Cortex ==="
echo ""

# Install skill + agents + references + scripts + evals
echo "Installing skill..."
mkdir -p "$SKILL_DIR"
cp -r "$SCRIPT_DIR/skills/scaffold/"* "$SKILL_DIR/"
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null || true

# Install commands (/scaffold, /scaffold-audit, /scaffold-optimize)
echo "Installing commands..."
mkdir -p "$COMMANDS_DIR"
cp "$SCRIPT_DIR/commands/"*.md "$COMMANDS_DIR/"

# Install hooks (merge into settings if possible, otherwise inform user)
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  # Check if hooks already exist — don't overwrite user's existing hooks
  if grep -q '"SessionStart"' "$SETTINGS_FILE" 2>/dev/null; then
    echo "Hooks: SessionStart hook already exists in settings.json, skipping"
  else
    echo "Hooks: To enable the auto-suggest hook, add the contents of hooks/hooks.json to $SETTINGS_FILE"
  fi
else
  echo "Hooks: Copy hooks/hooks.json content into $SETTINGS_FILE to enable auto-suggest"
fi

echo ""
echo "=== Cortex installed ==="
echo ""
echo "Usage in Claude Code:"
echo "  /scaffold                                    # scaffold current directory"
echo "  /scaffold https://github.com/org/repo        # scaffold any GitHub repo"
echo "  /scaffold audit                              # audit existing AI setup"
echo "  /scaffold optimize                           # optimize existing skills"
