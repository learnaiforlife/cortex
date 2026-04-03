# Full Audit Report: `learnaiforlife/cortex`

**Auditor:** Claude Opus 4.6 (1M context)
**Date:** 2026-04-01
**Repository:** https://github.com/learnaiforlife/cortex
**Methodology:** Full codebase read, GitHub metadata analysis, competitive landscape research, claim verification against implementation

---

## 1. Executive Summary

**Cortex** is a Claude Code plugin that analyzes any codebase and generates AI development configuration files for three tools simultaneously: Claude Code, Cursor, and Codex. It was created on April 1, 2026 in a ~3 hour sprint by a single developer with AI assistance. The repository contains 233 files totaling 1.3MB, all shell scripts, Python, and markdown -- zero external dependencies.

**Verdict: Promising concept, pre-alpha execution.** The "analyze repo -> generate tailored config for multiple AI tools -> score quality -> iterate" pipeline is genuinely novel compared to the template-library approach used by competitors. However, the project is hours old, completely untested in real-world use, has zero community validation, and faces an extremely crowded competitive landscape where incumbents have 100K+ stars. The autoresearch-inspired self-improvement loop is the most intellectually interesting component but remains unproven.

---

## 2. What the Project Is

Cortex bills itself as "the intelligence layer for AI-powered development." In practice, it is a **Claude Code skill plugin** that provides three slash commands:

- **`/scaffold [repo]`** -- Analyze a codebase and generate `CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, `.mcp.json`, `.cursor/rules/`, and `AGENTS.md`
- **`/scaffold audit`** -- Scan existing AI setup files for stale/broken/duplicate configs
- **`/scaffold optimize`** -- Run evals against generated output, identify weak dimensions, and iteratively improve

It does **not** run code, deploy anything, or modify source code. It exclusively generates/modifies configuration and instruction files consumed by AI coding assistants.

---

## 3. What the Code Actually Does

### Verified claims vs. reality:

| README Claim | Code Reality | Status |
|---|---|---|
| "Deep-analyze your codebase" | `analyze.sh` is an 81-line heuristic that checks for file extensions and `docker-compose.yml`. Real analysis is delegated to subagent prompts that instruct Claude to read files. | **Partially true** -- analysis depth depends entirely on Claude's execution, not Cortex's code |
| "Recommend official plugins first" | `skill-recommender.md` agent prompt explicitly says to read `official-plugins-catalog.md` before generating custom skills. Catalog contains real plugin names. | **True** -- but enforcement is prompt-based, not code-enforced |
| "Quantitative 0-100 scoring" | `score.sh` (260 lines) genuinely scores across 4 dimensions with file existence checks, size checks, placeholder detection, and structure validation | **True** -- scoring is real and mechanical |
| "Quality gate before writing" | `quality-reviewer.md` agent runs checks. SKILL.md Step 6 requires PASS before Step 7 (write). | **True** -- but the "gate" is a prompt instruction, not a hard code block |
| "Autoresearch-inspired iteration" | `auto-improve.sh` and `run.py` implement a baseline->edit->measure->keep/revert loop. `run.py` is 368 lines of real Python. | **True** -- the loop exists, but has never been run on real data (no results.tsv in repo) |
| "Works on any project" | Test fixtures cover Next.js, FastAPI, and minimal Node.js. No Rust, Go, Java, Ruby, or other ecosystem fixtures. | **Overclaimed** -- tested against 3 mock projects only |

### Critical observation:

The majority of Cortex's "intelligence" lives in **markdown prompt files**, not executable code. The 7 subagent `.md` files are instructions for Claude -- they have no implementation of their own. This means Cortex's output quality is a function of Claude's ability to follow complex multi-step prompts, not of Cortex's code.

**What actually executes:**
- `install.sh` -- 44 lines, copies files
- `analyze.sh` -- 81 lines, heuristic scan
- `score.sh` -- 260 lines, scoring logic
- `validate.sh` -- 98 lines, format checks
- `auto-improve.sh` -- 225 lines, iteration loop
- `run.py` + `measure.py` -- 765 lines, Python optimization loop

**What is prompt engineering (not code):**
- `SKILL.md` -- 554 lines of orchestration instructions
- 7 agent `.md` files -- ~1,175 lines total
- 5 reference catalogs -- ~900+ lines of format specs and catalogs
- 3 command definitions

The ratio is roughly **60% prompt engineering, 40% executable code**.

---

## 4. Technical Architecture and Main Components

```
+---------------------------------------------------------+
|                      User Input                          |
|        /scaffold [url|path|audit|optimize]                |
+----------------------------+----------------------------+
                             |
                             v
