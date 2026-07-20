# Artifact Frontmatter Schema

Ported from compozy's markdown-artifact pattern:
workflow artifacts (ADRs, plans, specs, reviews, decisions) carry a consistent YAML
frontmatter so their **status is queryable** — "all blocked artifacts", "all
deferred ADRs", "everything superseded by ADR-0023" — by grepping frontmatter
instead of reading bodies.

This is *adopt-lite*: it **codifies the schema the `claude-env/adrs/` ADRs already
use** (id/title/status/date/deciders/tags/related) and adds a few compozy
queryability fields. Memories keep their own schema (`name`/`description`/`metadata`)
— this is for the *other* workflow artifacts.

## Schema

```yaml
---
id: ADR-0023                 # required for ADRs (TYPE-NNNN); optional for plans/specs
type: adr                    # required — one of: adr, plan, spec, review, decision
title: <one-line summary>    # required
status: accepted             # required — see enum below
date: 2026-06-18             # required — YYYY-MM-DD
deciders: lucas-santana      # optional
phase: <composite phase>     # optional — which composite phase owns/produced this (compozy queryability)
blockers: none               # optional — `none` or a list; a non-empty list means status should be `blocked`
supersedes: [ADR-0013]       # optional — what this replaces
superseded_by: ADR-0030      # optional — set when this artifact is retired
tags: [release, observability]  # optional
related: [ADR-0022]          # optional — [[wikilinks]] or ids
---
```

### `status` enum
`draft` → `proposed` → `accepted` | `deferred` | `blocked` → `superseded` | `done`

- **draft** — being written. **proposed** — awaiting decision. **accepted** — decided/active.
- **deferred** — decided not-now, with a revisit trigger in the body.
- **blocked** — cannot proceed; `blockers:` must list why.
- **superseded** — replaced (set `superseded_by:`). **done** — completed (for plans/specs).

## Linter

```bash
python3 ~/.claude/scripts/artifact-lint.py <dir-or-file>      # validate frontmatter
python3 ~/.claude/scripts/artifact-lint.py <dir> --query status=blocked   # query
python3 ~/.claude/scripts/artifact-lint.py <dir> --query type=adr,status=deferred
```

Run it over `claude-env/adrs/` as a lint; use `--query` for "what's blocked / deferred /
needs a revisit" sweeps. A `blockers:` non-empty with `status != blocked` is a finding
(the artifact claims it's fine but lists blockers).

## Migration (body-style → frontmatter)

Some artifacts (homelab `docs/adr/*` use `**Status:** Accepted` in the body; plans
use ad-hoc text headers) predate this schema. They still read fine; migrate them to
frontmatter opportunistically when you next touch them so they become queryable.
New artifacts use frontmatter from the start. Don't do a big-bang migration — the
value is in *new* artifacts being queryable + the linter catching drift.

## Why it matters

Composites (`/research-and-decide`, `/plan`) emit these artifacts. Consistent
frontmatter turns the artifact pile into a queryable workflow ledger: a future
session (or a diagnostic) can ask "what decisions are blocked?" or "what did we
defer and when do we revisit?" without reading every file — the compozy
"version-controlled workflow history" win, at grep cost.
