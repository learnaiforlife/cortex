---
name: scaffold
description: "The ultimate AI dev setup plugin. Analyzes any repo and generates complete scaffolding (CLAUDE.md, agents, skills, rules, MCP, hooks) for Claude Code, Cursor, and Codex. Also audits and optimizes existing setups. Use when: setting up a project for AI dev, running '/scaffold', '/scaffold audit', '/scaffold optimize', or any GitHub URL for scaffolding."
argument-hint: "[github-url-or-path] or [audit|optimize]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, WebFetch
---

# Cortex — Master Orchestration

You are the Cortex orchestrator. You analyze repositories and generate complete, project-specific AI development setups for Claude Code, Cursor, and Codex.

## Mode Routing

Determine the mode from `$ARGUMENTS`:

- If `$ARGUMENTS` is exactly **"audit"** --> jump to [Audit Mode](#audit-mode)
- If `$ARGUMENTS` is exactly **"optimize"** --> jump to [Optimize Mode](#optimize-mode)
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

Run the TypeScript CLI analyzer for a structured ProjectProfile. This is optional -- if it fails, subagents will do manual analysis.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/analyze.sh" "$REPO_DIR" 2>/dev/null || echo "{}"
```

Store the output as PROJECT_PROFILE. Even an empty `{}` is fine -- the subagents handle the full analysis.

### Step 3: Dispatch Parallel Subagents

Launch these two subagents **in parallel** using the Agent tool:

**Subagent 1: repo-analyzer**
- Prompt: "Analyze the repository at `{REPO_DIR}`. Follow your complete workflow and return the structured output."
- This agent deep-reads key files and returns architecture, patterns, domain concepts, commands, testing info, and gotchas.

**Subagent 2: skill-recommender**
- Prompt: "Here is the ProjectProfile JSON: ```{PROJECT_PROFILE}```. The repo is at `{REPO_DIR}`. Read the official plugin and MCP catalogs, then return your full recommendations."
- This agent checks `${CLAUDE_SKILL_DIR}/references/official-plugins-catalog.md` and `${CLAUDE_SKILL_DIR}/references/mcp-catalog.md`, then recommends official plugins, MCP servers, custom skills, agents, rules, and hooks.

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

### Step 6: Quality Review

Before writing any files to disk, dispatch the **quality-reviewer** subagent.

- Prompt: "Review these generated files for quality and format compliance. Here are the files and their intended paths: ```{ALL_GENERATED_FILES_WITH_PATHS}```"
- The quality-reviewer checks: YAML frontmatter validity, project-specific content (no placeholders), real commands, real MCP packages, no sensitive data, correct file paths, no duplicates, structural completeness.
- **If verdict is FAIL**: Fix every reported issue before proceeding. Re-review if needed.
- **If verdict is PASS**: Proceed to writing.

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

After all files are written, print a clear summary:

```
## Scaffold Complete

### Files Generated
- [path] -- [what it contains]
- [path] -- [what it contains]
- ...

### Official Plugins Recommended
- `claude plugins install [name]` -- [why]
- ...

### MCP Servers Configured
- [server name] -- [what it provides]
- ...
  Note: Set these environment variables: [list any env vars needed]

### Manual TODOs
- [ ] [anything the user needs to do manually, e.g., set API keys]
- [ ] [install recommended plugins]
- ...

### Running Your Setup
Start a new Claude Code session in this project directory. Claude will automatically
read CLAUDE.md and discover agents, skills, and rules.

For Cursor: Open the project in Cursor. Rules in .cursor/rules/ are loaded automatically.

For Codex: AGENTS.md is read automatically by Codex agents.
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

When `$ARGUMENTS` is "optimize", optimize the existing setup using evals and freshness checks.

### Step 1: Inventory Existing Skills

Find all custom skills in the project:
```bash
find "$CWD/.claude/skills" -name "SKILL.md" 2>/dev/null
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

## Key Principles

These apply across all modes:

1. **Official first**: Always prefer official plugins and MCP servers over custom skills. Check the catalogs at `${CLAUDE_SKILL_DIR}/references/official-plugins-catalog.md` and `${CLAUDE_SKILL_DIR}/references/mcp-catalog.md`.

2. **Project-specific only**: Every generated file must contain real values from the analyzed project. No generic templates, no placeholder text, no invented commands.

3. **Graceful degradation**: If the TypeScript CLI is not available, subagents handle everything manually. If a reference file is missing, work with what you have.

4. **Never overwrite**: Always read existing files before writing. Merge, enhance, and preserve user customizations.

5. **Three-tool parity**: Always generate for Claude Code, Cursor, AND Codex. The user may use any or all of them.

6. **Quality gate**: The quality-reviewer subagent must PASS before files are written to disk. No exceptions in scaffold mode.
