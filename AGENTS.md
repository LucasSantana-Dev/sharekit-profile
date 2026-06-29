# AGENTS.md — sharekit-profile

This repo is the **sharekit operator harness profile**. It ships a portable Claude Code / OpenCode workflow: skills, agents, hooks, standards, and a memory system.

## Primary harness: OpenCode

OpenCode is the **first-choice harness** for this profile. Claude Code remains supported; OpenCode is preferred where its multi-provider routing and lower token overhead matter.

- Config: `opencode.json` at repo root.
- Default model: `anthropic/claude-sonnet-4-5` (Sonnet tier — implementation).
- Small/planning model: `anthropic/claude-haiku-4-5` (Haiku tier — mechanical/planning).
- **Fallback provider: OpenRouter** — used when the primary provider is rate-limited or unavailable. Configure via `opencode auth login openrouter` (set `OPENROUTER_API_KEY`).

## Model efficiency policy

Match model strength to task — high result per token:

- **Haiku** — mechanical work: formatting, symbol lookups, grep, simple renames, exploration, planning drafts.
- **Sonnet** — implementation, feature work, code review, single-phase dispatch.
- **Opus** — only deep reasoning: critic role, architecture review, cross-session synthesis, ADRs, ≥5-step reasoning.

Do not override tier for speculative speed. Use `/smart-model-select` when ambiguous.

## Analysis agents are read-only by construction

Any subagent dispatched for analysis (review, explore, plan, audit) must deny write/edit tools in its `permission` block — not just a prompt instruction. Edits from analysis are applied by the orchestrator or a separate implementer stage.

## Pattern Discovery Protocol (mandatory before implementation)

Before any non-trivial implementation (new feature, multi-file change, unfamiliar area), search first — do not implement from scratch when a pattern, prior decision, or existing code already solves the problem.

Search order:
1. **Specs** — `recall` or grep `docs/specs/` for prior decisions about this domain
2. **Codebase** — grep/glob for existing implementations of the same pattern
3. **Session history** — `recall` for prior reasoning on this topic
4. **Docs** — check `docs/`, `~/.claude/standards/`, README, CONTRIBUTING
5. **Architectural validation** — for non-obvious cases, route to @oracle for a recommendation before implementing

Philosophy: "Search First, Reuse Always, Create Only When Necessary."

This chains `context-pack` before `plan` / `scope-and-execute` / `refactor` — the auto-invoke already partially does this. The rule makes it explicit: skipping pattern discovery for non-trivial work is a defect.

Trivial single-file edits (<20 lines, known path) are exempt.

## Independence Gate (review/security/critic agents)

Review, security, and critic agents MUST be independent subagents — never collapsed into the implementer lane.

Roles that MUST be independent (not collapsible):
- **code-reviewer** — reviews implementation; cannot review its own work
- **security-reviewer** — audits for vulnerabilities; independence is the audit's value
- **critic** — adversarial multi-perspective review; collapsing it defeats the purpose

This extends the existing "Analysis agents are read-only by construction" rule: read-only is about tool permissions (no write/edit). Independence is about lane separation — even with no write tools, a reviewer running in the same context as the implementer has compromised objectivity.

When to spawn an independent review subagent:
- After @fixer completes implementation → dispatch @code-reviewer or @oracle for review
- Before merge → dispatch @code-reviewer for final gate
- For security-sensitive changes → dispatch @security-reviewer
- For high-stakes decisions → dispatch @critic for adversarial challenge

The orchestrator (or human) gates on the review subagent's exit state before advancing.

## Harness files

- `claude/CLAUDE.md` — operator config for Claude Code.
- `opencode.json` — OpenCode config (primary harness).
- `docs/` — reference docs (overview, configuration, hooks, agents, composites).
- `scripts/check-catalog.sh` — validate the showcase skill catalog; also enforces a skill-count guardrail (warn >250, fail >350).
- `~/.claude/settings.json` sets `skillListingBudgetFraction: 0.05` to keep Claude Code's skill listing from truncating at 200+ skills. If count grows past 300, raise the fraction OR run `skill-maintainer` to prune duplicates.

## Storage

Live harness lives at `~/.claude/` (runtime) with tracked source at `~/.claude-env/`. Keep both in sync — the drift detector (`hooks/check-harness-drift.sh`) expects identical `agents/` and `hooks/` between them.
