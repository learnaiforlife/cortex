# Overnight Agent Rules

## CRITICAL: Usage Limit Fallback Strategy

If you hit Claude Code usage limits ("You're out of extra usage"), IMMEDIATELY switch:

### Fallback Order:
1. **Primary**: Claude Code (`claude --model claude-opus-4-6 --permission-mode bypassPermissions --print`)
2. **Fallback 1**: Cursor Agent (`cursor agent --print` in project directory)  
3. **Fallback 2**: Codex (`codex exec --full-auto` with PTY)
4. **Never stop** — always have a fallback running

### How to detect and switch:
```bash
# If claude command fails with usage error, use cursor:
claude --model claude-opus-4-6 --permission-mode bypassPermissions --print "task" 2>&1 || \
cursor agent --print "task" 2>&1 || \
codex exec --full-auto "task"
```

### For cursor agent (your subscription):
```bash
cd /Users/lathesh/Documents/workspace/cortex
cursor agent --print "Your full task here" 2>&1
```

### For Codex:
```bash
cd /Users/lathesh/Documents/workspace/cortex
codex exec --full-auto "Your full task here"
```

## Continuous Collaboration Strategy

You are 3 agents working as a team tonight. Use each for what it's best at:

| Tool | Best For |
|------|---------|
| Claude Code Opus | Complex reasoning, architecture, prompt engineering |
| Cursor Agent | Code review, refactoring, finding bugs in real files |
| Codex | Shell scripting, Python, file operations, quick fixes |

### Recommended Split:
- **Phase 1 (Build)**: Claude Code primary, Cursor fallback
- **Phase 2-4 (Review)**: Alternate between all 3 — each catches different things
- **Phase 5 (Autoresearch)**: Python scripts directly (no AI needed)
- **Phase 6 (OSS Tests)**: Cursor primary (uses your subscription, no usage limits)
- **Phase 7 (Code Review)**: Cursor + Codex in parallel
- **Phase 8-9 (Fix + Sync)**: Claude Code primary, Cursor fallback

## Parallel Execution Strategy

For independent tasks, run agents in parallel:
```bash
# Run Cursor and Codex reviews simultaneously
cursor agent --print "Review scripts/" &
CURSOR_PID=$!
codex exec --full-auto "Review agents/" &
CODEX_PID=$!
wait $CURSOR_PID $CODEX_PID
```

## New Ideas to Explore Tonight

While building and testing, look for opportunities to improve Cortex beyond the plan:

1. **Cross-tool consistency checker**: After generating CLAUDE.md + cursor rules + AGENTS.md, verify they say the same thing about key facts (same commands, same file paths). Generate a consistency report.

2. **Auto-detect project maturity level**: 
   - < 10 commits = early stage → suggest opinionated defaults
   - > 100 commits = established → analyze existing patterns first
   - > 1000 commits = mature → be conservative, minimal changes

3. **Skill gap analysis**: After scaffolding, check if the project has known pain points that existing skills cover. E.g., if they have a complex Makefile, suggest a Makefile skill.

4. **"Did you know?" suggestions**: Based on the repo analysis, surface 2-3 non-obvious Claude Code features the developer might not know about. E.g., "Your project has many parallel test files — did you know Claude Code can run them in parallel subagents?"

5. **Scaffold diff mode**: For repos that already have CLAUDE.md, show what WOULD change instead of overwriting. Let users review the diff first.

If any of these are quick to implement (< 30 min), add them. Otherwise document them in /tmp/new-ideas.md for Lathesh to review.

## Commit Strategy
Commit after EVERY completed task (not just phases). Use descriptive messages:
- `feat: add detect-opportunities.sh with Jira/Confluence/Slack detection`
- `feat: add opportunity-detector subagent (haiku model, produces SuggestionManifest)`
- `fix: cursor review - fix unquoted variable in detect-opportunities.sh`
- `test: all 4 new evals passing on nextjs-app fixture`

## When to Notify Lathesh
Send notification for each milestone:
```bash
openclaw system event --text "Cortex Phase X: [description]. Files: X new, Y modified. Evals: X/Y passing." --mode now
```

Send immediately if you find something interesting or unexpected — good or bad.
