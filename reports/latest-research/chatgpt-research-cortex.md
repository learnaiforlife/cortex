# Audit Report on learnaiforlife/cortex

## Executive summary

**1. Executive summary**

**What it is (fact):** This repository (“cortex”) is a **prompt-and-scripts toolkit** designed to **analyze a codebase and generate AI-development “scaffolding” files** (project instructions, subagents, skills, rules, MCP configuration, and hooks) primarily for **Claude Code**, plus compatible outputs for **Cursor** and **Codex-style agent formats**. The repository declares itself as a plugin with three modes: scaffold (generate), audit (review existing), optimize (improve via evals). citeturn20view0turn2view0

**How it works (fact):** The “engine” is not a compiled program; it is mostly:
- A large **skill prompt** (SKILL.md) that orchestrates analysis, choice of artifacts, generation, review, and scoring. citeturn30view3turn30view4turn30view7  
- A set of **shell scripts** that do heuristic scanning (`analyze.sh`), opportunity detection (`detect-opportunities.sh`), validation/scoring (`validate.sh`, `score.sh`), eval checking (`run-skill-evals.sh`), and machine-wide discovery (`discover-orchestrator.sh` + discover-* scripts). citeturn18view0turn17view2turn18view6turn18view1turn18view2turn18view4  
- Optional “auto-research” **Python** tooling that runs an optimization loop using the `claude` CLI to propose edits and measure improvements. citeturn36view0turn44view5turn44view8turn44view9

**Reality check on maturity (fact + inference):**
- The repo contains a fairly extensive **eval specification** (`skills/scaffold/evals/evals.json`) describing expected behaviors for scaffold/audit/discover and some structural assertions. citeturn28view1turn26view0turn46view0  
- The README “status” table claims a passing eval count (example: “52/52 assertions” shown there), but the eval file itself appears to have more cases/coverage than that claim implies, suggesting **status drift** between documentation and the current eval set. (Inference from comparing README’s reported count to the presence and size/content of eval specs.) citeturn2view0turn28view1turn46view0

**Bottom line verdict (inference):** Cortex is **promising for power users** of Claude Code who want **repeatable, repo-specific agent configuration** and are comfortable with prompt-driven automation and iterative refinement. It is **not a deterministic scaffolder**, so its reliability depends on the LLM and user oversight. It appears **non-novel in the “generate CLAUDE.md / Cursor rules” space** but **more distinctive in how it combines** (a) multi-tool scaffolding, (b) local discovery, (c) scoring and eval contracts, and (d) an auto-improvement loop. citeturn20view0turn30view3turn45search3turn45search22

**Scores (1–10):**
- **Usefulness:** 6/10 (high for a narrow audience; moderate overall)  
- **Originality:** 7/10 (composition and eval-driven workflow is the differentiator; many individual pieces exist elsewhere)  
- **Maintainability:** 5/10 (lots of prompt logic + shell scripts; format drift risk)  
- **Adoption potential:** 4/10 (requires Claude Code workflow buy-in; “setup” and “trust” hurdles)

**Confidence level (preview):** Medium (≈0.72). The repo is heavily prompt-driven, so “what it does in practice” can only be partially verified by static inspection. citeturn30view3turn18view2

## Project overview and intended users

**2. What the project is**

### Plain-English explanation
Cortex is a **starter kit for “teaching” AI coding tools how to work in a specific repository**. You point it at a repo, and it tries to generate:
- A **project memory/instructions file** (CLAUDE.md) telling the agent how the repo is structured and how to run common dev commands. citeturn30view3turn18view6  
- A set of **specialized subagents** (e.g., test runner, lint/format helper, PR writer) tailored to what it detects in the repo. citeturn30view0turn17view2  
- **Rules** and **hooks** to prevent unsafe edits and remind/run checks. citeturn21view1turn43view1turn45search0  
- Optional **MCP server configs** for integrations like GitHub (and others depending on detected services). citeturn43view0turn45search1turn45search9  
- Parallel outputs for other tooling ecosystems: **Cursor rules** and a Codex-style **AGENTS.md** file. citeturn30view3turn45search3turn26view2

### Technical explanation
Cortex is packaged like a **Claude Code plugin/skill** (it declares plugin metadata; it installs command files into a Claude configuration directory; and it ships a big SKILL.md prompt that defines the workflow). citeturn20view0turn4view0turn6view0turn30view3

