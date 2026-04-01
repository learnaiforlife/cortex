# Claude Code Auto-Research

Autonomous optimization loop for Cortex subagent prompts, inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

Instead of optimizing ML training code against `val_bpb`, this optimizes **subagent prompts** against **eval expectations** — using the same core pattern: **modify → run → measure → keep/discard → repeat**.

## How It Works

```
┌─────────────────┐
│  program.md     │  ← You define the optimization strategy
└────────┬────────┘
         ↓
┌─────────────────┐
│  run.py         │  ← Autonomous loop (the "autoresearch" engine)
│                 │
│  1. Read target │     (subagent prompt)
│  2. Propose mod │     (via Claude CLI)
│  3. Measure     │     (run evals, compute score)
│  4. Keep/discard│     (compare to best)
│  5. Repeat      │
└────────┬────────┘
         ↓
┌─────────────────┐
│  results.tsv    │  ← Experiment log
│  snapshots/best │  ← Best version found
└─────────────────┘
```

## Quick Start

```bash
# 1. One-time setup
python prepare.py

# 2. Edit program.md with your optimization goal
#    (default: optimize quality-reviewer subagent)

# 3. Run the optimization loop
python run.py

# 4. Check progress
python progress.py

# 5. Apply the best version
python run.py --apply-best
```

## Files

| File | Purpose |
|------|---------|
| `program.md` | Your optimization strategy (what to improve, constraints, stop conditions) |
| `config.json` | Loop settings (iterations, model, weights, fixtures) |
| `prepare.py` | One-time setup: validate config, snapshot baseline, run initial eval |
| `run.py` | The autonomous optimization loop |
| `measure.py` | Scoring engine: runs subagent, grades against expectations |
| `progress.py` | Report generator: score progression, statistics |
| `evals/subagent-expectations.json` | Per-subagent grading criteria for each fixture |
| `evals/trigger-evals.json` | Trigger accuracy test cases |
| `snapshots/baseline/` | Original version before optimization |
| `snapshots/best/` | Highest-scoring version found |
| `results.tsv` | Experiment log (auto-generated) |

## Changing the Target

Edit `config.json` to optimize a different subagent:

```json
{
  "target_file": "../skills/scaffold/agents/repo-analyzer.md"
}
```

Then update `program.md` with the relevant optimization strategy.

Available targets:
- `../skills/scaffold/agents/quality-reviewer.md`
- `../skills/scaffold/agents/repo-analyzer.md`
- `../skills/scaffold/agents/skill-recommender.md`
- `../skills/scaffold/agents/codex-specialist.md`
- `../skills/scaffold/agents/setup-auditor.md`

## Scoring

The composite score (0-100) is a weighted average of three dimensions:

- **Expectation Pass Rate** (50%): How many eval expectations the subagent output meets
- **Structural Score** (30%): Output format compliance (correct headings, tables, sections)
- **No-Hallucination Rate** (20%): Avoidance of wrong frameworks, fake commands, placeholders

Weights are configurable in `config.json`.

## Requirements

- Python 3.10+
- Claude CLI (`npm install -g @anthropic-ai/claude-code`)
- Cortex project with test fixtures in `test/fixtures/`
