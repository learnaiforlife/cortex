# Claude Code File Format Specifications

Complete reference for every Claude Code configuration file type. Use these exact formats when generating scaffold files.

---

## CLAUDE.md

**Location**: Project root (`./CLAUDE.md`)
**Also supported**: `.claude/CLAUDE.md`, nested `CLAUDE.md` in subdirectories (scoped to that directory)

**Format**: Plain Markdown. No frontmatter required.

**Purpose**: Project context that Claude reads automatically at session start. This is the single most important file for AI-assisted development.

**Best practices**:
- Keep it concise and high-signal. Every line should earn its place.
- Focus on what an AI agent needs to know, not what a human developer already knows.
- Include commands that can be copy-pasted and run without modification.
- Avoid duplicating information available in package.json, tsconfig.json, etc.
- Update it as the project evolves.

**Recommended structure**:

```markdown
# Project Name

Brief one-liner description.

## Architecture

- `src/` - Source code
- `src/components/` - React components
- `src/lib/` - Shared utilities
- `test/` - Test files

## Development Commands

```bash
npm run dev          # Start dev server
npm test             # Run all tests
npm run test:watch   # Watch mode
npm run build        # Production build
npm run lint         # Lint check
npm run lint:fix     # Auto-fix lint issues
```

## Key Conventions

- Use TypeScript strict mode
- Prefer named exports over default exports
- Tests live next to source files as `*.test.ts`
- Use `vitest` for testing, not jest

## Important Patterns

- All API routes use the `/api/v1/` prefix
- Database access goes through `src/lib/db.ts`
- Environment variables are validated in `src/lib/env.ts`

## Things to Avoid

- Do not modify generated files in `src/generated/`
- Do not import from `node_modules` directly
- Never commit `.env` files
```

**Anti-patterns to avoid**:
- Walls of text with no structure
- Listing every file in the project
- Including full API documentation (link to it instead)
- Repeating information from README.md

---

## Agents (.claude/agents/{name}.md)

**Location**: `.claude/agents/{name}.md`
**Invocation**: `claude --agent {name}` or via `/agent {name}` in session

**Format**: Markdown with YAML frontmatter.

**Frontmatter fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Lowercase with hyphens, max 64 chars. Display name for the agent. |
| `description` | string | Yes | When/why to use this agent. Drives auto-invocation suggestions. |
| `tools` | string[] | No | Allowlist of tools the agent can use. If omitted, inherits all available tools. |
| `disallowedTools` | string[] | No | Blocklist of tools. Opposite of `tools`. Cannot be used with `tools`. |
| `model` | string | No | Model to use: `sonnet`, `opus`, `haiku`, or `inherit` (default). |
| `permissionMode` | string | No | `default`, `acceptEdits`, `fullAuto`, or `plan`. Controls permission prompts. |
| `maxTurns` | number | No | Maximum number of agent turns before stopping. |
| `skills` | string[] | No | List of skill names this agent can invoke. |
| `mcpServers` | string[] | No | List of MCP server names (from `.mcp.json`) this agent can access. |
| `hooks` | object | No | Agent-specific hooks (same format as settings.json hooks). |
| `memory` | string | No | Path to a memory file the agent reads/writes for persistence. |
| `background` | boolean | No | If true, agent runs in background without interactive prompts. |
| `effort` | string | No | Reasoning effort: `low`, `medium`, `high`. |
| `isolation` | string | No | `full` (separate context) or `shared` (shares parent context). |

**Complete example**:

```yaml
---
name: test-runner
description: Run tests, analyze failures, and fix broken tests. Use when tests are failing or need to be written.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
model: sonnet
permissionMode: acceptEdits
maxTurns: 20
---

You are a test-focused development agent. Your job is to run tests, diagnose failures, and fix them.

## Workflow

1. Run the test suite to identify failures
2. Read failing test files and the source code they test
3. Determine if the bug is in the test or the source
4. Fix the issue
5. Re-run tests to confirm the fix
6. Report what you changed and why

## Rules

- Always run tests before and after making changes
- Prefer fixing source code over modifying tests (unless the test is wrong)
- Never skip or disable tests to make the suite pass
- If a test is flaky, note it but don't delete it
```

**More agent examples**:

```yaml
---
name: code-reviewer
description: Review code changes for quality, security, and best practices
tools:
  - Read
  - Glob
  - Grep
  - Bash
model: opus
maxTurns: 15
---

Review all staged changes. Check for:
- Security vulnerabilities
- Performance issues
- Code style violations
- Missing error handling
- Test coverage gaps

Provide actionable feedback with specific file and line references.
```

