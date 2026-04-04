# Cortex Release Plan — Product Completeness Backlog

Generated from a full audit of command routing, privacy claims, install safety,
auto-improve behavior, migration surface, and metadata consistency.

Focus: real user-facing completeness, not code style.

---

## P0 — Broken user flows (must fix before any release)

### P0-1: Optimize mode routing is unreachable for `auto-improve`

**Problem:** Top-level mode routing (`SKILL.md:53`) requires `$ARGUMENTS` to be
exactly `"optimize"`. But `/scaffold-optimize` sends `"optimize auto-improve"`,
which is not an exact match, so it falls through to Scaffold Mode and treats
`"optimize auto-improve"` as a repo path. Auto-Improve Mode is unreachable via
the documented command.

**Files:** `skills/scaffold/SKILL.md` (lines 50–55, 626–629)

**Acceptance criteria:**
- `"optimize"`, `"optimize auto-improve"`, and `"optimize /path"` all reach
  Optimize Mode
- Change routing from exact match to starts-with for `"optimize"`

**Parallel:** Yes — isolated to SKILL.md mode routing block.

---

### P0-2: Version mismatch — plugin.json vs VERSION file

**Problem:** `.claude-plugin/plugin.json` says `"version": "1.0.0"` while
`VERSION` says `0.2.0`. `install.sh` reads `VERSION`, so users see
`Installing Cortex v0.2.0` but the plugin registry says `1.0.0`.

**Files:** `.claude-plugin/plugin.json`, `VERSION`

**Acceptance criteria:**
- Both files show the same version string
- Decide canonical version (likely `0.2.0` since the product is pre-1.0)

**Parallel:** Yes — no overlap with other items.

---

### P0-3: `auto-improve.sh` loop always exits on first iteration

**Problem:** The loop re-scores the same fixtures immediately after printing
"dispatch skill-improver agent" (no edit happens). NEW_AVG == PREV_AVG, so it
hits the `revert` branch and breaks on iteration 1 every time. The script is
measurement infrastructure pretending to be a loop.

**Files:** `skills/scaffold/scripts/auto-improve.sh` (lines 148–208)

**Acceptance criteria:**
- Either: make the script an honest measurement-only tool (remove loop, rename),
  and update all docs that reference "autoresearch loop"
- Or: implement `--measure-only` flag so the script can be called in two phases
  (measure-before / measure-after)
- Remove the stale git-stash promise from the header (line 22)

**Parallel:** Yes — isolated script, no SKILL.md overlap.

---

### P0-4: `plugin.json` description omits 3 of 6 commands

**Problem:** Description says "Three modes: scaffold, audit, optimize" but the
product ships discover, toolbox, and migrate as first-class commands. Users
browsing the plugin registry see an incomplete feature list.

**Files:** `.claude-plugin/plugin.json` (line 3)

**Acceptance criteria:**
- Description mentions all 6 modes/commands
- Keywords array includes `discover`, `toolbox`, `migrate`

**Parallel:** Yes — can be batched with P0-2.

---

### P0-5: `install.sh` backup omits `scaffold-migrate.md`

**Problem:** The backup loop lists 5 commands but misses `scaffold-migrate.md`.
On reinstall, the user's migrate command backup is silently lost.

**Files:** `install.sh` (line 20)

**Acceptance criteria:**
- Backup loop includes all 6 `scaffold*.md` files
- Comment on line 39 lists all 6 commands

**Parallel:** Yes — isolated to install.sh.

---

## P1 — Misleading claims and wrong docs (fix before public promotion)

### P1-1: Audit mode ignores path argument

**Problem:** `commands/scaffold-audit.md` suggests `audit /path/to/repo`, but
SKILL.md routing (line 52) only matches the exact string `"audit"`. Passing
`"audit /some/path"` falls through to Scaffold Mode and interprets it as a
repo path — likely errors or wrong behavior.

**Files:** `skills/scaffold/SKILL.md` (line 52), `commands/scaffold-audit.md`

**Acceptance criteria:**
- Routing matches `$ARGUMENTS` starting with `"audit"`, then parses an optional
  path after the keyword
- Or: document that audit always uses cwd and remove path examples from the
  command file

**Parallel:** Can be batched with P0-1 (same routing block in SKILL.md).

---

### P1-2: Optimize mode ignores path argument

**Problem:** `commands/scaffold-optimize.md` suggests `optimize /path`, but
Optimize Mode Step 1 always runs `find ".claude/skills"` from cwd. The path
argument is never used.

