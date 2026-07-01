# Skill Consolidation & Reinforcement — Synthesized Plan

**Status:** Approved 2026-07-01. Phase 1 DONE, Phase 2 DONE (hit its own escalation gate), Phase 3 DONE (scoped per user's go/no-go answer: mcp-policy.json routing contract + structured redirects.yaml; skipped standards frontmatter/harness-doctor.sh/routing evals). Phase 4 not started.
**Date:** 2026-07-01 (executed same day as written)
**⚠️ Working location changed mid-execution:** all work after Phase 2 moved from the original shared checkout (`/Volumes/External HD/Desenvolvimento/sharekit-profile`) to a dedicated worktree at `/Volumes/External HD/Desenvolvimento/.worktrees/skill-consolidation-1` on branch `chore/skill-consolidation-reinforcement`, off `origin/main` (`b8b5f1f`). Reason: a second live session was concurrently editing the shared checkout (no worktree) to purge an exposed client script via `git filter-repo` + a temporary branch-protection-flip force-push, which silently reverted several of this session's uncommitted edits (see `feedback_concurrent_session_same_checkout` memory note). **Nothing has been committed or pushed from the worktree yet** — all Phase 1-3 changes exist only as uncommitted working-tree edits in the worktree as of this writing.

**Recovery note:** the silent revert was more extensive than first caught — `index.html`'s `ads`/`marketing` entries, `AGENTS.md`'s skill count, `README.md` (6 spots), and `docs/composites.md`'s `/ads` entry (all from an *earlier, separate* session predating this plan) had all reverted to match `origin/main`/old HEAD, undetected until `check-harness-manifest.sh`'s fingerprint check and manual grep caught the discrepancies. All were redone from memory in the worktree and re-verified. `.harness/manifest.json`'s fingerprints for `mcp-policy.json`, `AGENTS.md`, `README.md`, and `docs/skill-catalog-efficiency.md` were refreshed accordingly.
**Sources reconciled:** 5 of 6 Warp Drive notebooks (exported to `~/.agents/plans/`):
- Harness & Skill Efficiency Continuation (COMPLETED 2026-06-30 — historical only)
- Skill Capability Preservation and Lean Catalog Reinforcement
- Removed Skill Capability Consolidation Plan
- Reinforce Support Layers to Backstop the Lean Skill Catalog
- Harness Improvement — Deep-Research Findings & Self-Improvement Roadmap

**Missing:** "SAFe Agentic Workflow Integration Plan" was never exported/found. Not blocking this plan (its scope is unknown) — re-run `/plan` on it separately once available.

## Why this plan exists, not a straight copy of the notebooks

The 4 active-scope notebooks were written across different Warp sessions and describe overlapping work at different completion states, using stale counts (50 skills, "56-58 runtime skills," "no `claude/settings.json`," etc.). Before planning further work, 4 parallel read-only agents verified actual current repo state. Several notebook claims are now **stale/resolved**; the plan below reflects only what's still real.

## Current state (verified 2026-07-01, not assumed)

| Claim (from notebooks) | Verified reality | Verdict |
|---|---|---|
| Catalog at 50 active skills | **51** (this session added `ads`, a new paid-ads-audit domain skill) | Catalog is fine; docs partially stale |
| `skill-validate.sh`, `check-catalog.sh`, `check-catalog-canonical.sh`, `check-harness-boundary.sh` | All 4 pass green (51 skills, 39 agents, 16 categories, errors=0) | ✅ No validation debt |
| `docs/skill-catalog-efficiency.md` reflects current count | Still says "50 active skill folders" | ❌ Stale — small fix needed |
| Runtime (`~/.claude/skills`) has 56-58 skills vs repo's 50 (drift) | One check claimed runtime has **0** skills — almost certainly a `find` без `-L` bug (the path is a symlink per ADR-0041) | ⚠️ Unverified — recheck with `find -L` before acting, don't trust either number blindly |
| "No `claude/settings.json` exists, hooks are orphan artifacts" (self-improvement flywheel P0 blocker) | `claude/settings.json` **exists**, wired to 8 lifecycle hook events; `.harness/constitution.json` + `mcp-policy.json` provide a parallel enforcement layer | ✅ Stale claim — P0 done |
| Flywheel P1 (observability/eval baseline) not built | `eval-baseline.sh`, `eval-run.sh`, `eval-tasks.sh`, `tool-shortlist.sh` exist and wired | ✅ Done |
| Flywheel P2 (5 scripts: history/propose/gate/deploy-watch/repo-map) | All 5 exist, 710 combined lines, wired (`gate.sh` → `policy-gate.sh`, exit-2 deterministic DENY) | ✅ Done |
| Flywheel P3 (cycle runner + tool-shortlist hook + cache-aware routing) | `cycle.sh` (481 lines), `diagnose.sh`, `distill.sh` operational; `tool-shortlist.sh` + `model-cache-guard.sh` wired | ✅ Done |
| Knowledge-brain drift: "8,120 chunks, ~50 stale, coverage gap" | Current: 7,903 chunks, **0 stale**, drift-reindex ran clean 2h ago; memory files have 0 active recommendations of removed skills | ✅ Better than claimed — no repair needed |
| Ponytail/secure/quality-gates/quality-assurance capability merges | All DONE — verified via diff read (severity=harm×reach, evidence rule, do-not-flag list present in ponytail; consolidated routing in quality-assurance/quality-gates) | ✅ Done |
| `debug` absorbed systematic-debugging's 4-phase loop | PARTIAL — has a 9-step approach but not the explicit 4-phase framing or the "≥3 failed fixes → question architecture" red-flag rule | ⚠️ Real gap |
| `rag-maintenance` absorbed adt-rag-coverage/adt-rag-drift | PARTIAL — `rag-quality`/`rag-curate` were properly inlined ("Integrated former X behavior"), but `adt-rag-coverage`/`adt-rag-drift` are still referenced as `**Invoke:**` targets even though both are archived in this repo (`claude/skills/.archive/`) | ⚠️ Real gap — genuine dangling reference |
| `knowledge-loop` frontmatter | Description still names archived `rag-curate` instead of `rag-maintenance` (body/Phase-3 logic is already correct) | ⚠️ Real gap, cosmetic |
| `memory-prune` references | Still cites archived `adt-rag-drift`/`rag-curate` as supporting skills | ⚠️ Real gap, cosmetic |
| No superseding memory for the 50/51-skill catalog decision | Confirmed absent | ⚠️ Real gap |

## Goal

Close the remaining real gaps from the consolidation work without re-litigating what's already done, without expanding scope into the (already-shipped) self-improvement flywheel, and without raising the active skill count.

## In scope

- Fix the 4 confirmed dangling/stale references (`rag-maintenance`, `debug`, `knowledge-loop`, `memory-prune`).
- Bump `docs/skill-catalog-efficiency.md` to the current 51-skill state (same pattern already applied to README/AGENTS/composites.md this session).
- Re-verify the runtime-vs-repo skill drift number properly.
- Write one superseding knowledge-brain memory for the 50→51 catalog transition.

## Out of scope (this pass)

- Self-improvement flywheel P4/P5 (context-KG memory, deterministic multi-agent orchestration core, external governance layer, skill marketplace) — P0-P3 are done; P4+ is a large, separate initiative that deserves its own `/research-and-decide` pass, not a tack-on here.
- The "Reinforce Support Layers" plan's Phase 2-5 (redirects.yaml ledger, standards frontmatter, `harness-doctor.sh`, routing-eval fixtures) — real value, but `.harness/constitution.json` + `mcp-policy.json` already cover meaningful ground here; building a parallel doctor script without first checking for overlap risks duplicating governance surfaces. Needs a scoped review, not blind execution — see Phase 3 below.
- Re-running any deletion pass, raising the skill count, or touching anything already verified DONE above.
- The unread "SAFe Agentic Workflow Integration Plan."

## Phases

### Phase 1 — Close the 4 confirmed dangling/stale references (small, mechanical) — ✅ DONE 2026-07-01
1. ✅ `claude/skills/rag-maintenance/SKILL.md`: inlined `adt-rag-coverage`/`adt-rag-drift` as `**Integrated former X behavior:**` sections; moved exact sqlite/report commands to new `references/coverage-drift-queries.md`; also fixed a second dangling ref in the Stop/Failure Conditions section (`adt-rag-coverage flags for escalation`) found during validation, and a pre-existing invalid-YAML frontmatter bug (unquoted colon in a plain-scalar description — collapsed to a single-line quoted string).
2. ✅ `claude/skills/debug/SKILL.md`: restructured the existing 9 steps under explicit Phase 1-4 headers (Investigation/Pattern Analysis/Hypothesis & Testing/Implementation), linked the 3 previously-orphaned `references/*.md` files (root-cause-tracing, condition-based-waiting, defense-in-depth — they already existed on disk but SKILL.md never pointed to them), and sharpened "≥2 fixes failed" to explicitly say "return to Phase 1, not Phase 4."
3. ✅ `claude/skills/knowledge-loop/SKILL.md`: fixed frontmatter description + reconciliation-block + stop-conditions line (3 spots, not just 1) from `rag-curate` → `rag-maintenance`.
4. ✅ `claude/skills/memory-prune/SKILL.md`: replaced `adt-rag-drift`/`rag-curate` references with `rag-maintenance` (2 spots).
5. ✅ `docs/skill-catalog-efficiency.md`: bumped 3 count instances (headline blockquote, execution status, problem statement) 50→51 with an `ads` addition note.
6. ✅ (found during validation, not in original scope) `curated-skills.txt` was missing `ads` entirely — added it alphabetically.
7. ✅ (found during validation) `index.html`'s `ads` SKILLS entry + `marketing` CATEGORIES entry + count bumps, added in the prior session's `/plan` turn, had been silently reverted — `git diff index.html` showed the file exactly matching HEAD despite no intentional revert this session. Root-caused via `git reflog` + `git fsck --unreachable`: found a stash-shaped dangling commit (`untracked files on chore/harness-skill-efficiency-pass`) from an unrelated earlier branch, not today's edit — recovery from it was checked and ruled out (didn't contain the `ads` content). Redid the edit directly from memory. **Open concern, not resolved:** the actual mechanism that reverted the working-tree edit was not conclusively identified — candidate cause is a parallel `Explore`-type investigation subagent running `git` commands (diff/stash) as part of "read-only" analysis; `Explore` agents have unrestricted `Bash`, so "read-only by agentType" does not guarantee no destructive git operations. Worth a memory note + tighter agent prompting (explicitly forbid `git stash`/`checkout`/`reset` in analysis-agent prompts) as a follow-up, not resolved in this pass.

