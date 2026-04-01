---
name: scaffold-monorepo
description: "Monorepo-specific scaffold variant. Handles turbo.json, nx.json, lerna.json, and pnpm-workspace.yaml projects with scoped agents and per-package CLAUDE.md files."
---

# Monorepo Scaffold Variant

This variant overrides Steps 2, 3, and 5 of the main scaffold flow for monorepo projects. Steps 4 and 6 are extended with monorepo-specific checks. Steps 1, 7-9 remain unchanged -- refer to the main `SKILL.md` for those.

## When to Use This Variant

Activate this variant when any of these files exist in `REPO_DIR`:
- `turbo.json` --> Turborepo
- `nx.json` --> Nx
- `workspace.json` or `project.json` --> Nx (older config)
- `lerna.json` --> Lerna
- `pnpm-workspace.yaml` --> pnpm workspaces

Also activate if `package.json` has a `workspaces` field (Yarn/npm workspaces) without any of the above.

---

## Step 2: Monorepo Structure Detection (replaces main Step 2)

### 2A: Detect Monorepo Tool

```bash
# Detect the monorepo orchestrator
if [ -f "$REPO_DIR/turbo.json" ]; then
  MONOREPO_TOOL="turborepo"
elif [ -f "$REPO_DIR/nx.json" ]; then
  MONOREPO_TOOL="nx"
elif [ -f "$REPO_DIR/lerna.json" ]; then
  MONOREPO_TOOL="lerna"
elif [ -f "$REPO_DIR/pnpm-workspace.yaml" ]; then
  MONOREPO_TOOL="pnpm-workspaces"
else
  MONOREPO_TOOL="npm-workspaces"  # fallback: package.json workspaces field
fi
```

### 2B: Enumerate Workspace Packages

Read the workspace configuration to find all packages:

- **Turborepo / npm / Yarn**: Read `package.json` -> `workspaces` array (e.g., `["packages/*", "apps/*"]`). Expand globs.
- **pnpm**: Read `pnpm-workspace.yaml` -> `packages` array. Expand globs.
- **Nx**: Read `workspace.json` or scan for `project.json` files in subdirectories.
- **Lerna**: Read `lerna.json` -> `packages` array. Expand globs.

For each discovered package directory, read its `package.json` (or `project.json` for Nx).

### 2C: Classify Each Package

For each package, determine its type:

| Signal | Classification |
|--------|---------------|
| Directory starts with `apps/` or has a `dev` script with `next`, `vite`, `express`, `fastify` | **app** |
| Directory starts with `packages/ui` or `packages/components`, exports React/Vue components | **ui-library** |
| Directory starts with `packages/config`, `packages/tsconfig`, `packages/eslint` | **config** |
| Has only type exports, no runtime code | **types** |
| Has CLI bin entry in package.json | **tooling** |
| Everything else under `packages/` | **library** |

### 2D: Map Inter-Package Dependencies

For each package, read its `package.json` dependencies and devDependencies. Identify references to other workspace packages (they use workspace protocol `workspace:*` or match other package names). Build a dependency graph:

```
apps/web --> packages/ui, packages/config
apps/api --> packages/db, packages/config
packages/ui --> packages/config
```

