---
name: code-teardown
description: Reverse-engineer an external repository or codebase (competitor OSS, reference implementation, trending project) and map every adoptable idea — architecture, code patterns, DX, tooling, testing, docs conventions — into a teardown report where each finding carries evidence (file:line), an adopt/adapt/already-have/reject verdict, and a constraint rationale for our context. Use when asked "faz um teardown desse repo", "analisa esse repositório pra ideias", "o que dá pra aproveitar desse projeto open-source", "evaluate X repo for insights", "what can we learn from this codebase". Read-only toward the target; clones to External HD. For live apps use app-teardown; to onboard for contributing use adt-repo-intake; to document our own architecture use doc-and-modernize.
triggers:
  - teardown desse repo
  - analisa esse repositório pra ideias
  - o que dá pra aproveitar desse projeto
  - evaluate repo for insights
  - what can we learn from this codebase
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/code-teardown
---

# Code Teardown

Reads someone else's codebase to answer one question: what do they do that WE should do?
Same contract as `app-teardown` (live apps); this one targets repos and reads code.
Output is a decision artifact with verdicts, not an architecture tour — for "how does X
work" documentation use `doc-and-modernize`.

## Use When

- An external repo should be mined for architecture/pattern/DX/tooling ideas for one of our projects.
- User names a repo, OSS project, or codebase and asks what to learn, adopt, or steal from it.
- Evaluating a trending project ("should we care about X?") — the negative outcome is captured too.

## Do Not Use When

- Target is a live product to browse → `app-teardown`.
- You will contribute to or modify the target repo → `adt-repo-intake`.
- Documenting OUR OWN system → `doc-and-modernize`.

## Inputs / Prereqs

- Target repo (URL or local path). Clone shallow to
  `${DEV_ROOT}/<repo>` (storage policy; never `$HOME`, never internal disk).
- OUR context lock: which project the ideas land in, its stack and constraints.
- Memory state-check FIRST: `reference_<target>_evaluated_*` exists → surface prior outcome
  and stop unless the revisit condition is met.
- Target is read-only: no issues, no PRs, no edits there.

## Workflow

1. **Scope + constraint capture** — why does their design work FOR THEM (scale, team size,
   ecosystem, age, funding model)? Record upfront; feeds the cargo-cult gate.
2. **Shallow clone + intake sweep** — `git clone --depth 1`. Read README, docs/, ADRs,
   CONTRIBUTING, CI config, package manifest, top-level layout. For large repos dispatch
   read-only `Explore` agents per area instead of reading serially.
3. **Map by dimension** — Architecture (boundaries, data flow, state), Code patterns
   (idioms, error handling, abstractions worth naming), DX (scripts, codegen, local-dev
   loop), Tooling/CI (build, release, quality gates), Testing (strategy, fixtures, ratio),
   Docs conventions (ADRs, changelogs, onboarding). 2+ dimensions minimum; note deliberate
   ABSENCES (what they chose not to build).
4. **State-check per candidate finding** — do WE already have it? graphify query on the
   target project (if `graphify-out/` exists) + grep + memory. Hits → `already-have`.
5. **Verdict + rationale per finding** — apply the shared contract:
   `~/.agents/skills/app-teardown/references/teardown-contract.md`
   (evidence as `file:line` at a pinned commit SHA, verdict, mandatory
   "[their constraint] → [applies to us?] → [action]" rationale, effort, landing spot).
6. **Emit + remember** — report to `<project>/docs/reference/<target>-teardown-<date>.md`.
   Memory note `reference_<target>_evaluated_<date>.md` with outcome + revisit condition;
   "evaluated → nothing" is a first-class outcome (megabrain/llmwiki precedent). Summary:
   "N findings, A adopt, D adapt, H already-have, R rejected". Remove the clone if nothing
   was adopted and no revisit is planned.

## Outputs / Evidence

- Teardown report; every finding cites `file:line` @ commit SHA read this session.
- Ranked ADOPT list at top with effort + landing spot in our repo.
- Memory note with outcome + revisit condition.

## Failure / Stop Conditions

- Zero adopt/adapt findings → still emit report + "evaluated → nothing" memory; do not
  invent findings.
- Never mark `adopt` without constraint rationale + state-check (cargo-cult gate).
- Repo too large to sweep honestly in-session → narrow to the dimensions the brief needs
  and mark `coverage: partial`; never fake breadth.

## Load These Resources

- `~/.agents/skills/app-teardown/references/teardown-contract.md` —
  shared findings schema, verdicts, cargo-cult gates, memory protocol.

## Related Skills

- `app-teardown` — same contract, live-app targets.
- `adt-repo-intake` — onboarding to work inside a repo.
- `doc-and-modernize` — architecture documentation of a local codebase.
- `plan` / `backlog` — consumers of the ADOPT list.

## Memory Hooks

- Read: `reference_<target>_evaluated_*` before starting (mandatory).
- Write: outcome note per teardown, always — including negative outcomes.