**Validation:** `rg -n 'adt-rag-coverage|adt-rag-drift|rag-quality|rag-curate' claude/skills docs` → clean (3 remaining hits are legitimate historical/documentary context: a P1-execution-history line in skill-catalog-efficiency.md, the intentional "no separate X sub-skills" self-description in rag-maintenance's own frontmatter, and the intentional archived→active replacement table in docs/composites.md). `skill-validate.sh` → 51 skills, errors=0. `check-catalog.sh` → 51 skills, 39 agents, 16 categories, consistent. `check-catalog-canonical.sh` → no stale showcase entries. `check-harness-boundary.sh` → OK. All green.

### Phase 2 — Verify runtime/repo skill drift properly — ✅ DONE 2026-07-01, hit its own escalation gate
1. ✅ Re-ran with `find -L`: runtime (`~/.claude/skills` → resolves to `~/.agents/skills`, canonical per ADR-0041) has **229** skills. Repo (`claude/skills`) has **51**. The earlier "0 runtime skills" claim was confirmed to be exactly the suspected `find`-without-`-L` bug.
2. **Not classified individually — escalated per this phase's own stop condition** ("if the gap is large (>10 skills either direction), don't resolve inline"). 229 vs 51 is a 178-skill gap, far past that threshold. More importantly, the framing itself is wrong: `curated-skills.txt`'s own header says this repo is "Curated portable skills for the **sharekit public profile** (ADR-0039)" — i.e. a deliberately small, curated *public export* of a much larger personal global skill library, not a 1:1 runtime mirror. The prior notebooks' assumption (drift between near-equal counts, e.g. "56-58 vs 50") no longer matches reality now that the real ratio is visible. Reclassifying 178 skills one-by-one as promote/merge/keep-runtime-only/archive is a large, separate undertaking — not a "recheck."

**Validation:** drift count is a known, explained number (229 vs 51) with a root-cause (curated-subset architecture, not sync failure) — satisfies "every difference has an explicit classification" at the aggregate level; per-skill classification is out of scope for this phase.

**Escalation, not a blocker:** this doesn't block anything already shipped (Phase 1's fixes are independent of this number). It's a scope decision for later: does "repo/runtime drift" even need reconciling, given the public/private split is intentional? Recommend treating this as a closed question ("not drift, it's the curated-export architecture working as designed") unless there's a specific skill known to be missing from the public repo that should be there.

