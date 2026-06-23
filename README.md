# Sharekit Profile: lucassantana

My Claude Code workflow — the operator `CLAUDE.md` plus 55 portable skills, install with one command.

## Install

```bash
npx @lucassantana/sharekit install LucasSantana-Dev
```

This previews the changes, backs up anything it overwrites, and mirrors into `~/.claude/`:
- **`CLAUDE.md`** — the operator workflow: default priorities, autonomy, model tiering (Opus/Sonnet/Haiku), skill-first execution, and the hard rules (parallel-execution mandate, read-only analysis agents, idempotency, no big-bang rewrites, stuck protocol, signal-first, verify-the-result).
- **55 skills** in `~/.claude/skills/` — behavioral + engineering, e.g.:
  - *prompting/behavior:* `caveman` (terse output), `ponytail` (lazy/minimal design), `brainstorming`, `xp`, `teach`, `three-man-team`, `plow-ahead`, `prototype`
  - *engineering:* `tdd`, `debug`, `refactor`, `review`, `dep-sweep`, `error-handling-audit`, `overengineering-audit`, `naming-consistency`
  - *testing:* `test-cleanup`, `test-health`, `mutation-test`, `coverage-gap`, `generate-tests`, `backend-testing`
  - *architecture:* `architecture-patterns`, `domain-modeling`, `codebase-design`, `coupling-map`, `refactor-plan`
  - *frontend:* `frontend-design`, `tailwind-design-system`, `shadcn`, `webapp-testing`, `design-an-interface`
  - *process:* `changelog-update`, `version-bump`, `setup-pre-commit`, `using-git-worktrees`, `quality-gates`, `pr-merge-readiness`

## Memory system (works out of the box)

A **persistent, file-based memory** for the agent — and the skills that run it work with **zero setup**:

- **`recall`** — retrieve relevant past knowledge before acting (scans `MEMORY.md` + `grep`, no database).
- **`sync-memories`** — capture a durable fact (one file + index update).
- **`knowledge-loop`** — pair recall + capture around a task.
- **`memory-prune`** — merge duplicates, drop stale facts.
- **`memory-eval`** *(advanced)* — gate retrieval quality so a change can't silently degrade recall; label-free regression gate over a golden set. Needs a retriever; the grep default needs none of it.

By default memory lives at `~/.claude/memory/` and recall is `grep`-based — nothing to install. Two optional upgrades via `settings.local.json` `env`: set **`BRAIN_ROOT`** to use a git repo (versioned, syncs across machines), and **`MEMORY_RETRIEVER`** to plug in any semantic/embedding search (falls back to `grep` when unset).

`claude/memory-structure/` documents the convention (`CORE.md` tier-0, `MEMORY.md` index, typed per-fact frontmatter: `user`/`feedback`/`project`/`reference`) with empty skeletons. The `rag` skill is a full RAG-pipeline guide if you want to build a retriever. **No personal memory content is included — only the structure and the skills.**

## Portable by design

These skills are machine-independent — paths and identity flow through env vars (`${DEV_ROOT}`, `${GITHUB_USER}`, …) rather than hardcoded values. Set yours in `~/.claude/settings.local.json` under `"env"` (or your shell). No personal infrastructure, IPs, or secrets are included.

Skills tied to a personal memory/RAG stack are intentionally excluded — this is the portable subset.

## Safety

- **Hooks are never auto-installed.** A profile's `settings.json` (which can run shell commands) is flagged and skipped unless you opt in with `--include-hooks`.
- **Everything is backed up** before it's applied; `npx @lucassantana/sharekit rollback LucasSantana-Dev` restores it.

---

Fork it, adapt it, make it yours. A workflow that nobody follows is worse than none.
