# Discover Integration Catalog

Detectable integrations for Cortex Discover. Each entry lists detection signals, MCP server configuration, confidence level, and whether the integration should be configured at user-level (~/.claude/) or project-level (.claude/).

**Signal types**: Detection signals are categorized as:
- **Machine-level** (checked by `discover-integrations.sh`): Environment variables, config files/directories, installed CLIs. These are always checked.
- **Project-level** (checked during per-project scaffolding): Dependencies in package.json/pyproject.toml, git remotes, CI config files. These require per-project scanning and are only checked during scaffold runs, not during initial discovery.

---

## Level Classification

- **user-level**: Configured in `~/.claude/.mcp.json`. Applies across all projects. Used for integrations that are personal or organization-wide (Jira, Slack, etc.).
- **project-level**: Configured in `.mcp.json` at the project root. Applies only to that project. Used for project-specific tooling (databases, test runners, etc.).

---

## Integration Catalog

### jira
- **Category**: Project management
- **Detection signals**:
  - `~/.jira.d/` directory exists
  - `JIRA_API_TOKEN` environment variable set
  - `JIRA_URL` environment variable set
  - `jira` CLI installed and on PATH
  - Git branch names matching pattern `JIRA-\d+` (e.g., `JIRA-1234-fix-login`)
  - `.jira.d/config.yml` in home directory
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Create, read, update, and transition Jira issues directly from Claude Code. View sprint boards, search issues with JQL, add comments, and link issues to code changes.
- **When to skip**: Team does not use Jira for project management. If using Linear, Asana, or another tracker, this server is not relevant.
- **Security notes**: Requires Jira API token and email. Use API tokens scoped to the minimum required permissions. Never use admin-level tokens.
- **Level**: ALWAYS user-level -- Jira is used across all projects in an organization.
- **Env vars needed**: `JIRA_URL` -- Jira instance URL (e.g., `https://mycompany.atlassian.net`), `JIRA_EMAIL` -- Jira account email, `JIRA_API_TOKEN` -- Jira API token
- **MCP server**: `npx @anthropic-ai/mcp-server-jira`
- **Configuration**:
```json
{
  "jira": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-jira"],
    "env": {
      "JIRA_URL": "${JIRA_URL}",
      "JIRA_EMAIL": "${JIRA_EMAIL}",
      "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
    }
  }
}
```

---

### confluence
- **Category**: Documentation
- **Detection signals**:
  - `~/.atlassian/` directory exists
  - `CONFLUENCE_TOKEN` environment variable set
  - `CONFLUENCE_URL` environment variable set
  - Jira detected (Confluence often co-exists with Jira in Atlassian suite)
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Search and read Confluence pages, create and update documentation, browse spaces, and access knowledge base content directly from Claude Code.
- **When to skip**: Team does not use Confluence. If documentation lives in Notion, Google Docs, or the repo itself, skip this.
- **Security notes**: Requires Confluence API token. Use tokens with read-only access unless Claude Code needs to create/edit pages. Scope to specific spaces when possible.
- **Level**: ALWAYS user-level -- Confluence is an organization-wide documentation platform.
- **Env vars needed**: `CONFLUENCE_URL` -- Confluence instance URL (e.g., `https://mycompany.atlassian.net/wiki`), `CONFLUENCE_TOKEN` -- Confluence API token
- **MCP server**: `npx @anthropic-ai/mcp-server-confluence`
- **Configuration**:
```json
{
  "confluence": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-confluence"],
    "env": {
      "CONFLUENCE_URL": "${CONFLUENCE_URL}",
      "CONFLUENCE_TOKEN": "${CONFLUENCE_TOKEN}"
    }
  }
}
```

---

