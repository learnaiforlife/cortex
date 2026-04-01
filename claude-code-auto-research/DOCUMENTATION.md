# Claude Code Auto-Research — Complete Documentation

> Everything that was researched, decided, and built — from initial investigation through final implementation.

---

## Table of Contents

1. [Research Phase: Understanding Both Projects](#1-research-phase-understanding-both-projects)
2. [Analysis Phase: What Transfers and What Doesn't](#2-analysis-phase-what-transfers-and-what-doesnt)
3. [Architecture Decisions](#3-architecture-decisions)
4. [Implementation: Every File Explained](#4-implementation-every-file-explained)
5. [How Cortex's Existing Infrastructure Was Leveraged](#5-how-cortexs-existing-infrastructure-was-leveraged)
6. [Scoring System Design](#6-scoring-system-design)
7. [Usage Guide](#7-usage-guide)
8. [Future Improvements](#8-future-improvements)

---

## 1. Research Phase: Understanding Both Projects

### 1.1 What is Cortex?

**Cortex** is an intelligent scaffolding system that analyzes any software repository and automatically generates complete, production-ready AI development setups for three tools simultaneously:

- **Claude Code**: CLAUDE.md, agents, skills, rules, MCP configs, hooks, settings.json
- **Cursor**: `.cursor/rules/*.mdc`, `.cursor/mcp.json`
- **Codex**: `AGENTS.md`

**Key components explored:**

| Component | Path | Purpose |
|-----------|------|---------|
| Master orchestrator | `skills/scaffold/SKILL.md` | Three modes: scaffold, audit, optimize |
| Repo analyzer agent | `skills/scaffold/agents/repo-analyzer.md` | Deep codebase exploration |
| Skill recommender agent | `skills/scaffold/agents/skill-recommender.md` | Matches needs to official plugins first |
| Quality reviewer agent | `skills/scaffold/agents/quality-reviewer.md` | Quality gate before writing files |
| Codex specialist agent | `skills/scaffold/agents/codex-specialist.md` | Generates AGENTS.md for Codex |
| Setup auditor agent | `skills/scaffold/agents/setup-auditor.md` | Audits existing AI setups |
| Official plugins catalog | `skills/scaffold/references/official-plugins-catalog.md` | Curated list of official plugins |
| MCP catalog | `skills/scaffold/references/mcp-catalog.md` | Known MCP servers with detection signals |
| Eval suite | `skills/scaffold/evals/evals.json` | 9 eval cases with 3-10 expectations each |
| Heuristic scanner | `skills/scaffold/scripts/analyze.sh` | Fast pre-scan of project structure |
| Validator | `skills/scaffold/scripts/validate.sh` | Structural correctness checks |
| Test fixtures | `test/fixtures/` | 3 test repos (nextjs-app, python-api, minimal) |

**Cortex's optimize mode** (SKILL.md lines 260-330) was identified as the key gap: it checks freshness and generates evals but has **no autonomous iteration loop**. It reports problems without fixing them.

### 1.2 What is karpathy/autoresearch?

**autoresearch** (62.9K GitHub stars) is an open-source project by Andrej Karpathy that enables AI agents to autonomously run ML experiments overnight. The core concept:

```
Agent modifies train.py → trains for 5 min → measures val_bpb → keeps/discards → repeats
```

**Key architecture (only 3 files):**

| File | Role | Agent can modify? |
|------|------|-------------------|
| `prepare.py` | Downloads data, trains tokenizer | No (fixed) |
| `train.py` | Full GPT model + training loop | Yes (the optimization target) |
| `program.md` | Human programs the research strategy | No (human writes this) |

**Key design principles:**
- **Single file to modify** — keeps scope manageable, diffs reviewable
- **Fixed time budget** (5 min) — all experiments are directly comparable
- **Self-contained** — one GPU, one file, one metric (`val_bpb`)
- **`program.md` as the human interface** — you program the strategy, not individual experiments
- **~12 experiments/hour, ~100 overnight** — removes the human bottleneck

### 1.3 What Already Existed in the Ecosystem

The `skill-creator` plugin (installed at `~/.claude/skills/skill-creator/`) was discovered to already implement a structurally similar loop:

- `scripts/run_loop.py`: Eval-improve cycle with train/test split, parallel workers, live HTML report
- `scripts/run_eval.py`: Tests skill trigger accuracy via `claude -p` with stream-JSON parsing
- `scripts/improve_description.py`: Uses Claude to generate improved descriptions based on failures
- `scripts/aggregate_benchmark.py`: Aggregates benchmark results with mean/stddev/min/max

However, `skill-creator` operates on **skill descriptions** (trigger accuracy), while autoresearch operates on **code** (numeric metric). Cortex needed something in between: optimize **subagent prompts** against **multi-dimensional quality metrics**.

---

## 2. Analysis Phase: What Transfers and What Doesn't

### 2.1 What Transfers Well

| Autoresearch Concept | How It Maps to Cortex |
|---|---|
| `train.py` (the thing being optimized) | Subagent prompt files (e.g., `quality-reviewer.md`) |
| `val_bpb` (the metric) | Composite score from expectation pass rate + structural checks + hallucination detection |
| `program.md` (human programs strategy) | `program.md` defining optimization goals, constraints, stop conditions |
| Fixed time budget | Fixed token/time budget per eval run |
| Keep-best-version tracking | `snapshots/best/` directory with highest-scoring version |
| Autonomous iteration loop | `run.py` loop: propose → measure → keep/discard → repeat |
| Experiment log | `results.tsv` with iteration, score, delta, change summary, status |

### 2.2 What Does NOT Transfer

| Challenge | Why | Mitigation |
|-----------|-----|------------|
| **No single numeric metric** | ML has `val_bpb`; scaffold quality is multi-dimensional (structural, semantic, completeness, hallucination) | Designed a composite score with configurable weights |
| **Cost per experiment** | ML experiment ~$0.10; scaffold run involves multiple LLM calls ~$2-5 | Optimize subagents independently; use cheaper models for grading; cap iterations |
| **Stochastic output** | ML training with same data → deterministic; LLM output varies per run | Multiple runs per iteration (`runs_per_iteration: 2`); take best run |
| **100 experiments overnight** | Too expensive for LLM-based evaluation (~$200-500) | Capped at 10 iterations per session; can resume across sessions |

### 2.3 Decision: Standalone Folder vs. Integration

**Initial proposal**: Embed autoresearch patterns directly into Cortex's SKILL.md optimize mode.

**User preference**: Create a standalone `claude-code-auto-research/` folder inside the Cortex project.

**Rationale**: Keeps the autoresearch tooling independent and self-contained. Can be tested, iterated, and understood without modifying Cortex's core scaffold logic. The best versions produced can be manually applied back to Cortex subagents.

---

## 3. Architecture Decisions

### 3.1 Decision: Optimize Subagents Independently (Not End-to-End)

Running a full scaffold pipeline per experiment would cost $2-5 and take 5-10 minutes. Instead, each subagent is tested independently against fixtures:
- The repo-analyzer is tested by checking if it correctly identifies architecture and patterns
- The quality-reviewer is tested by checking if it catches hallucinations and format errors
- The skill-recommender is tested by checking if it maps signals to the right plugins

This mirrors autoresearch's approach of making focused modifications rather than rewriting everything.

### 3.2 Decision: Composite Score as the "val_bpb Equivalent"

Since there is no single quality metric, a composite score (0-100) was designed:

```
total_score = (
    weight_expectation × expectation_pass_rate +
    weight_structural × structural_score +
    weight_hallucination × no_hallucination_rate
)
```

Default weights (configurable in `config.json`):
- **Expectation pass rate** (50%): How many eval expectations the subagent output meets
- **Structural score** (30%): Output format compliance (correct headings, tables, sections)
- **No-hallucination rate** (20%): Avoidance of wrong frameworks, fake commands, placeholders

### 3.3 Decision: Use Claude CLI (`claude -p`) for Proposals and Grading

Rather than using the Anthropic API directly (which would require API keys, SDK installation), the system shells out to `claude -p` (the Claude Code CLI in non-interactive mode). This:
- Requires no API key management (uses the user's existing Claude Code auth)
- Keeps scripts simple (no SDK dependency)
- Uses the same model routing as the user's Claude Code setup

### 3.4 Decision: TSV for Results (Not JSON, Not SQLite)

`results.tsv` was chosen because:
- Human-readable in any text editor or terminal (`cat results.tsv | column -t`)
- Appendable without parsing the whole file
- Git-friendly for diffs (if ever tracked)
- Matches autoresearch's simplicity philosophy

### 3.5 Decision: Baseline + Best Snapshot Strategy

- `snapshots/baseline/` stores the original file before any optimization (for comparison)
- `snapshots/best/` stores the highest-scoring version found so far
- On each iteration, if score improves → overwrite `best/`; if score decreases → restore previous version
- `--apply-best` copies the best version back to the actual Cortex subagent path with a `.bak` backup

---

## 4. Implementation: Every File Explained

### 4.1 Directory Structure Created

```
cortex/claude-code-auto-research/
├── .gitignore                          # Ignores results.tsv, baseline snapshots, __pycache__
├── README.md                           # Quick start guide and file reference
├── DOCUMENTATION.md                    # This file — complete documentation
├── config.json                         # Loop configuration (iterations, models, weights)
├── program.md                          # Human optimization strategy (autoresearch's program.md)
├── prepare.py                          # One-time setup script
├── run.py                              # The autonomous optimization loop
├── measure.py                          # Scoring engine
├── progress.py                         # Progress report generator
├── evals/
│   ├── subagent-expectations.json      # Per-subagent grading criteria per fixture
│   └── trigger-evals.json              # Skill trigger accuracy test cases
└── snapshots/
    ├── baseline/                       # Original subagent prompt (before optimization)
    └── best/                           # Best-scoring version found
```

### 4.2 `.gitignore`

**Path**: `claude-code-auto-research/.gitignore`

Ignores experiment artifacts that shouldn't be committed:
- `results.tsv` — regenerated each run, contains timestamped experiment data
- `snapshots/baseline/` — copy of original file, can be recreated from git history
- `snapshots/*.tmp` — temporary files during optimization
- `__pycache__/`, `*.pyc`, `.venv/` — standard Python ignores

The `snapshots/best/` directory is NOT ignored — the best optimized version is worth tracking.

### 4.3 `config.json` — Loop Configuration

**Path**: `claude-code-auto-research/config.json`

Controls all loop behavior:

```json
{
  "max_iterations": 10,            // Maximum iterations per run
  "max_no_improvement": 3,         // Stop after N consecutive non-improvements
  "runs_per_iteration": 2,         // Multiple runs to handle LLM stochasticity
  "model": "sonnet",               // Model for subagent execution and proposals
  "grading_model": "haiku",        // Cheaper model for grading (cost optimization)
  "target_file": "../skills/scaffold/agents/quality-reviewer.md",  // What to optimize
  "fixtures": [                    // Test repos to evaluate against
    "../test/fixtures/nextjs-app",
    "../test/fixtures/python-api",
    "../test/fixtures/minimal"
  ],
  "eval_source": "../skills/scaffold/evals/evals.json",  // Original Cortex evals
  "expectations_file": "evals/subagent-expectations.json", // Decomposed per-subagent evals
  "score_weights": {               // Composite score weights (must sum to 1.0)
    "expectation_pass_rate": 0.5,
    "structural_score": 0.3,
    "no_hallucination_rate": 0.2
  }
}
```

**Design rationale**: All paths are relative to the script directory, allowing the auto-research folder to be moved without breaking references. Two different models are used — `sonnet` for the heavier work (running subagents, proposing modifications) and `haiku` for the cheaper grading work.

### 4.4 `program.md` — The Human Interface

**Path**: `claude-code-auto-research/program.md`

This is the autoresearch equivalent of `program.md`. The human writes their optimization strategy here. The autonomous loop reads it before each iteration to understand what to optimize and how.

**Sections:**
- **Objective**: What improvement you want (e.g., "catch hallucinated content better")
- **Target**: Which file to optimize (path to subagent prompt)
- **Test Against**: Which fixtures to evaluate against
- **Key Metrics**: What success looks like
- **Constraints**: Limits (max iterations, line count, format preservation)
- **Strategy**: Specific areas to focus improvement on
- **Stop Conditions**: When to terminate the loop

**Default program** targets the `quality-reviewer` subagent with focus on hallucination detection — the most objectively measurable aspect of scaffold quality.

### 4.5 `prepare.py` — One-Time Setup

**Path**: `claude-code-auto-research/prepare.py`  
**Lines**: 198  
**Dependencies**: Python 3.10+ stdlib only (json, os, shutil, subprocess, sys, pathlib)

**What it does (5 steps):**

1. **Validates configuration** (`validate_config`):
   - Checks that `target_file` exists (e.g., `quality-reviewer.md`)
   - Checks that all fixture directories exist (`test/fixtures/nextjs-app`, etc.)
   - Checks that `eval_source` file exists (`evals.json`)
   - Checks that `expectations_file` exists (`subagent-expectations.json`)
   - Exits with error listing all missing paths if any validation fails

2. **Checks Claude CLI** (`check_claude_cli`):
   - Runs `claude --version` to verify the CLI is installed
   - Prints warning with install instructions if not found
   - Does not abort — CLI is only needed for `run.py`, not `prepare.py` itself

3. **Snapshots baseline** (`snapshot_baseline`):
   - Copies the target file to `snapshots/baseline/` (preserves original for comparison)
   - Also copies to `snapshots/best/` as the initial "best" version
   - Uses `shutil.copy2` to preserve file metadata (timestamps)

4. **Displays optimization program** (`read_program`):
   - Reads and prints `program.md` so the user can review their strategy
   - Warns if `program.md` doesn't exist

5. **Runs baseline eval** (`run_baseline_eval`):
   - Invokes `measure.py` as a subprocess
   - Parses the JSON output to get the baseline score
   - Initializes `results.tsv` with a BASELINE row
   - If eval fails (e.g., Claude CLI not available), prints instructions to run later

**Key functions:**
- `load_config()` — reads `config.json`, exits if not found
- `resolve_path(relative_path)` — resolves paths relative to script directory (not CWD)

### 4.6 `measure.py` — Scoring Engine

**Path**: `claude-code-auto-research/measure.py`  
**Lines**: 397  
**Dependencies**: Python 3.10+ stdlib only (json, os, subprocess, sys, re, pathlib)

This is the measurement system that replaces autoresearch's `val_bpb`. It produces a composite quality score (0-100) for the target subagent.

**Pipeline:**

```
For each fixture:
  For each run (runs_per_iteration):
    1. Read fixture context (package.json, docker-compose, file listing)
    2. Run subagent on fixture (via claude -p)
    3. Grade output against expectations (via claude -p with grading prompt)
    4. Compute structural score (regex-based)
    5. Compute hallucination score (regex-based)
    6. Calculate composite score for this run
  Take best run for this fixture
Average across all fixtures → final composite score
```

**Key functions:**

- `read_fixture_context(fixture_path)` — reads key files from a test fixture to provide context:
  - Package manifests (package.json, pyproject.toml, Cargo.toml, go.mod)
  - Docker compose files
  - Complete file listing (excluding node_modules, .git, __pycache__)
  - Returns formatted markdown string

- `run_subagent_on_fixture(config, fixture_path)` — runs the target subagent against a fixture:
  - Reads the subagent's prompt file (the optimization target)
  - Builds a test prompt that includes the subagent prompt + fixture context
  - Executes via `claude -p` with the configured model
  - Returns the raw output string (or "ERROR:" prefixed string on failure)
  - Timeout: 180 seconds per run

- `grade_with_claude(subagent_output, expectations, model)` — uses Claude to grade output:
  - Sends the subagent output and list of expectations to Claude
  - Expects structured output: `EXPECTATION [N]: MET | NOT_MET | UNCLEAR — [reason]`
  - Parses with regex to count MET expectations
  - Returns `{met, total, details[], error?}`
  - Uses the cheaper `grading_model` (haiku by default)
  - Timeout: 120 seconds per grading call

- `compute_structural_score(subagent_output)` — deterministic format compliance check:
  - **+20 pts**: Has a `**Verdict**: PASS | FAIL` line
  - **+15 pts**: Has a `**Quality Score**: [number]` line
  - **+15 pts**: Has dimension scores table (Format Compliance, Specificity, etc.)
  - **+15 pts**: Has per-file results section
  - **+10 pts**: Has summary section
  - **+15 pts**: Reasonable output length (500-10,000 chars optimal)
  - **+10 pts**: References specific checks (Check 1, Check 2, etc.)
  - Capped at 100. No external API calls — pure regex.

- `compute_hallucination_score(subagent_output, fixture_name)` — checks for wrong content:
  - Starts at 100, penalizes for detected issues
  - **-15 pts each**: Mentioning wrong frameworks for the fixture (e.g., Django in a Next.js project)
  - **-20 pts**: Containing placeholder text (`[PROJECT_NAME]`, `PLACEHOLDER`, `TODO:`)
  - Maintains per-fixture maps of expected vs. wrong frameworks
  - Floor at 0. No external API calls — pure regex.

- `measure(config)` — orchestrates the full pipeline:
  - For each fixture: runs subagent N times, takes best composite score
  - Averages across fixtures
  - Returns structured JSON with total_score, breakdown, fixture_results, failures

**Output format** (JSON to stdout):
```json
{
  "total_score": 72.5,
  "breakdown": {
    "expectation_pass_rate": 66.7,
    "structural_score": 85.0,
    "no_hallucination_rate": 90.0
  },
  "weights": {"expectation_pass_rate": 0.5, "structural_score": 0.3, "no_hallucination_rate": 0.2},
  "fixture_results": [...],
  "failures": [{"fixture": "minimal", "expectation": "Does not over-generate warnings"}],
  "fixtures_evaluated": 3,
  "target": "quality-reviewer"
}
```

Human-readable summary goes to stderr so it doesn't interfere with JSON parsing.

### 4.7 `run.py` — The Autonomous Loop (Core)

**Path**: `claude-code-auto-research/run.py`  
**Lines**: 368  
**Dependencies**: Python 3.10+ stdlib only (argparse, json, os, shutil, subprocess, sys, datetime, pathlib, re)

This is the heart of the system — the autoresearch equivalent. It implements the autonomous modify → measure → keep/discard loop.

**CLI interface:**
```bash
python run.py                    # Run the optimization loop
python run.py --apply-best       # Copy best version back to target
python run.py --dry-run          # Show what would happen without changes
```

**The loop (step by step):**

1. **Load state**: Reads `config.json`, `program.md`, `results.tsv` (previous experiments)
2. **Calculate starting point**: Finds the best score from history, counts consecutive non-improvements
3. **Print status**: Shows target file, best score, iteration number, stale limit
4. **For each iteration**:
   - **Check stale limit**: If `max_no_improvement` consecutive discards → STOP
   - **Read current content**: Reads the target subagent prompt file
   - **Propose modification** (`propose_modification`):
     - Builds a prompt with: optimization program + current file + experiment history + current failures
     - Sends to Claude via `claude -p` with the configured model
     - Extracts the `CHANGE: [summary]` line and the complete modified file between `---BEGIN FILE---` / `---END FILE---` markers
     - Rules given to Claude: ONE focused change, don't repeat discarded changes, keep format intact
   - **Apply modification**: Writes new content to the target file
   - **Measure**: Runs `measure.py` as subprocess, parses JSON output
   - **Keep or discard**:
     - If `score >= best_score`: KEPT — save to `snapshots/best/`, reset no-improvement counter
     - If `score < best_score`: DISCARDED — restore previous version, increment no-improvement counter
   - **Log**: Append result to `results.tsv`
5. **Final summary**: Print baseline vs best score, kept/discarded counts, instructions for apply

**Key functions:**

- `propose_modification(config, current_content, results, last_failures, program)` — the "research agent":
  - Provides Claude with full context: the optimization program, current file, last 10 experiment results, and the specific failed expectations
  - Asks for ONE focused change (not a complete rewrite)
  - Instructs to avoid repeating previously discarded changes
  - Parses structured output: `CHANGE: [summary]` + `---BEGIN FILE---` / `---END FILE---`
  - Returns `(new_content, change_summary)` tuple

- `apply_best(config)` — copies the best snapshot back to the original target:
  - Creates a `.bak` backup of the current target file
  - Copies `snapshots/best/` version to the target path
  - Shows the score improvement (baseline → best)

- `append_result(iteration, score, delta, summary, status)` — adds a row to results.tsv:
  - Handles TSV header creation if file doesn't exist
  - Sanitizes summary (escapes tabs/newlines, truncates to 200 chars)
  - Timestamps in UTC ISO format

**Error handling:**
- If proposal fails (Claude returns error or bad format): logs ERROR, skips iteration, continues
- If measurement fails (subprocess error or JSON parse error): restores previous version, logs ERROR, continues
- Never crashes the loop on a single iteration failure

### 4.8 `progress.py` — Report Generator

**Path**: `claude-code-auto-research/progress.py`  
**Lines**: 117  
**Dependencies**: Python 3.10+ stdlib only (sys, pathlib)

Reads `results.tsv` and prints a formatted progress report.

**Output includes:**

1. **Score Progression Table**: Iteration, Score, Delta, Status (BASE/KEPT/DROP/ERR!), Change summary
2. **ASCII Score Chart**: Visual bar chart with `█` blocks, `✓`/`✗` status markers, best score marker
3. **Summary Statistics**: Baseline score, best score, total improvement, iterations run, changes kept/discarded, acceptance rate
4. **Best Version Info**: Path to best snapshot, apply command

**Example output:**
```
======================================================================
Claude Code Auto-Research — Progress Report
======================================================================

## Score Progression

Iter    Score    Delta      Status  Change
----------------------------------------------------------------------
   0     45.2        0        BASE  baseline
   1     52.1     +6.9        KEPT  Added explicit MCP validation rules
   2     48.3     -3.8        DROP  Restructured output format
   3     55.7     +3.6        KEPT  Added command existence checks

## Score Chart

    0 ✓ |                         45.2
    1 ✓ |████████████████████████████████████ 52.1
    2 ✗ |████████████████ 48.3
    3 ✓ |██████████████████████████████████████████████████ 55.7 ◄ best

## Summary

  Baseline score:    45.2
  Best score:        55.7 (iteration 3)
  Total improvement: +10.5
  Iterations run:    3
  Changes kept:      2
  Changes discarded: 1
  Acceptance rate:   67%
```

### 4.9 `evals/subagent-expectations.json` — Decomposed Expectations

**Path**: `claude-code-auto-research/evals/subagent-expectations.json`

This file is the critical bridge between Cortex's existing `evals.json` (which tests the full scaffold pipeline) and the per-subagent optimization loop. Expectations were decomposed from the 9 eval cases in `skills/scaffold/evals/evals.json` and assigned to the specific subagent responsible for each expectation.

**Structure**: `{ subagent_name: { fixture_name: [expectations] } }`

**Coverage:**

| Subagent | nextjs-app | python-api | minimal | Total |
|----------|-----------|-----------|---------|-------|
| quality-reviewer | 6 expectations | 4 expectations | 5 expectations | 15 |
| repo-analyzer | 6 expectations | 5 expectations | 4 expectations | 15 |
| skill-recommender | 8 expectations | 4 expectations | 4 expectations | 16 |
| codex-specialist | 6 expectations | 3 expectations | — | 9 |
| setup-auditor | — (tested via audit mode) | — | — | 6 (general) |

**Example expectations for quality-reviewer on nextjs-app:**
1. Catches hallucinated MCP servers not present in docker-compose.yml
2. Validates YAML frontmatter syntax in all generated agent files
3. Does not reject valid Prisma-related content
4. Verifies commands referenced in skills exist in package.json scripts
5. Detects placeholder content like [PROJECT_NAME] or TODO:
6. Returns structured PASS/FAIL verdict with specific issues listed

### 4.10 `evals/trigger-evals.json` — Trigger Accuracy Tests

**Path**: `claude-code-auto-research/evals/trigger-evals.json`

20 test cases (10 positive, 10 negative) for testing whether the scaffold skill's description triggers correctly on user queries.

**Positive triggers** (should_trigger: true):
- "Set up my project for AI development"
- "Generate CLAUDE.md for this repo"
- "scaffold https://github.com/org/repo"
- "/scaffold"
- "Audit my AI setup"
- "Optimize my scaffold setup"
- "Analyze this repo and generate AI configs"
- "Create Cursor rules and CLAUDE.md for this project"
- "Generate AGENTS.md for Codex"
- "Set up Claude Code, Cursor, and Codex for this repo"

**Negative triggers** (should_trigger: false):
- "Write a React component"
- "Fix this TypeScript error"
- "How do I deploy to Vercel?"
- "Run the tests"
- "Explain this function to me"
- "Refactor the auth middleware"
- "What does this error mean?"
- "Create a new API endpoint"
- "Review my pull request"
- "Debug the database connection issue"

These can be used with `skill-creator`'s existing `run_eval.py` infrastructure or as part of a future trigger optimization loop.

---

## 5. How Cortex's Existing Infrastructure Was Leveraged

### 5.1 Test Fixtures (Reused As-Is)

The 3 existing test fixtures at `test/fixtures/` serve as the "training data" for the optimization loop:

| Fixture | Files | Purpose |
|---------|-------|---------|
| `test/fixtures/nextjs-app/` | package.json, next.config.js, tsconfig.json, prisma/schema.prisma, docker-compose.yml, .github/workflows/ci.yml, src/app/page.tsx, tailwind.config.js, Dockerfile | Complex fullstack app with multiple services |
| `test/fixtures/python-api/` | pyproject.toml, app/main.py, openapi.yaml, Dockerfile, .github/workflows/test.yml, tests/conftest.py | Python backend with OpenAPI |
| `test/fixtures/minimal/` | package.json, index.js | Bare-bones project (tests restraint) |

### 5.2 Eval Cases (Decomposed)

The 9 eval cases from `skills/scaffold/evals/evals.json` were analyzed and their expectations assigned to specific subagents:

| Original Eval ID | Expectations | Assigned To |
|-------------------|-------------|-------------|
| scaffold-nextjs-fullstack | 10 expectations | Split across repo-analyzer, skill-recommender, quality-reviewer |
| scaffold-python-api | 6 expectations | Split across repo-analyzer, skill-recommender |
| scaffold-minimal-no-overgenerate | 5 expectations | quality-reviewer, skill-recommender |
| scaffold-official-first | 6 expectations | skill-recommender |
| audit-stale-setup | 5 expectations | setup-auditor |
| codex-output-format | 5 expectations | codex-specialist |
| scaffold-monorepo | 5 expectations | repo-analyzer |
| audit-duplicate-rules | 4 expectations | setup-auditor |
| quality-gate-catches-hallucination | 4 expectations | quality-reviewer |

### 5.3 Quality Reviewer Format (Understood and Preserved)

The quality-reviewer's output format (198 lines, 10 checks, structured PASS/FAIL with dimension scores) was read and understood before designing the scoring system. The `compute_structural_score` function in `measure.py` validates against this exact format — checking for:
- `**Verdict**: PASS | FAIL`
- `**Quality Score**: [number]`
- Dimension scores table
- Per-file results section
- Summary section

---

## 6. Scoring System Design

### 6.1 Three Dimensions

**Dimension 1: Expectation Pass Rate (weight: 0.5)**
- Uses Claude (haiku model) as a grading agent
- Sends subagent output + list of expectations
- Expects structured `EXPECTATION [N]: MET | NOT_MET | UNCLEAR` output
- Score = (MET count / total expectations) × 100

**Dimension 2: Structural Score (weight: 0.3)**
- Pure regex-based — no LLM calls
- Checks for presence of expected sections and formatting
- Rewards correct output structure (verdict, quality score, dimension table, per-file results, summary)
- Penalizes too-short or too-long output

**Dimension 3: No-Hallucination Rate (weight: 0.2)**
- Pure regex-based — no LLM calls
- Starts at 100, deducts for detected hallucinations
- Per-fixture framework maps define what should/shouldn't appear
- Catches wrong frameworks and placeholder text

### 6.2 Why These Weights

- **Expectation pass rate** gets 50% because it's the most meaningful signal — does the subagent actually do what we want?
- **Structural score** gets 30% because format compliance matters for downstream tooling (the scaffold pipeline parses this output)
- **No-hallucination rate** gets 20% because it's a binary check that's partially covered by expectations

### 6.3 Multi-Run Handling

Each iteration runs the subagent `runs_per_iteration` times (default: 2) per fixture. The best composite score across runs is used. This handles LLM stochasticity — the same prompt can produce different quality output on different runs.

---

## 7. Usage Guide

### 7.1 First Run

```bash
cd cortex/claude-code-auto-research

# 1. Validate everything and establish baseline
python prepare.py

# 2. Review the default optimization program
cat program.md

# 3. Start the optimization loop
python run.py

# 4. Monitor progress
python progress.py
```

### 7.2 Changing the Optimization Target

To optimize a different subagent (e.g., repo-analyzer instead of quality-reviewer):

1. Edit `config.json`: change `target_file` to `../skills/scaffold/agents/repo-analyzer.md`
2. Edit `program.md`: update objective, strategy, and constraints for the new target
3. Run `python prepare.py` to re-snapshot baseline
4. Run `python run.py` to start optimization

### 7.3 Resuming Across Sessions

The loop is designed to be resumable:
- `results.tsv` persists across sessions
- `run.py` reads previous history and continues from the last iteration
- The best version is always in `snapshots/best/`
- The no-improvement counter is reconstructed from history

### 7.4 Applying the Best Version

```bash
# Copy the best-scoring version back to the actual Cortex subagent
python run.py --apply-best
```

This creates a `.bak` backup before overwriting. The score improvement is displayed.

### 7.5 Dry Run

```bash
# See what the loop would do without making changes
python run.py --dry-run
```

Shows proposals and their change summaries without modifying files or running measurements.

---

## 8. Future Improvements

### 8.1 End-to-End Scaffold Validation

After optimizing individual subagents, run a full scaffold pipeline to verify the improvements compose well together.

### 8.2 Cross-Subagent Optimization

Optimize how subagents interact — e.g., ensure the repo-analyzer's output format matches what the skill-recommender expects as input.

### 8.3 Additional Test Fixtures

Expand beyond 3 fixtures to cover more project types: Go, Rust, monorepo, mobile app, etc.

### 8.4 Live HTML Report

Like `skill-creator`'s `run_loop.py`, generate a live HTML report with charts and detailed results.

### 8.5 Integration with Cortex Optimize Mode

Once validated, fold the autoresearch loop into Cortex's SKILL.md optimize mode so `/scaffold optimize` can run autonomous improvement sessions.

### 8.6 Cost Tracking

Track API costs per iteration to help users budget their optimization sessions.
