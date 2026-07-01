# ADR-0001: Harness improvement sequencing — enforcement before flywheel activation

- **Status:** Accepted
- **Date:** 2026-07-01
- **Decision process:** /research-and-decide (deep-research 4-audit pass + external literature benchmark → adversarial decision-critic review → this record)

## Context

A deep analysis of this harness (2026-07-01) surfaced defects across six improvement tracks:

- **A. Enforcement integrity** — `check-harness-boundary.sh` scans directories that don't exist (`.claude/skills`) and has never scanned the real catalog (`claude/skills/`, ~400 files); this blindness let a client-identifying script reach public `main` (history-purged same day). Also: a sed glob→regex bug disables `check-dangerous-patterns.sh`'s sensitive-paths deny-list; `check-catalog-canonical.sh` is wired to no gate; the coauthor-trailer gate scans `git log --all` so stray branches can fail unrelated PRs.
- **B. Quality infrastructure** — 48+ shell scripts, zero shellcheck/shfmt, zero tests.
- **C. Flywheel activation** — the propose→trial→gate→deploy loop runs only manually/opt-in-nightly; trajectory telemetry is effectively not accumulating (56 lines, stale); 2025–2026 self-evolving-agent literature documents verifier-gaming/alignment-drift risks and uniformly recommends human review before persistence + rollback contracts, which `.harness/constitution.md` does not yet specify for self-modification.
- **D. Security depth** — secret scanning is pattern-matching only (missed the client campaign ID); a PAT (`HOMEBREW_TAP_TOKEN`) exposed 2026-06-25 still needs revoke+replace.
- **E. Concurrency discipline** — two same-week incidents of concurrent AI sessions destroying uncommitted work in this checkout; the worktree convention exists only as prose, unenforced.
- **F. Measurement/evals** — the 103→51 skill consolidation was judged on description similarity, not usage data; no skill/routing evals exist.

Six candidate orderings were evaluated. An adversarial critic (artifact-only, no access to the candidates' advocate reasoning) **rejected all six** as initially framed, identifying: (1) a false dependency — B (days of work) was sequenced before C's telemetry, which is calendar-gated 2–4 weeks regardless and unaffected by B; (2) a conflation inside C — its *safety* prerequisite (human-review gate, rollback contract) is independent of B and must precede telemetry-driven activation, so C splits into C1 (safety contract) and C2 (activation); (3) the two active-harm items (PAT revoke, session collisions) buried mid-sequence in every ordering.

The critic's flip-condition — that Track A's and Track E's file sets don't intersect (making a parallel first wave safe) — was verified: A touches only existing gate scripts + `.husky/pre-commit`; E is a new hook + `claude/settings.json` registration. Intersection empty.

## Decision

Adopt the critic-amended parallel-wave sequencing:

- **Wave 0 (operator action, immediate):** revoke + replace the exposed `HOMEBREW_TAP_TOKEN`.
- **Wave 1 (parallel, ~hours):**
  - A — fix all four broken/blind gates;
  - E-lite — session-lock sentinel hook enforcing the worktree convention (escalate to fuller coordination only if incidents recur);
  - D-quick — adopt a semantic/history secret scanner (e.g. gitleaks) in CI alongside GitGuardian;
  - C-clock — verify trajectory logging fires in live sessions, so the 2–4 week telemetry window starts now.
- **Wave 2 (~days):** B, scoped to the security-gate scripts first (shellcheck CI + bats tests for the `check-*` hooks), remaining scripts after.
- **Wave 3 (~days, explicitly NOT gated on B):** C1 — flywheel safety contract in `.harness/constitution.md`: human review before any self-modification persists, rollback contract per deployed change, invariant-preservation check.
- **Wave 4 (calendar-gated):** F runs as a go/no-go review of the skill-catalog scope, then C2 — telemetry-driven flywheel activation. Preconditions: C1 done, B (gate scope) done, ≥2–4 weeks of real telemetry.

## Alternatives considered

1. **A→E→B→C→D→F (strict serial, enforcement first)** — rejected: buries PAT revoke and collision fix; false B→C dependency.
2. **C-first (flywheel self-discovers gaps)** — rejected: self-modification atop broken gates is the literature's named amplification anti-pattern; telemetry starved anyway.
3. **E→A→B→D→C→F** — rejected: same serial-burial problem; A and E proven parallelizable.
4. **B→A→E→C→D→F (test infra first)** — rejected: highest up-front cost while known-broken gates stay broken.
5. **D→A→E→B→C→F (security depth first)** — rejected: scanner adoption without fixed gates re-leaks; D's urgent item (PAT) is wave-0-able without sequencing all of D first.
6. **Parallel {A+E+D-quick} → B → C → F (as originally framed)** — closest to adopted, but treated C as monolithic and F as terminal; amended per critic into the wave structure above.

## Consequences

- **Positive:** active harms (exposed PAT, collision loss, blind gates) all addressed in wave 0–1; telemetry clock starts immediately instead of after B; flywheel cannot activate without a safety contract, closing the self-modification risk the external research flagged.
- **Negative:** flywheel autonomy (the harness's flagship idea) is deliberately delayed ≥2–4 weeks; wave 1 runs three worktrees in parallel in a repo that just demonstrated concurrency failures — mitigated by disjoint file sets (verified) and worktree isolation.
- **Neutral:** F moves from "someday" to a hard gate before C2 — catalog decisions stop being vibes-based at exactly the moment they'd start feeding an autonomous loop.

## Revisit when

- Another concurrent-session incident occurs after E-lite lands → escalate E to full coordination (locking, not sentinel).
- Real telemetry reaches 4 weeks → schedule F review + C2 activation decision.
- Any new secret-class leak reaches a public branch → reopen D as top priority.
- The flywheel produces its first autonomous proposal → verify C1's human-review gate actually intercepted it before merge.
