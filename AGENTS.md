# AGENTS.md — sharekit-profile

> See `SOUL.md` for identity and philosophy. See `RULES.md` for constraints and hard rules.

This repo is the **sharekit operator harness profile**. It ships a portable, harness-agnostic workflow — skills, agents, hooks, standards, and a memory system for Claude Code. Claude Code is the primary distribution channel (npm package, marketplace listing). OpenCode support is archived under `archive/opencode/`.

## Governance

- `.harness/constitution.json` — source of truth for enforced invariants, branch policy, verification policy
- `.harness/constitution.md` — human-readable mirror of the JSON
- `.harness/mcp-policy.json` — MCP server policy (defaultDeny, approved servers, dangerous patterns)
- `docs/THREAT_MODEL.md` — committed threat model artifact
- `docs/hook-firing-order.md` — hook/skill firing order contract

## Harness support: Claude Code

The skill/agent/hook library is the source of truth and is harness-agnostic — it installs into `~/.claude/` (Claude Code) from the tracked source, with drift detection keeping runtime copies identical:

- **Claude Code** — supported natively, and the primary tag/discoverability surface (`npx @lucassantana/sharekit install`, marketplace listing).
- **Any other Claude-compatible CLI/provider** — the skills/hooks/standards are plain files (Markdown + shell + JSON); nothing in the profile hard-requires more than how a harness loads skills.

## Model efficiency policy

Match model strength to task — high result per token:

- **Sonnet, low effort** — mechanical work: formatting, symbol lookups, grep, simple renames, exploration, planning drafts. Haiku is retired in this profile (`claude/standards/model-tiering.md`).
- **Sonnet** — implementation, feature work, code review, single-phase dispatch.
- **Opus** — only deep reasoning: critic role, architecture review, cross-session synthesis, ADRs, >=5-step reasoning.

Do not override tier for speculative speed. When ambiguous, choose the lightest tier that can satisfy the task and document the reason.

## Agent routing

| Complexity | Signals | Model tier |
|-----------|---------|------------|
| **Low** | Single-file edit, grep, config change | Sonnet (`effort: low`) |
| **Medium** | Multi-file feature, bug fix, test writing | Sonnet |
| **High** | Architecture, cross-repo, security audit | Opus |

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

- Medium effort is the default; raise it only for genuinely complex tasks
- Context is managed by Claude Code's automatic and idle compaction; `session-length-guard.sh` warns when a long or idle session gets expensive to keep (cache TTL), so there is no message-count rule
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
- `docs/` — reference docs (overview, configuration, hooks, agents, composites).
- `scripts/check-catalog.sh` — validate the showcase skill catalog; also enforces a skill-count guardrail (warn >250, fail >350).
- `evals/routing/` — LLM-behavioral skill-routing eval gate (ported from harness-evals Phase 0, 2026-07-30): 40 frozen tasks, OpenRouter-pinned model, gate = accuracy drop >5pp vs fingerprinted baseline. `--validate-only` runs offline in CI; full gate needs `OPENROUTER_API_KEY`. Tasks expecting skills outside the listing under test are SKIPped, not scored.
- `~/.claude/settings.json` sets `skillListingBudgetFraction: 0.015` and `skillListingMaxDescChars: 160` to keep the per-request skill listing small; rarely used skills carry `disable-model-invocation: true` (still usable as `/name`). If count grows past 350, run `skill-maintainer` to prune duplicates.

## Counts and inventory

Counts are not kept in this file: they drifted every week. Get them from the scripts that CI already runs:

- `bash scripts/check-catalog.sh`: skills and agents listed on the site vs on disk
- `bash scripts/check-marketplace.sh`: plugins, curated entries, hooks wired in `claude/settings.json`
- `claude/hooks/README.md`: the hooks the profile wires (keep it in step with `claude/hooks/hooks.json`)

Skill frontmatter: `description` must be a single line. `hooks/skill-validate.sh` cannot parse YAML block scalars (`|`, `>`, `>-`).

## Storage

Live harness lives at `~/.claude/` (runtime) with tracked source at `~/.claude-env/`. Keep both in sync — the drift detector (`hooks/check-harness-drift.sh`) expects identical `agents/` and `hooks/` between them.

## Gotchas

- **Pre-commit hooks**: Always run before commits — use `HUSKY=0` prefix to skip only for non-code changes
- **Branch protection**: Cannot push directly to `main` — all changes must go through PR
- **Catalog counts**: index.html skill/agent/category counts are gated by `scripts/check-catalog.sh` against the `SKILLS`/`AGENTS` arrays; update the array entry, not just the displayed number, or the count silently drifts.
