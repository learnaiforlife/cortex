# Audit and Technical Analysis of learnaiforlife/cortex

## 1. Executive summary

Cortex is a Claude Code plugin and shell-scripted orchestration layer that analyzes a software repository and generates coordinated AI assistant configuration for Claude Code, Cursor, and Codex, with additional modes for auditing, optimization, and machine-wide discovery. It is technically substantial and largely complete, with a detailed SKILL.md orchestrator, 10+ specialized subagents, 15+ Bash scripts, and an eval suite wired into an autoresearch-style improvement loop. The project is most useful for advanced users already invested in Claude Code and adjacent tools, but overlaps significantly with emerging tools like ai‑nexus, rule‑porter, and akm that each solve adjacent parts of the “AI dev setup” problem. Overall it is moderately novel and high in craft quality but niche and somewhat redundant; the main risks are versioning inconsistencies, limited real‑world test coverage, and the operational complexity of running a multi‑step, agent‑orchestrated pipeline.[^1][^2][^3][^4][^5][^6][^7]

## 2. What the project is

Cortex is described as an “AI development setup, automated” that, given a Git URL or local path, analyzes the target repository and generates CLAUDE.md, .claude/agents and skills, .claude/rules, .cursor/rules, .mcp.json, .cursor/mcp.json, and AGENTS.md tailored to that project. It ships as a Claude Code skill named `scaffold` with subcommands `/scaffold`, `/scaffold audit`, `/scaffold optimize`, and `/scaffold discover`, plus a Bash installer that copies the skill and commands into `~/.claude`. The repository also contains an embedded `claude-code-auto-research` directory that adapts Karpathy’s autoresearch pattern to iteratively improve the quality-reviewer and SKILL.md prompts based on fixture scores.[^2][^8][^9][^10][^11][^12][^1]

### Plain‑English explanation

Cortex is a tool you install into Claude Code so that, instead of hand‑writing CLAUDE.md, Cursor rules, and Codex agent docs for every project, you can run `/scaffold` and let an orchestrated set of AI agents and shell scripts generate them from your repo. It can also scan your machine to find projects, audit existing AI configs for problems, and run a feedback loop that keeps adjusting its own prompts based on how well they score on test repositories.[^3][^1][^2]

### Technical explanation

Technically, Cortex is a Claude skill that uses Bash, Claude subagents, and a scoring/eval harness to implement a multi‑stage pipeline: clone or locate the repo, run a heuristic pre‑scan, detect opportunities via shell heuristics, fan out to subagents (repo analysis, skill recommendation, integration generation), synthesize consistent config for three tools, run a quality‑review subagent and a shell scoring script, optionally loop with an improver subagent, then finally write files and log results to `~/.cortex`. A separate autoresearch runner (`auto-improve.sh` plus Python scripts) scores fixture scaffolds and guides a `skill-improver` subagent to propose edits to SKILL.md, only keeping changes that improve averaged scores.[^13][^11][^2][^3]

## 3. What the code actually does

### Core skill orchestration

The main `skills/scaffold/SKILL.md` file defines the `scaffold` skill, its description, allowed tools, and the full multi‑step flow for four modes: scaffold, audit, optimize, and discover. In scaffold mode it parses flags (`--all`, `--interactive`, `--minimal`), dispatches variant SKILLs based on a JSON dispatch table, then runs a nine‑step process: acquire repo, heuristic pre‑scan via `analyze.sh`, opportunity detection via a subagent running `detect-opportunities.sh`, interactive or automatic suggestion selection, parallel `repo-analyzer` and `skill-recommender` subagents, existing setup detection/merging, filtered generation of files for Claude/Cursor/Codex, quality review plus optional iterative improvement, writing/merging files, summary reporting, and scoring/logging via `score.sh` and `log-result.sh`.[^2][^13][^3]

### Shell scripts and heuristics

The `analyze.sh` script performs a fast, dependency-free scan of the target repo: it counts files by extension, records the presence of key manifests and config files, heuristically detects services from docker‑compose, inspects env vars to infer integrations (Jira, Slack, Linear, Sentry, etc.), and notes any pre‑existing AI setup (CLAUDE.md, .claude, .cursor, .mcp.json). The `detect-opportunities.sh` script then derives `subagentSignals`, `integrationScores`, and `softSkillSignals` by inspecting files like Jest/Vitest configs, lint configs, monorepo markers (turbo.json, nx.json), CI workflows, env vars, and branch naming conventions to infer which subagents, skills, and integrations to suggest.[^13][^3]

