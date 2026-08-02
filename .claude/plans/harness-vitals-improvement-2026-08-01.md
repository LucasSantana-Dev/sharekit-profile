# Plan: Harness vitals improvement (data-driven)

**Date:** 2026-08-01
**Status:** draft — needs confirm before Phase 1/2/4/5 execute (git push, deletes, config change, doc edit)

## Goal

Fix the 7 concrete issues `harness-vitals.sh` flagged this session, plus fold in findings from 3 deep-research passes (ADR-0005 observability reopen, skill-catalog health, security posture vs 2026 threats) run the same day — one data-driven pass instead of scattered fixes.

## Scope

### In-Scope
- `~/.claude-env` and `~/.agents/skills` sync recovery (unpushed commits, failed SessionEnd push).
- Three-way `model` setting conflict (live/shared/machine).
- Stale RAG nightly-rebuild launchd job (130h vs 36h expected).
- Canonical `~/.agents/skills` hygiene: 87 broken symlinks, 127 live/archive name duplicates.
- `docs/THREAT_MODEL.md` revision per security-research findings (indirect injection, CVE-2025-59536 config-injection class, MCP credential handling).
- This repo's (`sharekit-profile`) stale catalog counts in `CLAUDE.md` (claims 51/52, actual 47/1).
- ADR-0005 status note update (defer confirmed, triggers revised — no code action).

### Out-of-Scope
- Adopting Langfuse/Inspect AI/OpenHands/Agno now — research confirms the defer holds; only a memory-note update is in scope, not tooling adoption.
- Building a skill-sourcing vetting policy from scratch — flagged as a future nice-to-have, not urgent (catalog is currently 100% in-house authored).
- Restoring `skill-maintainer` from archive — needs its own scoped decision, not bundled here.

## Phases

### Phase 1: Git sync recovery
**Objective:** Stop risking silent data loss from unpushed commits + diagnose why SessionEnd auto-push is failing.

**Steps:**
1. Investigate `.last-push.log` error first — `"No user exists for uid 501" / "fatal: Could not read from remote repository"` is an auth/identity error, not a network blip. Check what runs the SessionEnd push hook and under what uid/SSH-agent context (likely a launchd/cron job losing keychain/SSH-agent access outside an interactive shell).
2. Once root cause is understood (not just papered over): `git -C ~/.claude-env push`
3. `git -C ~/.agents/skills push`

**Files Touched:** `~/.claude-env/.last-push.log` (read), whatever hook/script performs the SessionEnd push (locate via `grep -r "sync push" ~/.claude/hooks/`), git remotes for both repos
**Verify:** for both repos, `git status --porcelain` returns empty AND `git rev-list --left-right --count @{upstream}...HEAD` returns `0 0`; a fresh SessionEnd triggers a push that succeeds (check log for absence of the uid-501 error)
**Done When:** both repos synced AND the auth root cause is fixed, not just this one push retried
**Time:** 20-30 min (root-cause diagnosis is the real work; the pushes themselves are seconds)

**Replanning triggers:**
- If the uid-501 error is a sandboxed-session artifact (e.g., this Claude Code session's own bash sandbox has a different uid mapping than the operator's normal shell) rather than a real launchd/cron problem, this becomes a one-off retry, not a hook fix — confirm which before spending time on "fixing" a hook that isn't actually broken.

---

### Phase 2: Resolve settings model drift (NEEDS OPERATOR DECISION)
**Objective:** Live `settings.json` (`model: sonnet`, set this session via `/model sonnet`) differs from both `shared.json` (`model: fable`) and the machine-specific override (`model: opus`) — next `sync pull` will silently clobber the just-set sonnet default.

**Steps:**
1. Operator confirms intended canonical default: sonnet (matches this session's explicit choice + this repo's own "Sonnet = default execution tier" policy), fable, or opus.
2. Port the confirmed value into `~/.claude-env/settings/shared.json` (all machines) or `~/.claude-env/settings/machines/$(hostname -s).json` (this machine only) — per vitals hint, whichever scope is intended.
3. Do NOT just let the drift stand — `sync pull` will silently override the live value at some point, undoing today's explicit `/model` choice with no warning.

