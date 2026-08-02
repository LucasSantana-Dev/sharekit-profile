# Plan: Token usage optimization — work-setup Claude Code install

**Date:** 2026-08-01
**Status:** draft
**Spec:** `.claude/plans/spec-token-optimization-work-setup.md`

## Goal

Cut token/cost spend on the operator's vanilla work-machine Claude Code install via model routing, context hygiene, and MCP-server pruning — while explicitly rejecting rtk and unverified compression plugins based on independently-tested evidence (JetBrains controlled A/B, 2026-07-20).

## Scope

### In-Scope
- Work-machine `settings.json`: subagent model routing, `autoCompactEnabled`, `effortLevel`.
- Work-machine `CLAUDE.md`: trim to <200 lines.
- Work-machine MCP server audit (disable unused).
- Port caveman+ponytail force-injection hook (the one lever with a statistically-significant verified win: ponytail −10.3% cost, p=0.004).
- Correct this repo/harness's own decision record (ADR-0008, ADR-0049) — they measured rtk's raw-byte compression, not net session cost; JetBrains' controlled test shows that metric doesn't predict actual savings.

### Out-of-Scope
- Adopting rtk, magic-compact, claude-rolling-context, or token-optimizer-mcp (all rejected — see spec Decision 2).
- Rebuilding the full sharekit-profile skill/agent catalog on the work machine.
- Multi-provider/OpenRouter routing (stays first-party Claude endpoints per existing provider rule).
- Exact current pricing modeling (pricing table is 30+ days stale — flagged, not resolved here).

## Phases

### Phase 1: Baseline measurement (work machine — operator action)
**Objective:** Establish pre-change token/cost numbers so later phases are measurable, not asserted.

**Steps:**
1. Run `/usage` across 3-5 representative work sessions on the work machine.
2. Record current `settings.json` and `CLAUDE.md` line count as-is (no edits yet).

**Files Touched:** work-machine `~/.claude/settings.json` (read-only), `~/.claude/CLAUDE.md` (read-only)
**Verify:** `/usage` output captured and saved (screenshot or paste into a scratch note)
**Done When:** baseline $/session and CLAUDE.md line count recorded
**Time:** 15 min

**Replanning triggers:**
- If `/usage` isn't available on that Claude Code version → fall back to OpenTelemetry export (spec Decision 6 escalation path).

---

### Phase 2: Model routing (work machine — operator action)
**Objective:** Route mechanical/subagent work to Haiku, keep Sonnet as session default, reserve Opus/Fable for genuine deep reasoning.

**Steps:**
1. Set `CLAUDE_CODE_SUBAGENT_MODEL=haiku` (env var or `settings.json`).
2. Confirm no default override forces Opus for the main session.

**Files Touched:** work-machine `~/.claude/settings.json` (or shell profile for the env var)
**Verify:** launch a session that triggers a subagent, confirm it dispatches on Haiku (via `/usage` per-model breakdown)
**Done When:** subagent dispatch confirmed on Haiku in `/usage` output
**Time:** 10 min

---

### Phase 3: Context hygiene (work machine — operator action)
**Objective:** Reduce fixed per-turn overhead (CLAUDE.md size) and tune per-call reasoning cost (`effortLevel`).

