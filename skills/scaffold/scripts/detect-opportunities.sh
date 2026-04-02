#!/bin/bash
# Cortex opportunity detector
# Scans repo + environment for subagent, skill, and integration opportunities
# Outputs OpportunitySignals JSON
#
# Usage: detect-opportunities.sh <repo-dir>

set -uo pipefail

REPO_DIR="${1:-.}"

# --- Subagent signals ---
detect_test_framework() {
  local found=""
  [ -f "$REPO_DIR/jest.config.js" ] || [ -f "$REPO_DIR/jest.config.ts" ] && found="jest"
  [ -f "$REPO_DIR/vitest.config.ts" ] || [ -f "$REPO_DIR/vitest.config.js" ] && found="vitest"
  [ -f "$REPO_DIR/pytest.ini" ] || [ -f "$REPO_DIR/conftest.py" ] || [ -f "$REPO_DIR/setup.cfg" ] && found="pytest"
  [ -z "$found" ] && [ -f "$REPO_DIR/tests/conftest.py" ] && found="pytest"
  [ -z "$found" ] && [ -f "$REPO_DIR/test/conftest.py" ] && found="pytest"
  if [ -z "$found" ] && [ -f "$REPO_DIR/pyproject.toml" ]; then
    grep -qE '\[tool\.pytest' "$REPO_DIR/pyproject.toml" 2>/dev/null && found="pytest"
  fi
  [ -f "$REPO_DIR/go.mod" ] && [ -z "$found" ] && found="go-test"
  [ -f "$REPO_DIR/Cargo.toml" ] && [ -z "$found" ] && found="cargo-test"
  if [ -f "$REPO_DIR/package.json" ]; then
    grep -qE '"(jest|vitest|mocha|ava)"' "$REPO_DIR/package.json" 2>/dev/null && [ -z "$found" ] && found="package-dep"
  fi
  echo "$found"
}

detect_linter() {
  local found=""
  for f in .eslintrc.js .eslintrc.json eslint.config.js eslint.config.mjs biome.json ruff.toml .golangci.yml; do
    [ -f "$REPO_DIR/$f" ] && found="$f" && break
  done
  if [ -z "$found" ] && [ -f "$REPO_DIR/pyproject.toml" ]; then
    grep -qE '\[tool\.ruff' "$REPO_DIR/pyproject.toml" 2>/dev/null && found="pyproject-ruff"
  fi
  echo "$found"
}

detect_build_tool() {
  local found=""
  for f in next.config.js next.config.ts next.config.mjs vite.config.ts vite.config.js webpack.config.js; do
    [ -f "$REPO_DIR/$f" ] && found="$f" && break
  done
  [ -f "$REPO_DIR/Cargo.toml" ] && [ -z "$found" ] && found="cargo"
  [ -f "$REPO_DIR/go.mod" ] && [ -z "$found" ] && found="go"
  echo "$found"
}

