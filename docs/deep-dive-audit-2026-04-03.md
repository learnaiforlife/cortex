# Cortex Deep Dive Audit (2026-04-03)

## Scope

This document captures a deep repository walkthrough of `cortex`, aligns key project docs with current code reality, and records a severity-ranked issue register for later fixes.

## Ground Truth Inventory

Current repository state (verified from file system and scripts):

- Subagents: **13** (`skills/scaffold/agents/*.md`)
- Scripts: **16** (`skills/scaffold/scripts/*.sh`)
- Reference catalogs: **10** (`skills/scaffold/references/*.md`)
- Eval cases: **18** (`skills/scaffold/evals/evals.json`)
- Assertion types implemented: **15** (`skills/scaffold/scripts/run-skill-evals.sh`)
- Main skill length: **962 lines** (`skills/scaffold/SKILL.md`)

## Architecture Snapshot

### Primary workflow (`/scaffold`)

1. Variant dispatch (`skills/scaffold/variants/dispatch-table.json`)
2. Pre-scan (`skills/scaffold/scripts/analyze.sh`)
3. Opportunity detection (`skills/scaffold/scripts/detect-opportunities.sh`)
4. Interactive selection or `--all` fallback
5. Parallel analysis by:
   - `skills/scaffold/agents/repo-analyzer.md`
   - `skills/scaffold/agents/skill-recommender.md`
6. Generation + quality gate (`skills/scaffold/agents/quality-reviewer.md`)
7. Write files + score + log (`score.sh`, `log-result.sh`)

### Discover workflow (`/scaffold discover`)

- Orchestrator: `skills/scaffold/scripts/discover-orchestrator.sh`
- Inputs from scripts:
  - `discover-projects.sh`
  - `discover-tools.sh`
  - `discover-services.sh`
  - `discover-integrations.sh`
  - `discover-company.sh`
- Synthesis by agents:
  - `cross-project-analyzer.md`
  - `dna-synthesizer.md`
  - `user-level-generator.md`

### Optimize and audit workflows

- `/scaffold optimize` uses freshness + eval checks in `skills/scaffold/SKILL.md`
- `/scaffold optimize auto-improve` uses `skills/scaffold/scripts/auto-improve.sh`
- `/scaffold audit` routes through `skills/scaffold/agents/setup-auditor.md`

## Documentation Alignment Performed

The following files were updated to reflect current codebase reality:

- `AGENTS.md`
- `CLAUDE.md`
- `.cursor/rules/project-context.mdc`
- `README.md`
- `CHANGELOG.md` (new `Unreleased` notes)
- `docs/autoresearch-integration.md`

## Issue Register (Do Not Fix Yet)

### Critical

- None identified in this pass.

### High

1. **`output_contains` assertions are always skipped**
   - Why it matters: Some evals can pass without verifying runtime output.
   - Evidence: `skills/scaffold/scripts/run-skill-evals.sh` (`output_contains` returns skip).
   - Fix direction: Implement output capture mode or replace with file-based assertions.

2. **`scaffold-monorepo` eval does not use a monorepo fixture**
   - Why it matters: The test may pass while not validating monorepo behavior.
   - Evidence: `skills/scaffold/evals/evals.json` (`scaffold-monorepo` has no `fixture`), fallback behavior in `run-skill-evals.sh`.
   - Fix direction: Add dedicated monorepo fixture and bind eval to it.

3. **Version metadata disagreement**
   - Why it matters: Release/support confusion and automation drift.
   - Evidence: `VERSION` (`0.2.0`) vs `.claude-plugin/plugin.json` (`1.0.0`) vs README status text.
   - Fix direction: Define single source of truth and align all published metadata.

### Medium

1. **`score.sh` can over-credit format checks when no files match**
   - Why it matters: Score inflation creates false quality confidence.
   - Evidence: Loop patterns in `skills/scaffold/scripts/score.sh` rely on glob iteration and may pass vacuously.
   - Fix direction: Require at least one matched file before awarding section points.

2. **Legacy/stale count claims were present across multiple docs**
   - Why it matters: Contributors follow outdated architecture facts.
   - Evidence: Previously inconsistent counts in `AGENTS.md`, `CLAUDE.md`, and `.cursor/rules/project-context.mdc`.
   - Fix direction: Keep docs tied to generated inventory checks during releases.

3. **`auto-improve.sh` prerequisite comment mismatches behavior** — FIXED
   - Why it matters: Comment implied git stashing and autonomous editing that script does not perform.
   - Evidence: Header comment in `skills/scaffold/scripts/auto-improve.sh`.
   - Fix: Rewrote auto-improve.sh as measurement-only tool. All user-facing text updated to match. See cursor/auto-improve-workflow-honesty-a60e branch.

4. **Plugin description omits discover mode**
   - Why it matters: Product messaging differs from actual command surface.
   - Evidence: `.claude-plugin/plugin.json` says three modes, while commands include discover.
   - Fix direction: Update plugin description (requires protected file confirmation).

### Low

1. **Discover default scan scope is broad**
   - Why it matters: Users may not expect scanning across multiple home directories.
   - Evidence: Defaults in `skills/scaffold/scripts/discover-orchestrator.sh`.
   - Fix direction: Add stronger first-run explanation and explicit opt-in wording.

2. **Mixed strict-mode patterns across scripts**
   - Why it matters: Error handling is not fully uniform (`-e` missing in some scripts).
   - Evidence: `set -uo pipefail` in some scripts, `set -euo pipefail` in others.
   - Fix direction: Standardize strict mode with script-specific exceptions documented.

3. **`npx -y` MCP install pattern may concern security-sensitive users**
   - Why it matters: Runtime package fetch trust concerns.
   - Evidence: `.mcp.json` GitHub server setup.
   - Fix direction: Document optional pinning strategy for reproducibility/security.

## Next Phase (Planned)

When approved, fixes should be handled in this order:

1. High: eval runner/output assertion validity and fixture correctness
2. High: version source-of-truth alignment
3. Medium: score inflation edge cases
4. Medium/Low: script/docs consistency cleanups
