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

## Memory structure

`claude/memory-structure/` is a convention for giving the agent a **persistent, file-based memory** that survives across sessions — `CORE.md` (tier-0), a `MEMORY.md` index, and one fact per file with typed frontmatter (`user`/`feedback`/`project`/`reference`). It's the *methodology + skeletons*, not anyone's actual memories. A few session/RAG skills that operate it are included (`session-bootstrap`, `context-save`, `adt-rag`); the deeper memory automation assumes a personal vault+retriever stack and is left out by design.

## Portable by design

These skills are machine-independent — paths and identity flow through env vars (`${DEV_ROOT}`, `${GITHUB_USER}`, …) rather than hardcoded values. Set yours in `~/.claude/settings.local.json` under `"env"` (or your shell). No personal infrastructure, IPs, or secrets are included.

Skills tied to a personal memory/RAG stack are intentionally excluded — this is the portable subset.

## Safety

- **Hooks are never auto-installed.** A profile's `settings.json` (which can run shell commands) is flagged and skipped unless you opt in with `--include-hooks`.
- **Everything is backed up** before it's applied; `npx @lucassantana/sharekit rollback LucasSantana-Dev` restores it.

---

Fork it, adapt it, make it yours. A workflow that nobody follows is worse than none.