**Steps:**
1. Trim `CLAUDE.md` to under 200 lines; move anything specialized into skills that load on-demand.
2. Confirm `autoCompactEnabled` is `true` (Claude Code default — verify it wasn't disabled).
3. Set `effortLevel: "medium"` (or `"low"` for routine/non-architecture work).
4. Optional (D9): enable beta context-editing (`clear_tool_uses_20250919`) if the work machine's SDK/CLI version exposes it — native, no proxy risk, but do not count on Anthropic's self-reported 29-39% savings figure; it has zero independent verification, unlike the rtk/caveman/ponytail numbers this spec already corrected.

**Files Touched:** work-machine `~/.claude/CLAUDE.md`, `~/.claude/settings.json`
**Verify:** `wc -l ~/.claude/CLAUDE.md` reports <200; `grep effortLevel ~/.claude/settings.json`
**Done When:** both checks pass
**Time:** 30-45 min (mostly the CLAUDE.md trim)

---

### Phase 4: MCP server audit (work machine — operator action)
**Objective:** Remove tool-listing overhead from unused MCP servers — the highest-leverage lever for a vanilla install per spec Decision 5.

**Steps:**
1. List configured MCP servers on the work machine.
2. For each, confirm actual use in the last 2 weeks (or just judgment call for a fresh install); disable the rest.
3. Concrete short-list per D10: keep Context7 (docs freshness), GitHub MCP (if PR/CI-heavy), Playwright MCP (if e2e testing) — cut anything filesystem-type (native Read/Write/Bash already cover it at zero token cost; this repo's own `.harness/mcp-policy.json` audit, 2026-07-30, already did this and confirms the finding).
4. If installing any non-Anthropic-first-party skill/plugin alongside this pass: vet first per D11 (Snyk Feb 2026 audit found 36.82% of scanned community skills had ≥1 flaw, 13.4% critical, confirmed malware distribution via ClawHub).

**Files Touched:** work-machine MCP config (`~/.claude.json` or `.mcp.json` depending on scope)
**Verify:** re-run `/usage` or a fresh session, confirm fewer MCP tool names loaded
**Done When:** MCP server list documented + unused ones disabled
**Time:** 15 min

---

### Phase 5: Port terse-prompting force-injection (work machine — operator action)
**Objective:** Apply the one lever in this research pass with a statistically significant, independently-verified positive result — ponytail-style discipline, force-injected (not passive, since JetBrains found passive installs self-activate zero times).

**Steps:**
1. Port a UserPromptSubmit hook equivalent to this harness's `mode-reminder.sh` pattern that force-injects terse/scoped-build discipline every turn (does not require the full sharekit-profile skill catalog — just the hook + a short reminder string).
2. Register it in work-machine `settings.json` hooks config.

**Files Touched:** work-machine `~/.claude/hooks/mode-reminder.sh` (new, minimal version), `~/.claude/settings.json`
**Verify:** send a prompt, confirm the reminder banner appears in the system-reminder context
**Done When:** hook fires on next prompt submit
**Time:** 20 min

---

### Phase 6: Re-measure (work machine — operator action)
**Objective:** Close the loop — confirm the changes actually reduced cost, not just plausibly should.

**Steps:**
1. Run `/usage` after ~1 week of Phases 2-5 live.
2. Compare against Phase 1 baseline.

**Files Touched:** none (measurement only)
**Verify:** `/usage` delta vs. Phase 1 baseline
**Done When:** delta documented; if savings <10%, revisit which lever underperformed before adding anything new
**Time:** 10 min

**Replanning triggers:**
- If cost is flat or worse after 1 week → do not reach for rtk/plugins (rejected per spec Decision 2); instead re-check Phase 2-4 were actually applied (config drift is more likely than "need a new tool").

---

### Phase 7: Correct this harness's own decision record (this repo/session — executable now)
**Objective:** ADR-0008 and ADR-0049 in `~/.claude/adrs/` currently read as "rtk validated, 55-61% savings" — that conclusion rests on a metric (raw-byte compression) JetBrains' controlled A/B shows doesn't predict net session cost. The record should not stand uncorrected.

**Steps:**
1. Add a dated addendum to `~/.claude/adrs/0008-headroom-vs-rtk-token-compression.md` and `~/.claude/adrs/0049-rtk-rewrite-hook-wired-truncation-flags-rejected.md` citing the JetBrains finding and reconciling the metric mismatch (see spec-research report, 2026-08-01).
2. Update the `rtk_hook_wired_2026-07-09` memory note's description to reflect the correction.
3. Note in `token_baseline_2026-05-13` memory that the "50-75% caveman savings" internal estimate is corrected downward to JetBrains' measured 8.5%.
4. Run `docs-sync` if `~/.claude-env` mirrors these files (per this harness's dual-location convention).

**Files Touched:** `~/.claude/adrs/0008-headroom-vs-rtk-token-compression.md`, `~/.claude/adrs/0049-rtk-rewrite-hook-wired-truncation-flags-rejected.md`, `~/.claude/rag-index` memory files noted above (outside this git repo — separate harness-config location, not `sharekit-profile`)
**Verify:** `grep -l "JetBrains" ~/.claude/adrs/0008*.md ~/.claude/adrs/0049*.md` returns both files
**Done When:** both ADRs carry the addendum, memory notes updated, docs-sync run if applicable
**Time:** 20 min

**Replanning triggers:**
- If the operator decides to actually revert the rtk PreToolUse hook (not just correct the record) — that's a separate, larger decision (rtk is currently live in `bypassPermissions` mode per ADR-0049) and needs its own confirm-before-acting pass, not bundled into this correction.

## Dependencies & Assumptions

- Phases 1-6 happen **on the work machine**, which this session has no direct access to — they're operator-executed instructions, not something this agent runs now.
- Phase 7 is the only phase executable from this session, and it touches `~/.claude/adrs/` — a location outside the `sharekit-profile` git repo (this repo mirrors a subset of that harness for public publishing; the correction belongs in the source location first).
- Assumes Claude Code CLI version on the work machine is recent enough to support `/usage`, `effortLevel`, and `autoCompactEnabled` (all confirmed VERIFIED against official docs as of this spec, but not confirmed against the specific work-machine version).

## Current State (if partial)

- Spec written and corrected: `.claude/plans/spec-token-optimization-work-setup.md` (Decisions 1-8, all cited/graded).
- Deep-research on rtk alternatives complete — verdict: reject rtk and all three alternatives; keep native compaction + terse-prompting.
- No work-machine changes applied yet (Phases 1-6 not started).
- Phase 7 (ADR correction) not started.

## Notes

- Full research report (JetBrains rtk/caveman/ponytail benchmarks, contradiction reconciliation against ADR-0008/0049) is in this session's transcript, 2026-08-01. Not yet persisted to a memory note — recommend `/sync-memories` after Phase 7 lands, so the correction survives past this session.
- Pricing table (spec Decision 8) is stale >30 days; Sonnet 5 intro pricing expires 2026-08-31 — re-pull before Phase 6's cost-delta math if precise $ figures matter.
