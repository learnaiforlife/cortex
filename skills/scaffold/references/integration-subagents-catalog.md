# Integration Subagents Catalog

Catalog of integration-specific subagents that scaffold can recommend when external services are detected. The opportunity-detector subagent reads this file to map integration signals to subagent suggestions.

Each integration subagent wraps an MCP server with a purpose-built workflow -- it does not just expose raw API access, it provides an opinionated automation (e.g., "create Jira issues from TODOs" rather than "call Jira API").

---

## Credential Handling

**Never store or read credential values.** Only reference them via `${ENV_VAR}` syntax in all generated configuration files. Subagent templates must not:
- Hardcode API keys, tokens, or secrets
- Read credentials from files or environment at generation time
- Log or echo credential values
- Store credentials in CLAUDE.md or any checked-in file

All credential references use the format `${ENV_VAR}` which is resolved at runtime by the MCP server process.

---

## Detection Score Formula

Each integration uses a weighted signal detection score to determine recommendation strength:

```
Score = sum of matched signal weights (0-100 scale)

Signal weights:
  Environment variable set:     +30 per matching env var (max 60)
  CLI tool installed:           +20
  Config file/directory exists: +15
  Dependency in package.json:   +15
  Git pattern match:            +10
  Co-detection with related:    +10

Thresholds:
  score >= 30: "suggested"    -- mention to user as available
  score >= 60: "recommended"  -- include in generated config by default
```

---

## Integration Subagents

### Jira

| Field | Value |
|-------|-------|
| **Integration Name** | Jira |
| **Category** | Project Management |
| **What the Subagent Does** | Creates Jira issues from TODO/FIXME comments in code, updates issue status when branches are merged, links commits to issues via branch naming conventions, and posts work summaries as issue comments. |
| **MCP Server** | `mcp-server-jira` (`npx -y @anthropic-ai/mcp-server-jira`) |
| **Template Path** | `templates/subagents/jira-manager.md` |
| **Required Env Vars** | `JIRA_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `JIRA_API_TOKEN` env var set | Environment variable | +30 |
| `JIRA_URL` env var set | Environment variable | +30 |
| `~/.jira.d/` directory exists | Config directory | +15 |
| `jira` CLI installed (`command -v jira`) | CLI tool | +20 |
| Git branch names matching `[A-Z]+-\d+` (e.g., `PROJ-1234`) | Git pattern | +10 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use API tokens scoped to minimum required permissions. Never use admin-level tokens. Tokens are tied to a specific Atlassian account. The subagent should only create/update issues, not delete them or modify project settings.

---

### Confluence

| Field | Value |
|-------|-------|
| **Integration Name** | Confluence |
| **Category** | Documentation |
| **What the Subagent Does** | Creates and updates Confluence wiki pages from code context, syncs architecture decision records (ADRs) to Confluence spaces, and generates API documentation pages from code analysis. |
| **MCP Server** | `mcp-server-confluence` (`npx -y @anthropic-ai/mcp-server-confluence`) |
| **Template Path** | `templates/subagents/confluence-writer.md` |
| **Required Env Vars** | `CONFLUENCE_URL`, `CONFLUENCE_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `CONFLUENCE_TOKEN` env var set | Environment variable | +30 |
| `CONFLUENCE_URL` env var set | Environment variable | +30 |
| `~/.atlassian/` directory exists | Config directory | +15 |
| Jira co-detected (Atlassian suite) | Co-detection | +10 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use tokens with read-only access unless the subagent needs to create or edit pages. Scope to specific spaces when possible. Never overwrite existing pages without user confirmation.

---

### Slack

