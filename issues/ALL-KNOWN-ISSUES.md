# Cortex — All Known Issues

**Last updated:** 2026-04-04
**Source:** 18 review files from 5 AI reviewers across 3 review rounds, quality audit, A/B testing on 8 local + OSS projects

---

## Status Legend

| Status | Meaning |
|--------|---------|
| ✅ FIXED | Resolved and committed |
| 🔴 OPEN | Not yet fixed |
| 🟡 PARTIAL | Partially addressed |

---

## 1. Detection Accuracy Issues

### ISS-001: False positive migrations in fixture-heavy repos 🔴
**Severity:** HIGH  
**Source:** Local testing (2026-04-04)  
**File:** `scripts/detect-migration.sh`  
**Description:** Cortex detected 4 migrations in its own repo (Python→TypeScript, Django→FastAPI, AWS→GCP, AWS→Azure). These are false positives caused by test fixture files (`test/fixtures/migration-py-to-ts/`) containing both Python and TypeScript code.  
**Proposed Fix:** Exclude paths matching `test/`, `tests/`, `fixtures/`, `__tests__/`, `spec/`, `examples/`, `sample/` from migration signal scanning. Or weight signals lower if they only appear inside test directories.

### ISS-002: False positive migration in Deno (Express→Fastify) 🔴
**Severity:** MEDIUM  
**Source:** OSS testing (2026-04-04)  
**File:** `scripts/detect-migration.sh`  
**Description:** Deno (a Rust runtime) was flagged for Express→Fastify migration. Likely triggered by JS/TS test files or example code within the repo, not an actual migration.  
**Proposed Fix:** Cross-reference detected framework with primary language. If primary language is Rust and framework signal is Node.js, reduce confidence significantly or discard.

### ISS-003: sourceFileCount=0 on OSS repos 🔴
**Severity:** MEDIUM  
**Source:** OSS testing (2026-04-04)  
**File:** `scripts/detect-opportunities.sh`  
**Description:** The `softSkillSignals.sourceFileCount` field returns 0 for next.js, flask, and deno repos despite having thousands of source files.  
**Proposed Fix:** Debug the file counting logic in detect-opportunities.sh. Likely a `find` command with wrong maxdepth or missing file extensions.

### ISS-004: Ecosystem detection is machine-level, not project-level 🔴
**Severity:** HIGH  
**Source:** OSS testing (2026-04-04)  
**File:** `scripts/detect-cli-tools.sh`  
**Description:** Flask (Python-only) shows `hasPackageJson`, `hasTsconfig`, `hasGoMod`, `hasCargoToml` as true. The script is checking for these at the machine level or too broadly, not within the project directory.  
**Proposed Fix:** Ensure all ecosystem detection checks are scoped to `$REPO_DIR` only, not the user's home directory or global paths.

### ISS-005: Slack integration false positive on minimal projects 🟡
**Severity:** MEDIUM  
**Source:** Quality audit (2026-04-04)  
**File:** `scripts/detect-opportunities.sh`  
**Description:** Slack integration score=60 assigned to all projects including minimal ones with no Slack signals. `/Applications/Slack.app` is a machine-level signal, not project-level evidence.  
**Status:** Partially fixed — Slack.app weight reduced from 20→10 and made conditional. But still triggers on projects with zero Slack integration.  
**Proposed Fix:** Only score Slack > 0 if project-level signals exist (SLACK_BOT_TOKEN, @slack/bolt dep, webhook URL). Machine-level Slack.app should add at most +5 bonus on top of existing project signals, never standalone.

### ISS-006: next.js detected as AWS→GCP migration 🔴
**Severity:** LOW  
**Source:** OSS testing (2026-04-04)  
**File:** `scripts/detect-migration.sh`  
**Description:** next.js repo detected as having AWS→GCP cloud migration. Likely triggered by AWS SDK references in examples/tests alongside Vercel (GCP-adjacent) deployment config.  
**Proposed Fix:** Increase confidence threshold for cloud migrations. Require explicit migration-intent signals (terraform provider changes, cloud CLI config files) not just SDK coexistence.

---

## 2. Shell Script Issues

### ISS-007: find -o operator precedence in detect-migration.sh 🟡
**Severity:** HIGH  
**Source:** Cursor GPT-5.4 review, Round 1  
**File:** `scripts/detect-migration.sh:215`  
**Description:** `find "$REPO_DIR" -maxdepth 2 -type d -name "kubernetes" -o -name "k8s"` — the `-name "k8s"` arm has no `-type d` or `-maxdepth 2` constraint due to missing parentheses.  
**Status:** Reported as fixed in round 2 but Round 3 Cursor GPT-5.4 flagged it again. Need to verify.  
**Proposed Fix:** `find "$REPO_DIR" -maxdepth 2 -type d \( -name "kubernetes" -o -name "k8s" \)`