**Files:** `skills/scaffold/SKILL.md` (lines 631–636), `commands/scaffold-optimize.md`

**Acceptance criteria:**
- Either: implement path-aware optimize (use parsed path as base dir)
- Or: remove path examples from the command file and document cwd-only behavior

**Parallel:** Can be batched with P0-1 / P1-1 (same SKILL.md area).

---

### P1-3: Post-scaffold suggestion says "optimize fixes automatically" — it doesn't

**Problem:** When score is low, SKILL.md (lines 566–569) prints "Run
`/scaffold optimize` to fix automatically." But Optimize Mode is report-only;
it does not apply fixes. Users expect auto-fix, get a report.

**Files:** `skills/scaffold/SKILL.md` (lines 566–569)

**Acceptance criteria:**
- Change wording to "Run `/scaffold optimize` to identify improvement
  opportunities" or similar honest phrasing
- Or: implement actual fix capability in Optimize Mode

**Parallel:** Can be batched with P0-1 group (same file, different section).

---

### P1-4: Discover privacy claim is overstated

**Problem:** `discover-orchestrator.sh` header (line 12) claims "No environment
variable VALUES are read — only existence is checked." But sub-script
`detect-cli-tools.sh` reads the value of `USE_BUILTIN_RIPGREP` and emits it
into JSON output. `discover-company.sh` reads file contents (npm configs, git
remotes) and emits internal URLs and org names. The "nothing leaves your
machine" claim in `commands/scaffold-discover.md` doesn't account for the fact
that DeveloperDNA is fed to AI model agents.

**Files:**
- `skills/scaffold/scripts/discover-orchestrator.sh` (lines 11–12)
- `commands/scaffold-discover.md` (line with "Nothing leaves your machine")
- `skills/scaffold/scripts/detect-cli-tools.sh` (lines 154–161)

**Acceptance criteria:**
- Narrow the orchestrator claim to "Scripts do not upload data. The resulting
  DeveloperDNA is stored locally and only shared with AI agents you invoke."
- Fix the specific env-value leak in detect-cli-tools.sh (emit existence boolean
  instead of actual value)
- Remove or qualify "Nothing leaves your machine" from the command file

**Parallel:** Yes — isolated to discover scripts and one command file.

---

### P1-5: `install-cli-tools.sh` "never runs without explicit user confirmation" is misleading

**Problem:** Header (line 3) claims confirmation is required, but there is no
interactive prompt. The `--yes` flag is a non-interactive bypass. "Explicit user
confirmation" means passing a CLI flag, not a human-in-the-loop approval.

**Files:** `skills/scaffold/scripts/install-cli-tools.sh` (lines 2–4)

**Acceptance criteria:**
- Either: add an actual interactive `read -p "Continue? [y/N]"` prompt when
  `--yes` is not passed
- Or: reword the header to "Defaults to dry-run mode. Pass --yes to execute
  installs."

**Parallel:** Yes — isolated script.

---

### P1-6: `AGENTS.md` says 18 evals, actual count is 28

**Problem:** `AGENTS.md` states "18 eval cases" and "18 test cases" in multiple
places. `evals.json` has 28 entries. `CLAUDE.md` correctly says 28.

**Files:** `AGENTS.md` (all lines referencing "18")

**Acceptance criteria:**
- All references to eval count in AGENTS.md updated to 28

**Parallel:** Yes — documentation only.

---

### P1-7: Optimize mode references external `skill-creator` command

**Problem:** SKILL.md line 647 tells users to run `skill-creator eval
{skill-name}`. That is an external plugin not shipped by Cortex. Users without
it get a command-not-found error.

**Files:** `skills/scaffold/SKILL.md` (line 647)

