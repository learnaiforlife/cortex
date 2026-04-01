# Cursor File Format Specifications

Complete reference for all Cursor configuration file types. Use these exact formats when generating Cursor scaffold files.

---

## Overview

Cursor supports a more limited set of AI configuration files compared to Claude Code:

| Concept | Cursor Equivalent |
|---------|-------------------|
| CLAUDE.md | `.cursor/rules/project.mdc` (or multiple .mdc files) |
| Agents | No native equivalent. Convert to rules (.mdc files). |
| Skills | No native equivalent. Convert to rules (.mdc files). |
| Rules | `.cursor/rules/{name}.mdc` |
| Hooks | No native equivalent. Cannot be directly represented. |
| MCP | `.cursor/mcp.json` |

---

## Rules (.cursor/rules/{name}.mdc)

**Location**: `.cursor/rules/{name}.mdc`
**Format**: Markdown with YAML frontmatter. File extension MUST be `.mdc` (not `.md`).

**Frontmatter fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | Yes | Description of the rule. Used for context matching when `alwaysApply` is false. |
| `alwaysApply` | boolean | Yes | If `true`, rule is always active. If `false`, only activates when relevant files are open. |
| `globs` | string[] | No | Glob patterns for file-scoped activation. Only used when `alwaysApply: false`. |

**Rule activation modes**:

1. **Always active** (`alwaysApply: true`): Rule content is included in every prompt. Use for project-wide conventions.
2. **Glob-scoped** (`alwaysApply: false` + `globs`): Rule activates only when the user is working with files matching the glob patterns.
3. **Agent-selected** (`alwaysApply: false`, no `globs`): Cursor's AI decides when the rule is relevant based on the description.

**Example: Project-wide rule (always active)**:

```yaml
---
description: "Core project conventions and architecture overview"
alwaysApply: true
---

# Project Conventions

This is a TypeScript monorepo using pnpm workspaces.

## Architecture

- `packages/core/` - Shared business logic
- `packages/web/` - Next.js frontend
- `packages/api/` - Express API server
- `packages/shared/` - Shared types and utilities

## Commands

```bash
pnpm dev          # Start all services
pnpm test         # Run all tests
pnpm build        # Build all packages
pnpm lint         # Lint all packages
```

## Key Conventions

- Use TypeScript strict mode in all packages
- Prefer named exports
- Use zod for runtime validation
- All API responses use the `ApiResponse<T>` wrapper type
```

**Example: Glob-scoped rule (file-type specific)**:

```yaml
---
description: "React component development conventions"
alwaysApply: false
globs: ["src/components/**/*.tsx", "src/components/**/*.ts"]
---

# React Component Rules

- Use functional components with TypeScript interfaces for props
- Name component files in PascalCase: `Button.tsx`, `UserCard.tsx`
- Co-locate tests: `Button.test.tsx` next to `Button.tsx`
- Co-locate styles: `Button.module.css` next to `Button.tsx`
- Export component as named export, not default
- Use `React.FC` only when children are explicitly needed
- Prefer composition over prop drilling

## Component Template

```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary';
}

export function Button({ label, onClick, variant = 'primary' }: ButtonProps) {
  return (
    <button className={styles[variant]} onClick={onClick}>
      {label}
    </button>
  );
}
```
```

**Example: Agent-selected rule (contextually activated)**:

```yaml
---
description: "Database migration and schema change guidelines"
alwaysApply: false
---

# Database Migration Rules

When creating or modifying database schemas:

1. Always create a migration file, never modify the schema directly
2. Migrations must be reversible (include both `up` and `down`)
3. Test migrations against a copy of production data
4. Never drop columns in production - deprecate first, remove in a later release
5. Add indexes for any column used in WHERE clauses or JOINs
6. Use `snake_case` for all database identifiers
```

**Example: API-scoped rule**:

```yaml
---
description: "API endpoint development patterns and security requirements"
alwaysApply: false
globs: ["src/api/**/*.ts", "src/routes/**/*.ts"]
---

# API Development Rules

- All endpoints must validate input using zod schemas
- Use proper HTTP status codes:
  - 200 for successful GET/PUT
  - 201 for successful POST (creation)
  - 204 for successful DELETE
  - 400 for validation errors
  - 401 for authentication failures
  - 403 for authorization failures
  - 404 for not found
  - 500 for unexpected server errors
- Never expose stack traces in production responses
- All endpoints must be authenticated unless explicitly marked public
- Log all requests with correlation IDs
- Rate limit public endpoints
```

