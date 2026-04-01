#!/bin/bash
# Cortex discover-tools — machine-wide developer environment discovery
# Detects installed CLIs, IDEs, package managers, and auth status
# Outputs a JSON profile to stdout for the Cortex intelligence layer
#
# Usage: ./discover-tools.sh
#
# Requirements:
#   - bash + Python 3.10+ stdlib (no pip packages)
#   - Works on macOS and Linux
#   - All external commands have 3-second timeouts
#   - Never reads sensitive data — only checks existence
#   - Always exits 0 (failures become empty/false values)

set -uo pipefail

# Timeout wrapper — 3 seconds max per command
safe_run() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 3 "$@" 2>/dev/null
  else
    # macOS: use perl as fallback (coreutils timeout not always available)
    perl -e '
      eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm 3;
        exec @ARGV;
      };
      exit 124 if $@ eq "alarm\n";
    ' -- "$@" 2>/dev/null
  fi
}

# Extract version string from --version output (first semver-like match)
extract_version() {
  local output="$1"
  echo "$output" | head -5 | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.search(r'(\d+\.\d+[\.\d]*)', line)
    if m:
        print(m.group(1))
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# Check a CLI tool: outputs  "name": {"installed": bool, "version": "X.Y.Z" or null}
check_cli() {
  local name="$1"
  local bin="${2:-$name}"
  if safe_run command -v "$bin" >/dev/null 2>&1; then
    local ver_output
    ver_output=$(safe_run "$bin" --version 2>&1 || true)
    local version
    version=$(extract_version "$ver_output")
    if [ -n "$version" ]; then
      printf '    "%s": {"installed": true, "version": "%s"}' "$name" "$version"
    else
      printf '    "%s": {"installed": true, "version": null}' "$name"
    fi
  else
    printf '    "%s": {"installed": false, "version": null}' "$name"
  fi
}

# ---------------------------------------------------------------------------
# Begin JSON output
# ---------------------------------------------------------------------------

echo "{"

# --- CLIs ---
echo '  "clis": {'
CLIS="docker kubectl terraform aws gcloud az gh glab jira-cli linear vercel netlify fly supabase firebase heroku pulumi helm ansible"
FIRST=true
for cli in $CLIS; do
  [ "$FIRST" = true ] && FIRST=false || echo ","
  # Map tool names to binary names where they differ
  case "$cli" in
    jira-cli) check_cli "$cli" "jira" ;;
    linear)   check_cli "$cli" "linear" ;;
    *)        check_cli "$cli" "$cli" ;;
  esac
done
echo ""
echo '  },'

# --- IDEs ---
echo '  "ides": {'

# VS Code
VSCODE_INSTALLED=false
VSCODE_EXT="null"
if safe_run command -v code >/dev/null 2>&1; then
  VSCODE_INSTALLED=true
  ext_count=$(safe_run code --list-extensions 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$ext_count" ] && [ "$ext_count" -gt 0 ] 2>/dev/null && VSCODE_EXT="$ext_count"
fi
printf '    "vscode": {"installed": %s, "extensionCount": %s},\n' "$VSCODE_INSTALLED" "$VSCODE_EXT"

# Cursor
CURSOR_INSTALLED=false
CURSOR_EXT="null"
if safe_run command -v cursor >/dev/null 2>&1; then
  CURSOR_INSTALLED=true
elif [ -d "/Applications/Cursor.app" ]; then
  CURSOR_INSTALLED=true
fi
printf '    "cursor": {"installed": %s, "extensionCount": %s},\n' "$CURSOR_INSTALLED" "$CURSOR_EXT"

# JetBrains (check common IDEs)
JETBRAINS_INSTALLED=false
if ls /Applications/IntelliJ*.app 1>/dev/null 2>&1 || \
   ls /Applications/WebStorm.app 1>/dev/null 2>&1 || \
   ls /Applications/PyCharm*.app 1>/dev/null 2>&1 || \
   ls /Applications/GoLand.app 1>/dev/null 2>&1 || \
   ls /Applications/Rider.app 1>/dev/null 2>&1 || \
   ls /Applications/CLion.app 1>/dev/null 2>&1 || \
   safe_run command -v idea >/dev/null 2>&1 || \
   safe_run command -v webstorm >/dev/null 2>&1 || \
   safe_run command -v pycharm >/dev/null 2>&1; then
  JETBRAINS_INSTALLED=true
fi
printf '    "jetbrains": {"installed": %s, "extensionCount": null}\n' "$JETBRAINS_INSTALLED"

echo '  },'

# --- Package Managers ---
echo '  "packageManagers": {'
PKG_MANAGERS="npm yarn pnpm pip pip3 poetry cargo go ruby bundle composer mvn gradle"
FIRST=true
for pm in $PKG_MANAGERS; do
  [ "$FIRST" = true ] && FIRST=false || echo ","
  # Use the display name from spec (mvn → maven)
  display_name="$pm"
  [ "$pm" = "mvn" ] && display_name="maven"
  if safe_run command -v "$pm" >/dev/null 2>&1; then
    printf '    "%s": true' "$display_name"
  else
    printf '    "%s": false' "$display_name"
  fi
done
echo ""
echo '  },'

# --- Auth Status ---
echo '  "auth": {'

# GitHub
GH_AUTH=false
if safe_run command -v gh >/dev/null 2>&1; then
  if safe_run gh auth status >/dev/null 2>&1; then
    GH_AUTH=true
  fi
fi
printf '    "github": {"authenticated": %s},\n' "$GH_AUTH"

# GitLab
GL_AUTH=false
if safe_run command -v glab >/dev/null 2>&1; then
  if safe_run glab auth status >/dev/null 2>&1; then
    GL_AUTH=true
  fi
fi
printf '    "gitlab": {"authenticated": %s}\n' "$GL_AUTH"

echo '  }'

echo "}"

exit 0