**Acceptance criteria:**
- Replace with Cortex's own eval runner: `bash
  ~/.claude/skills/scaffold/scripts/run-skill-evals.sh`
- Or: note that `skill-creator` is optional and link to its install page

**Parallel:** Can be batched with P1-3 (same file, nearby section).

---

### P1-8: Optimize mode suggests wrong eval format

**Problem:** SKILL.md (lines 645–646) tells users to create `eval_001.md`,
`eval_002.md` files. Cortex's own eval harness uses `evals/evals.json` with
assertion-based JSON — the markdown eval files would never be run by
`run-skill-evals.sh`.

**Files:** `skills/scaffold/SKILL.md` (lines 642–646)

**Acceptance criteria:**
- Replace with guidance to add entries to `evals.json` using Cortex's assertion
  format, or remove the eval-creation advice from Optimize Mode

**Parallel:** Can be batched with P1-7 (same file section).

---

## P2 — Edge cases and polish (fix before scaling)

### P2-1: Discover `/tmp` path collisions

**Problem:** SKILL.md steps D2/D11 use fixed path
`/tmp/cortex-developer-dna.json`. Concurrent sessions overwrite each other.

**Files:** `skills/scaffold/SKILL.md` (lines 1043–1046, 1231–1234)

**Acceptance criteria:**
- Use `mktemp` or session-scoped temp dir instead of fixed path

**Parallel:** Yes.

---

### P2-2: Migration variant can preempt plain scaffold unexpectedly

**Problem:** `dispatch-table.json` defines a `migration` variant (priority 15)
triggered by `MIGRATION-PLAN.md` or `detect-migration.sh`. A plain `/scaffold`
on a repo with those files gets routed to `SKILL-migration.md` — probably not
what the user intended.

**Files:** `skills/scaffold/variants/dispatch-table.json` (lines 37–46),
`skills/scaffold/SKILL.md` (lines 12–29)

**Acceptance criteria:**
- Either: remove the migration row from dispatch-table (migration should be
  explicit via `/scaffold-migrate` only)
- Or: lower priority below monorepo and add a user confirmation step

**Parallel:** Yes — isolated to dispatch-table.json (protected file; plan explicitly requires it).

---

### P2-3: Monorepo dispatch misses yarn/npm workspaces

**Problem:** `dispatch-table.json` checks for turbo/nx/lerna/pnpm-workspace but
not plain `workspaces` field in `package.json` (yarn/npm workspaces).
`SKILL-monorepo.md` documents handling these, but dispatch won't route to it.

**Files:** `skills/scaffold/variants/dispatch-table.json` (lines 15–21)

**Acceptance criteria:**
- Add `workspaces` in `package.json` as a signal for monorepo variant

**Parallel:** Can be batched with P2-2 (same file).

---

### P2-4: `detect-cli-tools.sh` missing package managers

**Problem:** `detect_pkg_manager` only recognizes brew/apt/dnf/pacman. Missing
yum, zypper, nix-env. On those systems, tool install recommendations are
degraded.

**Files:** `skills/scaffold/scripts/detect-cli-tools.sh`

**Acceptance criteria:**
- Add yum, zypper, nix-env detection
- Fallback message when no supported manager is found

**Parallel:** Yes.

---

### P2-5: `schedule-autorun.sh` has no confirmation before crontab rewrite

**Problem:** `setup` subcommand immediately rewrites user crontab or loads
launchd jobs with no interactive confirmation.

**Files:** `skills/scaffold/scripts/schedule-autorun.sh`

**Acceptance criteria:**
- Add confirmation prompt before modifying crontab/launchd
- Print what will be added before asking

**Parallel:** Yes.

---

### P2-6: `output_contains` eval assertion always skips

**Problem:** In `run-skill-evals.sh`, the `output_contains` assertion type
returns 2 (skip) unconditionally. Any eval relying solely on `output_contains`
(audit, discover, parts of toolbox/migrate evals) never actually validates model
output.

**Files:** `skills/scaffold/scripts/run-skill-evals.sh`

**Acceptance criteria:**
- Either: implement `output_contains` to check captured command output
- Or: convert affected evals to use `file_contains` or `file_exists` assertions
  that actually run
- Document which assertions are live vs skipped

**Parallel:** Yes — isolated to eval harness.

---

### P2-7: `audit-existing.sh` is shipped but never wired

**Problem:** The script exists and is installed, but `SKILL.md` Audit Mode never
calls it. It could provide useful pre-scan data for the audit flow.

**Files:** `skills/scaffold/scripts/audit-existing.sh`, `skills/scaffold/SKILL.md`
(Audit Mode section)

**Acceptance criteria:**
- Wire it into Audit Mode Step 1 as an initial scan, or remove it from the
  install to reduce surface area

**Parallel:** Yes — touches SKILL.md Audit Mode section only.

---

### P2-8: `install.sh` comment lists only 4 commands

**Problem:** Comment on line 39 says "Install commands (/scaffold,
/scaffold-audit, /scaffold-optimize, /scaffold-discover)" but the `cp` glob
actually installs all 6. Misleading for maintainers.

**Files:** `install.sh` (line 39)

**Acceptance criteria:**
- Update comment to list all 6 commands

**Parallel:** Can be batched with P0-5 (same file).

---

### P2-9: Discover services script not passed projects file

**Problem:** `discover-services.sh` accepts an optional projects file for
compose-file detection, but `discover-orchestrator.sh` never passes it. The
`composeFiles` field in DeveloperDNA is always empty.

**Files:** `skills/scaffold/scripts/discover-orchestrator.sh` (line 68),
`skills/scaffold/scripts/discover-services.sh`

**Acceptance criteria:**
- Pass projects.json to discover-services.sh from orchestrator
- Or: remove the parameter from discover-services.sh if compose detection is
  not needed at the orchestrator level

**Parallel:** Yes.

---

## Execution Batches

Ordered to minimize merge conflicts, especially around `SKILL.md`.

### Batch 1: SKILL.md routing + claims (serial)

Items: **P0-1, P1-1, P1-2, P1-3, P1-7, P1-8**

All touch `skills/scaffold/SKILL.md`. Do them in one branch to avoid conflicts.
P0-1 is the routing fix (lines 50–55). P1-1/P1-2 extend routing for audit/optimize
paths. P1-3 is wording fix (lines 566–569). P1-7/P1-8 are nearby in Optimize
Mode (lines 642–647).

**Estimated scope:** ~20 lines changed in SKILL.md.

---

### Batch 2: Metadata and install (parallel-safe)

Items: **P0-2, P0-4, P0-5, P1-6, P2-8**

Files: `VERSION`, `.claude-plugin/plugin.json`, `install.sh`, `AGENTS.md`.
No overlap with SKILL.md. All changes are small and independent.

---

### Batch 3: `auto-improve.sh` reconciliation (parallel-safe)

Items: **P0-3**

File: `skills/scaffold/scripts/auto-improve.sh`. Rewrite the script to be an
honest two-phase measurer or connect it to the Python autoresearch loop.
Isolated from other batches.

---

### Batch 4: Privacy and safety claims (parallel-safe)

Items: **P1-4, P1-5, P2-5**

Files: `discover-orchestrator.sh`, `detect-cli-tools.sh`,
`commands/scaffold-discover.md`, `install-cli-tools.sh`,
`schedule-autorun.sh`. No SKILL.md overlap.

---

### Batch 5: Dispatch table and variants (parallel-safe)

Items: **P2-2, P2-3**

File: `skills/scaffold/variants/dispatch-table.json`. Small, isolated.
**Note:** This is a protected file per AGENTS.md; changes require testing
against all 3 fixtures.

---

### Batch 6: Eval harness and wiring (parallel-safe)

Items: **P2-6, P2-7**

Files: `run-skill-evals.sh`, `SKILL.md` (Audit Mode only — can go after
Batch 1 merges).

---

### Batch 7: Small script fixes (parallel-safe)

Items: **P2-1, P2-4, P2-9**

Files: `SKILL.md` (discover temp path), `detect-cli-tools.sh`,
`discover-orchestrator.sh`. P2-1 touches SKILL.md Discover section — schedule
after Batch 1.

---

## Summary

| Priority | Count | Key theme |
|----------|-------|-----------|
| P0       | 5     | Broken routing, version lies, dead loop, incomplete install |
| P1       | 8     | Misleading docs, overstated claims, wrong tool references |
| P2       | 9     | Edge cases, missing wiring, polish |
| **Total**| **22**| |

| Batch | Items | Conflict risk | Can parallelize with |
|-------|-------|---------------|---------------------|
| 1     | P0-1, P1-1, P1-2, P1-3, P1-7, P1-8 | High (SKILL.md) | Nothing |
| 2     | P0-2, P0-4, P0-5, P1-6, P2-8 | None | Batches 3–7 |
| 3     | P0-3 | None | Batches 2, 4–7 |
| 4     | P1-4, P1-5, P2-5 | None | Batches 2, 3, 5–7 |
| 5     | P2-2, P2-3 | Low (dispatch-table) | Batches 2–4, 6–7 |
| 6     | P2-6, P2-7 | Low | Batches 2–5 |
| 7     | P2-1, P2-4, P2-9 | Low (SKILL.md discover) | Batches 2–5 (after Batch 1) |

**Recommended order:** Batch 1 first (unblocks correct routing), then
Batches 2–5 in parallel, then Batches 6–7.
