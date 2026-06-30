---
name: backend-testing
description: Comprehensive backend testing guidance for unit, integration, authentication,
  and API flows across Node.js and Python stacks. Use when writing or reviewing backend
  tests and the task needs realistic coverage, isolation strategy, or framework-specific
  examples.
tags:
- testing
- backend
- unit-test
- integration-test
- API-test
- Jest
- Pytest
- TDD
platforms:
- Claude
- ChatGPT
- Gemini
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/backend-testing
  progressive_disclosure: split
---













# Backend Testing

Use this skill to turn backend behavior into tests that prove real user value instead of just increasing line count.

## Inputs / Prereqs

- Know the backend stack, test runner, and the behavior under test.
- Identify whether the need is unit, integration, auth, API, or troubleshooting guidance.
- Load only the relevant reference file for the active testing problem.

## Workflow

1. Start from the business behavior or failure mode that matters.
2. Choose the smallest realistic test level that can prove it.
3. Pull the matching reference for workflow, examples, or troubleshooting.
4. Finish with coverage that reflects real flows, not trivial getters or enums.

## Outputs / Evidence

- Concrete test guidance, examples, or changes tied to the requested backend behavior.
- The intended isolation level, fixtures or mocks, and coverage target.
- Any known risk that still needs integration or end-to-end validation.

## Failure / Stop Conditions

- Do not optimize for synthetic coverage instead of meaningful behavior.
- Do not over-mock the system boundaries that actually need verification.
- Do not suggest fragile shared-state patterns between tests.

## Load These Resources

- [workflow-and-constraints.md](./references/workflow-and-constraints.md)
- [examples.md](./references/examples.md)
- [practice-and-troubleshooting.md](./references/practice-and-troubleshooting.md)

## Memory Hooks

- Read memory when the repo already has testing conventions, fixture patterns, or known flake history.
- Write memory only when the session establishes a durable testing policy or anti-pattern.