**Stop condition:** if the gap is large (>10 skills either direction), don't resolve inline — escalate as its own follow-up plan; this phase is a recheck, not a resync project.

### Phase 3 — Scoped review of "Reinforce Support Layers" before building anything new — ✅ DONE 2026-07-01
1. ✅ Read `.harness/constitution.json`, `.harness/mcp-policy.json`, `.harness/manifest.json` in full; also checked `standards/` (repo has exactly 1 unrelated file, `typed-result-schema.md` — the real target of "standards frontmatter" is the *global* `~/.claude/standards/`, outside this repo) and `evals/` (doesn't exist).
2. ✅ Classification: `redirects.yaml` → **extend** (docs/composites.md's table covers it conceptually for ~17 named skills, not all 53 — structured, not built fresh). Standards frontmatter → **out of scope for this repo** (wrong target). `harness-doctor.sh` → **deferred** (its prerequisite ledger wasn't complete; `check-harness-manifest.sh` already covers fingerprint-integrity doctoring). MCP routing contract → **extend** (the one concrete, right-sized gap). Routing eval fixtures → **deferred/optional** (`composite-router.sh` already does this live).
3. ✅ Per user's go/no-go answer ("also structure redirects.yaml"): built exactly 2 of the 4 proposed artifacts, both as *extensions* of existing files, not new parallel systems:
   - `.harness/mcp-policy.json`: added a `routingContract` object with `use_when`/`do_not_use_when`/`fallback`/`expected_callers` for all 8 approved servers, plus a `meta` note citing this plan.
   - `.harness/redirects.yaml` (new file): structured the existing `docs/composites.md` replacement table into 17 machine-parseable disposition entries (`absorbed_by`/`replaced_by_rule`), explicitly scoped-noted as covering only the documented table, not a full 53-skill audit.
   - Did NOT build `harness-doctor.sh` or `evals/routing/*.yaml` — deferred per classification.

**Validation:** `.harness/mcp-policy.json` valid JSON, `.harness/redirects.yaml` valid YAML, `bash scripts/check-harness-manifest.sh` passes (fingerprints refreshed for `mcp-policy.json`, `AGENTS.md`, `README.md`, `docs/skill-catalog-efficiency.md`). All 4 catalog gates (`skill-validate.sh`, `check-catalog.sh`, `check-catalog-canonical.sh`, `check-harness-boundary.sh`) still green after the phase.

### Phase 4 — Knowledge-brain closure (small) — ✅ DONE 2026-07-01
1. ✅ Wrote `project_skill_catalog_state_2026-07-01.md` (global memory, project-type) documenting the 103→50→51 transition, why (`ads` is additive, not a re-expansion), current validation state, the runtime-vs-repo curated-export clarification from Phase 2, and a pointer to the concurrent-session caveat. Indexed in `MEMORY.md`. No prior memory existed to supersede (confirmed absent during Phase 0 ground-truth check) — this is a net-new entry, not an overwrite.

**Validation:** memory file exists at `~/.claude/projects/-Volumes-External-HD-Desenvolvimento-sharekit-profile/memory/project_skill_catalog_state_2026-07-01.md`, indexed in `MEMORY.md`.

## Non-goals (repeated from source plans, still binding)

- Do not re-run a broad skill deletion campaign.
- Do not raise the active repo skill count above its current value without explicit approval.
- Do not permanently delete archived skills.
- Do not commit changes unless explicitly requested.
- Do not start Phase 3's build step before its classification step.
- Do not start self-improvement flywheel P4/P5 work as part of this plan.

## Open question for the user

Phase 3's outcome depends on how much overlap exists between `.harness/*` and the proposed `redirects.yaml`/`harness-doctor.sh`/standards-frontmatter system — worth a quick go/no-go check-in after Phase 3's classification step, before any new file gets built, since that's the one phase where scope could expand significantly.
