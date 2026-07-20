# Harness genericization — env-var indirection + personal-stack tiering

**Status:** ACCEPTED — 2026-06-23
**Scope:** the agent-os harness (`~/.agents/skills`, standards, hooks, `settings.*.json`)

---

## Context

The harness had machine-specific values hardcoded across **248 files** — `/Users/<user>` (127 files), the dev root (56), the operator's GitHub handle (143), homelab/Tailscale references (≈40), and a handful of real IPs. This coupling meant the harness only ran on one machine, couldn't be shared without a per-share sanitization pass that immediately drifts, and mixed personal infrastructure into otherwise-reusable skills.

A coupling audit (2026-06-23) found the problem is **tiered**, not uniform:
- **Mechanical** — paths + identity, ~170 files, deterministic find-replace.
- **Already solved** — secrets in `settings.json`/`.mcp.json` already use `${VAR}` indirection (`NEON_API_KEY`, `FIRECRAWL_API_KEY`, `SONARQUBE_TOKEN`, `TAVILY_API_KEY`, `NOTION_API_KEY`); 0 inline tokens.
- **Mostly noise** — most "IPs" are RFC-5737 documentation examples (`192.0.2.x`, `203.0.113.x`), not real infra.
- **Hard** — ~50 skills *assume* the personal RAG/vault/knowledge-brain/graphify/claude-mem stack; not find-replaceable.

## Decision

**1. Env-var indirection for paths + identity (Wave-1 — DONE).**
Skills reference `${DEV_ROOT}`, `${EXTERNAL_HD}`, `${GITHUB_USER}`, `${OPERATOR_EMAIL}`. The machine-specific values live in `~/.claude/settings.local.json`'s `env` block (per-machine, not shared) — the same mechanism the secrets already use. Documented in `.env.example`. A deterministic codemod converted 165 content files; eval-artifact dirs and `.log` files are excluded (a traceback's absolute path is not configurable and is not shipped).

**2. Personal-stack skills stay local (Wave-2 — DECIDED: tier, don't gate).**
The ~50 vault/RAG/graphify/memory skills are **tiered as "personal-stack" and kept local — not generified.** Capability-gating them to "degrade gracefully without a vault" (option A) was rejected: a `rag-maintenance` or `sync-memories` skill with no RAG/vault does nothing meaningful — these skills *are* the vault, so portability for them has ~no value. They resolve `${BRAIN_ROOT}` etc. from the optional env vars and otherwise remain personal.

**3. Secrets — formalize, don't rebuild.** Already env-var'd; `.env.example` now documents the required keys. No inline secrets to extract.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| Maintain a hand-sanitized share fork (per the earlier "public subset" plan) | Rejected — treats the symptom; drifts from the real harness every share. Fix the source instead. |
| Wave-2 option A: capability-gate the ~50 vault skills to run without the stack | Rejected — those skills are intrinsically about the personal memory system; "works without a vault" is mostly nonsensical. Revisit only on concrete demand to run them sans-vault. |
| Big-bang rewrite of all 222 skills | Rejected — the operator's own no-big-bang rule. Piloted on one skill, measured (2 friction points, below the escalation gate), then swept. |

## Consequences

**Positive:** the ~170 portable skills are now machine-independent and shareable by export (no sanitization fork); secrets never live in shared files; adopters set a handful of env vars. Sharing/`sharekit`/`forgekit`-export becomes a clean pull, not a maintained sanitization.

**Negative:** skills now require the `env` block to be set (or the `${VAR}` renders literally); documented in `.env.example`. The ~50 personal-stack skills remain non-portable by design.

**Neutral:** `frontend-workspace` (9 MB of eval artifacts) was left as-is — it's a personal eval workspace, not a portable skill.

## Revisit when

- A concrete need arises to run a vault/RAG skill on a machine without the vault → reopen Wave-2 option A (capability-gating) for that specific skill.
- The env block proves error-prone in practice → consider a sourced config file or a config-loader shim.
- More than a couple of skills accumulate eval-artifact bloat → add a shared `.gitignore` rule for `iteration-*/`, `rendered*/`, `run-*/`, `*.log`.

## Validation

- Codemod: **158 content files** converted (156 `.md` + 2 `.sh`); post-sweep residual of hardcoded `${DEV_ROOT}` and `/Users/<user>` in content = **0** (fixed-string verified). `${EXTERNAL_HD}`×47, `${DEV_ROOT}`×22, `${GITHUB_USER}`×17.
- **`.py` decoupled properly (7 files, DONE):** the string codemod first broke them (`${VAR}` is a dead literal in Python — `Path('$HOME/...')` ≠ home), caught by file-type verification and reverted, then **re-done idiomatically**: 6 skill-maintainer scripts use `Path.home()`; `token-audit/audit.py` derives the Claude project-dir slug prefixes from `Path.home()`/`os.environ['DEV_ROOT']`/`['EXTERNAL_HD']` (which resolve to the exact original values — verified by parity check), keeping the personal project labels as data. All 7 compile; 8/9 skill-maintainer tests pass (the 1 failure is a pre-existing env-dependent "real roots" smoke, confirmed against backup). Lesson: a string-substitution codemod is safe for markdown + shell, **not** for code/config where `${VAR}` doesn't auto-expand — for code, decouple idiomatically (`Path.home()`/`os.environ`) and verify the derived values match the originals.
- `settings.local.json` `env` block added and JSON-validated; the 212 permission rules untouched.
- Full pre-sweep backup tarball retained; `~/.agents/skills` is git-tracked (not committed/pushed — left for operator review).
- Gotcha recorded: macOS/BSD `sed -E` silently ignores `\b`; the identity pass was redone with a `\b`-free replacement.
