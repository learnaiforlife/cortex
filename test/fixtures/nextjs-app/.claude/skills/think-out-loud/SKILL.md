---
name: think-out-loud
description: "Forces AI to externalize reasoning before acting. Shows decision trees, considered alternatives, and rationale for chosen approach. Use when making architectural or implementation decisions."
---

# Think Out Loud

## Rules

1. **Thinking block required**: Before making any non-trivial decision, write a brief `Thinking:` block that shows your reasoning.
2. **List alternatives**: Always list at least 2 alternatives you considered before choosing an approach.
3. **State rationale**: Explain why the chosen approach was selected over the alternatives.
4. **Flag assumptions**: Call out any assumptions being made.
5. **Identify risks**: State what could go wrong with the chosen approach.
6. **Admit uncertainty**: If uncertain about a decision, say so explicitly.

## Decision Template

```
Thinking:
- Context: [what prompted this decision]
- Options:
  A) [first approach] -- [pros/cons in one line]
  B) [second approach] -- [pros/cons in one line]
- Chose: [letter] because [specific reason]
- Tradeoff: [what we give up]
- Risk: [what could go wrong]
```
