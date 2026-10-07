# `~/.claude/hooks/` — inventory

Last updated: 2026-10-02 (after Wave B lean-out: 23 bindings over 23 scripts, 38 scripts on disk)

## Source of truth

Hook bindings live in `~/.claude-env/settings/shared.json` (deep-merged with `settings/machines/<host>.json`, applied to `~/.claude/settings.json` by `~/.claude-env/bin/sync pull`). Editing `~/.claude/settings.json` directly works for the current session but can be overwritten on the next pull, so update `shared.json` as well.

To list what is really wired, read `~/.claude/settings.json`, not this file. Anything in `hooks/*.sh` that is not bound there is unwired.

## Wired hooks (live)

| Event | Matcher | Script | Purpose |
|---|---|---|---|
| PreToolUse | Bash | `bash-prefilter.sh` | Skip trivial commands, otherwise chain to `rtk-rewrite.sh` (rtk-owned, sha256-locked) |
| PreToolUse | Read, Bash | `block-secret-reads.sh` | Block secret-bearing reads and secret-shaped literals in commands |
| PreToolUse | Edit, Write, MultiEdit | `protect-files.sh` | Block edits to sensitive files |
| PreToolUse | Edit, Write, MultiEdit | `memory-write-guard.sh` | Secret redaction on the memory write path |
| PreToolUse | Bash, Write, Edit, NotebookEdit | `t2-gate-detect.sh` | Make the T2 autonomy gate observable (advisory context) |
| PreToolUse | Bash | `check-pr-automation-halt.sh` | Halt automation on PRs with comments or other authors |
| PreToolUse | Agent, Task | `check-analysis-agent-type.sh` | Analysis agents must use write-incapable types |
| PostToolUse | Write, Edit, MultiEdit | `skill-quality-gate.sh` | Skill quality gate on edits (calls `gate.sh`) |
| PostToolUse | * (async) | `tool-logger.sh` | Trajectory log, skill invocation log, rtk-miss log (one process) |
| UserPromptSubmit | * | `mode-reminder.sh` | Caveman, ponytail, agent-econ anchor (ADR-0050) |
| UserPromptSubmit | * | `model-tier-router.sh` | Suggest a cheaper model for routine prompts |
| UserPromptSubmit | * | `session-length-guard.sh` | Warn on long sessions |
| UserPromptSubmit | * | `composite-router.sh` | Match prompts to composite skills |
| UserPromptSubmit | * | `team-mode-guard.sh` | Team mode and guest-repo detection |
| SessionStart | * | `harness-vitals.sh` | Surface silent harness failures and MEMORY.md over 180 lines |
| SessionStart | * | `hook-selftest.sh` | Run the blocking hooks' regression suite |
| SessionStart | compact | `reinject-compact.sh` | Re-inject session facts, auto-handoff, precompact snapshot pointer and team-mode tag after a compact |
| PreCompact | * | `pre-compact-summary.sh`, `memory-extract.sh` | Handoff summary and memory snapshot before compaction |
| Stop | * | `knowledge-loop-nudge.sh` | Nudge `/knowledge-loop` at a considerable stopping point |
| SessionEnd | * | `session-cost-telemetry.sh`, `memory-extract.sh`, `tool-failures-flush.sh` | Cost telemetry, memory extractor (expensive sessions only), failure flush |
| SubagentStart, SubagentStop | * | `subagent-checkpoint.sh` | Per-subagent checkpoint record |

Also wired outside `hooks`: `statusline.sh` (statusLine). Memory sleep, roadmap aggregate and the rag report run from launchd, not hooks.

## Bash hook chain

```
Bash(<cmd>)
  └─► bash-prefilter.sh
       ├─ trivial cmd: exit 0
       └─ otherwise exec rtk-rewrite.sh (EC 0 allow rewritten, 1 passthrough, 2 deny, 3 rewrite+ask;
          EC 3 is silently dropped in bypassPermissions, see rtk-ai/rtk#1233)
After the call: tool-logger.sh logs outputs of 5KB or more that were not rtk-wrapped.
```

## Unwired but kept

Not bound in `settings.json`; each has a live caller or an open decision. Delete only after checking.

| Script | Why kept |
|---|---|
| `rtk-rewrite.sh` | Called by `bash-prefilter.sh`, `rtk-miss-detector.sh`, `harness-vitals.sh` |
| `gate.sh`, `history.sh` | Called by `skill-quality-gate.sh`, the scorecard and the roadmap-aggregate launchd job |
| `check-harness-drift.sh` | Used by the `sync-sharekit-profile` skill |
| `session-budget-guard.sh`, `rate-limit-watch.sh` | Pair; calibrated by `scripts/session-budget-guard.calib.py` |
| `skill-index.sh` | Referenced by `scripts/skill-prune.sh` |
| `grep-before-rag-nudge.sh` | Has 3 selftest checks; decide re-wire or drop with its tests |
| `auto-context-pack.sh`, `complexity-classifier.sh` | Conflicting docs (a 2026-05-13 rescue decision, ``); owner decision pending |
| `eval-run.sh`, `eval-tasks.sh`, `eval-baseline.sh`, `check-idempotency.sh` | Eval cluster, possibly in use by another session |

Deleted in Wave B (recoverable from `~/.claude-env` git history): `tool-shortlist`, `cycle` and its callees (`deploy-watch`, `diagnose`, `distill`, `propose`, `memory-consolidate`, `dispatch`), `session-token-stop`, `message-counter`, `turn-counter`, `snapshot-compact`, `trajectory-log`, `skill-outcome-logger` and `rtk-miss-detector` (merged into tool-logger), `main-release-drift-nudge` and `memory-index-size-alert` (folded into harness-vitals), `sessionend-rag-sync`, `bash-repeat-cache`, `check-stuck-loop`, `compaction-guard`, `harness-drift-nudge`, `hotfix-followup-tracker`, `multiedit-nudge`, `post-compact-reset`, `rag-usage-tracker`, `release-branch-detector`, `repeat-read-guard`, `session-start-load`, and the inert `updatedToolOutput` hooks.

## Conventions

- Start with `#!/usr/bin/env bash` and `set -euo pipefail` (or `set -uo pipefail` when the hook tolerates command failures).
- Stay bash 3.2 safe: no `declare -A` (the selftest gates this).
- Bind with `${CLAUDE_DIR}/hooks/<name>.sh` in `shared.json`; `apply_settings` expands the placeholder.
- Exit 0 unless the hook intends to block. PreToolUse: `0` allow, `2` block (stderr shown to the model), other non-zero is a non-blocking error.
- Read stdin for the tool payload (a JSON envelope).
- Hook edits take effect live in-session, no restart needed.

## Adding a hook

1. Create `hooks/<name>.sh` following the conventions.
2. Bind it in `settings/shared.json` under `hooks.<event>`.
3. Commit in `~/.claude-env`, then `~/.claude-env/bin/sync pull`.
4. Run `~/.claude/test/harness-selftest.sh` and trigger the event once.

## Known issues

- `apply_settings` deep-merge replaces rather than preserves: a hook only in local `settings.json` is wiped on the next pull. Fix it in `shared.json`.
- rtk integrity-checks `rtk-rewrite.sh` (`.rtk-hook.sha256`). Do not edit it; wrap behavior in `bash-prefilter.sh`.