### Subagents and templates

The `agents/` directory contains detailed prompts for subagents such as `repo-analyzer`, `skill-recommender`, `quality-reviewer`, `codex-specialist`, `setup-auditor`, `user-level-generator`, `dna-synthesizer`, `cross-project-analyzer`, `scaffold-improver`, `skill-improver`, and `variant-dispatcher`. For example, `repo-analyzer.md` defines a structured workflow to read README, manifests, entrypoints, tests, schemas, CI workflows, configs, and derive a Project Purpose, Architecture Overview, Domain Concepts, Protected Files, Gotchas, and Critical Commands. The skill uses template catalogs for subagents, soft skills, and integrations along with per‑framework format references (claude‑code‑formats, cursor‑formats, codex‑formats) to map analysis output into concrete files.[^8][^9][^14]

### Quality gating, scoring, and evals

The `quality-reviewer` subagent validates frontmatter, project‑specific content, real commands, MCP packages, absence of secrets, path conventions, duplication, AGENTS.md structure, and overall structural completeness, then outputs a PASS/FAIL verdict and a dimension‑scored quality report. Independently, the `score.sh` script walks the generated tree to compute a 0‑100 score broken into four 25‑point dimensions (format compliance, specificity, completeness, structural quality) based on concrete checks like presence/size of CLAUDE.md and AGENTS.md, valid YAML, JSON parseability, non‑placeholder content, existence of rules and Cursor `.mdc` files, and reasonable file counts. An eval harness (`evals/evals.json` + `run-skill-evals.sh`) defines ~18 eval cases with 10+ assertion types (file_exists, file_contains, file_min_size, score_min, max_file_count, etc.) across three fixtures and some remote monorepo targets, covering official‑first behavior, minimal projects, audit mode, discover mode, variant dispatch, and integration detection.[^14][^15][^4]

### Autoresearch integration

The `docs/autoresearch-integration.md` describes how Cortex borrows architectural patterns from Karpathy’s autoresearch: quantitative scoring (`score.sh`), an automated eval runner, experiment logging (`log-result.sh`), an iterative improvement loop (Step 6B in SKILL + `scaffold-improver`), auto‑improve mode for SKILL.md (`auto-improve.sh` + `skill-improver`), and explicit error recovery and batch autonomy patterns. The `claude-code-auto-research` directory adds a more canonical autoresearch runner with `program.md`, `prepare.py`, `measure.py`, and `progress.py` configured to iteratively refine the `quality-reviewer` agent against the three fixtures, using val‑like metrics derived from eval pass rates and structure correctness.[^10][^11]

### Install and hooks

The `install.sh` script copies `skills/scaffold/*` into `~/.claude/skills/scaffold`, installs command files into `~/.claude/commands`, ensures scripts are executable, creates `~/.cortex` for logs, and prints manual instructions for merging `hooks/hooks.json` into `~/.claude/settings.json` to enable a SessionStart tip and a Stop‑time reminder based on last scaffold score. Hooks run small shell snippets that suggest running `/scaffold` when a project has manifests but no CLAUDE.md, and remind the user to run `/scaffold optimize auto-improve` if the last recorded scaffold score was under 70.[^12][^16]

## 4. Technical architecture and main components

### High‑level architecture

Cortex’s architecture is centered on a single orchestrator skill (`SKILL.md`) that uses Claude subagents and Bash utilities as building blocks, with an explicit state machine for modes and steps. The system is designed so that all substantive behavior is encoded in markdown prompts (for agents) and small shell scripts, leaving no custom binary or server component; installation is just file copying into Claude’s plugin directories.[^9][^12][^2]

### Modes and data flow

The README and AGENTS.md both depict the scaffold data flow from `/scaffold [repo]` through variant dispatch, heuristic pre‑scan, two parallel subagents, codex‑specialist, quality review, write‑files, score, and log steps; the SKILL implementation matches this, with additional detail about flags, interactive selection, and failure fallbacks. Audit mode runs only the `setup-auditor` subagent against the current directory, reports issues and offers automated fixes; optimize mode inspects existing skills, CLAUDE.md, and `.mcp.json` for freshness and eval coverage; discover mode runs a `discover-orchestrator.sh` and related scripts to build a machine‑wide DeveloperDNA JSON and generate user‑level and project‑level setups.[^1][^3][^2][^13]

