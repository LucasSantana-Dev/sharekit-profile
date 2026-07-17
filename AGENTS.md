# AGENTS.md — sharekit-profile

> See `SOUL.md` for identity and philosophy. See `RULES.md` for constraints and hard rules.

This repo is the **sharekit operator harness profile**. It ships a portable Claude Code / OpenCode workflow: skills, agents, hooks, standards, and a memory system.

## Governance

- `.harness/constitution.json` — source of truth for enforced invariants, branch policy, verification policy
- `.harness/constitution.md` — human-readable mirror of the JSON
- `.harness/mcp-policy.json` — MCP server policy (defaultDeny, approved servers, dangerous patterns)
- `docs/THREAT_MODEL.md` — committed threat model artifact
- `docs/hook-firing-order.md` — hook/skill firing order contract

## Primary harness: OpenCode

OpenCode is the **first-choice harness** for this profile. Claude Code remains supported; OpenCode is preferred where its multi-provider routing and lower token overhead matter.

- Config: `opencode/opencode.jsonc` (OpenCode config, primary harness).
- Default model: `anthropic/claude-sonnet-4-5` (Sonnet tier — implementation).
- Small/planning model: `anthropic/claude-haiku-4-5` (Haiku tier — mechanical/planning).
- **Fallback provider: OpenRouter** — used when the primary provider is rate-limited or unavailable. Configure via `opencode auth login openrouter` (set `OPENROUTER_API_KEY`).

## Model efficiency policy

Match model strength to task — high result per token:

- **Haiku** — mechanical work: formatting, symbol lookups, grep, simple renames, exploration, planning drafts.
- **Sonnet** — implementation, feature work, code review, single-phase dispatch.
- **Opus** — only deep reasoning: critic role, architecture review, cross-session synthesis, ADRs, >=5-step reasoning.

Do not override tier for speculative speed. When ambiguous, choose the lightest tier that can satisfy the task and document the reason.

## Agent routing

| Complexity | Signals | Model tier |
|-----------|---------|------------|
| **Low** | Single-file edit, grep, config change | Haiku |
| **Medium** | Multi-file feature, bug fix, test writing | Sonnet |
| **High** | Architecture, cross-repo, security audit | Opus |

### OpenCode Go tier (`opencode-go/*` namespace)
The `opencode-go/*` namespace exposes 13 models via the OpenCode Go subscription gateway. Route by capability: `glm-5.2`/`deepseek-v4-pro`/`qwen3.7-max` for implementation, `deepseek-v4-flash`/`mimo-v2.5` for mechanical work, `kimi-k2.7-code` for code-tuned tasks.

### Role agents (subagents in `agent/roles/`)
- `critic` — adversarial multi-perspective review of plans/code (read-only)
- `code-reviewer` — severity-rated review, SOLID/logic/security checks (read-only)
- `security-reviewer` — OWASP Top 10, secrets, unsafe patterns (read-only)
- `debugger` — root-cause analysis, regression isolation (write-capable)
- `test-engineer` — TDD, integration/e2e coverage, flake hardening (write-capable)

## Skill auto-invoke

Auto-trigger without being asked: `self-heal`/`debug` on errors, `eval` on LLM output, `context` at >=50%, `memory` at session end, `secure` on auth/payments, `verify` before every PR.

### Composite-first principle
When the user's intent matches a composite skill, ALWAYS invoke the composite — never the individual sub-skills. The full trigger map lives in `~/.agents/skills/standards/skill-auto-invoke.md`.

## Session budget

- `model_reasoning_effort = "medium"` is the default — only escalate for genuinely complex tasks
- After every 12 messages: warn "Context at ~45%"
- After every 18 messages: warn "Context ~70% — compact immediately"
- After every 22 messages: auto-generate a handoff file at `~/.claude/handoffs/<project>/latest.md`
- Commit after each functional step — smaller commits mean less re-work if a session ends

## Harness files

- `claude/CLAUDE.md` — operator config for Claude Code.
- `opencode.json` — OpenCode config (primary harness).
- `docs/` — reference docs (overview, configuration, hooks, agents, composites).
- `scripts/check-catalog.sh` — validate the showcase skill catalog; also enforces a skill-count guardrail (warn >50, fail >75).
- `~/.claude/settings.json` sets `skillListingBudgetFraction: 0.05` to keep Claude Code's skill listing from truncating at 200+ skills. If count grows past 75, run `skill-maintainer` to prune duplicates.

## Current state (2026-06-30)

**Schema validation:** `skill-validate.sh` reports `errors=0` after PRs #13-14 fixed 55 frontmatter errors (28 block-scalar descriptions → single-line, 2 missing `description:` fields inserted). 262 non-blocking warnings remain (261 "no triggers field" + 1 "description exceeds 500 chars") — these are tracked in [`docs/skill-catalog-efficiency.md`](docs/skill-catalog-efficiency.md) but do not fail CI.

**Hook count:** 42 hook scripts in `hooks/` (up from 30+ at session start).

**Skill count:** 51 active skill folders in `claude/skills/` (down from 103 via consolidation to 50, +1 `sync-memories` restored from archive as `invocation_type: internal` 2026-07-01 — was misapplied archival, is a required `knowledge-loop` sub-skill; 52 archived in `claude/skills/.archive/` for recoverability; `ads` moved to its client project 2026-07-01). Runtime skills are reconciled through canonical `~/.agents/skills`; `~/.claude/skills` is the symlinked runtime view and `~/.claude-env/skills` is a downstream mirror.

**P8+P9 hooks shipped:**
- `hooks/reorder-context.sh` — post-compaction attention reordering (LlamaIndex-style)
- `hooks/checklist-gate.sh` — binary security/release checklist enforcement
- `hooks/transcript-scanner.sh` — 6 pattern scanners (refusals, eval-awareness, env-drift, hallucination, excessive-agency, injection tells)
- `hooks/trial-apply.sh` — materializes candidate hook edits into `.harness/forge/trial/` for isolated gating
- `hooks/gate.sh` — gains `--proposal` + `--candidate` modes
- `hooks/eval-run.sh` — gains `--seed` parameter for stateful hooks
- `hooks/cycle.sh` — wires deploy-watch post-merge hook
- `hooks/check-stuck-loop.sh` — gains real state file
- `hooks/reflect-retry.sh` + `hooks/textgrad.sh` — advisory reflection + textual gradient

**Known limitation:** `skill-validate.sh` grep-based extractor cannot parse YAML block scalars (`|`, `>`, `>-`). Accepted as-is — block scalars are valid YAML but fail the validator; skill authors should use single-line descriptions.

## Storage

Live harness lives at `~/.claude/` (runtime) with tracked source at `~/.claude-env/`. Keep both in sync — the drift detector (`hooks/check-harness-drift.sh`) expects identical `agents/` and `hooks/` between them.

## Gotchas

- **Pre-commit hooks**: Always run before commits — use `HUSKY=0` prefix to skip only for non-code changes
- **Branch protection**: Cannot push directly to `main` — all changes must go through PR
- **Context limits**: At 20+ messages, save state to handoff and start a fresh session
- **Catalog counts**: index.html skill/agent/category counts are gated by `scripts/check-catalog.sh` against the `SKILLS`/`AGENTS` arrays; update the array entry, not just the displayed number, or the count silently drifts.
