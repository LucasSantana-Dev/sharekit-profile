# Handoff: auth token rotation
## Active Objective
Ship refresh token rotation for acme/auth-api.
## Repo, Branch, Worktree
Repo: ${DEV_ROOT}/auth-api  Branch: feat/token-rotation
## What Changed
- src/tokens/rotate.ts (NEW, 1-120)
- src/routes/refresh.ts (modified, 30-75)
- migrations/0042_refresh_family.sql (NEW)
- tests/rotate.test.ts (NEW, 1-200)
## What Was Verified
- Unit: 41/41 passing
- Reuse detection: replayed token revokes family (tests/rotate.test.ts:150)
- Design: rotation window 30s per ADR-0033
## What Remains
- Load test refresh endpoint at 200 rps
- Update OpenAPI spec docs/openapi.yaml:310
- Rollout flag ROTATE_REFRESH=1 in staging
## Blockers
- Staging DB migration 0042 needs DBA approval (ticket SEC-118), not yet granted
## ⚡ IMPLEMENT THIS
1. Update docs/openapi.yaml:310 with the rotated refresh response.
2. Run k6 load test scripts/load/refresh.js and record p95 in the PR.
3. Ping SEC-118 for migration approval, then flip the staging flag.
## Decisions
- Family revocation instead of single token revoke (ADR-0033).
- No sliding expiry, fixed 30 day cap.
## Notes
- Do not touch src/legacy/session.ts, scheduled for removal.
- k6 install is via brew, not npm.
