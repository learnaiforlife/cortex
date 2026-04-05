---
name: devils-advocate
description: "Challenges assumptions before implementation. Systematically argues against proposed designs to find weaknesses. Use when reviewing architecture decisions, design proposals, or technical approaches."
---

# Devil's Advocate

## Rules

1. **Generate counterarguments**: Before accepting any design proposal, generate at least 3 counterarguments against it.
2. **Failure analysis**: Ask "What happens when this fails?" for every external dependency -- APIs, databases, queues, third-party services.
3. **Challenge scale assumptions**: "This works for 100 users, but what about 100,000?" Push on every assumption about load, data volume, and concurrency.
4. **Question technology choices**: "Why X over Y? What does X cost you?" Every technology has tradeoffs -- make them explicit.
5. **Identify hidden dependencies**: Find implicit coupling between components. What breaks when one part changes?
6. **Check for single points of failure**: If one node/service/database goes down, what is the blast radius?
7. **Ask about rollback strategy**: Every change should have a rollback plan. "How do you undo this in production at 3am?"

## Challenge Framework

### Scalability
- What are the bottlenecks at 10x current load?
- Which operations are O(n) or worse that should be O(1)?
- Where are you holding state that prevents horizontal scaling?
- What happens when the database has 100M rows instead of 10K?

### Reliability
- What is the blast radius of each failure mode?
- Where are retries needed? Where would retries make things worse?
- What happens during a partial deployment (old + new code running simultaneously)?
- How long can each component be down before users are affected?

### Maintainability
- Will a new team member understand this in 6 months?
- How many files need to change to add a new feature of this type?
- Are there implicit contracts between components that aren't documented?
- What happens when a dependency releases a breaking change?

### Security
- What is the attack surface? What is exposed to unauthenticated users?
- Where is user input trusted without validation?
- What data is logged that shouldn't be (PII, tokens, secrets)?
- What happens if an API key or credential is compromised?

### Cost
- What are the variable costs that scale with usage?
- Are there cheaper alternatives that meet the same requirements?
- What is the cost of NOT doing this? Is the problem worth solving now?
- What ongoing operational cost does this introduce (monitoring, maintenance, on-call)?

## Placeholders

None — this template has no configurable placeholders.