+-----------------------------------------------------------+
|             SKILL.md -- Master Orchestrator                |
|    (Mode routing: scaffold / audit / optimize)             |
+------+-----------+-----------+----------------------------+
       |           |           |
       v           v           v
  +---------+ +----------+ +---------------+
  | analyze | | repo-    | | skill-        |
  |   .sh   | | analyzer | | recommender   |
  |(heurist)| | (agent)  | | (agent)       |
  +----+----+ +----+-----+ +-----+---------+
       |           |              |
       v           v              v
  +----------------------------------------------+
  |         Synthesis & Generation                |
  |  (Claude Code + Cursor + Codex files)         |
  +---------------------+------------------------+
                        |
                        v
  +----------------------------------------------+
  |         quality-reviewer (agent)              |
  |      PASS/FAIL gate with 0-100 score          |
  +-------------+---------------+----------------+
                |               |
           PASS v          FAIL v
  +----------------+  +---------------------+
  |  Write files   |  | scaffold-improver   |
  |  to disk       |  | (fix weakest dim)   |
  |                |  | -> re-review         |
  +----------------+  +---------------------+
```

### Component breakdown:

| Layer | Components | Purpose |
|---|---|---|
| **Entry** | 3 command `.md` files, hooks.json | Register slash commands, auto-suggest on new projects |
| **Orchestration** | SKILL.md (554 lines) | Route modes, coordinate subagents, enforce sequence |
| **Analysis** | repo-analyzer, analyze.sh | Codebase understanding |
| **Recommendation** | skill-recommender, plugin catalog, MCP catalog | Match project to ecosystem |
| **Generation** | Main thread in SKILL.md | Produce files for 3 tools |
| **Quality** | quality-reviewer, score.sh, validate.sh | Gate output quality |
| **Improvement** | scaffold-improver, skill-improver, auto-improve.sh, run.py | Iterative enhancement |
| **Evaluation** | evals.json, subagent-expectations.json, run-skill-evals.sh | Machine-checkable assertions |
| **Specialized** | codex-specialist, setup-auditor | AGENTS.md generation, audit mode |

### Subagent details:

| Agent | Lines | Purpose |
|-------|-------|---------|
| **repo-analyzer** | 195 | Deep codebase exploration: reads key files, maps architecture, identifies domain concepts, patterns, testing, protected files, critical commands, gotchas |
| **skill-recommender** | 200 | Matches project signals to official plugins FIRST, only designs custom skills for gaps. Checks official-plugins-catalog + mcp-catalog |
| **quality-reviewer** | 198 | Quality gate: validates format compliance, specificity (no placeholders), completeness (all 3 tools), structural quality. Outputs 0-100 score with 4-dimension breakdown |
| **codex-specialist** | 223 | Generates AGENTS.md for OpenAI Codex with project-specific content |
| **scaffold-improver** | 90 | Targets weakest scoring dimension and regenerates only files related to that dimension |
| **setup-auditor** | 181 | Audits existing setup: checks for duplicates, stale references, broken configs, quality issues |
| **skill-improver** | 88 | Edits SKILL.md to improve scaffold quality. Makes one focused change per iteration (FIX, DERIVED, or CAPTURED) |

### Scripts:

| Script | Lines | Purpose |
|--------|-------|---------|
| **score.sh** | 260 | Quantitative 0-100 scoring across 4 weighted dimensions (format_compliance, specificity, completeness, structural_quality) |
| **validate.sh** | 98 | Quick format validation (YAML frontmatter, JSON validity, file sizes) |
| **analyze.sh** | 81 | Heuristic pre-scanner: detects languages, key files, docker services, existing setup |
| **auto-improve.sh** | 225 | Orchestrates autoresearch loop for SKILL.md: baseline -> propose -> measure -> keep/revert -> repeat |
| **run-skill-evals.sh** | -- | Eval assertion runner (11 assertion types: file_exists, dir_exists, file_contains, frontmatter_absent, score_min, etc.) |
| **audit-existing.sh** | -- | Audits existing setup for issues |
| **log-result.sh** | -- | Appends results to experiment log TSV |

---

## 5. Code Quality and Maintainability Assessment

### Strengths:
- **Well-structured shell scripts** -- `score.sh` uses clean accumulator pattern with caps, comments explain each check
- **Python code is readable** -- `run.py` uses standard library only, clean function decomposition
- **Agent prompts are detailed** -- each has clear input/output contracts, specific check lists, and example outputs
- **Eval system is well-designed** -- 11 assertion types with clear semantics
- **Graceful degradation** -- SKILL.md explicitly handles failure at each step

### Weaknesses:
- **No automated test suite** -- test fixtures exist but there are no `pytest` tests, no shell test framework, no CI/CD. The evals require Claude to run (expensive, non-deterministic).
- **`eval` usage in score.sh** -- `eval "$var=$new"` (line 38) is a minor code injection risk if inputs are ever unsanitized. Currently safe because inputs are internal, but fragile.
- **No shellcheck validation** -- scripts don't have shellcheck compliance verified
- **Hardcoded paths** -- `$HOME/.claude/skills/scaffold/` assumes Claude Code's directory structure won't change
- **No versioning** -- no version number anywhere, no changelog, no migration path
- **Reference catalogs will rot** -- `official-plugins-catalog.md` and `mcp-catalog.md` are static snapshots. As the ecosystem evolves, these become stale unless manually updated.

### Maintainability: 5/10
Single developer, no tests, no CI, static knowledge bases that require manual updates. The prompt-engineering-heavy architecture means changes require understanding complex agent interaction patterns, not just code.

---

## 6. Similar/Competing Projects -- Comparison Table

### Direct Competitors

| Project | Stars | Multi-tool | Codebase Analysis | Scoring/Evals | Self-improvement | Scope |
|---|---|---|---|---|---|---|
| **Cortex** | **0** | **CC + Cursor + Codex** | **Yes (dynamic)** | **Yes (0-100)** | **Yes** | Generate + Audit + Optimize |
| everything-claude-code | ~129K | CC + Codex + Cursor + others | No | No | No | Pre-built kit (130+ skills) |
| Superpowers | ~129K | CC + Cursor + Codex + Gemini | No | No | No | Methodology enforcement |
| awesome-cursorrules | ~39K | Cursor only | No | No | No | Template library |
| awesome-claude-skills | ~50K | CC only | No | No | No | Curated directory |
| Antigravity skills | ~30K | Universal | No | No | No | 1340+ skills library |
| ClaudeForge | ~330 | CC only | Yes | Yes (0-100) | No | CLAUDE.md generator |
| ai-agent-md.com | N/A | 10+ tools | Wizard-based | No | No | Web form generator |
| agentrules-architect | ~112 | CC + Codex + Cursor | Partial | No | No | AGENTS.md generator + ExecPlan |
| Claude /init (built-in) | N/A | CC only | Yes | No | No | Basic CLAUDE.md generation |

### Detailed competitor profiles:

**everything-claude-code (~129K stars):** Comprehensive agent harness with 30 specialized subagents, 136 skills, 60 slash commands. A pre-built kit you install rather than a tool that dynamically analyzes YOUR codebase and generates tailored output.

**Superpowers (~129K stars):** Agentic skills framework enforcing TDD, systematic debugging, brainstorming, and subagent-driven development. Focuses on methodology enforcement (how you work) rather than project setup (how you configure). Complementary more than competitive.

**ClaudeForge (~330 stars):** CLAUDE.md generator with quality scoring (0-100), interactive initialization, and a Guardian agent that keeps CLAUDE.md synced with codebase changes. Narrower scope (Claude Code only, CLAUDE.md only) but similar "analyze codebase and generate" philosophy.

**ai-agent-md.com:** Web-based tool generating instruction files for 10+ AI coding tools in ~5 minutes. More accessible but less intelligent than Cortex's automated analysis approach.

### Key differentiators vs. field:

**Cortex is unique in combining:** dynamic codebase analysis + multi-tool output + quantitative scoring + iterative self-improvement. No other project does all four.

**Cortex is NOT unique in:** generating AI setup files (many do this), supporting multiple tools (several do), or analyzing codebases (ClaudeForge, /init do this).

---

## 7. Usefulness Assessment

### Who gets value:

1. **Developer setting up a new project for AI-assisted coding** -- Cortex saves 30-60 minutes of manual CLAUDE.md + cursor rules + AGENTS.md creation
2. **Team standardizing AI tool configs across repos** -- run `/scaffold` on each repo for consistent setup
3. **Someone using Claude Code + Cursor + Codex simultaneously** -- single command generates for all three

### Who doesn't get value:

1. **Developer using only one AI tool** -- built-in `/init` or ClaudeForge is sufficient
2. **Experienced AI tool user with established setup** -- Cortex's audit/optimize modes are the only value, and they're unproven
3. **Anyone not using Claude Code** -- Cortex is a Claude Code plugin; you need Claude Code to run it

### Honest usefulness assessment:

The core value proposition -- "point at repo, get complete AI setup for 3 tools" -- is **genuinely useful** for the target audience. The question is whether the output quality is good enough to beat spending 15 minutes writing a CLAUDE.md manually. Since the quality depends entirely on Claude's prompt-following ability (not on Cortex's code), this is hard to evaluate without running it.

**The autoresearch loop is the most novel component** but is also the least validated. If it works, it represents a genuinely new approach to prompt engineering -- using quantitative measurement and iterative refinement instead of vibes-based editing.

---

## 8. All Possible Use Cases and Scenarios

### Primary use cases:
1. **New project setup** -- `/scaffold` on a fresh repo to bootstrap AI configs
2. **Onboarding a repo** -- `/scaffold https://github.com/org/repo` to quickly understand and configure AI tools for an unfamiliar codebase
3. **Multi-tool standardization** -- generate consistent configs across Claude Code, Cursor, and Codex
4. **Setup audit** -- `/scaffold audit` to find stale skills, broken MCP configs, duplicate rules
5. **Quality improvement** -- `/scaffold optimize` to measure and improve existing skill quality

