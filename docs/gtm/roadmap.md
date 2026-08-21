# sharekit-profile / sharekit — Roadmap

Date: 2026-08-04. Built via roadmap-prioritization framework (fixed appetite over
estimation, portfolio balance over reactive backlog). Inputs: `launch-plan.md`
(GTM), `.claude/backlog/2026-08-04.md` (open #127/#128), this session's
portability/noise findings (not yet filed as issues).

## Portfolio balance

4 themes, deliberately front-loaded toward table-stakes + one big bet, not
incremental polish. Pre-launch stage: reactive noise/doc fixes would be exactly
the "speed bump" mistake the framework warns against right now — they don't
move the one thing that matters (does anyone outside this repo use it).

| Theme | Type | Appetite (fixed) |
|-------|------|-------------------|
| Ship-readiness | Table stakes | 1 day |
| Go-to-market validation | Big bet | 4 weeks (already gated in launch-plan.md G1-G5) |
| Trust backfill (test coverage) | Table stakes | ongoing background, no dedicated sprint |
| Operator noise/doc polish | Incremental | opportunistic only, no time-box |

Ratio: 2 table-stakes tracks + 1 big bet + 1 incremental track, deliberately unscheduled.

## Theme 1 — Ship-readiness (do first, blocks the big bet)

**Why first:** the GTM plan's own Day-1 launch-week script is a live `npx
@lucassantana/sharekit install` demo (Show HN, demo clip, DM outreach). A crash
on stock macOS bash 3.2 during that exact moment is not a bug, it's a launch
failure. This must close before Crawl-phase outreach starts, not after.

- Fix `declare -A` (bash 4+ only) in `dispatch.sh`, `memory-consolidate.sh`,
  `skill-prune.sh` — convert to indexed arrays per the pattern already applied
  to `tool-shortlist.sh` (8fa7085). Same root cause, 2nd occurrence — this
  repo's own rule ("same root cause >=2x in 14 days -> forced ADR") applies.
- Appetite: 1 day. If it takes longer, cut scope to just the 3 hooks, not a
  general bash-compat audit.

## Theme 2 — Go-to-market validation (the big bet)

Already fully specified in `launch-plan.md`. Not re-planned here, just slotted:

- **Crawl (weeks 1-2)**: DM variants ready (`crawl-dm-variants.md`), 7 real
  candidates found this session, need ~8 more before the test has enough n.
- **Walk (weeks 3-4)**: align README/docs to winning variant.
- **Run (week 5+)**: only if G1-G5 gates pass.
- Kill criteria already fixed: <5 non-author users by week 4 = stop, don't
  sink more into the product. This is the framework's "fixed appetite" done
  right already, not re-litigated.

## Theme 3 — Trust backfill (background, not urgent)

- #127: ~35/49 hooks with zero bats coverage.
- #128: eval fixtures cover 8/47 skills.
- Deliberately NOT time-boxed against the launch window. Rationale: nobody
  outside this repo can observe untested hooks yet (0 external users pre-Crawl)
  the risk this mitigates only starts mattering once Theme 2 gates pass and
  strangers start depending on the thing. Pick up opportunistically between
  Crawl and Walk, don't let it compete with Theme 1/2 for attention now.

## Theme 4 — Operator noise/doc polish (opportunistic only)

- `mode-reminder.sh` re-emits its banner every turn with no session
  memoization (real, measured this session, but a cost to the operator only,
  not to an external user or the launch).
- Two-hook-tree doc gap (`hooks/` 49 vs `claude/hooks/` 71, undocumented split).
- No dedicated time. Fold into Theme 1's PR if trivial, otherwise defer past
  the Crawl/Walk window — fixing operator-only friction before anyone external
  has used the product is exactly the reactive-backlog trap the framework
  flags ("prioritizing management reporting over primary user workflows" —
  here, primary user is the external installer, not the operator's own
  session ergonomics).

## What this roadmap deliberately does NOT include

- The 3 extract-product candidates evaluated this session (router-eval,
  Warp proxy, transcript-scanner) — debate concluded none clear the bar to
  spin off now. Not on this roadmap; revisit only if real inbound demand
  appears post-launch.
- Any new feature work. Nothing here is a "big idea" — per the framework,
  reacting to hypothetical asks before the one live big bet (GTM validation)
  resolves would be premature.
