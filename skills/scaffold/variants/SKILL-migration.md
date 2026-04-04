---
name: scaffold-migration
description: "Migration workflow variant. Detects active migrations, assesses risk, selects strategy, generates phased MIGRATION-PLAN.md with migration-specific AI agents, rules, and skills. Use when: running '/scaffold migrate', detecting dual-language/framework projects, or when MIGRATION-PLAN.md exists."
---

# Migration Workflow Variant

This variant handles the `/scaffold migrate` command. It is a parallel workflow to standard scaffold — it generates temporary, phased migration tooling rather than steady-state AI setup.

## When to Use This Variant

Activate when:
- User runs `/scaffold migrate` explicitly
- `detect-migration.sh` returns `"detected": true`
- `MIGRATION-PLAN.md` exists in the repo (resuming a migration)

## Sub-command Routing

Parse the command arguments to determine the action:

| Argument | Action |
|----------|--------|
| (none) or `--auto-detect` | Full migration setup (Steps 0-9) |
| `--from X --to Y` | Explicit migration — skip detection, construct signals directly |
| `--status` | Show migration progress (jump to Status Flow) |
| `--validate` | Validate current phase (jump to Validation Flow) |
| `--next` | Advance to next phase (jump to Next Flow) |
| `--cleanup` | Remove migration artifacts (jump to Cleanup Flow) |
| `--rollback` | Show rollback for current phase (jump to Rollback Flow) |

---

## Full Migration Setup

### Step 0: Command Parsing

Parse flags from the command arguments:
- `--from <source>` and `--to <target>`: explicit migration type (skip auto-detection)
- `--auto-detect` (default): run heuristic detection
- `--yes` / `-y`: skip interactive prompts, use recommended defaults

If `--from` and `--to` are provided, construct a MigrationSignals JSON directly:
```json
{
  "detected": true,
  "migrations": [{"category": "explicit", "from": "<source>", "to": "<target>", "confidence": 1.0, "signals": [{"type": "user_specified", "detail": "--from/--to flags"}]}],
  "migrationDocs": [],
  "commentMarkers": {"todo_migrate": 0, "deprecated": 0, "legacy": 0, "migrated": 0},
  "dualConfigs": [],
  "deprecationMarkers": 0
}
```

### Step 1: Heuristic Migration Detection

Run the detection script:
```bash
bash {CLAUDE_SKILL_DIR}/scripts/detect-migration.sh {REPO_DIR}
```

Store the output as `MIGRATION_SIGNALS`.

If `detected` is `false` and no `--from/--to` flags were given:
- Report: "No migration signals detected. Use `--from X --to Y` to specify explicitly."
- Exit the migration workflow.

If `detected` is `true`, display a summary of detected migrations to the user.

### Step 2: Deep Migration Analysis

Dispatch the **migration-analyzer** agent:

**Subagent: migration-analyzer** (sonnet, 30 turns)
- Input: `REPO_DIR` + `MIGRATION_SIGNALS` JSON
- The agent reads the repo, maps old/new/shared files, estimates completion, finds coexistence patterns
- Output: `MIGRATION_PROFILE` (MigrationProfile JSON)

In parallel, read context:
- `README.md`, `CONTRIBUTING.md` for migration context
- Any existing migration docs (`MIGRATION.md`, `docs/migration-*.md`)
- Existing `MIGRATION-PLAN.md` if present (resuming a migration)

### Step 3: Risk Assessment

Dispatch the **risk-assessor** agent:

**Subagent: risk-assessor** (sonnet, 15 turns)
- Input: `MIGRATION_PROFILE` JSON
- Scores 5 dimensions: complexity, blast-radius, reversibility, test-coverage, data-risk
- Output: `RISK_ASSESSMENT` (RiskAssessment JSON)

### Step 3.5: Fast Track Check

If the number of detected migrations is 1 AND `RISK_ASSESSMENT.overallRisk` is `LOW` or `MEDIUM`, AND the migration category is one of: `toolchain`, `ai-tools`, or a simple language migration (e.g. JS→TS):

