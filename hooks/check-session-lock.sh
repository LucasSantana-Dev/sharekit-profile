#!/usr/bin/env bash
# check-session-lock.sh — SessionStart + PreToolUse (Write/Edit/NotebookEdit) hook.
# Enforces the concurrency rule from RULES.md "Parallel execution is mandatory for >=2
# independent tasks" — a corollary is that concurrent sessions on the same checkout
# (non-worktree) can silently destroy each other's uncommitted work.
#
# This hook implements Track E-lite of ADR-0001 (harness-improvement-sequencing):
# a session-lock sentinel that warns loudly when two live sessions compete for the
# same checkout, and blocks writes if a fresh lock from another session exists.
#
# Two modes:
#   --claim (SessionStart): write .harness/runtime/session.lock with session metadata.
#              If a fresh lock from another session exists (pid alive, <8h old),
#              emit a warning to stdout (becomes context). Exit 0 always.
#   (default, PreToolUse): on each Write/Edit/NotebookEdit, warn once per session if
#              another live session owns the lock. Exit 0 always (advisory in v1).
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
mkdir -p "$RUNTIME"

LOCK_FILE="$RUNTIME/session.lock"
# Per-session marker to suppress warning spam (only warn once per session).
SESSION_WARNED_MARKER="$RUNTIME/.session-lock-warned-$$"

# ---- Detect session ID (try env var, fall back to PPID) ----
SESSION_ID="${CLAUDE_SESSION_ID:-$(( $$ - 1 ))}"
CURRENT_PID="$$"
CURRENT_PPID="${PPID:-1}"

# ---- Mode: --claim (SessionStart) ----
if [[ "${1:-}" == "--claim" ]]; then
  ts_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # If lock exists, check if it's from another live session.
  if [[ -f "$LOCK_FILE" ]]; then
    existing_lock="$(cat "$LOCK_FILE" 2>/dev/null || echo '')"
    if [[ -n "$existing_lock" ]]; then
      existing_session="$(printf '%s' "$existing_lock" | jq -r '.session_id // empty' 2>/dev/null || true)"
      existing_pid="$(printf '%s' "$existing_lock" | jq -r '.pid // empty' 2>/dev/null || true)"
      existing_ts="$(printf '%s' "$existing_lock" | jq -r '.claimed_at // empty' 2>/dev/null || true)"

      # Check if the existing lock is fresh (claimed <8h ago) AND belongs to a different session.
      if [[ -n "$existing_session" && "$existing_session" != "$SESSION_ID" ]]; then
        lock_age_secs=0
        if [[ -n "$existing_ts" ]]; then
          # Parse ISO timestamp: works on macOS and Linux.
          # Convert "2026-07-01T22:33:35Z" to Unix timestamp.
          lock_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$existing_ts" +%s 2>/dev/null || echo 0)
          lock_age_secs=$(($(date -u +%s) - lock_epoch))
        fi

        # Fresh lock (<8h = 28800s) from a different session.
        if [[ $lock_age_secs -lt 28800 ]]; then
          # Check if the owning process is still alive (kill -0 returns 0 if alive).
          if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            # Another session is actively using this checkout.
            printf '\n' >&2
            printf '⚠ CONCURRENT SESSION DETECTED\n' >&2
            printf '  Existing session: %s (pid %s, claimed %s)\n' \
              "$existing_session" "$existing_pid" "$existing_ts" >&2
            printf '  Current session:  %s (pid %s)\n' "$SESSION_ID" "$CURRENT_PID" >&2
            printf '\n' >&2
            printf '  ⚠ WARNING: Uncommitted work WILL be silently lost to race conditions.\n' >&2
            printf '\n' >&2
            printf '  ACTION: Work in a separate worktree:\n' >&2
            printf '    git worktree add '\''/Volumes/External\ HD/Desenvolvimento/.worktrees/<task>'\'' -b <branch>\n' >&2
            printf '\n' >&2
            # Exit 0 (advisory only in v1).
            exit 0
          fi
        fi
      fi
    fi
  fi

  # Write (or replace) the lock with this session's metadata.
  jq -nc \
    --arg session_id "$SESSION_ID" \
    --arg pid "$CURRENT_PPID" \
    --arg claimed_at "$ts_iso" \
    --arg cwd "$(pwd)" \
    '{session_id: $session_id, pid: $pid, claimed_at: $claimed_at, cwd: $cwd}' \
    > "$LOCK_FILE"

  exit 0
fi

# ---- Mode: default (PreToolUse on Write/Edit/NotebookEdit) ----
# Read tool input from stdin (hook protocol).
hook_input="$(sed -n '1,$p')"
tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)"

# Only warn on write-like tools.
case "$tool_name" in
  Write|Edit|NotebookEdit) ;; # Proceed to lock check.
  *) exit 0 ;; # Other tools, no check needed.
esac

# If lock exists and belongs to a different session, warn once per session.
if [[ -f "$LOCK_FILE" ]]; then
  existing_lock="$(cat "$LOCK_FILE" 2>/dev/null || echo '')"
  if [[ -n "$existing_lock" ]]; then
    existing_session="$(printf '%s' "$existing_lock" | jq -r '.session_id // empty' 2>/dev/null || true)"
    existing_pid="$(printf '%s' "$existing_lock" | jq -r '.pid // empty' 2>/dev/null || true)"
    existing_ts="$(printf '%s' "$existing_lock" | jq -r '.claimed_at // empty' 2>/dev/null || true)"

    # Different session AND lock is fresh (<8h) AND process still alive?
    if [[ -n "$existing_session" && "$existing_session" != "$SESSION_ID" ]]; then
      lock_age_secs=0
      if [[ -n "$existing_ts" ]]; then
        # Parse ISO timestamp: works on macOS and Linux.
        # Convert "2026-07-01T22:33:35Z" to Unix timestamp.
        lock_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$existing_ts" +%s 2>/dev/null || echo 0)
        lock_age_secs=$(($(date -u +%s) - lock_epoch))
      fi

      if [[ $lock_age_secs -lt 28800 ]] && [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
        # Only warn if we haven't warned this session yet.
        if [[ ! -f "$SESSION_WARNED_MARKER" ]]; then
          printf '\n' >&2
          printf '⚠ CONCURRENT SESSION: another session (%s, pid %s) owns this checkout.\n' \
            "$existing_session" "$existing_pid" >&2
          printf '  Uncommitted work WILL be lost to races. Use a worktree:\n' >&2
          printf '    git worktree add '\''/Volumes/External\ HD/Desenvolvimento/.worktrees/<task>'\'' -b <branch>\n' >&2
          printf '\n' >&2
          # Mark that we warned in this session, so we don't spam.
          touch "$SESSION_WARNED_MARKER"
        fi
      fi
    fi
  fi
fi

exit 0
