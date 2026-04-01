# Optimization Program

## Objective
Improve the quality-reviewer subagent's ability to catch hallucinated content while avoiding false positives on valid project-specific content.

## Target
../skills/scaffold/agents/quality-reviewer.md

## Test Against
- ../test/fixtures/nextjs-app
- ../test/fixtures/python-api
- ../test/fixtures/minimal

## Key Metrics
- Expectation pass rate on "quality-gate-catches-hallucination" eval
- No false positives (don't reject valid content like Prisma references in a Next.js project)
- Structural correctness of PASS/FAIL verdicts

## Constraints
- Max 10 iterations per session
- Keep prompt under 200 lines
- Don't change the PASS/FAIL output format (other tools depend on it)
- Don't add external dependencies

## Strategy
Focus on improving detection of:
1. Hallucinated MCP servers (recommending servers for services not in the project)
2. Non-existent commands referenced in generated skills
3. Placeholder/TODO content that should never appear in output
4. Framework mentions that don't match actual project dependencies

## Stop Conditions
- All targeted eval expectations pass across all fixtures
- No improvement for 3 consecutive iterations
- Time budget exhausted
