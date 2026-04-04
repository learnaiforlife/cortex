#!/bin/bash
# Cortex — Install as Claude Code plugin
# Safe to re-run: backs up previous installation before overwriting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/scaffold"
COMMANDS_DIR="$HOME/.claude/commands"
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")

echo "=== Installing Cortex v$VERSION ==="
echo ""

# Backup existing installation if present.
# Each run creates a timestamped backup so nothing is ever silently lost.
if [ -d "$SKILL_DIR" ]; then
  BACKUP_DIR="$HOME/.cortex/backups/scaffold-$(date +%Y%m%d-%H%M%S)"
  echo "Backing up existing installation to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR/skill"
  mkdir -p "$BACKUP_DIR/commands"
  cp -r "$SKILL_DIR" "$BACKUP_DIR/skill/" 2>/dev/null || true
  # Backup all scaffold commands (must match the set installed below)
  for cmd in scaffold.md scaffold-audit.md scaffold-optimize.md scaffold-discover.md scaffold-toolbox.md scaffold-migrate.md; do
    [ -f "$COMMANDS_DIR/$cmd" ] && cp "$COMMANDS_DIR/$cmd" "$BACKUP_DIR/commands/" 2>/dev/null || true
  done
  echo "  Backup complete."
  echo "  Restore skill:    cp -r $BACKUP_DIR/skill/scaffold/* $SKILL_DIR/"
  echo "  Restore commands: cp $BACKUP_DIR/commands/*.md $COMMANDS_DIR/"
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

# Install commands (all scaffold-*.md files from commands/)
echo "Installing commands..."
mkdir -p "$COMMANDS_DIR"
cp "$SCRIPT_DIR/commands/"*.md "$COMMANDS_DIR/"
echo "  Commands:   $(find "$COMMANDS_DIR" -maxdepth 1 -name "scaffold*.md" -type f 2>/dev/null | wc -l | tr -d ' ') commands"

# Create cortex data directory
mkdir -p "$HOME/.cortex/logs"

# Hook guidance.
# Hooks are NOT installed automatically — they require manual setup because
# they modify Claude Code's global settings.json, and auto-merging JSON is
# fragile and risky (could corrupt existing hooks or settings).
SETTINGS_FILE="$HOME/.claude/settings.json"
echo "Hooks (manual setup required):"
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q '"SessionStart"' "$SETTINGS_FILE" 2>/dev/null; then
    echo "  SessionStart hook already present in $SETTINGS_FILE — no action needed."
  else
    echo "  To enable session-start tips, manually merge hooks/hooks.json into:"
    echo "    $SETTINGS_FILE"
    echo "  See hooks/hooks.json for the JSON to add."
  fi
else
  echo "  No settings.json found. To enable session-start tips:"
  echo "    1. Create $SETTINGS_FILE"
  echo "    2. Merge the contents of hooks/hooks.json into it"
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
echo "  /scaffold migrate                            # migration workflow"
echo "  /scaffold-toolbox                            # detect & recommend CLI tools"
echo "  /scaffold-toolbox install                    # install recommended CLI tools"
echo "  /scaffold-toolbox configure                  # set AI agent env vars"
echo ""
echo "Shell env config (optional):"
echo "  bash ~/.claude/skills/scaffold/templates/ai-agent-config.sh"
echo "  # Preview output, then append with --append (idempotent, safe to re-run)"
echo ""
echo "Scheduling (auto-improve & re-discover):"
echo "  bash ~/.claude/skills/scaffold/scripts/schedule-autorun.sh setup"
echo "  bash ~/.claude/skills/scaffold/scripts/schedule-autorun.sh status"