### ISS-008: validate-migration-phase.sh $DETAIL json_escape 🟡
**Severity:** HIGH  
**Source:** Cursor GPT-5.4, Round 3  
**File:** `scripts/validate-migration-phase.sh:190`  
**Description:** `$DETAIL` variable not passed through `json_escape()` at line 190 when embedded in JSON output.  
**Status:** Fixed in commit `957d928` but Round 3 reviewer still flagged it. May have been reviewing pre-fix code.  
**Proposed Fix:** Verify the fix is actually in place. If not, wrap `$DETAIL` in `json_escape()`.

### ISS-009: 4 soft skill templates missing ## Placeholders 🔴
**Severity:** LOW  
**Source:** Quality audit (2026-04-04)  
**Files:** `templates/skills/avoid-ai-slop.md`, `devils-advocate.md`, `grill-me.md`, `think-out-loud.md`  
**Description:** These templates don't have `## Placeholders` sections. Intentional (they're not parameterized) but inconsistent with the project convention.  
**Proposed Fix:** Add `## Placeholders` section with "None — this template has no configurable placeholders" for consistency.

### ISS-010: 7 orphaned/unused files 🔴
**Severity:** LOW  
**Source:** Quality audit (2026-04-04)  
**Files:**
- `templates/ai-agent-config.sh` — generated but not referenced by any agent or SKILL.md step
- `scripts/log-discover.sh` — appears unused by discover-orchestrator.sh
- Possibly others  
**Proposed Fix:** Audit each file. If genuinely unused, either integrate into the workflow or remove.

---

## 3. Migration Workflow Issues

### ISS-011: Fast Track confidence vs risk confusion ✅
**Severity:** CRITICAL  
**Source:** Cursor Opus, Round 1  
**File:** `variants/SKILL-migration.md`  
**Description:** Fast Track at Step 1.5 used detection "confidence" as proxy for "risk" — these are different dimensions.  
**Status:** Fixed — moved to Step 3.5, now uses RiskAssessment.overallRisk.

### ISS-012: SKILL.md migrate mode routing ✅
**Severity:** CRITICAL  
**Source:** Anthropic Opus, Round 1  
**File:** `skills/scaffold/SKILL.md`  
**Description:** Main SKILL.md didn't recognize "migrate" mode in its routing table.  
**Status:** Fixed — added migrate mode routing.

### ISS-013: Migration evals untestable ✅
**Severity:** CRITICAL  
**Source:** Anthropic Opus, Round 1  
**File:** `evals/evals.json`  
**Description:** 5 of 6 migration evals were skipped by static runner.  
**Status:** Fixed — added script_output_valid_json assertions with fixture args.

### ISS-014: 14 of 21 template placeholders unknown to generator ✅
**Severity:** HIGH  
**Source:** Cursor Codex 5.3, Round 1  
**File:** `agents/migration-agent-generator.md`  
**Description:** Generator only knew 7 of 21 placeholders across 4 templates.  
**Status:** Fixed — all 30 placeholders now documented and covered.

### ISS-015: JSON injection in detect-migration.sh ✅
**Severity:** HIGH  
**Source:** Cursor GPT-5.4, Round 1  
**File:** `scripts/detect-migration.sh`  
**Description:** ~22 locations with unescaped variable interpolation into JSON strings.  
**Status:** Fixed — json_escape() added.

### ISS-016: validate-migration-phase.sh runs npm test silently ✅
**Severity:** HIGH  
**Source:** Cursor GPT-5.4, Round 1  
**File:** `scripts/validate-migration-phase.sh:114`  
**Description:** Script actually ran `npm test` on target repo — dangerous side effects.  
**Status:** Fixed — replaced with infrastructure check (no test execution).

### ISS-017: PHASE_NUM not validated as integer ✅
**Severity:** HIGH  
**Source:** Cursor GPT-5.4, Round 1  
**File:** `scripts/validate-migration-phase.sh`  
**Description:** User input passed to grep regex without integer validation.  
**Status:** Fixed — validated with `^[0-9]+$` regex.

### ISS-018: Empty repos return detected:true ✅
**Severity:** HIGH  
**Source:** Codex, Round 1  
**File:** `scripts/detect-migration.sh`  
**Description:** AI-tools category treated "no AI setup" as migration even in empty repos.  
**Status:** Fixed — requires ≥3 source files.

### ISS-019: Verdict enum mismatch ✅
**Severity:** MEDIUM  
**Source:** Anthropic Opus, Round 3  
**File:** `scripts/validate-migration-phase.sh`  
**Description:** Script used PASS/FAIL but agent also defined WARN.  
**Status:** Fixed — added WARN verdict to script.