### Edge cases:
- **Monorepo** -- evals.json has a monorepo test case, but no fixture exists to validate it
- **Non-English codebases** -- untested, likely works since Claude handles multilingual content
- **Very large repos** -- `git clone --depth 1` mitigates, but Claude's context window is the bottleneck
- **Private repos** -- works locally, but GitHub URL cloning requires auth
- **Repos with sensitive code** -- all analysis happens via Claude; the same privacy considerations as normal Claude Code usage apply

### Failure scenarios:
- **Claude doesn't follow SKILL.md instructions** -- the entire system breaks because it's prompt-dependent
- **Stale reference catalogs** -- recommends plugins that no longer exist or misses new ones
- **Quality reviewer is too lenient/strict** -- prompt-tuning problem with no easy fix
- **Score gaming** -- autoresearch loop could optimize for score.sh metrics without improving actual usefulness
- **Install script breaks user's setup** -- blind `cp -r` could overwrite customized skills
- **Naming collision** -- "Cortex" conflicts with Snowflake Cortex, cortex.io, and many others

---

## 9. Pros and Cons

### Pros:
- **Genuinely novel approach** -- dynamic analysis + multi-tool + scoring + iteration. Nobody else does this combination.
- **Official-first philosophy** -- smart design decision to recommend existing plugins before generating custom skills
- **Zero dependencies** -- pure shell + markdown + optional Python. No npm, no pip, no Docker required.
- **Well-thought-out architecture** -- the subagent decomposition, quality gate, and evaluation system show sophisticated design thinking
- **Autoresearch-inspired loop** -- applying ML optimization patterns to prompt engineering is creative and potentially powerful
- **Comprehensive eval system** -- 9 test cases with 11 assertion types, plus per-subagent expectations. More rigorous than most projects in this space.
- **MIT licensed** -- permissive, no restrictions