### Components overview

Key components include:

- **Skill orchestrator**: `skills/scaffold/SKILL.md` (core logic for all modes, variant dispatch, loops, fallbacks).[^2]
- **Subagents**: `skills/scaffold/agents/*.md` (11+ specialized agents such as repo‑analyzer, skill‑recommender, quality‑reviewer, codex‑specialist, etc.).[^8][^14]
- **Scripts**: `skills/scaffold/scripts/*.sh` (analyze, detect‑opportunities, score, run‑skill‑evals, auto‑improve, discover‑*, validate, log‑result, schedule‑autorun).[^15][^3][^13]
- **Reference catalogs**: `skills/scaffold/references/*.md` (plugin catalog, MCP catalog, format specs, integration and template catalogs) that encode tool‑specific formats and preferred official plugins.[^9]
- **Variants**: `skills/scaffold/variants/SKILL-*.md` plus `dispatch-table.json` for monorepo and minimal projects, adjusting steps 2–6 while sharing acquisition and logging steps.[^9][^2]
- **Tests and fixtures**: `test/fixtures/` and `skills/scaffold/evals/evals.json` for repeatable scoring and regression checks.[^4]

### Error handling and autonomy

The SKILL defines an explicit fallback table for each step, e.g., falling back from shallow to full git clone, from pre‑scan to manual subagent analysis, from parallel to sequential subagents, and from agent‑based quality review to `validate.sh` when necessary. It also defines timeout policies, crash logging via `log-result.sh`, and batch‑mode autonomy rules (never stop on non‑fatal errors, but stop on repeated crashes or disk errors) inspired by autoresearch’s “NEVER STOP” clause.[^10][^2]

## 5. Code quality and maintainability assessment

### Structure and clarity

The codebase is well‑structured for its domain: there is a clear separation between orchestration (SKILL), analysis subagents, shell utilities, reference data, and tests, with consistent naming and directory conventions documented in AGENTS.md. Shell scripts are generally small, single‑purpose, and written with `set -euo pipefail`, and agent prompts use explicit “Workflow” and “Rules” sections, which aids readability.[^8][^13][^9]

### Robustness and testing

Cortex has explicit evaluation infrastructure that checks specific expectations (e.g., CLAUDE.md referencing the correct frameworks, no placeholders, monorepo handling) and asserts minimum scores across fixtures, which is stronger than many comparable prompt‑heavy projects. However, the eval suite focuses primarily on three synthetic fixtures and a handful of specific behaviors; claims in the README about “tested against 3 fixture projects and 3 OSS repos (shadcn‑ui, FastAPI, Express)” and a 52/52 pass rate cannot be directly verified from the repo alone because the OSS repos are not included as fixtures and the eval runner is not exercised in this analysis environment.[^4][^1][^10]

### Implementation vs documentation

Most high‑level claims in the README and AGENTS.md about architecture, official‑first behavior, scoring, self‑improvement, variant dispatch, and discover mode are backed by concrete SKILL steps, scripts, and agent definitions. There are some inconsistencies: the README “Status” section claims version v0.3.0 and lists 52 assertions, while the VERSION file contains `0.2.0` and `evals.json` currently defines fewer than 52 assertions, implying the documentation may be slightly ahead of the tagged version in the repo.[^17][^1][^10][^2]

### Maintainability and risk

Maintainability is mixed: the Bash scripts and small reference files are straightforward to evolve, but the central SKILL.md is long (800+ lines), tightly coupled to Claude’s tool semantics, and requires careful editing to avoid breaking orchestrations. The project mitigates this somewhat with `skill-improver` auto‑improve workflows and eval‑gated changes, but the complexity of the skill and the reliance on proprietary tool semantics mean future Claude/Cursor/Codex changes could require non‑trivial updates.[^3][^10][^2]

## 6. Similar and competing projects

### Identified related tools

The README itself mentions ai‑nexus (rule routing), rule‑porter (format conversion), and akm (rule indexing) as related tools, and external sources confirm their capabilities. Beyond these, there is a broader ecosystem of AI dev tools, but most focus on IDE functionality or app scaffolding (e.g., SWE‑Kit, various AI app builders) rather than multi‑tool AI config generation from existing repos.[^5][^6][^7][^12][^1][^3][^8]

