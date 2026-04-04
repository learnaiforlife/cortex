# Autoresearch Integration — What Was Done and Why

## Background

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch) is an autonomous ML experiment runner. An AI agent modifies `train.py`, trains for 5 minutes, checks if `val_bpb` improved, keeps or discards the change, and repeats. The human programs `program.md` (the agent's instructions), not the Python.

Cortex is an AI scaffolding tool — it generates CLAUDE.md, .cursor/rules, AGENTS.md for any repo. Before this work, Cortex generated scaffolds in a single shot with a binary PASS/FAIL quality gate.

The integration borrowed **6 architectural patterns** from autoresearch and applied them to scaffolding. The ML training pipeline itself was not relevant — only the iteration/measurement/tracking patterns.

---

## What Was Built

### 1. Quantitative Scoring System

**File**: `skills/scaffold/scripts/score.sh`

**Autoresearch equivalent**: `evaluate_bpb()` in `prepare.py`

**What it does**: Scores any scaffold output directory 0-100 across four weighted dimensions (25 points each):

| Dimension | What it checks | Points |
|-----------|---------------|--------|
| Format compliance | YAML frontmatter valid, JSON valid, correct extensions | 25 |
| Specificity | No placeholders, real commands, real framework references | 25 |
| Completeness | All 3 tools covered (Claude Code + Cursor + Codex), sections present | 25 |
| Structural quality | Agents have body content, skills have workflow steps, no short files | 25 |

**Usage**:
```bash
bash skills/scaffold/scripts/score.sh /path/to/scaffolded-repo
```

**Output**: JSON with total score and per-dimension breakdown.

**Why it matters**: Before this, Cortex had no way to compare two scaffold runs quantitatively. The quality-reviewer gave binary PASS/FAIL. Now there's a single number (like `val_bpb`) that enables everything else — iteration, tracking, and self-improvement.

---

### 2. Automated Eval Runner

**File**: `skills/scaffold/scripts/run-skill-evals.sh` (rewritten from placeholder)

**Autoresearch equivalent**: The fixed evaluation contract — `evaluate_bpb` is immutable, the agent cannot redefine what "good" means.

**What it does**: Reads machine-verifiable assertions from `evals/evals.json` and checks them against scaffold output. Supports 15 assertion types:

| Assertion type | What it checks |
|---------------|---------------|
| `file_exists` | A specific file exists in the output |
| `dir_exists` | A directory exists |
| `file_contains` | File matches a regex pattern |
| `file_not_contains` | File does NOT match a regex pattern |
| `file_min_size` | File is at least N bytes |
| `max_file_count` | Total generated files don't exceed N |
| `frontmatter_absent` | File has no YAML frontmatter (for AGENTS.md) |
| `frontmatter_field` | YAML frontmatter field equals an expected value |
| `no_skill_named` | No skill directory matches a forbidden pattern |
| `no_placeholder_in_dir` | No placeholder text in any file under a directory |
| `score_min` | Scaffold score meets a minimum threshold |
| `script_output_valid_json` | Script output parses as valid JSON |
| `no_placeholders` | No `{{PLACEHOLDER}}` tokens in generated `.claude` files |
| `file_not_exists` | A specific file must not exist |
| `output_contains` | CLI output matches a pattern (skipped in file-based mode) |

**Usage**:
```bash
# Run all evals on a scaffolded directory
bash skills/scaffold/scripts/run-skill-evals.sh /path/to/scaffolded-repo

# Run a specific eval
bash skills/scaffold/scripts/run-skill-evals.sh /path/to/repo scaffold-nextjs-fullstack
```

**Output**: Per-assertion pass/fail with detail messages, summary with pass rate and scaffold score.

**What changed in evals.json**: Each eval case now has an `assertions` array alongside the human-readable `expectations`. The expectations describe intent; assertions are machine-checkable.

---

### 3. Experiment Tracking

**File**: `skills/scaffold/scripts/log-result.sh`

**Autoresearch equivalent**: `results.tsv` — an append-only lab notebook for every experiment.

**What it does**: After every scaffold run, appends one TSV row to `~/.cortex/scaffold-results.tsv`:

```
timestamp  repo  score  format  specificity  completeness  structure  files_generated  status  description
```

**Status values**: `success`, `partial` (quality-reviewer required fixes), `fail`, `crash`.

**Usage**:
```bash
bash skills/scaffold/scripts/log-result.sh /path/to/repo success "Scaffolded nextjs-app"
```

**Why it matters**: Over many scaffold runs, the log reveals which repo types score lowest, whether SKILL.md changes actually improve scores, and common failure patterns. Without this, every scaffold run was a one-off with no learning across invocations.

**SKILL.md change**: Step 9 was added after the Summary Report (Step 8) to automatically score and log every scaffold run.

---

### 4. Iterative Improvement Loop

**Files**:
- `skills/scaffold/SKILL.md` — new Step 6B between quality review and writing
- `skills/scaffold/agents/scaffold-improver.md` — new subagent

**Autoresearch equivalent**: The core loop — edit `train.py`, run, evaluate, keep or revert.

**What it does**: After the quality-reviewer scores the scaffold output (Step 6), if the score is below 80, Step 6B kicks in:

1. Identify the weakest dimension from the score breakdown
2. Dispatch the `scaffold-improver` agent to fix only files related to that dimension
3. Re-score. If the score improved, keep the changes. If not, revert.
4. Repeat up to 2 times

**The scaffold-improver agent** is specialized for targeted regeneration. It receives the score breakdown, quality review, and project profile. It only touches files related to the weakest dimension — it does not rewrite everything.

**Decision rule**: Same as autoresearch. Strictly better = keep. Equal or worse = revert.

**Skip condition**: If quality score >= 80 or quality-reviewer gave clean PASS with no warnings, skip iteration entirely.

---

### 5. Self-Improving SKILL.md (Auto-Improve Mode)

**Files**:
- `skills/scaffold/scripts/auto-improve.sh` — orchestration script
- `skills/scaffold/agents/skill-improver.md` — agent that edits SKILL.md
- `commands/scaffold-optimize.md` — updated with auto-improve sub-command
- `skills/scaffold/SKILL.md` — new Auto-Improve Mode section

**Autoresearch equivalent**: The agent edits `train.py` and measures the result. Here, the agent edits SKILL.md and measures scaffold quality.

**What it does**: This is autoresearch applied to prompt engineering.

1. Score all test fixtures to establish a baseline average
2. Identify the weakest dimension across fixtures
3. Dispatch `skill-improver` agent to make ONE targeted edit to SKILL.md
4. Re-score all fixtures
5. If average score improved: keep the edit. If not: revert.
6. Repeat up to 5 times

**The skill-improver agent** follows strict editing rules:
- One change at a time (1-3 sentences or bullet points)
- Preserve existing structure
- Be specific (not "add real commands" but "read package.json scripts and include the actual test command")
- Keep SKILL.md under 400 lines
- Don't break dimensions that already score well

**Usage**: `/scaffold-optimize auto-improve` in Claude Code

**auto-improve.sh** provides the measurement infrastructure. It scores all fixtures, identifies the weakest dimension, reports what the agent should target, and logs every iteration to `~/.cortex/auto-improve-log.tsv`.

---

### 6. Error Recovery and Batch Autonomy

**File**: `skills/scaffold/SKILL.md` — new section at the end

**Autoresearch equivalent**: `program.md`'s explicit recovery patterns and "NEVER STOP" clause.

**What was added**:

**Fallback chain**: Every step now has a primary method, a fallback, and a "both fail" response. Example: Step 3 (subagents) primary = both in parallel, fallback = run sequentially, both fail = main thread analysis only.

**Timeout handling**:
- Subagents: 2 minutes
- Git clone: 60 seconds
- Scoring scripts: 30 seconds

**Crash logging**: When any step crashes unexpectedly, log to `~/.cortex/scaffold-results.tsv` with status `crash` and the error message.

**Batch mode autonomy**: When scaffolding multiple repos in sequence:
- Do not ask for confirmation between repos
- Do not stop on non-fatal errors (log and continue)
- Do stop on 3+ consecutive crashes or disk full
- Print a batch summary table after all repos are processed

---

### 7. Quality-Reviewer Update

**File**: `skills/scaffold/agents/quality-reviewer.md`

**What changed**: The output format now includes a numeric quality score (0-100) with a per-dimension breakdown table and a "weakest dimension" indicator, alongside the existing PASS/FAIL verdict. Also includes a scoring guide matching the dimensions in `score.sh`.

---

## Files Summary

### New files (5)

| File | Lines | Purpose |
|------|-------|---------|
| `scripts/score.sh` | 259 | Quantitative scaffold scoring (0-100 JSON) |
| `scripts/log-result.sh` | 84 | Append-only experiment log |
| `scripts/auto-improve.sh` | 224 | Autoresearch loop for self-improving SKILL.md |
| `agents/scaffold-improver.md` | 89 | Agent that improves scaffold output per dimension |
| `agents/skill-improver.md` | 76 | Agent that edits SKILL.md based on experiment data |

### Modified files (6)

| File | What changed |
|------|-------------|
| `SKILL.md` | Added Step 6B (iterative improvement), Step 9 (score/log), Auto-Improve Mode, Error Recovery section |
| `agents/quality-reviewer.md` | Numeric scoring output, dimension breakdown, scoring guide |
| `scripts/run-skill-evals.sh` | Full rewrite: placeholder -> assertion engine with 15 assertion types |
| `evals/evals.json` | Added `assertions` array to each eval case with machine-checkable checks |
| `commands/scaffold-optimize.md` | Added `auto-improve` sub-command |
| `README.md` | Updated architecture section, added scripts reference table |

---

## How the Pieces Connect

```
/scaffold <repo>
    |
    v
Steps 1-5: Analyze + Generate (unchanged)
    |
    v
Step 6: Quality Review + Score  <-- quality-reviewer now outputs 0-100 score
    |
    v
Step 6B: Iterative Improvement  <-- NEW: autoresearch loop (max 2 iters)
    |   score -> dispatch scaffold-improver -> re-score -> keep/revert
    |
    v
Step 7: Write Files (unchanged)
    |
    v
Step 8: Summary Report (unchanged)
    |
    v
Step 9: Score + Log  <-- NEW: score.sh + log-result.sh
    |
    v
~/.cortex/scaffold-results.tsv  <-- NEW: experiment history
```

```
/scaffold-optimize auto-improve
    |
    v
auto-improve.sh: Score all fixtures -> baseline
    |
    v
skill-improver agent: Edit SKILL.md (one change)
    |
    v
auto-improve.sh: Re-score all fixtures -> compare
    |
    v
Keep or revert -> repeat up to 5 times
    |
    v
~/.cortex/auto-improve-log.tsv  <-- NEW: improvement history
```

---

## Pattern Mapping: Autoresearch -> Cortex

| Autoresearch concept | Cortex implementation |
|---------------------|----------------------|
| `val_bpb` (single metric) | `score.sh` total score (0-100) |
| `evaluate_bpb()` (immutable eval) | `run-skill-evals.sh` + `evals.json` assertions |
| `results.tsv` (experiment log) | `~/.cortex/scaffold-results.tsv` via `log-result.sh` |
| `train.py` (mutable artifact) | Scaffold output files (Step 6B) / SKILL.md (auto-improve) |
| `program.md` (agent instructions) | SKILL.md |
| Git commit/revert per experiment | Keep/revert decision after each iteration |
| "NEVER STOP" clause | Batch mode autonomy rules |
| Crash -> log 0.0 -> move on | Crash -> log status=crash -> continue |
| 5-minute time budget | Not adopted (scaffold runs are fast) |
| Single-file constraint | Not adopted (scaffold generates 10+ files) |

---

## Related: claude-code-auto-research/

The repo also contains `claude-code-auto-research/`, a more complete Python-based autoresearch implementation that optimizes individual subagent prompts (not SKILL.md). It uses a `run.py` loop to modify subagent files (e.g., `quality-reviewer.md`), run evals via Claude CLI, and keep/discard changes based on a composite score. This is complementary to the bash-based tooling above:

- **claude-code-auto-research/**: Optimizes individual subagent prompts. Python-based. Requires Claude CLI. More granular (targets one subagent at a time).
- **skills/scaffold/scripts/auto-improve.sh**: Optimizes SKILL.md (the master orchestration). Bash-based. Measures across all fixtures. Broader scope.

Both use the same core autoresearch pattern. Use `claude-code-auto-research/` when you want to fine-tune a specific subagent's behavior. Use `auto-improve.sh` when you want to improve the overall scaffold flow.
