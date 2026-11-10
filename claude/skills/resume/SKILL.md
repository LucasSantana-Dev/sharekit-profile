---
name: resume
description: 'Rehydrate the current task from handoffs, plans and git. Triggers: resume, continue, what was I doing, where was I, wake up. Default is full; --brief gives a 4-section brief (~800 tokens).'
triggers:
  - resume
  - continue
  - what was I doing
  - where was I
  - wake up
  - bootstrap me
  - quick start
  - get me going
metadata:
  absorbs: wake-up
---

# resume

Recover state before doing new work. Two modes.

| Mode | Triggers |
|---|---|
| brief | `--brief`, "wake up", "wake me up", "quick start", "bootstrap me", "get me going", "quick brief", or a `session-bootstrap` call |
| full (default) | "resume", "continue", "what was I doing", "where was I", or an explicit argument N |

## Step 0: pick the handoff (both modes)

Never read only `latest.md` (legacy). A project has several open handoffs (`*.md`) plus `auto/*.md` compaction snapshots. Tool: `~/.claude/skills/handoff/bin/handoffs`.

0. Explicit argument: if invoked with N or a name fragment (with or without `--brief`), run `handoffs path <arg>` and skip the heuristic below. The SessionStart hook says "escolha com /resume N; nao assuma qual e o desta sessao", so never guess when an argument is given. Exit 1 (no match, or more than one) means run `handoffs list` and ask.
1. Run `handoffs list`. Lines look like `1)   3h  [auto] compact-1730  |  Auto snapshot (compaction)`: number, age, optional `[auto]`/`[legado]` label, stem, title. `[legado]` marks `latest.md`.
2. One open entry: read it with `handoffs path <stem>`.
3. Several entries: name them (title + age) in the reply and pick the most recent non-`[auto]` one. Brief mode or a `session-bootstrap` run: pick and state why in one line (for example it matches the current branch). Full and interactive: pick on a branch match, else ask which to resume. Use `[auto]` snapshots only as supporting context.
4. Every open entry is `[auto]`: use the newest `[auto]` as the handoff, labeled "auto snapshot, no written handoff", and say so in Context.
5. After listing, read with `handoffs path <stem>`, not a number: the list can reorder between calls (the tool's own `done` refuses numbers for this reason).
6. `handoffs list` says "sem handoff aberto": try `"$(handoffs dir)/latest.md"` (the tool resolves the project to the main repo, not a worktree basename). Print its age and label it "stale (>7d)" past the 7-day window. Then the global `~/.claude/handoffs/latest.md`, surfaced only if the project named inside matches cwd.
7. Read `latest.md` directly only if the `handoffs` tool is missing.
8. Never claim "no handoff" or "no context" while `handoffs list` shows entries.

## Mode: --brief

Cap output at **~800 tokens, structured**. Always these 4 sections, in this order, no extras:

```
## blockers
<1-3 bullets: what is preventing progress right now. Empty bullet ok if none.>

## what's next
<1-3 bullets: concrete next action(s). Cite file:line or PR# when applicable.>

## context
<3-5 bullets: recent decisions, prior reasoning, gotchas. Cite source.>

## fresh state
<one line: branch, git status counts, latest commit subject>
```

Pull order (stop at ~800 tokens):

1. Handoff from Step 0. Its "IMPLEMENT THIS" section feeds **what's next**; its blockers feed **blockers**. Any OPEN P0/P1 incident flag goes first in **blockers**.
2. RAG top 3: `rag_query(query="<handoff title or repo name>", top=3, scope_repos=null)`. Auto-scopes to cwd. Feeds **context**.
3. Newest memory note: `ls -t ~/.claude/projects/-Users-<github-user>/memory/*.md | head -1`, read about 40 lines. Use only if it adds something the handoff did not.
4. Git: `git status -sb && git log -1 --oneline`. One line into **fresh state**.
5. Swarm: only if `swarm_state.py` exists (path in full mode), run it; any LOST agent becomes one line in **blockers**.

Rules:

- Cite paths as `file:line` so the user can jump.
- Skip a section's content if there is no signal: empty is honest, padding is noise.
- Do not open files for context; RAG snippets are enough. Pull files only when the user picks a thread.
- Compress the handoff, never paste it or the fixtures back. Do not repeat a decision the handoff already states.
- With several open handoffs, name them in **context** and say which one the brief follows.
- No handoff at all: lead **what's next** with "no active handoff" and pull RAG on repo README/CHANGELOG topics.

## Mode: full (default)

Read order:

1. Handoff from Step 0.
2. Newest plan in `.claude/plans/` or `.agents/plans/`.
3. `.agents/memory/in-progress.md`.
4. Subagent checkpoints: `python3 "${DEV_ROOT:-$HOME/dev}/harness-evals/swarm_state.py"`. Any LOST in-flight agents from a crashed swarm must be re-dispatched or explicitly abandoned before new work; inspect their uncommitted worktree files first. Do not propose the next phase while agents are LOST.
5. Current git branch, status, and open PRs.

Post-incident check: after loading the handoff, scan for OPEN incident flags (P0/P1 failures). If present, surface them before anything else: a committed root-cause artifact (ADR or incident-log) is required before the next task proceeds. Do not recommend the next task, or silently skip the flag.

Return, in this order:

- open incident flags (first, if found)
- active objective
- repo, branch, worktree
- what is already done
- what remains
- exact next action (cite file:line)
- handoffs found (title + age) when more than one, and which was used

## Stop conditions

- No handoff, plan, or git context found (handoffs list empty, no fallback file): say "no context found" and ask for orientation. Do not invent a task.
- Full mode, several handoffs, no branch match, no argument: ask, do not guess silently. Brief mode picks and says why.

## Pair with

- `standards/session-budget.md`: when checkpoints and handoffs are created (70%/90% context) that resume rehydrates from.
- `context-pack` when the brief is not enough and a multi-source bundle is needed.
- `next-priority` when nothing is in flight and something must be picked.
- `session-bootstrap` calls `resume --brief` as its Phase 1.
