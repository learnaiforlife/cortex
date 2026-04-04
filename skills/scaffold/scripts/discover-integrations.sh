#!/bin/bash
# Cortex integration discovery engine
# Detects productivity tool integrations (Jira, Slack, GitHub, Sentry, etc.)
# by checking for config files, environment variables, and installed CLIs.
# Outputs JSON to stdout.
#
# PRIVACY GUARANTEES:
#   - Only checks EXISTENCE of environment variables, NEVER reads their values
#   - Only checks if config files/directories exist, NEVER reads their contents
#   - Signal descriptions are generic ("JIRA_API_TOKEN env var set"), never actual values
#
# Usage: ./discover-integrations.sh
# Dependencies: bash, python3 (3.10+ stdlib only)
# Platforms: macOS, Linux
# Exit code: always 0

set -uo pipefail

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslashes first
  s="${s//\"/\\\"}"    # double quotes
  s="${s//$'\t'/\\t}"  # tabs
  s="${s//$'\n'/\\n}"  # newlines
  s="${s//$'\r'/\\r}"  # carriage returns
  printf '%s' "$s"
}

# ── Helper: timeout command (macOS compatibility) ────────────────────────────
safe_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" 2>/dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@" 2>/dev/null
  else
    # Fallback: run without timeout
    "$@" 2>/dev/null
  fi
}

# ── Helper: collect signals for a single integration ──────────────────────────

signals_json() {
  local first=true
  printf "["
  for sig in "$@"; do
    [ "$first" = true ] && first=false || printf ", "
    printf '"%s"' "$(json_escape "$sig")"
  done
  printf "]"
}

# ── Jira ──────────────────────────────────────────────────────────────────────

jira_signals=()
[ -d "$HOME/.jira.d" ]            && jira_signals+=(".jira.d config directory exists")
[ -n "${JIRA_API_TOKEN:-}" ]      && jira_signals+=("JIRA_API_TOKEN env var set")
[ -n "${JIRA_URL:-}" ]            && jira_signals+=("JIRA_URL env var set")
command -v jira >/dev/null 2>&1        && jira_signals+=("jira CLI installed")

# ── Confluence ────────────────────────────────────────────────────────────────

confluence_signals=()
[ -d "$HOME/.atlassian" ]         && confluence_signals+=(".atlassian config directory exists")
[ -n "${CONFLUENCE_TOKEN:-}" ]    && confluence_signals+=("CONFLUENCE_TOKEN env var set")
[ -n "${CONFLUENCE_URL:-}" ]      && confluence_signals+=("CONFLUENCE_URL env var set")

# ── Slack ─────────────────────────────────────────────────────────────────────

slack_signals=()
[ -n "${SLACK_BOT_TOKEN:-}" ]     && slack_signals+=("SLACK_BOT_TOKEN env var set")
[ -n "${SLACK_WEBHOOK_URL:-}" ]   && slack_signals+=("SLACK_WEBHOOK_URL env var set")
[ -d "/Applications/Slack.app" ]  && slack_signals+=("Slack.app installed")

# ── Linear ────────────────────────────────────────────────────────────────────

linear_signals=()
[ -n "${LINEAR_API_KEY:-}" ]      && linear_signals+=("LINEAR_API_KEY env var set")
command -v linear >/dev/null 2>&1      && linear_signals+=("linear CLI installed")

# ── Notion ────────────────────────────────────────────────────────────────────

notion_signals=()
[ -n "${NOTION_API_KEY:-}" ]      && notion_signals+=("NOTION_API_KEY env var set")
[ -n "${NOTION_TOKEN:-}" ]        && notion_signals+=("NOTION_TOKEN env var set")

# ── Sentry ────────────────────────────────────────────────────────────────────

sentry_signals=()
[ -f "$HOME/.sentryclirc" ]       && sentry_signals+=(".sentryclirc exists")
[ -n "${SENTRY_DSN:-}" ]          && sentry_signals+=("SENTRY_DSN env var set")
[ -n "${SENTRY_AUTH_TOKEN:-}" ]   && sentry_signals+=("SENTRY_AUTH_TOKEN env var set")

# ── GitHub ────────────────────────────────────────────────────────────────────

github_signals=()
if safe_timeout 3 gh auth status >/dev/null 2>&1; then
  github_signals+=("gh authenticated")
fi
[ -n "${GITHUB_TOKEN:-}" ]        && github_signals+=("GITHUB_TOKEN env var set")
[ -n "${GH_TOKEN:-}" ]            && github_signals+=("GH_TOKEN env var set")

# ── GitLab ────────────────────────────────────────────────────────────────────

gitlab_signals=()
if safe_timeout 3 glab auth status >/dev/null 2>&1; then
  gitlab_signals+=("glab authenticated")
fi
[ -n "${GITLAB_TOKEN:-}" ]        && gitlab_signals+=("GITLAB_TOKEN env var set")
[ -n "${GL_TOKEN:-}" ]            && gitlab_signals+=("GL_TOKEN env var set")

# ── Datadog ───────────────────────────────────────────────────────────────────

datadog_signals=()
[ -n "${DD_API_KEY:-}" ]          && datadog_signals+=("DD_API_KEY env var set")
[ -n "${DD_APP_KEY:-}" ]          && datadog_signals+=("DD_APP_KEY env var set")
command -v datadog-ci >/dev/null 2>&1  && datadog_signals+=("datadog-ci CLI installed")

# ── PagerDuty ─────────────────────────────────────────────────────────────────

pagerduty_signals=()
[ -n "${PAGERDUTY_TOKEN:-}" ]     && pagerduty_signals+=("PAGERDUTY_TOKEN env var set")

# ── Build JSON output via Python for safe escaping ────────────────────────────

build_entry() {
  local name="$1"
  shift
  local detected="false"
  [ "$#" -gt 0 ] && detected="true"
  printf '  "%s": {"detected": %s, "signals": %s}' "$(json_escape "$name")" "$detected" "$(signals_json "$@")"
}

{
  echo "{"
  build_entry "jira"        "${jira_signals[@]+"${jira_signals[@]}"}"
  echo ","
  build_entry "confluence"  "${confluence_signals[@]+"${confluence_signals[@]}"}"
  echo ","
  build_entry "slack"       "${slack_signals[@]+"${slack_signals[@]}"}"
  echo ","
  build_entry "linear"      "${linear_signals[@]+"${linear_signals[@]}"}"
  echo ","
  build_entry "notion"      "${notion_signals[@]+"${notion_signals[@]}"}"
  echo ","
  build_entry "sentry"      "${sentry_signals[@]+"${sentry_signals[@]}"}"
  echo ","
  build_entry "github"      "${github_signals[@]+"${github_signals[@]}"}"
  echo ","
  build_entry "gitlab"      "${gitlab_signals[@]+"${gitlab_signals[@]}"}"
  echo ","
  build_entry "datadog"     "${datadog_signals[@]+"${datadog_signals[@]}"}"
  echo ","
  build_entry "pagerduty"   "${pagerduty_signals[@]+"${pagerduty_signals[@]}"}"
  echo ""
  echo "}"
} 2>/dev/null || true

exit 0
