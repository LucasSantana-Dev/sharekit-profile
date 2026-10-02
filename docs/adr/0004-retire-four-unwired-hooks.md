# ADR 0004: Retire four unwired hooks, keep the rest of `hooks/`

**Status:** Accepted
**Created:** 2026-10-02
**Owner:** the operator
**Tags:** sharekit-profile, hooks, lean-out

## Context

A harness lean-out asked whether the repo-root `hooks/` directory (49 scripts) should be
retired. `hooks/` is this repo's own dev-time flywheel, documented in the README and
`docs/flywheel.md`, and exercised by `tests/*.bats`, which CI runs.

A reference check across the repo (code, tests, CI, other hooks) found:

- 45 scripts are called by another hook (for example `cycle.sh`, `session-start-load.sh`,
  `claude/hooks/gate.sh`, `claude/hooks/eval-run.sh`), covered by a test, or wired in a
  settings file. Other sessions were still fixing two of them on 2026-10-02.
- 4 scripts had no caller, no test, no CI step and no settings wiring: `model-cache-guard`,
  `observe-otel`, `post-incident-adr`, `repo-map`. Only prose docs mentioned them, and the
  README claimed they ran on hook events, which was false.

## Decision

Delete the four unwired scripts and the documentation that described them. Keep every other
script in `hooks/`. Regenerate `.harness/manifest.json`.

## Alternatives considered

- **Retire all of `hooks/`.** Rejected: 45 scripts are live dependencies of the flywheel and
  its tests; removal would break `cycle.sh` and CI.
- **Keep the four and only fix the README.** Rejected: unwired code with no test drifts and
  misleads readers about what the profile enforces.
- **Wire the four instead.** Rejected: no owner asked for the behavior, and each adds a
  per-turn or per-tool hook cost.

## Consequences

- 4 fewer scripts to maintain, and the docs match what runs.
- Anyone who copied one of the four loses the upstream copy; it stays in git history.

## Revisit when

Someone needs cache-aware model routing, OTEL spans, a repo map or a post-incident reminder.
Restore from history together with a test and a settings entry, never as an unwired script.