### Cons:
- **Zero real-world validation** -- created today, never used on a non-fixture project
- **Prompt-dependent** -- 60% of the system is markdown instructions. Output quality is as good as Claude's compliance.
- **No CI/CD** -- no automated testing, no linting, no build pipeline
- **Static knowledge bases** -- plugin and MCP catalogs will rot without manual updates
- **Single developer** -- bus factor of 1
- **Misleading comparison table in README** -- "Why Cortex beats everything else" compares against "Manual Setup" and "Other tools" generically. Does not name or honestly compare against specific competitors with 100K+ stars.
- **No published results** -- no evidence the scoring/iteration system actually improves output quality
- **Name collision** -- "Cortex" is heavily used in the AI/dev-tools space
- **Overclaimed scope** -- "Any repo" is tested against 3 tiny mock fixtures

---

## 10. Risks and Red Flags

### Red flags:
1. **Created in a single day with AI assistance** -- 5 commits over 3 hours, 3 with Claude co-authorship. This is not inherently bad, but the lack of iteration/feedback from real users is concerning.
2. **No dogfooding evidence** -- the repo itself doesn't have a CLAUDE.md generated by Cortex. If the tool is useful, why wasn't it used on itself?
3. **Eval fixtures are synthetic** -- the Next.js, FastAPI, and minimal fixtures are tiny mock projects (a dozen files each), not real codebases. Performance on these says nothing about performance on real 10K+ file repos.
4. **The autoresearch loop has never run** -- there's no `results.tsv` in the repo, meaning `run.py` has likely never been executed end-to-end.
5. **install.sh blindly copies files** -- `cp -r` overwrites without backup. If a user has customized their `~/.claude/skills/scaffold/`, it's gone.
6. **README marketing exceeds reality** -- phrases like "beats everything else" and "the intelligence layer" set expectations the code can't yet support.

