# Cortex Overnight Build Task

## Mission
Implement the full interactive scaffold feature plan, run multiple review cycles, autoresearch loop, test on real open source projects, then fix all gaps found. All while Lathesh sleeps.

## Reference Files
- Plan: /tmp/cortex-feature-plan.md (full 5-phase implementation plan)
- Cortex: /Users/lathesh/Documents/workspace/cortex/
- Skills installed at: ~/.claude/skills/scaffold/

## Phase 0: Sync Skills Before Starting
```bash
# Copy latest cortex skills to global install
cp -r /Users/lathesh/Documents/workspace/cortex/skills/scaffold/* ~/.claude/skills/scaffold/
```

## Phase 1: Implement the Feature (Follow the Plan)
Read /tmp/cortex-feature-plan.md completely. Then implement ALL tasks in order:

### Task 1: Create detect-opportunities.sh
File: skills/scaffold/scripts/detect-opportunities.sh
- Bash script that detects subagent signals (test frameworks, linters, build tools, git activity, CI)
- Detects integration signals (Jira, Confluence, Slack, Linear, Notion, Sentry, Datadog) via env vars + file heuristics
- Detects soft skill signals (hasDocs, hasComplexDomain, isMediumPlus)
- Outputs OpportunitySignals JSON
- Test: bash skills/scaffold/scripts/detect-opportunities.sh test/fixtures/nextjs-app → valid JSON

### Task 2: Create opportunity-detector subagent
File: skills/scaffold/agents/opportunity-detector.md
- model: haiku (fast, cheap)
- Reads OpportunitySignals + 3 reference catalogs
- Produces SuggestionManifest JSON (subagents, skills, integrations)

### Task 3: Create 3 new reference catalogs
- skills/scaffold/references/subagent-templates-catalog.md
- skills/scaffold/references/soft-skills-catalog.md  
- skills/scaffold/references/integration-subagents-catalog.md

### Task 4: Create 7 code subagent templates
Directory: skills/scaffold/templates/subagents/
- test-runner.md (model: haiku)
- lint-format.md (model: haiku)
- build-watcher.md (model: haiku)
- commit-assistant.md (model: haiku)
- code-reviewer.md (model: sonnet)
- pr-writer.md (model: sonnet)
- architecture-advisor.md (model: opus)
Each: YAML frontmatter, workflow, rules, {{PLACEHOLDER}} values

### Task 5: Create 4 soft skill templates
Directory: skills/scaffold/templates/skills/
- avoid-ai-slop.md
- devils-advocate.md
- grill-me.md
- think-out-loud.md

### Task 6: Create 6 integration subagent templates
Directory: skills/scaffold/templates/subagents/
- jira-manager.md (model: sonnet)
- confluence-writer.md (model: sonnet)
- slack-notifier.md (model: haiku)
- notion-writer.md (model: sonnet)
- linear-manager.md (model: sonnet)
- github-pr-writer.md (model: sonnet)
Each: references MCP tools, safety rules, {{PLACEHOLDER}} values, never hardcode credentials

### Task 7: Create integration-subagent-gen subagent
File: skills/scaffold/agents/integration-subagent-gen.md
- Generates integration subagent files from templates
- Fills {{PLACEHOLDERS}} with project values
- Writes .mcp.json entries

### Task 8: Modify SKILL.md - Add Interactive Steps
Insert between Step 2 and Step 3:
- Step 2.5: Opportunity Detection (dispatch opportunity-detector, get SuggestionManifest)
- Step 2.7: Interactive Selection (AskUserQuestion x3, build FilteredManifest)
Add flag parsing: --all (skip interaction) and --minimal (CLAUDE.md only)
Modify Step 5 to use FilteredManifest (only generate selected items)
Modify Step 8 Summary to show: detected vs selected, cost estimates, env vars needed

### Task 9: Update analyze.sh
Add to output JSON: integrationSignals, cliTools fields
Detect: JIRA_API_TOKEN, CONFLUENCE_URL, SLACK_BOT_TOKEN, LINEAR_API_KEY, NOTION_API_KEY env vars
Detect: package.json deps for @slack/bolt, @sentry/, @datadog/

