# MCP Server Catalog

Known MCP servers with detection signals and configuration templates. Use this catalog to recommend MCP servers based on project analysis.

---

## Recommendation Confidence Levels

- **recommended**: Strong project signals match. Include in generated `.mcp.json` by default.
- **candidate**: Weak or indirect signals. Mention as available but let the user decide.

---

## Server Catalog

### github
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@modelcontextprotocol/server-github"]`
- **Trigger when**:
  - `.github/` directory exists
  - `.github/workflows/` contains GitHub Actions CI files
  - `package.json` has GitHub-related scripts
  - Remote origin URL points to github.com
  - Pull request templates exist (`.github/pull_request_template.md`)
  - Issue templates exist (`.github/ISSUE_TEMPLATE/`)
- **Confidence**: recommended
- **What it provides**: Create/read/update issues, pull requests, branches, files, reviews, and comments directly from Claude Code. Enables full GitHub workflow without leaving the terminal.
- **When to skip**: Project is not hosted on GitHub (uses GitLab, Bitbucket, etc.), or team does not use GitHub's issue/PR workflow.
- **Security notes**: Requires a GitHub personal access token with appropriate scopes. Minimum scopes: `repo` for private repos, `public_repo` for public repos. Use fine-grained tokens when possible to limit access to specific repositories.
- **Env vars needed**: `GITHUB_TOKEN` -- GitHub personal access token
- **Configuration**:
```json
{
  "github": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_TOKEN": "${GITHUB_TOKEN}"
    }
  }
}
```

---

### postgres
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@bytebase/dbhub", "--dsn", "${DATABASE_URL}"]`
- **Trigger when**:
  - `DATABASE_URL` environment variable contains `postgres://` or `postgresql://`
  - `docker-compose.yml` contains a PostgreSQL service
  - Prisma schema (`prisma/schema.prisma`) uses `provider = "postgresql"`
  - `pg` or `@prisma/client` in package.json dependencies
  - `psycopg2`, `asyncpg`, or `sqlalchemy` with postgres in Python dependencies
  - Knex or TypeORM config references PostgreSQL
  - Migration files reference PostgreSQL-specific syntax
- **Confidence**: recommended
- **What it provides**: Execute SQL queries, inspect schema, list tables, describe columns, and explore database structure directly from Claude Code. Enables data-aware code generation and debugging.
- **When to skip**: No PostgreSQL database in the project, or database access is not needed for development (e.g., frontend-only work). Skip if the project uses a different database exclusively.
- **Security notes**: The DSN connection string contains credentials. Never hardcode it in `.mcp.json`. Always use environment variable reference. Consider using a read-only database user for safety. Do NOT point this at production databases.
- **Env vars needed**: `DATABASE_URL` -- PostgreSQL connection string (e.g., `postgresql://user:pass@localhost:5432/dbname`)
- **Configuration**:
```json
{
  "postgres": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@bytebase/dbhub", "--dsn", "${DATABASE_URL}"]
  }
}
```

---

### playwright
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@playwright/mcp@latest"]`
- **Trigger when**:
  - `@playwright/test` in package.json dependencies or devDependencies
  - `playwright.config.ts` or `playwright.config.js` exists
  - Test files using Playwright imports (`from '@playwright/test'`)
  - `e2e/` or `tests/e2e/` directory with Playwright test files
- **Confidence**: recommended
- **What it provides**: Browser automation capabilities -- navigate pages, click elements, fill forms, take screenshots, evaluate JavaScript, and inspect the DOM. Enables Claude Code to interact with web applications for testing and debugging.
- **When to skip**: Project has no web frontend, no E2E tests, and no browser-based testing needs. Skip for pure backend or CLI projects.
- **Security notes**: Playwright runs a real browser. Be cautious about navigating to URLs that require authentication or contain sensitive data. The browser session is local and not sandboxed beyond normal browser security.
- **Env vars needed**: None required. Optional: `PLAYWRIGHT_BROWSERS_PATH` for custom browser install location.
- **Configuration**:
```json
{
  "playwright": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest"]
  }
}
```

---

### filesystem
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@modelcontextprotocol/server-filesystem", "./src", "./docs"]`
- **Trigger when**:
  - Large monorepo with multiple packages/workspaces
  - Complex directory structure with many nested levels
  - Project has documentation directory that needs frequent reference
  - Projects with generated code directories that need monitoring