### slack
- **Category**: Communication
- **Detection signals**:
  - `SLACK_BOT_TOKEN` environment variable set
  - `SLACK_WEBHOOK_URL` environment variable set
  - Slack.app installed on the system (`/Applications/Slack.app` on macOS)
  - `@slack/bolt` or `@slack/web-api` in project dependencies
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Read and send Slack messages, manage channels, search message history, and interact with Slack workspaces from Claude Code. Enables development workflows that involve Slack communication.
- **When to skip**: Team does not use Slack, or Slack is only used for casual chat without programmatic needs. Skip if using Microsoft Teams or Discord instead.
- **Security notes**: Requires Slack bot token with appropriate scopes. Use the minimum required scopes. Be cautious about which channels the bot can access. Never post to production channels during development.
- **Level**: ALWAYS user-level -- Slack is a personal/organization-wide communication tool.
- **Env vars needed**: `SLACK_BOT_TOKEN` -- Slack bot OAuth token, `SLACK_TEAM_ID` -- Slack workspace ID
- **MCP server**: `npx @anthropic-ai/mcp-server-slack`
- **Configuration**:
```json
{
  "slack": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-slack"],
    "env": {
      "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
      "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
    }
  }
}
```
**Note**: Already exists in `mcp-catalog.md` -- see that file for the canonical project-level configuration. This entry documents the user-level classification for Discover.

---

### linear
- **Category**: Issue tracking
- **Detection signals**:
  - `LINEAR_API_KEY` environment variable set
  - `linear` CLI installed and on PATH
  - Git branch names matching Linear issue patterns (e.g., `LIN-\d+`, `ENG-\d+`)
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Create, read, update, and search Linear issues. View projects, cycles, and team workflows. Transition issue states and add comments directly from Claude Code.
- **When to skip**: Team does not use Linear. If using Jira or another issue tracker, this server is not relevant.
- **Security notes**: Requires Linear API key. Use personal API keys, not workspace-level keys. The key grants access to all issues the user can see in Linear.
- **Level**: ALWAYS user-level -- Linear is used across all projects in an organization.
- **Env vars needed**: `LINEAR_API_KEY` -- Linear personal API key
- **MCP server**: `npx @anthropic-ai/mcp-server-linear`
- **Configuration**:
```json
{
  "linear": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-linear"],
    "env": {
      "LINEAR_API_KEY": "${LINEAR_API_KEY}"
    }
  }
}
```

---

### notion
- **Category**: Knowledge base
- **Detection signals**:
  - `NOTION_API_KEY` environment variable set
  - `NOTION_TOKEN` environment variable set
  - References to Notion in documentation or README files
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Search pages and databases, create and update pages, query database views, manage comments, and access knowledge base content directly from Claude Code.
- **When to skip**: Team does not use Notion. If documentation and knowledge management lives in Confluence, Google Docs, or the repo itself, skip this.
- **Security notes**: Requires Notion integration token. Create a dedicated integration in Notion's developer settings. The integration only has access to pages explicitly shared with it.
- **Level**: ALWAYS user-level -- Notion is a personal/organization-wide knowledge platform.
- **Env vars needed**: `NOTION_API_KEY` -- Notion internal integration token
- **MCP server**: `npx @anthropic-ai/mcp-server-notion`
- **Configuration**:
```json
{
  "notion": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-notion"],
    "env": {
      "NOTION_API_KEY": "${NOTION_API_KEY}"
    }
  }
}
```

---

### github
- **Category**: Source control
- **Detection signals**:
  - `gh auth status` succeeds (GitHub CLI authenticated)
  - `GITHUB_TOKEN` environment variable set
  - `GH_TOKEN` environment variable set
  - Git remotes pointing to `github.com`
  - `.github/` directory exists
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: See `mcp-catalog.md` for full details. Create/read/update issues, pull requests, branches, files, reviews, and comments.
- **When to skip**: Project is not hosted on GitHub.
- **Security notes**: See `mcp-catalog.md` for full security notes.
- **Level**: User-level if >50% of the developer's repos use GitHub. Otherwise project-level.
- **Env vars needed**: `GITHUB_TOKEN` -- GitHub personal access token
- **MCP server**: Already defined in `mcp-catalog.md` -- reference that file for the canonical configuration.
- **Level decision logic**:
  - Discover checks how many of the developer's local repos use GitHub remotes
  - If more than half use GitHub, configure at user-level (`~/.claude/.mcp.json`)
  - Otherwise, configure at project-level (`.mcp.json`)

