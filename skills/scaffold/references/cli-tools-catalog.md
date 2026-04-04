# CLI Tools Catalog — AI Agent Accelerators

CLI tools that make AI coding agents faster by providing efficient search, analysis, linting, and formatting capabilities through the terminal. CLIs are the native interface for AI agents — they compose naturally and produce structured output agents can reason about.

## Recommendation Priority Levels

- **essential**: Install for ALL developers using AI agents. Fundamental acceleration regardless of project type.
- **recommended**: Install when project type matches. High value for matching stacks.
- **optional**: Useful for power users. Mention as available but do not push.

## Agent Impact Scoring (1-10)

- **10**: Directly invoked by AI agents as a core tool (ripgrep → Grep, fd → Glob, gh → GitHub ops)
- **8**: Produces structured output agents consume (shellcheck, eslint, ruff, tokei)
- **6**: Speeds up AI-suggested workflows or developer velocity (fzf, lazygit, delta, direnv)
- **4**: General developer productivity with indirect agent benefit
- **2**: Primarily human-facing UI enhancement

---

## Search Tools

### ripgrep

| Field | Value |
|-------|-------|
| **ID** | `ripgrep` |
| **Binary** | `rg` |
| **Category** | search |
| **Priority** | essential |
| **Agent Impact** | 10 |
| **Purpose** | Fast regex search across codebases. 10-100x faster than grep with automatic .gitignore filtering. |
| **Why for AI Agents** | Claude Code's Grep tool shells out to rg. System ripgrep with USE_BUILTIN_RIPGREP=0 is 2-5x faster than the bundled Node.js wrapper. Every search-heavy agent task benefits. |
| **Install (macOS)** | `brew install ripgrep` |
| **Install (Linux/apt)** | `sudo apt install ripgrep` |
| **Install (Linux/dnf)** | `sudo dnf install ripgrep` |
| **Install (cargo)** | `cargo install ripgrep` |
| **Verify** | `rg --version` |
| **AI Config** | Set `USE_BUILTIN_RIPGREP=0` in shell profile |
| **Project Types** | all |
| **Official Source** | https://github.com/BurntSushi/ripgrep |
| **Complements** | fd, ast-grep |
| **Conflicts** | none |
| **When to Skip** | never — always recommend |

---

### fd

| Field | Value |
|-------|-------|
| **ID** | `fd` |
| **Binary** | `fd` |
| **Category** | search |
| **Priority** | essential |
| **Agent Impact** | 9 |
| **Purpose** | Fast file finder. 3-7x faster than find with .gitignore awareness and smart defaults. |
| **Why for AI Agents** | Claude Code's Glob tool benefits from fd for file discovery. Agents frequently need to locate files by pattern — fd makes this near-instant on large repos. |
| **Install (macOS)** | `brew install fd` |
| **Install (Linux/apt)** | `sudo apt install fd-find` |
| **Install (Linux/dnf)** | `sudo dnf install fd-find` |
| **Install (cargo)** | `cargo install fd-find` |
| **Verify** | `fd --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/sharkdp/fd |
| **Complements** | ripgrep, fzf |
| **Conflicts** | none |
| **When to Skip** | never — always recommend |

---

### ast-grep

| Field | Value |
|-------|-------|
| **ID** | `ast-grep` |
| **Binary** | `sg` |
| **Category** | search |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | AST-aware structural code search and replace. Matches code patterns semantically, not just text. |
| **Why for AI Agents** | Enables agents to find code patterns by structure (e.g., "all functions returning a Promise") rather than regex. Produces precise matches for refactoring tasks. |
| **Install (macOS)** | `brew install ast-grep` |
| **Install (Linux/apt)** | `npm install -g @ast-grep/cli` |
| **Install (cargo)** | `cargo install ast-grep` |
| **Verify** | `sg --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/ast-grep/ast-grep |
| **Complements** | ripgrep |
| **Conflicts** | none |
| **When to Skip** | very small projects (<10 files) |

---

### fzf

