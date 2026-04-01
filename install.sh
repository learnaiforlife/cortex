#!/bin/bash
# Cortex — Install as Claude Code skill
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/scaffold"

echo "=== Installing Cortex ==="
echo ""

# Install skill
mkdir -p "$SKILL_DIR"
cp -r "$SCRIPT_DIR/skills/scaffold/"* "$SKILL_DIR/"

# Make scripts executable
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null || true

echo "Done! Cortex is installed."
echo ""
echo "Usage in Claude Code:"
echo "  /scaffold                                    # scaffold current directory"
echo "  /scaffold https://github.com/org/repo        # scaffold any GitHub repo"
echo "  /scaffold audit                              # audit existing AI setup"
echo "  /scaffold optimize                           # optimize existing skills"
