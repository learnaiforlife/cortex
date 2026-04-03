# Cortex Deep Audit and Research Report

Based on a thorough analysis of the Cortex repository's code, scripts, subagent prompts, and documentation.

## 1. Executive Summary
Cortex is an ambitious, agentic meta-tool designed to automate the configuration of AI coding assistants (Claude Code, Cursor, and Codex). Instead of relying on generic templates, it uses a swarm of parallel subagents to deeply analyze a specific codebase and generate tailored instructions, rules, and skills. Its standout feature is an "autoresearch-inspired" self-improvement loop that allows its own prompts and generated skills to iteratively evolve based on quantitative scoring. While likely expensive in token usage and reliant on some brittle bash scripts, it represents a cutting-edge approach to AI developer experience (DevX).

## 2. What the Project Is
Cortex acts as an "intelligence layer" for AI-powered development. It is primarily built as a plugin/skill for Anthropic's Claude Code CLI. When pointed at a local directory or GitHub URL, it acts as an orchestrator, dispatching specialized AI subagents to read the code, understand the architecture, and generate the necessary configuration files (`CLAUDE.md`, `.cursorrules`/`.mdc`, `AGENTS.md`, and MCP server configs) so that your AI IDEs immediately understand how to work within that specific project.

## 3. What the Code Actually Does
The implementation is a mix of Markdown-based prompt engineering, Bash scripting, and Python:
*   **Installation (`install.sh`)**: Copies the Cortex orchestration skill into the user's `~/.claude/skills/` directory and sets up command aliases (`/scaffold`).
*   **Heuristic Pre-scan (`analyze.sh`)**: A pure bash script that quickly counts file extensions and detects key config files (e.g., `package.json`, `docker-compose.yml`) to build a lightweight JSON profile of the project.
*   **Orchestration (`SKILL.md`)**: The master prompt that dictates the workflow. It clones the target repo (if a URL is provided), runs the pre-scan, and dispatches parallel subagents (`repo-analyzer` and `skill-recommender`).
*   **Quality Gating (`quality-reviewer.md` & `score.sh`)**: Before writing any files, a reviewer agent checks the output for hallucinations, placeholders, and YAML validity. A bash script (`score.sh`) assigns a hard 0-100 quantitative score based on format compliance, specificity, completeness, and structural quality.
*   **Self-Improvement Loop (`run.py` & `auto-improve.sh`)**: An autonomous Python/Bash engine that allows Cortex to edit its own subagent prompts, run evaluations against test fixtures, measure the new score, and keep the changes only if the score improves.

## 4. Technical Architecture and Main Components
*   **Master Orchestrator**: The `scaffold` skill that manages the pipeline.
*   **Subagent Swarm**: 7 specialized markdown files defining agents with specific tools, models (mostly `sonnet` and `haiku`), and instructions (e.g., `repo-analyzer`, `codex-specialist`, `setup-auditor`).
*   **Reference Catalogs**: Markdown files containing lists of official Claude plugins and MCP servers. Cortex checks these *first* to avoid generating redundant custom skills.
*   **Eval Suite**: Test fixtures (e.g., a minimal Next.js app) used to baseline and measure the quality of the generated scaffolding.

## 5. Code Quality and Maintainability Assessment
*   **Prompt Engineering**: Excellent. The prompts are highly structured, utilize clear fallback chains, and enforce strict formatting rules.
*   **Scripting**: Moderate to Poor. The project relies heavily on Bash (`score.sh`, `analyze.sh`) to parse JSON and evaluate Markdown structures (using `grep` and `awk`). This is brittle and prone to breaking if the LLM slightly alters its output formatting.
*   **Python Engine**: Good. The `claude-code-auto-research` loop is clean, modular, and safely handles state rollbacks if an optimization fails.
*   **Maintainability**: The reliance on LLM instruction-following for complex multi-file generation is inherently flaky, but the project mitigates this brilliantly with the `quality-reviewer` gate and quantitative scoring.

## 6. Similar/Competing Projects

| Feature | Cortex | Cursorrules.com / Templates | GitHub Copilot Setup |
| :--- | :--- | :--- | :--- |
| **Approach** | Dynamic, repo-specific analysis | Static copy-pasting | Generic instructions |
| **Multi-Tool** | Yes (Claude, Cursor, Codex) | No (Cursor only) | No (Copilot only) |
| **Quality Gates** | Yes (Subagent review + scoring) | No | No |
| **Self-Improving**| Yes (Autoresearch loop) | No | No |
| **Cost** | High (Multiple LLM calls) | Free | Free |

## 7. Usefulness Assessment
**Highly Useful.** Writing comprehensive, project-specific AI rules is tedious. Developers often skip it, leading to AI assistants hallucinating commands or breaking project conventions. Cortex automates this entirely. Its "official-first" philosophy (recommending existing plugins before generating custom ones) proves the author understands the danger of prompt/skill bloat. 

