---
name: backlog
description: Composite - end-to-end backlog builder for a single repo. Analyzes the repo in parallel (audit-deep + ecosystem-health + repo-state-snapshot), scores each finding with a value_score (1-5, measuring user/business impact of delivery), ROI-ranks using severity × urgency × value_score / effort, groups findings into sprint themes, proposes with a Val column and per-finding "Value:" justification, supports sprint budget mode ("I have 2 days") for greedy knapsack selection, learns from approval history to deprioritize consistently-rejected categories, generates specs for features, creates GitHub issues (deduped), and adds to the Active Backlog Project board. Use whenever the user wants to know what to work on, build a backlog, prioritize issues, or plan a sprint.
user-invocable: true
auto-invoke: build a backlog, generate a backlog, find gaps, find opportunities, refactoring opportunities, what should i work on, what is missing in this repo, audit and plan, comprehensive backlog, project audit and plan, what can i get done this week, sprint planning, i have N days, prioritize my work, what has the most value
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/backlog
---

# /backlog

End-to-end backlog builder for a single repo. Turns "what's wrong or missing
here?" into a curated, ROI-ranked, deduped set of GitHub issues on a Project
board — with full specs for new features and a propose-then-confirm gate
before any GitHub write.

Replaces running these separately:
- `/audit-deep` (discover findings)
- `/repo-state-snapshot` (capture current state)
- `/ecosystem-health` (cross-repo context, when applicable)
- `/adt-specs-spec-new` (write feature specs)
- `/plan-to-issues` (create GH issues from plan)
- manual `gh project item-add` per card

## When this fires

User phrases (matched by `~/.claude/hooks/composite-router.sh`):
- "build a backlog for this repo"
- "generate a backlog"
- "find gaps in this project"
- "find refactoring opportunities"
- "what should I work on"
- "what's missing in this repo"
- "audit and plan"
- "comprehensive backlog"
- "project audit and plan"

Auto-queued by:
- `/onboard-new-repo` (after initial repo intake, suggests `/backlog` as the
  "ok, now what?" follow-up)

Auto-queues at end:
- `/next-priority` (so the user knows what to start from the freshly-ranked board)

## Workflow

The `/backlog` composite runs 8 phases sequentially, with parallel discovery
in Phase 1. Detailed procedures for each phase are documented in
[references/workflow.md](references/workflow.md).

**Phase chain (inline summary):**

### Phase 0 — RAG pre-flight + skip-if-fresh gate

Check for prior snapshot via RAG. If snapshot found and < 14 days old, offer interactive
"reuse vs. fresh" gate before Phase 1. Load deferred items (Phase 0d) and approval history
(Phase 0e). See [references/memory-integration.md](references/memory-integration.md).

### Phase 1 — Discover (parallel)

