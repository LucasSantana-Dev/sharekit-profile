#!/usr/bin/env bash
# harness-vitals.sh — SessionStart heartbeat. Surfaces SILENT failures in the harness's own
# automation (the class of bug that left the memory mirror dead 9 days undetected, 2026-06-26).
# Design: cheap checks every session, the one slow check (scorecard) only when skills changed.
# SILENT WHEN HEALTHY — emits a vitals block ONLY if something is off, so it's signal not noise.
# Never blocks (always exit 0); SessionStart context injection is advisory.
set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
ENV_DIR="$HOME/.claude-env"
SKILLS="$CLAUDE_DIR/skills"
warns=()

now=$(date +%s)
age_h() { echo $(( (now - $1) / 3600 )); }   # epoch -> hours ago

# 1. claude-env mirror: unpushed commits OR last push stale (> 36h) => mirror may be silently behind
if [ -d "$ENV_DIR/.git" ]; then
  ahead=$(git -C "$ENV_DIR" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
  [ "${ahead:-0}" -gt 0 ] && warns+=("claude-env: $ahead commit(s) UNPUSHED — run: git -C ~/.claude-env push (or 'sync push')")
  last=$(git -C "$ENV_DIR" log -1 --format=%ct 2>/dev/null || echo "$now")
  h=$(age_h "$last"); [ "$h" -gt 36 ] && warns+=("claude-env: last commit ${h}h ago — mirror may be stale (SessionEnd 'sync push' not firing?)")
fi

# 2. skills repo (~/.agents/skills behind the symlink): unpushed snapshot
ASK="$HOME/.agents/skills"
if [ -d "$ASK/.git" ]; then
  sahead=$(git -C "$ASK" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
  [ "${sahead:-0}" -gt 0 ] && warns+=("skills-repo: $sahead commit(s) unpushed — git -C ~/.agents/skills push")
fi

# 3. broken symlinks for the core trees
for link in skills standards; do
  t="$CLAUDE_DIR/$link"
  [ -L "$t" ] && [ ! -e "$t" ] && warns+=("symlink BROKEN: ~/.claude/$link -> $(readlink "$t") (dangling)")
done

# 4. RAG index freshness (stale retrieval => recall returns old context silently)
rag_db=$(ls -t "$CLAUDE_DIR"/rag-index/*.sqlite "$CLAUDE_DIR"/rag-index/*.db 2>/dev/null | head -1)
if [ -n "${rag_db:-}" ]; then
  m=$(stat -f %m "$rag_db" 2>/dev/null || stat -c %Y "$rag_db" 2>/dev/null || echo "$now")
  d=$(( (now - m) / 86400 )); [ "$d" -gt 7 ] && warns+=("RAG index ${d}d old ($(basename "$rag_db")) — recall may miss recent work; reindex")
fi

# 5. scorecard delta — only when a skill changed since the committed baseline (keeps SessionStart fast)
sc="$CLAUDE_DIR/scripts/harness-skill-scorecard.py"
base="$CLAUDE_DIR/scripts/scorecard-baseline.json"
if [ -f "$sc" ] && [ -f "$base" ]; then
  changed=$(find "$SKILLS/" -maxdepth 2 -name SKILL.md -newer "$base" 2>/dev/null | head -1)
  if [ -n "$changed" ]; then
    cur=$(timeout 15 python3 "$sc" --json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['structural_score_pct'])" 2>/dev/null || echo "")
    bscore=$(python3 -c "import json;print(json.load(open('$base'))['structural_score_pct'])" 2>/dev/null || echo "")
    if [ -n "$cur" ] && [ -n "$bscore" ]; then
      lower=$(python3 -c "print(1 if float('$cur')<float('$bscore') else 0)" 2>/dev/null || echo 0)
      [ "$lower" = "1" ] && warns+=("scorecard REGRESSION: ${cur}% < baseline ${bscore}% — a skill broke; run: python3 $sc")
    fi
  fi
fi

# 5a. unread eval regression alerts — REGRESSION-ALERTS.log fired daily 06-22→07-01 unseen (ADR-0052)
RALOG="$CLAUDE_DIR/rag-index/eval/REGRESSION-ALERTS.log"
RASEEN="$CLAUDE_DIR/rag-index/eval/.alerts-seen"
if [ -f "$RALOG" ]; then
  lm=$(stat -f %m "$RALOG" 2>/dev/null || stat -c %Y "$RALOG" 2>/dev/null || echo 0)
  sm=$(stat -f %m "$RASEEN" 2>/dev/null || stat -c %Y "$RASEEN" 2>/dev/null || echo 0)
  [ "$lm" -gt "$sm" ] && warns+=("UNREAD eval regression alert(s): $(tail -1 "$RALOG") — investigate, then: touch $RASEEN")
fi

# 5b. mount guard — external drive unmounted means RAG/brain/repos silently unreachable
# (knowledge-brain.md prescribes loud-fail; was only enforced per-skill until 2026-07-09)
mount | grep -q "${DEV_ROOT}" || warns+=("external drive NOT MOUNTED — RAG index, knowledge-brain, and dev repos unreachable; mount before any memory/graph write")

# 6. settings drift — a live settings.json value that shared+machine will overwrite on the
# next `sync pull` (e.g. `/model opus` writes the derived file, but `model` is owned by
# shared.json, so the pull silently reverts it). Fix by porting the value into
# ~/.claude-env/settings/shared.json (all machines) or settings/machines/<host>.json (this one).
#
# 2026-07-15: was an mtime comparison (derived newer than shared.json => "drift"). settings.json
# is DERIVED — `sync pull` rewrites it every session, so its mtime is always newer and the check
# fired on every session by construction, never once identifying a real edit. Now content-based:
# `sync settings-check` re-renders the expected merge and reports only genuinely divergent keys
# (silent when clean; keys the merge preserves — theme/mcpServers/plugin cache — are not drift).
if [ -x "$ENV_DIR/bin/sync" ]; then
  drift=$("$ENV_DIR/bin/sync" settings-check 2>/dev/null || true)
  [ -n "$drift" ] && warns+=("settings drift: $drift — live settings.json differs from shared+machine; next \`sync pull\` will clobber it. Port to ~/.claude-env/settings/shared.json (all machines) or settings/machines/\$(hostname -s).json (this one)")
fi

# 6b. backgrounded SessionEnd sync push — failures only surface here (no auto-retry;
# next successful SessionEnd push clears it). Marker written by the SessionEnd hook.
PUSH_EXIT_FILE="$ENV_DIR/.last-push-exit"
if [ -f "$PUSH_EXIT_FILE" ]; then
  pe=$(tr -dc '0-9' < "$PUSH_EXIT_FILE" 2>/dev/null || echo "")
  [ -n "$pe" ] && [ "$pe" -ne 0 ] && warns+=("last SessionEnd sync push FAILED (exit $pe) — env changes not on remote; run: ~/.claude-env/bin/sync push (log: ~/.claude-env/.last-push.log)")
fi

# 7. stale active handoff (> 14d) — a forgotten resume packet
hand=$(ls -t "$CLAUDE_DIR"/handoffs/latest.md "$CLAUDE_DIR"/handoffs/*/latest.md 2>/dev/null | head -1)
if [ -n "${hand:-}" ]; then
  m=$(stat -f %m "$hand" 2>/dev/null || stat -c %Y "$hand" 2>/dev/null || echo "$now")
  d=$(( (now - m) / 86400 )); [ "$d" -gt 14 ] && warns+=("handoff ${d}d old ($hand) — stale resume packet, clear or act on it")
fi

# Emit ONLY if something is off (silent-when-healthy)
if [ ${#warns[@]} -gt 0 ]; then
  printf '## ⚠ Harness vitals (%d issue%s)\n' "${#warns[@]}" "$([ ${#warns[@]} -eq 1 ] || echo s)"
  for w in "${warns[@]}"; do printf -- '- %s\n' "$w"; done
  printf 'Silent-failure check — address or it persists unseen. (harness-vitals.sh)\n'
fi
exit 0