The “scaffold” workflow includes:
- A **heuristic pre-scan** that counts file types and detects signals from repo files (implemented in shell). citeturn18view0turn17view2  
- Subagent orchestration for deeper repo reading + recommendations (defined in SKILL.md). citeturn30view3  
- A post-generation **validation/scoring** phase (scripts) and an optional optimize/auto-improve loop (scripts + optional Python loop). citeturn30view4turn18view1turn36view0turn44view5

### Who it is for
- **Primary target (inference):** individual developers or small teams already using Claude Code heavily and wanting to reduce repeated setup prompts, standardize agent behavior, and improve reliability via rules/hooks/evals. This is strongly implied by the project’s focus on Claude Code skill packaging, hooks, and eval-driven iteration. citeturn20view0turn30view3turn45search0  
- **Secondary target (inference):** “multi-tool” environments where some use Cursor and some use a Codex-style workflow, and the team wants a single “setup generator” that emits all needed config artifacts. citeturn20view0turn30view3turn45search3  

### Who should use this
- Developers who want **repo-specific AI instructions** and are okay with **reviewing generated artifacts** before trusting them. citeturn30view3turn18view6  
- People who already maintain CLAUDE.md / rules / hooks, and want a more systematic approach (scoring + eval contracts). citeturn30view4turn18view1turn28view1  

### Who should avoid this
- Anyone expecting a **deterministic**, buildable CLI that “just works” without LLM variance (this repo is fundamentally prompt-and-process based). citeturn30view3turn18view2  
- Organizations with strict privacy/compliance constraints who do not want machine-wide scanning (“discover”) or automated scheduled jobs unless they fully audit and sandbox them. citeturn30view7turn42view16turn42view15  
- Teams not using Claude Code at all (the installation, commands, skill packaging, and hooks are Claude-centric). citeturn4view0turn6view0turn45search0  

## What the code actually does

**3. What the code actually does**

### Installation and integration surface (facts)
- The repository includes an install script that copies a scaffold skill directory and command definitions into a user’s `~/.claude/` directory (the install script explicitly references `~/.claude/skills` and `~/.claude/commands`). citeturn4view0  
- It ships command entrypoints that appear to map to Claude Code-style commands like `/scaffold`, `/scaffold audit`, and `/scaffold optimize` (as command markdown files). citeturn6view0turn6view1turn6view2turn6view3  
- It defines plugin metadata with a description explicitly claiming: analysis + scaffolding generation for Claude Code, Cursor, and Codex, with modes scaffold/audit/optimize. citeturn20view0  

### Local heuristic scanners and validators (facts)
Cortex includes shell scripts that are not “generators” themselves but produce signals and quality checks:

- **`analyze.sh`** emits a “ProjectProfile” JSON by scanning the filesystem for file extensions and common key files (no external dependencies implied in the header). citeturn18view0  
- **`detect-opportunities.sh`** scans for repo signals (test framework configs, etc.) and outputs “OpportunitySignals JSON.” citeturn17view2  
- **`validate.sh`** performs basic checks like CLAUDE.md existence/size and warnings about short/generic files. citeturn18view6  
- **`score.sh`** computes a numeric score (0–100) across dimensions like format compliance, specificity, completeness, and structural quality; it also attempts JSON validity checks using `python3` or `node` if present. citeturn18view1turn42view2turn42view4  
- **`run-skill-evals.sh`** is described as a runner that checks machine-verifiable assertions from `evals.json` against scaffold output (it verifies output; it does not run scaffold). citeturn18view2  

### Discovery engine (facts)
The “discover” feature is implemented as local scripts that scan a developer machine and produce a “DeveloperDNA JSON”:
- The orchestrator script claims it runs discovery scripts “in parallel” and merges results (privacy claims: local scanning; does not read env var values). citeturn18view4turn30view7  
- The orchestrator explicitly runs multiple scripts concurrently (backgrounding them) according to the code snippet visible in the repository. citeturn42view13  
- A separate `schedule-autorun.sh` sets up periodic tasks using **launchd (macOS)** or **cron (Linux)**. citeturn18view7turn42view16turn42view15  

### Hooks and “nudges” (facts)
The repo includes a dedicated `hooks/hooks.json` that adds session-start or stop-time messages nudging users to run `/scaffold` or `/scaffold discover`, and to run auto-improve if the last score was low. citeturn44view2turn44view1  

