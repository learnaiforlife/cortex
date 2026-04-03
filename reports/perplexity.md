# Audit and Analysis of learnaiforlife/cortex

## Executive summary

Cortex is a Claude Code skill that automates creation, auditing, and optimization of AI development setups (CLAUDE.md, .claude/, .cursor/, AGENTS.md, MCP configs) for arbitrary code repositories, targeting Claude Code, Cursor, and OpenAI Codex simultaneously. It does this by orchestrating seven specialized subagents plus several Bash and Python utilities for heuristic pre‑scanning, scoring, evals, experiment logging, and autoresearch-style self-improvement. The implementation is largely complete and internally consistent, but many guarantees in the README depend on large language model behavior rather than hard-coded logic, so real-world reliability will vary. Compared to adjacent tools like ai‑nexus, AGENTS.md Generator, and rule‑porter, Cortex is more ambitious (multi-tool, analysis-driven, self-optimizing) but also more complex and opinionated, making it best suited to advanced users already invested in Claude Code workflows.[^1][^2][^3][^4][^5][^6][^7]

Overall assessment: useful and relatively novel within its niche, with strong ideas and decent implementation quality, but still experimental and somewhat fragile.

- Usefulness: 8/10
- Originality: 8/10
- Maintainability: 7/10
- Adoption potential: 6/10

## What the project is

Cortex is an "intelligence layer" for AI-powered development, distributed as a Claude Code plugin/skill named `scaffold` plus companion commands `/scaffold`, `/scaffold-audit`, and `/scaffold-optimize`. After installation via `install.sh`, it copies the scaffold skill, agents, references, scripts, and evals into `~/.claude/skills/scaffold` and installs command descriptors into `~/.claude/commands`, integrating directly with the Claude Code environment rather than providing a standalone CLI.[^2][^1]

At a product level, Cortex promises:

- One-command scaffolding of a repo into AI-friendly configuration for Claude Code, Cursor, and Codex.
- Auditing of existing AI configurations for duplicates, staleness, and broken references.
- Optimization and self-improvement of its own scaffolding behavior using evals and iterative refinement.

The project also includes a `claude-code-auto-research` submodule that generalizes Karpathy’s `autoresearch` pattern to automatically optimize individual subagent prompts based on eval outcomes.[^3]

## What the code actually does

### Installation and integration

`install.sh` is the only executable entrypoint shipped; it copies everything under `skills/scaffold` into `~/.claude/skills/scaffold`, markes scripts executable, and installs the three command files into `~/.claude/commands/`. It does not modify Claude Code settings directly but prints guidance for manually integrating the provided `hooks/hooks.json` (a `SessionStart` hook that suggests running `/scaffold` when a repo has code but no CLAUDE.md).[^8][^2]

### Skill orchestration

The heart of the system is `skills/scaffold/SKILL.md`, which encodes the entire orchestrator behavior as a Claude skill definition with detailed multi-step instructions. It declares allowed tools (Bash, Read, Write, Edit, Glob, Grep, Agent, WebFetch) and routes behavior based on arguments into three main modes:[^4]

- Scaffold mode (default): analyze a repo and generate new AI setup.
- Audit mode: inspect existing AI setup and report issues via the `setup-auditor` agent.
- Optimize mode: inventory skills, check eval coverage, assess freshness of CLAUDE.md and MCP config, and optionally run an auto-improve loop on SKILL.md itself.[^4]

### Heuristic pre-scan and analysis

Before invoking subagents, the skill runs `scripts/analyze.sh` against the target repo to produce a `ProjectProfile` JSON that records detected file types, key config files, Docker services, and whether AI setup already exists. This is a pure-shell implementation (no external dependencies) and is resilient to missing tools.[^9]

Two subagents then perform parallel deep analysis:

- `repo-analyzer.md`: reads README, language manifests, entrypoints, tests, CI, configs, schemas, and directory structure to produce a structured markdown profile of project purpose, architecture, domain concepts, commands, protected files, and testing patterns.[^10]
- `skill-recommender.md`: reads the ProjectProfile and two reference catalogs (`official-plugins-catalog.md` and `mcp-catalog.md`), then recommends which official Claude Code plugins and MCP servers to use before designing any custom skills or agents.[^6][^11]

