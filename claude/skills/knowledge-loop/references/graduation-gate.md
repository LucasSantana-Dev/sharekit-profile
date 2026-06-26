# Graduation Gate — Memory vs Documentation

Full decision tree for Phase 2a classification. Determines: what artifact to write, which tags to apply, and whether the knowledge must graduate to committed documentation.

---

## Step 1: Ephemerality check

Is this auto-generated or transient state?

| Condition | Action |
|-----------|--------|
| Machine-generated (session log, precompact snapshot, hook output, audit run) | `session_` / `precompact_snapshot_` · tag `#meta/auto` · prune in 7d · **stop** |
| Transient project state (version, test counts, open PRs, in-progress work) | `project_` note · update in place · **stop** |
| Everything else | Continue to Step 2 |

## Step 2: Agency test

**"Would a future agent need this committed to make a correct decision?"**

- **Yes** → Must commit to the relevant repo. **Go to Step 3.**
- **No** → Capture as durable vault note. **Go to Step 4.**

## Step 3: Commitment type (agent-actionable knowledge)

| Knowledge type | Artifact | Where to commit |
|----------------|----------|----------------|
| Architecture / library / infra / pattern choice with real tradeoffs | `adr_` (check CONTRIBUTING.md for next uid) | Repo `docs/adr/` OR `knowledge-brain/memory/` + cited in CLAUDE.md/AGENTS.md |
| How Claude/agents should behave (rule, constraint, hard preference) | `feedback_` → draft CLAUDE.md rule or `standards/<area>.md` | `~/.claude/CLAUDE.md` or `~/.claude/standards/` |
| Reusable multi-step workflow / agent skill | Skill `SKILL.md` | `~/.claude/skills/<name>/` |
| Scope / product / investment decision | `decision_` | `knowledge-brain/memory/` — add to `MEMORY.md` if broad |
| P0/P1 incident root cause | `incident_` + post-incident `adr_` | Committed ADR before next task (CLAUDE.md hard rule) |

**Open watch rule:** if the artifact is committed to the vault but NOT yet to the repo, surface it as open watch in reconciliation: `"[artifact] must be committed to [repo] before next session relies on it."`

## Step 4: Recurrence test (non-agent-actionable)

Has this pattern or gotcha been hit **≥2 times** OR was it a **>30-min blocker** OR did it cause a **production issue**?

- **Yes** → `reference_` note or append to `memory/gotchas.md`. Tag `#type/reference`. Consider `standards/` if cross-project.
- **No** → `feedback_` note (single-session lesson). Tag `#type/feedback`. No commit needed.

## Step 5: Scope test

Is this knowledge cross-project (applies to ≥2 repos or to all Claude sessions)?

- **Cross-project** → write to `$SYM/<type>_<slug>.md` (knowledge-brain vault).
- **Project-scoped** → write to `.agents/memory/<project>.md` or project-local `.claude/` instead; skip vault push.

---

## Frontmatter templates

Filename convention: `<type-prefix>_<kebab-slug>[_<YYYY-MM-DD>].md`
(No rename/move/delete — these revert on rsync consolidation. To retire: set `status/superseded` or `status/archived`.)

### ADR
```yaml
---
name: adr_<uid>_<kebab-slug>
adr_uid: "<check CONTRIBUTING.md for next uid>"
tags:
  - type/adr
  - topic/<area>
  - status/active
description: "<one line — what was decided, key tradeoff, outcome>"
metadata:
  type: decision
---
```

### Decision (scope/product/investment)
```yaml
---
name: decision_<slug>_<YYYY-MM-DD>
tags:
  - type/decision
  - topic/<area>
  - status/active
description: "<what was chosen, what was deferred, why>"
metadata:
  type: decision
---
```

### Feedback (behavioral rule for Claude/agents)
```yaml
---
name: feedback_<slug>
tags:
  - type/feedback
  - topic/<area>
  - status/active
description: "<the rule: what to do/avoid and in what context>"
metadata:
  type: feedback
---
```
Body structure: **Lead with the rule.** Then **Why:** (the reason, incident, or strong preference). Then **How to apply:** (when/where it kicks in). This structure lets future sessions judge edge cases rather than blindly follow rules.

### Reference (gotcha / recurring pattern)
```yaml
---
name: reference_<slug>
tags:
  - type/reference
  - topic/<area>
  - status/active
description: "<what pattern/gotcha this covers>"
metadata:
  type: reference
---
```

### Incident (P0/P1 post-mortem)
```yaml
---
name: incident_<slug>_<YYYY-MM-DD>
tags:
  - type/incident
  - topic/<area>
  - status/active
description: "<what failed, root cause, immediate fix>"
metadata:
  type: project
---
```
An incident note alone is not enough: a follow-up ADR or `standards/` entry must be committed before the next task.

### Session log (auto, ephemeral)
```yaml
---
name: session_<YYYY-MM-DD>_<slug>
tags:
  - type/session
  - meta/auto
  - status/active
description: "<what happened this session — 1 line>"
metadata:
  type: project
---
```
Auto-pruned to `archive/` after 7 days. Do NOT add to `MEMORY.md`.

---

## MEMORY.md update gate

`$BRAIN/MEMORY.md` is the curated Tier-1 index that auto-loads every session. Keep ≤ 200 lines.

**Qualifying artifact types (add a pointer for these):**

| Type | Qualifies? | Notes |
|------|-----------|-------|
| `adr_` | ✅ Yes | When it changes how future sessions operate |
| `decision_` | ✅ Yes | When multiple projects need to reference it |
| `incident_` | ✅ Yes, P0/P1 only | Broad cross-project lessons only |
| `reference_` | ❌ No | Retrieve via `recall`/`search_knowledge` — even if cross-project |
| `feedback_` | ❌ No | Same — durable in vault, not in index |
| `project_` | ❌ No | Transient state |
| `session_` / `precompact_snapshot_` | ❌ No | Auto-tagged `#meta/auto`, auto-pruned |
| `backlog_` / `audit_` | ❌ No | Operational, not session-critical |

**The test is artifact TYPE, not "is it agent-actionable".** A cross-project gotcha (reference_) is agent-actionable and still does NOT go in MEMORY.md — future sessions recall it via `search_knowledge`, not the index.

Format: `- [Title](filename.md) — one-line hook under ~150 chars`

---

## Quick cheatsheet

```
New knowledge this session?
│
├─ Auto-generated / transient state?
│   └─ Yes → session_/project_ · #meta/auto · no graduation
│
├─ Future agent needs this to decide correctly?
│   └─ Yes → must commit
│       ├─ Architecture choice → adr_ → repo docs/adr/
│       ├─ Behavior rule → feedback_ → CLAUDE.md/standards/
│       ├─ Reusable workflow → skill → ~/.claude/skills/
│       ├─ Scope decision → decision_ → vault + MEMORY.md
│       └─ P0/P1 incident → incident_ + adr_ → committed before next task
│
└─ No commit needed, but worth preserving?
    ├─ Hit ≥2× or >30min blocker → reference_ / gotchas.md
    └─ Single-session lesson → feedback_ (vault only)
```
