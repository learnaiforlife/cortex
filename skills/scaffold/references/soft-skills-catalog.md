# Soft Skills Catalog

Non-code productivity skills that improve AI output quality and decision-making. The opportunity-detector subagent reads this file to determine which soft skills to suggest based on project characteristics.

These skills do not run tests, lint code, or produce artifacts. Instead, they shape how the AI thinks, writes, and communicates during development sessions.

---

## Confidence Levels

- **0.9**: Almost always relevant. Suggest unless project is trivially small.
- **0.8**: Relevant for specific domains. Suggest when domain signals are strong.
- **0.7**: Relevant for medium-to-large projects. Suggest when complexity signals match.
- **0.5**: Universally available but low urgency. Mention as an option, do not push.

---

## Skill Catalog

### avoid-ai-slop

| Field | Value |
|-------|-------|
| **ID** | `avoid-ai-slop` |
| **Name** | Avoid AI Slop |
| **Purpose** | Prevents generic, verbose, and filler-heavy AI output in code, comments, documentation, and commit messages. Enforces tight, specific, human-quality writing. |
| **Detection Signals** | `README.md` exists, `docs/` directory exists, more than 5 markdown files in the project, any documentation generation tooling (typedoc, sphinx, mkdocs, docusaurus), comments-heavy codebase |
| **Confidence** | 0.9 |
| **Priority** | Always suggest for non-trivial projects. This is the single highest-impact soft skill for AI-assisted development. |
| **Template Path** | `templates/skills/avoid-ai-slop.md` |
| **Value Proposition** | Prevents generic/verbose AI output -- you get tighter code and docs |

**Why this matters**: Without this skill, AI-generated code tends toward over-commenting, verbose variable names, unnecessary abstractions, and documentation that restates the obvious. This skill enforces discipline: no filler comments, no "This function does X" docstrings that add zero information, no emoji-laden commit messages, no marketing language in technical docs.

**When to skip**: Prototype or throwaway projects where output quality does not matter. Projects with zero documentation needs.

---

### devils-advocate

| Field | Value |
|-------|-------|
| **ID** | `devils-advocate` |
| **Name** | Devil's Advocate |
| **Purpose** | Challenges assumptions, pokes holes in proposed designs, and forces consideration of alternatives before implementation begins. |
| **Detection Signals** | More than 30 source files, microservice architecture (`docker-compose.yml` with 3+ services), monorepo structure (`packages/`, `turbo.json`, `nx.json`, `pnpm-workspace.yaml`), multiple API endpoints or service boundaries, infrastructure-as-code files (Terraform, Pulumi, CDK) |
| **Confidence** | 0.7 |
| **Priority** | Medium-to-large projects where wrong architectural decisions are expensive to reverse. |
| **Template Path** | `templates/skills/devils-advocate.md` |
| **Value Proposition** | Challenges your design assumptions before you build the wrong thing |

**Why this matters**: In complex projects, the cost of a wrong design decision compounds over time. AI assistants tend toward agreement and implementation rather than pushback. This skill forces a structured adversarial review: "What could go wrong?", "What are you assuming that might not be true?", "Is there a simpler approach?"

**When to skip**: Small, well-understood projects. Single-purpose scripts. Projects where the architecture is already locked in and stable.

---

### grill-me

| Field | Value |
|-------|-------|
| **ID** | `grill-me` |
| **Name** | Grill Me |
| **Purpose** | Socratic questioning for high-stakes decisions. Forces thorough requirement analysis before implementation by asking hard, domain-specific questions. |
| **Detection Signals** | Domain keywords in README, package description, or top-level docs: `financial`, `trading`, `healthcare`, `payment`, `security`, `compliance`, `regulatory`, `banking`, `insurance`, `medical`, `HIPAA`, `PCI`, `SOC2`, `GDPR`, `audit`, `encryption`, `authentication`, `authorization` |
| **Confidence** | 0.8 |
| **Priority** | High-stakes domains where bugs have real-world consequences beyond broken UIs. |
| **Template Path** | `templates/skills/grill-me.md` |
| **Value Proposition** | Asks hard questions about your requirements before you start coding |

**Why this matters**: In regulated or high-stakes domains, missing a requirement is not just a bug -- it is a compliance violation, a security breach, or a financial loss. AI assistants default to building what you ask for, not questioning whether what you asked for is correct or complete. This skill forces the uncomfortable questions upfront.

**When to skip**: Projects with no regulatory, financial, security, or safety implications. Internal tools with low blast radius. Learning projects and prototypes.

---

### think-out-loud

| Field | Value |
|-------|-------|
| **ID** | `think-out-loud` |
| **Name** | Think Out Loud |
| **Purpose** | Forces AI to externalize its reasoning chain before taking action. Makes decision points visible so the developer can catch bad logic early. |
| **Detection Signals** | Universal -- applies to any project. No specific signals required. |
| **Confidence** | 0.5 |
| **Priority** | Low. Always available as an option but never pushed. Most useful for developers who want transparency into AI reasoning. |
| **Template Path** | `templates/skills/think-out-loud.md` |
| **Value Proposition** | Shows AI reasoning so you catch bad decisions before they ship |

**Why this matters**: AI assistants sometimes make plausible-sounding but incorrect decisions. Without externalized reasoning, the developer only sees the output -- not the chain of logic that produced it. This skill forces a "thinking step" before action: state assumptions, list options considered, explain why one was chosen.

**When to skip**: Fast-paced prototyping where speed matters more than auditability. Simple tasks where the reasoning is obvious. Developers who prefer concise output over verbose explanations.

---

## Skill Selection Logic

Use this process when deciding which soft skills to recommend:

```
1. ALWAYS check avoid-ai-slop first:
   - If project has README.md, docs/, or >5 markdown files -> suggest (confidence 0.9)
   - If project is non-trivial (>10 source files) -> suggest even without doc signals

2. Check project complexity for devils-advocate:
   - Count source files, check for monorepo/microservice signals
   - If >30 files OR multi-service architecture -> suggest (confidence 0.7)

3. Scan for domain keywords for grill-me:
   - Search README.md, package.json description, top-level docs
   - If ANY high-stakes domain keyword found -> suggest (confidence 0.8)

4. ALWAYS include think-out-loud as an available option:
   - Never push it, but list it in the "also available" section
   - Confidence 0.5 means it shows up last in the recommendation list
```

## Priority Ordering

When presenting soft skill recommendations to the user:

1. **avoid-ai-slop** (0.9) -- suggest first, most universally impactful
2. **grill-me** (0.8) -- suggest second if domain signals match
3. **devils-advocate** (0.7) -- suggest third if complexity signals match
4. **think-out-loud** (0.5) -- mention last as an available option

Never suggest more than 3 soft skills for a single project. If all 4 match, drop think-out-loud from the active suggestions and list it as "also available."
