# AGENTS.md — sharekit-profile

> See `SOUL.md` for identity and philosophy. See `RULES.md` for constraints and hard rules.

This repo is the **sharekit operator harness profile**. It ships a portable, harness-agnostic workflow — skills, agents, hooks, standards, and a memory system that works with Claude Code, OpenCode, or any Claude-compatible CLI/provider. Claude Code is the primary distribution channel (npm package, marketplace listing) for discoverability; it is not the only supported way to run this profile.

## Governance

- `.harness/constitution.json` — source of truth for enforced invariants, branch policy, verification policy
- `.harness/constitution.md` — human-readable mirror of the JSON
- `.harness/mcp-policy.json` — MCP server policy (defaultDeny, approved servers, dangerous patterns)
- `docs/THREAT_MODEL.md` — committed threat model artifact
- `docs/hook-firing-order.md` — hook/skill firing order contract

## Harness support: any provider, any way of using

The skill/agent/hook library is the source of truth and is harness-agnostic — it installs into `~/.claude/` (Claude Code) and `~/.config/opencode/` (OpenCode) from the same tracked source, with drift detection keeping runtime copies identical. Neither harness is required over the other:

- **Claude Code** — supported natively, and the primary tag/discoverability surface (`npx @lucassantana/sharekit install`, marketplace listing).
- **OpenCode** — supported natively via `opencode/opencode.jsonc`, useful where its multi-provider routing matters. Default model: `anthropic/claude-sonnet-4-5` (Sonnet tier — implementation); small/planning model: `anthropic/claude-haiku-4-5` (Haiku tier). **Fallback provider: OpenRouter** when the primary provider is rate-limited or unavailable — configure via `opencode auth login openrouter` (set `OPENROUTER_API_KEY`).
- **Any other Claude-compatible CLI/provider** — the skills/hooks/standards are plain files (Markdown + shell + JSON); nothing in the profile hard-requires OpenCode's or Claude Code's runtime beyond how each harness loads skills.

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

- **`hooks/` vs `claude/hooks/` — two different trees, not duplicates.** `hooks/`
  (repo root) is this repo's *own* dev-time governance: what `.husky/pre-commit`
  and `.harness/manifest.json` run when *you* commit to sharekit-profile. It can
  assume tools present on a maintainer's machine (e.g. `rg`). `claude/hooks/` is
  the *distributable product* — what `npx sharekit install` copies into an end
  user's `~/.claude/hooks/`. It has to work with zero assumed dependencies
  (`grep`/`cat`, no `rg`), because it runs on machines this repo doesn't control.
  Some scripts share a name across both trees (e.g. `check-idempotency.sh`) because
  the repo dogfoods its own product for self-governance — expect small, intentional
  portability-driven diffs between same-named files in each tree, not drift to fix.
- `claude/CLAUDE.md` — operator config for Claude Code.
- `opencode.json` — OpenCode config.
- `docs/` — reference docs (overview, configuration, hooks, agents, composites).
- `scripts/check-catalog.sh` — validate the showcase skill catalog; also enforces a skill-count guardrail (warn >50, fail >75).
- `evals/routing/` — LLM-behavioral skill-routing eval gate (ported from harness-evals Phase 0, 2026-07-30): 40 frozen tasks, OpenRouter-pinned model, gate = accuracy drop >5pp vs fingerprinted baseline. `--validate-only` runs offline in CI; full gate needs `OPENROUTER_API_KEY`. Tasks expecting skills outside the listing under test are SKIPped, not scored.
- `~/.claude/settings.json` sets `skillListingBudgetFraction: 0.05` to keep Claude Code's skill listing from truncating at 200+ skills. If count grows past 75, run `skill-maintainer` to prune duplicates.

## Current state (2026-08-04)

**Schema validation:** `hooks/skill-validate.sh` reports `errors=0` after PRs #13-14 fixed 55 frontmatter errors (28 block-scalar descriptions → single-line, 2 missing `description:` fields inserted). 3 non-blocking warnings remain (per `hooks/skill-validate.sh --dir claude/skills`, 2026-08-04) — these are tracked in [`docs/skill-catalog-efficiency.md`](docs/skill-catalog-efficiency.md) but do not fail CI.

**Hook count:** 50 top-level `.sh` hook scripts in `hooks/` (this repo's own dev-governance tree)
plus 71 in `claude/hooks/` (the distributable product tree) — see "Harness files" above for why
these are two separate counts, not one drifted number. This section drifts fast (was 49 a day
after being corrected in #125); don't trust it without re-running `git ls-files hooks/ | grep '.sh$' | wc -l`.

**Skill count:** 49 skills listed in `index.html`'s `SKILLS` array (per `scripts/check-catalog.sh` 2026-08-02 canonical count; down from 103 via consolidation). `claude/skills/` itself holds 47 skill folders (`fd -t f '^SKILL\.md$' claude/skills`) — the array is now 2 *over* the folder count, not under: `add`/`debug`/`fallback` are listed built-in/composite entries with no dedicated `claude/skills/` folder (documented-but-not-a-directory, not drift). `check-catalog.sh` WARNs (non-blocking) if this gap ever changes shape. Archived skills live in `claude/skills/.archive/` for recoverability. Runtime skills are reconciled through canonical `~/.agents/skills`; `~/.claude/skills` is the symlinked runtime view and `~/.claude-env/skills` is a downstream mirror.

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

**Known limitation:** `hooks/skill-validate.sh` grep-based extractor cannot parse YAML block scalars (`|`, `>`, `>-`). Accepted as-is — block scalars are valid YAML but fail the validator; skill authors should use single-line descriptions.

## Storage

Live harness lives at `~/.claude/` (runtime) with tracked source at `~/.claude-env/`. Keep both in sync — the drift detector (`hooks/check-harness-drift.sh`) expects identical `agents/` and `hooks/` between them.

## Gotchas

- **Pre-commit hooks**: Always run before commits — use `HUSKY=0` prefix to skip only for non-code changes
- **Branch protection**: Cannot push directly to `main` — all changes must go through PR
- **Context limits**: At 20+ messages, save state to handoff and start a fresh session
- **Catalog counts**: index.html skill/agent/category counts are gated by `scripts/check-catalog.sh` against the `SKILLS`/`AGENTS` arrays; update the array entry, not just the displayed number, or the count silently drifts.
