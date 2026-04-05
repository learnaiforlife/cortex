---
name: grill-me
description: "Socratic questioning for high-stakes decisions. Asks probing questions about requirements, edge cases, and failure modes before implementation. Use when starting features in financial, healthcare, payment, or compliance domains."
---

# Grill Me

## Rules

1. **Ask before building**: Before implementing any feature, ask at least 5 probing questions. Do not write code until the questions are answered.
2. **Focus on what breaks**: Edge cases, failure modes, regulatory requirements, and data integrity are the priority.
3. **Null/empty/malformed**: "What happens when X is null, empty, zero, negative, or malformed?" Ask this for every input.
4. **Audit trail**: "What are the audit requirements for this operation? Who needs to see what happened and when?"
5. **Rollback plan**: "How do you roll back if this goes wrong in production? Can you reverse the data changes?"
6. **Notification chain**: "Who else needs to be notified when this happens? What downstream systems depend on this?"
7. **Silent failure**: "What's the worst case scenario if this fails silently? How would you even know it failed?"

## Question Categories

### Data Integrity
- What is the source of truth for this data?
- Can this operation be run twice safely (idempotency)?
- What happens if the process crashes mid-operation?
- Are there concurrent writes that could cause race conditions?
- What validation exists at the database level vs application level?

### Error Handling
- What errors can the user recover from vs which are fatal?
- Are errors surfaced to the user or swallowed silently?
- What is the retry strategy? Is it safe to retry?
- How are partial failures handled in multi-step operations?
- What monitoring/alerting exists for this failure mode?

### Security & Auth
- Who is authorized to perform this action?
- Is the authorization check at the right layer (API, service, database)?
- What sensitive data touches this flow? Is it encrypted in transit and at rest?
- Are there rate limits to prevent abuse?
- What happens if a session/token expires mid-operation?

### Compliance
- What regulations apply (GDPR, HIPAA, PCI-DSS, SOX)?
- Is there a data retention policy? When must data be deleted?
- Are there geographic restrictions on where data can be stored or processed?
- What consent is required before collecting or processing this data?
- Is there an audit log that satisfies regulatory requirements?

### Observability
- How do you know this feature is working correctly in production?
- What metrics indicate degradation before users report it?
- Can you trace a single request through the entire system?
- What dashboards or alerts need to be created alongside this feature?
- How do you distinguish between a bug and expected behavior in the logs?

## Placeholders

None — this template has no configurable placeholders.
