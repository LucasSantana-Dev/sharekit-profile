# Handoff: billing retry queue
## Active Objective
Finish retry queue for failed invoice webhooks.
## Blockers
- ci / integration fails: redis container not starting
## ⚡ IMPLEMENT THIS
1. Pin redis image to 7.2 in .github/workflows/ci.yml:44
2. Add backoff cap test in tests/retry.integration.test.ts:88