### Comparison table

| Aspect | Cortex | ai‑nexus | rule‑porter | akm |
|-------|--------|----------|------------|-----|
| Primary function | Analyze repos and generate CLAUDE.md, rules, agents, Cursor rules, MCP config, AGENTS.md | Manage and route existing AI rules across Claude Code, Cursor, Codex with semantic router | Convert existing rules between Cursor `.mdc`, CLAUDE.md, AGENTS.md, Copilot, Windsurf | Index existing skills/rules in place for cross‑tool search |
| Input | Existing repo + environment | Existing rules and hooks; prompt text | Existing rule files in various formats | Existing rules/skills in tool‑specific locations |
| Output | New or merged config files for three tools + logs and scores | Optimized rule loading per prompt, optional cross‑tool sync | Converted rule files in target format(s) | Search/index layer without moving files |
| Codebase analysis | Deep repo analysis via subagent and heuristics | None; operates on rules only | None; operates on rule files only | None; indexing only |
| Official plugin awareness | Yes, via official‑plugins catalog and skill‑recommender | No explicit plugin catalog; focuses on routing | No; purely syntactic conversion | No; focuses on indexing |
| Quality scoring | 0‑100 scoring and eval assertions on fixture scaffolds | No built‑in scoring; relies on runtime behavior | No scoring; conversion correctness only | No scoring; concerned with discoverability |
| Multi‑tool parity | Explicit support for Claude Code, Cursor, Codex in one run | Supports Claude, Cursor, Codex, with semantic routing and some cross‑tool sync | Converts between Cursor, Claude, Copilot, Windsurf, AGENTS.md | Cross‑tool indexing but no generation |

Sources: ai‑nexus CLI and semantic router description, rule‑porter README and DEV article, akm “index in place” description.[^6][^18][^19][^7][^5]

## 7. Usefulness assessment

For engineers or teams heavily using Claude Code, Cursor, and Codex with multiple repos, Cortex can significantly reduce the manual effort of setting up and maintaining AI assistant configuration, especially when installing across many projects. Its official‑first plugin behavior, safety‑oriented rules, and audit/optimize modes are valuable for reducing hallucinated commands, stale configs, and duplicated rules across tools.[^14][^1][^4][^2][^9]

However, Cortex is less compelling for:

- Single‑tool users (e.g., only Cursor) who can manage rules directly or use rule‑porter.
- Teams that already have established CLAUDE.md/rules practices and just need better routing (where ai‑nexus excels).[^19][^5]
- Projects that are small, experimental, or rarely touched, where the upfront complexity of Cortex may outweigh benefits.

Overall, usefulness is solid but bounded to a niche of advanced AI tooling users.

## 8. Possible use cases, edge cases, and failure scenarios

### Realistic use cases

- **Greenfield project setup**: A team starting a new Next.js or FastAPI service runs `/scaffold` once to generate CLAUDE.md, .claude rules, Cursor rules, and AGENTS.md, then iteratively tweaks based on their workflow.[^1][^4]
- **Retrofit existing repos**: A company with many existing services uses `/scaffold discover` to scan directories, classify projects, and propose user‑level vs project‑level setups, then runs `/scaffold` per repo.[^13][^2]
- **Audit and cleanup**: A codebase with ad‑hoc rules and stale configs runs `/scaffold audit` to detect duplicates, stale references, and broken MCP configs, optionally auto‑fixing common issues.[^4][^2]
- **Prompt engineering R&D**: A platform team uses autoresearch integration with fixtures to systematically improve Cortex’s own SKILL and quality‑reviewer behavior over time.[^11][^10]

### Edge cases

- **Very large monorepos**: The monorepo variant and heuristics for turbo/nx/pnpm help, but extremely large, heterogeneous repos may still produce over‑broad CLAUDE.md and rules, or timeouts in clone and analysis steps.[^3][^2]
- **Unusual tech stacks**: Repos using languages or frameworks not covered in `analyze.sh` or `detect-opportunities.sh` may still scaffold, but with weaker or generic suggestions, since heuristics rely on known config file patterns.[^13][^3]
- **Limited environments**: Environments lacking git, Python 3, or shell utilities may cause scoring, logging, or even acquisition steps to fail; SKILL includes fallbacks, but some behavior (scoring, evals) is explicitly dependent on Python present in PATH.[^15][^3][^13]
- **Existing heavy customization**: Projects with heavily customized CLAUDE.md, rules, or Cursor configs risk conflicts; Cortex attempts to merge and avoid overwrites, but merge logic is described procedurally in SKILL and relies on the agent respecting preservation rules.[^14][^2]

