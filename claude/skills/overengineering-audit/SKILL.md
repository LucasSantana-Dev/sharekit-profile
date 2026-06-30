---
name: overengineering-audit
description: Scans code for speculative abstractions, unused flexibility, and reinvented stdlib that can be cut.
  Flag over-engineering — speculative abstractions, premature generalization, single-use "flexibility", unnecessary indirection, config for things that never vary, and patterns heavier than the project needs. Scope-tightenable by design — audit a path, the current diff, specific categories, or a severity floor (default narrow, never whole-repo unprompted). Read-only / advisory: proposes the simpler alternative with its cost, never rewrites. Use in review, before merge, or when a module "feels" too clever for what it does.
user-invocable: true
argument-hint: "[<path> | --changed] [--category abstraction,indirection,config,generalization,premature-opt,types] [--severity low|med|high] [--budget N]"
metadata:
  type: skill
  status: stable
---

# Overengineering Audit

Find code that's heavier than the problem it solves — abstraction without a second
caller, flexibility nobody asked for, indirection that only adds hops. Report the
**simpler thing** and what the current complexity costs. **Read-only**: this audits and
proposes; it never rewrites (hand confirmed findings to `/refactor` or a fixer).

The failure mode of this audit is noise — every codebase has *some* abstraction, and
"could be simpler" is infinite. So **scope first, always.**

## Auto-invocation triggers

"is this over-engineered", "is this too clever / too abstract", "do we need this
abstraction/layer/interface", "simplify this", a reviewer asking "why isn't this just a
function", or `/overengineering-audit [scope]`. In a PR review, default to `--changed`.

## Scope — tighten before auditing (the whole point)

Pick the narrowest scope that answers the question. **Never audit the whole repo unless
explicitly asked** — surface the default and proceed:

| Option | Effect | Use when |
| --- | --- | --- |
| `<path>` (file or dir) | Audit only that module | "is `src/payments/` over-built?" |
| `--changed` / `--diff` | Only the working diff / `main..HEAD` | PR review, pre-merge (the default in review) |
| `--category a,b` | Only these smell classes (see table) | "just check the abstraction layers" |
| `--severity high` | Drop everything below the floor | high-signal pass; tired of nitpicks |
| `--budget N` | Cap at the top-N findings by severity×reach | quick triage; remote/limited bandwidth |

Default when no scope is given: **`--changed` if there's a diff, else ask for a path** —
do not silently sweep the repo. State the chosen scope in one line before reporting.

## Detection catalog (smell → simpler alternative)

| Category | Smell | Simpler alternative |
| --- | --- | --- |
| **abstraction** | Interface / base class / factory with exactly one implementation; a "strategy" with one strategy | Inline it; add the seam when the 2nd caller actually arrives |
| **generalization** | Generic `<T>`/params/hooks for cases that don't exist; "configurable" with one config | Hard-code the one case; YAGNI the rest |
| **indirection** | Wrapper that only forwards; a manager/service/handler that adds a hop and no behavior | Call the thing directly; delete the pass-through |
| **config** | Env var / option / feature flag for a value that never varies; settings nobody flips | Constant in code; reintroduce config when a 2nd value is real |
| **premature-opt** | Cache / pool / batch / memo with no measured hotspot; micro-opt that hurts readability | Remove it; optimize when a profile says so (see `/performance-audit`) |
| **types** | Type gymnastics (deep conditional/mapped types) modeling states that can't occur; enums with one member | Collapse to the states that exist; a plain type/union |
| **lifecycle** | Init/teardown/registry seams retained "in case"; no-op hooks kept for symmetry | Delete dead seams; git history is the rollback |

Rule of thumb: **one caller = not an abstraction, it's indirection.** Flexibility is a
cost paid now for an option used later — flag it when the "later" isn't on the roadmap.

## What is NOT over-engineering (don't flag)

- A seam with a **named, near-term** second caller or a documented extension point (ADR/comment).
- Boundaries at real module/ownership/security edges (validation at trust boundaries, API contracts).
- Patterns the framework/ecosystem expects (e.g. DI in Nest, repositories where the stack assumes them).
- Defensive code on **external** input. (For *internal* silent-failure bloat, that's a different lens.)
- Tests. Duplication-for-clarity in tests is usually fine.

## Output

Severity-ranked, evidence-first. Per finding:

```
[HIGH] Single-impl interface adds a layer for no seam
  src/payments/PaymentGateway.ts:12  (only impl: StripeGateway.ts:1)
  Cost: +1 file, +1 indirection hop, harder to navigate; 0 current benefit.
  Simpler: inline StripeGateway; extract the interface when a 2nd provider lands.
  Confidence: high (grep finds 1 implementor, 0 other callers).
```

Severity = harm × reach: **HIGH** = abstraction on a hot path / core module that misleads
every reader; **MED** = local cleverness; **LOW** = cosmetic. Lead with a one-line verdict
(`Over-engineered: 2 HIGH, 3 MED in <scope>` or `Proportional — nothing above the floor`).
Signal-first: if >3 non-critical findings, show top 3 then "N more — ask for the full list."

## Stop / negative rules

- Scope first — refuse a whole-repo sweep unless explicitly requested; default to `--changed`.
- Verify each claim before reporting (grep the caller/implementor count) — "feels complex"
  is not evidence. Don't fabricate a single-use claim you didn't check.
- Read-only. Propose; never edit. Route accepted findings to `/refactor`.
- Don't flag a seam with a real near-term second use, or framework-mandated structure.
- One finding per smell, not per line. Cluster repeats.

## Related

- `/refactor` — apply an accepted simplification · `/coupling-map` — find the over-connected nodes first · `/performance-audit` — before removing a "premature" optimization, confirm it isn't load-bearing · `/ai-slop-audit` — the frontend-output analogue · `/config-drift-detect` — over-strict *gates* (a sibling kind of over-engineering).
