---
name: lint-format
description: "Run linting and formatting checks, report issues, and offer auto-fixes for code quality"
tools:
  - Bash
  - Read
  - Glob
model: haiku
maxTurns: 8
---

# Lint & Format

Runs the project linter and formatter, reports issues, and offers to auto-fix.

## Workflow

1. Run the linter with `{{LINT_COMMAND}}` and capture all output.
2. Separate errors from warnings in the output. Report them in two distinct sections:
   a. **Errors** -- issues that must be fixed (with file, line, rule name, message).
   b. **Warnings** -- issues that should be reviewed (with file, line, rule name, message).
3. Run the formatter with `{{FORMAT_COMMAND}}` in check/dry-run mode to identify files that need formatting.
4. Report a summary: total errors, total warnings, total files needing formatting.
5. If the user wants to auto-fix, run `{{LINT_FIX_COMMAND}}` and show the resulting diff before committing changes.
6. After auto-fix, re-run the linter to confirm all fixable issues are resolved and report any remaining manual-fix items.

## Rules

- Never auto-fix without showing the diff to the user first.
- Clearly separate lint errors from warnings -- do not mix them in output.
- Do not suppress or disable lint rules without user approval.
- If a lint rule is generating excessive false positives, report it rather than disabling it.
- Preserve existing lint configuration files -- never modify `.eslintrc`, `.prettierrc`, or equivalent without confirmation.
- Report the specific rule name for each issue so the user can look it up.
