#!/bin/bash
# Cortex detect-cli-tools — AI agent acceleration tool detector
# Detects installed CLI tools that make AI coding agents faster
# Outputs JSON to stdout for the toolbox-recommender subagent
#
# Usage: ./detect-cli-tools.sh [repo-dir]
#
# Requirements:
#   - bash + Python 3.10+ stdlib (no pip packages)
#   - Works on macOS and Linux
#   - All external commands have 3-second timeouts
#   - Never reads sensitive data — only checks existence
#   - Always exits 0 (failures become empty/false values)

set -uo pipefail

REPO_DIR="${1:-.}"
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

# JSON-safe string escaping — prevents injection from version strings
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

# Timeout wrapper — 3 seconds max per command
safe_run() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 3 "$@" 2>/dev/null
  else
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

# Check a CLI tool: outputs JSON fragment
check_cli() {
  local name="$1"
  local bin="${2:-$name}"
  local esc_name esc_bin
  esc_name=$(json_escape "$name")
  esc_bin=$(json_escape "$bin")
  if safe_run command -v "$bin" >/dev/null 2>&1; then
    local ver_output
    ver_output=$(safe_run "$bin" --version 2>&1 || true)
    local version
    version=$(extract_version "$ver_output")
    if [ -n "$version" ]; then
      local esc_ver
      esc_ver=$(json_escape "$version")
      printf '"%s": {"installed": true, "version": "%s", "binary": "%s"}' "$esc_name" "$esc_ver" "$esc_bin"
    else
      printf '"%s": {"installed": true, "version": null, "binary": "%s"}' "$esc_name" "$esc_bin"
    fi
  else
    printf '"%s": {"installed": false, "version": null, "binary": "%s"}' "$esc_name" "$esc_bin"
  fi
}

# Detect platform
detect_platform() {
  case "$(uname -s)" in
    Darwin*) echo "darwin" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

# Detect primary package manager
detect_pkg_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  else
    echo "none"
  fi
}

# Detect shell and config file
detect_shell() {
  local shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")
  echo "$shell_name"
}

detect_shell_config() {
  local shell_name
  shell_name=$(detect_shell)
  case "$shell_name" in
    zsh)  echo "${HOME}/.zshrc" ;;
    bash)
      if [ -f "${HOME}/.bashrc" ]; then
        echo "${HOME}/.bashrc"
      else
        echo "${HOME}/.bash_profile"
      fi
      ;;
    fish) echo "${HOME}/.config/fish/config.fish" ;;
    *)    echo "${HOME}/.profile" ;;
  esac
}

# Detect repo context (what ecosystems are relevant) — scoped to REPO_DIR only
detect_repo_context() {
  local dir="$1"
  local has_pkg_json=false has_pyproject=false has_go_mod=false has_cargo_toml=false
  local has_tsconfig=false has_requirements=false has_setup_py=false
  [ -n "$(find "$dir" -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ] && has_pkg_json=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'tsconfig.json' -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ] && has_tsconfig=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'pyproject.toml' -print -quit 2>/dev/null)" ] && has_pyproject=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'requirements.txt' -print -quit 2>/dev/null)" ] && has_requirements=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'setup.py' -print -quit 2>/dev/null)" ] && has_setup_py=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'go.mod' -print -quit 2>/dev/null)" ] && has_go_mod=true
  [ -n "$(find "$dir" -maxdepth 3 -name 'Cargo.toml' -print -quit 2>/dev/null)" ] && has_cargo_toml=true
  printf '{"hasPackageJson": %s, "hasTsconfig": %s, "hasPyproject": %s, "hasRequirements": %s, "hasSetupPy": %s, "hasGoMod": %s, "hasCargoToml": %s}' \
    "$has_pkg_json" "$has_tsconfig" "$has_pyproject" "$has_requirements" "$has_setup_py" "$has_go_mod" "$has_cargo_toml"
}

# Detect AI agent config
detect_ai_config() {
  local shell_config
  shell_config=$(detect_shell_config)

  # Check USE_BUILTIN_RIPGREP
  local rg_status="unset"
  if [ -n "${USE_BUILTIN_RIPGREP:-}" ]; then
    rg_status="${USE_BUILTIN_RIPGREP}"
  elif [ -f "$shell_config" ] && grep -q 'USE_BUILTIN_RIPGREP' "$shell_config" 2>/dev/null; then
    rg_status="configured-in-profile"
  fi

  printf '{"useBuiltinRipgrep": "%s"}' "$(json_escape "$rg_status")"
}

# ---------------------------------------------------------------------------
# Build JSON output
# ---------------------------------------------------------------------------

PLATFORM=$(detect_platform)
PKG_MANAGER=$(detect_pkg_manager)
SHELL_NAME=$(detect_shell)
SHELL_CONFIG=$(detect_shell_config)
REPO_CONTEXT=$(detect_repo_context "$REPO_DIR")
AI_CONFIG=$(detect_ai_config)