| Field | Value |
|-------|-------|
| **ID** | `fzf` |
| **Binary** | `fzf` |
| **Category** | search |
| **Priority** | recommended |
| **Agent Impact** | 6 |
| **Purpose** | Interactive fuzzy finder for the terminal. Pipes into any command for instant filtering. |
| **Why for AI Agents** | Agents suggest fzf-based workflows for interactive file selection and filtering. Enhances developer experience when agents produce lists of suggestions. |
| **Install (macOS)** | `brew install fzf` |
| **Install (Linux/apt)** | `sudo apt install fzf` |
| **Install (Linux/dnf)** | `sudo dnf install fzf` |
| **Verify** | `fzf --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/junegunn/fzf |
| **Complements** | fd, ripgrep, bat |
| **Conflicts** | none |
| **When to Skip** | headless/CI-only environments |

---

## Git Tools

### gh

| Field | Value |
|-------|-------|
| **ID** | `gh` |
| **Binary** | `gh` |
| **Category** | git |
| **Priority** | essential |
| **Agent Impact** | 10 |
| **Purpose** | Official GitHub CLI. Create PRs, manage issues, review code, run workflows — all from the terminal. |
| **Why for AI Agents** | Claude Code uses gh directly for GitHub operations (PR creation, issue management, CI checks). The gh MCP server also wraps this. Essential for any GitHub-hosted project. |
| **Install (macOS)** | `brew install gh` |
| **Install (Linux/apt)** | `sudo apt install gh` |
| **Install (Linux/dnf)** | `sudo dnf install gh` |
| **Verify** | `gh --version` |
| **Project Types** | all (GitHub-hosted) |
| **Official Source** | https://github.com/cli/cli |
| **Complements** | git-delta |
| **Conflicts** | none |
| **When to Skip** | GitLab-only projects (use glab instead) |

---

### git-delta

| Field | Value |
|-------|-------|
| **ID** | `git-delta` |
| **Binary** | `delta` |
| **Category** | git |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Enhanced git diff viewer with syntax highlighting, line numbers, and side-by-side mode. |
| **Why for AI Agents** | Agents frequently ask users to review diffs. Delta makes diffs readable with syntax highlighting, helping humans verify agent changes faster. |
| **Install (macOS)** | `brew install git-delta` |
| **Install (Linux/apt)** | `sudo apt install git-delta` |
| **Install (cargo)** | `cargo install git-delta` |
| **Verify** | `delta --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/dandavison/delta |
| **Complements** | gh, lazygit |
| **Conflicts** | none |
| **When to Skip** | none |

---

### glab

| Field | Value |
|-------|-------|
| **ID** | `glab` |
| **Binary** | `glab` |
| **Category** | git |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Official GitLab CLI. Manage MRs, issues, pipelines from the terminal. |
| **Why for AI Agents** | Equivalent of gh for GitLab. Agents use it for MR creation and CI pipeline management on GitLab-hosted repos. |
| **Install (macOS)** | `brew install glab` |
| **Install (Linux/apt)** | `sudo apt install glab` |
| **Verify** | `glab --version` |
| **Project Types** | all (GitLab-hosted) |
| **Official Source** | https://gitlab.com/gitlab-org/cli |
| **Complements** | git-delta |
| **Conflicts** | none |
| **When to Skip** | GitHub-only projects |

---

### lazygit

| Field | Value |
|-------|-------|
| **ID** | `lazygit` |
| **Binary** | `lazygit` |
| **Category** | git |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Terminal UI for git. Interactive staging, branching, rebasing, conflict resolution. |
| **Why for AI Agents** | Agents recommend lazygit for complex git operations (interactive rebase, conflict resolution) that are easier in a TUI than raw commands. |
| **Install (macOS)** | `brew install lazygit` |
| **Install (Linux/apt)** | `sudo apt install lazygit` |
| **Verify** | `lazygit --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/jesseduffield/lazygit |
| **Complements** | git-delta |
| **Conflicts** | none |
| **When to Skip** | developers who prefer git CLI or IDE git |

---

## Shell & Terminal Tools

### shellcheck

| Field | Value |
|-------|-------|
| **ID** | `shellcheck` |
| **Binary** | `shellcheck` |
| **Category** | shell |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Static analysis for bash/sh scripts. Catches common bugs, quoting issues, and portability problems. |
| **Why for AI Agents** | Agents generate bash scripts and use shellcheck to validate them. Claude Code can run shellcheck to catch issues in generated shell code before execution. |
| **Install (macOS)** | `brew install shellcheck` |
| **Install (Linux/apt)** | `sudo apt install shellcheck` |
| **Install (Linux/dnf)** | `sudo dnf install ShellCheck` |
| **Verify** | `shellcheck --version` |
| **Project Types** | all (any project with shell scripts) |
| **Official Source** | https://github.com/koalaman/shellcheck |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | projects with zero shell scripts |

---

### direnv

| Field | Value |
|-------|-------|
| **ID** | `direnv` |
| **Binary** | `direnv` |
| **Category** | shell |
| **Priority** | recommended |
| **Agent Impact** | 6 |
| **Purpose** | Per-directory environment variable management. Auto-loads .envrc when you cd into a project. |
| **Why for AI Agents** | Ensures AI agents and their MCP servers inherit the correct env vars per project. Eliminates "missing API key" errors when switching between projects. |
| **Install (macOS)** | `brew install direnv` |
| **Install (Linux/apt)** | `sudo apt install direnv` |
| **Verify** | `direnv --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/direnv/direnv |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | single-project developers |

---

### bat

| Field | Value |
|-------|-------|
| **ID** | `bat` |
| **Binary** | `bat` |
| **Category** | shell |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Cat replacement with syntax highlighting, line numbers, and git integration. |
| **Why for AI Agents** | Enhances readability when agents display file contents. Works as a pager for fzf preview windows. |
| **Install (macOS)** | `brew install bat` |
| **Install (Linux/apt)** | `sudo apt install bat` |
| **Verify** | `bat --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/sharkdp/bat |
| **Complements** | fzf, ripgrep |
| **Conflicts** | none |
| **When to Skip** | none |

---

### eza

| Field | Value |
|-------|-------|
| **ID** | `eza` |
| **Binary** | `eza` |
| **Category** | shell |
| **Priority** | optional |
| **Agent Impact** | 4 |
| **Purpose** | Modern ls replacement with colors, git status, tree view, and icons. |
| **Why for AI Agents** | Produces more readable directory listings when agents need to show project structure. |
| **Install (macOS)** | `brew install eza` |
| **Install (Linux/apt)** | `sudo apt install eza` |
| **Install (cargo)** | `cargo install eza` |
| **Verify** | `eza --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/eza-community/eza |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | none |