- **Confidence**: candidate
- **What it provides**: Enhanced file system operations including directory tree visualization, file search with pattern matching, and bulk file operations. Supplements Claude Code's built-in file tools with additional capabilities.
- **When to skip**: Small to medium projects where Claude Code's built-in Read, Glob, and Grep tools are sufficient. Most projects do NOT need this -- only recommend for genuinely complex file system needs.
- **Security notes**: Restrict accessible directories in the args. Only include directories the agent needs access to. Never include the entire filesystem (`/`). The server only allows access to explicitly listed directories.
- **Env vars needed**: None
- **Configuration**:
```json
{
  "filesystem": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "./src", "./docs", "./config"]
  }
}
```
**Note**: Adjust the directory paths in args based on the actual project structure. Only include directories that are relevant.

---

### sentry
- **Transport**: http
- **URL**: `https://mcp.sentry.dev/mcp`
- **Trigger when**:
  - `@sentry/node`, `@sentry/react`, `@sentry/nextjs`, or any `@sentry/*` package in dependencies
  - Sentry DSN configured in environment variables or config files
  - `sentry.client.config.ts` or `sentry.server.config.ts` exists
  - `sentry.properties` file exists
  - References to Sentry in error handling code
- **Confidence**: recommended
- **What it provides**: Access to Sentry error tracking data -- view issues, read stack traces, check error frequency, and correlate errors with code changes. Enables Claude Code to debug production errors with real error data.
- **When to skip**: Project does not use Sentry for error tracking. If using a different error tracking service (Bugsnag, Datadog, etc.), this server is not relevant.
- **Security notes**: Requires Sentry auth token. The token should have read-only access unless you want Claude Code to manage Sentry issues (resolve, assign, etc.). Use organization-scoped tokens, not user tokens.
- **Env vars needed**: `SENTRY_AUTH_TOKEN` -- Sentry authentication token
- **Configuration**:
```json
{
  "sentry": {
    "type": "http",
    "url": "https://mcp.sentry.dev/mcp",
    "env": {
      "SENTRY_AUTH_TOKEN": "${SENTRY_AUTH_TOKEN}"
    }
  }
}
```

---

### memory
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@modelcontextprotocol/server-memory"]`
- **Trigger when**:
  - Large/complex project where context across sessions is valuable
  - Projects with many team conventions that accumulate over time
  - Long-running development efforts where continuity matters
  - Monorepos with cross-package dependencies that are hard to re-discover
- **Confidence**: candidate
- **What it provides**: Persistent knowledge graph that Claude Code can read and write across sessions. Stores entities, observations, and relations. Enables Claude Code to remember decisions, patterns, and context between sessions.
- **When to skip**: Small projects, short-lived projects, or projects where CLAUDE.md captures all needed context. Memory server adds overhead for simple projects.
- **Security notes**: Memory is stored locally as a JSON file. It may contain sensitive project information. Consider where the memory file is stored and whether it should be gitignored.
- **Env vars needed**: None required. Optional: `MEMORY_FILE_PATH` to specify storage location.
- **Configuration**:
```json
{
  "memory": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```

---

### sqlite
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-sqlite", "--db-path", "${SQLITE_DB_PATH}"]`
- **Trigger when**:
  - `.sqlite`, `.db`, or `.sqlite3` files in the project
  - `better-sqlite3` or `sql.js` in package.json dependencies
  - `sqlite3` in Python dependencies
  - Prisma schema uses `provider = "sqlite"`
  - Drizzle or Knex config references SQLite
  - `database/` directory with SQLite files
- **Confidence**: recommended
- **What it provides**: Query SQLite databases, inspect schemas, run SQL commands, and explore data directly from Claude Code. Useful for development databases, test fixtures, and local data stores.
- **When to skip**: Project uses a different database (PostgreSQL, MySQL, MongoDB) exclusively with no SQLite files. Skip if SQLite files are only used for caching or temporary storage.
- **Security notes**: SQLite databases may contain application data. Point to development/test databases, not production data. The server has full read/write access to the specified database.
- **Env vars needed**: `SQLITE_DB_PATH` -- Path to the SQLite database file (e.g., `./data/dev.db`)
- **Configuration**:
```json
{
  "sqlite": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@anthropic-ai/mcp-server-sqlite", "--db-path", "${SQLITE_DB_PATH}"]
  }
}
```

---

### brave-search
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@modelcontextprotocol/server-brave-search"]`
- **Trigger when**:
  - Projects that need web research during development (documentation lookup, API reference)
  - Projects integrating with many external services
  - Research-heavy development workflows
  - Projects where up-to-date information is critical (security advisories, version compatibility)