# Determine which ecosystem categories are relevant — scoped to REPO_DIR
HAS_JS=false
HAS_PY=false
HAS_GO=false
HAS_RUST=false
HAS_DOCKER=false

[ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ] || \
  [ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'tsconfig.json' -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ] && HAS_JS=true
[ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'pyproject.toml' -print -quit 2>/dev/null)" ] || \
  [ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'requirements.txt' -print -quit 2>/dev/null)" ] || \
  [ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'setup.py' -print -quit 2>/dev/null)" ] && HAS_PY=true
[ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'go.mod' -print -quit 2>/dev/null)" ] && HAS_GO=true
[ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'Cargo.toml' -print -quit 2>/dev/null)" ] && HAS_RUST=true
[ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'Dockerfile' -print -quit 2>/dev/null)" ] || \
  [ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'docker-compose.yml' -print -quit 2>/dev/null)" ] || \
  [ -n "$(find "$REPO_DIR" -maxdepth 3 -name 'docker-compose.yaml' -print -quit 2>/dev/null)" ] && HAS_DOCKER=true

# Start JSON
echo "{"
printf '  "platform": "%s",\n' "$(json_escape "$PLATFORM")"
printf '  "packageManager": "%s",\n' "$(json_escape "$PKG_MANAGER")"
printf '  "shell": "%s",\n' "$(json_escape "$SHELL_NAME")"
printf '  "shellConfig": "%s",\n' "$(json_escape "$SHELL_CONFIG")"
printf '  "repoContext": %s,\n' "$REPO_CONTEXT"
printf '  "aiAgentConfig": %s,\n' "$AI_CONFIG"

# --- Category: search (always relevant) ---
echo '  "tools": {'
echo '    "search": {'
printf '      '; check_cli "ripgrep" "rg"; echo ","
printf '      '; check_cli "fd" "fd"; echo ","
printf '      '; check_cli "ast-grep" "sg"; echo ","
printf '      '; check_cli "fzf" "fzf"
echo ""
echo '    },'

# --- Category: git (always relevant) ---
echo '    "git": {'
printf '      '; check_cli "gh" "gh"; echo ","
printf '      '; check_cli "git-delta" "delta"; echo ","
printf '      '; check_cli "glab" "glab"; echo ","
printf '      '; check_cli "lazygit" "lazygit"
echo ""
echo '    },'

# --- Category: shell (always relevant) ---
echo '    "shell": {'
printf '      '; check_cli "shellcheck" "shellcheck"; echo ","
printf '      '; check_cli "direnv" "direnv"; echo ","
printf '      '; check_cli "bat" "bat"; echo ","
printf '      '; check_cli "eza" "eza"; echo ","
printf '      '; check_cli "zoxide" "zoxide"; echo ","
printf '      '; check_cli "starship" "starship"
echo ""
echo '    },'

# --- Category: json-data (always relevant) ---
echo '    "json-data": {'
printf '      '; check_cli "jq" "jq"; echo ","
printf '      '; check_cli "yq" "yq"; echo ","
printf '      '; check_cli "fx" "fx"
echo ""
echo '    },'

# --- Category: code-metrics (always relevant) ---
echo '    "code-metrics": {'
printf '      '; check_cli "tokei" "tokei"; echo ","
printf '      '; check_cli "scc" "scc"; echo ","
printf '      '; check_cli "cloc" "cloc"
echo ""
echo '    },'

# --- Category: js-ecosystem (conditional) ---
echo '    "js-ecosystem": {'
if [ "$HAS_JS" = true ]; then
  printf '      '; check_cli "eslint" "eslint"; echo ","
  printf '      '; check_cli "prettier" "prettier"; echo ","
  printf '      '; check_cli "biome" "biome"; echo ","
  printf '      '; check_cli "oxlint" "oxlint"; echo ","
  printf '      '; check_cli "tsc" "tsc"; echo ","
  printf '      '; check_cli "tsx" "tsx"; echo ","
  printf '      '; check_cli "turbo" "turbo"; echo ","
  printf '      '; check_cli "nx" "nx"; echo ","
  printf '      '; check_cli "bun" "bun"; echo ","
  printf '      '; check_cli "deno" "deno"
else
  printf '      "_skipped": true, "_reason": "no JS/TS project detected"'
fi
echo ""
echo '    },'

# --- Category: python-ecosystem (conditional) ---
echo '    "python-ecosystem": {'
if [ "$HAS_PY" = true ]; then
  printf '      '; check_cli "ruff" "ruff"; echo ","
  printf '      '; check_cli "uv" "uv"; echo ","
  printf '      '; check_cli "mypy" "mypy"; echo ","
  printf '      '; check_cli "pyright" "pyright"; echo ","
  printf '      '; check_cli "black" "black"; echo ","
  printf '      '; check_cli "isort" "isort"; echo ","
  printf '      '; check_cli "pipx" "pipx"
else
  printf '      "_skipped": true, "_reason": "no Python project detected"'
fi
echo ""
echo '    },'