### ISS-020: Catalog model contradicts template (JS→TS haiku vs sonnet) ✅
**Severity:** HIGH  
**Source:** Cursor Codex 5.3, Round 1  
**File:** `references/migration-catalog.md`  
**Description:** JS→TS entry said "haiku" but migration-converter.md uses sonnet.  
**Status:** Fixed — aligned to sonnet.

---

## 4. Scaffold / Interactive UX Issues

### ISS-021: --all --interactive flag conflict ✅
**Severity:** MEDIUM  
**Source:** GPT-5.4, Interactive UX review  
**File:** `skills/scaffold/SKILL.md`  
**Description:** No defined behavior when both --all and --interactive passed.  
**Status:** Fixed — --interactive wins, --minimal always overrides.

### ISS-022: No visual marker for smart defaults ✅
**Severity:** LOW  
**Source:** GPT-5.4, Interactive UX review  
**File:** `skills/scaffold/SKILL.md`  
**Description:** Pre-selected items in interactive screen had no visual indicator.  
**Status:** Fixed — added `*` suffix for smart defaults.

---

## 5. Toolbox / CLI Issues

### ISS-023: json_escape missing in detect-cli-tools.sh ✅
**Severity:** HIGH  
**Source:** Quality audit (2026-04-04)  
**File:** `scripts/detect-cli-tools.sh`  
**Description:** Tool version strings interpolated into JSON without escaping.  
**Status:** Fixed in commit `614405a`.

### ISS-024: ai-agent-config.sh was a stub ✅
**Severity:** MEDIUM  
**Source:** Review (2026-04-04)  
**File:** `templates/ai-agent-config.sh`  
**Description:** Only 15 lines — insufficient for the configure sub-command.  
**Status:** Fixed — expanded to 172 lines covering Claude Code, Codex, Cursor, PATH, EDITOR.

---

## 6. Documentation Issues

### ISS-025: Stale CLAUDE.md counts ✅
**Severity:** MEDIUM  
**Source:** Quality audit (2026-04-04)  
**File:** `CLAUDE.md`  
**Description:** Documented "18 test cases" (actual: 28), "17 subagent templates" (actual: 21).  
**Status:** Fixed in commit `ecfa0a9`.

### ISS-026: codex-formats.md not passed to codex-specialist agent 🔴
**Severity:** LOW  
**Source:** Quality audit (2026-04-04)  
**File:** `agents/codex-specialist.md`  
**Description:** Agent may discover `references/codex-formats.md` independently, but no explicit reference in its instructions.  
**Proposed Fix:** Add explicit `Read {CLAUDE_SKILL_DIR}/references/codex-formats.md` instruction.

---

## 7. Original Codex 5.4 Line-by-Line Review (All Fixed)

### ISS-027: Spaced path handling in discovery scripts ✅
### ISS-028: Credential leaks in git remote/npm registry output ✅
### ISS-029: Quality gate bypass (integration gen before gate) ✅
### ISS-030: --minimal mode not overriding generation gate ✅
### ISS-031: 5 agents missing ## Workflow section ✅
### ISS-032: Soft-skill templates missing model/tool metadata ✅
### ISS-033: Missing MCP catalog entries (gitlab/confluence/pagerduty) ✅
### ISS-034: Template placeholder vars not documented ✅
### ISS-035: Inconsistent set -euo pipefail ✅
### ISS-036: score.sh eval usage (brittle pattern) ✅
### ISS-037: ls | wc -l fragile counting (SC2012) ✅
### ISS-038: schedule-autorun.sh A && B || C anti-pattern ✅
### ISS-039: Unused variable in run-skill-evals.sh ✅
### ISS-040: Python files missing return type annotations ✅
### ISS-041: Silent exception swallowing in Python/shell ✅
### ISS-042: Agent descriptions inconsistent (not starting with "Use when") ✅
### ISS-043: Soft-skill catalog missing allowed-tools ✅
### ISS-044: json_escape missing in 10 older scripts ✅

---

## Summary

| Status | Count |
|--------|-------|
| ✅ FIXED | 34 |
| 🔴 OPEN | 8 |
| 🟡 PARTIAL | 2 |
| **Total** | **44** |

### Open Issues by Priority

| Priority | Count | Issues |
|----------|-------|--------|
| HIGH | 2 | ISS-001 (fixture false positives), ISS-004 (ecosystem machine-level) |
| MEDIUM | 3 | ISS-002 (Deno false positive), ISS-003 (sourceFileCount=0), ISS-005 (Slack partial) |
| LOW | 5 | ISS-006 (next.js AWS→GCP), ISS-007 (find -o verify), ISS-009 (soft skill placeholders), ISS-010 (orphaned files), ISS-026 (codex-formats ref) |

---

*This document is the single source of truth for all known Cortex issues. Update it as issues are fixed or new ones discovered.*