---

### zoxide

| Field | Value |
|-------|-------|
| **ID** | `zoxide` |
| **Binary** | `zoxide` |
| **Category** | shell |
| **Priority** | optional |
| **Agent Impact** | 3 |
| **Purpose** | Smarter cd that remembers frequently visited directories. |
| **Why for AI Agents** | Speeds up manual navigation between projects the developer frequently visits. |
| **Install (macOS)** | `brew install zoxide` |
| **Install (Linux/apt)** | `sudo apt install zoxide` |
| **Verify** | `zoxide --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/ajeetdsouza/zoxide |
| **Complements** | fzf |
| **Conflicts** | none |
| **When to Skip** | none |

---

### starship

| Field | Value |
|-------|-------|
| **ID** | `starship` |
| **Binary** | `starship` |
| **Category** | shell |
| **Priority** | optional |
| **Agent Impact** | 2 |
| **Purpose** | Cross-shell prompt with git status, language versions, and environment indicators. |
| **Why for AI Agents** | Shows current branch, language version, and environment at a glance — context that helps developers verify agent assumptions. |
| **Install (macOS)** | `brew install starship` |
| **Install (Linux/apt)** | `brew install starship` |
| **Verify** | `starship --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/starship/starship |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | developers happy with their current prompt |

---

## JSON & Data Tools

### jq

| Field | Value |
|-------|-------|
| **ID** | `jq` |
| **Binary** | `jq` |
| **Category** | json-data |
| **Priority** | essential |
| **Agent Impact** | 9 |
| **Purpose** | JSON processor — query, filter, transform JSON from the command line. |
| **Why for AI Agents** | Agents parse API responses, config files, and tool outputs with jq. Essential for composing CLI pipelines that process structured data. |
| **Install (macOS)** | `brew install jq` |
| **Install (Linux/apt)** | `sudo apt install jq` |
| **Install (Linux/dnf)** | `sudo dnf install jq` |
| **Verify** | `jq --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/jqlang/jq |
| **Complements** | yq |
| **Conflicts** | none |
| **When to Skip** | never — always recommend |

---

### yq

| Field | Value |
|-------|-------|
| **ID** | `yq` |
| **Binary** | `yq` |
| **Category** | json-data |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | YAML/JSON/XML/TOML processor — jq-like syntax for YAML files. |
| **Why for AI Agents** | Agents manipulate Kubernetes manifests, CI configs, docker-compose files, and other YAML. yq enables precise, scriptable edits. |
| **Install (macOS)** | `brew install yq` |
| **Install (Linux/apt)** | `sudo apt install yq` |
| **Verify** | `yq --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/mikefarah/yq |
| **Complements** | jq |
| **Conflicts** | none |
| **When to Skip** | projects with no YAML config |

---

### fx

| Field | Value |
|-------|-------|
| **ID** | `fx` |
| **Binary** | `fx` |
| **Category** | json-data |
| **Priority** | optional |
| **Agent Impact** | 4 |
| **Purpose** | Interactive JSON viewer and processor with mouse support and themes. |
| **Why for AI Agents** | Helps developers explore large JSON outputs from APIs or agent tool results interactively. |
| **Install (macOS)** | `brew install fx` |
| **Install (npm)** | `npm install -g fx` |
| **Verify** | `fx --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/antonmedv/fx |
| **Complements** | jq |
| **Conflicts** | none |
| **When to Skip** | developers comfortable with jq |

---

## Code Metrics Tools

### tokei

| Field | Value |
|-------|-------|
| **ID** | `tokei` |
| **Binary** | `tokei` |
| **Category** | code-metrics |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Fast code statistics — lines of code, blanks, comments per language. |
| **Why for AI Agents** | Agents use tokei to understand codebase composition before making recommendations. Helps estimate complexity and identify dominant languages. |
| **Install (macOS)** | `brew install tokei` |
| **Install (Linux/apt)** | `sudo apt install tokei` |
| **Install (cargo)** | `cargo install tokei` |
| **Verify** | `tokei --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/XAMPPRocky/tokei |
| **Complements** | none |
| **Conflicts** | scc, cloc (pick one) |
| **When to Skip** | if scc already installed |

---

### scc

| Field | Value |
|-------|-------|
| **ID** | `scc` |
| **Binary** | `scc` |
| **Category** | code-metrics |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Code complexity counter — lines, complexity scores, COCOMO estimates. |
| **Why for AI Agents** | Provides complexity scores beyond line counts, helping agents identify the most complex files for refactoring. |
| **Install (macOS)** | `brew install scc` |
| **Install (Linux/apt)** | `sudo apt install scc` |
| **Verify** | `scc --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/boyter/scc |
| **Complements** | none |
| **Conflicts** | tokei, cloc (pick one) |
| **When to Skip** | if tokei already installed |

---

### cloc

| Field | Value |
|-------|-------|
| **ID** | `cloc` |
| **Binary** | `cloc` |
| **Category** | code-metrics |
| **Priority** | optional |
| **Agent Impact** | 4 |
| **Purpose** | Count lines of code across languages. The original line counter. |
| **Why for AI Agents** | Legacy tool that agents may reference. Slower than tokei/scc but widely known. |
| **Install (macOS)** | `brew install cloc` |
| **Install (Linux/apt)** | `sudo apt install cloc` |
| **Verify** | `cloc --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/AlDanial/cloc |
| **Complements** | none |
| **Conflicts** | tokei, scc (pick one) |
| **When to Skip** | if tokei or scc already installed |