Simultaneously, the main skill thread reads key files like README, package manifests, and entrypoints for additional context.[^4]

### Generation pipeline

Using outputs from repo-analyzer, skill-recommender, and its own reading, the orchestrator instructs itself to generate a full set of outputs:

- Claude Code: `CLAUDE.md`, `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`, `.claude/rules/*.md`, `.claude/settings.json`, and `.mcp.json`.
- Cursor: `.cursor/rules/*.mdc` and `.cursor/mcp.json`, following a dedicated format reference with examples for monorepos and different rule-scoping modes.[^12]
- Codex: `AGENTS.md`, generated by the dedicated `codex-specialist` agent using ProjectProfile plus repo-analyzer output.[^13]

The skill emphasizes several invariants in its instructions:

- Never overwrite existing files blindly; always merge and preserve user content where present.
- Only include commands that actually exist in package manifests or build tooling.
- Only configure MCP servers for services that the project demonstrably uses, guided by the catalog.[^11][^4]

However, these invariants are enforced by prompts and lightweight scripts, not by deeply validating or executing commands against the repo.

### Quality gate, scoring, and evals

Before writing any files, the skill dispatches the `quality-reviewer` agent with all generated file contents and paths; this agent checks YAML frontmatter, placeholders, commands versus project context, MCP package plausibility, sensitive data, path conventions, duplicate content, structural completeness, and assigns a 0–100 quality score split across four dimensions. The reviewer outputs a PASS/FAIL verdict and a breakdown table, and the SKILL.md text states that a FAIL must block writing until issues are fixed.[^14][^4]

Separately, `scripts/score.sh` computes another 0–100 score by scanning the scaffolded repo on disk, using heuristics like file existence, content size, presence/absence of placeholders, counts of sections, agent bodies, workflow steps, and reasonable file counts. This is used both standalone and inside the eval runner.[^3]

`skills/scaffold/evals/evals.json` defines a suite of evals for specific scenarios (Next.js fullstack app, Python FastAPI API, minimal project, monorepo, official-first behavior, Codex format correctness, hallucination detection), each with human-readable expectations and machine-checkable assertions. `scripts/run-skill-evals.sh` runs these assertions against a previously scaffolded repo, using `score.sh` where needed and reporting pass/fail per assertion and eval.[^15]

Finally, `scripts/log-result.sh` logs each scaffold run into `~/.cortex/scaffold-results.tsv` with timestamp, repo identifier, scores per dimension, file counts, quality-reviewer verdict, whether the improver ran, whether it helped, and subagent timeouts, forming an append-only experiment log.[^3]

### Iterative improvement and autoresearch

If the quality-reviewer score is below a threshold (or has significant issues), SKILL.md triggers Step 6B, which dispatches the `scaffold-improver` agent to target the weakest scoring dimension (format, specificity, completeness, or structure), regenerate only related files, and then re-score; improvements are kept, regressions reverted.[^4]

Beyond per-run improvement, `/scaffold-optimize auto-improve` orchestrates a longer-running auto-improve loop for SKILL.md itself using `scripts/auto-improve.sh` and the `skill-improver` agent. Auto-improve scores all test fixtures, identifies the weakest dimension on average, asks skill-improver to make a single focused change to SKILL.md, rescored fixtures, and keeps or reverts changes based on whether the average score improves. The `claude-code-auto-research` submodule further generalizes this pattern to optimize individual subagent prompts (default target: `quality-reviewer.md`) via an external Claude CLI, `measure.py`, and a results.tsv log.[^3]

## Technical architecture and main components

### High-level architecture

At a high level, Cortex consists of:

- A single Claude skill (`scaffold`) that orchestrates the workflow and exposes three main modes plus one sub-mode.
- Seven Claude subagents: repo-analyzer, skill-recommender, codex-specialist, setup-auditor, quality-reviewer, scaffold-improver, skill-improver.[^10][^11][^13][^14]
- A set of Bash scripts implementing heuristics, scoring, eval-running, auto-improvement, and experiment logging (`analyze.sh`, `score.sh`, `run-skill-evals.sh`, `auto-improve.sh`, `log-result.sh`, plus wrapper scripts for local testing).[^9][^3]
- Reference documentation describing format specs for Claude, Cursor, and Codex, and catalogs of official plugins and MCP servers.[^11][^12]
- Test fixtures (Next.js+Prisma app, FastAPI API, minimal Node script) used to validate behavior and drive auto-improvement.
- An optional Python-based auto-research engine (`claude-code-auto-research/`) to optimize subagent prompts over time.[^3]

