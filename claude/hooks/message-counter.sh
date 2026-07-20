#!/usr/bin/env bash
set -euo pipefail
# message-counter.sh — UserPromptSubmit hook
# Tracks message count per session. Auto-generates per-project handoff at limit threshold.
# Cost: 0 tokens on normal messages. Only prints at thresholds 15, 20, 25, 30+.

COUNTER_FILE="$HOME/.claude/.session-msg-count"
HANDOFF_BASE="$HOME/.claude/handoffs"

count=$(cat "$COUNTER_FILE" 2>/dev/null | tr -dc '0-9'); count=${count:-0}
count=$(( count + 1 ))
tmp="${COUNTER_FILE}.$$"; echo "$count" > "$tmp" && mv -f "$tmp" "$COUNTER_FILE"

# Derive project identifier: prefer git remote slug, fallback to dirname
get_project_id() {
  local workdir="${CLAUDE_PROJECT_DIR:-$PWD}"
  local remote
  remote=$(cd "$workdir" 2>/dev/null && git remote get-url origin 2>/dev/null)
  if [ -n "$remote" ]; then
    echo "$remote" | sed 's|.*[:/]\([^/]*/[^/]*\)\.git$|\1|' | tr '/' '-' | tr '[:upper:]' '[:lower:]'
  else
    basename "$workdir"
  fi
}

