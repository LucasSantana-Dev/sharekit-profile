# Handoff: billing retry queue

## Active Objective
Finish retry queue for failed invoice webhooks in acme/billing-svc.

## Repo, Branch, Worktree
Repo: ${DEV_ROOT}/billing-svc
Branch: feat/webhook-retry

## What Remains
- Integration test for backoff cap (tests/retry.integration.test.ts:88)
- Open PR after test is green

## Blockers
- CI job `ci / integration` fails: redis service container not starting (workflow .github/workflows/ci.yml:41)

## ⚡ IMPLEMENT THIS
1. Pin redis image to 7.2 in .github/workflows/ci.yml:44 and rerun ci / integration.
2. Add backoff cap test in tests/retry.integration.test.ts:88.
3. Open PR against main.

## Decisions
- Exponential backoff, cap 5 min, per ADR-0021.