---

### gitlab
- **Category**: Source control
- **Detection signals**:
  - `glab auth status` succeeds (GitLab CLI authenticated)
  - `GITLAB_TOKEN` environment variable set
  - `GL_TOKEN` environment variable set
  - Git remotes pointing to `gitlab.com` or self-hosted GitLab instances
  - `.gitlab-ci.yml` exists
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Create/read/update issues, merge requests, branches, files, and CI/CD pipelines directly from Claude Code. Enables full GitLab workflow without leaving the terminal.
- **When to skip**: Project is not hosted on GitLab. If using GitHub or Bitbucket, this server is not relevant.
- **Security notes**: Requires GitLab personal access token. Use tokens with minimum required scopes (`api` for full access, `read_api` for read-only). For self-hosted GitLab, ensure the token is scoped to the correct instance.
- **Level**: User-level if >50% of the developer's repos use GitLab. Otherwise project-level.
- **Env vars needed**: `GITLAB_TOKEN` -- GitLab personal access token
- **MCP server**: `npx @anthropic-ai/mcp-server-gitlab`
- **Configuration**:
```json
{
  "gitlab": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-gitlab"],
    "env": {
      "GITLAB_TOKEN": "${GITLAB_TOKEN}"
    }
  }
}
```
- **Level decision logic**:
  - Discover checks how many of the developer's local repos use GitLab remotes
  - If more than half use GitLab, configure at user-level (`~/.claude/.mcp.json`)
  - Otherwise, configure at project-level (`.mcp.json`)

---

### sentry
- **Category**: Error monitoring
- **Detection signals**:
  - `~/.sentryclirc` file exists
  - `SENTRY_DSN` environment variable set
  - `SENTRY_AUTH_TOKEN` environment variable set
  - `@sentry/*` packages in project dependencies (e.g., `@sentry/node`, `@sentry/react`, `@sentry/nextjs`)
  - `sentry.properties` file exists
  - `sentry.client.config.ts` or `sentry.server.config.ts` exists
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: See `mcp-catalog.md` for full details. Access Sentry error tracking data -- view issues, read stack traces, check error frequency, and correlate errors with code changes.
- **When to skip**: Project does not use Sentry. If using a different error tracking service (Bugsnag, Rollbar, etc.), this server is not relevant.
- **Security notes**: See `mcp-catalog.md` for full security notes.
- **Level**: User-level if detected in ANY project -- error monitoring is cross-cutting.
- **Env vars needed**: `SENTRY_AUTH_TOKEN` -- Sentry authentication token
- **MCP server**: Already defined in `mcp-catalog.md` -- reference that file for the canonical configuration.

---

### datadog
- **Category**: Monitoring
- **Detection signals**:
  - `DD_API_KEY` environment variable set
  - `DD_APP_KEY` environment variable set
  - `datadog-ci` CLI installed and on PATH
  - `dd-trace` or `datadog-lambda-js` in project dependencies
  - `datadog.yaml` or `datadog-agent` configuration files
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Query metrics, view dashboards, search logs, list monitors, and inspect APM traces from Claude Code. Enables data-driven debugging and performance analysis without leaving the terminal.
- **When to skip**: Team does not use Datadog. If using Prometheus/Grafana, New Relic, or another monitoring stack, this server is not relevant.
- **Security notes**: Requires Datadog API and application keys. Use keys with minimum required scopes. API keys can send data; application keys grant read access. Never use keys with admin permissions.
- **Level**: User-level if detected -- monitoring is typically organization-wide.
- **Env vars needed**: `DD_API_KEY` -- Datadog API key, `DD_APP_KEY` -- Datadog application key
- **MCP server**: `npx @anthropic-ai/mcp-server-datadog`
- **Configuration**:
```json
{
  "datadog": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-datadog"],
    "env": {
      "DD_API_KEY": "${DD_API_KEY}",
      "DD_APP_KEY": "${DD_APP_KEY}"
    }
  }
}
```

