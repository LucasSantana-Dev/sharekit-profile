# ADR 0004: Keep the repo-root hooks, mark four as opt-in

**Status:** Accepted
**Created:** 2026-10-02
**Owner:** the operator
**Tags:** sharekit-profile, hooks, lean-out

## Context

A harness lean-out asked whether the repo-root `hooks/` directory (49 scripts) should be
retired. It is this repo's own dev-time flywheel, documented in the README and
`docs/flywheel.md`, and exercised by `tests/*.bats`, which CI runs.

A reference check across code, tests, CI and other hooks found 45 scripts called by another
hook, covered by a test or wired in a settings file. Four had no caller and no settings wiring
at the time: `model-cache-guard`, `observe-otel`, `post-incident-adr`, `repo-map`. The README,
`docs/flywheel.md` and `docs/hook-firing-order.md` described them as running on hook events,
which was false. A retirement PR (#210) was opened, then closed: #202 added bats coverage for
those four while it was open, so they are kept.

## Decision

Keep every script in `hooks/`. Document the four as opt-in (shipped and tested, not wired in
the shipped settings) instead of claiming they run on events.

## Alternatives considered

- **Retire all of `hooks/`.** Rejected: 45 scripts are live dependencies of the flywheel and
  its tests.
- **Delete the four.** Rejected: they now have tests and an active coverage effort (#127).
- **Wire the four by default.** Rejected: each adds per-turn or per-tool cost and nobody asked
  for the behavior.

## Consequences

- Docs match what runs.
- Four tested scripts stay unwired; readers wanting them add a settings entry.

## Revisit when

A script loses its tests or has no commits for a year. Then delete it. Or when one of the four
is wanted by default: wire it and add a settings test.
