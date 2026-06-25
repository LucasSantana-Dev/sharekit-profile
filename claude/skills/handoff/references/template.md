# Handoff Packet Template

Output file: `~/.claude/handoffs/<project>/latest.md`

Use this exact structure. Fill each section with 1–3 sentences of specifics.

---

## Active Objective

One sentence. What are you finishing or resuming?

Example: "Finishing JWT refresh middleware for POST /auth/login; tests passing, ready for integration test before merge."

## Repo, Branch, Worktree

Exact paths. Include worktree parent if inside `.worktrees/`.

Example:
```
Repo: ${DEV_ROOT}/myapp
Branch: feat/auth-refresh
Worktree: ${DEV_ROOT}/.worktrees/auth-refresh-task-1/
```

## What Changed

File paths touched (with line ranges for key edits, no full file dumps).

Example:
```
- src/middleware/jwt-refresh.ts (NEW, 1–85)
- src/routes/auth.ts (modified POST /auth/login, 42–67)
- tests/auth.integration.test.ts (added test case for 401 → 200 flow, 120–150)
```

## What Was Verified

Blockers cleared, tests passing, decisions confirmed.

Example:
```
- Unit tests: 24/24 passing (jest src/middleware/*.test.ts)
- Integration test: POST /auth/login with expired token → 200 (curl command in next-action)
- Design decision: sessionless (JWT only, no server-side session store) ✓ per ADR-0015
- Deployment: staging branch merges cleanly to main
```

## What Remains

Next 2–3 steps, in order. Be concrete.

Example:
```
1. Run full integration suite on staging (npm run test:integration)
2. Merge to main (git merge feat/auth-refresh, no force)
3. Deploy to production via CI gate (usual Vercel workflow)
```

## Blockers + Gates

Anything blocking next action; what condition unblocks it.

Example:
```
BLOCKER: Code review from @teammate (PR #1234 open, awaiting approval).
UNBLOCK: Once approved, merge → triggers CI → auto-deploy to staging.

GATE: All tests must be green on main before production deploy.
STATUS: 24/24 passing; green light cleared.
```

## Exact Next Action

Copy-pasteable command or skill invocation. Test it in the current session if possible.

Example:
```bash
cd ${DEV_ROOT}/myapp && \
  npm run test:integration && \
  git merge feat/auth-refresh && \
  git push origin main
```

Or:

```
Invoke: /ship
(verifies CI passing, merges PR #1234, triggers production deploy)
```

## Key Anchors

PR/issue URLs, commit SHAs, decision links (ADRs, memory), diagnostic tools.

Example:
```
PR: https://github.com/yourorg/myapp/pull/1234
Latest commit: abc1234def567 (Add JWT refresh middleware)
ADR: ADR-0015 Sessionless Auth Design
Memory: https://vault.your-knowledge-brain.com/adr-0015
Diagnostic: Ran `npm run test:health` on 2026-06-22 — all gates green
```

---

## Anti-patterns to avoid

- ❌ "Fixed auth stuff" — no specifics; receiver has to rediscover
- ❌ Whole `package.json` or `.env.example` dumped — link to file + line range instead
- ❌ "Will do next steps when I have time" — you own the next action; be specific and testable
- ❌ Vague gates: "waiting for review" — add the PR URL and approval condition
- ❌ Packets >2000 words — break into sub-packets or reference external ADRs
