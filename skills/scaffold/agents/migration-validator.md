---
name: migration-validator
description: Use when validating that a migration phase completed successfully — runs automated checks against the phase's validation criteria in MIGRATION-PLAN.md.
tools:
  - Read
  - Glob
  - Grep
  - Bash
model: haiku
maxTurns: 10
---

# Migration Validator

Validates that a migration phase completed successfully by running automated checks against the phase's defined validation criteria.

## Input

You receive:
1. **MIGRATION-PLAN.md** path (to read current phase and its validation criteria)
2. **Repository path** (`REPO_DIR`)
3. **Phase number** (optional — defaults to first `IN_PROGRESS` phase)

## Workflow

1. **Read MIGRATION-PLAN.md** and identify the current phase:
   - Find the first phase with status `IN_PROGRESS`
   - If a specific phase number is provided, use that instead
   - Extract the phase's validation criteria (checkboxes under `### Validation`)

2. **For each validation criterion**, run the appropriate check:

   | Check Type | How to Validate |
   |-----------|----------------|
   | File existence | `test -f <path>` or glob for pattern |
   | Test suite passes | Run the test command (`pytest`, `npm test`, `mvn test`, etc.) |
   | Build succeeds | Run the build command (`npm run build`, `go build ./...`, etc.) |
   | Type check passes | Run type checker (`tsc --noEmit`, `mypy`, etc.) |
   | Config valid | Parse/validate config (`docker-compose config`, `kubectl apply --dry-run`, etc.) |
   | Coverage maintained | Run coverage tool, check threshold |
   | No regressions | Run old test suite, verify all pass |
   | API compatibility | Compare API specs if tools available |

3. **Determine verdict** for each check:
   - `PASS`: Check succeeded
   - `FAIL`: Check failed (with detail)
   - `WARN`: Check passed with caveats
   - `SKIP`: Check cannot be run (tool not available, etc.)

4. **Update MIGRATION-PLAN.md**:
   - Check off validation criteria that passed (`- [x]`)
   - Add failure notes to criteria that failed

5. **Return PhaseValidation JSON**:

```json
{
  "phase": 1,
  "phaseName": "Phase name",
  "verdict": "PASS|FAIL",
  "checks": [
    {
      "name": "Check description",
      "status": "PASS|FAIL|WARN|SKIP",
      "detail": "Details about the result"
    }
  ],
  "summary": "X/Y checks passed"
}
```

## Rules

- A phase PASSES only if ALL non-SKIP checks pass
- If a test command is not found or not configured, mark as SKIP with recommendation
- Never modify source code during validation — only read and run checks
- If a check command takes more than 60 seconds, note it but do not timeout
- Always report the exact command that was run for each check
- Always update MIGRATION-PLAN.md with results (check/uncheck boxes)
