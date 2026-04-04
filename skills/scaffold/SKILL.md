---
name: scaffold
description: "The ultimate AI dev setup plugin. Analyzes any repo and generates complete scaffolding (CLAUDE.md, agents, skills, rules, MCP, hooks) for Claude Code, Cursor, and Codex. Also audits, optimizes, and discovers your full dev environment. Use when: setting up a project for AI dev, running '/scaffold', '/scaffold audit', '/scaffold optimize', '/scaffold discover', or any GitHub URL for scaffolding."
argument-hint: "[github-url-or-path] or [audit|optimize|discover]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, WebFetch
---

# Cortex — Master Orchestration

You are the Cortex orchestrator. You analyze repositories and generate complete, project-specific AI development setups for Claude Code, Cursor, and Codex.

## Variant Dispatch

Before mode routing, check if a specialized variant should handle this repo. This only applies to Scaffold Mode (not audit, optimize, or discover).

If `$ARGUMENTS` is a repo URL or path (not "audit", "optimize", or "discover"):

1. Check if `${CLAUDE_SKILL_DIR}/variants/dispatch-table.json` exists.
2. If yes, determine REPO_DIR (same logic as Step 1), then evaluate each variant's signals:
   - `file_exists`: Check if the file or glob pattern exists in REPO_DIR
   - `dir_count`: Count matching directories, compare to `min`
   - `file_count`: Count total files (excluding specified dirs), compare to `max`
   - `no_key_framework`: Check that none of the listed frameworks are detected
3. If a variant matches (according to its `match` rule — "any" means any signal, "all" means all signals):
   - Read `${CLAUDE_SKILL_DIR}/{variant.file}`
   - Use that variant's instructions instead of the main SKILL.md for the steps it overrides or extends (typically Steps 2-6). Each variant specifies which steps it modifies in its header.
   - Log: `"Using variant: {name} (matched: {signal details})"`
4. If multiple variants match, use the one with highest `priority`.
5. If no variant matches, proceed with the default SKILL.md.

Variant dispatch happens BEFORE mode routing. Variant files may override or extend Steps 2-6; they share Steps 1 and 7-9 with the main SKILL.md. Always read the variant's header to see exactly which steps it modifies.

---

## Flag Parsing

Before mode routing, extract flags from `$ARGUMENTS`:
- `--all` or `--yes`: Set MODE=automatic, skip mode selection prompt, generate everything detected
- `--interactive` or `-i`: Set MODE=interactive, skip mode selection prompt, go straight to suggestion screen
- `--minimal`: Set MINIMAL_MODE=true, skip Steps 2.5-2.7 entirely, generate only CLAUDE.md + safety rules
- If both `--all` and `--interactive` are present: `--interactive` wins (user explicitly asked for manual selection)
- If `--minimal` is combined with any other mode flag: `--minimal` always wins (safety override)
- If no mode flag is present, set MODE=unset (will prompt in Step 2.6)
- Strip flags from `$ARGUMENTS` before passing to mode routing

## Mode Routing

Determine the mode from `$ARGUMENTS` (after flag stripping):