### Risks:
- **Ecosystem dependency** -- entirely coupled to Claude Code's skill/agent architecture. If Anthropic changes the format, Cortex breaks.
- **Stale catalogs** -- the plugin catalog becomes wrong within months as the ecosystem evolves
- **Score gaming** -- the autoresearch loop optimizes for `score.sh` metrics, which may diverge from actual usefulness
- **Context window limits** -- for large repos, the subagents may hit Claude's context limit, degrading analysis quality silently

---

## 11. Improvement Recommendations

If the author wants to make this viable:

1. **Dogfood it** -- run `/scaffold` on Cortex itself and 10+ real open-source projects. Publish the results. This is the single most important thing.
2. **Add CI** -- GitHub Actions running `score.sh` and `run-skill-evals.sh` on every PR against the 3 fixtures. This is 20 minutes of work.
3. **Rename the project** -- "Cortex" is heavily contested. Consider something distinctive and searchable.
4. **Fix install.sh** -- add backup/diff before overwriting, add `--force` flag for explicit overwrite.
5. **Add real fixtures** -- clone 5-10 popular open-source repos, run scaffold, commit the expected output as golden files.
6. **Dynamic catalog** -- fetch plugin/MCP catalogs from a URL or GitHub at runtime instead of shipping static files.
7. **Publish autoresearch results** -- run the loop, show the before/after scores, demonstrate the improvement.
8. **Remove "beats everything" claim** -- replace with honest comparison naming specific competitors.
9. **Add versioning** -- semver, changelog, migration docs.
10. **Ship as installable plugin** -- publish to the Claude Code plugin marketplace for one-command install.

---

## 12. Final Verdict