---

### pagerduty
- **Category**: Incident management
- **Detection signals**:
  - `PAGERDUTY_TOKEN` environment variable set
  - PagerDuty referenced in runbooks or on-call documentation
  - `@pagerduty/pdjs` in project dependencies
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: View and manage incidents, check on-call schedules, acknowledge and resolve alerts, and search incident history from Claude Code. Enables rapid incident response during development.
- **When to skip**: Team does not use PagerDuty. If using Opsgenie, VictorOps, or another incident management platform, this server is not relevant.
- **Security notes**: Requires PagerDuty API token. Use read-only tokens unless Claude Code needs to acknowledge or resolve incidents. Be cautious about triggering test incidents.
- **Level**: User-level if detected -- incident management is organization-wide.
- **Env vars needed**: `PAGERDUTY_TOKEN` -- PagerDuty API token (v2)
- **MCP server**: `npx @anthropic-ai/mcp-server-pagerduty`
- **Configuration**:
```json
{
  "pagerduty": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-pagerduty"],
    "env": {
      "PAGERDUTY_TOKEN": "${PAGERDUTY_TOKEN}"
    }
  }
}
```

---

## Integration Detection Logic

Use this process when Cortex Discover scans for integrations:

```
For each integration in the catalog:
  1. Check detection signals:
     a. Environment variables (check with: printenv | grep PATTERN)
     b. CLI tools (check with: command -v TOOL)
     c. Config files (check with: test -f PATH)
     d. Git branch patterns (check with: git branch -a | grep PATTERN)
     e. Project dependencies (check package.json, requirements.txt, etc.)
  2. If any signal matches:
     a. Mark integration as detected
     b. Determine level (user vs project) per the rules above
     c. Check if MCP server is already configured (avoid duplicates)
  3. For user-level integrations:
     a. Add to ~/.claude/.mcp.json
     b. Add env var instructions to ~/.claude/CLAUDE.md
  4. For project-level integrations:
     a. Add to .mcp.json at project root
     b. Add env var instructions to project CLAUDE.md
```

## Environment Variable Summary

Quick reference for all integration env vars:

| Integration | Env Var | Description | Required |
|-------------|---------|-------------|----------|
| jira | `JIRA_URL` | Jira instance URL | Yes |
| jira | `JIRA_EMAIL` | Jira account email | Yes |
| jira | `JIRA_API_TOKEN` | Jira API token | Yes |
| confluence | `CONFLUENCE_URL` | Confluence instance URL | Yes |
| confluence | `CONFLUENCE_TOKEN` | Confluence API token | Yes |
| slack | `SLACK_BOT_TOKEN` | Slack bot OAuth token | Yes |
| slack | `SLACK_TEAM_ID` | Slack workspace ID | Yes |
| linear | `LINEAR_API_KEY` | Linear personal API key | Yes |
| notion | `NOTION_API_KEY` | Notion integration token | Yes |
| github | `GITHUB_TOKEN` | GitHub personal access token | Yes |
| gitlab | `GITLAB_TOKEN` | GitLab personal access token | Yes |
| sentry | `SENTRY_AUTH_TOKEN` | Sentry auth token | Yes |
| datadog | `DD_API_KEY` | Datadog API key | Yes |
| datadog | `DD_APP_KEY` | Datadog application key | Yes |
| pagerduty | `PAGERDUTY_TOKEN` | PagerDuty API token | Yes |
