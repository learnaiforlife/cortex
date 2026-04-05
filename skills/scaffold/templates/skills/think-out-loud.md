---
name: think-out-loud
description: "Forces AI to externalize reasoning before acting. Shows decision trees, considered alternatives, and rationale for chosen approach. Use when making architectural or implementation decisions."
---

# Think Out Loud

## Rules

1. **Thinking block required**: Before making any non-trivial decision, write a brief `Thinking:` block that shows your reasoning.
2. **List alternatives**: Always list at least 2 alternatives you considered before choosing an approach.
3. **State rationale**: Explain why the chosen approach was selected over the alternatives. Be specific -- "it's simpler" is not enough; say what makes it simpler.
4. **Flag assumptions**: Call out any assumptions being made. Mark them clearly so they can be validated.
5. **Identify risks**: State what could go wrong with the chosen approach and under what conditions.
6. **Admit uncertainty**: If uncertain about a decision, say so explicitly and explain what information would resolve the uncertainty.

## Decision Template

Use this format before any significant decision:

```
Thinking:
- Context: [what prompted this decision]
- Options:
  A) [first approach] -- [pros/cons in one line]
  B) [second approach] -- [pros/cons in one line]
  C) [third approach, if applicable] -- [pros/cons in one line]
- Chose: [letter] because [specific reason]
- Tradeoff: [what we give up by not choosing the other options]
- Assumption: [what we're assuming to be true]
- Risk: [what could go wrong and when we'd revisit this decision]
```

## When to Use Thinking Blocks

**Always use** for:
- Choosing between libraries or frameworks
- Designing data models or schemas
- Selecting API patterns (REST vs GraphQL, sync vs async)
- Deciding on error handling strategies
- Structuring code across files or modules
- Choosing between performance and readability
- Any decision that would be hard to reverse

**Skip** for:
- Variable naming (unless it affects public API)
- Import ordering
- Formatting choices covered by linters
- Obvious single-option situations

## Example

```
Thinking:
- Context: Need to add real-time updates to the dashboard
- Options:
  A) WebSockets -- full duplex, but adds infrastructure complexity (need WS server, connection management)
  B) Server-Sent Events -- simpler, one-way, works over HTTP, but no client-to-server channel
  C) Polling every 5s -- simplest, no new infra, but wastes bandwidth and has latency
- Chose: B because updates are server-to-client only, SSE works over existing HTTP infra, and auto-reconnect is built into the EventSource API
- Tradeoff: If we later need client-to-server real-time (e.g., collaborative editing), we'll need to migrate to WebSockets
- Assumption: Update frequency is low enough (< 1/second) that SSE overhead is acceptable
- Risk: If we need to support IE11 or certain corporate proxies, SSE may not work -- would fall back to polling
```

## Placeholders

None — this template has no configurable placeholders.