**Fast Track Path** (simplified 2-step flow):
1. Generate a simplified 2-phase plan (Prep + Execute) directly using the catalog's default strategy
2. Skip interactive strategy selection (Step 4)
3. Skip agent generation for LOW risk migrations
4. Jump to Step 5 output

For all other cases (HIGH/CRITICAL risk, multiple migrations, complex categories), continue with the full pipeline.

### Step 3.6: Risk Gate

Display the risk assessment to the user in a formatted table:

```
## Migration Risk Assessment

Overall Risk: [LEVEL] ([score]/100)

| Dimension     | Score | Key Factors                              |
|---------------|-------|------------------------------------------|
| Complexity    | XX    | [factors]                                |
| Blast Radius  | XX    | [factors]                                |
| Reversibility | XX    | [factors]                                |
| Test Coverage | XX    | [factors]                                |
| Data Risk     | XX    | [factors]                                |

BLOCKERS: [if any]
RECOMMENDATIONS: [list]
```

If risk is CRITICAL (81+): display extra warning — "This migration has CRITICAL risk. Consider a pilot project first."

If `--yes` flag was NOT set: ask user to confirm proceeding.

### Step 4: Strategy Selection

Present interactive strategy selection based on risk level and migration type.

Read `{CLAUDE_SKILL_DIR}/references/migration-catalog.md` for the migration type's recommended strategy and available prompts.

Display options:

```
## Choose Migration Strategy

Based on your [Source → Target] migration ([RISK] risk), recommended strategies:

[1] [star] [Strategy Name] (recommended for [RISK] risk)
    [Description from catalog]

[2] [Strategy Name]
    [Description]

[3] [Strategy Name]
    [Description]

[4] Custom
    Define your own strategy.

Select strategy [1]:
```

After selection, ask the strategy-specific follow-up question from the catalog (routing layer, comparison approach, priority order, etc.).

Build `MIGRATION_STRATEGY` JSON:
```json
{
  "pattern": "<strategy-name>",
  "phases": "<estimated from catalog>",
  "coexistencePlan": "<from follow-up answer>",
  "rollbackStrategy": "<based on strategy>",
  "validationApproach": "<based on strategy>",
  "priorityOrder": "<from follow-up answer>"
}
```

If `--yes` flag was set: use the first (recommended) strategy with default options.

### Step 5: Plan Generation

Dispatch the **migration-planner** agent:

**Subagent: migration-planner** (opus, 25 turns)
- Input: `MIGRATION_PROFILE` + `RISK_ASSESSMENT` + `MIGRATION_STRATEGY`
- Reads: `{CLAUDE_SKILL_DIR}/references/migration-catalog.md`
- Output: `MIGRATION_PLAN` — full phased plan content for MIGRATION-PLAN.md

Write `MIGRATION-PLAN.md` to the repo root.

Display plan summary to the user.

---

## Steps 6-9: AI Tooling Generation

*(Added in Phase 2 — see below)*

### Step 6: AI Tooling Generation

Dispatch the **migration-agent-generator** agent:

**Subagent: migration-agent-generator** (sonnet, 20 turns)
- Input: `MIGRATION_PROFILE` + `MIGRATION_STRATEGY` + `MIGRATION_PLAN`
- Reads: `{CLAUDE_SKILL_DIR}/references/migration-catalog.md` for conversion rules and agent patterns
- Reads: `{CLAUDE_SKILL_DIR}/templates/subagents/migration-*.md` for agent templates
- Output: Generated migration agents, rules, and skills (file contents)

Generated files are marked with `# MIGRATION: remove after completion` for later cleanup.

### Step 7: Conflict Check

If the repo already has a scaffold setup (`.claude/agents/`, `.claude/rules/`):
1. Read existing files
2. Check for conflicts (existing safety rules that block migration changes)
3. Merge migration rules additively (do not replace existing rules)
4. Add migration agents alongside existing agents
5. Append migration section to existing CLAUDE.md (do not rewrite)

### Step 8: Quality Review

Use the existing **quality-reviewer** agent on all generated migration files.

