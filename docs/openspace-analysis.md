# OpenSpace Analysis — What Could Help Cortex

## What is OpenSpace?

[OpenSpace](https://github.com/HKUDS/OpenSpace) is a self-evolving skill engine for AI agents. Skills are living entities that auto-fix, auto-improve, and auto-learn from real-world usage. Agents share evolved skills via a cloud community.

Key capabilities:
- **Three evolution modes**: FIX (repair), DERIVED (specialized variant), CAPTURED (extract new pattern)
- **Three triggers**: Post-execution analysis, tool degradation detection, metric monitoring
- **Quality monitoring**: Applied rate, completion rate, effective rate, fallback rate per skill
- **Cloud community**: Upload/download skills, group sharing, access control
- **Token efficiency**: 46% fewer tokens by reusing successful patterns

## Cortex vs. OpenSpace: Different Problems

| Aspect | Cortex | OpenSpace |
|--------|--------|-----------|
| Core function | Generate AI config files for repos | Runtime skill engine for any AI agent |
| Skill count | 1 skill (scaffold) | Hundreds of evolving skills |
| Execution model | Run once per repo | Continuous runtime with learning |
| Evolution | Autoresearch loop (from this session) | Built-in FIX/DERIVED/CAPTURED pipeline |
| Quality tracking | score.sh + results.tsv | SQLite store with per-skill metrics |
| Sharing | None | Cloud community with upload/download |

OpenSpace is solving a bigger, different problem. But three specific patterns are transferable.

---

## Actionable Improvements for Cortex

### 1. Evolution Taxonomy (FIX / DERIVED / CAPTURED)

**What OpenSpace does**: Every skill change is classified:
- **FIX**: Repair broken instructions. Same skill, new version.
- **DERIVED**: Create enhanced or specialized variant. New skill, coexists with parent.
- **CAPTURED**: Extract novel reusable pattern from successful execution. Brand new skill.

**What Cortex should do**: The `skill-improver` agent currently treats all SKILL.md edits the same. Classifying changes would make the auto-improve loop more strategic.

**Concrete changes**:

In `agents/skill-improver.md`, add an evolution mode to the output format:

```markdown
## SKILL.md Edit

**Evolution mode**: FIX | DERIVED | CAPTURED
**Target weakness**: [dimension]
**Change made**: [description]
```

In `scripts/auto-improve.sh`, log the evolution mode in the TSV:

```
timestamp  iteration  avg_score  ...  status  evolution_mode  description
```

In SKILL.md Auto-Improve Mode, add guidance on when each mode applies:

- **FIX**: When a specific step produces consistently wrong output (e.g., YAML frontmatter always invalid). Patch the instruction in-place.
- **DERIVED**: When a repo type needs fundamentally different handling (e.g., monorepos). Consider creating a `SKILL-monorepo.md` variant instead of bloating the main SKILL.md.
- **CAPTURED**: When a successful scaffold run reveals a pattern not in the instructions (e.g., "always check for Dockerfile and add container MCP server"). Extract it as a new bullet point.

**Effort**: Small. Mostly labeling changes in existing agents and log format.

---

### 2. Per-Subagent Quality Metrics

**What OpenSpace does**: Tracks applied rate, completion rate, effective rate, and fallback rate for every skill, every tool call, and every code execution.

**What Cortex should do**: Track per-subagent performance metrics in `scaffold-results.tsv`.

**Concrete changes**:

Extend the TSV schema in `log-result.sh`:

```
timestamp  repo  score  ...  quality_reviewer_verdict  quality_reviewer_score  improver_ran  improver_helped  subagent_timeouts
```

New columns:
- `quality_reviewer_verdict`: PASS/FAIL on first attempt
- `quality_reviewer_score`: The numeric score from the reviewer
- `improver_ran`: true/false (did Step 6B run?)
- `improver_helped`: true/false (did the improver raise the score?)
- `subagent_timeouts`: count of subagents that timed out

In SKILL.md Step 9, collect these metrics before calling `log-result.sh`.

**Why it matters**: After 50+ scaffold runs, you can answer:
- "The quality-reviewer fails on first pass 40% of the time" -> strengthen Step 5 instructions
- "The scaffold-improver only helps 20% of the time" -> the improver agent needs better instructions
- "Subagent timeouts happen on 10% of runs" -> increase timeout or add caching

**Effort**: Medium. Requires extending the log format and collecting metrics in SKILL.md.

---

### 3. Post-Execution Analysis Trigger

**What OpenSpace does**: Runs analysis after EVERY task and automatically suggests FIX/DERIVED/CAPTURED evolution. No manual trigger needed.

**What Cortex should do**: After every scaffold run (Step 9), if the score is below a threshold, automatically print a diagnostic suggesting what to improve — without requiring the user to run `/scaffold-optimize auto-improve`.

**Concrete changes**:

In SKILL.md Step 9, after printing the quality score, add:

```
### Improvement Suggestions

If the total score is below 70, analyze the weakest dimension and print one specific suggestion:

- If **format_compliance** < 15: "Consider adding YAML frontmatter validation in Step 5. Common issue: agent `tools` field written as comma-separated string instead of YAML list."
- If **specificity** < 15: "CLAUDE.md may contain placeholder text. Re-read the project's package.json and replace generic commands with actual ones."
- If **completeness** < 15: "Missing files for one or more tools. Check: CLAUDE.md exists? .cursor/rules/*.mdc exists? AGENTS.md exists?"
- If **structural_quality** < 15: "Some files may be too short or missing body content. Agents need system prompts after frontmatter. Skills need workflow steps."

End with: "Run `/scaffold-optimize auto-improve` to fix these automatically."
```

This is lighter than OpenSpace's full post-execution analysis engine, but it captures the key idea: every run teaches you something about how to improve.

**Effort**: Small. A few paragraphs added to SKILL.md Step 9.

---

## Ideas That Are NOT Worth Pursuing Now

### Cloud Skill Community
OpenSpace's cloud registry lets agents share evolved skills. Applied to Cortex, this would mean users share scaffold templates for specific project types. But this requires building infrastructure (registry API, upload/download CLI, versioning, access control) that is a product initiative, not a quick integration. Defer until there are enough Cortex users to create network effects.

### SQLite Skill Store
OpenSpace uses SQLite for version DAGs, quality metrics, and lineage tracking. Cortex's append-only TSV files are simpler and sufficient at current scale. If the experiment log grows past thousands of entries, consider migrating to SQLite.

### BM25 + Embedding Skill Search
OpenSpace uses hybrid search to find relevant skills from hundreds of candidates. Cortex has one skill. Not applicable until Cortex manages multiple scaffold variants.

### MCP Server Architecture
OpenSpace exposes itself as an MCP server with 4 tools. Cortex is a Claude Code skill/plugin. The distribution model is different and changing it would not improve scaffold quality.

### Tool Degradation Detection
OpenSpace monitors tool success rates and auto-triggers evolution when they drop. Cortex doesn't call external tools that degrade. The closest analog is stale MCP configs, already covered by the optimize mode.

---

## Recommended Implementation Order

1. **Evolution taxonomy** in `skill-improver.md` + log format (small, clarifies auto-improve)
2. **Post-execution suggestions** in SKILL.md Step 9 (small, immediate user value)
3. **Per-subagent metrics** in log format + SKILL.md (medium, enables data-driven improvement)

These three changes are additive. They don't conflict with each other or with the autoresearch integration already in place.