| Field | Value |
|-------|-------|
| **Integration Name** | Slack |
| **Category** | Communication |
| **What the Subagent Does** | Posts build success/failure notifications to designated channels, sends PR status updates, alerts on test suite regressions, and summarizes deployment activity. |
| **MCP Server** | `mcp-server-slack` (`npx -y @anthropic-ai/mcp-server-slack`) |
| **Template Path** | `templates/subagents/slack-notifier.md` |
| **Required Env Vars** | `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `SLACK_BOT_TOKEN` env var set | Environment variable | +30 |
| `SLACK_WEBHOOK_URL` env var set | Environment variable | +30 |
| `Slack.app` installed (`/Applications/Slack.app` on macOS) | CLI/app | +20 |
| `@slack/bolt` or `@slack/web-api` in `package.json` deps | Dependency | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use minimum required bot scopes. Never post to production or general channels during development. The subagent should only post to channels explicitly configured by the user. Rate-limit outgoing messages to avoid flooding.

---

### Linear

| Field | Value |
|-------|-------|
| **Integration Name** | Linear |
| **Category** | Issue Tracking |
| **What the Subagent Does** | Creates and updates Linear issues from development context, manages cycle assignments, transitions issue states on branch events, and links PRs to issues automatically. |
| **MCP Server** | `mcp-server-linear` (`npx -y @anthropic-ai/mcp-server-linear`) |
| **Template Path** | `templates/subagents/linear-manager.md` |
| **Required Env Vars** | `LINEAR_API_KEY` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `LINEAR_API_KEY` env var set | Environment variable | +30 |
| `linear` CLI installed (`command -v linear`) | CLI tool | +20 |
| Git branch names matching Linear patterns (`LIN-\d+`, `ENG-\d+`) | Git pattern | +10 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use personal API keys, not workspace-level keys. The key grants access to all issues the user can see. The subagent should not delete issues or modify team settings.

---

### Notion

| Field | Value |
|-------|-------|
| **Integration Name** | Notion |
| **Category** | Knowledge Base |
| **What the Subagent Does** | Creates Notion pages from development context, updates project databases with status and metrics, syncs meeting notes and decision logs, and maintains a living knowledge base of project conventions. |
| **MCP Server** | `mcp-server-notion` (`npx -y @anthropic-ai/mcp-server-notion`) |
| **Template Path** | `templates/subagents/notion-writer.md` |
| **Required Env Vars** | `NOTION_API_KEY` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `NOTION_API_KEY` env var set | Environment variable | +30 |
| `NOTION_TOKEN` env var set | Environment variable | +30 |
| `notion` referenced in README or project docs | Dependency/reference | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Create a dedicated Notion integration with minimum scopes. The integration only accesses pages explicitly shared with it. Never overwrite existing pages without confirmation.

---

### GitHub (Enhanced)

| Field | Value |
|-------|-------|
| **Integration Name** | GitHub (Enhanced) |
| **Category** | Source Control (Enhanced) |
| **What the Subagent Does** | Writes detailed PR descriptions from diff analysis, posts structured review comments with inline code suggestions, generates release notes from merged PRs, and manages issue labels based on code changes. |
| **MCP Server** | Built-in Claude Code GitHub MCP (`@modelcontextprotocol/server-github`) |
| **Template Path** | `templates/subagents/github-pr-writer.md` |
| **Required Env Vars** | `GITHUB_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `gh auth status` succeeds | CLI tool | +20 |
| `GITHUB_TOKEN` or `GH_TOKEN` env var set | Environment variable | +30 |
| `.github/` directory exists | Config directory | +15 |
| Git remote points to `github.com` | Git pattern | +10 |
| `.github/workflows/` contains CI files | Config directory | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use fine-grained personal access tokens scoped to specific repositories. Minimum scopes: `repo` for private repos, `public_repo` for public. Never use tokens with `admin` or `delete` permissions.

---

### GitLab

