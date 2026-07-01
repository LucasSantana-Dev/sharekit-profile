# AI & Agents Skills

Use active orchestration skills for multi-agent work and model-tier policy from `AGENTS.md` for model selection. Archived model-selection slash wrappers are replaced by policy and routing hooks.

---

## /dispatch

Fan out independent investigation or low-conflict work and reconcile results.

---

## /orchestrate

Coordinate multi-agent teams, worktrees, branches, dependency barriers, validation, and artifact handoff.

---

## /three-man-team

Architect → Builder → Reviewer lane separation for high-complexity implementation.

---

## Model-tier policy

- Haiku: mechanical search, formatting, simple renames, planning drafts.
- Sonnet: implementation, feature work, code review, test generation.
- Opus: critic role, architecture review, ADRs, cross-session synthesis, deep reasoning.

Choose the lightest tier that can satisfy the task. Do not override for speculative speed.

---

## Durable/background agent patterns

Use project-specific tools or external runners only when they are configured in the target repo. Keep portable sharekit guidance in active skills and standards; avoid creating narrow wrappers for each runner.

**Last updated:** 2026-07-01
