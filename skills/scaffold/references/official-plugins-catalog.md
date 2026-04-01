# Official & Popular Claude Code Plugins Catalog

Curated catalog of plugins that scaffold should recommend BEFORE generating custom skills. Always check if an existing plugin covers the need before creating a custom skill.

---

## Recommendation Priority Levels

- **must-have**: Recommend for ALL projects. These provide foundational capabilities.
- **recommended**: Recommend when project signals match. High value for matching projects.
- **optional**: Mention as available. Useful for specific workflows.

---

## Must-Have Plugins

### Plugin: superpowers
- **What it provides**: A comprehensive collection of meta-skills that improve Claude Code's overall effectiveness across all development workflows. This is the single most impactful plugin for any project.
- **Key skills**:
  - `test-driven-development` -- Guides red-green-refactor TDD cycle, test verification, and common pitfalls
  - `systematic-debugging` -- Root cause analysis, evidence gathering, and hypothesis testing before proposing fixes
  - `writing-plans` -- Creates structured implementation plans for multi-step tasks before touching code
  - `executing-plans` -- Executes written plans in separate sessions with review checkpoints
  - `brainstorming` -- Explores user intent, requirements, and design before implementation begins
  - `requesting-code-review` -- Structured code review to verify work meets requirements
  - `receiving-code-review` -- Technical rigor when receiving feedback, prevents blind agreement
  - `verification-before-completion` -- Requires running verification commands before claiming work is done
  - `finishing-a-development-branch` -- Guides branch completion with merge/PR/cleanup options
  - `dispatching-parallel-agents` -- Runs 2+ independent tasks in parallel using subagents
  - `subagent-driven-development` -- Quality gates per task, prevents context pollution
  - `using-git-worktrees` -- Creates isolated git worktrees for feature isolation
  - `writing-skills` -- Creating, editing, and verifying new skills
  - `using-superpowers` -- Meta-skill that ensures other skills are discovered and used
- **Recommend when**: ALWAYS. Every project benefits from these workflow skills. They enforce discipline (test before implement, plan before code, verify before claim done) that prevents the most common AI coding mistakes.
- **Install**: `claude plugins install superpowers`
- **Priority**: must-have
- **Why must-have**: Without superpowers, Claude Code tends to jump straight to implementation without planning, skip tests, and claim completion without verification. Superpowers fixes all of these anti-patterns.

---

### Plugin: hookify
- **What it provides**: Creates safety hooks from conversation analysis or explicit instructions. Hooks run as shell scripts on Claude Code lifecycle events (PreToolUse, PostToolUse, etc.) to enforce rules programmatically.
- **Key skills**:
  - `hookify` -- Analyze conversation for unwanted behaviors and create prevention hooks
  - `list` -- List all configured hookify rules
  - `configure` -- Enable/disable hookify rules interactively
  - `writing-rules` -- Guidance on hookify rule syntax and patterns
  - `help` -- Get help with the hookify plugin
- **Recommend when**: ALWAYS. Every project needs safety guardrails. Without hooks, Claude Code can modify protected files, run dangerous commands, or bypass conventions. Hookify makes rule enforcement automatic rather than relying on prompt instructions.
- **Install**: `claude plugins install hookify`
- **Priority**: must-have
- **Why must-have**: Rules in CLAUDE.md are suggestions. Hooks are enforcement. The combination of rules (what to do) + hooks (prevent violations) is what makes AI development reliable.
- **Example signals for custom hooks**:
  - Protected files that should never be edited (lock files, generated code, configs)
  - Dangerous commands that should be blocked (rm -rf, force push, drop table)
  - Post-edit checks that should always run (type checking, linting, tests)

---

## Recommended Plugins

### Plugin: skill-creator
- **What it provides**: Create, evaluate, improve, and benchmark Claude Code skills. Provides structured workflows for skill development with measurement.
- **Key skills**:
  - `skill-creator` -- Create new skills from scratch, update existing skills, run evals, benchmark performance with variance analysis, optimize descriptions for triggering accuracy
- **Recommend when**: The project will benefit from custom skills beyond what plugins provide. Specifically:
  - Projects with repetitive workflows that could be automated (component creation, API endpoint scaffolding)
  - Teams that want to encode institutional knowledge into reusable skills
  - When the scaffold generates custom skills, recommend skill-creator for iterating on them
- **Install**: `claude plugins install skill-creator`
- **Priority**: recommended
- **Project signals**:
  - Large codebase with established patterns
  - Team with specific conventions that need encoding
  - Repetitive development workflows identified during analysis

---

### Plugin: code-review
- **What it provides**: Automated pull request code review with structured feedback.
- **Key skills**:
  - `code-review` -- Review a pull request for quality, security, performance, and best practices
- **Recommend when**: The project uses pull requests for code integration. Most useful for:
  - Teams with active PR workflows
  - Projects where code quality is critical (production services, libraries)
  - When GitHub MCP server is also configured (they complement each other)