### MCP config shipped by default (facts)
At the repo root, `.mcp.json` is a valid MCP-style config defining a GitHub MCP server run via `npx @modelcontextprotocol/server-github`, with the token passed via an environment variable placeholder `"${GITHUB_TOKEN}"`. citeturn43view0turn45search9  

**Verification note (fact + inference):** This is consistent with current Claude Code documentation that treats MCP tools as regular tools in hook events, and with public MCP server collections and npm packaging patterns. citeturn45search0turn45search1turn45search9  

### Auto-research subproject (facts)
The repo includes a `claude-code-auto-research/` toolset that claims to run an “autoresearch” loop optimizing prompts against eval expectations. citeturn36view0  
- `config.json` includes knobs like max iterations, model choice, grading model, fixtures, and a target file (example target: `skills/scaffold/agents/quality-reviewer.md`). citeturn43view2  
- `run.py` uses `subprocess.run(["claude", "-p", ...])` and expects a specific marker format for modified file output. citeturn44view5turn44view6  
- `measure.py` is explicitly described as a scoring engine that runs a target subagent against fixtures and grades expectations to compute a composite score. citeturn44view9turn44view10turn44view11  

**4. Technical architecture and main components**

### High-level architecture (fact)
Cortex is best understood as **three layers**:

**Layer A: Orchestration prompt (“the policy”)**
- `skills/scaffold/SKILL.md` defines multi-mode workflows: scaffold generation, audit, optimize, discover; it mandates reading repo files, preferring official plugins, generating only repo-specific commands, and running scoring. citeturn30view3turn30view4turn30view7  

**Layer B: Deterministic local tooling (“the instruments”)**
- Shell scripts do scanning and enforce partial correctness (format checks, placeholder detection, JSON validation, file existence/size, score computation). citeturn18view0turn17view2turn18view1turn18view6turn18view2  
- Discovery scripts generate a “DeveloperDNA” snapshot by scanning repos, tools, services, integrations, and company signals. citeturn30view7turn18view4turn42view13  
- Scheduling scripts (cron/launchd) automate periodic runs (monthly rediscovery, auto-improve tasks). citeturn18view7turn42view16turn42view15  

**Layer C: Templates + catalogs (“the knowledge base”)**
The repo contains catalogs and templates for subagents, soft skills, format references, and integration recommendations (visible in the skill’s references directory and template folders). citeturn31view0turn34view0turn33view0  

### Data flows (fact + inference)
A typical scaffold run (as described by SKILL.md) follows:
1. Heuristic scan produces a ProjectProfile JSON. citeturn18view0turn30view3  
2. Opportunity detection suggests subagents/skills/integrations. citeturn17view2turn30view6  
3. Subagents analyze repo deeply and recommend “official first” plugins/MCP servers. citeturn30view3  
4. Generation emits files for Claude Code, Cursor, and Codex formats, then validates and scores output. citeturn30view3turn30view4turn18view1turn18view6  

The deterministic scripts can catch obvious “AI slop” (placeholders, too-short CLAUDE.md, invalid JSON) but cannot fully guarantee semantic correctness (e.g., validated commands actually run) without executing real builds/tests. (Inference based on the nature of checks described in `score.sh` and `validate.sh`.) citeturn18view1turn18view6turn42view4  

## Code quality and maintainability assessment

**5. Code quality and maintainability assessment**

### Strengths (facts)
- There is explicit emphasis on **format compliance** and **avoiding placeholders/hallucinations**, with scoring rules and eval assertions repeatedly referencing these failure modes. citeturn18view1turn42view4turn28view1  
- The repo includes a relatively detailed **evaluation contract** (`evals.json`) with assertions covering presence/size/content patterns for generated outputs, plus integration detection and minimal-mode expectations. citeturn28view1turn26view0turn46view0  
- The discovery orchestrator demonstrates a practical implementation detail: concurrency via parallel script execution, and a documented performance target. citeturn18view4turn42view13turn30view7  