### Data and control flow

A typical `/scaffold <repo>` run executes the following pipeline (partially described in `docs/autoresearch-integration.md`):[^4][^3]

1. Acquire repo (clone or local path) and set `REPO_DIR`.
2. Run `analyze.sh` to produce a ProjectProfile JSON.
3. Dispatch `repo-analyzer` and `skill-recommender` in parallel while the main thread reads key files.
4. Check for existing AI setup; if present, read all existing files for merging.
5. Generate candidate outputs for Claude Code, Cursor, and Codex based on combined analysis and references.
6. Send all generated content to `quality-reviewer` for PASS/FAIL plus multi-dimensional scoring.
7. Optionally run `scaffold-improver` loop (up to 2 iterations) targeting weakest dimension.
8. Write files to disk, merging JSON and Markdown carefully where files already exist.
9. Run `score.sh` and log results with `log-result.sh`, including reviewer outcomes and improver metrics.

Error-handling and fallback chains are explicitly documented: if subagents time out, clone fails, or scoring scripts error, the skill gracefully degrades by skipping certain steps or emitting only minimal output (like CLAUDE.md) while warning the user.[^3][^4]

### Key components

- **`repo-analyzer`**: Implements a structured exploration workflow with explicit search patterns for main files, tests, schemas, CI configs, and protected files, and outputs a canonical multi-section markdown profile usable by other agents.[^10]
- **`skill-recommender`**: Encodes a strong "official-first" philosophy via an explicit decision tree and mapping between ProjectProfile signals and specific Claude plugins/MCP servers; custom skills and agents are designed only for uncovered gaps.[^11]
- **`codex-specialist`**: Converts analysis into a richly structured AGENTS.md, covering overview, architecture, commands, conventions, testing, instructions, dependencies, and common tasks, with strict rules to reference only real commands and files.[^13]
- **`setup-auditor`**: Crawls existing AI setup across Claude, Cursor, and Codex, cross-references with actual project config and manifests, and emits a categorized audit report with concrete fixes.
- **`quality-reviewer`**: Applies strict validation rules to generated content, including format checks, placeholder detection, command verification, MCP plausibility, sensitive-data filters, path conventions, duplicate detection, and structural completeness, with numeric scoring.[^14]
- **`score.sh` and `run-skill-evals.sh`**: Provide a deterministic scoring and assertion framework decoupled from the LLM, enabling regression testing and auto-improvement without needing to re-run full interactive scaffolds every time.[^3]
- **`auto-improve.sh` and `claude-code-auto-research`**: Implement iterative prompt optimization loops for SKILL.md and specific subagents, informed by eval expectations and scoring.[^3]

## Code quality and maintainability assessment

### Shell scripts and tooling

The Bash scripts (`analyze.sh`, `score.sh`, `run-skill-evals.sh`, `log-result.sh`, `auto-improve.sh`) are generally well-structured, with comments, defensive checks, `set -e`/`set -euo pipefail`, and clear separation of concerns. They avoid non-portable dependencies, relying only on standard Unix tooling plus Python or Node for JSON parsing when available, and include fallbacks for missing interpreters. Complexity is moderate but manageable; the main risk is subtle bugs in regex-based heuristics and file globbing that may not generalize perfectly to all repo shapes.[^9][^3]

### Skill and agent definitions

SKILL.md and the agent markdown files are long but internally consistent, using structured sections, explicit workflows, and detailed output formats that reduce ambiguity for Claude. The use of reference catalogs and format specs centralizes domain knowledge, which is good for maintainability. However, the sheer length and interdependence of SKILL.md, evals, and scripts mean changes must be made carefully to avoid drift; this is partially mitigated by the auto-improvement loops and eval suite.[^13][^14][^10][^11][^4]

### Python auto-research code

