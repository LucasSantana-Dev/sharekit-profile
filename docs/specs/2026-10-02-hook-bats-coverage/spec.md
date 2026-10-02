---
status: draft
created: 2026-10-02
owner: Lucas Santana
issue: 127
tags: [tests, hooks, bats]
---

# Bats coverage for untested hooks (issue #127)

## Problem
32 of 50 `hooks/*.sh` are never named in any `tests/*.bats` (measured 2026-10-02 by basename grep). All P8+P9 hooks are among them.

## Slices (one PR each)
1. **Gate/security (this PR):** `checklist-gate`, `transcript-scanner`, `trial-apply`, `policy-gate`.
2. Context lifecycle: `snapshot-compact`, `reinject-compact`, `reorder-context`, `session-start-load`, `session-end-flush`, `compaction-guard`, `context-guard`.
3. Eval/loop: `eval-baseline`, `eval-tasks`, `textgrad`, `reflect-retry`, `tool-shortlist`, `trajectory-log`, `trajectory-seed`, `cycle`, `deploy-watch`.
4. Remainder.

## Acceptance (slice 1)
- New `tests/gate-hooks.bats`, hermetic (tmpdir, no network, no writes outside `$BATS_TEST_TMPDIR`), bash 3.2 compatible.
- Per hook: at least one allow/pass case, one block/fail case, one malformed or empty input case, asserting exit code and key output.
- `bats tests/` passes locally; no hook source modified. A bug found goes in the PR body, not a silent fix.
- Basename grep count of untested hooks drops from 32 to 28.

## Out of scope
Changing hook behavior, slices 2-4, coverage tooling.