---

## JavaScript/TypeScript Ecosystem

### eslint

| Field | Value |
|-------|-------|
| **ID** | `eslint` |
| **Binary** | `eslint` |
| **Category** | js-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 9 |
| **Purpose** | Pluggable JS/TS linter. Catches bugs, enforces style, supports custom rules. |
| **Why for AI Agents** | Agents run eslint to validate generated JS/TS code. Pre-commit hooks use it. AI agents parse eslint output to self-correct. |
| **Install (npm)** | `npm install -g eslint` |
| **Verify** | `eslint --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/eslint/eslint |
| **Complements** | prettier |
| **Conflicts** | biome (biome replaces eslint+prettier) |
| **When to Skip** | if biome is already adopted |

---

### prettier

| Field | Value |
|-------|-------|
| **ID** | `prettier` |
| **Binary** | `prettier` |
| **Category** | js-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Opinionated code formatter for JS/TS/CSS/HTML/JSON/YAML/Markdown. |
| **Why for AI Agents** | Agents format generated code with prettier to match project style. Eliminates formatting noise in diffs. |
| **Install (npm)** | `npm install -g prettier` |
| **Verify** | `prettier --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/prettier/prettier |
| **Complements** | eslint |
| **Conflicts** | biome (biome replaces eslint+prettier) |
| **When to Skip** | if biome is already adopted |

---

### biome

| Field | Value |
|-------|-------|
| **ID** | `biome` |
| **Binary** | `biome` |
| **Category** | js-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 9 |
| **Purpose** | Fast all-in-one linter and formatter for JS/TS/JSON/CSS. Written in Rust. Replaces eslint + prettier. |
| **Why for AI Agents** | Single tool = fewer config files, faster execution. Agents get lint+format in one pass. 10-100x faster than eslint+prettier combined. |
| **Install (npm)** | `npm install -g @biomejs/biome` |
| **Install (macOS)** | `brew install biome` |
| **Verify** | `biome --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/biomejs/biome |
| **Complements** | none |
| **Conflicts** | eslint + prettier (biome replaces both) |
| **When to Skip** | if eslint+prettier are already configured and team is happy |

---

### oxlint

| Field | Value |
|-------|-------|
| **ID** | `oxlint` |
| **Binary** | `oxlint` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 8 |
| **Purpose** | Ultra-fast JavaScript/TypeScript linter written in Rust. 50-100x faster than eslint. |
| **Why for AI Agents** | Near-instant feedback loop for agents generating JS/TS code. Can run on every file save without noticeable delay. |
| **Install (npm)** | `npm install -g oxlint` |
| **Install (macOS)** | `brew install oxc` |
| **Verify** | `oxlint --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/oxc-project/oxc |
| **Complements** | eslint (supplementary, not full replacement yet) |
| **Conflicts** | none |
| **When to Skip** | if biome is already adopted |

---

### tsc

| Field | Value |
|-------|-------|
| **ID** | `tsc` |
| **Binary** | `tsc` |
| **Category** | js-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | TypeScript compiler. Type-checks and transpiles TS code. |
| **Why for AI Agents** | Agents run tsc --noEmit to type-check generated TypeScript. Catches type errors before runtime. |
| **Install (npm)** | `npm install -g typescript` |
| **Verify** | `tsc --version` |
| **Project Types** | ts |
| **Official Source** | https://github.com/microsoft/TypeScript |
| **Complements** | eslint, prettier |
| **Conflicts** | none |
| **When to Skip** | JavaScript-only projects |

---

### tsx

| Field | Value |
|-------|-------|
| **ID** | `tsx` |
| **Binary** | `tsx` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | TypeScript executor — runs .ts files directly without compilation step. |
| **Why for AI Agents** | Agents can run TypeScript scripts directly for quick prototyping and testing without build steps. |
| **Install (npm)** | `npm install -g tsx` |
| **Verify** | `tsx --version` |
| **Project Types** | ts |
| **Official Source** | https://github.com/privatenumber/tsx |
| **Complements** | tsc |
| **Conflicts** | none |
| **When to Skip** | projects using bun or deno |

---

### turbo

| Field | Value |
|-------|-------|
| **ID** | `turbo` |
| **Binary** | `turbo` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Monorepo build system with caching, parallelism, and dependency-aware task execution. |
| **Why for AI Agents** | Agents use turbo to run builds and tests in monorepos with proper caching. Reduces build times dramatically. |
| **Install (npm)** | `npm install -g turbo` |
| **Verify** | `turbo --version` |
| **Project Types** | js monorepos |
| **Official Source** | https://github.com/vercel/turborepo |
| **Complements** | none |
| **Conflicts** | nx (pick one) |
| **When to Skip** | single-package projects, nx monorepos |