**Files Touched:** `~/.claude-env/settings/shared.json` or `~/.claude-env/settings/machines/MacBook-Pro-de-Lucas-10.json`
**Verify:** if shared scope chosen, live `~/.claude/settings.json` `model` matches `~/.claude-env/settings/shared.json`; if machine scope chosen, it matches `~/.claude-env/settings/machines/$(hostname -s).json` instead — do not require all three files to agree, a machine override is meant to diverge from shared
**Done When:** live value agrees with whichever source was selected as canonical
**Time:** 5 min once the decision is made

**Blocked on:** operator decision — this is a T2-shaped config change (affects every session's default model tier, i.e. cost profile), not a mechanical fix.

---

### Phase 3: Diagnose dead RAG nightly-rebuild job
**Objective:** `com.lucas.rag-nightly-rebuild` last completed 130h ago (expected <36h) — every RAG-backed research pass this session (including the ones that just ran) is working off a stale index without anyone knowing how stale.

**Steps:**
1. Check `launchctl list com.lucas.rag-nightly-rebuild` exit-status column (was `-` in this session's check — job may not be scheduled/loaded at all, not just failing).
2. `launchctl print gui/$(id -u)/com.lucas.rag-nightly-rebuild` for last-exit-status and next scheduled run.
3. Find and read its actual log file (search wasn't conclusive this session — locate the plist's `StandardOutPath`/`StandardErrorPath`).
4. Fix whatever's found: reload the job (`launchctl unload`/`load`), fix a broken script path, or fix a silent script-level failure.

**Files Touched:** `~/Library/LaunchAgents/com.lucas.rag-nightly-rebuild.plist`, its log path (TBD from plist)
**Verify:** `launchctl list com.lucas.rag-nightly-rebuild` shows a recent successful run after next scheduled fire, or manually trigger + confirm completion
**Done When:** job completes successfully and heartbeat freshness returns under 36h
**Time:** 15-20 min

---

### Phase 4: Canonical skills catalog hygiene (`~/.agents/skills`)
**Objective:** 87 broken symlinks + 127 names existing both live and archived — this is the actual dirty catalog (distinct from this repo's clean public mirror).

**Steps:**
1. `find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \; -delete` (vitals-provided command — deletes only symlinks whose target no longer exists, not real content)
2. Move `.archive/` out of the skills root so live-vs-archived name collisions stop being possible structurally (e.g., `~/.agents/skills-archive/` as a sibling, not `~/.agents/skills/.archive/`).

**Files Touched:** `~/.agents/skills/` (87 broken symlinks removed), `~/.agents/skills/.archive/` → relocated
**Verify:** `find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \; -print | wc -l` returns 0; `comm -12 <(ls ~/.agents/skills | sort) <(ls ~/.agents/skills-archive 2>/dev/null | sort)` returns empty
**Done When:** both checks pass
**Time:** 10 min

**Replanning triggers:**
- If any of the 87 broken symlinks turn out to be intentional stubs (unlikely, but check `plugin-firecrawl-firecrawl-download` / `vercel-agent` / `routing-middleware` samples before bulk-delete) — spot-check 3-5 before running the delete on all 87.

---

### Phase 5: THREAT_MODEL.md revision (docs-only, no code)
**Objective:** Close the three gaps the security-research pass found against current 2026 threat classes. Research agent's own assessment: protection posture (defaultDeny, fingerprinting) is already ahead of comparable tools — this is a documentation-completeness gap, not an architecture weakness.

**Steps:**
1. Split ASI01 (Agent Goal Hijack) into Direct (current `transcript-scanner.sh` coverage) vs Indirect (RAG/retrieval-time injection — 85%+ of real 2026 attacks per OWASP Q1 2026, and static regex provably can't catch feedback-optimized payloads per the IterInject paper). Note the gap: no retrieval-time filtering exists yet for RAG-ingested content.
2. Expand ASI04 (Supply Chain) to name **configuration injection** as a distinct class, citing CVE-2025-59536 (hooks injection via `.claude/settings.json`, CVSS 8.7) — current `mcp-policy.json` gates tool *invocation*, not hook *definitions* or settings-file integrity.
3. Add MCP credential-handling guidance: key scoping/rotation per session for approved servers with API tokens (context7, firecrawl), and documented fallback behavior if an approved server is compromised.

**Files Touched:** `docs/THREAT_MODEL.md` (this repo)
**Verify:** `docs/THREAT_MODEL.md` contains both the `ASI01 Agent Goal Hijack — Indirect` OWASP row and the `## 8. MCP Credential Handling & Server Compromise` heading, verbatim — a keyword grep can pass against pre-existing text and doesn't prove the specific entries exist
**Done When:** all three gaps have a named section with the cited evidence
**Time:** 2-3h (research agent's own estimate)

---

### Phase 6: Fix stale catalog counts in this repo's own CLAUDE.md
**Objective:** CLAUDE.md claims "51 active skill folders... 52 archived"; stale against both metrics `check-catalog.sh` actually reports: the `index.html` `SKILLS` array (site-listed count) and the raw `claude/skills/` folder count (`fd -t f '^SKILL\.md$' claude/skills`) — these are two distinct numbers, not one canonical count, and CLAUDE.md/AGENTS.md must say which one it's citing.

**Steps:**
1. Re-run `scripts/check-catalog.sh` to get the authoritative current SKILLS-array count.
2. Separately count `claude/skills/` folders with `fd -t f '^SKILL\.md$' claude/skills | wc -l`.
3. Update AGENTS.md's "Skill count" line (CLAUDE.md is generated from it, not edited directly) to state both numbers explicitly and which is which.

**Files Touched:** `AGENTS.md` (canonical), `CLAUDE.md` (generated via `scripts/sync-agents-claude.sh`, this repo)
**Verify:** `bash scripts/check-catalog.sh` SKILLS-array count and `fd -t f '^SKILL\.md$' claude/skills | wc -l` folder count both match what AGENTS.md/CLAUDE.md state
**Done When:** counts agree and the two metrics are distinguished, not conflated
**Time:** 10 min

---

### Phase 7: ADR-0005 status note (no code)
**Objective:** Research confirms the 2026-05-21 defer still holds — the "absent past-tense pull" condition remains true — but three of four original blocking gates weakened since (OpenHands SDK no longer needs Agno; Agno now has a free tier; Langfuse v3 shipped agent-graph tracing). Record this so the defer isn't re-litigated from scratch next time.

**Steps:**
1. Write/update a memory note capturing the revised triggers from the research pass (quoted in Phase Notes below) and the new revisit deadline (2027-03-31, replacing the prior Q3-2026 time gate).
2. No tooling adoption, no code change — this is a decision-record update only.

**Files Touched:** `/Volumes/External HD/Desenvolvimento/knowledge-brain/memory/` (new or updated note; not in this git repo)
**Verify:** note exists and links back to `adr_0005_harness_engineering_deferred.md`
**Done When:** note written
**Time:** 10 min

---

### Phase 8: Cost re-measure — grounded in real `agentsview` CLI data (2026-08-01)
**Objective:** Close the overdue 2026-07-16 re-measure (token_optimization_round2) with verified numbers, correcting the earlier estimate.

**Findings (VERIFIED via `agentsview` CLI, not stats-json alone):**
1. **Opus is still ~59% of Claude-attributed token volume** (`opus-4-8` 12.8M + `opus-5` 1.6M of 24.5M total Claude tokens, 28d window) — same or worse than the 56.6% flagged 2026-07-09. ADR-0050's mode-hook/autocompact fixes did not change model-tier routing itself.
2. **The apparent ~50% total-spend drop is partly a measurement artifact, not a real reduction.** `agentsview session usage <id>` on a `kimi-code/k3` session returns `Cost: n/a (unpriced: kimi-code/k3)` — confirmed no rate card exists in `~/.agentsview/config.toml` for `kimi-code/k3` or `k2p6`. The daily rollup (`usage daily`) silently displays unpriced models as `$0.00`, which reads as "free" but means "unknown." Real spend on those providers (if kimi-code is a paid API, not local) is untracked.
3. **Open discrepancy, not yet resolved:** `stats --since 28d` JSON reports `grade_distribution.F: 3`, but pulling `health --limit 300 --format json` and filtering `health_grade=='F'` returns zero across the same period. These appear to be two different grading computations scoped differently — not chased further this session (stopped per rabbit-hole discipline after 2 failed reproduction attempts).

**Steps:**
1. Add a rate card for `kimi-code/k3`/`k2p6` to `~/.agentsview/config.toml` if pricing is knowable (check the provider's actual billing — flat subscription vs. per-token), OR explicitly confirm they're free/local and the `n/a` label should read that way instead of `$0.00`.
2. Re-run the Haiku/Sonnet/Opus routing audit from `spec-token-optimization-work-setup.md` Decision 1 against **this** repo's own sessions, not just the work-machine spec — the 59% Opus share suggests the policy isn't being followed here either.
3. File a short follow-up note on the grade-distribution discrepancy (Phase 8 finding #3) for whoever next touches `agentsview` stats — don't silently trust either number until reconciled.

**Files Touched:** `~/.agentsview/config.toml` (if pricing added), this repo's own model-tier practice (no specific file — a practice change)
**Verify:** re-run `agentsview session usage <kimi-session-id>` — no longer shows `n/a`; `agentsview stats --since 28d --format json | jq '.model_mix.by_tokens'` shows Opus share trending down after routing changes land
**Done When:** pricing gap resolved (priced or explicitly confirmed free) AND a concrete Opus→Sonnet/Haiku routing change is identified and applied to this repo's own session practice
**Time:** 30-45 min (mostly the pricing research + routing audit)

**Replanning triggers:**
- If kimi-code/k2p6 turn out to be a flat-rate subscription with no marginal per-token cost, the "spend dropped" framing is actually correct after all — re-word the finding rather than treating it as urgent.

## Dependencies & Assumptions

- Phase 2 is blocked on an operator decision (which model value is canonical) — cannot proceed without that answer.
- Phase 1's root-cause diagnosis may reveal the uid-501 error is specific to this session's sandbox, in which case the "fix" is just a retry, not a hook change — don't over-build a fix for a problem that isn't real.
- Phases 3, 4, 6, 7 touch locations outside this git repo (`~/Library/LaunchAgents`, `~/.agents/skills`, `~/.claude/`, knowledge-brain memory) — none of that is version-controlled by `sharekit-profile`; only Phases 5 and 6 touch this repo directly.

## Current State (if partial)

- Diagnostics complete for all 7 vitals issues (git status, log tails, launchd list, symlink counts all captured this session — see conversation).
- All 3 deep-research passes complete and reconciled (ADR-0005, skill catalog, security posture).
- Zero phases executed yet — this plan is diagnosis-complete, execution-pending confirm.

## Notes

- Priority order follows this harness's own CLAUDE.md priorities: fix broken/blocking state first (Phases 1-3 — sync risk, RAG staleness), then safe security fixes (Phase 5), then hygiene/docs (Phases 4, 6, 7).
- Phase 1, 2, 4, and 5 involve push/delete/config-change/doc-edit actions — presenting as a plan for confirm before execution, per this session's own risk-tiering discipline (git push and irreversible deletes are not auto-executed without a nod).
- One flagged item during research: the security-research agent's raw report was auto-tagged by this harness's own injection scanner as matching instruction-shaped patterns — verified as a false positive (the report's *content* discusses settings.json injection risk, not an actual attempt to redirect the agent). No action needed beyond this note.