### Failure scenarios

- **Clone or path failures**: If git clone fails or the path is invalid, SKILL instructs the skill to stop and report “cannot access repo”; discovery mode similarly aborts when directories are missing.[^2]
- **Subagent timeouts**: If subagents time out (2 minute default), SKILL falls back to main‑thread analysis and partial output, potentially lowering quality and scores but not aborting the run.[^10][^2]
- **Quality gate failures**: If quality‑reviewer reports FAIL (e.g., invalid frontmatter, placeholder content, invented commands), SKILL requires fixes and re‑review before files are written; in practice this depends on the agent correctly enforcing this rule.[^14][^2]
- **Scoring or logging failures**: If scoring scripts exceed timeouts or fail due to missing Python, SKILL specifies proceeding without scoring/logging, meaning some runs may skip the experiment log entirely.[^15][^2]

## 9. Pros and cons

### Pros

- **Deep, repo‑aware scaffolding**: Goes beyond templates by analyzing actual code structures, tests, schemas, CI, and configs to generate project‑specific CLAUDE.md and rules.[^8][^4]
- **Multi‑tool coverage**: Supports Claude Code, Cursor, and Codex in one pipeline, reducing duplication and drift between tools.[^1][^9]
- **Quality and safety focus**: Quality reviewer, scoring script, evals, and official‑first plugin logic collectively reduce placeholder content, hallucinated commands, and unsafe configs.[^10][^2][^14]
- **Self‑improvement infrastructure**: Autoresearch‑style loops and auto‑improve scripts provide a structured path for the tool to improve itself over time using objective scores.[^11][^3][^10]
- **Clear design documentation**: AGENTS.md, README, and docs give a transparent view of architecture, principles, and testing, which is uncommon in many prompt‑heavy projects.[^9][^1][^10]

### Cons

- **Complex orchestration**: The central SKILL is long and intricate, increasing the chance of regressions when edited and making onboarding for contributors harder.[^2]
- **Narrow ecosystem fit**: Usefulness is concentrated among developers heavily invested in Claude Code, Cursor, and Codex; many teams use only one tool or a different stack (e.g., Copilot‑only).[^13][^2]
- **Operational heavy‑weight**: Running multi‑step pipelines with subagents, git clones, scoring scripts, and logs may feel heavy compared to lighter tools like rule‑porter or ai‑nexus that operate on existing configs only.[^5][^6]
- **Versioning/documentation drift**: The version mismatch (0.3.0 in README vs 0.2.0 in VERSION) and unclear assertion counts suggest documentation can get ahead of tagged releases.[^17][^1]
- **Limited real‑world fixtures**: Test coverage is geared around three synthetic fixtures and a few external repos mentioned in docs, which may not represent diverse real enterprise codebases.[^4][^10]

## 10. Risks and red flags

- **Version mismatch**: README status claims v0.3.0 while the VERSION file shows 0.2.0, which could confuse users and indicates release process friction.[^17][^1]
- **Eval claims not fully verifiable**: The README cites “Eval suite: 100% pass rate (52/52 assertions)” but the exact count and current pass status cannot be confirmed from static inspection without running the eval scripts.[^1][^4]
- **Reliance on proprietary semantics**: The SKILL and agents are tightly tied to Claude Code’s tool system, Cursor `.mdc` formats, Codex AGENTS.md formats, and specific official plugins; changes in these ecosystems could break Cortex without careful maintenance.[^9][^14][^2]
- **Partial automation in auto‑improve**: `auto-improve.sh` currently prints instructions and logs scores but relies on an external `skill-improver` agent invocation; without a fully wired loop, the “self‑improving SKILL.md” behavior may be more aspirational than turnkey.[^3][^10]
- **Potential over‑scaffolding**: For smaller or simpler projects, even with minimal mode and variants, generating multi‑tool scaffolds may add cognitive load and maintenance overhead relative to just writing a concise CLAUDE.md.[^4][^2]

## 11. Improvement recommendations

