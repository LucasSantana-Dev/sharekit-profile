# Multi-Person Work Ethics - agents in shared repositories

**Status:** active (defined 2026-07-24, from an incident postmortem on config round-trips
and solo-default autonomy). Mechanics live in `standards/cooperative-mode.md`; this file is
the ethics layer it enforces. Decision record: global ADR `2026-07-24b-multi-person-work-ethics`.

These rules apply whenever an agent acts on a repository other people may depend on,
regardless of who owns the remote. They exist because the dangerous window is the one
before anyone has engaged: unreviewed, uncommented, unwatched work.

## The rules

1. **Absence of objection is not approval.** Silence is the absence of a signal, not
   a signal. Every autonomous action must be able to answer: what positive signal
   authorized this? "No one said no" is not an answer.
2. **Guards that fire on engagement are floors, not policies.** A rule like "never
   automate on a PR someone else touched" only protects work others already saw. It is
   structurally blind to unreviewed work, which is the riskiest kind. Name the floor
   when you cite it.
3. **Unenforced review expectation = WAIT + finding.** A shared branch where review is
   expected by norm but not required by protection is exactly where an autonomous merge
   is technically allowed and socially wrong. "No required reviewers configured" never
   resolves to SKIP; it resolves to WAIT and a surfaced finding (ideally: fix the
   protection, don't just route around the gap).
4. **Team behavior is the standing default.** Opt-in safety is safety somebody forgot
   to turn on, and it fails asymmetrically: forgetting to enable it grants maximum
   autonomy where it is least appropriate; forgetting to disable it costs one avoidable
   confirmation. Detection may tighten on evidence (committer diversity in
   `repo-mode.sh`), never relax on absence of evidence.
5. **Merging to a shared branch is a social act.** It terminates other people's
   opportunity to review. It requires a human, categorically; no adversarial critic
   pass substitutes, because the cost lands on colleagues, not the operator. Direct
   pushes to shared branches are in the same category; use PRs.
6. **A rule claiming enforcement it does not have is worse than an honest advisory.**
   Phantom guardrails retire the reader's caution and replace it with nothing. Every
   rule asserting mechanical enforcement must name the artifact, and the artifact must
   exist (harness-vitals check 12 verifies this set). Aspirational rules must say so:
   "these are instructions you must follow, not guardrails that will catch you."
7. **Constitution and cited standard must agree.** Divergence between a governing doc
   and its authority turns behavior into a coin flip weighted by confidence of tone.
   Treat the divergence itself as a defect; reconcile at the source.
8. **Gates must stay rare enough to mean something.** Approval fatigue approves
   blindly. Tighten only the few actions that are irreversible or socially
   consequential; batch escalations into one decision; proceed autonomously everywhere
   else.

## How the harness enforces this

| Rule | Mechanism |
|---|---|
| 1, 3, 5 | AGENTS.md hard rules ("Silence is not approval", WAIT+finding, merges to shared branches = T3 categorical) + cooperative-mode autonomy caps |
| 2 | AGENTS.md annotation on the other-person-PR rule ("This rule is a FLOOR") |
| 4 | `repo-mode.sh`: marker > committer diversity > org allowlist > no-remote > cooperative default |
| 6 | harness-vitals check 12 (enforcement-artifact existence) |
| 7 | this standard + cooperative-mode.md cross-referenced in AGENTS.md |
| 8 | cooperative mode restricts escalation to outward/social actions only |

## Checklist (from the postmortem; audit against it periodically)

- [x] Team behavior is the default; no per-repo opt-in required.
- [x] Merges and direct pushes to shared branches require a human, categorically.
- [x] Unenforced review expectation resolves to WAIT plus finding, never SKIP.
- [ ] Branch protection status verified and reported per repo (partial: solo repos have
      CodeRabbit required checks; cooperative repos need a per-repo check before any merge).
- [x] Every rule claiming enforcement names a provably existing artifact.
- [x] Aspirational rules labeled as instructions, not guardrails.
- [x] Governing documents and cited standards agree; divergence is a defect.
- [x] Escalations rare, batched, reserved for irreversible/social consequences.