```yaml
---
name: docs-writer
description: Generate and update documentation based on code changes
tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
model: sonnet
---

You write clear, accurate documentation. Read the codebase and generate or update docs.

- Write for the target audience (developers, users, ops)
- Include code examples that actually work
- Keep docs close to the code they describe
```

---

## Skills (.claude/skills/{name}/SKILL.md)

**Location**: `.claude/skills/{name}/SKILL.md`
**Invocation**: `/{name}` in session, or auto-invoked based on description match

**Format**: Markdown with YAML frontmatter.

**Frontmatter fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Skill name, used as the slash command. |
| `description` | string | Yes | When to invoke this skill. Critical for auto-invocation accuracy. |
| `argument-hint` | string | No | Hint shown for arguments, e.g., `"[file-path]"` or `"<url>"`. |
| `disable-model-invocation` | boolean | No | If true, model cannot auto-invoke this skill. User must use `/name` explicitly. |
| `user-invocable` | boolean | No | If false, skill can only be invoked by other skills/agents, not directly by user. Default true. |
| `allowed-tools` | string | No | Comma-separated list of tools the skill can use, e.g., `"Bash, Read, Write"`. |
| `model` | string | No | Model override: `sonnet`, `opus`, `haiku`. |
| `effort` | string | No | Reasoning effort: `low`, `medium`, `high`. |
| `context` | string[] | No | List of file paths to always include in context when skill runs. |
| `agent` | string | No | Name of an agent to delegate execution to. |
| `hooks` | object | No | Skill-specific hooks. |
| `paths` | string[] | No | Glob patterns for files relevant to this skill (for context scoping). |
| `shell` | string | No | Shell to use for Bash commands, e.g., `"/bin/zsh"`. |

**Complete example**:

```yaml
---
name: add-component
description: Create a new React component with tests and storybook. Use when asked to add a UI component.
argument-hint: "<ComponentName>"
allowed-tools: Read, Write, Bash, Glob
model: sonnet
context:
  - src/components/Button/Button.tsx
  - src/components/Button/Button.test.tsx
---

Create a new React component following the project's established patterns.

## Steps

1. Check existing components in `src/components/` for patterns
2. Create the component file: `src/components/{Name}/{Name}.tsx`
3. Create the test file: `src/components/{Name}/{Name}.test.tsx`
4. Create the story file: `src/components/{Name}/{Name}.stories.tsx`
5. Export from `src/components/index.ts`
6. Run tests to verify

## Template

Use the same structure as the Button component (provided in context).
Follow the project's TypeScript and styling conventions.
```

**Skill description best practices**:
- Start with a verb: "Create...", "Run...", "Analyze..."
- Include trigger phrases: "Use when asked to...", "Trigger on..."
- Be specific enough to avoid false triggers but broad enough to catch valid ones

---

## Rules (.claude/rules/{name}.md)

**Location**: `.claude/rules/{name}.md`
**Activation**: Always active, or conditionally via `paths` glob in frontmatter

**Format**: Plain Markdown with optional YAML frontmatter.

**Frontmatter fields** (all optional):

| Field | Type | Description |
|-------|------|-------------|
| `paths` | string[] | Glob patterns. Rule only activates when working with matching files. |

**Example: Always-active rule**:

```markdown
# TypeScript Conventions

- Use `interface` for object shapes, `type` for unions and intersections
- Prefer `const` over `let`. Never use `var`
- Use explicit return types on exported functions
- Handle errors with try/catch, never silently swallow exceptions
- Use `unknown` instead of `any` wherever possible
```

**Example: Path-scoped rule**:

```yaml
---
paths:
  - "src/api/**/*.ts"
  - "src/routes/**/*.ts"
---

# API Route Rules

- All routes must validate input with zod schemas
- Return proper HTTP status codes (don't use 200 for errors)
- Log all errors with request ID for traceability
- Rate limit all public endpoints
- Never expose internal error details in responses
```

**Example: Test-scoped rule**:

```yaml
---
paths:
  - "**/*.test.ts"
  - "**/*.spec.ts"
---

# Testing Rules

- Use `describe` blocks to group related tests
- Test names should describe behavior, not implementation: "should return 404 when user not found"
- Use `beforeEach` for shared setup, not repeated code
- Mock external services, never make real network calls in tests
- Assert on behavior, not implementation details
```