### Weaknesses and maintainability risks (facts + inference)
- **Prompt complexity concentration:** The single SKILL.md file is very large and acts as a “program.” This is inherently harder to test and refactor than code with typed interfaces. (Inference; the file’s role and breadth is explicit.) citeturn30view3turn30view4  
- **Format drift exposure:** Cortex depends on external tool formats (Claude Code hooks/events; Cursor rules conventions). These ecosystems evolve; prompt + templates will drift unless continuously maintained. (Inference, supported by reliance on hooks and Cursor rules.) citeturn45search0turn45search3  
- **Platform constraints:** The scripts are bash-centric and clearly target macOS/Linux scheduling (launchd/cron). Windows-first environments will need adaptation. (Inference based on `schedule-autorun` design.) citeturn18view7turn42view16turn42view15  
- **Dependency ambiguity:** Some scripts and features assume `python3`/`node` availability for JSON validation and parsing (explicit in scoring and the auto-research toolchain). If absent, tests/scoring can degrade. citeturn42view2turn36view0turn44view9  

**9. Pros and cons**

Pros (grounded in repository evidence):
- Strong “official first” stance (reduce reinventing/duplicating official tooling) is explicitly enforced as a principle in the scaffold prompt. citeturn30view3  
- Includes automated scoring and an eval contract, which is more disciplined than ad-hoc “generate a CLAUDE.md once” approaches. citeturn18view1turn18view2turn28view1  
- Discovery + user-level generation is an ambitious attempt to separate **user-level** vs **project-level** patterns. citeturn30view7turn26view0  
- MCP configuration is handled with env placeholders (e.g., `${GITHUB_TOKEN}`), which is a safer baseline than hardcoding secrets. citeturn43view0turn26view0  

Cons (grounded + inference):
- Core behavior depends on LLM compliance with the SKILL prompt; deterministic scripts mostly validate *structure*, not fully *semantic accuracy*. citeturn18view1turn18view6turn30view3  
- Some eval expectations are inherently non-deterministic (“output contains …”, “offers to fix issues”), which can’t be fully verified without live runs. (Inference; the eval file includes output expectations and output-based assertions.) citeturn26view2turn46view0  
- The system could generate “too much” scaffolding (agents/rules/skills sprawl) if signals are overly sensitive or if the user runs `--all` frequently. (Inference; interactive selection exists specifically to mitigate over-generation.) citeturn30view0turn26view0  

**10. Risks and red flags**

Key risks (facts + inference):
- **Hook execution risk:** Claude Code hooks run arbitrary shell commands; any generated or installed hooks must be treated like code execution configuration. Cortex ships hooks that execute command strings (e.g., sending reminders or checking scores). citeturn21view1turn44view1turn45search0turn45search4  
- **Machine-wide scanning privacy risk:** “discover” scans directories such as `~/Documents`, `~/workspace`, `~/projects`, etc., and produces a profile. Even if “local only,” it can still capture sensitive metadata into output files (repo names, possibly remotes). citeturn30view7turn18view4turn45search15  
- **Scheduled automation risk:** The scheduling script can install periodic jobs via cron/launchd; this increases the risk of unattended execution, unexpected CPU usage, or accidental disclosure if logs/outputs are stored in shared locations. citeturn18view7turn42view16turn42view15  
- **Supply-chain exposure via `npx`:** The default MCP config uses `npx -y @modelcontextprotocol/server-github`; this is convenient but inherits npm supply-chain risk and requires careful version pinning if used in sensitive environments. citeturn43view0turn45search9  
- **Documentation drift:** The presence of evolving eval specs alongside a README claiming a specific assertion count is a subtle red flag for “truth is in code, not docs.” citeturn2view0turn46view0  

## Similar projects and usefulness assessment

**6. Similar/competing projects with comparison table**

The core problem Cortex addresses—**generating agent instructions and rules from a repo**—has multiple adjacent solutions:
- Claude Code has established concepts like hooks and repository-scoped memory files, and multiple guides/tools exist to generate CLAUDE.md quickly (including `/init` as a baseline approach per third-party guidance). citeturn45search0turn45search22  
- Cursor has an official rules system, and a small ecosystem of rule generators exists. citeturn45search3turn45search7turn45search16turn45search11  
- MCP has official/community server catalogs and package distributions. Cortex packages MCP suggestions/config generation into scaffolding, but MCP itself is not unique to Cortex. citeturn45search1turn45search13turn45search9  

### Comparison table