# Extract remaining (uncompleted) phases from the active plan file
get_next_actions() {
  local workdir="$1"
  local plan_file
  plan_file=$(ls -t "$workdir"/.agents/plans/*.md "$workdir"/.claude/plans/*.md 2>/dev/null | head -1)
  if [ -z "$plan_file" ]; then
    echo "No active plan found in $workdir. Check project directory for tasks."
    return
  fi

  # Find next unchecked phase/step (not marked done)
  local next
  next=$(grep -n "^### Phase\|^## Phase\|^- \[ \]" "$plan_file" 2>/dev/null \
    | grep -v "[OK]\|\[x\]\|DONE\|complete\|shipped\|Complete" \
    | head -5)

  if [ -z "$next" ]; then
    echo "[WARN] All phases in active plan appear complete."
    echo "  Plan: $plan_file"
    echo "  Ask the user what to work on — do not self-assign."
  else
    echo "$next"
    echo "(from: $plan_file)"
  fi
}

# Check if current plan has all phases done (stale handoff risk)
plan_is_complete() {
  local workdir="$1"
  local plan_file
  plan_file=$(ls -t "$workdir"/.agents/plans/*.md "$workdir"/.claude/plans/*.md 2>/dev/null | head -1)
  [ -z "$plan_file" ] && return 1
  local remaining
  remaining=$(grep "^### Phase\|^## Phase\|^- \[ \]" "$plan_file" 2>/dev/null \
    | grep -v "[OK]\|\[x\]\|DONE\|complete\|shipped\|Complete" | wc -l | tr -d ' ')
  [ "$remaining" -eq 0 ]
}

auto_handoff() {
  local workdir="${CLAUDE_PROJECT_DIR:-$PWD}"
  local project
  project=$(get_project_id)
  local project_dir="$HANDOFF_BASE/$project"
  mkdir -p "$project_dir"

  local timestamp
  timestamp=$(date +%Y-%m-%d-%H-%M)
  local handoff_file="$project_dir/latest.md"
  local timestamped="$project_dir/$timestamp.md"

  # Capture git state
  local branch log status diffstat
  branch=$(cd "$workdir" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
  log=$(cd "$workdir" 2>/dev/null && git log --oneline -5 2>/dev/null)
  status=$(cd "$workdir" 2>/dev/null && git status --short 2>/dev/null | head -15)
  diffstat=$(cd "$workdir" 2>/dev/null && git diff --stat HEAD 2>/dev/null | tail -8)

  # Get plan header only (title + goal, not full body)
  local plan_header
  plan_header=$(ls -t "$workdir"/.agents/plans/*.md "$workdir"/.claude/plans/*.md 2>/dev/null \
    | head -1 | xargs head -15 2>/dev/null)

  # Get remaining work from plan
  local next_actions
  next_actions=$(get_next_actions "$workdir")

  # Warn if plan is complete
  local plan_complete_warning=""
  if plan_is_complete "$workdir"; then
    plan_complete_warning="
[WARN]  ALL PLAN PHASES APPEAR COMPLETE. Do not auto-assign new work.
    Ask the user what to do next instead of archiving and stopping."
  fi

  cat > "$handoff_file" << HANDOFF
# Handoff — $project — $timestamp
<!-- Auto-generated at message $count. -->
<!-- Resume: cd $workdir && codex  (fish wrapper auto-loads) -->

##  IMPLEMENT THIS — Do Not Just Verify State or Archive
<!--
  IMPORTANT: Clean git / no uncommitted changes is NORMAL here.
  This handoff describes NEW work to implement, not already-done work.
  "Nothing to commit" does NOT mean you are finished.
  Only archive this file AFTER making commits and shipping the work below.
-->
$plan_complete_warning

### Next Steps (from active plan):
$next_actions

### Done When:
- [ ] At least one new commit created
- [ ] Test suite passes
- [ ] PR created or changes deployed to production

---

## Project
$project
Working directory: $workdir

## Git State
Branch: $branch

Recent commits:
$log

Uncommitted changes:
$status

Diff stat:
$diffstat

## Active Plan (header)
$plan_header

## Agent Instructions
- cd to: $workdir
- Rules: ~/.codex/AGENTS.md (Codex) | ~/.claude/CLAUDE.md (Claude Code)
- Commit after each functional step, never push directly to main
- Full plan: check .claude/plans/ or .agents/plans/ in the project dir
- If all phases complete: ask user for next task, do NOT self-terminate
HANDOFF

  cp "$handoff_file" "$timestamped"
  cp "$handoff_file" "$HANDOFF_BASE/latest.md"

  echo "$handoff_file"
}

# Token-based threshold (not message-based). Parse last session JSONL entry for actual
# cache_read tokens and compare against model context window.
# Rationale: message count is a poor proxy — big turns vs small turns vary 10×.
get_session_tokens() {
  local session_file
  session_file=$(ls -t "$HOME/.claude/projects/"*/*.jsonl 2>/dev/null | head -1)
  [ -z "$session_file" ] && { echo 0; return; }
  # Last line's cache_read + input tokens is a proxy for current context size
  tail -1 "$session_file" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    u = d.get('message', {}).get('usage', {})
    print((u.get('cache_read_input_tokens') or 0) + (u.get('input_tokens') or 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0
}

# Model-aware context window (from CLAUDE_MODEL env var)
case "${CLAUDE_MODEL:-opus-1m}" in
  *haiku*|*sonnet-4-5*|*200k*) CTX_MAX=200000 ;;
  *sonnet-4-6*) CTX_MAX=200000 ;;  # Sonnet 4.6 = 200K std
  *) CTX_MAX=1000000 ;;            # Opus 4.7 1M, default
esac

TOKENS=$(get_session_tokens)
# Threshold bands (% of CTX_MAX): 45% warn, 70% urge, 85% handoff
PCT=$(( TOKENS * 100 / CTX_MAX ))

if [ "$TOKENS" -gt 0 ] && [ "$PCT" -ge 85 ]; then
  # Only fire every ~5 msgs past 85% to reduce noise
  if [ $(( count % 5 )) -eq 0 ]; then
    PROJECT=$(get_project_id)
    auto_handoff > /dev/null
    echo "[red] [AUTO-HANDOFF] Context ~${PCT}% (${TOKENS}/${CTX_MAX} tokens). Handoff refreshed for $PROJECT."
    echo "   Run 'codex' in ${CLAUDE_PROJECT_DIR:-$PWD} to resume, OR /compact."
  fi
elif [ "$TOKENS" -gt 0 ] && [ "$PCT" -ge 70 ]; then
  echo "[WARN] [context] ~${PCT}% — /compact recommended before heavy new work"
elif [ "$TOKENS" -gt 0 ] && [ "$PCT" -ge 45 ] && [ $(( count % 10 )) -eq 0 ]; then
  echo "[WARN] [context] ~${PCT}% — plenty of runway, monitor"
fi