---

### nx

| Field | Value |
|-------|-------|
| **ID** | `nx` |
| **Binary** | `nx` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Smart monorepo build system with dependency graph, caching, and affected-only execution. |
| **Why for AI Agents** | Agents use nx affected to only test/build what changed. Project graph helps agents understand monorepo dependencies. |
| **Install (npm)** | `npm install -g nx` |
| **Verify** | `nx --version` |
| **Project Types** | js monorepos |
| **Official Source** | https://github.com/nrwl/nx |
| **Complements** | none |
| **Conflicts** | turbo (pick one) |
| **When to Skip** | single-package projects, turbo monorepos |

---

### bun

| Field | Value |
|-------|-------|
| **ID** | `bun` |
| **Binary** | `bun` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Fast JS runtime, bundler, package manager, and test runner. All-in-one toolkit. |
| **Why for AI Agents** | Bun's speed makes agent-driven install/test/run cycles faster. Package installs are 10-100x faster than npm. |
| **Install (macOS)** | `brew install oven-sh/bun/bun` |
| **Verify** | `bun --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/oven-sh/bun |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | projects committed to Node.js ecosystem |

---

### deno

| Field | Value |
|-------|-------|
| **ID** | `deno` |
| **Binary** | `deno` |
| **Category** | js-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Secure JavaScript/TypeScript runtime with built-in tooling (fmt, lint, test, bench). |
| **Why for AI Agents** | Built-in permissions model makes agent-executed scripts safer. No package.json needed for quick scripts. |
| **Install (macOS)** | `brew install deno` |
| **Verify** | `deno --version` |
| **Project Types** | js, ts |
| **Official Source** | https://github.com/denoland/deno |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | projects committed to Node.js ecosystem |

---

## Python Ecosystem

### ruff

| Field | Value |
|-------|-------|
| **ID** | `ruff` |
| **Binary** | `ruff` |
| **Category** | python-ecosystem |
| **Priority** | essential |
| **Agent Impact** | 9 |
| **Purpose** | Ultra-fast Python linter and formatter written in Rust. Replaces flake8, isort, black, and more. 10-100x faster. |
| **Why for AI Agents** | Agents lint and format Python code in one command. Near-instant execution means agents can lint on every edit. Replaces 3+ tools with one. |
| **Install (pip)** | `pip install ruff` |
| **Install (macOS)** | `brew install ruff` |
| **Install (pipx)** | `pipx install ruff` |
| **Verify** | `ruff --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/astral-sh/ruff |
| **Complements** | uv, mypy |
| **Conflicts** | black, isort, flake8 (ruff replaces all three) |
| **When to Skip** | never for Python projects |

---

### uv

| Field | Value |
|-------|-------|
| **ID** | `uv` |
| **Binary** | `uv` |
| **Category** | python-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Ultra-fast Python package manager and virtualenv creator. Drop-in replacement for pip + venv. 10-100x faster. |
| **Why for AI Agents** | Agents create venvs and install packages dramatically faster. `uv pip install` is a drop-in for `pip install`. |
| **Install (macOS)** | `brew install uv` |
| **Install (pip)** | `pip install uv` |
| **Verify** | `uv --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/astral-sh/uv |
| **Complements** | ruff |
| **Conflicts** | none (drop-in replacement, can coexist with pip) |
| **When to Skip** | none |

---

### mypy

| Field | Value |
|-------|-------|
| **ID** | `mypy` |
| **Binary** | `mypy` |
| **Category** | python-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Static type checker for Python. Catches type errors without running code. |
| **Why for AI Agents** | Agents run mypy to validate type annotations in generated Python code. Catches bugs at analysis time. |
| **Install (pip)** | `pip install mypy` |
| **Install (pipx)** | `pipx install mypy` |
| **Verify** | `mypy --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/python/mypy |
| **Complements** | ruff |
| **Conflicts** | pyright (pick one or use both — complementary in practice) |
| **When to Skip** | untyped Python codebases |

---

### pyright

| Field | Value |
|-------|-------|
| **ID** | `pyright` |
| **Binary** | `pyright` |
| **Category** | python-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Fast Python type checker from Microsoft. Faster than mypy, stricter defaults. |
| **Why for AI Agents** | Faster feedback loop than mypy. Agents get near-instant type-checking results. |
| **Install (npm)** | `npm install -g pyright` |
| **Install (pipx)** | `pipx install pyright` |
| **Verify** | `pyright --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/microsoft/pyright |
| **Complements** | ruff |
| **Conflicts** | mypy (pick one or use both) |
| **When to Skip** | untyped Python codebases |

---

### black

| Field | Value |
|-------|-------|
| **ID** | `black` |
| **Binary** | `black` |
| **Category** | python-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Opinionated Python code formatter. "The uncompromising code formatter." |
| **Why for AI Agents** | Agents format generated Python code to match project conventions. |
| **Install (pip)** | `pip install black` |
| **Install (pipx)** | `pipx install black` |
| **Verify** | `black --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/psf/black |
| **Complements** | isort |
| **Conflicts** | ruff format (ruff replaces black) |
| **When to Skip** | if ruff is adopted (ruff format replaces black) |