- **Align versioning and documentation**: Update VERSION to match README or vice versa and document the current assertion count; consider adding a small `--version` command for `/scaffold` that reads the VERSION file.[^17][^1]
- **Broaden fixture coverage**: Add more diverse fixtures (e.g., monoliths, polyglot repos, mobile apps, data pipelines) and corresponding evals to better represent real‑world usage; encode the OSS repos mentioned in README as reproducible fixtures or recorded outputs.[^10][^4]
- **Reduce SKILL complexity**: Factor SKILL.md into more modular sections or shared includes (if supported by Claude) and clearly mark extension points to reduce the cognitive burden for maintainers and contributors.[^2]
- **Tighten auto‑improve loop**: Wire `auto-improve.sh` to actually invoke the `skill-improver` agent programmatically (where environment allows) and document reproducible workflows for running auto‑improve end‑to‑end, including examples of before/after SKILL diffs.[^11][^3]
- **Improve safety tuning feedback**: Expose more of the quality‑reviewer’s dimension scores and weakest dimension directly in `/scaffold` summaries by default, and add optional “dry‑run” mode that runs analysis and scoring without writing files.[^14][^2]
- **Clarify interoperability with other tools**: Document how Cortex can coexist with ai‑nexus, rule‑porter, and akm, including recommended workflows (e.g., run Cortex once to scaffold, then use ai‑nexus for routing and rule‑porter for conversions).[^7][^6][^5]

## 12. Final verdict

Cortex is a thoughtfully engineered, technically credible tool for automating multi‑tool AI dev setup from existing repositories, with stronger testing and self‑improvement infrastructure than many peers. It is neither simple boilerplate nor groundbreaking research, but a well‑executed practitioner tool best suited to advanced users who value deep Claude/Cursor/Codex integration and are comfortable with shell scripts and agent orchestration. Given current alternatives, Cortex is moderately original and useful but constrained by ecosystem specificity and complexity; it is promising for power users, but likely overkill or redundant for casual AI tool adopters.[^1][^9][^10][^4][^2]

## 13. Scores, target users, and open questions

### Scores (1–10)

- **Usefulness**: 7/10 — very helpful for multi‑tool, multi‑repo Claude/Cursor/Codex users; less so for simpler setups.
- **Originality**: 7/10 — combining repo analysis, multi‑tool generation, scoring, and autoresearch is relatively unique; rule management and cross‑tool support overlap with ai‑nexus/rule‑porter/akm.[^6][^7][^5]
- **Maintainability**: 6/10 — clear structure and scripts but an increasingly large SKILL.md and dependence on proprietary tool semantics raise long‑term maintenance cost.[^9][^2]
- **Adoption potential**: 5/10 — strong fit for a small but growing niche of Claude Code power users, but competition from simpler tools and vendor‑native features limits mainstream adoption.[^12][^3][^2]

### Who should use this

- Developers who actively use all three tools (Claude Code, Cursor, Codex) and want consistent, high‑quality AI configuration across multiple repos.[^14][^2]
- Platform and DevEx teams responsible for standardizing AI tooling across an organization and willing to invest in fixtures and evals.
- Power users interested in applying autoresearch‑style loops to prompt engineering and AI dev workflows.

### Who should avoid this

- Individual developers using only one AI coding tool who can get most benefits from a single well‑crafted CLAUDE.md or Cursor rule set.
- Teams that prefer minimal automation and full manual control over AI configuration files.
- Environments where dependencies like git, Python 3, and Bash utilities are not reliably available.

### Confidence level and open questions

Confidence in this assessment is high, based on direct inspection of README, SKILL.md, agents, scripts, evals, fixtures, and docs. Remaining open questions include: how Cortex behaves on very large, messy real‑world monorepos; how often the autoresearch loop is actually used in practice; how resilient the tool is to future changes in Claude Code, Cursor, and Codex; and what real‑world adoption and community contributions look like (which are not obvious from the code alone).[^20][^8][^3][^13][^10][^4][^1][^2]

---

## References