| Project / approach | What it covers | How it works | Where it’s stronger than Cortex | Where Cortex is stronger |
|---|---|---|---|---|
| Cortex (this repo) | Claude Code + Cursor rules + Codex-style AGENTS; optional machine-wide “discover”; scoring/evals; prompt optimization loop | Prompt-orchestrated generation + local shell/Python scanners, validators, eval contracts citeturn20view0turn30view3turn18view1turn36view0 | N/A | Multi-tool scaffolding + eval-driven workflow + discovery/scheduling + “official first” policy citeturn30view3turn30view7turn18view7 |
| Claude Code baseline (`/init` + docs/guides) | Primarily CLAUDE.md + built-in workflows; hooks documented | Built-in initialization + documented hooks/events | Lower complexity; fewer moving parts; less “prompt-program” surface citeturn45search0turn45search22 | Cortex aims for deeper repo-specific scaffolding + subagents + cross-tool outputs + eval scoring citeturn20view0turn18view1turn26view2 |
| CLAUDE.md Generator sites | CLAUDE.md only | Form-based template generation | Simple UI; fast start for one file citeturn45search2turn45search10 | Cortex tries to generate a *system* (rules, agents, MCP, hooks) not just a single file citeturn20view0turn30view3 |
| Cursor rules official + rule generators | Cursor rules only | Cursor rules docs + community generators | Official alignment; narrow scope reduces failure modes citeturn45search3turn45search7turn45search16 | Cortex outputs Cursor rules *and* Claude/Codex artifacts while trying to keep them consistent citeturn20view0turn30view3 |
| Hook template repos/guides | Hooks only | Examples and recipes for hooks | Easier to audit; focused on one capability citeturn45search12turn45search4 | Cortex integrates hooks into a larger “setup generator,” including reminders and scoring nudges citeturn44view1turn21view1 |
| MCP server catalogs | MCP servers only | Reference implementations + examples | Authoritative catalogs; broader server coverage citeturn45search1turn45search13 | Cortex tries to choose MCP servers based on repo/service detection and integrate them into scaffolding citeturn30view3turn43view0 |

**7. Usefulness assessment**

Cortex is **useful if—and only if—your workflow already depends on AI coding agents** and you believe that better repo-specific context files + rules + subagents will measurably reduce iteration time.

Where it is genuinely valuable (inference grounded in design):
- If your team spends time repeatedly recreating “how to work in this repo” prompts, a generated CLAUDE.md + structured rules can create consistent baselines. citeturn30view3turn18view6turn45search22  
- If you actively use hooks, MCP servers, and subagents, the “scaffold” concept can compress setup time and encourage safer habits (e.g., running tests, not editing fixtures). citeturn21view1turn43view0turn45search0  
- The eval/scoring layer is a meaningful differentiator: it encourages iteration and regression detection for prompt outputs rather than relying purely on subjective quality. citeturn18view1turn18view2turn28view1turn36view0  

Where it may be low-value or redundant (inference):
- If you only need a CLAUDE.md, simpler generators or built-in initialization are likely enough. citeturn45search2turn45search22  
- If your environment is Cursor-only, a Cursor rules generator is simpler and more directly aligned with Cursor’s rules system. citeturn45search3turn45search7turn45search16  

## Use cases, recommendations, and final verdict

**8. All possible use cases and scenarios**

### Realistic use cases
- **Bootstrap a new repo’s AI setup:** Generate CLAUDE.md + safety rules + a couple of high-leverage subagents (test-runner, lint-format). citeturn30view0turn18view6  
- **Standardize a team’s multi-tool configs:** Emit both Claude Code artifacts and Cursor rules so different team members get consistent constraints and conventions. citeturn20view0turn45search3  
- **Audit and clean up existing AI config sprawl:** Run audit mode to detect stale/duplicate rules, skills referencing commands that don’t exist, or MCP servers that don’t match the repo. citeturn28view1turn26view0  
- **Build a machine-wide developer profile (“discover”):** Scan local repos, detect common patterns, and generate a global user-level setup under `~/.claude/` (with explicit confirmation prompts in the workflow). citeturn30view7turn26view0  
- **Iteratively improve prompt quality:** Use the auto-research loop to propose prompt edits and measure improvements against fixtures and expectations. citeturn36view0turn44view5turn44view11  

### Edge cases
- **Very large monorepos:** The eval spec explicitly calls out monorepo detection and expects monorepo-aware guidance. In practice, monorepos often break “single CLAUDE.md fits all,” so agent routing and scoped instructions become critical. citeturn46view0turn28view1  
- **Polyglot repos with multiple build systems:** Heuristic scanners can detect multiple extensions, but the prompt must avoid generating wrong commands/framework assumptions; this is exactly the hallucination risk the repo tries to mitigate with scoring/validation. citeturn18view0turn18view1turn42view4  
- **Repos with no tests/lint:** Cortex may still generate rules/hooks if it “detects” tooling incorrectly (false positives). Mitigation depends on the “official first / don’t invent commands” policy being followed. citeturn30view3turn42view4  
- **Environments without Python/Node:** Some checks rely on python/node for JSON validation (score.sh) or for parsing JSON for eval runners and discovery merging, which can reduce functionality if absent. citeturn42view2turn18view2turn18view4  