- **Confidence**: candidate
- **What it provides**: Web search capabilities via the Brave Search API. Claude Code can search the web for documentation, solutions, API references, and current information during development.
- **When to skip**: Most projects don't need this. The context7 plugin covers library documentation needs. Only recommend when active web research is part of the development workflow.
- **Security notes**: Requires a Brave Search API key. Search queries may contain sensitive project information. Be aware that queries are sent to Brave's API servers.
- **Env vars needed**: `BRAVE_API_KEY` -- Brave Search API key (free tier available at https://brave.com/search/api/)
- **Configuration**:
```json
{
  "brave-search": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": {
      "BRAVE_API_KEY": "${BRAVE_API_KEY}"
    }
  }
}
```

---

### puppeteer
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@modelcontextprotocol/server-puppeteer"]`
- **Trigger when**:
  - `puppeteer` or `puppeteer-core` in package.json dependencies
  - Web scraping scripts in the project
  - E2E test files using Puppeteer
  - PDF generation using headless browser
  - Screenshot automation scripts
- **Confidence**: recommended
- **What it provides**: Headless Chrome automation -- navigate pages, take screenshots, generate PDFs, scrape content, and evaluate JavaScript. Similar to Playwright MCP but uses Puppeteer/Chrome.
- **When to skip**: If Playwright MCP is already configured (they overlap significantly). Prefer Playwright over Puppeteer for new projects. Only use Puppeteer MCP if the project already uses Puppeteer.
- **Security notes**: Same security considerations as Playwright -- runs a real browser locally. Be cautious with authenticated sessions and sensitive data.
- **Env vars needed**: None required. Optional: `PUPPETEER_EXECUTABLE_PATH` for custom Chrome path.
- **Configuration**:
```json
{
  "puppeteer": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
  }
}
```

---

### slack
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-slack"]`
- **Trigger when**:
  - `@slack/bolt`, `@slack/web-api`, or `@slack/events-api` in dependencies
  - Slack webhook URLs in configuration
  - Slack bot configuration files
  - `.env` files referencing `SLACK_TOKEN` or `SLACK_WEBHOOK`
  - Slack integration mentioned in documentation
- **Confidence**: candidate
- **What it provides**: Read and send Slack messages, manage channels, and interact with Slack workspaces from Claude Code. Enables development workflows that involve Slack communication.
- **When to skip**: Project has no Slack integration, or Slack is only used for team chat (not programmatic access). Skip unless the project actively integrates with Slack's API.
- **Security notes**: Requires Slack bot token with appropriate scopes. Use the minimum required scopes. Be cautious about which channels the bot can access. Never post to production channels during development.
- **Env vars needed**: `SLACK_BOT_TOKEN` -- Slack bot OAuth token, `SLACK_TEAM_ID` -- Slack workspace ID
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

---

## MCP Server Selection Logic

Use this decision process when analyzing a project:

```
For each MCP server in the catalog:
  1. Check trigger signals against project analysis results
  2. If signals match:
     a. Check "when to skip" conditions
     b. If not skipped, add to recommendations with confidence level
  3. Check for conflicts:
     - playwright vs puppeteer: prefer playwright, skip puppeteer unless project uses it
     - postgres vs sqlite: can recommend both if both are used
  4. Check for dependencies:
     - github: most projects should have this
     - sentry: only if @sentry/* packages detected
  5. For "candidate" confidence servers:
     - Include in output but mark as optional
     - Let user decide whether to enable
```

## Environment Variable Summary

Quick reference for all required env vars across all servers:

| Server | Env Var | Description | Required |
|--------|---------|-------------|----------|
| github | `GITHUB_TOKEN` | GitHub personal access token | Yes |
| postgres | `DATABASE_URL` | PostgreSQL connection string | Yes |
| sentry | `SENTRY_AUTH_TOKEN` | Sentry auth token | Yes |
| sqlite | `SQLITE_DB_PATH` | Path to SQLite database file | Yes |
| brave-search | `BRAVE_API_KEY` | Brave Search API key | Yes |
| slack | `SLACK_BOT_TOKEN` | Slack bot OAuth token | Yes |
| slack | `SLACK_TEAM_ID` | Slack workspace ID | Yes |
| playwright | -- | None required | -- |
| puppeteer | -- | None required | -- |
| filesystem | -- | None required | -- |
| memory | -- | None required | -- |
| jira | `JIRA_URL` | Jira instance URL | Yes |
| jira | `JIRA_EMAIL` | Jira account email | Yes |
| jira | `JIRA_API_TOKEN` | Jira API token | Yes |
| linear | `LINEAR_API_KEY` | Linear personal API key | Yes |
| notion | `NOTION_API_KEY` | Notion integration token | Yes |
| datadog | `DD_API_KEY` | Datadog API key | Yes |
| datadog | `DD_APP_KEY` | Datadog application key | Yes |

## Generated .mcp.json Template

When generating the final `.mcp.json`, use this structure:

```json
{
  "mcpServers": {
    // Include only servers whose trigger signals matched
    // Use ${ENV_VAR} syntax for all secrets
    // Add comments in the scaffold output explaining each server
  }
}
```

Always generate a corresponding `.env.example` or document required environment variables when MCP servers need them.

**Note on package names**: MCP server packages below use placeholder names. Before generating `.mcp.json`, verify the package exists with `npm view <package-name>`. Known valid prefixes: `@modelcontextprotocol/server-*`, `@anthropic-ai/mcp-server-*`. Community servers may use different scopes. When in doubt, check https://registry.modelcontextprotocol.io or npm for the current package name.

## Integration Servers (User-Level)

These servers are detected by Cortex Discover and configured at user-level (`~/.claude/.mcp.json`) rather than project-level. They apply to all projects.

---

### jira
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-jira"]`
- **Trigger when**:
  - `discover-integrations.sh` detects Jira signals (env vars, CLI, config files)
  - Jira issue keys found in branch names (e.g., `JIRA-\d+`, `PROJ-\d+`)
  - `JIRA_API_TOKEN` environment variable set
  - `JIRA_URL` environment variable set
  - `~/.jira.d/` directory exists
  - `jira` CLI installed and on PATH
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Create, read, update, and transition Jira issues directly from Claude Code. View sprint boards, search issues with JQL, add comments, and link issues to code changes. Enables full Jira workflow without leaving the terminal.
- **When to skip**: Team does not use Jira for project management. If using Linear, Asana, or another issue tracker, this server is not relevant.
- **Security notes**: Requires Jira API token and associated email. Use API tokens scoped to the minimum required permissions. Never use admin-level tokens. Tokens are tied to a specific Atlassian account.
- **Level note**: User-level MCP server -- applies to all projects. Configure in `~/.claude/.mcp.json`.
- **Env vars needed**: `JIRA_URL` -- Jira instance URL (e.g., `https://mycompany.atlassian.net`), `JIRA_EMAIL` -- Jira account email, `JIRA_API_TOKEN` -- Jira API token
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

### linear
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-linear"]`
- **Trigger when**:
  - `LINEAR_API_KEY` environment variable set
  - `linear` CLI installed and on PATH
  - Git branch names matching Linear issue patterns (e.g., `LIN-\d+`, `ENG-\d+`)
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Create, read, update, and search Linear issues. View projects, cycles, and team workflows. Transition issue states and add comments directly from Claude Code.
- **When to skip**: Team does not use Linear. If using Jira or another issue tracker, this server is not relevant.
- **Security notes**: Requires Linear personal API key. The key grants access to all issues the user can see in Linear. Use personal keys, not workspace-level keys.
- **Level note**: User-level MCP server -- applies to all projects. Configure in `~/.claude/.mcp.json`.
- **Env vars needed**: `LINEAR_API_KEY` -- Linear personal API key
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
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-notion"]`
- **Trigger when**:
  - `NOTION_API_KEY` environment variable set
  - `NOTION_TOKEN` environment variable set
  - References to Notion in project documentation
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Search pages and databases, create and update pages, query database views, manage comments, and access knowledge base content directly from Claude Code.
- **When to skip**: Team does not use Notion. If documentation and knowledge management lives in Confluence, Google Docs, or the repo itself, skip this.
- **Security notes**: Requires Notion internal integration token. Create a dedicated integration in Notion's developer settings. The integration only has access to pages explicitly shared with it -- this provides good security scoping.
- **Level note**: User-level MCP server -- applies to all projects. Configure in `~/.claude/.mcp.json`.
- **Env vars needed**: `NOTION_API_KEY` -- Notion internal integration token
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

### datadog
- **Transport**: stdio
- **Command**: `npx`
- **Args**: `["-y", "@anthropic-ai/mcp-server-datadog"]`
- **Trigger when**:
  - `DD_API_KEY` environment variable set
  - `DD_APP_KEY` environment variable set
  - `datadog-ci` CLI installed and on PATH
  - `dd-trace` or `datadog-lambda-js` in project dependencies
  - `datadog.yaml` configuration file exists
- **Confidence**: recommended (when detected by Discover)
- **What it provides**: Query metrics, view dashboards, search logs, list monitors, and inspect APM traces from Claude Code. Enables data-driven debugging and performance analysis without leaving the terminal.
- **When to skip**: Team does not use Datadog. If using Prometheus/Grafana, New Relic, or another monitoring stack, this server is not relevant.
- **Security notes**: Requires Datadog API and application keys. API keys can send data to Datadog; application keys grant read access to dashboards and metrics. Use keys with minimum required scopes and never use keys with admin permissions.
- **Level note**: User-level MCP server -- applies to all projects. Configure in `~/.claude/.mcp.json`.
- **Env vars needed**: `DD_API_KEY` -- Datadog API key, `DD_APP_KEY` -- Datadog application key
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