---

## Converting Claude Code Concepts to Cursor Rules

Since Cursor lacks agents, skills, and hooks, these must be represented as rules:

### Agents -> Rules

Convert agent system prompts into `.mdc` rules with `alwaysApply: false` and a descriptive `description` field so Cursor activates them contextually.

**Claude Code agent**:
```yaml
# .claude/agents/test-runner.md
---
name: test-runner
description: Run tests, analyze failures, and fix broken tests
tools: [Read, Glob, Grep, Bash, Edit]
---
You are a test-focused agent. Run tests, diagnose failures, fix them.
```

**Cursor equivalent**:
```yaml
# .cursor/rules/test-runner.mdc
---
description: "Guidelines for running tests, analyzing failures, and fixing broken tests"
alwaysApply: false
globs: ["**/*.test.ts", "**/*.spec.ts", "test/**/*"]
---

# Test Runner Guidelines

When working with tests:
1. Run the full test suite first to identify failures
2. Read failing test files and the source they test
3. Determine if the bug is in the test or the source
4. Fix the issue
5. Re-run tests to confirm
6. Prefer fixing source over modifying tests (unless the test is wrong)
7. Never skip or disable tests to make the suite pass
```

### Skills -> Rules

Convert skill instructions into `.mdc` rules. The `argument-hint` and interactive aspects are lost.

**Claude Code skill**:
```yaml
# .claude/skills/add-component/SKILL.md
---
name: add-component
description: Create a new React component with tests
argument-hint: "<ComponentName>"
---
Create component following project patterns...
```

**Cursor equivalent**:
```yaml
# .cursor/rules/add-component.mdc
---
description: "How to create new React components with proper structure, tests, and stories"
alwaysApply: false
globs: ["src/components/**/*"]
---

# Creating New Components

When asked to create a new component:
1. Create `src/components/{Name}/{Name}.tsx`
2. Create `src/components/{Name}/{Name}.test.tsx`
3. Create `src/components/{Name}/{Name}.stories.tsx`
4. Add export to `src/components/index.ts`
5. Follow existing patterns (see Button component)
```

### Hooks -> Not Representable

Cursor has no hook system. Document hook behaviors as rules that Cursor will follow as guidelines (not enforced):

```yaml
# .cursor/rules/safety-guidelines.mdc
---
description: "Safety guidelines for file modifications and command execution"
alwaysApply: true
---

# Safety Guidelines

These are project safety rules (note: these are guidelines, not enforced hooks):

- Before editing files in `src/generated/`, confirm with the user
- After editing any TypeScript file, run `npx tsc --noEmit` to check types
- Never run `rm -rf` commands
- Never modify `.env` files
- Always run `npm test` after making code changes
```

---

## MCP Configuration (.cursor/mcp.json)

**Location**: `.cursor/mcp.json`
**Format**: JSON. Same structure as Claude Code's `.mcp.json`.

**Example**:

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
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./src"]
    }
  }
}
```

**Differences from Claude Code's .mcp.json**:
- Location is `.cursor/mcp.json` instead of project root `.mcp.json`
- Same JSON structure and server definitions
- Same transport types supported: `stdio`, `http`, `sse`, `ws`
- Environment variable interpolation works the same way (`${VAR_NAME}`)

---

## Cursor Settings (.cursor/settings.json)

**Location**: `.cursor/settings.json`
**Format**: JSON

This file can contain Cursor-specific editor settings but is NOT the place for AI rules (those go in `.mdc` files).

```json
{
  "cursor.chat.defaultModel": "claude-sonnet-4-20250514",
  "cursor.composer.defaultModel": "claude-sonnet-4-20250514"
}
```

---

## File Naming Conventions

| File Type | Naming Pattern | Example |
|-----------|---------------|---------|
| Project rules | `project.mdc` | `.cursor/rules/project.mdc` |
| Language rules | `{language}.mdc` | `.cursor/rules/typescript.mdc` |
| Framework rules | `{framework}.mdc` | `.cursor/rules/react.mdc` |
| Domain rules | `{domain}.mdc` | `.cursor/rules/api.mdc` |
| Workflow rules | `{workflow}.mdc` | `.cursor/rules/testing.mdc` |

Keep rule file names lowercase with hyphens. Use descriptive names that indicate scope.