---

### isort

| Field | Value |
|-------|-------|
| **ID** | `isort` |
| **Binary** | `isort` |
| **Category** | python-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Python import sorter. Organizes imports alphabetically and by section. |
| **Why for AI Agents** | Agents sort imports in generated Python files to match project conventions. |
| **Install (pip)** | `pip install isort` |
| **Install (pipx)** | `pipx install isort` |
| **Verify** | `isort --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/PyCQA/isort |
| **Complements** | black |
| **Conflicts** | ruff (ruff replaces isort) |
| **When to Skip** | if ruff is adopted |

---

### pipx

| Field | Value |
|-------|-------|
| **ID** | `pipx` |
| **Binary** | `pipx` |
| **Category** | python-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 4 |
| **Purpose** | Install Python CLI tools in isolated environments. Prevents dependency conflicts. |
| **Why for AI Agents** | Agents recommend pipx for installing Python tools (ruff, mypy, black) without polluting the global Python environment. |
| **Install (macOS)** | `brew install pipx` |
| **Install (pip)** | `pip install pipx` |
| **Verify** | `pipx --version` |
| **Project Types** | python |
| **Official Source** | https://github.com/pypa/pipx |
| **Complements** | ruff, mypy, black |
| **Conflicts** | none |
| **When to Skip** | if uv is used for tool management |

---

## Go Ecosystem

### golangci-lint

| Field | Value |
|-------|-------|
| **ID** | `golangci-lint` |
| **Binary** | `golangci-lint` |
| **Category** | go-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Fast Go meta-linter. Runs 50+ linters in parallel with caching. |
| **Why for AI Agents** | Agents validate generated Go code with one command instead of running individual linters. Catches vet, staticcheck, and style issues. |
| **Install (macOS)** | `brew install golangci-lint` |
| **Install (go)** | `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` |
| **Verify** | `golangci-lint --version` |
| **Project Types** | go |
| **Official Source** | https://github.com/golangci/golangci-lint |
| **Complements** | gopls |
| **Conflicts** | none |
| **When to Skip** | non-Go projects |

---

### staticcheck

| Field | Value |
|-------|-------|
| **ID** | `staticcheck` |
| **Binary** | `staticcheck` |
| **Category** | go-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 7 |
| **Purpose** | Advanced Go static analysis. Finds bugs, suggests simplifications, enforces style. |
| **Why for AI Agents** | Deep analysis that catches subtle bugs in generated Go code. Included in golangci-lint but useful standalone. |
| **Install (go)** | `go install honnef.co/go/tools/cmd/staticcheck@latest` |
| **Verify** | `staticcheck --version` |
| **Project Types** | go |
| **Official Source** | https://github.com/dominikh/go-tools |
| **Complements** | golangci-lint |
| **Conflicts** | none |
| **When to Skip** | if golangci-lint is installed (includes staticcheck) |

---

### gopls

| Field | Value |
|-------|-------|
| **ID** | `gopls` |
| **Binary** | `gopls` |
| **Category** | go-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 6 |
| **Purpose** | Official Go language server. Powers IDE features and can be used for programmatic analysis. |
| **Why for AI Agents** | Provides type information and semantic analysis that agents can leverage for Go refactoring. |
| **Install (go)** | `go install golang.org/x/tools/gopls@latest` |
| **Verify** | `gopls version` |
| **Project Types** | go |
| **Official Source** | https://github.com/golang/tools |
| **Complements** | golangci-lint |
| **Conflicts** | none |
| **When to Skip** | non-Go projects |

---

## Rust Ecosystem

### clippy

| Field | Value |
|-------|-------|
| **ID** | `clippy` |
| **Binary** | `cargo-clippy` |
| **Category** | rust-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 8 |
| **Purpose** | Official Rust linter. Catches common mistakes, suggests idiomatic patterns. |
| **Why for AI Agents** | Agents run `cargo clippy` to validate generated Rust code. Catches safety and performance issues. |
| **Install (rustup)** | `rustup component add clippy` |
| **Verify** | `cargo clippy --version` |
| **Project Types** | rust |
| **Official Source** | https://github.com/rust-lang/rust-clippy |
| **Complements** | cargo-nextest |
| **Conflicts** | none |
| **When to Skip** | non-Rust projects |

---

### cargo-nextest

| Field | Value |
|-------|-------|
| **ID** | `cargo-nextest` |
| **Binary** | `cargo-nextest` |
| **Category** | rust-ecosystem |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Next-generation Rust test runner. Faster than cargo test with better output and retries. |
| **Why for AI Agents** | Agents get faster test results and clearer failure output. Supports per-test timeouts and retries. |
| **Install (cargo)** | `cargo install cargo-nextest` |
| **Verify** | `cargo nextest --version` |
| **Project Types** | rust |
| **Official Source** | https://github.com/nextest-rs/nextest |
| **Complements** | clippy |
| **Conflicts** | none |
| **When to Skip** | non-Rust projects |

---

### cargo-watch

| Field | Value |
|-------|-------|
| **ID** | `cargo-watch` |
| **Binary** | `cargo-watch` |
| **Category** | rust-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Watch for file changes and re-run cargo commands automatically. |
| **Why for AI Agents** | Enables continuous testing during agent-driven development. Agents can suggest watch commands. |
| **Install (cargo)** | `cargo install cargo-watch` |
| **Verify** | `cargo watch --version` |
| **Project Types** | rust |
| **Official Source** | https://github.com/watchexec/cargo-watch |
| **Complements** | cargo-nextest |
| **Conflicts** | none |
| **When to Skip** | non-Rust projects |

---

### cargo-expand

| Field | Value |
|-------|-------|
| **ID** | `cargo-expand` |
| **Binary** | `cargo-expand` |
| **Category** | rust-ecosystem |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Show the result of macro expansion. Debug derive macros and procedural macros. |
| **Why for AI Agents** | Agents use cargo-expand to debug macro issues by seeing the expanded code. |
| **Install (cargo)** | `cargo install cargo-expand` |
| **Verify** | `cargo expand --version` |
| **Project Types** | rust |
| **Official Source** | https://github.com/dtolnay/cargo-expand |
| **Complements** | clippy |
| **Conflicts** | none |
| **When to Skip** | projects without macros |

---

## Performance & System Tools

### hyperfine

| Field | Value |
|-------|-------|
| **ID** | `hyperfine` |
| **Binary** | `hyperfine` |
| **Category** | performance |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Command-line benchmarking tool. Statistical analysis of command execution time. |
| **Why for AI Agents** | Agents use hyperfine to measure performance improvements after optimizations. Provides statistical rigor. |
| **Install (macOS)** | `brew install hyperfine` |
| **Install (cargo)** | `cargo install hyperfine` |
| **Verify** | `hyperfine --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/sharkdp/hyperfine |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | non-performance-critical projects |