detect_git_activity() {
  if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

detect_source_file_count() {
  find "$REPO_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" -not -path "*/dist/*" 2>/dev/null | wc -l | tr -d ' '
}

detect_ci() {
  local found=""
  [ -d "$REPO_DIR/.github/workflows" ] && found="github-actions"
  [ -f "$REPO_DIR/.gitlab-ci.yml" ] && found="gitlab-ci"
  [ -f "$REPO_DIR/Jenkinsfile" ] && found="jenkins"
  echo "$found"
}

# --- Integration signals ---
detect_jira() {
  local score=0
  [ -d "$HOME/.jira.d" ] && score=$((score + 30))
  [ -n "${JIRA_API_TOKEN:-}" ] && score=$((score + 40))
  [ -n "${JIRA_URL:-}" ] && score=$((score + 30))
  command -v jira &>/dev/null && score=$((score + 20))
  if [ -d "$REPO_DIR/.git" ]; then
    local jira_branches
    jira_branches=$(git -C "$REPO_DIR" branch -a 2>/dev/null | grep -cE '[A-Z]+-[0-9]+' || true)
    [ "$jira_branches" -gt 0 ] && score=$((score + 20))
  fi
  echo "$score"
}

detect_confluence() {
  local score=0
  [ -d "$HOME/.atlassian" ] && score=$((score + 30))
  [ -n "${CONFLUENCE_TOKEN:-}" ] && score=$((score + 40))
  [ -n "${CONFLUENCE_URL:-}" ] && score=$((score + 30))
  local jira_score
  jira_score=$(detect_jira)
  [ "$jira_score" -ge 30 ] && score=$((score + 15))
  echo "$score"
}

detect_slack() {
  local score=0
  [ -n "${SLACK_BOT_TOKEN:-}" ] && score=$((score + 40))
  [ -n "${SLACK_WEBHOOK_URL:-}" ] && score=$((score + 30))
  [ -d "/Applications/Slack.app" ] && score=$((score + 20))
  if [ -f "$REPO_DIR/package.json" ]; then
    grep -qE '@slack/' "$REPO_DIR/package.json" 2>/dev/null && score=$((score + 30))
  fi
  echo "$score"
}

detect_linear() {
  local score=0
  [ -n "${LINEAR_API_KEY:-}" ] && score=$((score + 50))
  command -v linear &>/dev/null && score=$((score + 30))
  if [ -d "$REPO_DIR/.git" ]; then
    local linear_branches
    linear_branches=$(git -C "$REPO_DIR" branch -a 2>/dev/null | grep -cE '(LIN|ENG|PROJ)-[0-9]+' || true)
    [ "$linear_branches" -gt 0 ] && score=$((score + 20))
  fi
  echo "$score"
}

detect_notion() {
  local score=0
  [ -n "${NOTION_API_KEY:-}" ] && score=$((score + 50))
  [ -n "${NOTION_TOKEN:-}" ] && score=$((score + 40))
  if [ -f "$REPO_DIR/README.md" ]; then
    grep -qi "notion" "$REPO_DIR/README.md" 2>/dev/null && score=$((score + 15))
  fi
  echo "$score"
}

detect_sentry() {
  local score=0
  [ -n "${SENTRY_DSN:-}" ] && score=$((score + 40))
  [ -n "${SENTRY_AUTH_TOKEN:-}" ] && score=$((score + 30))
  if [ -f "$REPO_DIR/package.json" ]; then
    grep -qE '@sentry/' "$REPO_DIR/package.json" 2>/dev/null && score=$((score + 30))
  fi
  echo "$score"
}

detect_datadog() {
  local score=0
  [ -n "${DD_API_KEY:-}" ] && score=$((score + 40))
  command -v datadog-ci &>/dev/null && score=$((score + 30))
  if [ -f "$REPO_DIR/package.json" ]; then
    grep -qE 'dd-trace|datadog' "$REPO_DIR/package.json" 2>/dev/null && score=$((score + 30))
  fi
  echo "$score"
}

detect_github() {
  local score=0
  [ -n "${GITHUB_TOKEN:-}" ] && score=$((score + 40))
  [ -d "$REPO_DIR/.github" ] && score=$((score + 30))
  command -v gh &>/dev/null && gh auth status &>/dev/null && score=$((score + 30))
  echo "$score"
}

detect_gitlab() {
  local score=0
  [ -n "${GITLAB_TOKEN:-}" ] && score=$((score + 40))
  [ -f "$REPO_DIR/.gitlab-ci.yml" ] && score=$((score + 40))
  command -v glab &>/dev/null && glab auth status &>/dev/null 2>&1 && score=$((score + 20))
  echo "$score"
}

detect_pagerduty() {
  local score=0
  [ -n "${PAGERDUTY_TOKEN:-}" ] && score=$((score + 50))
  if [ -f "$REPO_DIR/package.json" ]; then
    grep -qE '@pagerduty/pdjs' "$REPO_DIR/package.json" 2>/dev/null && score=$((score + 30))
  fi
  echo "$score"
}

# --- Soft skill signals ---
has_docs() {
  [ -f "$REPO_DIR/README.md" ] || [ -d "$REPO_DIR/docs" ]
}

has_complex_domain() {
  if [ -f "$REPO_DIR/README.md" ]; then
    grep -qiE '(financial|trading|healthcare|payment|security|compliance|regulatory|banking)' "$REPO_DIR/README.md" 2>/dev/null
  else
    return 1
  fi
}

is_medium_plus() {
  local count
  count=$(detect_source_file_count)
  [ "$count" -ge 30 ]
}

# --- Output JSON ---
TEST_FW=$(detect_test_framework)
LINTER=$(detect_linter)
BUILD_TOOL=$(detect_build_tool)
GIT_COMMITS=$(detect_git_activity)
SRC_COUNT=$(detect_source_file_count)
CI_SYSTEM=$(detect_ci)

JIRA_SCORE=$(detect_jira)
CONFLUENCE_SCORE=$(detect_confluence)
SLACK_SCORE=$(detect_slack)
LINEAR_SCORE=$(detect_linear)
NOTION_SCORE=$(detect_notion)
SENTRY_SCORE=$(detect_sentry)
DATADOG_SCORE=$(detect_datadog)
GITHUB_SCORE=$(detect_github)
GITLAB_SCORE=$(detect_gitlab)
PAGERDUTY_SCORE=$(detect_pagerduty)

cat <<ENDJSON
{
  "subagentSignals": {
    "testFramework": "$TEST_FW",
    "linter": "$LINTER",
    "buildTool": "$BUILD_TOOL",
    "gitCommits": $GIT_COMMITS,
    "sourceFileCount": $SRC_COUNT,
    "ciSystem": "$CI_SYSTEM"
  },
  "integrationScores": {
    "jira": $JIRA_SCORE,
    "confluence": $CONFLUENCE_SCORE,
    "slack": $SLACK_SCORE,
    "linear": $LINEAR_SCORE,
    "notion": $NOTION_SCORE,
    "sentry": $SENTRY_SCORE,
    "datadog": $DATADOG_SCORE,
    "github": $GITHUB_SCORE,
    "gitlab": $GITLAB_SCORE,
    "pagerduty": $PAGERDUTY_SCORE
  },
  "softSkillSignals": {
    "hasDocs": $(has_docs && echo "true" || echo "false"),
    "hasComplexDomain": $(has_complex_domain && echo "true" || echo "false"),
    "isMediumPlus": $(is_medium_plus && echo "true" || echo "false")
  }
}
ENDJSON