| Field | Value |
|-------|-------|
| **Integration Name** | GitLab |
| **Category** | Source Control |
| **What the Subagent Does** | Writes MR descriptions from diff analysis, debugs failed CI/CD pipelines by reading logs and suggesting fixes, and manages issue transitions on merge events. |
| **MCP Server** | `mcp-server-gitlab` (`npx -y @anthropic-ai/mcp-server-gitlab`) |
| **Template Path** | `templates/subagents/gitlab-mr-writer.md` |
| **Required Env Vars** | `GITLAB_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `glab auth status` succeeds | CLI tool | +20 |
| `GITLAB_TOKEN` or `GL_TOKEN` env var set | Environment variable | +30 |
| `.gitlab-ci.yml` exists | Config file | +15 |
| Git remote points to `gitlab.com` or self-hosted GitLab | Git pattern | +10 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use personal access tokens with minimum required scopes (`api` for full access, `read_api` for read-only). For self-hosted GitLab, ensure the token is scoped to the correct instance. Never use tokens with admin permissions.

---

### Sentry

| Field | Value |
|-------|-------|
| **Integration Name** | Sentry |
| **Category** | Error Monitoring |
| **What the Subagent Does** | Analyzes recurring error patterns from Sentry issues, correlates errors with recent code changes, suggests targeted fixes based on stack traces, and identifies error hotspots in the codebase. |
| **MCP Server** | Sentry MCP (`https://mcp.sentry.dev/mcp` via HTTP transport) |
| **Template Path** | `templates/subagents/sentry-analyzer.md` |
| **Required Env Vars** | `SENTRY_AUTH_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `SENTRY_DSN` env var set | Environment variable | +30 |
| `SENTRY_AUTH_TOKEN` env var set | Environment variable | +30 |
| `@sentry/*` packages in dependencies (`@sentry/node`, `@sentry/react`, `@sentry/nextjs`) | Dependency | +15 |
| `sentry.properties` file exists | Config file | +15 |
| `sentry.client.config.ts` or `sentry.server.config.ts` exists | Config file | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use auth tokens with read-only access unless the subagent needs to resolve or assign issues. Use organization-scoped tokens, not user tokens. Be cautious about accessing production error data in development contexts.

---

### Datadog

| Field | Value |
|-------|-------|
| **Integration Name** | Datadog |
| **Category** | Monitoring |
| **What the Subagent Does** | Queries metrics and dashboards during debugging sessions, searches logs for error patterns, correlates performance regressions with recent deployments, and inspects APM traces for latency analysis. |
| **MCP Server** | `mcp-server-datadog` (`npx -y @anthropic-ai/mcp-server-datadog`) |
| **Template Path** | `templates/subagents/datadog-debugger.md` |
| **Required Env Vars** | `DD_API_KEY`, `DD_APP_KEY` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `DD_API_KEY` env var set | Environment variable | +30 |
| `DD_APP_KEY` env var set | Environment variable | +30 |
| `datadog-ci` CLI installed (`command -v datadog-ci`) | CLI tool | +20 |
| `dd-trace` or `datadog-lambda-js` in dependencies | Dependency | +15 |
| `datadog.yaml` config file exists | Config file | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: API keys can send data to Datadog; application keys grant read access. Use keys with minimum required scopes. Never use keys with admin permissions. Be aware that metric queries may expose sensitive business data.

---

### PagerDuty

| Field | Value |
|-------|-------|
| **Integration Name** | PagerDuty |
| **Category** | Incidents |
| **What the Subagent Does** | Views active incidents and their timelines, correlates incidents with recent deployments and code changes, checks on-call schedules, and provides context during incident response by linking errors to code. |
| **MCP Server** | `mcp-server-pagerduty` (`npx -y @anthropic-ai/mcp-server-pagerduty`) |
| **Template Path** | `templates/subagents/pagerduty-responder.md` |
| **Required Env Vars** | `PAGERDUTY_TOKEN` |

**Detection Method**:

| Signal | Type | Weight |
|--------|------|--------|
| `PAGERDUTY_TOKEN` env var set | Environment variable | +30 |
| `@pagerduty/pdjs` in dependencies | Dependency | +15 |
| PagerDuty referenced in runbooks or on-call docs | Dependency/reference | +15 |

**Detection Threshold**: score >= 30 to suggest, >= 60 for recommended.

**Safety Notes**: Use read-only tokens unless the subagent needs to acknowledge or resolve incidents. Be cautious about triggering test incidents. Never create real incidents from development context.

---

## Integration Selection Logic

Use this process when deciding which integration subagents to recommend:

```
For each integration in the catalog:
  1. Run detection signals and compute weighted score
  2. If score >= 30:
     a. Mark as "suggested" -- mention in recommendations
  3. If score >= 60:
     a. Mark as "recommended" -- include in generated config
  4. Check for conflicts and redundancy:
     - Jira vs Linear: only recommend one issue tracker
     - Confluence vs Notion: only recommend one knowledge base
     - GitHub vs GitLab: only recommend the one matching the git remote
  5. Check co-detection bonuses:
     - Jira + Confluence: both get +10 co-detection bonus
     - GitHub + Sentry: suggest Sentry analyzer if GitHub is detected
     - Datadog + PagerDuty: suggest both if either is detected (ops stack)
  6. Order recommendations:
     - Source control (GitHub/GitLab) first
     - Issue tracking (Jira/Linear) second
     - Communication (Slack) third
     - Knowledge base (Confluence/Notion) fourth
     - Monitoring (Sentry/Datadog/PagerDuty) last
```

## Environment Variable Summary

Quick reference for all integration env vars:

| Integration | Env Var | Description | Required |
|-------------|---------|-------------|----------|
| Jira | `JIRA_URL` | Jira instance URL | Yes |
| Jira | `JIRA_EMAIL` | Jira account email | Yes |
| Jira | `JIRA_API_TOKEN` | Jira API token | Yes |
| Confluence | `CONFLUENCE_URL` | Confluence instance URL | Yes |
| Confluence | `CONFLUENCE_TOKEN` | Confluence API token | Yes |
| Slack | `SLACK_BOT_TOKEN` | Slack bot OAuth token | Yes |
| Slack | `SLACK_TEAM_ID` | Slack workspace ID | Yes |
| Linear | `LINEAR_API_KEY` | Linear personal API key | Yes |
| Notion | `NOTION_API_KEY` | Notion integration token | Yes |
| GitHub | `GITHUB_TOKEN` | GitHub personal access token | Yes |
| GitLab | `GITLAB_TOKEN` | GitLab personal access token | Yes |
| Sentry | `SENTRY_AUTH_TOKEN` | Sentry auth token | Yes |
| Datadog | `DD_API_KEY` | Datadog API key | Yes |
| Datadog | `DD_APP_KEY` | Datadog application key | Yes |
| PagerDuty | `PAGERDUTY_TOKEN` | PagerDuty API token (v2) | Yes |
