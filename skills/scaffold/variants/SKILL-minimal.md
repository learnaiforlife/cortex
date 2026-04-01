---
name: scaffold-minimal
description: "Minimal project scaffold variant. For repos with fewer than 10 files and no detected framework. Generates only essential files to avoid bloat."
---

# Scaffold Variant: Minimal Projects

This variant handles simple, small projects — scripts, utilities, learning repos, or brand-new projects with minimal structure. The key principle: **generate less, not more**.

## When This Variant Is Selected

The dispatch table routes here when:
- The repo has fewer than 10 files (excluding node_modules, .git, vendor, dist)
- No major framework is detected (no Next.js, Express, FastAPI, Django, etc.)

## Modified Steps

Steps 1 and 7-9 are the same as the main SKILL.md. Steps 2-5 differ, and Step 6 has a quality-review override for minimal projects.

### Step 2: Lightweight Pre-Scan

Run `analyze.sh` as usual, but expect minimal output. The project may have:
- A single entry point file (index.js, main.py, main.go)
- A package.json or pyproject.toml with few/no dependencies
- No CI, no Docker, no API spec

Note: A minimal project is NOT a broken project. Do not over-diagnose.

### Step 3: Skip Parallel Subagents

For minimal projects, do NOT dispatch repo-analyzer or skill-recommender as subagents. The overhead is not justified.

Instead, the main thread does a quick analysis:
1. Read the entry point file (if one exists)
2. Read the manifest file (package.json, pyproject.toml, etc.)
3. Identify the language, any dependencies, and the project purpose from README.md (if exists)

### Step 4: Check Existing Setup

Same as main SKILL.md — read any existing CLAUDE.md, .claude/, .cursor/ files.

### Step 5: Minimal Generation

Generate ONLY these files:

**Required (always generate):**

1. **`CLAUDE.md`** — Keep it short (30-60 lines max):
   ```markdown
   # [Project Name]

   ## Overview
   [1-2 sentences from README or inferred from code]

   ## Language & Tools
   - Language: [detected language]
   - Entry point: [file]
   - Package manager: [if any]

   ## Commands
   - [Only real commands from manifest, if any]

   ## Development Notes
   - [Any patterns noticed in the code]
   ```

2. **`.claude/rules/safety.md`** — Basic safety rule (same as main SKILL.md)

**Conditional (only if signals present):**

3. **`AGENTS.md`** — Only if the project has at least one script/command. Keep under 30 lines.

4. **`.cursor/rules/project-context.mdc`** — Only if `.cursor/` directory already exists or Cursor IDE is detected.

**DO NOT generate for minimal projects:**
- Custom agents (no complex workflows to automate)
- Custom skills (no multi-step processes)
- `.mcp.json` (no services to connect to)
- Multiple rule files (one safety rule is enough)
- `.claude/settings.json` (no hooks needed)

### File Count Target

A minimal scaffold should produce **2-4 files total**. If you find yourself generating more than 5, stop and reconsider — you're probably over-generating.

### Step 6 Override: Quality Review for Minimal Projects

When dispatching the quality-reviewer in Step 6, add this to the prompt:

> "This is a minimal project (fewer than 10 files, no framework). Adjusted expectations: Do NOT penalize missing agents, skills, Cursor rules, or MCP configs. A total file count of 2-4 is correct, not a deficiency. Do NOT flag missing AGENTS.md as a completeness issue unless the project has executable commands. A total score of 60+ is acceptable."

This prevents the quality-reviewer from triggering Step 6B improvement loops that add unnecessary files.

### Quality Score Expectations

For minimal projects, the quality score thresholds are different:
- **format_compliance**: Same standards (25 pts)
- **specificity**: Lower bar — project has less to be specific about (15 pts is good)
- **completeness**: Lower bar — fewer files is correct, not a deficiency (15 pts is good)
- **structural_quality**: Same standards (25 pts)

A total score of 60+ is acceptable for minimal projects (vs 70+ for normal projects).

## Plugins

Recommend **only** the `superpowers` plugin. Do not recommend context7 (no frameworks to look up), frontend-design (no frontend), or code-review (likely a solo project).

## Examples

### Example: A Python script project (3 files)

```
my-script/
├── main.py
├── requirements.txt
└── README.md
```

Generated scaffold:
```
CLAUDE.md               (40 lines — overview, language, commands)
.claude/rules/safety.md (15 lines — basic safety)
```

Total: 2 files. That's correct for this project.

### Example: A Node.js utility (5 files)

```
my-util/
├── package.json
├── index.js
├── lib/helper.js
├── test/index.test.js
└── README.md
```

Generated scaffold:
```
CLAUDE.md                          (50 lines — overview, commands, testing)
.claude/rules/safety.md            (15 lines)
AGENTS.md                          (25 lines — has npm scripts to document)
.cursor/rules/project-context.mdc  (20 lines — only if Cursor detected)
```

Total: 3-4 files. Correct.