---

### dust

| Field | Value |
|-------|-------|
| **ID** | `dust` |
| **Binary** | `dust` |
| **Category** | performance |
| **Priority** | optional |
| **Agent Impact** | 3 |
| **Purpose** | Intuitive disk usage analyzer. Like du but with a visual tree. |
| **Why for AI Agents** | Helps agents identify large directories and files consuming disk space. |
| **Install (macOS)** | `brew install dust` |
| **Install (cargo)** | `cargo install du-dust` |
| **Verify** | `dust --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/bootandy/dust |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | none |

---

### duf

| Field | Value |
|-------|-------|
| **ID** | `duf` |
| **Binary** | `duf` |
| **Category** | performance |
| **Priority** | optional |
| **Agent Impact** | 2 |
| **Purpose** | Better df alternative — disk usage with colors and human-readable output. |
| **Why for AI Agents** | Quick disk space check when agents need to verify available space. |
| **Install (macOS)** | `brew install duf` |
| **Install (Linux/apt)** | `sudo apt install duf` |
| **Verify** | `duf --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/muesli/duf |
| **Complements** | dust |
| **Conflicts** | none |
| **When to Skip** | none |

---

### procs

| Field | Value |
|-------|-------|
| **ID** | `procs` |
| **Binary** | `procs` |
| **Category** | performance |
| **Priority** | optional |
| **Agent Impact** | 3 |
| **Purpose** | Modern ps replacement with color, tree view, and search. |
| **Why for AI Agents** | Agents identify running processes (dev servers, databases) more easily. |
| **Install (macOS)** | `brew install procs` |
| **Install (cargo)** | `cargo install procs` |
| **Verify** | `procs --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/dalance/procs |
| **Complements** | none |
| **Conflicts** | none |
| **When to Skip** | none |

---

### bottom

| Field | Value |
|-------|-------|
| **ID** | `bottom` |
| **Binary** | `btm` |
| **Category** | performance |
| **Priority** | optional |
| **Agent Impact** | 2 |
| **Purpose** | Cross-platform system monitor. CPU, memory, network, disk in one TUI. |
| **Why for AI Agents** | Monitor system resources during heavy agent operations or builds. |
| **Install (macOS)** | `brew install bottom` |
| **Install (cargo)** | `cargo install bottom` |
| **Verify** | `btm --version` |
| **Project Types** | all |
| **Official Source** | https://github.com/ClementTsang/bottom |
| **Complements** | procs |
| **Conflicts** | none |
| **When to Skip** | none |

---

## Container & Infrastructure Tools

### docker

| Field | Value |
|-------|-------|
| **ID** | `docker` |
| **Binary** | `docker` |
| **Category** | container |
| **Priority** | recommended |
| **Agent Impact** | 7 |
| **Purpose** | Container runtime. Build, run, and manage containers. |
| **Why for AI Agents** | Agents build and run containers for testing, manage docker-compose services, and use Docker for isolated environments. |
| **Install (macOS)** | `brew install --cask docker` |
| **Verify** | `docker --version` |
| **Project Types** | projects with Dockerfile or docker-compose |
| **Official Source** | https://docs.docker.com/get-docker/ |
| **Complements** | docker-compose, lazydocker, dive |
| **Conflicts** | none |
| **When to Skip** | serverless-only projects |

---

### lazydocker

| Field | Value |
|-------|-------|
| **ID** | `lazydocker` |
| **Binary** | `lazydocker` |
| **Category** | container |
| **Priority** | optional |
| **Agent Impact** | 4 |
| **Purpose** | Terminal UI for Docker. View containers, images, volumes, logs in one place. |
| **Why for AI Agents** | Quick overview of container state when debugging containerized services. |
| **Install (macOS)** | `brew install lazydocker` |
| **Verify** | `lazydocker --version` |
| **Project Types** | projects with Docker |
| **Official Source** | https://github.com/jesseduffield/lazydocker |
| **Complements** | docker |
| **Conflicts** | none |
| **When to Skip** | projects without Docker |

---

### dive

| Field | Value |
|-------|-------|
| **ID** | `dive` |
| **Binary** | `dive` |
| **Category** | container |
| **Priority** | optional |
| **Agent Impact** | 5 |
| **Purpose** | Docker image layer analyzer. Explore each layer to reduce image size. |
| **Why for AI Agents** | Agents use dive to analyze Dockerfile optimizations and identify wasted space in image layers. |
| **Install (macOS)** | `brew install dive` |
| **Verify** | `dive --version` |
| **Project Types** | projects with Dockerfile |
| **Official Source** | https://github.com/wagoodman/dive |
| **Complements** | docker |
| **Conflicts** | none |
| **When to Skip** | projects without Docker |

---

### ctop

| Field | Value |
|-------|-------|
| **ID** | `ctop` |
| **Binary** | `ctop` |
| **Category** | container |
| **Priority** | optional |
| **Agent Impact** | 3 |
| **Purpose** | Top-like interface for container metrics. Real-time CPU/memory per container. |
| **Why for AI Agents** | Quick performance check of running containers during development. |
| **Install (macOS)** | `brew install ctop` |
| **Verify** | `ctop --version` |
| **Project Types** | projects with Docker |
| **Official Source** | https://github.com/bcicen/ctop |
| **Complements** | docker, lazydocker |
| **Conflicts** | none |
| **When to Skip** | projects without Docker |

---

### kubectl

| Field | Value |
|-------|-------|
| **ID** | `kubectl` |
| **Binary** | `kubectl` |
| **Category** | container |
| **Priority** | recommended |
| **Agent Impact** | 6 |
| **Purpose** | Kubernetes CLI. Manage clusters, pods, services, deployments. |
| **Why for AI Agents** | Agents manage Kubernetes resources, check pod status, view logs, and apply manifests. |
| **Install (macOS)** | `brew install kubectl` |
| **Install (Linux/apt)** | `sudo apt install kubectl` |
| **Verify** | `kubectl version --client` |
| **Project Types** | projects with Kubernetes manifests |
| **Official Source** | https://kubernetes.io/docs/tasks/tools/ |
| **Complements** | k9s |
| **Conflicts** | none |
| **When to Skip** | non-Kubernetes projects |

---

### k9s

| Field | Value |
|-------|-------|
| **ID** | `k9s` |
| **Binary** | `k9s` |
| **Category** | container |
| **Priority** | optional |
| **Agent Impact** | 4 |
| **Purpose** | Terminal UI for Kubernetes. Navigate clusters, pods, logs interactively. |
| **Why for AI Agents** | Quick Kubernetes exploration when agents need to debug cluster state. |
| **Install (macOS)** | `brew install k9s` |
| **Verify** | `k9s version` |
| **Project Types** | projects with Kubernetes |
| **Official Source** | https://github.com/derailed/k9s |
| **Complements** | kubectl |
| **Conflicts** | none |
| **When to Skip** | non-Kubernetes projects |

---

## Selection Logic

When recommending tools for a project:

1. **Always recommend essential tools** (ripgrep, fd, gh, jq, ruff for Python)
2. **Match ecosystem**: Only recommend js-ecosystem tools for JS/TS projects, python-ecosystem for Python, etc.
3. **Resolve conflicts first**: If eslint+prettier already installed, do not recommend biome. If biome installed, do not recommend eslint/prettier.
4. **Prefer modern replacements**: For new projects without existing tooling, prefer biome over eslint+prettier, ruff over black+isort+flake8, uv over pip.
5. **Respect existing choices**: Never recommend removing an installed tool. Only suggest alternatives for missing tools.
6. **Cap recommendations**: Show max 15 tools per run to avoid overwhelming users.

## AI Agent Configuration

These environment variables and shell configurations optimize AI agent performance:

| Config | Value | Effect | Applies To |
|--------|-------|--------|------------|
| `USE_BUILTIN_RIPGREP=0` | `0` | Use system ripgrep instead of bundled Node.js wrapper. 2-5x faster. | Claude Code |
| Shell profile location | auto-detected | Where to add env vars (.zshrc, .bashrc, config.fish) | all |

Add to shell profile:
```bash
# AI Agent Acceleration
export USE_BUILTIN_RIPGREP=0
```

## Security Notes

- All tools are installed via official package managers (brew, apt, dnf, npm, pip, cargo)
- No tools require `curl | sh` or piped script installation
- All listed tools are open source with active maintenance
- Version minimums ensure known vulnerabilities are avoided
- The install script validates every command against an allowlist before execution
