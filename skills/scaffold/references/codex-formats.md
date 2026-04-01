# OpenAI Codex File Format Specifications

Complete reference for Codex configuration files. Use these exact formats when generating Codex scaffold files.

---

## Overview

Codex has a deliberately simple configuration model. There is essentially one file:

| Concept | Codex Equivalent |
|---------|-----------------|
| CLAUDE.md | `AGENTS.md` |
| Agents | Sections within `AGENTS.md` |
| Skills | Sections within `AGENTS.md` |
| Rules | Sections within `AGENTS.md` |
| Hooks | Not supported |
| MCP | Not supported |

Codex uses a single `AGENTS.md` file that combines project context, conventions, agent instructions, and behavioral rules into one comprehensive document. There is no separation of concerns into multiple files -- everything goes into `AGENTS.md`.

---

## AGENTS.md

**Location**: Project root (`./AGENTS.md`)
**Format**: Plain Markdown. No frontmatter.

**Purpose**: The sole configuration file for OpenAI Codex. Must be comprehensive since there are no supplementary files. This is Codex's equivalent of CLAUDE.md + agents + rules + skills combined into a single document.

**Key differences from CLAUDE.md**:
- Must be more comprehensive (it's the ONLY file Codex reads)
- Should include explicit agent behavioral instructions
- Must contain all rules inline (no separate rules directory)
- Should be well-structured with clear sections since it carries all context
- No frontmatter or special syntax -- just Markdown

**Recommended structure and sections**:

### Section 1: Project Overview

```markdown
# Project Name

## Overview

One to three sentence description of what the project does, its primary purpose,
and the problem it solves.

**Tech Stack**: TypeScript, React, Node.js, PostgreSQL, Redis
**Package Manager**: pnpm
**Node Version**: 20+
```

### Section 2: Architecture

```markdown
## Architecture

### Directory Structure

```
project-root/
  src/
    api/           # Express route handlers
    components/    # React UI components
    hooks/         # Custom React hooks
    lib/           # Shared utilities and helpers
    services/      # Business logic layer
    types/         # TypeScript type definitions
  test/
    unit/          # Unit tests
    integration/   # Integration tests
    fixtures/      # Test data
  scripts/         # Build and deployment scripts
  docs/            # Documentation
```

### Key Modules

- **src/api/**: REST API endpoints. Each file exports an Express router.
- **src/services/**: Business logic. Services are injected into API handlers.
- **src/lib/db.ts**: Database connection and query builder.
- **src/lib/cache.ts**: Redis cache wrapper.
```

### Section 3: Development Commands

```markdown
## Development Commands

```bash
# Development
pnpm dev              # Start dev server with hot reload
pnpm dev:api          # Start API server only
pnpm dev:web          # Start frontend only

# Testing
pnpm test             # Run all tests
pnpm test:unit        # Run unit tests only
pnpm test:integration # Run integration tests
pnpm test:watch       # Run tests in watch mode
pnpm test:coverage    # Run tests with coverage report

# Building
pnpm build            # Production build
pnpm build:check      # Type-check without emitting

# Code Quality
pnpm lint             # Run ESLint
pnpm lint:fix         # Auto-fix lint issues
pnpm format           # Run Prettier
pnpm typecheck        # TypeScript type checking
```
```

### Section 4: Conventions

```markdown
## Conventions

### Code Style

- Use TypeScript strict mode (`"strict": true` in tsconfig.json)
- Prefer `interface` for object shapes, `type` for unions/intersections
- Use `const` by default. Use `let` only when reassignment is needed. Never use `var`.
- Prefer named exports over default exports
- Use explicit return types on all exported functions
- Handle all errors explicitly -- never silently catch and ignore

### File Naming

- Components: PascalCase (`UserCard.tsx`)
- Utilities: camelCase (`formatDate.ts`)
- Tests: Same name with `.test.ts` suffix (`formatDate.test.ts`)
- Types: PascalCase with `.types.ts` suffix (`User.types.ts`)
- Constants: SCREAMING_SNAKE_CASE for values, PascalCase for files

### Git Conventions

- Commit messages: `type(scope): description` (conventional commits)
- Branch names: `feature/description`, `fix/description`, `chore/description`
- Always create feature branches from `main`
- Squash merge feature branches

### Testing Requirements

- All new features must include tests
- Minimum 80% code coverage for new code
- Unit tests for business logic
- Integration tests for API endpoints
- Use `vitest` as the test runner
- Mock external services, never make real network calls in tests
```

### Section 5: Agent Instructions

```markdown
## Agent Instructions

### General Behavior

- Always read relevant files before making changes
- Run tests after every code change to verify correctness
- Never modify generated files in `src/generated/`
- Never modify lock files (`pnpm-lock.yaml`) directly
- Never commit secrets, API keys, or credentials
- Ask for clarification rather than making assumptions about requirements

### When Writing Code

- Follow existing patterns in the codebase
- Check for similar implementations before creating new abstractions
- Add proper error handling to all new code
- Include JSDoc comments for public APIs
- Keep functions small and focused (under 50 lines)

### When Fixing Bugs

- Reproduce the bug first with a failing test
- Fix the root cause, not the symptom
- Verify the fix doesn't break other tests
- Document what was wrong and why the fix works

### When Reviewing Code

- Check for security vulnerabilities (SQL injection, XSS, etc.)
- Verify error handling is comprehensive
- Ensure test coverage for new code paths
- Look for performance issues (N+1 queries, unnecessary re-renders)
- Confirm API contracts match documentation

### File Protection

Do NOT modify these files without explicit user confirmation:
- `package.json` (dependency changes)
- `tsconfig.json` (compiler settings)
- `.env*` files (environment configuration)
- `scripts/deploy.sh` (deployment pipeline)
- Database migration files once committed
```

### Section 6: API Documentation (if applicable)

```markdown
## API Patterns

### Request/Response Format

All API responses follow this structure:

```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
}
```

### Authentication

- All endpoints require Bearer token authentication except those under `/api/public/`
- Tokens are validated via the `authMiddleware` in `src/api/middleware/auth.ts`
- User context is available as `req.user` after authentication

### Error Handling

- Use `AppError` class from `src/lib/errors.ts` for all business errors
- The global error handler in `src/api/middleware/errorHandler.ts` catches and formats errors
- Log all 5xx errors with full stack traces
- Never expose internal error details in API responses
```