### Task 10: Add 4 new eval cases to evals.json
- interactive-subagent-suggestions (haiku model check)
- soft-skill-suggestions (avoid-ai-slop generated)
- integration-detection (detect-opportunities.sh valid JSON)
- minimal-no-subagents (minimal project doesn't over-generate)
Add new assertion types to run-skill-evals.sh:
- frontmatter_field (check model: in YAML frontmatter)
- script_output_valid_json (verify script produces valid JSON)

### Task 11: Update SKILL-minimal.md variant
Suppress subagent/integration suggestions for projects <10 files

### Task 12: Update SKILL-monorepo.md variant  
Add monorepo-specific subagent suggestions (per-package test runner)

### After each task: commit with descriptive message

## Phase 2: Review Cycle 1 (Alignment Check)
After all implementation:

1. Re-read /tmp/cortex-feature-plan.md completely
2. Check EVERY item in the plan is implemented
3. Check EVERY file mentioned exists
4. Check EVERY task description matches what was built
5. Fix anything misaligned or missing
6. Run: bash skills/scaffold/scripts/run-skill-evals.sh
7. Fix any failing evals
8. Commit fixes

## Phase 3: Review Cycle 2 (Quality Deep Dive)
Run through each new file and check:
- All YAML frontmatter is valid
- No unfilled {{PLACEHOLDERS}} remain in templates
- All model assignments are correct (haiku=mechanical, sonnet=creative, opus=architectural)
- All MCP tool references use correct names (mcp__service__tool format)
- Credentials always use ${ENV_VAR} syntax, never hardcoded values
- All detection scripts produce valid JSON
- Interactive prompts are clear and user-friendly
Fix any issues found. Commit.

## Phase 4: Review Cycle 3 (Integration Test)
Test the full interactive scaffold flow on all 3 fixtures:

```bash
# Sync to global install
cp -r skills/scaffold/* ~/.claude/skills/scaffold/

# Test 1: nextjs-app with --all flag (bypass interactive for testing)
cd /Users/lathesh/Documents/workspace/cortex
claude --permission-mode bypassPermissions --print "
Run /scaffold test/fixtures/nextjs-app --all
Save output to /tmp/cortex-test-nextjs.md
Report: files generated, quality score, any errors
"

# Test 2: python-api with --all flag
claude --permission-mode bypassPermissions --print "
Run /scaffold test/fixtures/python-api --all
Save output to /tmp/cortex-test-python.md
Report: files generated, quality score, any errors
"

# Test 3: minimal with --all flag
claude --permission-mode bypassPermissions --print "
Run /scaffold test/fixtures/minimal --all
Save output to /tmp/cortex-test-minimal.md
Report: files generated, quality score, any errors
"
```

Review all 3 outputs. Fix any issues. Commit.

## Phase 5: Autoresearch Loop
After integration tests pass:

```bash
cd /Users/lathesh/Documents/workspace/cortex/claude-code-auto-research
python3 prepare.py
python3 run.py
python3 progress.py
```

If the loop produces improvements (best score > baseline score):
- Apply best version: python3 run.py --apply-best
- Commit the improvement: git commit -m "feat: autoresearch loop improved quality-reviewer"
- Save results summary to /tmp/autoresearch-results.md

## Phase 6: Test on Real Open Source Projects
Test /scaffold on 5 real OSS projects (different languages/frameworks):

```bash
# Project 1: React/TypeScript SaaS starter
claude --permission-mode bypassPermissions --print "
Run scaffold on: https://github.com/shadcn-ui/ui
Use --all flag. Save full report to /tmp/oss-test-1-shadcn.md"

# Project 2: Python FastAPI project
claude --permission-mode bypassPermissions --print "
Run scaffold on: https://github.com/fastapi/fastapi
Use --all flag. Save full report to /tmp/oss-test-2-fastapi.md"

# Project 3: Go project
claude --permission-mode bypassPermissions --print "
Run scaffold on: https://github.com/charmbracelet/bubbletea
Use --all flag. Save full report to /tmp/oss-test-3-bubbletea.md"

# Project 4: Node.js library
claude --permission-mode bypassPermissions --print "
Run scaffold on: https://github.com/expressjs/express
Use --all flag. Save full report to /tmp/oss-test-4-express.md"

# Project 5: Full-stack app with many integrations (look for one with Jira/Slack in README)
claude --permission-mode bypassPermissions --print "
Run scaffold on: https://github.com/calcom/cal.com
Use --all flag. Save full report to /tmp/oss-test-5-calcom.md"
```

For each: analyze the report, identify failures, fix in cortex codebase, commit.

## Phase 7: Multi-Agent Independent Review
Use BOTH Cursor Agent AND Codex for independent review — two different AI systems catch different things.

### Review 7A: Cursor Agent (deep code analysis)
```bash
cd /Users/lathesh/Documents/workspace/cortex
cursor agent --print "
You are doing a thorough code review of the Cortex project — a Claude Code plugin.

Review ALL new files created in this session for:
1. Bugs in shell scripts (syntax errors, missing quotes, edge cases in detect-opportunities.sh)
2. YAML frontmatter validity in all new .md agent/skill files
3. Unfilled {{PLACEHOLDER}} values anywhere in templates
4. Incorrect model assignments (haiku should only be for mechanical tasks)
5. MCP tool name format errors (must be mcp__service__tool)
6. Security: hardcoded credentials, path traversal in file operations
7. Logic errors in the interactive selection parsing in SKILL.md
8. Missing --all/--minimal flag handling edge cases
9. Integration catalog entries that reference non-existent MCP servers
10. Inconsistencies between the plan (/tmp/cortex-feature-plan.md) and what was actually built

For each issue: file, line number, severity (critical/high/medium), description, fix.
Save findings to /tmp/cursor-review-findings.md
Fix all critical and high severity issues.
Commit: git commit -m 'fix: cursor review fixes'
" 2>&1
```

### Review 7B: Codex (shell script + security focus)
```bash
cd /Users/lathesh/Documents/workspace/cortex
codex exec --full-auto "
Review the Cortex project focusing on:
1. Shell script correctness (detect-opportunities.sh, analyze.sh, run-skill-evals.sh)
2. Python correctness (claude-code-auto-research/run.py, measure.py)
3. Command injection vulnerabilities in shell scripts
4. Unquoted variables that could break with spaces in paths
5. Missing error handling (what happens if git commands fail?)
6. Template {{PLACEHOLDER}} values that don't get filled during generation

Save findings to /tmp/codex-review-findings.md
Fix all critical issues.
Commit: git commit -m 'fix: codex review fixes'
"
```

## Phase 8: Final Gap Analysis + Polish
Based on all reviews, do a final pass:

1. Read all test reports (/tmp/oss-test-*.md, /tmp/cortex-test-*.md)
2. Read Codex findings (/tmp/codex-review-findings.md)
3. Identify top 10 issues by severity
4. Fix all critical issues
5. Add any missing templates or catalog entries discovered during testing
6. Update README.md to document the new interactive features:
   - New interactive scaffold mode
   - Subagent model routing
   - Soft skills catalog
   - Integration detection and subagents
   - --all and --minimal flags
7. Run final eval suite: bash skills/scaffold/scripts/run-skill-evals.sh
8. All evals must pass before final commit

## Phase 9: Final Sync + Notification
```bash
# Sync final version to global install
cp -r skills/scaffold/* ~/.claude/skills/scaffold/

# Final commit
git add -A
git commit -m "feat: complete interactive scaffold with smart suggestions (phases 1-4)"

# Create summary report
cat > /tmp/overnight-summary.md << 'EOF'
# Overnight Build Summary

## What Was Built
[Auto-fill with actual files created]

## Test Results  
[Auto-fill from test reports]

## Autoresearch Results
[Auto-fill from autoresearch run]

## OSS Test Results
[Auto-fill from OSS tests]

## Issues Found and Fixed
[Auto-fill from Codex review]

## Remaining Known Issues
[Auto-fill if any remain]
EOF

# Notify Lathesh
openclaw system event --text "Done: Cortex overnight build complete. Interactive scaffold + autoresearch + OSS tests + Codex review all finished. Check /tmp/overnight-summary.md for full results." --mode now
```

## Error Handling
- If any phase fails, document the failure in /tmp/overnight-errors.md and continue to next phase
- Never stop the whole pipeline for a single failure
- If evals fail, fix and re-run before moving to next phase
- If autoresearch produces no improvement, skip --apply-best and continue

## Success Criteria
- [ ] All 22 new files created
- [ ] All 5 modified files updated  
- [ ] All existing evals still pass
- [ ] 4 new evals pass
- [ ] Autoresearch loop ran (with or without improvement)
- [ ] All 5 OSS projects scaffolded without errors
- [ ] Codex review complete
- [ ] README updated
- [ ] Final notification sent