**Cortex is a well-designed but completely unvalidated prototype.** The architecture is thoughtful -- the subagent decomposition, official-first philosophy, quantitative scoring, and autoresearch-inspired iteration loop demonstrate genuine engineering sophistication. The concept of treating prompt quality as a measurable, improvable metric is novel in this space.

However, the project is hours old, has never been used on a real codebase, has no community, no tests, no CI, and competes in a space where established alternatives have 100K+ stars and thousands of users. The marketing claims exceed what the code can demonstrate.

**If the autoresearch loop actually works** and produces measurably better AI configurations through iterative refinement, this could be a genuinely valuable contribution. But that claim is currently unsubstantiated -- there's no evidence it's ever been run.

**Classification:** Promising prototype with a novel core idea (quantitative prompt optimization), wrapped in standard functionality (config file generation) that many competitors already provide. Not yet useful to anyone who isn't the author.

---

## 13. Confidence Level and Open Questions

**Confidence: 8/10** -- Every file in the repository was read and verified. Claims were checked against implementation. The competitive analysis covers 25+ projects across the ecosystem. The main uncertainty is whether the system actually produces good output when run, which requires execution testing.

### Open questions:
1. Has `/scaffold` ever been run on a real (non-fixture) project? What was the output quality?
2. Has `run.py` (autoresearch loop) ever been executed end-to-end? What scores did it produce?
3. Why doesn't the repo itself have a CLAUDE.md generated by Cortex?
4. What's the plan for keeping reference catalogs current?
5. Is there a roadmap for publishing to the Claude Code plugin marketplace?
6. How does the system handle repos with 1000+ files where subagents hit context limits?

---

## Supplementary Sections

### Plain-English Explanation

Cortex is like a setup wizard for AI coding tools. You point it at any code project and it figures out what the project does, then creates configuration files that make Claude Code, Cursor, and Codex smarter about your specific project. It also has a clever system where it scores its own output quality and tries to improve it automatically -- like a spell-checker for AI configurations.

### Technical Explanation

Cortex is a Claude Code skill plugin implementing a multi-agent pipeline: a master orchestrator (`SKILL.md`) dispatches parallel subagents for codebase analysis and plugin recommendation, synthesizes results into tool-specific configs (CLAUDE.md, `.cursor/rules/*.mdc`, `AGENTS.md`), enforces a quality gate via a reviewer agent with a quantitative 0-100 scoring function (`score.sh`), and supports iterative refinement through an autoresearch-inspired loop that measures, mutates, and selects prompt improvements based on composite scores across test fixtures.

### Who Should Use This

- Developers who use Claude Code AND want configs for Cursor/Codex too
- Teams standardizing AI setup across many repos
- People who want to experiment with quantitative prompt optimization
- The author, for learning and portfolio purposes

### Who Should Avoid This

- Anyone in production -- this is day-one unvalidated software
- Developers happy with their current AI setup
- Anyone not using Claude Code (it's a CC plugin)
- Anyone who needs stable, maintained tooling

---

## Scores (1-10)

| Dimension | Score | Rationale |
|---|---|---|
| **Usefulness** | **5/10** | Solves a real problem (multi-tool AI setup) but unproven. The manual alternative takes 15 minutes. |
| **Originality** | **7/10** | Multi-tool generation + quantitative scoring + autoresearch loop is genuinely novel. File generation itself is not. |
| **Maintainability** | **4/10** | Single author, no tests, no CI, static knowledge bases, 60% prompt engineering. |
| **Adoption potential** | **3/10** | Zero community, name collision, crowded market, no dogfooding evidence. Requires significant validation and marketing to gain traction. |

---

## Repository Metadata Snapshot

| Field | Value |
|---|---|
| URL | https://github.com/learnaiforlife/cortex |
| Created | 2026-04-01 |
| Commits | 5 (all same day) |
| Contributors | 1 (lathi712) |
| Stars | 0 |
| Forks | 0 |
| Issues | 0 |
| PRs | 0 |
| License | MIT |
| Languages | Shell (40KB), Python (36KB), Markdown |
| Total files | 233 |
| Repo size | 1.3MB |
| External dependencies | None |