---

## Hooks (.claude/settings.json or .claude/settings.local.json)

**Location**: `.claude/settings.json` (committed) or `.claude/settings.local.json` (gitignored)
**Format**: JSON

**Hook events** (all available lifecycle points):

| Event | When it fires | Common uses |
|-------|--------------|-------------|
| `SessionStart` | When a Claude session begins | Setup checks, environment validation |
| `UserPromptSubmit` | When user submits a prompt (before processing) | Input validation, logging |
| `PreToolUse` | Before a tool is executed | Safety checks, approval gates |
| `PermissionRequest` | When Claude requests permission for an action | Custom approval logic |
| `PostToolUse` | After a tool completes successfully | Validation, formatting, logging |
| `PostToolUseFailure` | After a tool fails | Error handling, retry logic |
| `Notification` | When Claude sends a notification | Alerts, external integrations |
| `SubagentStart` | When a subagent is spawned | Tracking, resource allocation |
| `SubagentStop` | When a subagent finishes | Cleanup, result aggregation |
| `ConfigChange` | When configuration changes | Reloading, validation |
| `FileChanged` | When a file in the workspace changes | Auto-formatting, rebuild triggers |
| `CwdChanged` | When the working directory changes | Context updates |
| `PreCompact` | Before context compaction | Saving important context |
| `PostCompact` | After context compaction | Restoring important context |
| `Stop` | When the session ends | Cleanup, final reports |

**Hook structure**:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex-pattern",
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.sh $FILE_PATH"
          }
        ]
      }
    ]
  }
}
```

**`matcher` field**: A regex pattern to match against the tool name (for PreToolUse/PostToolUse) or other event-specific data. Use `".*"` to match everything.

**`type` field**: Supported types: `"command"` (run shell command), `"prompt"` (single-turn LLM decision), `"agent"` (multi-turn subagent), `"http"` (POST to endpoint).

**`command` field**: Shell command to execute. Environment variables available:
- `$FILE_PATH` - Path of the file being operated on
- `$TOOL_NAME` - Name of the tool being used
- `$SESSION_ID` - Current session identifier

**Exit codes**:
- Exit 0: Hook passes, operation continues
- Exit 2: Hook blocks the operation (for Pre hooks)
- Any other non-zero: Hook fails, logged as warning

**Complete settings.json example**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/check-file-protection.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/validate-bash-command.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/auto-format.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/check-env.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/session-summary.sh"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": []
  }
}
```

---

## MCP Configuration (.mcp.json)

**Location**: Project root (`.mcp.json`) or `~/.claude/.mcp.json` (global)
**Format**: JSON

**Transport types**:

| Type | Description | Use case |
|------|-------------|----------|
| `stdio` | Communicates via stdin/stdout | Local CLI tools, npm packages |
| `http` | HTTP-based communication | Remote/cloud MCP servers |
| `sse` | Server-Sent Events | Streaming responses from remote servers |
| `ws` | WebSocket | Bidirectional real-time communication |

**stdio server format**:

```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@package/server-name"],
      "env": {
        "API_KEY": "value"
      }
    }
  }
}
```

**http server format**:

```json
{
  "mcpServers": {
    "server-name": {
      "type": "http",
      "url": "https://mcp.example.com/mcp"
    }
  }
}
```

**sse server format**:

```json
{
  "mcpServers": {
    "server-name": {
      "type": "sse",
      "url": "https://mcp.example.com/sse"
    }
  }
}
```

**ws server format**:

```json
{
  "mcpServers": {
    "server-name": {
      "type": "ws",
      "url": "wss://mcp.example.com/ws"
    }
  }
}
```

**Complete .mcp.json example**:

```json
{
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@bytebase/dbhub", "--dsn", "${DATABASE_URL}"]
    },
    "sentry": {
      "type": "http",
      "url": "https://mcp.sentry.dev/mcp",
      "env": {
        "SENTRY_AUTH_TOKEN": "${SENTRY_AUTH_TOKEN}"
      }
    },
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./src", "./docs"]
    }
  }
}
```

**Environment variable interpolation**: Use `${VAR_NAME}` syntax in `env` values or `args` to reference environment variables. These are resolved at runtime from the shell environment.

**Security notes**:
- Never hardcode secrets in `.mcp.json`. Always use environment variable references.
- Add `.mcp.json` to `.gitignore` if it contains project-specific server URLs or tokens.
- Alternatively, use `${VAR}` syntax and commit `.mcp.json` safely.