The `claude-code-auto-research` Python code is clean, typed at the docstring level, and uses robust subprocess handling, log file management, and snapshotting for best prompt versions. It follows the original `autoresearch` pattern faithfully: measure baseline, propose modifications via Claude CLI, measure again, keep or discard changes, and log results.[^3]

### Testing and validation

The presence of realistic fixtures and a non-trivial eval suite is a strong positive; evals go beyond file existence to check content size, regex matches for frameworks, absence of placeholders, file counts, and minimum scores. However, there is no fully automated CI pipeline in the repo (no `.github/workflows` or similar), and the eval runner does not itself execute `/scaffold`; it assumes that a scaffold run has already been performed for the target repo.[^15]

As a result, end-to-end correctness still depends on manual or interactive runs inside Claude Code, and the eval framework primarily checks structural properties, not dynamic behavior (e.g., whether commands actually succeed when executed).

### Maintainability risks

- Heavy reliance on prompt text: core control flow, error-handling, and business logic live inside SKILL.md and agent markdown, making refactoring more subtle than typical code changes.
- Expanding scope: supporting more frameworks, languages, and IDEs will increase SKILL.md complexity unless modularized or split into variants.
- External coupling: behavior depends on evolving Claude Code skill APIs, plugin catalogs, MCP ecosystems, and Codex/Cursor formats; maintaining compatibility requires ongoing effort.

Overall, code quality is above average for a prompt-and-script-based tool, but long-term maintainability will hinge on disciplined use of the eval and auto-improvement tooling.

## Similar and competing projects

Several adjacent tools aim to simplify or unify AI coding configurations across Claude Code, Cursor, Codex, and related tools.

### Notable alternatives

- **ai-nexus**: A CLI that lets users write rules once in plain Markdown and deploy them to Claude Code, Cursor, and Codex, including a semantic router that loads only relevant rules per prompt and a community rule marketplace.[^5]
- **AGENTS.md Generator**: A Claude Code skill that scans a repo and generates standardized AGENTS.md (and sometimes CLAUDE.md) with commands, tests, and architecture to ground AI agents in project-specific reality, with a safety-first approach.[^7]
- **rule-porter**: A CLI that reads `.cursor/rules/*.mdc` and converts them into CLAUDE.md, AGENTS.md, or Copilot instructions, handling frontmatter/globs and warning about lossy conversions.[^6]
- **akm and similar indexers**: Tools that index existing skills/rules across Claude Code, Cursor, and Codex to provide a unified search layer, without generating new scaffolds.

### Comparison table

