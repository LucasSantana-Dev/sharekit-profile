---
name: resume
description: Rehydrate interrupted work—recover task state from handoffs, plans, in-progress memory, or git when context is lost. Use when rejoining a session, resuming after a handoff, or clarifying "where were we."
metadata:
  tier: foundational
  owner: core
  canonical_source: standards/session-resume.md
triggers:
  - resume session
  - continue work
  - what was I doing
  - recover task state
---

# resume

Restore active task context before continuing work.

## Step 1: Query prior context from memory/vault

**Done when:** Found ≥1 source or confirmed none exist.

Mount guard: `mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — handoffs unreachable"; exit 1; }`

Query order (stop at first match):
1. Project handoff: `rag_query(query="current task state", top=1, scope_types=["handoffs"])` for `~/.claude/handoffs/<project>/latest.md`
2. Global handoff: `rag_query(query="in-progress work", top=1, scope_types=["handoffs"])` for `~/.claude/handoffs/latest.md`
3. Memory recall: `search_knowledge(query="active objective status", top=3)` for `.agents/memory/in-progress.md`

If no RAG/vault hit: fall back to filesystem—read newest `.claude/plans/` or `.agents/plans/` by mtime; surface blocker if none found.

**Blocker:** No handoff, plan, or in-progress note found → Surface: "resume: no prior context found; start fresh or specify task." Halt.

## Step 2: Load git state (branch, uncommitted changes, open PRs)

**Done when:** Branch name, worktree path, and git status visible; any open PR linked.

Sequence:
- `git rev-parse --abbrev-ref HEAD` — current branch
- `git status --short` — uncommitted changes (stops if diverges significantly)
- `git log -1 --oneline` — latest commit for context
- If active repo is known: `gh pr list --state open --author @me --json number,title,url` — open PRs

## Step 3: Signal-first summary

**Done when:** User sees verdict + 3-line state summary inline.

Output (in order):
1. **Verdict** — "Resume from [handoff|plan|in-progress] at [task name]" OR "No prior state; starting fresh"
2. **Active objective** — 1 sentence (from recovered context)
3. **Current state** — repo, branch, worktree, uncommitted changes (if any), open PR (if relevant)
4. **Exact next action** — the stated next step from handoff, or derived from remaining work
5. **Blockers** — if any (missing handoff, stuck test, etc.)

Cite sources: "From: ~/.claude/handoffs/latest.md (recovered 2m ago)" or "From: git branch/status."

Cross-reference: See `standards/session-resume.md §1-4` for read order and behavior.