- **Install**: `claude plugins install code-review`
- **Priority**: recommended
- **Project signals**:
  - `.github/` directory exists
  - PR templates exist (`.github/pull_request_template.md`)
  - Branch protection rules mentioned in docs
  - CI/CD pipeline configured

---

### Plugin: context7
- **What it provides**: Fetches current documentation for any library, framework, SDK, or API. Ensures Claude Code has up-to-date docs rather than relying on training data.
- **Key skills**:
  - `resolve-library-id` -- Find the correct library identifier
  - `query-docs` -- Fetch documentation for a specific library topic
- **Recommend when**: The project uses external libraries, frameworks, or SDKs. Especially valuable when:
  - Using rapidly-evolving frameworks (Next.js, React, Svelte, etc.)
  - Working with less common libraries where Claude's training data may be thin
  - Debugging version-specific API issues
  - Migrating between framework versions
- **Install**: `claude plugins install context7`
- **Priority**: recommended
- **Project signals**:
  - `package.json` with multiple dependencies
  - `requirements.txt` or `pyproject.toml` with dependencies
  - `Cargo.toml`, `go.mod`, `Gemfile`, or any dependency manifest
  - Framework-specific config files (next.config.js, vite.config.ts, etc.)
- **When to skip**: Pure scripts with no external dependencies, or projects using only standard library

---

### Plugin: frontend-design
- **What it provides**: Build production-grade UI components with high design quality. Creates distinctive interfaces that avoid generic AI aesthetics.
- **Key skills**:
  - `frontend-design` -- Create web components, pages, and applications with polished design
- **Recommend when**: The project has a user-facing frontend. Most valuable for:
  - Landing pages and marketing sites
  - Dashboard interfaces
  - Component library development
  - Any UI work where visual quality matters
- **Install**: `claude plugins install frontend-design`
- **Priority**: recommended
- **Project signals**:
  - React, Vue, Svelte, or Angular in dependencies
  - CSS/SCSS/Tailwind files present
  - `src/components/` directory exists
  - Design system or component library structure
  - Storybook configuration present
- **When to skip**: Backend-only projects, CLI tools, libraries with no UI

---

## Optional Plugins

### Plugin: playground
- **What it provides**: Creates interactive HTML playgrounds -- self-contained single-file explorers that let users visually configure something, see a live preview, and copy outputs.
- **Key skills**:
  - `playground` -- Create an interactive HTML playground for any topic
- **Recommend when**: The project would benefit from interactive exploration tools:
  - Regex builders
  - Color/theme configurators
  - API endpoint explorers
  - CSS layout playground
  - Data structure visualizers
- **Install**: `claude plugins install playground`
- **Priority**: optional
- **Project signals**:
  - Design system projects
  - Projects with complex configuration options
  - Educational or documentation-heavy projects
  - Internal tooling projects

---

### Plugin: code-simplifier
- **What it provides**: Reviews code for unnecessary complexity and simplifies it while preserving behavior.
- **Key skills**:
  - `simplify` -- Review changed code for reuse, quality, and efficiency, then fix issues
- **Recommend when**: The codebase shows signs of over-engineering:
  - Excessive abstraction layers
  - Overly generic code for specific use cases
  - Complex inheritance hierarchies
  - Unnecessary design patterns
- **Install**: `claude plugins install code-simplifier`
- **Priority**: optional
- **Project signals**:
  - Large, mature codebase
  - Multiple contributors with different styles
  - Recent refactoring efforts
  - Tech debt reduction initiatives
- **When to skip**: New projects, small codebases, projects actively adding complexity for good reasons

---

## Recommendation Decision Tree

Use this logic when deciding which plugins to recommend:

```
1. ALWAYS recommend: superpowers, hookify
   |
2. Does the project use external libraries/frameworks?
   YES -> recommend: context7
   |
3. Does the project have a frontend?
   YES -> recommend: frontend-design
   |
4. Does the project use GitHub PRs?
   YES -> recommend: code-review
   |
5. Will the project need custom skills?
   YES -> recommend: skill-creator
   |
6. Would interactive explorers be useful?
   YES -> optional: playground
   |
7. Is the codebase complex/over-engineered?
   YES -> optional: code-simplifier
```

---

## Plugin vs. Custom Skill Decision

Before generating a custom skill, check this list:

| Need | Plugin that covers it | Generate custom? |
|------|----------------------|-----------------|
| TDD workflow | superpowers (test-driven-development) | No |
| Debugging | superpowers (systematic-debugging) | No |
| Planning | superpowers (writing-plans) | No |
| Code review | code-review or superpowers (requesting-code-review) | No |
| Safety hooks | hookify | No |
| Skill creation | skill-creator | No |
| Library docs | context7 | No |
| UI components | frontend-design | No |
| Interactive tools | playground | No |
| Code cleanup | code-simplifier | No |
| Project-specific workflows | None | YES - generate custom |
| Domain-specific conventions | None | YES - generate as rules |
| Custom build pipelines | None | YES - generate custom |
| Project-specific testing patterns | None | YES - generate custom |

Only generate custom skills for needs that no existing plugin covers.