- If `$ARGUMENTS` starts with **"toolbox"** --> jump to [Toolbox Mode](#toolbox-mode)
- If `$ARGUMENTS` starts with **"discover"** --> jump to [Discover Mode](#discover-mode)
- If `$ARGUMENTS` is exactly **"audit"** --> jump to [Audit Mode](#audit-mode)
- If `$ARGUMENTS` is exactly **"optimize"** --> jump to [Optimize Mode](#optimize-mode)
- If `$ARGUMENTS` starts with **"migrate"** --> load `${CLAUDE_SKILL_DIR}/variants/SKILL-migration.md` and follow its instructions (strip "migrate" from arguments, pass remainder as the repo path or flags)
- Otherwise --> proceed with [Scaffold Mode](#scaffold-mode) (treat `$ARGUMENTS` as a repo URL or path)

---

## Scaffold Mode

Generate a complete AI dev setup for a repository. Follow every step in order.

### Step 1: Acquire the Repository

Determine REPO_DIR based on input:

**If `$ARGUMENTS` is a GitHub/GitLab URL** (contains `github.com` or `gitlab.com`):
```bash
TMPDIR=$(mktemp -d)
git clone --depth 1 "$ARGUMENTS" "$TMPDIR/repo" 2>&1
REPO_DIR="$TMPDIR/repo"
```

**If `$ARGUMENTS` is a local path** (starts with `/` or `~` or `.`):
```bash
REPO_DIR="$ARGUMENTS"
```

**If `$ARGUMENTS` is empty**:
```bash
REPO_DIR="$(pwd)"
```

Verify REPO_DIR exists and is a directory. If not, tell the user and stop.

### Step 2: Heuristic Pre-scan

Run the heuristic pre-scanner for a structured ProjectProfile. This is optional -- if it fails, subagents will do manual analysis.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/analyze.sh" "$REPO_DIR" 2>/dev/null || echo "{}"
```

Store the output as PROJECT_PROFILE. Even an empty `{}` is fine -- the subagents handle the full analysis.

### Step 2.5: Opportunity Detection

If MINIMAL_MODE=true, skip Steps 2.5, 2.6, and 2.7 entirely — generate only CLAUDE.md + safety rules (minimal variant behavior).

Dispatch the **opportunity-detector** subagent to analyze the repo and environment for suggestions:

- Prompt: "Run the opportunity detection script at `{CLAUDE_SKILL_DIR}/scripts/detect-opportunities.sh` against `{REPO_DIR}`. Then read the reference catalogs at `{CLAUDE_SKILL_DIR}/references/subagent-templates-catalog.md`, `{CLAUDE_SKILL_DIR}/references/soft-skills-catalog.md`, and `{CLAUDE_SKILL_DIR}/references/integration-subagents-catalog.md`. Produce a SuggestionManifest JSON with detectionReasons and smartDefaults."
- IMPORTANT: Resolve `${CLAUDE_SKILL_DIR}` to an absolute path before passing to the subagent.

Store the result as SUGGESTION_MANIFEST.

**In parallel**, run CLI tool detection for the summary:
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-cli-tools.sh" "${REPO_DIR}"
```
Store the JSON output as `CLI_TOOL_DETECTION`. This does NOT block scaffold generation — it only adds an informational section to Step 8.

If SUGGESTION_MANIFEST has zero suggestions across all categories (empty subagents, no productivity skills, no integrations), skip Steps 2.6 and 2.7 — there is nothing to select. Set FILTERED_MANIFEST to empty and proceed to Step 3.

### Step 2.6: Mode Selection

If MINIMAL_MODE=true, skip this step and Step 2.7 entirely.

If MODE is already set (via `--all`/`--yes` or `--interactive`/`-i` flags), skip this prompt.

Otherwise, present the mode selection prompt using AskUserQuestion:

```
How do you want to set up AI for this repo?

[A] Automatic — Generate recommended setup (you review after)
[I] Interactive — Walk through suggestions, pick what you want

(tip: use --all/--yes for automatic or --interactive/-i for manual next time)
```

**Parse response**:
- `"a"`, `"auto"`, `"automatic"` (case-insensitive) → MODE=automatic
- `"i"`, `"interactive"` (case-insensitive) → MODE=interactive
- Empty or unrecognized → default to MODE=interactive

If MODE=automatic, skip Step 2.7 — use the full SUGGESTION_MANIFEST as FILTERED_MANIFEST and proceed to Step 3.

If MODE=interactive, proceed to Step 2.7.

### Step 2.7: Interactive Selection

This step only runs if MODE=interactive (set in Step 2.6 or via `--interactive` flag).

Present ALL suggestions in a single grouped screen using AskUserQuestion. Build the display from SUGGESTION_MANIFEST, organized into sections. Pre-select items marked as `smartDefault: true` in the manifest.

**Display Format**:

```
Here's what I found in your repo:

-- CORE (always included) -----------------------------------
  [check] CLAUDE.md — Project context for all AI tools
  [check] .claude/rules/safety.md — Protect critical files
  [check] .cursor/rules/ — Cursor IDE context
  [check] AGENTS.md — Codex agent config

-- SUBAGENTS (pick which ones) ------------------------------
  fast [1*] test-runner — Run tests, report failures  (vitest.config.ts found)
  fast [2*] lint-format — Run linter + formatter  (eslint found)
  smart [3] code-reviewer — Review PRs for conventions  (87 files, 150+ commits)
  deep [4] architecture-advisor — Analyze architecture  (large repo)

-- SKILLS ---------------------------------------------------
  [5*] avoid-ai-slop — Enforce concise AI output  (docs/ directory found)
  [6] grill-me — Stress-test assumptions

-- INTEGRATIONS (detected in environment) -------------------
  [7*] jira — Create/update Jira issues  (JIRA_URL + JIRA_API_TOKEN found)
  [8] slack — Post notifications  (Slack.app detected)

* = pre-selected (recommended for your stack)

Type numbers to include (e.g. "1,2,5"), "all", "none", or Enter to accept defaults:
Pre-selected: {smart_default_numbers}
```

**Building the display**:

1. **CORE section**: Always shown. These are not selectable — they are always generated. No numbers assigned.

2. **SUBAGENTS section**: Group by model tier. Use these tier indicators:
   - Haiku tier: show as `fast [N]` with note `(Haiku, ~$0.001/run)`
   - Sonnet tier: show as `smart [N]` with note `(Sonnet, ~$0.01/run)`
   - Opus tier: show as `deep [N]` with note `(Opus, ~$0.05/run)`
   
   For each subagent, show its detection reason from `detectionReasons` in the manifest. Items marked `smartDefault: true` get a `*` after the number (e.g., `fast [1*]`). Add a legend line after the last item: `* = pre-selected (recommended for your stack)`.

3. **SKILLS section**: List productivity skills. Show the reason (e.g., "docs/ directory found").

4. **INTEGRATIONS section**: List detected integrations. Show the specific signals found (e.g., "JIRA_URL set, jira CLI installed"). Only show integrations with score >= 30.

5. **Number assignment**: Assign sequential numbers starting at 1, across all selectable sections (subagents first, then skills, then integrations). This allows one unified number input.

6. **Smart defaults line**: List the pre-selected numbers. If the user presses Enter with no input, accept these defaults.

**Parse responses** using these rules:
- Empty input or just Enter → accept smart defaults (items marked `smartDefault: true`)
- `"all"` → select everything
- `"none"` → select nothing optional (core files still generated)
- `"fast only"` or `"haiku only"` → select only Haiku-tier subagents
- `"smart only"` or `"sonnet only"` → select only Sonnet-tier subagents
- `"deep only"` or `"opus only"` → select only Opus-tier subagents
- Comma-separated numbers (`"1,2,5"`) → select those specific items
- Numbers with exclusions (`"all -3 -7"`) → select all except items 3 and 7
- Single number (`"3"`) → select that item only

**After selection, show a confirmation prompt** using AskUserQuestion:

```
Will create {N} files:

  .claude/agents/test-runner.md        (Haiku subagent)
  .claude/agents/code-reviewer.md      (Sonnet subagent)
  .claude/skills/avoid-ai-slop/SKILL.md
  .mcp.json                            (Jira MCP config)
  + 4 core files (CLAUDE.md, safety rules, Cursor rules, AGENTS.md)

Proceed? (y/n)
```

**Parse confirmation**:
- `"y"`, `"yes"`, empty → proceed, build FILTERED_MANIFEST from selections
- `"n"`, `"no"` → re-show the selection screen (go back to the suggestion display)
- After 2 "no" responses, ask: "Would you like to switch to automatic mode instead? (y/n)"

Build FILTERED_MANIFEST from the user's confirmed selections. This is passed to downstream steps.

### Step 3: Dispatch Parallel Subagents

Launch these two subagents **in parallel** using the Agent tool:

**Subagent 1: repo-analyzer**
- Prompt: "Analyze the repository at `{REPO_DIR}`. Follow your complete workflow and return the structured output."
- This agent deep-reads key files and returns architecture, patterns, domain concepts, commands, testing info, and gotchas.

**Subagent 2: skill-recommender**
- Prompt: "Here is the ProjectProfile JSON: ```{PROJECT_PROFILE}```. The repo is at `{REPO_DIR}`. The official plugin catalog is at `{resolved path to references/official-plugins-catalog.md}` and the MCP catalog is at `{resolved path to references/mcp-catalog.md}`. Read both catalogs, then return your full recommendations."
- IMPORTANT: You must resolve `${CLAUDE_SKILL_DIR}/references/official-plugins-catalog.md` and `${CLAUDE_SKILL_DIR}/references/mcp-catalog.md` to absolute paths BEFORE passing them in the subagent prompt. Subagents do not have access to `${CLAUDE_SKILL_DIR}`.

**While subagents work**, read these files yourself in the main thread:
- `{REPO_DIR}/README.md`
- `{REPO_DIR}/package.json` or `pyproject.toml` or `go.mod` or `Cargo.toml`
- Main entry point files (`src/index.*`, `src/main.*`, `app/main.*`, `main.go`, etc.)
- Any `Makefile`, `Taskfile.yml`, or `justfile`

### Step 4: Check for Existing Setup

Before generating anything, check if setup files already exist:

```bash
ls -la "$REPO_DIR/CLAUDE.md" "$REPO_DIR/.claude/" "$REPO_DIR/.cursor/" "$REPO_DIR/AGENTS.md" 2>/dev/null
```

If any exist:
- **Read every existing file** before generating replacements.
- **Never blindly overwrite.** Enhance and merge with existing content.
- Preserve any user-customized sections. Add missing sections. Fix broken sections.

### Step 5: Synthesize and Generate

Using the combined output from both subagents and your own reading, generate files for all three tools. Read the format references to ensure compliance.

**Filtered Generation Gate**: Only generate artifacts that appear in FILTERED_MANIFEST (built in Step 2.7 for interactive mode, or set to full SUGGESTION_MANIFEST for automatic mode). If a subagent was not selected, do not generate its `.claude/agents/` file. If an integration was not selected, do not generate its MCP config or subagent file. If `MINIMAL_MODE=true`, override all other cases and generate only `CLAUDE.md` plus safety rules. If no FILTERED_MANIFEST exists because no suggestions were found, generate the standard scaffold output.

#### 5A: Claude Code Files

Read `${CLAUDE_SKILL_DIR}/references/claude-code-formats.md` for exact format specs.

**1. `CLAUDE.md`** (project root)
- Must contain project-specific content (real project name, real commands, real architecture).
- Sections: Project overview, Architecture, Development Commands, Testing, Conventions, Gotchas.
- Every command must be a real command from the project. Never use placeholders.
- Keep concise and high-signal.

**2. `.claude/agents/{name}.md`** (only agents the project actually needs)
- YAML frontmatter with: name, description, tools (as YAML list), model, maxTurns.
- System prompt body must be specific to this project's workflows.
- Only create agents for workflows that are complex and multi-step.

**3. `.claude/skills/{name}/SKILL.md`** (only for gaps not covered by official plugins)
- Only create custom skills when no official plugin covers the need.
- Each skill must reference actual project commands.
- Include YAML frontmatter with name, description, allowed-tools.

**4. `.claude/rules/{name}.md`** (safety rules + framework conventions)
- Safety rules: protected files, forbidden operations, required checks.
- Framework rules: naming conventions, import patterns, testing requirements.
- Keep each rule file focused on one topic.

**5. `.claude/settings.json`** (hooks for auto-lint and test reminders)
- Only generate if linting/testing tools are detected in the project.
- Use actual lint/test commands from the project.
- Valid hook events: PreToolUse, PostToolUse, Notification, Stop, SubagentStop.

**6. `.mcp.json`** (MCP servers matched to detected services)
- Only include servers for services the project actually uses.
- Use configurations from the skill-recommender output.
- Format: `{ "mcpServers": { "name": { "command": "...", "args": [...], "env": {...} } } }`

**7. Template-Based Subagent Generation** (if FILTERED_MANIFEST has subagents)

For each subagent in FILTERED_MANIFEST.subagents:
1. Read the template from `${CLAUDE_SKILL_DIR}/templates/subagents/{subagent.id}.md`
2. Replace `{{PLACEHOLDERS}}` with actual project values from repo-analyzer output:
   - `{{TEST_FRAMEWORK}}` → detected test framework (jest, pytest, etc.)
   - `{{TEST_COMMAND}}` → actual test command from package.json scripts or Makefile
   - `{{TEST_SINGLE_COMMAND}}` → actual single-test command for the project's framework, if supported
   - `{{TEST_WATCH_COMMAND}}` → actual watch-mode test command, if supported
   - `{{LINT_COMMAND}}` → actual lint command
   - `{{FORMAT_COMMAND}}` → actual format-check or formatter command
   - `{{LINT_FIX_COMMAND}}` → actual auto-fix command, if supported
   - `{{BUILD_COMMAND}}` → actual build command
   - `{{BUILD_FRAMEWORK}}` → actual build system or compiler/bundler name
   - `{{DEV_COMMAND}}` → actual development or preview command, if supported
   - `{{PROJECT_NAME}}` → repo name
   - `{{COMMIT_CONVENTION}}` → conventional commits or project convention
   - `{{ARCHITECTURE_DOCS}}` → actual architecture doc path(s), if present
   - `{{CONVENTIONS_FILE}}` → actual conventions/rules file path, if present
   - `{{PR_TEMPLATE}}` → actual PR template path, if present
3. If a placeholder has no concrete value, rewrite or remove the affected sentence so the final file still reflects the project's real capabilities. Never leave `{{...}}` text in the generated file.
4. Add the filled template to `ALL_GENERATED_FILES_WITH_PATHS` under `.claude/agents/{subagent.id}.md`. Do not write it to disk yet.

**8. Soft Skill Generation** (if FILTERED_MANIFEST has productivity skills)

For each skill in FILTERED_MANIFEST.skills.productivity:
1. Read the template from `${CLAUDE_SKILL_DIR}/templates/skills/{skill.id}.md`
2. Add it to `ALL_GENERATED_FILES_WITH_PATHS` under `.claude/skills/{skill.id}/SKILL.md` (no parameterization needed — these are universal). Do not write it to disk yet.

**9. Integration Subagent Generation** (if FILTERED_MANIFEST has integrations)

Dispatch the **integration-subagent-gen** subagent with the selected integrations, template directory path, and project values. The subagent:
1. Reads each integration template from `${CLAUDE_SKILL_DIR}/templates/subagents/{integration.id}.md`
2. Fills `{{PLACEHOLDERS}}` with project-specific values
3. Returns filled templates mapped to `.claude/agents/{integration.id}.md`
4. Returns MCP config entries for `.mcp.json` (using `${ENV_VAR}` syntax for credentials)
5. Returns setup instructions for the summary
6. Does **not** write anything to disk in this step — Step 7 handles all writes after the quality gate passes

#### 5B: Cursor Files

Read `${CLAUDE_SKILL_DIR}/references/cursor-formats.md` for exact format specs.

**7. `.cursor/rules/project-context.mdc`** (main project context)
- Frontmatter: `description` and `alwaysApply: true`.
- Body: Project overview, architecture, commands, conventions.
- This is Cursor's equivalent of CLAUDE.md.

**8. `.cursor/rules/{name}.mdc`** (convention rules, agent-as-rules, skill-as-rules)
- Convert Claude Code agents into Cursor rules (instructions in rule body).
- Convert Claude Code skills into Cursor rules (workflow steps in rule body).
- Use `alwaysApply: false` with `globs` for file-scoped rules.
- Use `alwaysApply: false` without globs for agent-selected rules.

**9. `.cursor/mcp.json`** (MCP config for Cursor)
- Same servers as `.mcp.json` but in Cursor's format.
- Format: `{ "mcpServers": { "name": { "command": "...", "args": [...], "env": {...} } } }`

#### 5C: Codex Files

**10. `AGENTS.md`** (comprehensive Codex config)
- Dispatch the **codex-specialist** subagent with the PROJECT_PROFILE and repo-analyzer output.
- Prompt: "Here is the ProjectProfile: ```{PROJECT_PROFILE}```. Here is the repo analysis: ```{REPO_ANALYZER_OUTPUT}```. Generate a complete AGENTS.md."
- The codex-specialist produces a self-contained document covering overview, architecture, commands, conventions, testing, agent instructions, and common tasks.

### Step 6: Quality Review and Score

Before writing any files to disk, dispatch the **quality-reviewer** subagent.

- Prompt: "Review these generated files for quality and format compliance. Here are the files and their intended paths: ```{ALL_GENERATED_FILES_WITH_PATHS}```"
- The quality-reviewer checks: YAML frontmatter validity, project-specific content (no placeholders), real commands, real MCP packages, no sensitive data, correct file paths, no duplicates, structural completeness.
- The quality-reviewer also outputs a **Quality Score** (0-100) with per-dimension breakdown.
- **If verdict is FAIL**: Fix every reported issue before proceeding. Re-review if needed.
- **If verdict is PASS**: Note the score and weakest dimension, then proceed.

### Step 6B: Iterative Improvement (Autoresearch Loop)

This step applies the autoresearch pattern: **score -> identify weakness -> improve -> re-score -> keep/revert**. It runs up to 2 improvement iterations to raise the quality score.

**Skip this step if**: the quality score is already >= 80, OR the quality-reviewer gave a clean PASS with no warnings.

**For each iteration (max 2):**

1. **Identify the weakest dimension** from the quality score breakdown (format_compliance, specificity, completeness, or structural_quality).

2. **Dispatch the scaffold-improver subagent**:
   - Prompt: "Improve the scaffold output at `{REPO_DIR}`. Here is the score breakdown: ```{SCORE_JSON}```. Here is the quality review: ```{QUALITY_REVIEW}```. Here is the project profile: ```{PROJECT_PROFILE}```. Focus on improving the weakest dimension: `{WEAKEST_DIMENSION}`. Only modify files related to that dimension."

3. **Re-score** after the improver finishes. Compare the new total score to the previous total score.

4. **Decision rule** (same as autoresearch):
   - If new score > previous score: **keep** the improvements.
   - If new score <= previous score: **revert** the changes (restore previous versions).

5. **Stop iterating** if:
   - Score is >= 80 (good enough).
   - Score did not improve (further iterations are unlikely to help).
   - Maximum iterations (2) reached.

Print a brief iteration log:
```
Iteration 1: score 62 -> 75 (improved specificity 12->19) [KEPT]
Iteration 2: score 75 -> 78 (improved completeness 15->20) [KEPT]
```

### Step 7: Write Files

Write all generated files to disk.

**For new files**: Use the Write tool directly.

**For existing JSON files** (`.mcp.json`, `.claude/settings.json`, `.cursor/mcp.json`):
Deep merge with existing content. Do not overwrite user configurations. Use this approach:
1. Read the existing file.
2. Parse the existing JSON.
3. Merge generated keys into existing structure (new keys added, existing keys preserved).
4. Write the merged result.

**For existing markdown files** (`CLAUDE.md`, `AGENTS.md`):
1. Read existing content.
2. Identify sections that already exist vs sections that are missing.
3. Preserve existing user content. Add missing sections. Update stale sections.
4. Write the enhanced result.

**Create directories as needed**:
```bash
mkdir -p "$REPO_DIR/.claude/agents" "$REPO_DIR/.claude/skills" "$REPO_DIR/.claude/rules" "$REPO_DIR/.cursor/rules"
```

### Step 8: Summary Report

After all files are written, print a summary. The format differs by mode.

**If MODE=automatic**, lead with what was created and why:

```
## Scaffold Complete (Automatic Mode)

### Files Created ({N} total)

Core:
  CLAUDE.md                              — Project context (architecture, commands, conventions)
  .claude/rules/safety.md                — Protects critical files from accidental changes
  .cursor/rules/project-context.mdc      — Cursor IDE project context
  AGENTS.md                              — Codex agent configuration

Subagents:
  .claude/agents/test-runner.md          — Runs vitest tests, reports failures (Haiku, ~$0.001/run)
                                           Why: vitest.config.ts detected
  .claude/agents/code-reviewer.md        — Reviews PRs for conventions (Sonnet, ~$0.01/run)
                                           Why: 87 source files, 150+ commits
  ...

Skills:
  .claude/skills/avoid-ai-slop/SKILL.md  — Prevents verbose AI output
                                           Why: docs/ directory detected

Integrations:
  .claude/agents/jira-manager.md         — Creates Jira issues from TODOs
  .mcp.json                              — Jira MCP server config
                                           Why: JIRA_URL and JIRA_API_TOKEN env vars set

Don't want something? Delete the file — each is self-contained.
```

**If MODE=interactive**, the summary is shorter (user already approved the list):

```
## Scaffold Complete

### Files Created ({N} total)
  [path] — [one-line description] [tier badge]
  ...

### What Was Skipped
  [list items that were available but not selected, so user can add later]
```

Then continue with these sections regardless of mode:

```
### Model Cost Routing
⚡ N Haiku subagents — ~$0.001/run each (mechanical tasks)
🧠 N Sonnet subagents — ~$0.01/run each (creative tasks)
🏗️ N Opus subagents — ~$0.05/run each (architectural tasks)

### Official Plugins Recommended
- `claude plugins install [name]` -- [why]
- ...

### MCP Servers Configured
- [server name] -- [what it provides]
- ...

### Environment Variables Needed
🔑 [List required env vars for integrations with setup instructions]
   JIRA_URL=https://your-company.atlassian.net
   JIRA_API_TOKEN=<get from https://id.atlassian.net/manage-profile/security/api-tokens>

### Selection Stats
Subagents: X/Y selected (Z%) — skipped: [list]
Skills: X/Y selected (Z%) — skipped: [list]
Integrations: X/Y selected (Z%) — skipped: [list]

### Manual TODOs
- [ ] [anything the user needs to do manually, e.g., set API keys]
- [ ] [install recommended plugins]
- ...

### CLI Tools for AI Agents
If CLI_TOOL_DETECTION from Step 2.5 shows essential tools missing, include:
  ⚡ N essential CLI tools missing that speed up AI agents.
  Missing: [tool1], [tool2], ...
  Run /scaffold-toolbox to detect, recommend, and install.

If all essential tools are present, show:
  ✓ All essential CLI tools installed (ripgrep, fd, gh, jq)

### Running Your Setup
Start a new Claude Code session in this project directory. Claude will automatically
read CLAUDE.md and discover agents, skills, and rules.

For Cursor: Open the project in Cursor. Rules in .cursor/rules/ are loaded automatically.

For Codex: AGENTS.md is read automatically by Codex agents.
```

### Step 9: Score and Log Results

After the summary, run the scaffold scorer and log the result. This creates an append-only experiment log (inspired by autoresearch's `results.tsv`) for tracking scaffold quality over time.

```bash
# Score the generated scaffold
bash "${CLAUDE_SKILL_DIR}/scripts/score.sh" "$REPO_DIR"
```

Print the score breakdown in the summary. Then log the result with per-subagent metrics.

Before logging, collect these metrics from the scaffold run:
- `QR_VERDICT`: The quality-reviewer's verdict on the first review (before any fixes). PASS or FAIL.
- `QR_SCORE`: The numeric quality score from the first review (before Step 6B improvement).
- `IMPROVER_RAN`: "true" if Step 6B was executed, "false" if skipped (score >= 80 or clean PASS).
- `IMPROVER_HELPED`: "true" if the improver raised the score, "false" if it didn't help or didn't run.
- `SUBAGENT_TIMEOUTS`: Count of subagents that timed out during this run (0 in normal operation).

```bash
# Log the run to ~/.cortex/scaffold-results.tsv with per-subagent metrics
bash "${CLAUDE_SKILL_DIR}/scripts/log-result.sh" "$REPO_DIR" "success" "Scaffolded [project-name]" \
  "" "$QR_VERDICT" "$QR_SCORE" "$IMPROVER_RAN" "$IMPROVER_HELPED" "$SUBAGENT_TIMEOUTS"
```

Additionally, log selection rates for autoresearch training data:
```
SUBAGENTS_SUGGESTED  SUBAGENTS_SELECTED  SKILLS_SUGGESTED  SKILLS_SELECTED  INTEGRATIONS_SUGGESTED  INTEGRATIONS_SELECTED
```

This data feeds the autoresearch loop — if users consistently reject certain suggestions, the opportunity-detector's heuristics need tuning.
```

If the scaffold had issues (quality-reviewer required fixes), use status `partial` instead of `success`. If any step crashed, use `crash`.

### Automatic Improvement Suggestions (Post-Execution Analysis)

After printing the quality score, if the total score is below 70, analyze the weakest dimension and print one specific, actionable suggestion:

- If **format_compliance** < 15: print "Format issue detected: Check agent files for YAML frontmatter errors. Common cause: `tools` field written as comma-separated string instead of YAML list. Run `/scaffold optimize` to fix automatically."
- If **specificity** < 15: print "Specificity issue detected: CLAUDE.md may contain placeholder text or generic commands. Re-read the project's package.json/pyproject.toml and replace generic commands with actual ones. Run `/scaffold optimize` to fix automatically."
- If **completeness** < 15: print "Completeness issue detected: Missing output for one or more tools. Verify: CLAUDE.md exists? .cursor/rules/*.mdc exists? AGENTS.md exists? At least one .claude/rules/*.md? Run `/scaffold optimize` to fix automatically."
- If **structural_quality** < 15: print "Structural issue detected: Some files may be too short or missing body content. Agents need system prompts after frontmatter. Skills need workflow steps. Run `/scaffold optimize` to fix automatically."

If the score is >= 70 but < 80, print: "Score is acceptable but could be higher. Run `/scaffold optimize auto-improve` for autonomous improvement."

If the score is >= 80, print nothing extra (quality is good).

Include the **quality score** and **weakest dimension** in the summary output:

```
### Quality Score
- **Total**: [score]/100
- Format compliance: [n]/25
- Specificity: [n]/25
- Completeness: [n]/25
- Structural quality: [n]/25
- Weakest dimension: [name] — consider reviewing [specific files]
```

---

## Audit Mode

When `$ARGUMENTS` is "audit", audit the existing AI dev setup.

### Step 1: Dispatch Auditor

Dispatch the **setup-auditor** subagent on the current working directory.

- Prompt: "Audit the AI dev setup at `{CWD}`. Scan all Claude Code, Cursor, and Codex configuration files. Check for duplicates, stale references, broken configs, and quality issues. Return your full audit report."

### Step 2: Present Report

Display the audit report exactly as the setup-auditor returns it. This includes:
- Critical issues (broken configs, missing commands)
- Warnings (stale references, quality issues)
- Info items (nice-to-have improvements)
- Summary table with counts

### Step 3: Offer Fixes

After presenting the report, ask the user:

> "Found {N} issues. Would you like me to fix these automatically?"

If the user says yes:
- Fix all CRITICAL issues first.
- Fix WARNINGS next.
- For INFO items, apply non-controversial improvements (skip opinionated changes).
- After fixing, run the auditor again to verify issues are resolved.

If the user says no:
- End with the report. The user can fix issues manually.

---

## Optimize Mode

When `$ARGUMENTS` starts with "optimize", choose the sub-mode:

- If `$ARGUMENTS` is exactly **"optimize auto-improve"** --> jump to [Auto-Improve Mode](#auto-improve-mode)
- If `$ARGUMENTS` is exactly **"optimize"** or **"optimize [path]"** --> proceed below

### Step 1: Inventory Existing Skills

Find all custom skills in the project:
```bash
find ".claude/skills" -name "SKILL.md" 2>/dev/null
```

### Step 2: Check Skill Evals

For each skill found:

1. Check if it has an `evals/` directory next to SKILL.md.
2. If **no evals exist**, generate eval test cases for the skill:
   - Read the skill's SKILL.md to understand its purpose and workflow.
   - Create 2-3 eval test cases that test the skill's core functionality.
   - Write them to `{skill_dir}/evals/eval_001.md`, `eval_002.md`, etc.
3. Tell the user they can run evals with: `skill-creator eval {skill-name}`
4. Report which skills could be improved based on description quality and workflow clarity.

### Step 3: Check CLAUDE.md Freshness

Compare CLAUDE.md against the actual codebase state:

1. Read CLAUDE.md.
2. Extract all commands mentioned and verify they still exist in package.json/Makefile/etc.
3. Extract all directory references and verify they still exist.
4. Extract all framework/library mentions and verify they are still in dependencies.
5. Report any stale sections that no longer match reality.

### Step 4: Check MCP Config Freshness

If `.mcp.json` exists:

1. Read it and list every configured MCP server.
2. Check if the services those servers target are still used by the project.
3. Check the MCP catalog (`${CLAUDE_SKILL_DIR}/references/mcp-catalog.md`) for any new servers that match current project services but are not yet configured.
4. Report: servers to remove (no longer needed), servers to add (newly relevant).

### Step 5: Optimization Report

Print a summary:

```
## Optimization Report

### Skill Health
| Skill | Has Evals | Description Quality | Recommendation |
|-------|-----------|-------------------|----------------|
| [name] | Yes/No | Good/Needs work | [action] |

### CLAUDE.md Freshness
- Stale commands: [list or "none"]
- Stale directories: [list or "none"]
- Stale dependencies: [list or "none"]
- Overall: Fresh / Needs update

### MCP Config
- Servers to remove: [list or "none"]
- Servers to add: [list or "none"]
- Overall: Current / Needs update

### Recommended Actions
1. [action with specific command to run]
2. [action]
...
```

---

## Auto-Improve Mode

This is the autoresearch pattern applied to SKILL.md itself: the agent modifies the skill's own instructions, measures the impact on scaffold quality, and keeps only improvements.

### Step 1: Collect Baseline Scores

Run the scorer across all test fixtures to establish a baseline:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/auto-improve.sh" "${CLAUDE_SKILL_DIR}"
```

This scores every fixture in `test/fixtures/` and reports the average score and weakest dimension.

### Step 2: Dispatch Skill-Improver Agent

Launch the **skill-improver** subagent with the baseline data:

- Prompt: "Read the SKILL.md at `{CLAUDE_SKILL_DIR}/SKILL.md`. The experiment log is at `~/.cortex/auto-improve-log.tsv`. The evals are at `{CLAUDE_SKILL_DIR}/evals/evals.json`. The weakest dimension across fixtures is `{WEAKEST_DIMENSION}` with avg score `{WEAKEST_SCORE}/25`. Make ONE targeted edit to SKILL.md to improve scaffold output for that dimension. Follow your editing rules strictly."

### Step 3: Re-Score and Decide

After the skill-improver edits SKILL.md:

1. Re-run the scorer on all fixtures:
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/auto-improve.sh" "${CLAUDE_SKILL_DIR}"
```

2. Compare the new average score to the baseline.

3. **Decision rule** (from autoresearch):
   - If new avg score > baseline: **keep** the edit. Commit with message `"auto-improve: [dimension] [before]->[after]"`.
   - If new avg score <= baseline: **revert** the edit with `git checkout -- "${CLAUDE_SKILL_DIR}/SKILL.md"`.

### Step 3B: Handle DERIVED Changes

**Only if the change was KEPT in Step 3** (score improved): If the skill-improver classified its change as **DERIVED**, dispatch the **variant-dispatcher** subagent to extract the conditional logic into a variant file:

- Prompt: "The skill-improver flagged a DERIVED change for [repo type]. Extract the conditional blocks from SKILL.md at `{CLAUDE_SKILL_DIR}/SKILL.md` into `variants/SKILL-{type}.md`. Update `variants/dispatch-table.json`. SKILL.md path: `{CLAUDE_SKILL_DIR}/SKILL.md`. Dispatch table: `{CLAUDE_SKILL_DIR}/variants/dispatch-table.json`."
- After extraction, re-score to verify no regression.

If the change was FIX or CAPTURED, skip this step.

### Step 4: Repeat or Report

If the edit was kept and the score is still < 80, go back to Step 2 for another iteration. Maximum 5 iterations per auto-improve session.

After stopping, print the improvement summary:

```
## Auto-Improve Results

| Iteration | Score | Change | Dimension | Status |
|-----------|-------|--------|-----------|--------|
| Baseline  | [n]   | --     | --        | --     |
| 1         | [n]   | +[n]   | [dim]     | kept   |
| 2         | [n]   | +[n]   | [dim]     | kept   |
| 3         | [n]   | +0     | [dim]     | reverted |

**Total improvement**: +[n] points ([baseline] -> [final])
**Iterations run**: [n]
**Results log**: ~/.cortex/auto-improve-log.tsv
```

---

## Key Principles

These apply across all modes:

1. **Official first**: Always prefer official plugins and MCP servers over custom skills. Check the catalogs at `${CLAUDE_SKILL_DIR}/references/official-plugins-catalog.md` and `${CLAUDE_SKILL_DIR}/references/mcp-catalog.md`.

2. **Project-specific only**: Every generated file must contain real values from the analyzed project. No generic templates, no placeholder text, no invented commands.

3. **Graceful degradation**: If the heuristic pre-scanner fails, subagents handle everything manually. If a reference file is missing, work with what you have.

4. **Never overwrite**: Always read existing files before writing. Merge, enhance, and preserve user customizations.

5. **Three-tool parity**: Always generate for Claude Code, Cursor, AND Codex. The user may use any or all of them.

6. **Quality gate**: The quality-reviewer subagent must PASS before files are written to disk. No exceptions in scaffold mode.

---

## Error Recovery and Autonomy

Inspired by autoresearch's `program.md`: explicit recovery patterns for every failure mode, so the skill can run unattended.

### Fallback Chain

Each step has a fallback. If the primary method fails, use the fallback. If the fallback also fails, log the failure and proceed with reduced output rather than stopping entirely.

| Step | Primary | Fallback | If Both Fail |
|------|---------|----------|--------------|
| Step 1 (Acquire) | `git clone --depth 1` | `git clone` (full) | Stop and report "cannot access repo" |
| Step 2 (Pre-scan) | `analyze.sh` | Skip (subagents do analysis) | Proceed with `{}` profile |
| Step 3 (Subagents) | Both in parallel | Run sequentially | Main thread analysis only |
| Step 4 (Existing) | `ls -la` check | `find` check | Assume no existing setup |
| Step 5 (Generate) | Full 3-tool output | Generate what's possible | At minimum generate CLAUDE.md |
| Step 6 (Review) | quality-reviewer agent | validate.sh script | Manual review warning |
| Step 6B (Improve) | scaffold-improver agent | Skip (keep v1 output) | Proceed with unimproved output |
| Step 7 (Write) | Write tool | Bash `cat >` fallback | Report files to stdout |
| Step 9 (Score/Log) | score.sh + log-result.sh | Skip scoring | Proceed without logging |

### Timeout Handling

- **Subagent timeout**: If any subagent does not respond within 2 minutes, proceed without its output. Use whatever context the main thread gathered.
- **Clone timeout**: If `git clone` takes longer than 60 seconds, try `--depth 1 --single-branch`. If that also times out, report and stop.
- **Score/eval timeout**: If scoring scripts take longer than 30 seconds, skip scoring and proceed.

### Crash Logging

When any step crashes (unexpected error, not a graceful fallback):

1. Log the crash to `~/.cortex/scaffold-results.tsv` with status `crash` and a description of which step failed.
2. Include the error message (first 200 chars) in the description field.
3. Proceed to the next step if possible, or stop gracefully with a clear error message.

```bash
# Example crash logging
bash "${CLAUDE_SKILL_DIR}/scripts/log-result.sh" "$REPO_DIR" "crash" "Step 3 failed: subagent timeout after 120s"
```

### Batch Mode Autonomy

When scaffolding multiple repos in sequence (e.g., from a list of URLs), follow these autonomy rules inspired by autoresearch's "NEVER STOP" clause:

1. **Do not ask for confirmation** between repos. Scaffold each repo, log the result, move to the next.
2. **Do not stop on non-fatal errors.** If one repo fails to scaffold, log it as `crash` or `fail` and continue with the next repo.
3. **Do stop on** repeated fatal errors (3+ consecutive crashes), disk full, or permission denied on the output directory.
4. **Print a batch summary** after all repos are processed:

```
## Batch Scaffold Summary

| Repo | Score | Status | Weakest Dimension |
|------|-------|--------|-------------------|
| [name] | [n]/100 | success | [dim] |
| [name] | [n]/100 | partial | [dim] |
| [name] | --/100 | crash | Step 3: clone failed |

Total: [n] repos, [n] success, [n] partial, [n] crash
Results log: ~/.cortex/scaffold-results.tsv
```

---

## Toolbox Mode

When `$ARGUMENTS` starts with "toolbox", detect, recommend, and optionally install CLI tools that accelerate AI coding agents. CLIs are the native interface for AI agents — they compose naturally and produce structured output that agents consume directly.

### Sub-mode Routing

Strip "toolbox" from `$ARGUMENTS`. Determine sub-mode from the remainder:

- If empty or **"recommend"** → Recommend Mode (default)
- If **"install"** → Install Mode (detect + install all recommended)
- If **"audit"** → Audit Mode (check for outdated tools and conflicts)
- If **"configure"** → Configure Mode (AI agent env vars only)

### Step T1: Detect Installed Tools

Run the detection script against the current repo:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-cli-tools.sh" "$(pwd)"
```

Store the JSON output as `TOOL_DETECTION`. This provides:
- Platform and package manager
- Repo context (which ecosystems are relevant)
- Per-category tool status (installed/missing with versions)
- AI agent config state (USE_BUILTIN_RIPGREP, etc.)

### Step T2: Generate Recommendations

Dispatch the **toolbox-recommender** subagent:

- Pass `REPO_DIR` as `$(pwd)`
- Pass `SCRIPT_DIR` as `${CLAUDE_SKILL_DIR}/scripts`
- Pass `CATALOG_PATH` as `${CLAUDE_SKILL_DIR}/references/cli-tools-catalog.md`

The subagent:
1. Runs detection, reads the catalog
2. Scores each missing tool (agent impact 40%, project relevance 30%, ecosystem fit 20%, install ease 10%)
3. Resolves conflicts (biome vs eslint+prettier, ruff vs black+isort, etc.)
4. Returns a ToolboxManifest JSON with `installed[]`, `recommended[]`, `aiConfigActions[]`, `conflicts[]`

### Step T3: Present Recommendations

Display a grouped, prioritized recommendation screen:

```
## CLI Tools for AI Agent Acceleration

### Currently Installed ({N} tools)
  ✓ ripgrep 14.1.0  — Fast regex search (agent impact: 10/10)
  ✓ fd 10.0.0       — Fast file finder (agent impact: 9/10)
  ✓ gh 2.44.0       — GitHub CLI (agent impact: 10/10)
  ...

### Essential — Missing ({N} tools)
  [1*] jq              — JSON processor for CLI pipelines (score: 92)
       Install: brew install jq
  [2*] ast-grep        — AST-aware code search (score: 88)
       Install: brew install ast-grep
  ...

### Recommended for This Project ({language})
  [3*] biome           — Fast lint+format, replaces eslint+prettier (score: 85)
       Install: npm install -g @biomejs/biome
  [4]  oxlint          — Ultra-fast supplementary linter (score: 72)
       Install: npm install -g oxlint
  ...

### AI Agent Configuration
  [C1] Set USE_BUILTIN_RIPGREP=0 in ~/.zshrc
       Why: Use system ripgrep (2-5x faster) instead of bundled version

* = pre-selected

Install all recommended? [Yes / Pick specific / Configure only / Skip]
```

- **If sub-mode is "recommend"**: Stop here after presenting. Let the user decide.
- **If sub-mode is "install"**: Auto-select all essential + recommended tools and proceed to Step T4.

### Step T4: Installation

If the user selects tools (or sub-mode is "install"):

1. Build an install manifest JSON file from selected tools (array of `{id, installCommand, verifyCommand}` objects).
2. **Dry-run first** — always show what will happen:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/install-cli-tools.sh" /tmp/cortex-install-manifest.json --dry-run
   ```
3. Present the dry-run output to the user. Ask for confirmation.
4. **After user confirms** — execute:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/install-cli-tools.sh" /tmp/cortex-install-manifest.json --yes
   ```
5. Present the install report (installed, failed, skipped, rejected).

**Security**: The install script validates every command against an allowlist. It rejects any command that does not start with an approved prefix (brew install, sudo apt install, npm install -g, pip install, cargo install, etc.). It never runs `curl | sh` or similar piped installs.

### Step T5: Configuration

For each AI agent config action in the ToolboxManifest:

1. Show the user what will be added:
   ```
   Will append to ~/.zshrc:
     export USE_BUILTIN_RIPGREP=0
   ```
2. After user confirms, append the line(s) to the shell profile.
3. Remind the user: "Run `source ~/.zshrc` or restart your shell for changes to take effect."

### Step T6: Summary

Present a final summary:

```
## Toolbox Summary

Installed: {N} new tools
  - fd 10.0.0 (brew install fd)
  - ast-grep 0.25.0 (brew install ast-grep)

Failed: {N}
  - [tool]: [error]

Configured:
  - USE_BUILTIN_RIPGREP=0 added to ~/.zshrc

Previously installed: {N} tools up to date

Run /scaffold-toolbox audit anytime to check for updates.
```

### Audit Sub-mode

When sub-mode is "audit":
1. Run Step T1 (detection)
2. Compare installed versions against the catalog's recommended versions
3. Report:
   - Missing essential tools
   - Outdated tools (installed but old)
   - Conflicting tools (e.g., both eslint and biome installed)
   - AI config gaps (env vars not set)
4. No installation — information only

### Configure Sub-mode

When sub-mode is "configure":
1. Run Step T1 (detection) — only the `aiAgentConfig` section matters
2. Check which AI agent env vars are not set
3. Show recommended additions and ask for confirmation
4. Execute Step T5

---

## Discover Mode

When `$ARGUMENTS` starts with "discover", run the machine-wide discovery and multi-level setup generation pipeline. This scans the developer's environment, builds a DeveloperDNA profile, classifies patterns as user-level vs project-level, and generates a cohesive AI setup across all levels.

**Everything runs locally. Nothing leaves the machine. All scanning is read-only.**

### Step D1: Permission and Directory Selection

Parse any directories from `$ARGUMENTS` (after "discover") into a `SCAN_DIRS` array so spaces are preserved. If `--user-level-only` is present, note it for Step D7.

Present the user with a permission prompt:

```
Cortex Discover will scan your development environment to build a complete developer profile.

What it scans:
  - Git repositories in specified directories
  - Installed CLI tools and their versions
  - Running services (port checks only)
  - Integration configs (checks existence only, never reads credentials)

What it does NOT do:
  - Read file contents beyond package manifests
  - Read environment variable values (only checks if set)
  - Send any data externally
  - Modify any existing files

Directories to scan: [list directories or defaults]

Proceed? [Yes / Customize directories / Cancel]
```

Default directories (if none specified): `~/Documents`, `~/workspace`, `~/projects`, `~/code`, `~/Desktop`.

If the user wants to customize, ask for a comma-separated list of directories, trim whitespace, and store them in the `SCAN_DIRS` array.

If the user cancels, stop immediately.

### Step D2: Run Discovery Engine

Execute the discovery orchestrator (shell scripts only, no LLM calls):

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/discover-orchestrator.sh" "${SCAN_DIRS[@]}" > /tmp/cortex-developer-dna.json
```

This runs 5 discovery scripts in parallel:
- `discover-projects.sh` — finds all git repos, profiles each
- `discover-tools.sh` — detects CLIs, IDEs, package managers
- `discover-services.sh` — checks running ports, Docker containers
- `discover-integrations.sh` — checks Jira/Slack/GitHub/Sentry/etc configs
- `discover-company.sh` — detects internal registries, conventions

**Performance target**: Under 60 seconds for 100 repos.

Read the output JSON. This is the DeveloperDNA.

### Step D3: Preview Results

Present a summary of what was discovered. Do NOT proceed to generation without user confirmation.

```
## Discovery Results

### Developer Profile
- Role: [fullstack-engineer / backend-engineer / etc.]
- Dominant language: [language]
- Active projects: [N] (of [total] total)

### Projects Found
| Project | Language | Framework | Activity |
|---------|----------|-----------|----------|
| [name]  | [lang]   | [fw]      | active   |
| ...     |          |           |          |

### Tools & Services
- CLIs: [list installed]
- Running services: [list]
- Docker containers: [count]

### Integrations Detected
- [Jira / Slack / GitHub / Sentry / etc. with signals]

### Cross-Project Patterns
- [dependency] used in [N]/[total] repos → will be user-level
- [test framework] common across [N]% of repos
- [linter] common across [N]% of repos

### What Will Be Generated

**User-level (~/.claude/):**
- CLAUDE.md with developer profile
- MCP servers: [list]
- Global rules: [list]

**Project-level ([N] active repos):**
- Per-project CLAUDE.md, agents, skills, rules, MCP configs
- Only project-specific items (global patterns excluded)

Generate AI setup? [Yes / User-level only / Review full DNA JSON / Cancel]
```

### Step D4: Classify Patterns (Cross-Project Analysis)

Dispatch the **cross-project-analyzer** subagent:

- Before dispatching, read `${CLAUDE_SKILL_DIR}/references/discover-integration-catalog.md` and include its content in the prompt (subagents cannot resolve `${CLAUDE_SKILL_DIR}`).
- Prompt: "Analyze this DeveloperDNA and classify every pattern as user-level, candidate, or project-level. Detect service relationships. Identify deduplication opportunities. Here is the integration catalog for classification rules: ```{INTEGRATION_CATALOG_CONTENT}```. DeveloperDNA: ```{DNA_JSON}```"
- Output: ClassificationPlan JSON.

### Step D5: Synthesize Generation Plan

Dispatch the **dna-synthesizer** subagent:

- Before dispatching, read `${CLAUDE_SKILL_DIR}/references/user-level-formats.md` and include its content in the prompt (subagents cannot resolve `${CLAUDE_SKILL_DIR}`).
- Prompt: "Given this DeveloperDNA and ClassificationPlan, produce a concrete GenerationPlan listing every file to create at user-level and project-level. Resolve conflicts and handle deduplication. Here is the user-level formats spec: ```{USER_LEVEL_FORMATS_CONTENT}```. DeveloperDNA: ```{DNA_JSON}```. ClassificationPlan: ```{CLASSIFICATION_JSON}```"
- Output: GenerationPlan JSON.

### Step D6: Generate User-Level Setup

Dispatch the **user-level-generator** subagent:

- Prompt: "Based on this GenerationPlan and DeveloperDNA, produce the user-level AI setup file contents. Return all generated content in your output — do NOT write files to disk. Writing is handled later in Step D9 after quality review. For each file, output its target path and content. GenerationPlan: ```{GENERATION_PLAN_JSON}```. DeveloperDNA: ```{DNA_JSON}```"
- The agent generates:
  - `~/.claude/CLAUDE.md` — developer profile + global conventions
  - `~/.claude/.mcp.json` — integration MCP servers (if any detected)
  - `~/.claude/rules/*.md` — global rules (company conventions, security, shared testing/linting)

**If `--user-level-only` was specified, skip D7 (project-level scaffolding) and proceed directly to Step D8 (quality review for user-level files) then D9 (write) then D10 (summary).**

### Step D7: Generate Project-Level Setups (Batch)

For each active project in the DeveloperDNA:

**Note**: Variant dispatch (monorepo, minimal) DOES apply during D7 batch scaffolding. Each project is evaluated against the dispatch table independently.

1. Set `REPO_DIR` to the project's path.
2. Inject DeveloperDNA context into the scaffold run:
   - Pass the `skip_patterns` list from the GenerationPlan (patterns already at user-level).
   - Pass the `serviceRelationships` context so project scaffolds understand cross-project connections.
3. Run the standard Scaffold Mode Steps 2-9 for this project, with these modifications:
   - **Step 3 (Subagents)**: Include DeveloperDNA summary in the repo-analyzer and skill-recommender prompts.
   - **Step 5 (Generate)**: Skip generating rules/skills for patterns marked "covered at user-level".
   - **Step 5 (Generate)**: Do NOT generate user-level MCP servers in project `.mcp.json`.
   - **Step 6 (Quality Review)**: Score as usual, but do not penalize missing patterns that are at user-level.

**Parallelism**: If projects are in different directories (not nested), scaffold up to 3 projects in parallel using background agents.

**If there are more than 10 active projects**: Ask the user which projects to scaffold. Show the list sorted by activity (most recent first) and let them select. Default to the 5 most active.

### Step D8: Quality Review (Per-Level)

After all generation is complete:

1. Review user-level files: dispatch quality-reviewer on `~/.claude/` output.
2. Review each project's output: already done in Step D7's quality gate (Step 6).
3. Check for cross-level duplication: scan for patterns that appear in BOTH user-level rules AND project-level rules. Flag these.

### Step D9: Write All Files

**Note**: The user-level-generator in Step D6 generates file CONTENT but does NOT write to disk. Step D9 handles all writes after quality review.

Write files in this order:

1. **User-level files** → `~/.claude/` (CLAUDE.md, .mcp.json, rules/)
   - Write the content produced by the user-level-generator in Step D6.
   - For existing files: MERGE using the same strategy as Scaffold Mode Step 7.
   - For `.mcp.json`: deep merge (new servers added, existing preserved).
   - For `CLAUDE.md`: preserve existing sections, add new sections, update stale sections.

2. **Project-level files** → each repo directory
   - Already written in Step D7 by the per-project scaffold runs (each runs its own Step 7).

### Step D10: Discover Summary Report

Print a unified summary:

```
## Cortex Discover Complete

### User-Level Setup (~/.claude/)
- [path] — [what it contains]
- [path] — [what it contains]
- ...

### Project-Level Setups
| Project | Files Generated | Score | Weakest Dimension |
|---------|----------------|-------|-------------------|
| [name]  | [N] files      | [N]   | [dim]             |
| ...     |                |       |                   |

### Cross-Project Intelligence Applied
- [pattern] deduplicated to user-level (was in [N] projects)
- [relationship]: [provider] → [consumer] (API contract)
- ...

### Integration MCP Servers Configured
- [server] — [what it provides] (env vars needed: [list])
- ...

### Manual TODOs
- [ ] Set environment variable: [VAR_NAME] for [integration]
- [ ] Install recommended plugins: `claude plugins install [name]`
- [ ] Review and customize ~/.claude/CLAUDE.md
- ...

### What's Next
- Start a new Claude Code session to load the updated setup
- Run `/scaffold [repo]` to scaffold individual repos later
- Run `/scaffold discover` again after setting up new projects
```

### Step D11: Score and Log Results

Log the discover run to `~/.cortex/discover-results.tsv`:

```bash
mkdir -p "$HOME/.cortex"
```

TSV columns: `timestamp`, `scan_dirs`, `total_projects`, `active_projects`, `integrations_found`, `user_level_files`, `project_level_files`, `status`, `description`

Also save the DeveloperDNA for future comparisons:

```bash
cp /tmp/cortex-developer-dna.json "$HOME/.cortex/developer-dna.json"
```