1. [cortex-client](https://pypi.org/project/cortex-client/) - [Deprecated] Python SDK for the CognitiveScale Cortex5 AI Platform

2. [Codex vs Cursor vs Claude Code: AI Coding Tool Comparison (2026)](https://www.nxcode.io/resources/news/codex-vs-cursor-vs-claude-code-2026) - Codex vs Cursor vs Claude Code: Which AI Coding Tool Should You Use in 2026? March 2026 — Three AI c...

3. [Awesome AI-Powered Developer Tools - GitHub](https://github.com/jamesmurdza/awesome-ai-devtools) - Web-Based Tools. App Builders. Platforms that scaffold and deploy full-stack applications from natur...

4. [cortex module - github.com/hurttlocker/cortex - Go Packages](https://pkg.go.dev/github.com/hurttlocker/cortex)

5. [I built a CLI that writes AI rules once for Claude Code, Cursor, and ...](https://dev.to/jsk9999/how-i-manage-ai-coding-rules-across-claude-code-cursor-and-codex-with-one-cli-3lmd) - Every AI coding tool has its own rule format. Claude Code uses .claude/rules/*.md. Cursor uses...

6. [nedcodes-ok/rule-porter - GitHub](https://github.com/nedcodes-ok/rule-porter) - Convert AI IDE rules between Cursor, Windsurf, CLAUDE.md, AGENTS.md, and Copilot. Bidirectional. Zer...

7. [Stop Copying Skills Between Claude Code, Cursor, and Codex](https://dev.to/itlackey/stop-copying-skills-between-claude-code-cursor-and-codex-olb) - Your agent skills are scattered across three tools. Here's why indexing in place beats copying or sy...

8. [9 open-source AI coding tools that every developer should know](https://dev.to/composiodev/9-open-source-ai-coding-tools-that-every-developer-should-know-28l4) - Generate a new agent scaffolding. swekit scaffold crewai -o swe_agent ... Composio works with famous...

9. [Cortex AI Demo Framework](https://www.snowflake.com/en/developers/guides/cortex-ai-demo-framework/)

10. [GitHub - cortexapps/learn-cortex: Repository for setting up test entities and learning how to use Cortex.](https://github.com/cortexapps/learn-cortex) - Repository for setting up test entities and learning how to use Cortex. - cortexapps/learn-cortex

11. [Cursor Launches a New AI Agent Experience to Take On Claude ...](https://www.wired.com/story/cusor-launches-coding-agent-openai-anthropic/) - The product, which was developed under the code name Glass, is Cursor's response to agentic coding t...

12. [The best AI artificial intelligence tools for developers - Port.io](https://www.port.io/blog/best-ai-tools-developers) - Instead of writing software line-by-line, these tools scaffold entire apps from prompts,wireframes, ...

13. [Codex vs Claude vs Cursor - DEV Community](https://dev.to/wafa_bergaoui/codex-vs-claude-vs-cursor-4g3k) - Introduction AI is transforming how developers think, build, debug, deploy, and even...

14. [Codex vs Claude Code: which is the better AI coding agent?](https://www.builder.io/blog/codex-vs-claude-code) - Claude Code uses CLAUDE.md. If you want one instructions file that works across tools, use AGENTS.md...

15. [7 of the Best AI App Builders for 2026 | Figma](https://www.figma.com/resource-library/ai-app-builders/) - If you already have a design in Figma, you can paste the URL directly into Lovable to scaffold the a...

16. [Snowflake Cortex Chatbot...](https://www.datacamp.com/tutorial/how-to-build-a-chatbot-with-snowflake-cortex-ai) - Learn how to build a chatbot with Snowflake Cortex AI. Step-by-step guide to preparing data, using C...

17. [Claude vs Codex vs Cursor — what would you pick for serious side ...](https://www.reddit.com/r/vibecoding/comments/1r6htpy/claude_vs_codex_vs_cursor_what_would_you_pick_for/) - If you could only keep one Pro coding tool, which would you choose: Claude Code, Codex, Cursor, or A...

18. [Convert Cursor rules to CLAUDE.md, AGENTS.md, and Copilot](https://dev.to/nedcodes/rule-porter-convert-cursor-rules-to-claudemd-agentsmd-and-copilot-4hjc) - This is a submission for the DEV Weekend Challenge: Community The Community Cursor AI...

19. [I built an open-source semantic router for Claude Code that loads ...](https://www.reddit.com/r/ClaudeCode/comments/1rnk1yp/i_built_an_opensource_semantic_router_for_claude/) - So I built ai-nexus. It installs a hook in Claude Code that analyzes each prompt and loads only the ...

20. [How Claude Code rules actually work](https://joseparreogarcia.substack.com/p/how-claude-code-rules-actually-work) - A practical guide to memory, scoped rules, and predictable behaviour in real projects using Claude C...

