# `~/.claude/hooks/` — inventory

Last updated: 2026-05-03

## Source of truth

Hook bindings live in `~/.claude-env/settings/shared.json` (deep-merged with `settings/machines/<host>.json`, applied to `~/.claude/settings.json` on every `SessionStart` via `~/.claude-env/bin/sync pull`). Editing `~/.claude/settings.json` directly works for the current session but **gets overwritten on next session start** — always update `shared.json` and push.

## Bash hook chain

`PreToolUse` runs in array order. The Bash matcher fires first.

```
Claude calls Bash(<cmd>)
  └─► bash-prefilter.sh        (set -euo pipefail)
       ├─ trivial cmd? → exit 0   (skip rtk spawn, ~30ms saved)
       └─ otherwise: exec rtk-rewrite.sh (rtk-owned, hash-locked)
            ├─ rtk: rewrites cmd → "rtk <subcommand> ..."
            ├─ EC=0: auto-allow with rewritten command
            ├─ EC=1: passthrough (no rtk equivalent)
            ├─ EC=2: deny (Claude Code's native deny handles)
            └─ EC=3: rewrite + ask (CAUTION: silently dropped in bypassPermissions mode — see rtk-ai/rtk#1233)
```

After the Bash call returns:

```
Bash output captured
  └─► PostToolUse Bash → rtk-miss-detector.sh
       └─ if output ≥5KB AND cmd doesn't start with `rtk` → log to ~/.claude/rtk-misses.log

  if tool failed:
  └─► PostToolUseFailure → ~/.claude/tool-failures.log (jsonl)
```

## File inventory

| File | Set on | Purpose | Trigger |
|---|---|---|---|
| `bash-prefilter.sh` | `set -euo pipefail` | Fast-path bypass for trivial cmds, then chain to rtk | PreToolUse Bash |
| `rtk-rewrite.sh` | rtk-owned | Token-saving rewrites via rtk binary | (chained from prefilter) |
| `rtk-miss-detector.sh` | `set -euo pipefail` | Log >5KB Bash outputs that didn't use rtk | PostToolUse Bash |
| `statusline.sh` | `set -uo pipefail` | Render `[project] msg:N ↓<rtk_saved>tok` | statusLine |
| `protect-files.sh` | (rtk pattern) | Block edits to sensitive files | PreToolUse Edit\|Write\|MultiEdit |
| `pre-compact.sh` | — | Pre-compaction snapshot | PreCompact |
| `post-compact.sh` | — | Resume context after compact | PostCompact |
| `auto-context-pack.sh` | — | Inject project context pack | UserPromptSubmit |
| `message-counter.sh` | — | Track message count for auto-compact triggers | UserPromptSubmit |
| `validate-command.sh` | — | (currently unwired — review) | — |
| `validate-handoff.sh` | — | (currently unwired — review) | — |
| `test-auto-context-pack.sh` | — | Test fixture for auto-context-pack | — |

## Archived

Moved to `archive/` 2026-05-03:
- `automation-orchestrator.sh` (7.5KB) — never wired in any settings.json since 2026-02-22
- `context-optimizer.sh` (5.5KB) — same

## Conventions

- All hook scripts must start with `#!/usr/bin/env bash` + `set -euo pipefail` (or `set -uo pipefail` if they intentionally tolerate command failures, like `statusline.sh`).
- Hooks called from `shared.json` use `${CLAUDE_DIR}/hooks/<name>.sh` — apply_settings expands the placeholder.
- Hooks must exit 0 unless they intend to block the tool. PreToolUse exit-code protocol: `0` = allow, `2` = block/deny (stderr shown to the model), other non-zero = non-blocking error. Blocking hooks here use `exit 2` (see `block-secret-reads.sh`, `protect-files.sh`).
- Hooks must read stdin if they need the tool payload — Claude Code pipes a JSON envelope.
- For PostToolUse failure-logging, the payload field for stderr varies by tool — fall through `tool_response.error // .stderr // .stdout // "unknown"`.

## Adding a new hook

1. Create `~/.claude/hooks/<name>.sh` with the conventions above.
2. Add binding to `~/.claude-env/settings/shared.json` under `hooks.<event>`.
3. `cd ~/.claude-env && git add settings/shared.json hooks/<name>.sh && git commit && git push`.
4. `~/.claude-env/bin/sync pull` to apply locally.
5. Smoke test by triggering the event.

## Known issues

- `apply_settings` deep-merge replaces, not deep-preserves. Any hook in local `settings.json` but not in `shared.json` gets wiped at SessionStart pull. **Fix is in shared.json, not local.**
- rtk integrity-checks `rtk-rewrite.sh` (sha256 in `.rtk-hook.sha256`). Modifying it directly fails — wrap behavior in `bash-prefilter.sh` instead.
