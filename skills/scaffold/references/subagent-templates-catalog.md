# Subagent Templates Catalog

Catalog of reusable code subagent templates that scaffold can recommend based on project analysis. The opportunity-detector subagent reads this file to map detection signals to subagent suggestions.

---

## Model Tier Classification

- **haiku**: Mechanical and rule-based tasks. Fast, cheap, high throughput. Use for tasks with clear inputs, deterministic outputs, and minimal judgment required (running tests, formatting, building, committing).
- **sonnet**: Creative and judgment-requiring tasks. Balanced speed and quality. Use for tasks that require reading context, making decisions, and producing nuanced output (code review, PR descriptions).
- **opus**: Architectural and complex reasoning tasks. Highest quality, slower. Use for tasks that require deep analysis, cross-cutting concerns, and design-level thinking (architecture review, system design).

---

## Subagent Templates

### test-runner

| Field | Value |
|-------|-------|
| **ID** | `test-runner` |
| **Model Tier** | haiku |
| **Description** | Runs test suite, reports failures with context, and suggests targeted fixes. |
| **Template Path** | `templates/subagents/test-runner.md` |
| **Detection Signals** | `jest.config.*`, `vitest.config.*`, `pytest.ini`, `conftest.py`, `setup.cfg` with `[tool:pytest]`, `go.mod` (Go projects), `Cargo.toml` (Rust projects), `test` or `jest` or `vitest` or `mocha` or `ava` in `package.json` devDependencies, `phpunit.xml`, `.rspec` |
| **When to Skip** | No test framework detected. No test files exist. Project is a static site or config-only repo with nothing to test. |
| **Example Invocation** | `Run all tests, report failures with file:line context, and suggest a fix for each failing assertion.` |

---

### lint-format

| Field | Value |
|-------|-------|
| **ID** | `lint-format` |
| **Model Tier** | haiku |
| **Description** | Runs linter and formatter on changed files, auto-fixes what it can, reports remaining issues. |
| **Template Path** | `templates/subagents/lint-format.md` |
| **Detection Signals** | `.eslintrc.*`, `eslint.config.*`, `eslint.config.mjs`, `biome.json`, `biome.jsonc`, `ruff.toml`, `pyproject.toml` with `[tool.ruff]`, `.golangci.yml`, `.golangci.yaml`, `.prettierrc*`, `.stylelint*`, `deno.json` with lint config, `clippy` in Rust toolchain |
| **When to Skip** | No linter or formatter config detected. Project explicitly opts out of linting (e.g., prototype, spike, or scratch project). |
| **Example Invocation** | `Lint and format all files changed since the last commit. Auto-fix what you can, then list remaining issues with severity.` |

---

### build-watcher

| Field | Value |
|-------|-------|
| **ID** | `build-watcher` |
| **Model Tier** | haiku |
| **Description** | Runs the build, catches type errors and compilation failures, reports them with fix suggestions. |
| **Template Path** | `templates/subagents/build-watcher.md` |
| **Detection Signals** | `next.config.*`, `vite.config.*`, `webpack.config.*`, `rollup.config.*`, `Cargo.toml` (Rust), `go.mod` (Go), `tsconfig.json`, `tsconfig.*.json`, `build.gradle*`, `pom.xml`, `CMakeLists.txt`, `Makefile` with build targets, `turbo.json`, `nx.json` |
| **When to Skip** | No build step exists. Project is an interpreted-only script (pure Python, shell scripts) with no compilation or bundling. |
| **Example Invocation** | `Run the build command. If it fails, extract every error with file, line, and message. Suggest a fix for each.` |

---

### commit-assistant

| Field | Value |
|-------|-------|
| **ID** | `commit-assistant` |
| **Model Tier** | haiku |
| **Description** | Stages changed files, analyzes diffs, and writes conventional commit messages. |
| **Template Path** | `templates/subagents/commit-assistant.md` |
| **Detection Signals** | Git repository with more than 10 commits (indicates active development, not a fresh repo). |
| **When to Skip** | Repository has fewer than 10 commits. Project uses a non-conventional commit style that the template would conflict with. Team has strict commit message policies enforced by other tooling. |
| **Example Invocation** | `Stage all meaningful changes, generate a conventional commit message (type: subject + body), and create the commit.` |

---

### code-reviewer