# --- Category: go-ecosystem (conditional) ---
echo '    "go-ecosystem": {'
if [ "$HAS_GO" = true ]; then
  printf '      '; check_cli "golangci-lint" "golangci-lint"; echo ","
  printf '      '; check_cli "staticcheck" "staticcheck"; echo ","
  printf '      '; check_cli "gopls" "gopls"
else
  printf '      "_skipped": true, "_reason": "no Go project detected"'
fi
echo ""
echo '    },'

# --- Category: rust-ecosystem (conditional) ---
echo '    "rust-ecosystem": {'
if [ "$HAS_RUST" = true ]; then
  printf '      '; check_cli "cargo-watch" "cargo-watch"; echo ","
  printf '      '; check_cli "cargo-nextest" "cargo-nextest"; echo ","
  printf '      '; check_cli "cargo-expand" "cargo-expand"
  # clippy is checked via rustup
  echo ","
  if safe_run rustup component list 2>/dev/null | grep -q 'clippy.*installed'; then
    printf '      "clippy": {"installed": true, "version": null, "binary": "cargo-clippy"}'
  else
    printf '      "clippy": {"installed": false, "version": null, "binary": "cargo-clippy"}'
  fi
else
  printf '      "_skipped": true, "_reason": "no Rust project detected"'
fi
echo ""
echo '    },'

# --- Category: performance (always available) ---
echo '    "performance": {'
printf '      '; check_cli "hyperfine" "hyperfine"; echo ","
printf '      '; check_cli "dust" "dust"; echo ","
printf '      '; check_cli "duf" "duf"; echo ","
printf '      '; check_cli "procs" "procs"; echo ","
printf '      '; check_cli "bottom" "btm"
echo ""
echo '    },'

# --- Category: container (conditional) ---
echo '    "container": {'
if [ "$HAS_DOCKER" = true ] || command -v docker >/dev/null 2>&1 || command -v kubectl >/dev/null 2>&1; then
  printf '      '; check_cli "docker" "docker"; echo ","
  printf '      '; check_cli "lazydocker" "lazydocker"; echo ","
  printf '      '; check_cli "dive" "dive"; echo ","
  printf '      '; check_cli "ctop" "ctop"; echo ","
  printf '      '; check_cli "kubectl" "kubectl"; echo ","
  printf '      '; check_cli "k9s" "k9s"
else
  printf '      "_skipped": true, "_reason": "no container/k8s signals detected"'
fi
echo ""
echo '    }'

echo '  },'

# --- Summary ---
# Count installed and missing tools using the JSON we just built
# (lightweight: just count check_cli calls that returned installed: true)
INSTALLED=0
MISSING=0

for cmd in rg fd sg fzf gh delta glab lazygit shellcheck direnv bat eza zoxide starship jq yq fx tokei scc cloc hyperfine dust duf procs btm; do
  if safe_run command -v "$cmd" >/dev/null 2>&1; then
    INSTALLED=$((INSTALLED + 1))
  else
    MISSING=$((MISSING + 1))
  fi
done

# Ecosystem-specific counts
if [ "$HAS_JS" = true ]; then
  for cmd in eslint prettier biome oxlint tsc tsx turbo nx bun deno; do
    if safe_run command -v "$cmd" >/dev/null 2>&1; then
      INSTALLED=$((INSTALLED + 1))
    else
      MISSING=$((MISSING + 1))
    fi
  done
fi

if [ "$HAS_PY" = true ]; then
  for cmd in ruff uv mypy pyright black isort pipx; do
    if safe_run command -v "$cmd" >/dev/null 2>&1; then
      INSTALLED=$((INSTALLED + 1))
    else
      MISSING=$((MISSING + 1))
    fi
  done
fi

if [ "$HAS_GO" = true ]; then
  for cmd in golangci-lint staticcheck gopls; do
    if safe_run command -v "$cmd" >/dev/null 2>&1; then
      INSTALLED=$((INSTALLED + 1))
    else
      MISSING=$((MISSING + 1))
    fi
  done
fi

if [ "$HAS_RUST" = true ]; then
  for cmd in cargo-watch cargo-nextest cargo-expand; do
    if safe_run command -v "$cmd" >/dev/null 2>&1; then
      INSTALLED=$((INSTALLED + 1))
    else
      MISSING=$((MISSING + 1))
    fi
  done
fi

if [ "$HAS_DOCKER" = true ] || command -v docker >/dev/null 2>&1 || command -v kubectl >/dev/null 2>&1; then
  for cmd in docker lazydocker dive ctop kubectl k9s; do
    if safe_run command -v "$cmd" >/dev/null 2>&1; then
      INSTALLED=$((INSTALLED + 1))
    else
      MISSING=$((MISSING + 1))
    fi
  done
fi

echo '  "summary": {'
printf '    "installed": %d,\n' "$INSTALLED"
printf '    "missing": %d\n' "$MISSING"
echo '  }'

echo "}"

exit 0