| Tool | Primary purpose | Input | Outputs | Multi-tool coverage | Generation vs. conversion | Auto-optimization / evals | Distribution model |
|------|-----------------|-------|---------|----------------------|---------------------------|---------------------------|--------------------|
| **Cortex** | Analyze repos and generate complete AI dev setup (Claude, Cursor, Codex) with scoring, audits, and self-improvement.[^1][^3] | Existing repo (URL or path) | CLAUDE.md, .claude/agents, .claude/skills, .claude/rules, .claude/settings.json, .mcp.json, .cursor/rules/*.mdc, .cursor/mcp.json, AGENTS.md.[^4][^12][^13] | Claude Code, Cursor, Codex | Analysis-driven generation from codebase + manifests | Yes: score.sh, evals.json, quality-reviewer, scaffold-improver, auto-improve.sh, auto-research.[^3][^14][^15] | Claude Code skill installed via install.sh; no standalone CLI.[^2] |
| **ai-nexus** | Single-source-of-truth rule management and semantic routing across tools.[^5] | Plain Markdown rule files or team rule repo | .claude/rules/*.md, .cursor/rules/*.mdc, AGENTS.md, hooks/settings.[^5] | Claude Code, Cursor, Codex | Conversion and routing from canonical rule format | Limited: semantic router uses LLM/keyword selection but no eval-based self-improvement.[^5] | Standalone CLI (`npx ai-nexus`) with interactive wizard and marketplace.[^5] |
| **AGENTS.md Generator** | Generate AGENTS.md (and sometimes CLAUDE.md) from repo to improve Claude context.[^7] | Repo on disk (via Claude skill) | AGENTS.md (project overview, commands, architecture, testing, conventions).[^7] | Primarily Codex/Claude via AGENTS.md | Analysis-driven generation, but narrower scope (no Cursor, MCP, or skills).[^7] | Not documented; emphasis on one-off generation and safety (no overwrite). |
| **rule-porter** | Convert existing Cursor rules to other formats.[^6] | `.cursor/rules/*.mdc` | AGENTS.md, CLAUDE.md, Copilot instructions.[^6] | Cursor → Claude/Codex/Copilot | Pure conversion, with warnings about lossy mappings | None; focus on one-shot conversion with `--dry-run` previews.[^6] | Standalone CLI (`npx rule-porter`).[^6] |
| **akm** | Index/search skills and rules across tools without moving them. | Existing skill/rule directories | Search index, `akm search/show` results | Claude Code, Cursor, Codex (indirectly) | No generation; indexing and retrieval only | None; no scoring or evals mentioned. | Standalone CLI installed via shell script. |

In short, Cortex overlaps most with ai-nexus and AGENTS.md Generator but is differentiated by its focus on per-repo scaffolding (not global rule management), multi-artifact output (agents, skills, rules, MCP, hooks), and a built-in measurement and self-improvement loop.

## Usefulness assessment

### Plain-English explanation

For a developer or team that uses Claude Code (and possibly Cursor and Codex) heavily, Cortex can save substantial setup time by automatically generating the AI-facing documentation, agents, rules, and MCP configs that would otherwise be hand-written for each new project. It also helps keep those configs honest over time by auditing for stale commands, broken references, and misaligned frameworks, and by providing metrics and evals to understand how good a scaffold actually is.[^1][^15][^4][^3]

However, Cortex is not a push-button magic solution: it still depends on the quality of Claude’s reasoning, expects a reasonably conventional project layout, and assumes the user is comfortable running agent-driven workflows and shell scripts. It is particularly valuable for power users and teams standardizing AI development practices across multiple codebases, and less so for one-off scripts or developers who rarely switch between AI tools.

### Technical explanation

Technically, Cortex encodes a non-trivial multi-agent, multi-step pipeline entirely in Claude skill/agent prompts plus small shell and Python utilities. It tries to systematize best practices for AI development setup (project-specific CLAUDE.md, safe rules, calibrated agents, MCP wiring) and then enforces them via a combination of a strict quality-reviewer agent, deterministic scoring scripts, and an eval suite that encodes expectations as assertions.[^14][^15][^3]

This makes it a viable foundation for both manual and automated experimentation: one can run `/scaffold` across many repos, log scores, and iteratively improve SKILL.md and subagents via the auto-research loop as if they were model training code. Within that framing, Cortex is a fairly sophisticated “prompt engineering and tooling” project rather than an algorithmic codebase.

### Who should use this

- Teams using Claude Code as a primary AI coding tool and also relying on Cursor and/or Codex, who want consistent, high-quality AI configuration across many repos.
- Developers maintaining complex or safety-critical systems where incorrect AI behavior (e.g., editing generated code, running wrong commands) is costly, and who value quality gates and audits.
- Tooling/platform engineers building an internal AI developer platform, for whom the evals, scoring, and logs provide useful observability into AI setup quality.

### Who should avoid this

- Developers who only use a single AI coding tool or do not use Claude Code at all; many benefits of Cortex assume Claude Code as the orchestration layer.
- Small projects, scripts, or throwaway repos where writing a minimal CLAUDE.md and one or two rules by hand is faster than installing and tuning Cortex.
- Teams uncomfortable running auto-generated scripts or granting an AI agent significant control over configuration files and MCP connections.

## All possible use cases and scenarios

### Primary use cases

- **Initial AI setup for new or existing repos**: Run `/scaffold` on a new Next.js app, Python API, monorepo, etc., to generate a coherent CLAUDE.md, rules, agents, Cursor rules, and AGENTS.md, reducing the cognitive overhead of setting up each tool manually.[^1][^15][^4]
- **Auditing existing AI setups**: Use `/scaffold audit` to find duplicated rules, stale commands, hallucinated MCP servers, and low-quality CLAUDE.md content, then optionally auto-fix issues via the auditor’s suggested workflow.[^15]
- **Ongoing optimization of skills**: Run `/scaffold optimize` to inventory custom skills, generate evals, check CLAUDE.md and MCP freshness, and surface stale sections for manual or automated updates.[^15][^4]
- **Self-improvement / research**: Use `/scaffold-optimize auto-improve` and the auto-research tooling to iteratively refine SKILL.md or subagent prompts, treating prompt changes as experiments with measurable outcomes.[^3]

### Secondary/advanced scenarios

- **Benchmarking scaffolding strategies**: Compare Cortex’s scaffolds to hand-written setups or alternative tools (e.g., ai-nexus + AGENTS.md Generator) by running evals and scoring all outputs, using results.tsv files to track performance over time.
- **Monorepo specialization**: Apply Cortex to large monorepos (e.g., Turborepo) and validate whether produced CLAUDE.md and rules capture package boundaries and correct commands; adjust SKILL.md and evals further using the monorepo fixture/eval case.[^15]
- **Custom plugin/MCP catalogs**: Extend the official plugin and MCP catalogs with internal plugins or servers, allowing skill-recommender to treat them as first-class options.

### Edge cases and failure scenarios

- **Unusual or exotic tech stacks**: Projects without standard manifests (no package.json, pyproject.toml, go.mod, etc.) or with unconventional layouts may confound analyze.sh and repo-analyzer, leading to generic or incorrect scaffolds.
- **Very large monorepos**: While repo-analyzer and references mention monorepos, there is no dedicated SKILL variant; handling complex workspaces may rely heavily on the LLM’s ability to summarize sampled directories, and the monorepo eval case is aspirational rather than backed by explicit code paths.[^12][^10][^15]
- **Incomplete or misleading READMEs**: If README or manifests are outdated, Cortex may propagate stale frameworks, commands, or services into CLAUDE.md and MCP configs; quality-reviewer checks for placeholders and some inconsistencies but cannot fully detect semantic staleness.
- **Offline or restricted environments**: Git clone, `npx`-based MCP servers, and plugin installations assume internet connectivity and certain tooling; offline repos or limited dev environments could break parts of the pipeline.
- **Subagent timeouts or failures**: SKILL.md includes fallback logic when subagents or scoring scripts fail, but those fallbacks often mean reduced coverage (e.g., no ProjectProfile, no eval scoring), leading to weaker scaffolds.

## Pros and cons

### Pros

- **Multi-tool coverage**: First-class support for Claude Code, Cursor, and Codex in one run, including agents, rules, and MCP configs, is relatively unique among current tools.[^12][^1][^13][^4]
- **Official-first philosophy**: Systematic use of an official plugin and MCP catalog reduces duplication and keeps custom skills focused on genuinely project-specific workflows.[^11]
- **Strong safety and quality focus**: Quality-reviewer, scoring, evals, and audit mode all aim to prevent hallucinated commands, mismatched frameworks, and unsafe or low-quality configurations.[^14][^15][^3]
- **Self-improving architecture**: Auto-improve and auto-research patterns make SKILL.md and subagents measurable and tunable over time, which is rare in prompt-based tooling.[^3]
- **Good documentation and references**: The repo includes detailed docs on architecture, autoresearch integration, and format specs, plus realistic fixtures.[^12][^3]

### Cons

- **High complexity and learning curve**: Understanding how SKILL.md, agents, scripts, evals, and auto-research fit together requires non-trivial time and familiarity with Claude Code internals.
- **Reliance on LLM behavior**: Many guarantees (“never overwrite,” “only real commands,” “no hallucinated MCP servers”) are expressed as instructions rather than enforced by deterministic code, leaving room for subtle failures.[^14][^4]
- **Limited portability**: The tooling is deeply tied to Claude Code, Codex, and Cursor; users of other AI IDEs or chatbots gain little benefit without adopting this stack.
- **No turnkey end-to-end tests**: There is no CI that runs `/scaffold` headlessly across fixtures and asserts evals; the eval tooling assumes a prior run and is not automatically wired into a test runner.
- **Name collision and discoverability**: "Cortex" is a popular name with multiple other AI projects (e.g., enterprise AI platforms, vector DBs, decentralized AI networks), which may cause confusion.

## Risks and red flags

- **Overstated generality**: Claims like "works on any project" and "any language/framework" are aspirational; in practice, heuristics and evals focus on web/backend stacks (Next.js, FastAPI, Docker, Prisma, common DBs), and exotic stacks are likely to get weaker scaffolds.[^1][^9][^15]
- **Soft quality gate**: The requirement that quality-reviewer must PASS before writing is only encoded in SKILL.md text; there is no external enforcement, so prompt regressions or model behavior changes could allow low-quality outputs to be written.[^4][^14]
- **Command correctness not executed**: Quality-reviewer and evals check for the presence and shape of commands, but they never execute them; commands could still fail at runtime, especially in complex CI or multi-service setups.[^14][^15]
- **Vendor and ecosystem dependence**: The approach depends on Claude Code skills, official plugins, and MCP servers remaining available and compatible; ecosystem churn could quickly date the catalogs and instructions.[^11]
- **Security considerations**: While there are checks for obvious secrets and recommended use of env vars in MCP configs, enabling broad MCP access (GitHub, DBs, Sentry, Brave search) via automatically generated configs still requires careful human review to avoid over-privileged tokens or pointing at production resources.[^11]

## Improvement recommendations

1. **Add fully automated end-to-end tests**: Provide a test harness (e.g., a small Python or Bash runner plus a harness LLM) that actually invokes `/scaffold` against fixtures in non-interactive mode and then runs `run-skill-evals.sh`, making it easy to catch regressions before release.
2. **Strengthen hard constraints outside prompts**: Where feasible, add more deterministic checks in scripts (e.g., verifying that every command in skills exists in manifests; checking framework mentions against dependency lists) instead of relying solely on quality-reviewer.
3. **Expose a lightweight CLI wrapper**: Provide a simple command-line entrypoint that can run scaffold + scoring + evals headlessly given a repo path and a configure Claude API key, making integration into CI and platform tooling easier.
4. **Modularize SKILL.md**: Consider splitting SKILL.md into variants or including a more modular structure (e.g., per-language/per-framework includes) to reduce cognitive load and make evolution more manageable.
5. **Improve monorepo support**: Implement explicit detection and handling logic for common monorepo setups (Turborepo, pnpm workspaces, Nx) with specialized agents or SKILL variants, aligning actual behavior with the monorepo eval expectations.[^15]
6. **Broaden fixture coverage**: Add fixtures for Go, Rust, JVM, and mobile apps and extend evals accordingly, better justifying "any language" claims and catching stack-specific regressions.
7. **Clarify scope and disclaimers in README**: Make it explicit that guarantees are best-effort, that human review of generated configs is strongly recommended, and that certain stacks are better covered than others.
8. **Add observability into real-world runs**: Provide optional anonymized telemetry hooks or a structured export from scaffold-results.tsv so teams can analyze which repos and stacks perform poorly and prioritize improvements.

## Final verdict

Cortex is a well-thought-out and relatively mature attempt to systematize AI development setup across Claude Code, Cursor, and Codex, with particular strength in its measurement and self-improvement architecture. It is neither a trivial template pack nor a thin wrapper around existing tools; instead, it encodes a multi-agent, eval-driven approach that goes beyond current competitors like ai-nexus and AGENTS.md Generator in ambition, at the cost of higher complexity and reliance on specific tooling ecosystems.[^5][^7][^1][^4][^3]

For teams already committed to Claude Code and interested in running multiple AI tools against the same repos, Cortex is promising and likely to deliver real value, provided they treat it as an assistant whose outputs are reviewed and iterated, not as an infallible oracle. For casual or single-tool users, it may be overkill relative to simpler alternatives.

- **Usefulness**: 8/10
- **Originality**: 8/10
- **Maintainability**: 7/10
- **Adoption potential**: 6/10

## Confidence level and open questions

Confidence in this assessment is moderate-to-high based on direct inspection of SKILL.md, agents, scripts, docs, evals, and auto-research code, plus comparison with public descriptions of similar tools. Remaining uncertainties include:[^2][^7][^5][^6][^1][^3]

- How well the system performs on very large or unusual repos in practice.
- How reliably quality-reviewer and score.sh correlate with actual developer satisfaction and AI behavior quality.
- Whether the broader community will standardize around shared tools like ai-nexus and AGENTS.md Generator, or adopt more opinionated frameworks like Cortex.
- How quickly the authors can keep catalogs and prompts aligned with evolving Claude Code, Cursor, Codex, MCP servers, and plugin ecosystems.

---

## References

1. [Stop Copying Skills Between Claude Code, Cursor, and Codex](https://dev.to/itlackey/stop-copying-skills-between-claude-code-cursor-and-codex-olb) - You've got Claude Code at work, Codex for side projects, Cursor for quick edits. Each one has its ow...

2. [CognitiveScale Announces Launch Of Cortex Fabric Version 6 To Fuel Quick Development Of Large Scale, Trusted AI Campaigns](https://www.prnewswire.com/news-releases/cognitivescale-announces-launch-of-cortex-fabric-version-6-to-fuel-quick-development-of-large-scale-trusted-ai-campaigns-301334538.html) - /PRNewswire/ -- CognitiveScale, the enterprise AI company that helps organizations win with intellig...

3. [Repo for AI assistant configs (Cursor, Claude Code, Codex etc.)](https://www.reddit.com/r/cursor/comments/1oo564y/repo_for_ai_assistant_configs_cursor_claude_code/) - Claude Code configs (CLAUDE.md files, skills, hooks, the whole deal). Codex configs for autonomous a...

4. [Elixir Skills for Claude, Cursor, Codex - Dev Env / Tools / AI](https://elixirforum.com/t/elixir-skills-for-claude-cursor-codex/74180) - This first entry is a skill to automatically remove cyclic dependencies from your code base. Copy th...

5. [Inside Nishkarsh Srivastava's Journey to Build Cortex, the Intelligent ...](https://www.every.io/blog-post/inside-nishkarsh-srivastavas-journey-to-build-cortex-the-intelligent-retrieval-layer-for-ai-applications) - AI agents are transforming the way we work. But to be effective in our workflows, agents need access...

6. [convert your .mdc rules to CLAUDE.md, AGENTS.md, or Copilot](https://forum.cursor.com/t/rule-porter-convert-your-mdc-rules-to-claude-md-agents-md-or-copilot/153197) - I built a small CLI that reads your .cursor/rules/ directory and outputs the equivalent config for o...

7. [The Best AI Coding Workflow (Codex CLI + Cursor)](https://www.youtube.com/watch?v=BKQDPh-pjRQ) - In this video I guide you through the AI coding workflow I personally find the best. My programming ...

8. [CortxAI: Home](https://www.cortxai.tech) - Building intelligent systems at the edge of possibility.

9. [AGENTS.md Generator: Claude Code Skill for AI Context](https://mcpmarket.com/tools/skills/agents-md-context-generator) - Generates structured AGENTS.md and CLAUDE.md files to provide AI coding agents with essential projec...

10. [We got tired of switching from Claude Code to Codex to Cursor..etc ...](https://www.reddit.com/r/ClaudeCode/comments/1s5hfgd/we_got_tired_of_switching_from_claude_code_to/) - It keeps shared context, task state, and memory synced across Claude Code, Codex, and Cursor, so you...

11. [GitHub - loreum-org/cortex: Empowering seamless collaboration between human and AI agents through distributed intelligence.](https://github.com/loreum-org/cortex) - Empowering seamless collaboration between human and AI agents through distributed intelligence. - lo...

12. [I built a CLI that writes AI rules once for Claude Code, Cursor, and ...](https://dev.to/jsk9999/how-i-manage-ai-coding-rules-across-claude-code-cursor-and-codex-with-one-cli-3lmd) - Every AI coding tool has its own rule format. Claude Code uses .claude/rules/*.md . Cursor uses .cur...

13. [Claude vs Codex vs Cursor — what would you pick for serious side ...](https://www.reddit.com/r/vibecoding/comments/1r6htpy/claude_vs_codex_vs_cursor_what_would_you_pick_for/) - For what you care about, Claude Code is hard to beat for agent workflows and reasoning. The $20 tier...

14. [CORTEX AI - We Are CORTEX](https://www.wearecortex.com/cortex-ai/) - AI in telco is here and the revolution has begun. Importantly, Communication Service Providers are a...

15. [Claude Code just Built me an AI Agent Team (Claude ... - YouTube](https://www.youtube.com/watch?v=0J2_YGuNrDo) - I'd highly suggest to anyone who is not a developer to run Claude code in a sandbox environment such...

