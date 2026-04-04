#!/bin/bash
# Cortex — Install as Claude Code plugin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/scaffold"
COMMANDS_DIR="$HOME/.claude/commands"
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")

echo "=== Installing Cortex v$VERSION ==="
echo ""

# Backup existing installation if present
if [ -d "$SKILL_DIR" ]; then
  BACKUP_DIR="$HOME/.cortex/backups/scaffold-$(date +%Y%m%d-%H%M%S)"
  echo "Backing up existing installation to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -r "$SKILL_DIR" "$BACKUP_DIR/" 2>/dev/null || true
  # Also backup commands
  for cmd in scaffold.md scaffold-audit.md scaffold-optimize.md scaffold-discover.md scaffold-toolbox.md; do
    [ -f "$COMMANDS_DIR/$cmd" ] && cp "$COMMANDS_DIR/$cmd" "$BACKUP_DIR/" 2>/dev/null || true
  done
  echo "  Backup complete. Restore with: cp -r $BACKUP_DIR/scaffold/* $SKILL_DIR/"
  echo ""
fi

# Install skill + agents + references + scripts + evals + variants
echo "Installing skill..."
mkdir -p "$SKILL_DIR"
mkdir -p "$SKILL_DIR/variants"
cp -r "$SCRIPT_DIR/skills/scaffold/"* "$SKILL_DIR/"
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null || true

echo "  Agents:     $(find "$SKILL_DIR/agents" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') agents"
echo "  Scripts:    $(find "$SKILL_DIR/scripts" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ') scripts"
echo "  References: $(find "$SKILL_DIR/references" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') reference docs"
echo "  Variants:   $(find "$SKILL_DIR/variants" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') skill variants"

# Install commands (/scaffold, /scaffold-audit, /scaffold-optimize, /scaffold-discover)
echo "Installing commands..."
mkdir -p "$COMMANDS_DIR"
cp "$SCRIPT_DIR/commands/"*.md "$COMMANDS_DIR/"
echo "  Commands:   $(find "$COMMANDS_DIR" -maxdepth 1 -name "scaffold*.md" -type f 2>/dev/null | wc -l | tr -d ' ') commands"

# Create cortex data directory
mkdir -p "$HOME/.cortex/logs"

# Install hooks (merge into settings if possible, otherwise inform user)
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
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
echo "  /scaffold discover                           # discover & setup all projects"
echo "  /scaffold discover ~/work ~/personal         # discover custom directories"
echo "  /scaffold-toolbox                              # detect & recommend CLI tools"
echo "  /scaffold-toolbox install                      # install recommended CLI tools"
echo "  /scaffold-toolbox configure                    # set AI agent env vars"
echo ""
echo "Scheduling (auto-improve & re-discover):"
echo "  bash ~/.claude/skills/scaffold/scripts/schedule-autorun.sh setup"
echo "  bash ~/.claude/skills/scaffold/scripts/schedule-autorun.sh status"
