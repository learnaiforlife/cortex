---
name: scaffold-migration
description: "Migration workflow variant. Detects active migrations, assesses risk, selects strategy, generates phased MIGRATION-PLAN.md with migration-specific AI agents, rules, and skills. Use when: running '/scaffold migrate', detecting dual-language/framework projects, or when MIGRATION-PLAN.md exists."
---

# Migration Workflow Variant

> **Variable inheritance**: `{CLAUDE_SKILL_DIR}` and `{REPO_DIR}` are inherited from the parent SKILL.md dispatch. `{CLAUDE_SKILL_DIR}` resolves to the skill installation directory (e.g. `~/.claude/skills/scaffold/`). `{REPO_DIR}` is set by Step 1 of the main SKILL.md.

This variant handles the `/scaffold migrate` command. It is a parallel workflow to standard scaffold — it generates temporary, phased migration tooling rather than steady-state AI setup.

## When to Use This Variant

Activate when:
- User runs `/scaffold migrate` explicitly
- `detect-migration.sh` returns `"detected": true`
- `MIGRATION-PLAN.md` exists in the repo (resuming a migration)

## Multi-Migration Handling

If `detect-migration.sh` returns multiple detected migrations:

1. Display all detected migrations as a numbered list with category, from→to, and confidence
2. Ask the user: "Which migration would you like to address? (enter number, 'all' for sequential, or 'cancel')"
3. If user selects a single migration, proceed with only that one
4. If user selects 'all', process migrations sequentially in priority order (highest confidence first)
5. Each migration gets its own section in MIGRATION-PLAN.md

## Sub-command Routing

Parse the command arguments to determine the action:

| Argument | Action | Backing |
|----------|--------|---------|
| (none) or `--auto-detect` | Full migration setup (Steps 0-9) | Scripts + agents |
| `--from X --to Y` | Explicit migration — skip detection, construct signals directly | Scripts + agents |
| `--status` | Show migration progress (jump to Status Flow) | `migration-progress.sh` + agent |
| `--validate` | Validate current phase (jump to Validation Flow) | `validate-migration-phase.sh` + agent |
| `--next` | Advance to next phase (jump to Next Flow) | LLM-orchestrated (edits MIGRATION-PLAN.md) |
| `--cleanup` | Remove migration artifacts (jump to Cleanup Flow) | LLM-orchestrated (finds + removes files) |
| `--rollback` | Show rollback for current phase (jump to Rollback Flow) | LLM-orchestrated (reads plan, displays instructions) |

> **Implementation note:** `--next`, `--cleanup`, and `--rollback` are orchestrated
> by the LLM reading and editing MIGRATION-PLAN.md directly. They have no dedicated
> scripts. Their quality depends on the plan content generated during setup.

---

## Full Migration Setup

### Step 0: Command Parsing

Parse flags from the command arguments:
- `--from <source>` and `--to <target>`: explicit migration type (skip auto-detection)
- `--auto-detect` (default): run heuristic detection
- `--yes` / `-y`: skip interactive prompts, use recommended defaults

**Conflict rule**: If both `--from/--to` and `--auto-detect` are present, `--from/--to` takes precedence — explicit user specification always overrides heuristic detection.

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

**Fast Track Path** (simplified flow — skips Steps 4-6):
1. Generate a simplified 2-phase plan (Prep + Execute) directly using the catalog's default strategy
2. Generate 1 converter agent from the appropriate template (use `migration-converter.md` for language/framework/toolchain, `migration-ci-converter.md` for devops, `migration-infra.md` for cloud/infrastructure)
3. Generate the migration safety rule (same as full-pipeline Step 6, item 4)
4. Skip Steps 4-6 entirely — jump to Step 7 (Conflict Check)

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

> **No dedicated script.** The LLM reads and edits MIGRATION-PLAN.md directly.

1. Read MIGRATION-PLAN.md. If missing, report error and exit.
2. Find current phase (first `IN_PROGRESS`). If no phase is in progress, report that.
3. Run `bash {CLAUDE_SKILL_DIR}/scripts/validate-migration-phase.sh {REPO_DIR}` on the current phase.
4. If validation passes (all non-SKIP checks pass): update MIGRATION-PLAN.md — set current phase status to `COMPLETE`, set next phase status to `IN_PROGRESS`.
5. If validation fails or returns WARN: report the failing/skipped checks, do **not** advance. Tell the user what needs to pass before advancing.
6. If all phases are already `COMPLETE`, suggest running `--cleanup`.

> **Limitation:** Phase advancement is a text edit to MIGRATION-PLAN.md. There is no
> transactional guarantee. If the edit fails or is interrupted, re-run `--status`
> to see the current state.

### Cleanup Flow (`--cleanup`)

> **No dedicated script.** The LLM searches for migration markers and removes files.

1. Search the repo for files containing `# MIGRATION: remove after` (the marker placed by the migration-agent-generator).
2. List all matching files and display them to the user.
3. **Ask user to confirm** before deleting anything.
4. If confirmed: delete the listed files.
5. If MIGRATION-PLAN.md exists, move it to `docs/migrations/YYYY-MM-DD-[type].md` (create the directory if needed).
6. Remove any migration sections previously appended to CLAUDE.md and AGENTS.md (look for `## Active Migration:` and `## Migration:` headers).
7. Suggest re-running `/scaffold` to regenerate clean AI setup.

> **Limitation:** Cleanup relies on the `# MIGRATION: remove after` marker being
> present in generated files. If migration files were hand-edited and the marker
> was removed, those files will not be found. Review the result manually.

### Rollback Flow (`--rollback`)

> **No dedicated script.** The LLM reads MIGRATION-PLAN.md and displays instructions.

1. Read MIGRATION-PLAN.md. If missing, report error and exit.
2. Find current phase (first `IN_PROGRESS`). If none, report that.
3. Extract and display the `### Rollback` section for that phase verbatim.
4. Ask the user to confirm they want to mark the phase as rolled back.
5. If confirmed: set the phase status to `NOT_STARTED` in MIGRATION-PLAN.md.

> **Limitation:** This only displays rollback *instructions* — it does not execute
> them. The user must perform the actual rollback steps manually. The quality of
> the instructions depends entirely on what the migration-planner agent wrote
> during the initial setup.

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
/scaffold migrate             (scripts + agents)
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

/scaffold migrate --status    (migration-progress.sh + agent)
/scaffold migrate --validate  (validate-migration-phase.sh + agent)
/scaffold migrate --next      (LLM-orchestrated: validates then edits plan)
/scaffold migrate --cleanup   (LLM-orchestrated: finds markers, removes files)
/scaffold migrate --rollback  (LLM-orchestrated: displays plan's rollback section)
```

Steps 1, 7-9 follow the same patterns as the main SKILL.md. Steps 2-6 are migration-specific and replace the standard scaffold agent dispatch.

`--next`, `--cleanup`, and `--rollback` have no dedicated scripts — they are LLM-driven
operations on MIGRATION-PLAN.md. See [Sub-command Flows](#sub-command-flows) for details
and limitations.
