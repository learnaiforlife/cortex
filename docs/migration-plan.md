Now I have a deep understanding of the entire Cortex architecture. Let me design the migration workflow system.

---

# Cortex Migration Workflow System — Technical Design

## Table of Contents
1. [System Architecture Overview](#1-system-architecture-overview)
2. [New Agents](#2-new-agents)
3. [New Scripts & Detectors](#3-new-scripts--detectors)
4. [Migration Workflow Steps](#4-migration-workflow-steps)
5. [Example Outputs](#5-example-outputs)
6. [Integration with Existing Cortex](#6-integration-with-existing-cortex)
7. [File Structure](#7-file-structure)
8. [Implementation Phases](#8-implementation-phases)

---

## 1. System Architecture Overview

### Core Concept

The migration system is a **parallel workflow** to scaffold, not a replacement. Where `/scaffold` asks "what AI setup does this repo need?", `/scaffold migrate` asks "this repo is *changing* — what AI setup helps it change safely?"

The key insight: a migration is a **temporary, phased transformation** that needs different AI tooling than steady-state development. Migration agents are ephemeral — they're designed to be removed once migration completes.

### Architecture Diagram

```
/scaffold migrate [repo] [--from X --to Y | --auto-detect]
         │
         ▼
┌─────────────────────┐
│ Migration Detector   │  ← detect-migration.sh (heuristic)
│ (script + agent)     │  ← migration-analyzer agent (deep analysis)
└────────┬────────────┘
         │ MigrationProfile JSON
         ▼
┌─────────────────────┐
│ Risk Assessor        │  ← Scores complexity, blast radius, reversibility
│ (agent)              │  ← Produces RiskAssessment JSON
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Strategy Selector    │  ← Interactive: user picks migration strategy
│ (interactive prompt) │  ← Strangler fig, parallel run, big-bang, etc.
└────────┬────────────┘
         │ MigrationStrategy
         ▼
┌─────────────────────────────────────────────┐
│              Parallel Generation             │
│  ┌──────────────┐  ┌──────────────────────┐ │
│  │ migration-   │  │ migration-agent-     │ │
│  │ planner      │  │ generator            │ │
│  │ (phased plan)│  │ (AI tooling)         │ │
│  └──────┬───────┘  └──────────┬───────────┘ │
│         │                     │              │
│         ▼                     ▼              │
│  MIGRATION-PLAN.md    .claude/agents/        │
│  (living document)    .claude/rules/         │
│                       .claude/skills/        │
│                       .cursor/rules/         │
│                       AGENTS.md (updated)    │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────┐
│ Quality Review + Conflict Check  │  ← Existing quality-reviewer
│ (no conflicts with existing      │  ← + new migration-conflict-checker
│  scaffold output)                │
└─────────────────────┬───────────┘
                      │
                      ▼
               Write Files + Summary
```

### Key Data Structures

**MigrationProfile** (output of detection phase):

```json
{
  "migrations": [
    {
      "id": "lang-py-to-java",
      "category": "language",
      "from": { "name": "Python", "version": "3.11", "evidence": ["pyproject.toml", "*.py files (47)"] },
      "to": { "name": "Java", "version": "21", "evidence": ["pom.xml", "*.java files (12)", "src/main/java/"] },
      "coexistence": {
        "status": "active",
        "shared_interfaces": ["proto/*.proto", "openapi/spec.yaml"],
        "bridge_patterns": ["python/client.py calls java/api via HTTP"]
      },
      "completionEstimate": 0.20,
      "affectedPaths": ["src/services/", "src/models/", "tests/"]
    }
  ],
  "repoProfile": { /* existing ProjectProfile */ },
  "migrationSignals": {
    "dual_language": true,
    "deprecated_markers": ["# DEPRECATED", "// TODO: migrate"],
    "migration_docs": ["docs/migration-plan.md"],
    "version_gaps": { "node": "14→20", "python": "3.8→3.11" },
    "config_coexistence": ["webpack.config.js AND vite.config.ts"]
  }
}
```

**RiskAssessment** (output of risk analysis):

```json
{
  "overallRisk": "HIGH",
  "score": 78,
  "dimensions": {
    "complexity": { "score": 85, "factors": ["47 Python files to convert", "3 external API integrations", "custom ORM layer"] },
    "blastRadius": { "score": 70, "factors": ["2 downstream services depend on Python API", "shared database schemas"] },
    "reversibility": { "score": 60, "factors": ["database schema changes are hard to reverse", "API contract changes affect consumers"] },
    "testCoverage": { "score": 35, "factors": ["only 23% test coverage on Python side", "no integration tests"] },
    "dataRisk": { "score": 90, "factors": ["production database migration required", "3 tables need schema changes"] }
  },
  "blockers": [
    { "type": "low_test_coverage", "detail": "Python code has 23% coverage — migrate tests first", "severity": "HIGH" }
  ],
  "recommendations": [
    "Write integration tests for Python API before starting migration",
    "Set up parallel-run validation between Python and Java services",
    "Migrate non-critical services first (reporting, notifications)"
  ]
}
```

**MigrationStrategy** (user-selected approach):

```json
{
  "pattern": "strangler-fig",
  "phases": 4,
  "coexistencePlan": "route-by-endpoint",
  "rollbackStrategy": "feature-flags",
  "validationApproach": "parallel-run-with-diff",
  "priorityOrder": ["tests-first", "leaf-services", "core-services", "data-layer"]
}
```

---

## 2. New Agents

### 2.1 migration-analyzer (sonnet, 30 turns)

**Role**: Deep analysis of what migration(s) are happening, their current state, and interdependencies.

**Tools**: Read, Glob, Grep, Bash

**Input**: Repository path + MigrationSignals from `detect-migration.sh`

**Workflow**:
1. Read migration signals from heuristic scan
2. For each detected migration type:
   - Identify source and target technologies
   - Map which files belong to "old" vs "new" vs "shared"
   - Detect bridge/adapter patterns (how old and new coexist)
   - Estimate completion percentage (files migrated / total files)
   - Identify shared interfaces (APIs, schemas, protocols, contracts)
3. Detect cross-migration dependencies (e.g., language migration + framework migration happening simultaneously)
4. Identify existing migration documentation or plans in the repo
5. Map the dependency graph of what must migrate before what

**Output**: MigrationProfile JSON (structure shown above)

**Why a new agent**: The repo-analyzer understands steady-state architecture. This agent understands *transition state* — what's old, what's new, what's in-between.

---

### 2.2 risk-assessor (sonnet, 15 turns)

**Role**: Score migration risk across 5 dimensions, identify blockers, produce actionable recommendations.

**Tools**: Read, Glob, Grep, Bash

**Input**: MigrationProfile JSON

**Workflow**:
1. **Complexity** (0-100): Count files to migrate, external integrations, custom abstractions, number of breaking changes
2. **Blast Radius** (0-100): Map downstream consumers, shared databases, API contracts, deployed services
3. **Reversibility** (0-100): Score based on migration type (config changes = easy, schema changes = hard, data migrations = very hard)
4. **Test Coverage** (0-100): Run coverage tools if available, count test files vs source files, check for integration tests
5. **Data Risk** (0-100): Detect database migrations, schema changes, data format changes, stateful transformations
6. Identify hard blockers (things that must be resolved before migration starts)
7. Generate prioritized recommendations

**Output**: RiskAssessment JSON

**Risk level thresholds**:

| Overall Score | Level | Guidance |
|---|---|---|
| 0-30 | LOW | Proceed with standard precautions |
| 31-60 | MEDIUM | Recommend phased approach, extra testing |
| 61-80 | HIGH | Recommend strangler fig, parallel run, feature flags |
| 81-100 | CRITICAL | Recommend pilot project first, explicit stakeholder sign-off |

---

### 2.3 migration-planner (sonnet, 25 turns)

**Role**: Generate a phased, living migration plan document (MIGRATION-PLAN.md) with concrete steps, validation criteria, and rollback instructions per phase.

**Tools**: Read, Glob, Grep

**Input**: MigrationProfile + RiskAssessment + MigrationStrategy (user-selected)

**Workflow**:
1. Decompose migration into ordered phases based on strategy pattern
2. For each phase:
   - List specific files/modules/services to migrate
   - Define entry criteria (what must be true before starting)
   - Define validation criteria (how to verify phase succeeded)
   - Define rollback procedure (how to undo this phase)
   - Estimate scope (files, tests, configs affected)
   - List risks specific to this phase
3. Create dependency graph between phases
4. Add progress tracking checkboxes
5. Include "canary checks" — automated validations to run after each phase

**Output**: MIGRATION-PLAN.md with this structure:

```markdown
# Migration Plan: [Source] → [Target]

## Overview
- **Type**: [category]
- **Risk Level**: [LOW/MEDIUM/HIGH/CRITICAL]
- **Strategy**: [strangler-fig/parallel-run/big-bang/incremental]
- **Estimated Phases**: N
- **Started**: [date]
- **Last Updated**: [date]

## Phase 1: [Name] — [Status: NOT_STARTED | IN_PROGRESS | COMPLETE | BLOCKED]

### Scope
- Files: [list or glob pattern]
- Tests: [corresponding tests]
- Configs: [configs that change]

### Entry Criteria
- [ ] [prerequisite 1]
- [ ] [prerequisite 2]

### Steps
1. [concrete step with command or file reference]
2. ...

### Validation
- [ ] [how to verify this phase worked]
- [ ] [automated check command]

### Rollback
[exact commands/steps to undo this phase]

### Risks
- [risk 1]: [mitigation]

---
## Phase 2: ...
```

---

### 2.4 migration-agent-generator (sonnet, 20 turns)

**Role**: Generate migration-specific AI agents, rules, and skills that help the developer execute each phase. These are *ephemeral* — designed to be removed after migration completes.

**Tools**: Read, Glob, Grep

**Input**: MigrationProfile + MigrationStrategy + MIGRATION-PLAN.md

**What it generates** (varies by migration type):

| Migration Type | Generated Agents | Generated Rules | Generated Skills |
|---|---|---|---|
| Language (Python→Java) | `migration-converter.md` — converts files one at a time with idiom translation | `migration-safety.md` — don't modify already-migrated files | `migrate-file/SKILL.md` — step-by-step single-file migration |
| Framework (Django→FastAPI) | `migration-router.md` — converts routes/views | `framework-coexistence.md` — rules for dual-framework period | — |
| Cloud (AWS→GCP) | `migration-infra.md` — converts IaC configs | `cloud-safety.md` — never delete source resources until target validated | `migrate-service/SKILL.md` — service-by-service migration |
| Architecture (mono→micro) | `service-extractor.md` — extracts bounded contexts | `api-contract.md` — enforce API versioning | `extract-service/SKILL.md` — extract one service |
| Toolchain (Webpack→Vite) | — | `build-migration.md` — rules for dual build system period | — |
| Infrastructure (Docker→K8s) | `k8s-converter.md` — converts Compose to K8s manifests | `deployment-safety.md` — validate manifests before apply | — |

**Agent template pattern** (migration-specific agents follow a distinct pattern):

```yaml
---
name: migration-converter
description: "Converts [source] files to [target] one at a time, preserving behavior and adapting idioms"
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
model: sonnet
maxTurns: 25
---

## Context
You are assisting with a [SOURCE] → [TARGET] migration.

## Migration State
- **Phase**: [current phase from MIGRATION-PLAN.md]
- **Already migrated**: [list or glob]
- **Do not touch**: [protected paths]

## Conversion Rules
[technology-specific conversion rules — e.g., Django ORM → SQLAlchemy, class components → functional]

## Workflow
1. Read the source file completely
2. Identify all imports, dependencies, and cross-references
3. Convert to target idiom following Conversion Rules
4. Write corresponding test (if source had test)
5. Verify: run target test suite
6. Update MIGRATION-PLAN.md progress

## Anti-Patterns
- Never convert multiple files at once
- Never delete the source file — mark as deprecated
- Never skip the test verification step
```

**Generated rules** follow the pattern:

```markdown
---
name: migration-safety
description: Safety guardrails during [Source] → [Target] migration
---

## Protected Paths (already migrated — do not modify)
[glob patterns of completed files]

## Coexistence Rules
- [rule about how old and new code interact]
- [rule about shared interfaces]

## Migration Conventions
- New [target] files go in: [path]
- Converted files get suffix: [convention]
- Bridge/adapter files go in: [path]

## Forbidden During Migration
- Do not refactor old [source] code — migrate it as-is first, then refactor
- Do not change shared API contracts without updating both sides
- Do not delete source files until phase validation passes
```

---

### 2.5 migration-validator (haiku, 10 turns)

**Role**: Validate that a migration phase completed successfully by running automated checks.

**Tools**: Read, Glob, Grep, Bash

**Input**: MIGRATION-PLAN.md (current phase) + repo path

**Workflow**:
1. Read current phase's validation criteria from MIGRATION-PLAN.md
2. For each criterion, run the check:
   - File existence checks (new files created?)
   - Test pass checks (run test suite, check exit code)
   - Build checks (does it compile/build?)
   - Config validity checks (parse JSON/YAML, validate)
   - API compatibility checks (OpenAPI diff, gRPC reflection)
   - No regression checks (old tests still pass?)
3. Update MIGRATION-PLAN.md with validation results
4. Return PASS/FAIL with details

**Output**: PhaseValidation JSON

```json
{
  "phase": 2,
  "phaseName": "Migrate API routes",
  "verdict": "PASS",
  "checks": [
    { "name": "New FastAPI routes exist", "status": "PASS", "detail": "12/12 routes converted" },
    { "name": "Old Django tests still pass", "status": "PASS", "detail": "47/47 passed" },
    { "name": "New FastAPI tests pass", "status": "PASS", "detail": "12/12 passed" },
    { "name": "API contract unchanged", "status": "WARN", "detail": "response format differs for /api/users (snake_case vs camelCase)" }
  ]
}
```

---

### 2.6 migration-progress-tracker (haiku, 10 turns)

**Role**: Parse MIGRATION-PLAN.md, compute progress metrics, update status, and report to user.

**Tools**: Read, Edit, Grep

**Input**: MIGRATION-PLAN.md path

**Workflow**:
1. Parse all phases and their checkbox statuses
2. Compute: phases complete, phases in progress, phases blocked
3. Compute file-level progress: files migrated vs total
4. Identify blockers and stalled phases
5. Update the overview section with current stats
6. Return progress summary

**Output**: Progress report for display

---

### Agent Summary Table

| Agent | Model | Turns | Role | Input | Output |
|---|---|---|---|---|---|
| migration-analyzer | sonnet | 30 | Detect & characterize migrations | repo + signals | MigrationProfile JSON |
| risk-assessor | sonnet | 15 | Score risk, find blockers | MigrationProfile | RiskAssessment JSON |
| migration-planner | sonnet | 25 | Generate phased plan | Profile + Risk + Strategy | MIGRATION-PLAN.md |
| migration-agent-generator | sonnet | 20 | Generate migration-specific AI tooling | Profile + Strategy + Plan | agents, rules, skills |
| migration-validator | haiku | 10 | Validate phase completion | Plan + repo | PhaseValidation JSON |
| migration-progress-tracker | haiku | 10 | Track and report progress | Plan | Progress summary |

---

## 3. New Scripts & Detectors

### 3.1 detect-migration.sh

**Purpose**: Heuristic pre-scan for migration signals (runs before any LLM, like `analyze.sh`).

**Detection logic**:

```bash
# Category 1: Language Migration
# Detect dual-language projects where one language is clearly newer
# Signal: presence of both *.py and *.java in src/, with Java files having newer mtime
# Signal: build configs for both (pyproject.toml + pom.xml, package.json + go.mod)

# Category 2: Framework Migration
# Signal: both old and new framework configs (webpack.config.js + vite.config.ts)
# Signal: both old and new framework imports (import Django + import FastAPI)
# Signal: migration-specific files (vue-migration-helper, angular2-migration)

# Category 3: Cloud Migration
# Signal: IaC files for multiple clouds (terraform with aws + gcp providers)
# Signal: cloud-specific SDK imports for multiple providers
# Signal: migration docs referencing cloud move

# Category 4: Legacy → Modern
# Signal: both callback and async/await patterns in same codebase
# Signal: both class components and functional components (React)
# Signal: both REST controllers and GraphQL resolvers

# Category 5: Toolchain
# Signal: both old and new CI configs (.circleci/ + .github/workflows/)
# Signal: both old and new build configs (webpack + vite, Grunt + Rollup)
# Signal: both package managers (package-lock.json + pnpm-lock.yaml)

# Category 6: Infrastructure
# Signal: docker-compose.yml + kubernetes/ directory
# Signal: Dockerfile + Helm charts
# Signal: both old and new OS references in configs

# Category 7: Architecture
# Signal: monolith app + new microservice directories
# Signal: REST routes + event handlers in same project
# Signal: sync database calls + message queue consumers

# Category 8: AI Tool Migration
# Signal: .cursor/rules/ without .claude/ (Cursor-only → multi-tool)
# Signal: stale CLAUDE.md (references removed packages, old commands)
# Signal: no AI config at all (greenfield AI setup)
```

**Output**: MigrationSignals JSON

```json
{
  "detected": true,
  "migrations": [
    {
      "category": "framework",
      "from": "webpack",
      "to": "vite",
      "confidence": 0.85,
      "signals": [
        { "type": "config_coexistence", "files": ["webpack.config.js", "vite.config.ts"] },
        { "type": "deprecation_marker", "file": "webpack.config.js", "line": "// TODO: remove after vite migration" }
      ]
    }
  ],
  "migrationDocs": ["docs/migration-plan.md", "MIGRATION.md"],
  "deprecationMarkers": 14,
  "dualConfigs": [["webpack.config.js", "vite.config.ts"]],
  "ageGap": { "older": "webpack.config.js (2023-01)", "newer": "vite.config.ts (2025-11)" }
}
```

**Implementation approach**:
- Pure bash (no LLM, like existing `analyze.sh`)
- File existence checks via glob
- Content checks via grep (import patterns, markers)
- Timestamp comparison for detecting "old" vs "new"
- Confidence scoring based on signal count and strength

---

### 3.2 migration-catalog.md

**Purpose**: Reference catalog mapping migration types to strategies, risks, and agent configurations — similar to how `subagent-templates-catalog.md` maps signals to subagent templates.

**Structure**:

```markdown
# Migration Catalog

## Language Migrations

### Python → Java
- **Typical Strategy**: strangler-fig (service-by-service)
- **Risk Baseline**: HIGH (different paradigm, type system, runtime)
- **Key Challenges**: Dynamic typing → static typing, pip → maven, pytest → JUnit
- **Bridge Patterns**: REST API boundary, shared protobuf/OpenAPI, database as integration point
- **Conversion Rules**: 
  - `dict` → `Map<K,V>` or POJO
  - `list comprehension` → `Stream.map().collect()`
  - `with` → try-with-resources
  - `**kwargs` → Builder pattern
  - `pytest` fixtures → JUnit `@BeforeEach`
- **Test Approach**: Port tests first, then convert source to pass ported tests
- **Estimated Agent Config**: migration-converter (sonnet), migration-safety rule, migrate-file skill

### JavaScript → TypeScript
- **Typical Strategy**: incremental (file-by-file, strict mode off initially)
- **Risk Baseline**: LOW (same runtime, gradual adoption)
- **Key Challenges**: Adding types to dynamic patterns, any-casting, third-party typings
- **Bridge Pattern**: allowJs: true in tsconfig, rename .js → .ts progressively
- **Conversion Rules**:
  - Add type annotations to function signatures
  - Replace `require()` with `import`
  - Add interfaces for object shapes
  - Convert `module.exports` to `export`
- **Test Approach**: Tests work as-is, add type checking to CI
- **Estimated Agent Config**: migration-converter (haiku — low complexity), ts-strictness rule

[... similar entries for each migration type ...]

## Framework Migrations

### Django → FastAPI
- **Typical Strategy**: strangler-fig (route-by-route)
- **Risk Baseline**: MEDIUM
- **Key Challenges**: ORM (Django ORM → SQLAlchemy/Tortoise), middleware, auth, template → API-only
- **Bridge Pattern**: Django serves legacy routes, FastAPI serves new routes, nginx routes by path prefix
- **Coexistence Config**: Both apps run, reverse proxy routes traffic
[...]

## Architecture Migrations

### Monolith → Microservices
- **Typical Strategy**: strangler-fig (extract bounded contexts)
- **Risk Baseline**: CRITICAL (changes deployment, data, team boundaries)
- **Key Challenges**: Data decomposition, distributed transactions, service discovery, observability
- **Bridge Pattern**: Shared database initially, then event-driven data sync
- **Phase Template**: 
  1. Identify bounded contexts
  2. Add API boundaries within monolith (modular monolith)
  3. Extract first service (lowest coupling)
  4. Add inter-service communication
  5. Extract remaining services
  6. Decompose database
[...]
```

This catalog is the **knowledge base** that migration-planner and migration-agent-generator use to produce project-specific plans and tooling.

---

### 3.3 validate-migration-phase.sh

**Purpose**: Automated validation script run by migration-validator agent.

**Checks by category**:

| Check | Command | Applies To |
|---|---|---|
| Tests pass | `npm test` / `pytest` / `mvn test` | All |
| Build succeeds | `npm run build` / `go build ./...` | Language, Framework |
| Type check | `tsc --noEmit` / `mypy` | TypeScript, Python typing |
| API compat | `openapi-diff old.yaml new.yaml` | REST→GraphQL, framework migrations |
| No regressions | `diff <(old_test_output) <(new_test_output)` | All |
| Config valid | `docker-compose config` / `kubectl apply --dry-run` | Infra, Cloud |
| Lint passes | Project's lint command | All |
| Coverage maintained | `coverage report --fail-under=N` | All with existing coverage |

---

### 3.4 migration-progress.sh

**Purpose**: Parse MIGRATION-PLAN.md and output progress metrics as JSON.

```json
{
  "totalPhases": 5,
  "completedPhases": 2,
  "inProgressPhases": 1,
  "blockedPhases": 0,
  "notStartedPhases": 2,
  "percentComplete": 40,
  "filesTotal": 47,
  "filesMigrated": 18,
  "testsTotal": 93,
  "testsMigrated": 41,
  "lastUpdated": "2026-04-03T14:30:00Z",
  "estimatedRemaining": "3 phases",
  "blockers": []
}
```

---

## 4. Migration Workflow Steps

### What happens when the user runs `/scaffold migrate`

**Step 0: Command Parsing**

```
/scaffold migrate                          → auto-detect migrations in CWD
/scaffold migrate --from django --to fastapi → explicit migration type
/scaffold migrate https://github.com/user/repo → clone + detect
/scaffold migrate --status                  → show migration progress
/scaffold migrate --validate                → validate current phase
/scaffold migrate --next                    → advance to next phase
```

**Step 1: Heuristic Migration Detection**

Run `detect-migration.sh` on the repo. Produces MigrationSignals JSON.

If `--from` and `--to` are specified, skip detection and construct signals directly.

If no migrations detected and no explicit flags: report "No migration signals detected. Use `--from X --to Y` to specify explicitly." and exit.

**Step 2: Deep Migration Analysis**

Dispatch **migration-analyzer** agent (sonnet, 30 turns).

Input: repo path + MigrationSignals JSON.

Parallelly, the main thread:
- Reads README, CONTRIBUTING for migration context
- Reads any existing migration docs (MIGRATION.md, docs/migration-*.md)
- Reads existing MIGRATION-PLAN.md if present (resuming a migration)

Output: MigrationProfile JSON.

**Step 3: Risk Assessment**

Dispatch **risk-assessor** agent (sonnet, 15 turns).

Input: MigrationProfile JSON.

Output: RiskAssessment JSON.

**Step 3.5: Risk Gate**

Display risk assessment to user:

```
## Migration Risk Assessment

Overall Risk: HIGH (78/100)

┌─────────────┬───────┬──────────────────────────────────────────────┐
│ Dimension   │ Score │ Key Factors                                  │
├─────────────┼───────┼──────────────────────────────────────────────┤
│ Complexity  │ 85    │ 47 files, 3 external APIs, custom ORM       │
│ Blast Radius│ 70    │ 2 downstream services, shared DB            │
│ Reversibility│ 60   │ Schema changes hard to reverse               │
│ Test Coverage│ 35   │ 23% coverage — migrate tests first!          │
│ Data Risk   │ 90    │ Production DB migration, 3 table changes    │
└─────────────┴───────┴──────────────────────────────────────────────┘

⚠️  BLOCKERS:
  1. Low test coverage (23%) — write tests for Python API before migrating

💡 RECOMMENDATIONS:
  1. Write integration tests for Python API first
  2. Use parallel-run validation between Python and Java
  3. Migrate non-critical services first (reporting, notifications)

Proceed with migration planning? (y/n)
```

If CRITICAL risk (81+): add extra warning "This migration has CRITICAL risk. Consider a pilot project first."

**Step 4: Strategy Selection**

Interactive prompt — user selects migration strategy:

```
## Choose Migration Strategy

Based on your [Python → Java] migration (HIGH risk), recommended strategies:

[1] ⭐ Strangler Fig (recommended for HIGH risk)
    Gradually replace old code with new. Both coexist behind a router/proxy.
    Old code stays live until new code is validated per-endpoint.
    Best for: API services, web apps, anything with clear routing boundaries.

[2] Parallel Run
    Run both old and new simultaneously, compare outputs.
    Catch discrepancies before switching over.
    Best for: Data pipelines, financial systems, anything where correctness is critical.

[3] Incremental (file-by-file)
    Convert one file at a time. Both languages coexist in the repo.
    Best for: Libraries, utilities, low-coupling codebases.

[4] Big Bang (⚠️ not recommended at this risk level)
    Rewrite everything at once. High risk, fast completion.
    Best for: Small projects, low-stakes code, or when old code is truly abandoned.

[5] Custom
    Define your own strategy.

Select strategy [1]:
```

Follow-up questions based on strategy:
- Strangler fig: "Which routing layer? (nginx / API gateway / code-level)"
- Parallel run: "Where should output comparison happen? (CI / runtime / offline)"
- Incremental: "Priority order? (tests first / leaf modules / core modules)"

**Step 5: Plan Generation**

Dispatch **migration-planner** agent (sonnet, 25 turns).

Input: MigrationProfile + RiskAssessment + MigrationStrategy.

Reads: migration-catalog.md for strategy templates specific to this migration type.

Output: MIGRATION-PLAN.md (full phased plan with checkboxes, validation criteria, rollback instructions).

**Step 6: AI Tooling Generation**

Dispatch **migration-agent-generator** agent (sonnet, 20 turns).

Input: MigrationProfile + MigrationStrategy + MIGRATION-PLAN.md.

Reads: migration-catalog.md for conversion rules and agent patterns.

Generates:
- Migration-specific agents (ephemeral — marked with `# MIGRATION: remove after completion`)
- Migration safety rules
- Migration skills (if multi-step workflows are needed)
- Updated CLAUDE.md section for migration context
- Updated .cursor/rules/ for migration conventions
- Updated AGENTS.md with migration instructions

**Step 7: Conflict Check with Existing Setup**

If the repo already has a scaffold setup:
- Read existing .claude/agents/, .claude/rules/, .claude/skills/
- Check for conflicts (e.g., existing safety rule blocks migration changes)
- Merge migration rules into existing rules (additive, not replacing)
- Add migration agents alongside existing agents
- Update existing CLAUDE.md with migration section (append, don't rewrite)

**Step 8: Quality Review**

Use existing **quality-reviewer** agent on all generated migration files.

Additional migration-specific checks:
- MIGRATION-PLAN.md has at least 2 phases (no big-bang disguised as phased)
- Each phase has validation criteria
- Each phase has rollback procedure
- Migration agents reference real files and commands from the repo
- Migration rules don't conflict with existing rules

**Step 9: Write Files + Summary**

Write all files to disk. Summary format:

```
## Migration Setup Complete

### Migration: Python → Java (Strangler Fig)
Risk Level: HIGH | Phases: 5 | Strategy: strangler-fig

### Files Created

Migration Plan:
  MIGRATION-PLAN.md                         — 5-phase plan with validation + rollback

Migration Agents:
  .claude/agents/migration-converter.md     — Converts Python files to Java (Sonnet)
  .claude/agents/migration-validator.md     — Validates phase completion (Haiku)

Migration Rules:
  .claude/rules/migration-safety.md         — Protect migrated files, enforce coexistence
  .cursor/rules/migration-conventions.mdc   — Cursor rules for migration period

Updated Files:
  CLAUDE.md                                 — Added Migration Context section
  AGENTS.md                                 — Added migration instructions

### What's Next
1. Review MIGRATION-PLAN.md — your phased plan
2. Start Phase 1: "Write integration tests for existing Python API"
3. Use: "convert src/services/users.py to Java" — migration-converter agent will assist
4. After each phase: run `/scaffold migrate --validate` to check completion
5. Track progress: run `/scaffold migrate --status`

### When Migration Completes
Run `/scaffold migrate --cleanup` to remove migration agents and rules.
```

---

### Sub-commands

| Command | Action |
|---|---|
| `/scaffold migrate` | Full migration setup (detect, assess, plan, generate) |
| `/scaffold migrate --from X --to Y` | Explicit migration type |
| `/scaffold migrate --status` | Show progress (phases complete, files migrated) |
| `/scaffold migrate --validate` | Validate current phase completion |
| `/scaffold migrate --next` | Mark current phase done, advance to next |
| `/scaffold migrate --cleanup` | Remove migration agents/rules after completion |
| `/scaffold migrate --rollback` | Show rollback instructions for current phase |
| `/scaffold migrate --replan` | Re-analyze and regenerate plan (if scope changed) |

---

## 5. Example Outputs

### Example 1: Python → Java Migration

**Scenario**: A Python 3.11 FastAPI service being rewritten in Java 21 Spring Boot. 12 Java files already exist alongside 47 Python files. Shared OpenAPI spec.

**Detected migration**:
```
Category: language
From: Python 3.11 (FastAPI) | 47 .py files, pyproject.toml, pytest
To: Java 21 (Spring Boot) | 12 .java files, pom.xml, JUnit
Coexistence: Active (20% complete)
Bridge: OpenAPI spec at openapi/spec.yaml
```

**Generated MIGRATION-PLAN.md** (abbreviated):

```markdown
# Migration Plan: Python (FastAPI) → Java (Spring Boot)

## Overview
- **Risk Level**: HIGH (78/100)
- **Strategy**: Strangler Fig (route-by-route)
- **Phases**: 5
- **Completion**: 20% (12/60 modules)

## Phase 1: Test Foundation — Status: NOT_STARTED

### Scope
- Write integration tests for all 15 untested Python endpoints
- Set up JUnit test structure mirroring pytest

### Entry Criteria
- [x] Java project structure exists (pom.xml, src/main/java/)
- [ ] CI runs both Python and Java test suites

### Steps
1. Add pytest-cov to dev dependencies, run `pytest --cov=src --cov-report=term`
2. For each untested endpoint in `src/routes/`:
   - Write integration test hitting the actual endpoint
   - Verify response matches OpenAPI spec
3. Set up JUnit + MockMvc test structure in `src/test/java/`
4. Add Java test stage to CI pipeline

### Validation
- [ ] Python test coverage >= 70%
- [ ] `pytest` passes (all tests green)
- [ ] `mvn test` passes (existing Java tests green)
- [ ] CI pipeline runs both suites

### Rollback
Remove new test files. No production code changed in this phase.

---

## Phase 2: Leaf Services (Notifications, Reporting) — Status: NOT_STARTED
[... migrate non-critical endpoints first ...]

## Phase 3: Core Services (Users, Auth, Orders) — Status: NOT_STARTED
[... migrate high-traffic endpoints ...]

## Phase 4: Data Layer — Status: NOT_STARTED
[... migrate database access, ORM → JPA ...]

## Phase 5: Cutover & Cleanup — Status: NOT_STARTED
[... remove Python code, update deployment, remove proxy routing ...]
```

**Generated migration-converter agent** (abbreviated):

```yaml
---
name: migration-converter
description: "Converts Python FastAPI endpoints to Java Spring Boot, preserving API contracts"
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
model: sonnet
maxTurns: 25
---
# MIGRATION: Remove after Python→Java migration completes

## Context
Converting Python 3.11 FastAPI service to Java 21 Spring Boot.
OpenAPI contract at openapi/spec.yaml is the source of truth.

## Conversion Rules
- FastAPI `@app.get("/path")` → Spring `@GetMapping("/path")`
- Pydantic models → Java records or POJOs with Jakarta validation
- `async def` → Spring WebFlux `Mono<>` / `Flux<>` (or blocking if simpler)
- SQLAlchemy models → JPA `@Entity` classes
- pytest fixtures → JUnit `@BeforeEach` + `@MockBean`
- `HTTPException(status_code=404)` → `ResponseStatusException(HttpStatus.NOT_FOUND)`
- Python `dict` returns → Java `ResponseEntity<T>`

## Workflow
1. Read the Python source file completely
2. Read the corresponding OpenAPI endpoint spec
3. Check if Java equivalent already exists (skip if so)
4. Convert: route → controller, model → entity/record, test → JUnit
5. Run `mvn test -pl [module]` to verify
6. Mark file as converted in MIGRATION-PLAN.md

## Do NOT
- Modify the OpenAPI spec (it's the contract)
- Delete the Python file (mark with `# MIGRATED: see java/...`)
- Convert multiple files in one session
- Refactor during migration — convert 1:1 first
```

**Generated migration-safety rule**:

```markdown
---
name: migration-safety
description: "Safety rules during Python→Java migration"
---

## Already Migrated (do not modify Python originals)
- src/routes/notifications.py → MIGRATED
- src/routes/reports.py → MIGRATED

## Coexistence Rules
- Python runs on port 8000, Java on port 8080
- Nginx routes: /api/notifications/* → Java, everything else → Python
- Both services share the same PostgreSQL database (read-only for new Java service until Phase 4)
- OpenAPI spec at openapi/spec.yaml is the CONTRACT — never modify without updating both sides

## Migration Conventions
- New Java files: src/main/java/com/example/[module]/
- When converting a Python file, add comment: `# MIGRATED: see src/main/java/com/example/[module]/`
- Bridge tests: tests that hit both Python and Java endpoints and compare responses go in tests/bridge/
```

---

### Example 2: Monolith → Microservices

**Scenario**: A Rails monolith (200+ models) being decomposed into microservices. Two services already extracted (auth, notifications). Shared PostgreSQL database.

**Detected migration**:
```
Category: architecture
From: Rails monolith (app/models/ 200+ files, app/controllers/ 80+ files)
To: Microservices (services/auth-service/, services/notification-service/)
Coexistence: Active (2 services extracted, monolith still handles 90% of traffic)
Bridge: Shared PostgreSQL database, REST API calls between services
```

**Risk Assessment**:
```
Overall: CRITICAL (88/100)
- Complexity: 95 (200+ models, deeply coupled)
- Blast Radius: 90 (production traffic, downstream consumers)
- Reversibility: 70 (can re-merge services, but DB decomposition is hard)
- Test Coverage: 65 (decent Rails test coverage)
- Data Risk: 95 (shared DB must be decomposed)
```

**Generated MIGRATION-PLAN.md** (abbreviated phases):

```markdown
# Migration Plan: Rails Monolith → Microservices

## Overview
- **Risk Level**: CRITICAL (88/100)
- **Strategy**: Strangler Fig (extract bounded contexts)
- **Phases**: 7
- **Completion**: 10% (2/~12 services extracted)

## Phase 1: Domain Mapping — Status: NOT_STARTED
Identify bounded contexts. Group 200+ models into service boundaries.
Map cross-boundary dependencies (which models reference which).
Output: services-map.md with proposed service boundaries.

## Phase 2: Modular Monolith — Status: NOT_STARTED
Add module boundaries WITHIN the monolith. Enforce module APIs.
This is the safety net — if decomposition fails, modular monolith is still an improvement.

## Phase 3: Extract Billing Service — Status: NOT_STARTED
Next lowest-coupling bounded context after auth and notifications.

## Phase 4: Event Bus + Async Communication — Status: NOT_STARTED
Replace direct DB queries between services with events.
Introduce message broker (RabbitMQ/Kafka).

## Phase 5: Extract Order Management — Status: NOT_STARTED
Higher coupling — requires event-driven data sync.

## Phase 6: Extract User Profiles — Status: NOT_STARTED
Depends on auth service. Shared users table must be decomposed.

## Phase 7: Database Decomposition — Status: NOT_STARTED
Each service gets its own database. Data sync via events.
THIS IS THE HARDEST PHASE. Separate planning recommended.
```

**Generated service-extractor agent**:

```yaml
---
name: service-extractor
description: "Extracts a bounded context from the Rails monolith into a standalone microservice"
model: sonnet
maxTurns: 30
tools: [Read, Write, Edit, Glob, Grep, Bash]
---
# MIGRATION: Remove after monolith decomposition completes

## Workflow
1. Read the domain map (services-map.md) for this bounded context
2. Identify all models, controllers, and jobs belonging to this context
3. Map cross-boundary dependencies (what this context calls, what calls it)
4. Create service directory structure (Dockerfile, API routes, models, tests)
5. Extract models — copy to service, add API endpoint for cross-service access
6. Extract controllers — convert to service API controllers
7. Add anti-corruption layer in monolith (calls service API instead of local model)
8. Write integration tests (service ↔ monolith)
9. Update docker-compose.yml with new service

## Rules
- Never move a model that is directly referenced by 5+ other models — add API first
- Always add database migration to copy data, never move-in-place
- Extracted service MUST have health check endpoint
- Monolith must be deployable independently at every step
```

---

### Example 3: GitLab → GitHub

**Scenario**: A team migrating from GitLab (self-hosted) to GitHub. Has .gitlab-ci.yml, GitLab-specific CI features (environments, deploy tokens), merge request templates, and GitLab container registry.

**Detected migration**:
```
Category: toolchain
From: GitLab (self-hosted) | .gitlab-ci.yml, .gitlab/, gitlab-ci templates
To: GitHub | .github/workflows/ (2 workflows already created)
Coexistence: Active (CI runs on both platforms during transition)
Bridge: Mirrored repos (GitLab mirrors to GitHub)
```

**Risk Assessment**:
```
Overall: MEDIUM (52/100)
- Complexity: 55 (CI pipeline is moderately complex, 8 stages)
- Blast Radius: 45 (team workflow changes, but code itself unchanged)
- Reversibility: 80 (can always go back to GitLab)
- Test Coverage: N/A (toolchain migration, not code)
- Data Risk: 30 (need to preserve MR history, issues)
```

**Generated MIGRATION-PLAN.md** (abbreviated):

```markdown
# Migration Plan: GitLab → GitHub

## Overview
- **Risk Level**: MEDIUM (52/100)
- **Strategy**: Parallel Run (both CIs run during transition)
- **Phases**: 4

## Phase 1: Repository & History Migration — Status: NOT_STARTED
### Steps
1. Push repo to GitHub (git remote add github; git push github --all --tags)
2. Transfer issues: `glab export` → `gh issue create` (or use GitLab→GitHub migration tool)
3. Transfer merge request history (archive, not recreate)
4. Set up branch protection rules on GitHub matching GitLab settings

### Validation
- [ ] All branches exist on GitHub
- [ ] All tags exist on GitHub
- [ ] Git history is identical (`git log --oneline` matches)
- [ ] Branch protection rules configured

## Phase 2: CI Pipeline Migration — Status: NOT_STARTED
### Steps
1. Convert .gitlab-ci.yml stages to .github/workflows/ jobs:
   - `stages: [build, test, deploy]` → separate workflow files or job dependencies
   - GitLab `variables:` → GitHub `env:` / secrets
   - GitLab `artifacts:` → GitHub `actions/upload-artifact`
   - GitLab `services: [postgres:14]` → GitHub `services:` in job
   - GitLab `rules:` → GitHub `on:` triggers + `if:` conditions
   - GitLab `include:` → GitHub reusable workflows
   - GitLab `environment:` → GitHub Environments
   - GitLab `deploy_token` → GitHub deploy keys / GITHUB_TOKEN
2. Set up GitHub Actions secrets (from GitLab CI/CD variables)
3. Run both CI systems in parallel for 2 weeks
4. Compare CI results daily

### Validation
- [ ] All 8 CI stages have GitHub Actions equivalents
- [ ] GitHub Actions passes on current main branch
- [ ] GitLab CI and GitHub Actions produce same artifacts
- [ ] Deploy workflow works to staging environment

## Phase 3: Team Workflow Migration — Status: NOT_STARTED
### Steps
1. Create PR template (.github/pull_request_template.md) from MR template
2. Set up CODEOWNERS from GitLab approval rules
3. Configure GitHub Projects board matching GitLab board
4. Update team docs: new workflow, new URLs, new commands (glab → gh)
5. Container registry: migrate images from GitLab registry to GHCR

## Phase 4: Cutover & Cleanup — Status: NOT_STARTED
### Steps
1. Archive GitLab repo (read-only)
2. Remove .gitlab-ci.yml and .gitlab/ directory
3. Update all docs referencing GitLab URLs
4. Remove GitLab-specific CI templates
5. Celebrate 🎉
```

**Generated migration-ci-converter agent**:

```yaml
---
name: migration-ci-converter
description: "Converts GitLab CI/CD configuration to GitHub Actions workflows"
model: sonnet
maxTurns: 20
tools: [Read, Write, Edit, Glob, Grep]
---
# MIGRATION: Remove after GitLab→GitHub migration completes

## Conversion Map
| GitLab CI | GitHub Actions |
|---|---|
| `stages:` | `jobs:` with `needs:` |
| `image:` | `runs-on:` + `container:` |
| `services:` | `services:` (same concept) |
| `variables:` | `env:` or `${{ secrets.X }}` |
| `artifacts: paths:` | `actions/upload-artifact@v4` |
| `cache: paths:` | `actions/cache@v4` |
| `rules: - if: $CI_COMMIT_BRANCH == "main"` | `on: push: branches: [main]` |
| `include: - template:` | Reusable workflow or composite action |
| `environment: name: staging` | `environment: staging` |
| `only: merge_requests` | `on: pull_request:` |
| `retry: max: 2` | `continue-on-error` + manual retry |

## Workflow
1. Read .gitlab-ci.yml completely
2. Parse into stages and jobs
3. For each stage, create corresponding GitHub Actions job
4. Handle special features (environments, artifacts, caching, services)
5. Write to .github/workflows/ci.yml
6. Test with `act` (local GitHub Actions runner) if available
```

---

## 6. Integration with Existing Cortex

### 6.1 How Migration Fits into the Existing Flow

```
/scaffold          → "What AI setup does this repo need?"        (steady-state)
/scaffold migrate  → "This repo is changing — help it change."   (transition)
/scaffold audit    → "Is the existing AI setup correct?"         (validation)
/scaffold optimize → "Can we improve the AI setup?"              (improvement)
/scaffold discover → "What's my whole dev environment?"          (multi-project)
```

Migration is **additive** — it does not replace or modify the scaffold flow. Instead:

1. Migration agents are generated **alongside** scaffold agents (not instead of)
2. Migration rules **merge into** existing rules (additive)
3. MIGRATION-PLAN.md is a **new artifact** that doesn't conflict with CLAUDE.md
4. The migration-specific CLAUDE.md section is **appended** to existing CLAUDE.md

### 6.2 Shared Components

| Component | Shared or New | How Used |
|---|---|---|
| `analyze.sh` | **Shared** | Migration uses existing ProjectProfile + adds migration signals |
| `detect-opportunities.sh` | **Shared** | Migration augments with migration-specific opportunities |
| `quality-reviewer` agent | **Shared** | Reviews migration files with same quality checks |
| `score.sh` | **Extended** | Add migration-specific scoring dimensions |
| `dispatch-table.json` | **Extended** | Add migration variant |
| `repo-analyzer` agent | **Shared** | Migration-analyzer calls it for baseline understanding |
| Reference catalogs | **Extended** | Add migration-catalog.md |
| Templates | **Extended** | Add migration agent/rule templates |
| Evals | **Extended** | Add migration eval cases |

### 6.3 Variant Dispatch Integration

Add a migration variant to `dispatch-table.json`:

```json
{
  "name": "migration",
  "file": "variants/SKILL-migration.md",
  "signals": [
    { "type": "file_exists", "pattern": "MIGRATION-PLAN.md" },
    { "type": "script_output", "script": "detect-migration.sh", "key": "detected", "value": true }
  ],
  "match": "any",
  "priority": 15
}
```

When the variant dispatcher detects an active migration, the regular `/scaffold` command can include migration context in generated CLAUDE.md automatically — even without running `/scaffold migrate` explicitly.

### 6.4 Command Integration

The `/scaffold migrate` command is a **new command** (`commands/scaffold-migrate.md`) that invokes the migration variant of SKILL.md. It shares the mode-routing infrastructure but takes a different path.

```
commands/
├── scaffold.md           # existing
├── scaffold-audit.md     # existing
├── scaffold-optimize.md  # existing
├── scaffold-discover.md  # existing
└── scaffold-migrate.md   # NEW
```

### 6.5 Post-Migration Cleanup

When migration completes, `/scaffold migrate --cleanup`:
1. Removes all agents marked `# MIGRATION: remove after...`
2. Removes migration-specific rules
3. Removes migration-specific skills
4. Archives MIGRATION-PLAN.md to `docs/migrations/YYYY-MM-DD-[type].md`
5. Runs regular `/scaffold` to regenerate clean AI setup for the new stack
6. Runs `/scaffold audit` to verify cleanliness

This is critical: **migration artifacts are designed to be temporary**.

---

## 7. File Structure

### New Files to Create

```
skills/scaffold/
├── agents/
│   ├── migration-analyzer.md          # NEW — detect & characterize migrations
│   ├── risk-assessor.md               # NEW — score risk, find blockers
│   ├── migration-planner.md           # NEW — generate phased plan
│   ├── migration-agent-generator.md   # NEW — generate migration AI tooling
│   ├── migration-validator.md         # NEW — validate phase completion
│   └── migration-progress-tracker.md  # NEW — track & report progress
├── scripts/
│   ├── detect-migration.sh            # NEW — heuristic migration signal scanner
│   ├── validate-migration-phase.sh    # NEW — automated phase validation
│   └── migration-progress.sh          # NEW — parse plan, output metrics
├── references/
│   └── migration-catalog.md           # NEW — migration types, strategies, rules
├── templates/
│   ├── subagents/
│   │   ├── migration-converter.md     # NEW — language/framework converter template
│   │   ├── migration-ci-converter.md  # NEW — CI system converter template
│   │   ├── service-extractor.md       # NEW — monolith→micro extractor template
│   │   └── migration-infra.md         # NEW — infrastructure converter template
│   └── migration-rules/
│       ├── migration-safety.md        # NEW — safety rule template
│       ├── coexistence.md             # NEW — dual-system coexistence template
│       └── migration-conventions.md   # NEW — naming/path conventions template
├── variants/
│   └── SKILL-migration.md             # NEW — migration variant of SKILL.md
├── evals/
│   └── evals.json                     # EXTEND — add migration eval cases
commands/
└── scaffold-migrate.md                # NEW — /scaffold migrate command
```

### Total: 16 new files + 2 extended files

- 6 new agents
- 3 new scripts
- 1 new reference catalog
- 4 new templates (subagents + rules)
- 1 new variant
- 1 new command
- Extended: evals.json, dispatch-table.json

---

## 8. Implementation Phases

### Phase 1: Foundation (Build First)

**Goal**: Detect migrations and generate plans. No AI tooling generation yet.

| # | Task | Files | Depends On |
|---|---|---|---|
| 1a | Write `detect-migration.sh` — heuristic signal scanner | `scripts/detect-migration.sh` | Nothing |
| 1b | Write `migration-catalog.md` — migration knowledge base | `references/migration-catalog.md` | Nothing |
| 1c | Write `migration-analyzer.md` agent | `agents/migration-analyzer.md` | 1a |
| 1d | Write `risk-assessor.md` agent | `agents/risk-assessor.md` | 1c |
| 1e | Write `migration-planner.md` agent | `agents/migration-planner.md` | 1b, 1d |
| 1f | Write `scaffold-migrate.md` command | `commands/scaffold-migrate.md` | 1e |
| 1g | Write `SKILL-migration.md` variant (Steps 0-5 only) | `variants/SKILL-migration.md` | 1a-1f |

**Deliverable**: `/scaffold migrate` detects migrations, shows risk, generates MIGRATION-PLAN.md. No AI agents generated yet.

**Validation**: Run against test fixtures with injected migration signals. Manually verify plan quality.

---

### Phase 2: AI Tooling Generation

**Goal**: Generate migration-specific agents, rules, and skills.

| # | Task | Files | Depends On |
|---|---|---|---|
| 2a | Write migration agent templates (converter, ci-converter, extractor, infra) | `templates/subagents/migration-*.md` | Phase 1 |
| 2b | Write migration rule templates (safety, coexistence, conventions) | `templates/migration-rules/*.md` | Phase 1 |
| 2c | Write `migration-agent-generator.md` agent | `agents/migration-agent-generator.md` | 2a, 2b |
| 2d | Extend `SKILL-migration.md` with Steps 6-9 (generation, review, write) | `variants/SKILL-migration.md` | 2c |
| 2e | Test with fixture repos: inject Python+Java, Django+FastAPI scenarios | Manual testing | 2d |

**Deliverable**: `/scaffold migrate` generates full migration setup (plan + agents + rules + skills).

---

### Phase 3: Validation & Progress Tracking

**Goal**: Phase validation, progress tracking, sub-commands.

| # | Task | Files | Depends On |
|---|---|---|---|
| 3a | Write `migration-validator.md` agent | `agents/migration-validator.md` | Phase 2 |
| 3b | Write `validate-migration-phase.sh` script | `scripts/validate-migration-phase.sh` | 3a |
| 3c | Write `migration-progress-tracker.md` agent | `agents/migration-progress-tracker.md` | Phase 2 |
| 3d | Write `migration-progress.sh` script | `scripts/migration-progress.sh` | 3c |
| 3e | Add sub-commands to SKILL-migration.md (`--status`, `--validate`, `--next`, `--cleanup`) | `variants/SKILL-migration.md` | 3a-3d |

**Deliverable**: Full lifecycle management — start migration, track progress, validate phases, clean up.

---

### Phase 4: Testing & Hardening

**Goal**: Eval cases, fixture projects, dispatch-table integration.

| # | Task | Files | Depends On |
|---|---|---|---|
| 4a | Add 6 migration eval cases to evals.json | `evals/evals.json` | Phase 3 |
| 4b | Create migration test fixture (dual-language project) | `test/fixtures/migration-py-to-ts/` | Phase 3 |
| 4c | Add migration variant to dispatch-table.json | `variants/dispatch-table.json` | Phase 3 |
| 4d | Run full eval suite, fix failures | All files | 4a-4c |
| 4e | Test interaction with existing scaffold (no conflicts) | Manual testing | 4d |

**Proposed eval cases**:

| Eval Name | Fixture | Key Assertions |
|---|---|---|
| `migrate-detect-dual-language` | migration-py-to-ts | `file_contains: MigrationProfile, "category": "language"` |
| `migrate-plan-has-phases` | migration-py-to-ts | `file_contains: MIGRATION-PLAN.md, "## Phase 1"` |
| `migrate-plan-has-rollback` | migration-py-to-ts | `file_contains: MIGRATION-PLAN.md, "### Rollback"` |
| `migrate-agents-are-ephemeral` | migration-py-to-ts | `file_contains: migration-converter.md, "# MIGRATION: remove"` |
| `migrate-no-conflict-with-scaffold` | migration-py-to-ts | Existing CLAUDE.md preserved, migration section appended |
| `migrate-cleanup-removes-artifacts` | migration-py-to-ts | After cleanup: no migration agents, rules, or skills remain |

---

### Phase 5: Polish & Extended Migration Types

**Goal**: Cover all 8 migration categories with catalog entries and templates.

| # | Task | Priority |
|---|---|---|
| 5a | Extend migration-catalog.md with all language migration entries | HIGH |
| 5b | Extend migration-catalog.md with all framework migration entries | HIGH |
| 5c | Extend migration-catalog.md with cloud migration entries | MEDIUM |
| 5d | Extend migration-catalog.md with architecture migration entries | MEDIUM |
| 5e | Extend migration-catalog.md with toolchain migration entries | MEDIUM |
| 5f | Extend migration-catalog.md with infrastructure migration entries | LOW |
| 5g | Extend migration-catalog.md with AI tool migration entries | LOW |
| 5h | Add strategy-specific interactive prompts (strangler fig, parallel run, etc.) | MEDIUM |
| 5i | Add multi-migration support (detect and plan 2+ simultaneous migrations) | LOW |

---

### Implementation Timeline Summary

| Phase | Scope | New Files | Dependencies |
|---|---|---|---|
| **Phase 1** | Detection + Planning | 7 | None |
| **Phase 2** | AI Tooling Generation | 5 | Phase 1 |
| **Phase 3** | Validation + Progress | 5 | Phase 2 |
| **Phase 4** | Testing + Hardening | 3 | Phase 3 |
| **Phase 5** | Extended Coverage | 0 (catalog extensions) | Phase 4 |

---

## Design Decisions & Trade-offs

### Decision 1: Separate command (`/scaffold migrate`) vs mode flag (`/scaffold --migrate`)

**Chose**: Separate command.

**Why**: Migration is a fundamentally different workflow from scaffolding. Scaffolding generates steady-state tooling; migration generates temporary, phased tooling. Sharing a command would lead to confusing flag combinations and unclear defaults. A separate command also makes it discoverable and documentable independently.

### Decision 2: Ephemeral migration agents vs permanent migration-aware agents

**Chose**: Ephemeral with explicit cleanup.

**Why**: Migration agents encode assumptions about the old→new transition that become wrong after migration completes. A "Python→Java converter" agent in a pure-Java repo is confusing. Marking them ephemeral and providing cleanup makes intent clear.

### Decision 3: MIGRATION-PLAN.md as living document vs separate tracking system

**Chose**: Living markdown document with checkboxes.

**Why**: Developers live in their editor and git. A markdown file is version-controlled, diff-able, reviewable in PRs, and editable by both humans and AI agents. External tracking adds friction. The progress-tracker agent updates it automatically.

### Decision 4: Strategy selection interactive vs auto-selected

**Chose**: Interactive with smart defaults.

**Why**: Migration strategy has massive impact on risk and effort. This is not a decision to make automatically. The system recommends based on risk level, but the developer chooses. This matches the existing Cortex interactive pattern.

### Decision 5: One migration-converter agent template vs per-migration-type templates

**Chose**: Per-type templates with shared structure.

**Why**: The conversion rules between Python→Java vs Django→FastAPI vs GitLab→GitHub are fundamentally different. A generic converter would either be too vague or require massive conditional logic. Templates with consistent structure (same frontmatter, same workflow pattern, different conversion rules) balance reuse with specificity.

---

This plan is designed to be built incrementally — Phase 1 alone delivers value (migration detection + planning), and each subsequent phase adds capability without breaking what came before. The architecture follows every existing Cortex pattern (agent frontmatter, template placeholders, quality review gate, scoring, eval cases) so migration fits seamlessly into the ecosystem.