---

## Complete AGENTS.md Template

Below is a minimal but complete template that can be adapted for any project:

```markdown
# Project Name

## Overview

Brief description of the project, its purpose, and primary functionality.

**Tech Stack**: [languages, frameworks, databases]
**Package Manager**: [npm/pnpm/yarn]

## Architecture

```
project-root/
  src/           # Source code
  test/          # Tests
  scripts/       # Build/deploy scripts
  docs/          # Documentation
```

### Key Modules

- **src/[module]**: What it does and why

## Development Commands

```bash
npm run dev    # Start development server
npm test       # Run tests
npm run build  # Build for production
npm run lint   # Run linter
```

## Conventions

- [Code style rules]
- [File naming patterns]
- [Testing requirements]
- [Git workflow]

## Agent Instructions

### Do

- Read files before editing
- Run tests after changes
- Follow existing patterns
- Handle errors explicitly

### Do Not

- Modify generated files
- Commit secrets or credentials
- Skip tests
- Make assumptions about requirements
```

---

## Converting Claude Code Files to AGENTS.md

When converting from a Claude Code setup to Codex:

### CLAUDE.md -> AGENTS.md Core Sections

Copy the content from CLAUDE.md into the Overview, Architecture, Commands, and Conventions sections of AGENTS.md.

### Agents -> Agent Instructions Section

Convert each agent's system prompt into a subsection under "Agent Instructions":

**Claude Code** (`.claude/agents/test-runner.md`):
```yaml
---
name: test-runner
description: Run tests, analyze failures, and fix broken tests
---
You are a test-focused agent...
```

**AGENTS.md equivalent**:
```markdown
## Agent Instructions

### When Running Tests

- Run the full test suite first to identify all failures
- Read failing test files and the source code they test
- Determine if the bug is in the test or the source
- Fix the issue in the appropriate file
- Re-run tests to confirm the fix
- Never skip or disable tests to make the suite pass
```

### Rules -> Conventions Section

Merge all rule content into the Conventions section:

**Claude Code** (`.claude/rules/typescript.md`):
```markdown
Use interface for object shapes, type for unions...
```

**AGENTS.md equivalent**:
```markdown
## Conventions

### TypeScript

- Use `interface` for object shapes, `type` for unions and intersections
- ...
```

### Skills -> Agent Instructions Subsections

Convert skill instructions into behavioral subsections:

**Claude Code** (`.claude/skills/add-component/SKILL.md`):
```yaml
---
name: add-component
description: Create a new React component
---
Steps to create a component...
```

**AGENTS.md equivalent**:
```markdown
### When Creating Components

1. Create `src/components/{Name}/{Name}.tsx`
2. Create `src/components/{Name}/{Name}.test.tsx`
3. Add export to `src/components/index.ts`
4. Follow the Button component as a reference pattern
```

### Hooks -> Not Representable

Codex has no hook system. Document critical safety rules as explicit instructions under "Agent Instructions" with "Do Not" subsections. These are guidelines only and cannot be enforced programmatically.

### MCP -> Not Representable

Codex does not support MCP. Any tool integrations must be described as manual instructions or scripts the agent can run via shell commands.

---

## Best Practices for AGENTS.md

1. **Be comprehensive**: This is the ONLY file Codex reads. Do not assume it has access to other configuration files.
2. **Be explicit**: Spell out every convention. Do not rely on Codex inferring patterns.
3. **Use examples**: Show code examples for conventions rather than just describing them.
4. **Prioritize the "Agent Instructions" section**: This is what makes Codex effective. Spend time making behavioral rules clear and actionable.
5. **Keep it updated**: Stale AGENTS.md leads to Codex making incorrect assumptions.
6. **Structure with clear headers**: Codex navigates the file by headers. Use a consistent hierarchy.
7. **Include file protection rules**: Explicitly list files that should never be modified without confirmation.
8. **Add debugging workflows**: Tell Codex how to approach common debugging scenarios in your project.