Additional migration-specific checks:
- MIGRATION-PLAN.md has at least 2 phases
- Each phase has validation criteria
- Each phase has rollback procedure
- Migration agents reference real files from the repo
- Migration rules do not conflict with existing rules
- No placeholder text (`[YOUR_PROJECT]`, `TODO:`, `{{VARIABLE}}`) in output files

### Step 9: Write Files + Summary

Write all generated files to disk. Display summary:

```
## Migration Setup Complete

### Migration: [Source] → [Target] ([Strategy])
Risk Level: [LEVEL] | Phases: N | Strategy: [pattern]

### Files Created
[list of created files with one-line descriptions]

### What's Next
1. Review MIGRATION-PLAN.md
2. Start Phase 1: "[phase name]"
3. After each phase: run `/scaffold migrate --validate`
4. Track progress: `/scaffold migrate --status`

### When Migration Completes
Run `/scaffold migrate --cleanup` to remove migration artifacts.
```

---

## Sub-command Flows

### Status Flow (`--status`)

1. Run: `bash {CLAUDE_SKILL_DIR}/scripts/migration-progress.sh {REPO_DIR}`
2. Dispatch **migration-progress-tracker** agent if MIGRATION-PLAN.md exists
3. Display formatted progress report

### Validation Flow (`--validate`)

1. Read MIGRATION-PLAN.md to find current phase (first phase with status `IN_PROGRESS` or `NOT_STARTED`)
2. Run: `bash {CLAUDE_SKILL_DIR}/scripts/validate-migration-phase.sh {REPO_DIR}`
3. Dispatch **migration-validator** agent for deep validation
4. Display results: PASS/FAIL with details per check

### Next Flow (`--next`)

1. Read MIGRATION-PLAN.md
2. Find current phase (first `IN_PROGRESS`)
3. Run validation on current phase
4. If validation passes: mark current phase as `COMPLETE`, mark next phase as `IN_PROGRESS`
5. If validation fails: report failures, do not advance
6. Update MIGRATION-PLAN.md

### Cleanup Flow (`--cleanup`)

1. Find all files marked with `# MIGRATION: remove after`
2. List them and ask user to confirm deletion
3. Remove migration-specific agents, rules, skills
4. Archive MIGRATION-PLAN.md to `docs/migrations/YYYY-MM-DD-[type].md`
5. Run standard `/scaffold` to regenerate clean AI setup

### Rollback Flow (`--rollback`)

1. Read MIGRATION-PLAN.md
2. Find current phase (first `IN_PROGRESS`)
3. Display the rollback instructions for that phase
4. Ask user to confirm rollback
5. If confirmed, mark phase as `NOT_STARTED` and update MIGRATION-PLAN.md

---

## Comment Marker Detection

In addition to file coexistence, the detection script scans for comment markers that indicate migration intent:

| Marker Pattern | Meaning |
|---------------|---------|
| `# TODO migrate`, `// TODO: migrate` | Planned migration |
| `@deprecated`, `# DEPRECATED` | Marked for replacement |
| `/* LEGACY */`, `# LEGACY` | Old code flagged for migration |
| `# MIGRATED: see ...` | Already migrated (points to new location) |

These markers contribute to migration confidence scores and help map which files are old vs new vs in-transition.

---

## Flow Summary

```
/scaffold migrate
  → Step 0: Parse flags
  → Step 1: detect-migration.sh (heuristic scan)
  → Step 2: migration-analyzer agent (deep analysis)
  → Step 3: risk-assessor agent (5-dimension scoring)
  → Step 3.5: Fast track check (LOW/MEDIUM risk → simplified path)
  → Step 3.6: Risk gate (display + confirm)
  → Step 4: Strategy selection (interactive)
  → Step 5: migration-planner agent (phased plan)
  → Step 6: migration-agent-generator agent (AI tooling)
  → Step 7: Conflict check with existing setup
  → Step 8: Quality review
  → Step 9: Write files + summary
```

Steps 1, 7-9 follow the same patterns as the main SKILL.md. Steps 2-6 are migration-specific and replace the standard scaffold agent dispatch.
