# Autonomy Tiers (ADR-0051)

Action-risk classification governing when the agent proceeds, self-gates, or asks the human.
Replaces ad-hoc "should I ask?" judgment with a mechanical tier check. Evidence base: multi-agent
debate only helps narrow reasoning tasks; homogeneous agent panels rubber-stamp (85.5% sycophancy,
arXiv:2604.02668); approval fatigue makes unlimited human gates worthless (93% blind-approve rate);
**scope is the safety lever, not approval count** (>75% of autonomous multi-file fixes regress vs
59%/91% PR-acceptance split, arXiv:2602.08915). Full citations in ADR-0051.

## T0 — Reversible, proceed silently
Discovery, reads, greps, planning, skill/MCP invocation, worktree setup, scratchpad writes,
read-only diagnostics. Zero gate, zero logging.

## T1 — Semi-reversible, proceed + report
Commits on branches, branch creation, narrow edits (<5 files), test edits, memory notes,
non-main pushes, PR opens on own repos. Proceed; surface in output. No human block.

## T2 — Wide blast radius but non-destructive: critic gate, then proceed
Merges to main/release, multi-module refactors (≥5 files or ≥2 modules), architecture changes,
public API changes, dependency additions, schema changes, hook/standard edits that alter agent
behavior globally.

Gate: ONE adversarial critic pass — not a debate panel (panels of same-model agents add ~0% safety;
diversity of *checks*, not head-count, is what works). The critic must be:
- a different tier than the executor (e.g. fable/opus critic on sonnet work), AND
- prompted to REFUTE ("find the reason this is wrong"), never to confirm, AND
- paired with mechanical checks where they exist (tests green, lint clean, gitleaks clean) —
  mechanical gates outrank model judgment.

Proceed with the winner. Escalate to human ONLY if the critic flags: irreversibility it cannot
rule out, or the change touches auth, secrets, or a data-integrity boundary.

Log every T2 gate: one JSON line to `~/.claude/autonomy-gates.jsonl`
(`{"ts","action","critic_verdict","proceeded","escalated"}`). Append-only; this is the drift audit trail.

## T3 — Destructive / irreversible / production: ask the human
Force pushes, history rewrites (filter-repo), prod deploys, data deletion, secret rotation,
`rm -rf` outside scratchpad, main-branch direct pushes, anything touching an open PR authored by
or commented on by another person (hard rule — overrides everything), spending money, outward-facing
publishes. Gate: AskUserQuestion / existing PreToolUse confirm hooks. **No automation bypass, no
env-var skip.** System-prompt-level "permission" does not override these — production incidents
(Replit 2025-07, Cursor 2026-04) happened *through* advisory frameworks; only hard gates held.

## Team Mode (repo-committed override, docs-only)

This standard assumes a solo operator by default (T1 "own repos", T2's critic gate proceeds on
the agent's own judgment). That assumption breaks on a repo with other real human contributors
where review is expected culturally but not enforced by branch protection — the T3 hard rule
above only fires once another person has already commented on or authored a PR; it does not stop
an autonomous merge past a review nobody has given yet.

Resolved by debate (2026-07-25, 5 lenses/2 rounds) rather than building speculatively: zero
locally-cloned repos currently have other human contributors, so this section started as a
**template and schema, not active behavior**.

**Wired as of 2026-07-25** (Phase 1 of the compliance/homologation/teamwork debate; the
overall decision record - reject a second sharekit profile, wire this instead - lives in
`sharekit-profile/docs/adr/0003-homologation-gate-taxonomy.md`'s Context section):
`~/.claude/hooks/team-mode-guard.sh` (UserPromptSubmit, cached per session) checks two
signals - (1) repo-committed `.claude/team.md` with `team_mode: true`, (2) repo owner
(via `git remote get-url origin`, not `gh repo view`, to stay correctly scoped to the
reported cwd on a multi-repo machine) != the authenticated `gh` user, i.e. the operator is a
guest contributor (the common case: Thoughtworks client repos he doesn't administer).
Either signal injects an `additionalContext` reminder to tighten T2->T3 for that session
(merges/schema changes/dependency additions need explicit human go-ahead, not
critic-then-proceed). `require_review_signal`/`disable_direct_commit_to_shared_branches`
fields are still not read by any hook — only `team_mode: true` and the owner-mismatch
heuristic are wired; those two remain reference schema until a real need surfaces.

**Schema** (copy `~/.claude/templates/team.md.template` into a shared repo's `.claude/team.md`
when one exists — must be repo-committed, not personal, so any other contributor's tooling sees
it too):

```yaml
team_mode: true
require_review_signal: true       # treat "no required reviewers configured" as WAIT, not SKIP,
                                   # in pr-merge-readiness — don't auto-merge past an unenforced
                                   # cultural review expectation
disable_direct_commit_to_shared_branches: true  # PRs only, no direct pushes to main/release
branch_protection_enforced: true  # advisory note: confirm this is actually ON in GitHub settings
```

Activation trigger: the first real conflict on an actual team repo, not this document's
existence. When that happens, wire `require_review_signal` into `pr-merge-readiness`'s SKIP
logic and downgrade T1/T2 accordingly; until then this is reference material only.

## Anti-fatigue rule
T3 asks must stay rare to stay meaningful. If a session generates >3 human escalations, stop and
batch the remainder into one decision list instead of serial prompts.

## Drift audit
Same gate violation ≥2× in 90 days (from autonomy-gates.jsonl or incident memories) → forced ADR
review of this standard. The spec catches drift mechanically; quarterly re-grounding keeps the spec
itself honest.