Run `audit-deep`, `ecosystem-health`, and `repo-state-snapshot` in parallel;
collect code markers and git history via `discover.sh`. See
[references/workflow.md § Phase 1](references/workflow.md#phase-1--discover-parallel).

**Skip condition:** if not in a git repo, abort immediately with the
reconciliation block showing `Discover: (failed: not a git repo)`.

### Phase 2 — Categorize, dedup, rank

Normalize findings into severity/effort/ROI. **New:** assign `value_score` (1-5)
and `value_justification` per finding. Apply category urgency penalties from
Phase 0e approval history. ROI formula: `(severity_weight × urgency × value_score) / effort_weight`.
Dedup against open issues. Sort by ROI descending. Group into 3-6 themes for Phase 3 display.
See [references/workflow.md § Phase 2](references/workflow.md#phase-2--categorize-dedup-rank).

### Phase 3 — Propose (interactive, gated)

Print findings grouped into named themes, each with a `Val` column (1-5) and
a one-line `Value:` justification per finding. **Sprint budget mode:** if the
user mentioned a time budget ("I have 2 days", `--budget 2d`), show a greedy
knapsack suggestion block after the table. User can approve by number, theme,
category, or budget selection. See
[references/workflow.md § Phase 3](references/workflow.md#phase-3--propose-interactive-gated).

**No GitHub writes happen before this gate.**

### Phase 4 — Spec generation (features only, conditional)

For each approved feature, generate a spec folder via `adt-specs-spec-new`
and populate it with finding details. See
[references/workflow.md § Phase 4](references/workflow.md#phase-4--spec-generation-features-only-conditional).

**Skip condition:** if no features in approved set, mark
`Spec: (skipped: no features approved)` in reconcile and proceed to Phase 5.

### Phase 5 — Write plan file

Generate `.claude/backlog/<YYYY-MM-DD>.md` with phased task list grouped by
severity. See
[references/workflow.md § Phase 5](references/workflow.md#phase-5--write-plan-file).

### Phase 6 — Create issues (via plan-to-issues + post-processing)

Create GitHub issues, apply labels, link specs, and comment on duplicates. See
[references/workflow.md § Phase 6](references/workflow.md#phase-6--create-issues-via-plan-to-issues--post-processing).

**Failed creations are NOT rolled back** — marked `(failed: <reason>)` in reconcile.
Plan file remains as durable artifact for manual recovery.

### Phase 7 — Add to Project board

Resolve (or create) the "Active Backlog" Project board and add all created
issues as cards in ROI-descending order. See
[references/workflow.md § Phase 7](references/workflow.md#phase-7--add-to-project-board).

If board missing AND user declines creation: skip this phase only. Issues
remain created and labeled.

### Phase 8 — Snapshot, memory, queue

Append run summary to plan file, save memory snapshot for future `/next-priority`
calls, and suggest invoking `/next-priority`. See
[references/workflow.md § Phase 8](references/workflow.md#phase-8--snapshot-memory-queue).

## Reconciliation block

Every run ends by printing this block, verbatim shape:

```
BACKLOG — <owner>/<repo>
  Pre-flight: prior snapshot: <date or none> · approval history: <N runs loaded or none>
              category penalties: <docs: −0.9 | none>
  Discover:   <N findings> (skills: audit-deep, ecosystem-health, repo-state-snapshot)
  Rank:       <M ranked from N> (<K skipped: existing-issue dedup>) · value scores assigned
  Themes:     <N themes: "Security hardening" (3), "Performance" (2), …>
  Propose:    <U approved by user, V rejected> · budget: <Nd used | off>
  Spec:       <F feature specs generated | (skipped: no features approved)>
  Plan:       .claude/backlog/<YYYY-MM-DD>.md
  Issues:     <list of #N URLs | (failed: <reason>)>
  Board:      <board URL with N cards added | (skipped: <reason>)>
  Snapshot:   ~/.claude/projects/-Users-<github-user>/memory/backlog_<repo>_<date>.md
  Queued:     /next-priority
  Open watch: <future-dated follow-up for any feature with ramp/cleanup date | (none)>
```

Every declared phase has a line — never silently omit. Skipped phases are
marked `(skipped: <reason>)`. Failed phases are marked `(failed: <reason>)`
and the chain continues per Stop conditions below.

## Stop conditions

Detailed stop conditions and recovery actions are documented in
[references/stop-conditions.md](references/stop-conditions.md).

**Key invariants:**
- Not a git repo → abort at Phase 1 with `Discover: (failed: not a git repo)`
- `gh` unauthenticated → Phase 1 still runs; Phase 6 halts with auth error
- Zero findings + clean state → write empty plan file, skip Phases 2-7
- User rejects all in Phase 3 → skip Phases 4-7, preserve plan as draft
- Plan file collision → append `-1`, `-2`, etc.; never overwrite
- Network failure mid-Phase-6 → continue with remaining issues; mark failed ones

## Negative rules

- Do NOT create issues without explicit user approval in Phase 3
- Do NOT skip the reconciliation block under any condition
- Do NOT create duplicate issues — always dedup against `gh issue list --state open`. If user explicitly says `keep dup`, allow it but flag in reconcile as `Issues: <list> (1 known duplicate kept per user request)`
- Do NOT run cross-repo — single-repo scope. `/ecosystem-health` is the multi-repo entry point. If user asks for cross-repo backlog, redirect them.
- Do NOT silently bail on any phase — every declared phase has a reconcile line
- Do NOT create issues without evidence (file paths, line numbers, log excerpts, or commit refs). If a finding lacks evidence, drop it before Phase 3.
- Do NOT generate specs for bugs / refactors / docs / tests / perf / security / tech-debt — only `category == feature`. Specs for everything else are over-engineered.
- Do NOT modify production code — `/backlog` is read-only for application code. It only writes plan, spec, config, label, and memory files.
- Do NOT auto-create the Active Backlog Project without explicit user `y` confirmation on first run (per "risky action = ask first" combined with composite-contract's no-silent-bail-out).
- Do NOT re-invoke `/audit-deep` mid-run if it just completed — Phase 1 runs it exactly once. Reuse its output memory file for Phase 2.

## Configuration

Per-repo config lives at `.claude/backlog-config.json`. All fields optional;
defaults are applied when keys are missing.

Full schema and field reference: [references/config-schema.md](references/config-schema.md).

**Key fields (summary):**
- `project_url` — explicit board URL. Overrides @me-scope "Active Backlog" default.
- `max_findings_per_run` — cap on Phase 3 table size. Default 25.
- `auto_create_board` — if true, skip user confirmation in Phase 7a. Default false.
- `dedup_strategy` — `title-fuzzy` (Levenshtein ≥0.85) or `title-exact`. Default fuzzy.
- `excluded_paths` — directories to skip when scanning code markers. Default: node_modules, dist, build, .next, vendor, coverage, .turbo.

If `.claude/backlog-config.json` is absent, all defaults apply.

## Notes / invariants

Key architectural decisions and constraints:

- **Parallel discovery** in Phase 1: 3 skills run independently (audit-deep,
  ecosystem-health, repo-state-snapshot). Independent tool calls per
  `claude-code.md`.
- **Dedup-before-write:** Phase 2 dedup runs before plan is written, so
  `plan-to-issues` never creates duplicates.
- **Spec ownership:** `adt-specs-spec-new` writes to `docs/specs/` unaware
  of `/backlog`; this skill populates spec content via Edit.
- **User-scoped board:** single "Active Backlog" board at @me-scope across
  all repos; `Repo` field distinguishes source.
- **Single-repo scope:** `/backlog` works on one repo at a time.
  `/ecosystem-health` is the multi-repo entrypoint.
- **No auto-create board:** always ask user for explicit `y` confirmation.
- **Read-only for app code:** only writes plan, spec, config, label, memory.

See [references/workflow.md § Invariants](references/workflow.md#invariants)
for full detail.