## 8. Use Cases, Edge Cases, and Scenarios
*   **Ideal Use Case**: A dev agency onboarding contractors to a complex monorepo. Running `/scaffold` generates the exact rules the contractors' AI tools need to avoid breaking the build.
*   **Maintenance Use Case**: Running `/scaffold audit` on a legacy project to find stale AI instructions (e.g., rules referencing a database that was migrated away from).
*   **Edge Case (Monorepos)**: Massive monorepos might cause the `repo-analyzer` to hit context limits or timeout before it can map the whole architecture.
*   **Failure Scenario (Mode Collapse)**: The `auto-improve` loop relies on `score.sh`. Because `score.sh` uses regex to check for quality, the AI might learn to "game the metric" (e.g., generating nonsense that happens to pass the regex checks) rather than actually improving the prompt.

## 9. Pros and Cons
**Pros:**
*   Eliminates the boilerplate of configuring AI IDEs.
*   Supports the three major AI coding tools simultaneously.
*   The quantitative scoring and self-improvement loop is a highly advanced, novel application of agentic workflows.
*   Prevents bloat by checking official plugin catalogs first.

**Cons:**
*   **Token Heavy**: Running 7 subagents to analyze a repo will consume a massive amount of tokens, making it expensive to run frequently.
*   **Execution Time**: The parallel processing and quality review steps mean scaffolding will take several minutes.
*   **Brittle Bash**: The scoring logic is vulnerable to slight formatting changes.

## 10. Risks and Red Flags
*   **Cost**: Users unaware of API pricing might rack up significant bills running this on large repositories.
*   **Security**: The `quality-reviewer` is instructed to fail if it sees API keys, but LLMs are not foolproof security scanners. Generated files might accidentally include sensitive data scraped from `.env.example` files or hardcoded test credentials.
*   **Dependency on Claude Code**: The orchestration relies entirely on Anthropic's Claude Code CLI. If Anthropic changes their plugin architecture, Cortex breaks.

## 11. Improvement Recommendations
1.  **Rewrite Bash in Python/Node**: Replace `score.sh` and `analyze.sh` with a robust script that uses proper AST parsing for Markdown and actual JSON parsers.
2.  **Structured Outputs**: Force the subagents to use JSON Schema (Structured Outputs) instead of relying on the `quality-reviewer` to catch YAML formatting errors.
3.  **Token Budgeting**: Add a "lite" mode that skips the deep `repo-analyzer` and relies only on the heuristic bash scan for smaller projects to save money.
4.  **Support Windsurf**: Add support for `.windsurfrules`.

## 12. Final Verdict
**Promising and Novel.** Cortex is not just another wrapper; it is a sophisticated meta-tool that treats AI configuration as code that can be generated, tested, and optimized. While the underlying bash scripts are a bit hacky and the token cost will be high, the architectural design—specifically the quality gates and the autoresearch loop—is exceptional. 

## 13. Confidence Level and Open Questions
*   **Confidence Level**: 9/10. (Based on deep inspection of the orchestration prompts, scoring scripts, and Python optimization engine).
*   **Open Questions**: How often does the `quality-reviewer` hallucinate a pass on a bad file? What is the real-world token cost of running `/scaffold` on a medium-sized repository like Next.js?

---

## Summary Explanations & Scores

**Plain-English Explanation:**
Cortex is a tool that looks at your code and automatically writes the instruction manuals for your AI assistants (like Cursor or Claude). Instead of you having to manually tell the AI "we use npm, not yarn" or "don't edit these files," Cortex figures it out and writes the rules for you. It even has a feature where it grades its own work and tries to rewrite its own brain to get a better score next time.

**Technical Explanation:**
Cortex is an orchestration skill for the Claude Code CLI. It utilizes a Map-Reduce agentic pattern: it clones a target repository, runs a heuristic bash script to generate a project profile, and dispatches parallel LLM subagents to analyze the AST/architecture and cross-reference official plugin catalogs. The reduced output is passed to a Quality Gate subagent that validates YAML frontmatter and checks for hallucinations. Furthermore, it implements an autonomous optimization loop (inspired by Karpathy's autoresearch) that mutates subagent system prompts, runs them against test fixtures, and commits the prompt changes only if a deterministic bash-based scoring function yields a higher score.

**Who should use this:**
*   DevOps/Platform engineers standardizing AI tooling across a company.
*   Developers who frequently jump between different tech stacks and open-source projects.
*   AI workflow researchers interested in self-improving prompt loops.

**Who should avoid this:**
*   Developers working on tiny, single-file scripts where a full AI setup is overkill.
*   Teams with strict data exfiltration policies (as this sends large chunks of codebase architecture to LLM APIs).
*   Users on strict API token budgets.

**Scores (1-10):**
*   **Usefulness**: 8/10 (Solves a real pain point, but is heavy).
*   **Originality**: 9/10 (The self-improving autoresearch loop applied to prompt engineering is highly novel).
*   **Maintainability**: 5/10 (Heavy reliance on bash regex to parse LLM markdown output).
*   **Adoption Potential**: 7/10 (Great for power users, but requires Claude Code CLI to orchestrate, limiting its reach to purely Cursor/Codex users).