| Field | Value |
|-------|-------|
| **ID** | `code-reviewer` |
| **Model Tier** | sonnet |
| **Description** | Reviews pull requests against project conventions, flags issues, and suggests improvements. |
| **Template Path** | `templates/subagents/code-reviewer.md` |
| **Detection Signals** | More than 1 contributor in the last 30 days (`git shortlog --since="30 days ago" -s`), more than 20 source files, CI/CD configuration present (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`), PR template exists (`.github/pull_request_template.md`) |
| **When to Skip** | Solo developer with no plans for collaboration. Trivial project (fewer than 10 files). No PR-based workflow. |
| **Example Invocation** | `Review the current branch diff against main. Check for: convention violations, security issues, performance concerns, missing tests. Output structured feedback.` |

---

### pr-writer

| Field | Value |
|-------|-------|
| **ID** | `pr-writer` |
| **Model Tier** | sonnet |
| **Description** | Analyzes branch diff and writes structured PR descriptions with summary, test plan, and context. |
| **Template Path** | `templates/subagents/pr-writer.md` |
| **Detection Signals** | `.github/` directory or `.gitlab-ci.yml` exists, git remote points to `github.com` or `gitlab.com`, PR template exists (`.github/pull_request_template.md`), more than 5 merged PRs in history |
| **When to Skip** | No remote repository configured. Project does not use a PR-based workflow. Solo developer committing directly to main. |
| **Example Invocation** | `Analyze all commits on this branch vs main. Write a PR description with: summary (what and why), changes list, test plan, and migration notes if applicable.` |

---

### architecture-advisor

| Field | Value |
|-------|-------|
| **ID** | `architecture-advisor` |
| **Model Tier** | opus |
| **Description** | Analyzes codebase design, identifies architectural patterns, and suggests improvements for maintainability and scalability. |
| **Template Path** | `templates/subagents/architecture-advisor.md` |
| **Detection Signals** | More than 50 source files, multiple `src/` subdirectories or package structure (`packages/`, `libs/`, `modules/`), `docker-compose.yml` or `docker-compose.yaml` with 2+ services, monorepo tooling (`turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml`), microservice indicators (multiple Dockerfiles, API gateway config) |
| **When to Skip** | Small project (fewer than 20 files). Single-purpose script or CLI tool. Project architecture is already well-documented and stable. |
| **Example Invocation** | `Analyze the codebase structure. Identify: architectural pattern in use, dependency flow between modules, potential coupling issues, and 3 concrete improvement suggestions with trade-offs.` |

---

## Template Selection Logic

Use this process when deciding which subagent templates to recommend:

```
1. Run detection signals against project analysis results
2. For each matching template:
   a. Check "When to Skip" conditions
   b. If not skipped, add to recommendations
3. Order recommendations by model tier (haiku first, then sonnet, then opus)
   - haiku templates are low-cost, recommend liberally
   - sonnet templates require judgment, recommend when signals are strong
   - opus templates are expensive, recommend only for large/complex projects
4. Check for redundancy:
   - If code-review plugin is already installed, code-reviewer template adds less value
   - If superpowers plugin handles commits, commit-assistant is lower priority
5. Cap recommendations:
   - Small projects (< 20 files): max 2 subagent templates
   - Medium projects (20-100 files): max 4 subagent templates
   - Large projects (> 100 files): all matching templates
```

## Signal Detection Commands

Quick reference for checking detection signals programmatically:

| Signal | Command |
|--------|---------|
| Test framework in deps | `jq '.devDependencies // {} + .dependencies // {} \| keys[]' package.json \| grep -E 'jest\|vitest\|mocha\|ava'` |
| Python test framework | `test -f pytest.ini \|\| test -f conftest.py \|\| grep -q pytest pyproject.toml 2>/dev/null` |
| Linter config | `ls .eslintrc.* eslint.config.* biome.json ruff.toml .golangci.yml 2>/dev/null` |
| Build config | `ls next.config.* vite.config.* webpack.config.* tsconfig.json Cargo.toml go.mod 2>/dev/null` |
| Git commit count | `git rev-list --count HEAD` |
| Contributor count (30d) | `git shortlog --since="30 days ago" -s \| wc -l` |
| Source file count | `find src lib app -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.rs' 2>/dev/null \| wc -l` |
| PR workflow indicators | `test -d .github/workflows \|\| test -f .gitlab-ci.yml` |
| Monorepo signals | `test -f turbo.json \|\| test -f nx.json \|\| test -f lerna.json \|\| test -f pnpm-workspace.yaml` |