Also run the heuristic pre-scanner at the root level:
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/analyze.sh" "$REPO_DIR" 2>/dev/null || echo "{}"
```

Store the combined output as PROJECT_PROFILE with an additional `monorepo` key containing tool, packages, and dependency graph.

---

## Step 3: Per-Package + Root Analysis (replaces main Step 3)

### 3A: Root-Level Analysis

Launch two subagents **in parallel**:

**Subagent 1: repo-analyzer** (root scope)
- Prompt: "Analyze the monorepo at `{REPO_DIR}`. This is a `{MONOREPO_TOOL}` monorepo with these packages: `{PACKAGE_LIST}`. Focus on: root-level CI/CD, Docker setup, shared config, monorepo commands, deployment pipeline. Return structured output."

**Subagent 2: skill-recommender** (root scope)
- **IMPORTANT**: You must resolve `${CLAUDE_SKILL_DIR}/references/official-plugins-catalog.md` and `${CLAUDE_SKILL_DIR}/references/mcp-catalog.md` to absolute paths and read their content BEFORE passing them in the subagent prompt (subagents cannot resolve `${CLAUDE_SKILL_DIR}`).
- Prompt: "Here is the ProjectProfile JSON: ```{PROJECT_PROFILE}```. This is a monorepo with `{N}` packages. The repo is at `{REPO_DIR}`. Here is the plugin catalog: ```{PLUGIN_CATALOG_CONTENT}```. Here is the MCP catalog: ```{MCP_CATALOG_CONTENT}```. Return recommendations considering all packages."

### 3B: Per-Package Lightweight Analysis

**While subagents run**, analyze each **app** package in the main thread (skip config/types packages):

For each app package, read:
- `{pkg}/package.json` -- framework, key dependencies, scripts
- `{pkg}/tsconfig.json` or equivalent -- build config
- `{pkg}/src/index.*` or `{pkg}/src/app/*` -- entry point pattern
- `{pkg}/test/` or `{pkg}/__tests__/` -- test framework detection

Build a per-package profile:
```json
{
  "name": "@acme/web",
  "type": "app",
  "framework": "next.js",
  "testFramework": "jest",
  "entryPoint": "src/app/layout.tsx",
  "keyDeps": ["next", "react", "@acme/ui"],
  "scripts": { "dev": "next dev", "build": "next build", "test": "jest" }
}
```

### 3C: Read Shared Context

Also read in the main thread:
- `{REPO_DIR}/README.md`
- `{REPO_DIR}/Makefile`, `Taskfile.yml`, or `justfile`
- `{REPO_DIR}/docker-compose.yml` (common in monorepos)
- `{REPO_DIR}/.github/workflows/` (CI config)

---

## Step 4: Check Existing Setup

Same as main SKILL.md Step 4. Additionally check for per-package CLAUDE.md files:

```bash
find "$REPO_DIR" -name "CLAUDE.md" -not -path "*/node_modules/*" 2>/dev/null
```

Preserve all existing per-package CLAUDE.md content during generation.

---

## Step 5: Monorepo-Aware Generation (replaces main Step 5)

### 5A: Claude Code Files

#### 1. Root `CLAUDE.md`

Must contain:
- Project name and one-line description
- Monorepo tool and how to use it
- Package overview table (name, type, framework, one-line purpose)
- Dependency graph summary (which packages depend on which)
- Root-level commands (build all, test all, lint all)
- Package-specific commands (how to run/test/build a single package)
- Shared conventions (import aliases, naming, coding standards)
- References to shared config packages

**Example for a Turborepo project:**

```markdown
# Acme Monorepo

Full-stack web application built as a Turborepo monorepo.

## Monorepo Structure

This is a **Turborepo** monorepo. All orchestration goes through `turbo`.

| Package | Type | Framework | Purpose |
|---------|------|-----------|---------|
| `apps/web` | app | Next.js 14 | Customer-facing web application |
| `apps/api` | app | Express | REST API server |
| `packages/ui` | library | React | Shared UI component library |
| `packages/config` | config | -- | Shared tsconfig and ESLint configs |

## Dependency Graph

apps/web --> packages/ui, packages/config
apps/api --> packages/config
packages/ui --> packages/config

## Development Commands

### Root-level (run everything)
- `turbo build` -- build all packages in dependency order
- `turbo test` -- run tests across all packages
- `turbo lint` -- lint all packages
- `turbo dev` -- start all dev servers

### Per-package
- `turbo build --filter=@acme/web` -- build only the web app
- `turbo test --filter=@acme/api` -- test only the API
- `cd apps/web && npm run dev` -- run web dev server directly

## Conventions

- All packages use TypeScript with shared tsconfig from `packages/config`
- Import workspace packages with `@acme/` prefix
- Do not import between apps -- only apps import from packages
- Shared components go in `packages/ui`, not duplicated across apps
```

#### 2. Per-Package `CLAUDE.md` Files

Generate a `CLAUDE.md` inside each **app** and **ui-library** package. These are loaded on-demand when Claude reads files in that directory.

Each per-package CLAUDE.md contains:
- Package purpose (one paragraph)
- Framework and key dependencies
- Package-specific commands (dev, test, build -- for this package only)
- Directory structure overview
- Key files and entry points
- Testing approach for this package
- What this package exports (for libraries) or serves (for apps)

**Example: `apps/web/CLAUDE.md`**

```markdown
# @acme/web

Next.js 14 customer-facing web application using the App Router.

## Key Dependencies
- next 14, react 18, @acme/ui (shared components)

## Commands
- `npm run dev` -- start dev server on port 3000
- `npm run build` -- production build
- `npm test` -- run Jest tests
- `npm run lint` -- ESLint check

## Structure
- `src/app/` -- Next.js App Router pages and layouts
- `src/components/` -- page-specific components (shared ones live in @acme/ui)
- `src/lib/` -- utilities, API client, hooks

## Testing
- Jest + React Testing Library
- Tests live next to source files as `*.test.tsx`
```

**Do NOT generate per-package CLAUDE.md for**: config packages, tsconfig packages, or packages with only type exports. These are too small to warrant their own context file.

**Exception**: If a package uses a fundamentally different stack (e.g., a Go service in a TypeScript monorepo), generate a full CLAUDE.md with extra detail about the different toolchain.

#### 3. `.claude/rules/monorepo-boundaries.md`

Always generate this rule:

```markdown
# Monorepo Boundary Rules

## Package Boundaries
- Apps (`apps/*`) may import from packages (`packages/*`) but NEVER from other apps.
- Packages may import from other packages only if declared in their package.json dependencies.
- Use the workspace protocol (`workspace:*`) for all inter-package dependencies.

## Import Conventions
- Always import workspace packages by their package name (e.g., `@acme/ui`), never by relative path (`../../packages/ui`).
- Shared types go in `packages/types` or are co-located with the package that owns them.

## Adding New Packages
1. Create the directory under `packages/` or `apps/`.
2. Add a `package.json` with the `@acme/` scoped name.
3. Add the package to `turbo.json` pipeline if it has build/test/lint scripts.
4. Run `npm install` (or `pnpm install`) from the root to link it.
```

Adapt the specifics (scope name, commands) to the actual project.

#### 4. `.claude/agents/`

Generate shared agents that understand the full monorepo context. Typical agents:

- **cross-package-refactor.md**: For refactoring that spans multiple packages (e.g., renaming a shared component, updating a shared type).
- Only create agents for workflows that genuinely span packages. Do NOT create per-package agents unless a package has a very different workflow.

#### 5. `.mcp.json`

Same as main SKILL.md. Union of all services used across all packages. If `apps/api` uses Postgres and `apps/web` does not, still include the Postgres MCP server at root level.

#### 6. `.claude/settings.json`

Same as main SKILL.md. Use the root-level lint/test commands (e.g., `turbo lint`, `turbo test`).

### 5B: Cursor Files

#### 7. `.cursor/rules/project-context.mdc`

Root-level Cursor rule covering the full monorepo structure. Same content as the root CLAUDE.md but in Cursor MDC format with frontmatter:

```
---
description: "Acme monorepo project context"
alwaysApply: true
---

[Same structure as root CLAUDE.md: package table, commands, conventions]
```

#### 8. `.cursor/rules/{package-name}.mdc`

Per-package Cursor rules, **only for app packages** (not libraries or configs):

```
---
description: "Context for the @acme/web Next.js application"
alwaysApply: false
globs: ["apps/web/**"]
---

[Same content as the per-package CLAUDE.md]
```

#### 9. `.cursor/mcp.json`

Same servers as root `.mcp.json`, in Cursor format.

### 5C: Codex Files

#### 10. `AGENTS.md`

Single file covering the entire monorepo. Structure it with per-package sections:

```markdown
# Acme Monorepo

[Overview, monorepo tool, package table]

## Package: apps/web
[Framework, commands, conventions for web app]

## Package: apps/api
[Framework, commands, conventions for API]

## Package: packages/ui
[What it exports, how to add components]

## Shared Conventions
[Cross-package rules, import patterns, testing]
```

Dispatch the **codex-specialist** subagent with the full PROJECT_PROFILE and package profiles.

---

## Step 6: Monorepo-Specific Quality Checks (extends main Step 6)

In addition to the standard quality checks from main SKILL.md Step 6, verify:

1. **Root CLAUDE.md lists all packages** -- every discovered package must appear in the package table.
2. **Root CLAUDE.md documents the monorepo tool** -- must mention turborepo/nx/lerna/pnpm by name with correct commands.
3. **Per-package CLAUDE.md exists for each app package** -- every package classified as `app` must have its own CLAUDE.md.
4. **No cross-package import violations** -- generated agents must not reference imports that violate the dependency graph.
5. **Reasonable file count** -- total generated files should be roughly `base_files + (N_apps * 2)`, not `base_files * N_packages`. Config and types packages should NOT generate their own agents, skills, or Cursor rules.
6. **monorepo-boundaries.md rule exists** -- this rule must always be generated.
7. **Commands are correct** -- turbo commands use `--filter`, nx commands use `--project`, pnpm uses `--filter`.

---

## Steps 7-9: Same as Main SKILL.md

Refer to the main `SKILL.md` for:
- **Step 7**: Write files (including creating per-package directories as needed)
- **Step 8**: Summary report (list all generated files including per-package ones)
- **Step 9**: Score and log results

---

## Monorepo Tool Quick Reference

Use these commands in generated files based on the detected monorepo tool:

### Turborepo
```
turbo build                      # build all packages
turbo test                       # test all packages
turbo lint                       # lint all packages
turbo dev                        # start all dev servers
turbo build --filter=@scope/pkg  # build one package
turbo build --filter=...[HEAD]   # build only changed packages
```

### Nx
```
nx run-many --target=build       # build all projects
nx run-many --target=test        # test all projects
nx affected --target=build       # build only affected projects
nx graph                         # visualize dependency graph
nx run @scope/pkg:build          # build one project
```

### pnpm Workspaces
```
pnpm -r build                    # build all packages recursively
pnpm -r test                     # test all packages
pnpm --filter @scope/pkg build   # build one package
pnpm --filter @scope/pkg...      # build a package and its dependencies
pnpm --filter "...[HEAD]" test   # test only changed packages
```

### Lerna
```
lerna run build                  # build all packages
lerna run test                   # test all packages
lerna run build --scope=@scope/pkg  # build one package
lerna run test --since=main      # test only changed packages
```

---

## Flow Summary

```
Step 1:  Acquire repo                          [same as main SKILL.md]
Step 2:  Monorepo structure detection          [THIS VARIANT]
Step 3:  Per-package + root analysis           [THIS VARIANT]
Step 4:  Check existing setup                  [same as main SKILL.md, extended]
Step 5:  Monorepo-aware generation             [THIS VARIANT]
Step 6:  Quality review + monorepo checks      [main SKILL.md + monorepo extensions]
Step 6B: Iterative improvement                 [same as main SKILL.md]
Step 7:  Write files                           [same as main SKILL.md]
Step 8:  Summary report                        [same as main SKILL.md]
Step 9:  Score and log results                 [same as main SKILL.md]
```