### Failure scenarios
- **Incorrect commands in generated files:** This is the primary failure mode for prompt-based scaffolders; structural checks cannot guarantee commands truly run. citeturn18view1turn30view3  
- **Overwriting existing user customizations:** SKILL.md instructs not to blindly overwrite and to merge, but success is LLM-dependent and must be reviewed carefully. citeturn30view3  
- **Hook misconfiguration:** Incorrect hooks can block edits, spam notifications, or run costly commands at the wrong time; hooks are code execution config. citeturn45search4turn21view1turn45search0  
- **Discover producing sensitive “profile artifacts”:** Even if local-only, outputs may store sensitive repo metadata; scheduled jobs can keep updating that profile without a user noticing. citeturn30view7turn18view7turn42view15  

**11. Improvement recommendations**

High-impact improvements (inference grounded in observed risks and architecture):
- **Make evaluation claims self-verifying:** The README should be generated or updated from running the eval runner, so “assertion counts” and pass rates can’t drift. citeturn2view0turn18view2turn46view0  
- **Separate “policy” from “mechanism”:** Break the monolithic SKILL.md into smaller composable modules (still assembled for the agent), and add versioning around tool format references to mitigate drift. citeturn30view3turn31view0  
- **Harden “don’t invent commands” guarantees:** Add an optional *execution verification mode* that runs candidate commands in a safe way (e.g., `--help`, `--version`, or dry-run patterns) and records results, rather than only checking for placeholders. (This is beyond current static checks.) citeturn42view4turn18view1  
- **Improve supply chain safety:** For the default `.mcp.json`, provide guidance on pinning versions / using lockfiles or local installs instead of `npx -y` for sensitive contexts. citeturn43view0turn45search9  
- **Add “privacy budget” controls for discover:** Provide explicit redaction controls and clear documentation of what fields are captured, especially around git remotes and project paths, and ensure scheduled tasks default to “off.” citeturn30view7turn18view7turn42view15  
- **Make Windows support explicit:** Either document “macOS/Linux only” or add PowerShell equivalents where feasible, especially if adoption is a goal. citeturn18view7turn42view16turn42view15  

**12. Final verdict**

Cortex is **promising but inherently brittle**:
- **Promising** because it combines multi-tool scaffolding, local heuristics, rules/hooks, MCP integration, and eval-driven iteration into a coherent system. citeturn20view0turn30view3turn18view1turn45search1  
- **Brittle** because the “core logic” is prompt-driven and must continuously track evolving agent tool formats (hooks, Cursor rules). Without continuous maintenance and strict evaluation discipline, it risks becoming a generator of plausible-but-wrong scaffolding files. citeturn45search0turn45search3turn18view1  
- **Not redundant**, but also **not fundamentally novel**: there are many CLAUDE.md generators and Cursor rules generators; Cortex’s novelty is mainly in the **integrated, eval-and-improve workflow** and the **“discover” cross-project profiling concept**. citeturn45search2turn45search7turn36view0turn30view7  

**13. Confidence level and open questions**

**Confidence level:** **Medium (≈0.72)**. I can verify repository structure, scripts, configs, and stated workflows, but I cannot fully verify real-world effectiveness without executing scaffold runs across diverse repos and measuring correctness of generated commands and rules. citeturn30view3turn18view2turn36view0  

**Open questions (what could not be fully verified statically):**
- Do the evals “pass” end-to-end in a clean environment, including cases that require live run outputs (e.g., audit report content)? citeturn18view2turn46view0  
- How often do generated commands actually match the repo’s real scripts and toolchain in non-fixture repos? (This is the hardest part for any prompt-driven scaffolder.) citeturn30view3turn18view1  
- What is the update strategy for keeping Claude Code hooks and Cursor rules formats current as official docs evolve? citeturn45search0turn45search3turn31view0  
- Is “discover” acceptable in privacy-sensitive environments, and are there strong defaults to prevent accidental scheduled profiling? citeturn18view7turn42view15turn30view7  

