# react-native-template disposition — make private, retire the remediation

- Date: 2026-05-30
- Status: Accepted (visibility change is operator-executed)
- Pipeline: `/research-and-decide` (2 research agents → critic → **fact-verification + reconciliation**)
- Supersedes: the "react-native-template first / audit-fix-now" portion of [`2026-05-30-cve-debt-remediation.md`]

## Context

Under the CVE-remediation ADR, react-native-template was the audit-fix pilot. The pilot **validated the mechanism** (`npm audit fix`, no `--force`, cleared the critical RSC-webpack RCE + all 13 highs, 41→18, no direct-dep major bumps) — but revealed the per-repo fix is **not cheap**: the repo's CI rejects it on 4 gates (strict `npm install` ERESOLVE on Expo's peer tree, PR-size-on-lockfile, audit-on-moderate, commitlint). The question became: defer / grind the gates / fix the CI / archive / make-private.

Two research agents + a critic, with the key fact **verified directly** (one agent hallucinated "ACTIVE, commit today"; `main` HEAD is actually **2025-10-27 — 7+ months idle**; the recent "activity" was rollout PR-branch churn, not development). Ground truth: **dormant 7mo, 0 stars/forks, `is_template=false`, public, not archived; lockfile pins a now-fixable critical RCE.**

The critic (REJECT) correctly flagged: (a) PR #2 is genuinely unmergeable as-is (CI ERESOLVE); (b) leaving a known critical RCE public+open indefinitely pending an "intent" answer is unsound; (c) the data already says "dead" — don't dodge with intent-routing; (d) **archive alone keeps the repo publicly forkable** (RCE still inheritable); (e) fixing CI gates for a dead repo is busywork. It also conceded the RCE is **low magnitude** (server-component/test-dep path, 0 consumers, advisory already public).

## Decision

**Make `react-native-template` private** (operator-executed — visibility change is the operator's call).

- One action removes all public fork/clone access → the public-vulnerable-lockfile concern is **neutralized immediately**, without merging anything.
- Preserves Lucas's optionality to keep using it as a **personal** RN/Expo scaffold (private templates work fine for that).
- **Moots** the blocked security PR #2 and the 3 mis-calibrated CI gates — no audit-fix merge, no `.npmrc`/PR-size/audit-level fixes, no rebase grind on a repo with no public future.
- **Close PR #2** (the fix is preserved on branch `fix/npm-audit-security` if ever needed); leave PR #1 (CI-caller) to the operator.

## Alternatives considered

- **Defer (leave public + PR #2 open)** — REJECTED (critic): leaves a known critical RCE public+unfixed indefinitely. Unsound even at low magnitude.
- **Grind the 4 CI gates + merge PR #2** — REJECTED: ~4 gate accommodations (`.npmrc`, commit-msg, PR-size override, audit threshold) on a 7-mo-dormant 0-consumer repo = the busywork the CVE ADR warns against.
- **Fix the 3 mis-calibrated CI gates** (a real, ~20min improvement per research) — REJECTED *for now*: only worth it if the repo stays public+active; moot once private. Revisit if re-published.
- **Archive (keep public, read-only)** — REJECTED: archived repos **stay publicly forkable**, so the RCE-lockfile remains inheritable; "honest dead signal" but doesn't neutralize exposure. Private is strictly better here.
- **Delete** — REJECTED: irreversible, more hostile than needed; private is reversible.
- **Critic's 4-phase (unblock→merge→private→archive)** — REJECTED as over-engineered: merging a security fix into a repo you're taking private is unnecessary (a private dead repo's lockfile is nobody's concern).

## Consequences

- (+) Public RCE exposure neutralized in one operator action; no PR/CI grind on dead code.
- (+) Lucas keeps the scaffold privately if he wants it.
- (−) If he later wants it as a *public* template offering, he must then fix the CI gates + merge the security fix before re-publishing (tracked below).
- (~) PR #2's validated fix is parked on a branch, not merged.
- (lesson) A subagent hallucinated repo recency; **direct verification of the default-branch HEAD date** flipped the disposition. Vitality claims must be checked against `main`, not PR-branch churn.

## Revisit when

- Lucas wants react-native-template **public again** (as a template offering) → first fix the 3 mis-calibrated CI gates (`.npmrc legacy-peer-deps=true`, exclude lockfiles from PR-size, `npm audit --audit-level=high`) + merge the parked security fix, THEN re-publish.
- He resumes active development on it → reassess (keep public + maintain).
- The same Expo peer-tree / lockfile-PR-size friction appears on a repo he DOES keep public → fix the gates there (the research showed they're genuinely mis-calibrated).
