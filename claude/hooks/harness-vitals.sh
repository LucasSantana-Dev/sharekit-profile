#!/usr/bin/env bash
# harness-vitals.sh — SessionStart heartbeat. Surfaces SILENT failures in the harness's own
# automation (the class of bug that left the memory mirror dead 9 days undetected, 2026-06-26).
# Design: cheap checks every session, the one slow check (scorecard) only when skills changed.
# SILENT WHEN HEALTHY — emits a vitals block ONLY if something is off, so it's signal not noise.
# Never blocks (always exit 0); SessionStart context injection is advisory.
#
# 2026-07-23: checks 8-11 added (hook/plist target existence, heartbeats, ADR-0039 guard,
# catalog surface) after the moved-rag-index incident; 2026-07-24: check 12 (phantom
# guardrails) from the multi-person-work-ethics findings. EDIT THE CANONICAL COPY IN
# ~/.claude-env — ~/.claude is derived via `sync pull`; derived edits get reverted.
set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
ENV_DIR="$HOME/.claude-env"
SKILLS="$CLAUDE_DIR/skills"
RAG_ROOT="${DEV_ROOT}/rag-index"
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
# 2026-07-23: the index lives on the External HD now; the old ~/.claude/rag-index glob
# silently no-opped for weeks (the monitor had the disease it monitors for).
rag_db=$(ls -t "$RAG_ROOT"/*.sqlite "$RAG_ROOT"/*.db 2>/dev/null | head -1)
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
RALOG="$RAG_ROOT/eval/REGRESSION-ALERTS.log"
RASEEN="$RAG_ROOT/eval/.alerts-seen"
if [ -f "$RALOG" ]; then
  lm=$(stat -f %m "$RALOG" 2>/dev/null || stat -c %Y "$RALOG" 2>/dev/null || echo 0)
  sm=$(stat -f %m "$RASEEN" 2>/dev/null || stat -c %Y "$RASEEN" 2>/dev/null || echo 0)
  [ "$lm" -gt "$sm" ] && warns+=("UNREAD eval regression alert(s): $(tail -1 "$RALOG") — investigate, then: touch $RASEEN")
fi

# 5b. mount guard — External HD unmounted means RAG/brain/repos silently unreachable
# (knowledge-brain.md prescribes loud-fail; was only enforced per-skill until 2026-07-09)
[ -d "${DEV_ROOT}" ] || warns+=("External HD NOT MOUNTED - RAG index, knowledge-brain, and dev repos unreachable; mount before any memory/graph write")

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

# 8. hook + launchd target existence - moved/deleted scripts fail SILENTLY for weeks
# (2026-07-23: 4 hooks + graph-refresh plist pointed at the pre-move rag-index path;
# 2 orphaned plists pointed at a deleted skill dir; autorecall burned a 20s timeout
# on every prompt). This check turns that class into a same-session alarm.
settings_json="$CLAUDE_DIR/settings.json"
if [ -f "$settings_json" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && [ ! -e "$p" ] && warns+=("hook target MISSING: $p (registered in settings.json) - hook errors every fire")
  done < <(python3 - "$settings_json" 2>/dev/null <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
for groups in (d.get("hooks") or {}).values():
    for g in groups:
        for h in g.get("hooks", []):
            c = h.get("command", "")
            m = re.search(r'"(/[^"]+)"|(?:^|\s)(/[^\s;>&|]+\.(?:sh|py|js))\b', c)
            if m:
                print(next(x for x in m.groups() if x))
PY
)
fi

PLIST_PREFIXES="com.lucas. com.luk. com.<github-user>."
for pre in $PLIST_PREFIXES; do
for plist in "$HOME/Library/LaunchAgents/$pre"*.plist; do
  [ -f "$plist" ] || continue
  while IFS= read -r raw; do
    # expand common vars; skip flags, remote specs (scp host:path), non-absolute args
    p="${raw//\$HOME/$HOME}"; p="${p//\$\{HOME\}/$HOME}"; p="${p/#\~/$HOME}"
    case "$p" in -*|:*|*:* ) continue;; esac
    [ "${p#/}" = "$p" ] && continue
    # arg is a command line with parameters: check only the program token
    if [ "$p" != "${p%% *}" ]; then
      first="${p%% *}"
      case "$first" in *.sh|*.py|*.command|*/bin/*) p="$first";; *) continue;; esac
    fi
    [ -e "$p" ] || warns+=("launchd target MISSING: $raw ($(basename "$plist")) - job errors every fire; unload or repoint")
  done < <(plutil -extract ProgramArguments json -o - "$plist" 2>/dev/null | python3 -c 'import json,sys
try:
  [print(x) for x in json.load(sys.stdin) if isinstance(x, str)]
except Exception: pass' 2>/dev/null)
done
done

# 9. scheduled-job heartbeats - jobs that exit 0 while doing nothing (nightly rebuild
# logged "skipping" + exit 0 for weeks via a PATH bug) only surface via freshness.
hb_dir="$HOME/.claude/heartbeats"
check_hb() { # $1 label, $2 max-age-hours
  f="$hb_dir/$1.ok"
  if [ ! -f "$f" ]; then warns+=("heartbeat MISSING: $1 never completed since instrumentation - check job + log"); return; fi
  h=$(age_h "$(cat "$f" 2>/dev/null || echo 0)")
  [ "$h" -gt "$2" ] && warns+=("heartbeat STALE: $1 last completed ${h}h ago (expected < ${2}h) - job dead or no-op?")
}
check_hb rag-nightly-rebuild 36
check_hb memory-weekly-sync 200

# 10. ADR-0039 guard - project auto-memory copies must never re-enter the RAG index
# (they are ~84% vault duplicates that filled both retrieval slots; enforced in
# build.py 2026-07-23). Alert if any chunk reappears under a .claude/projects path.
rag_db_main="$RAG_ROOT/index.sqlite"
if [ -f "$rag_db_main" ]; then
  n=$(sqlite3 "$rag_db_main" "SELECT COUNT(*) FROM chunks WHERE path LIKE '%/.claude/projects/%/memory/%';" 2>/dev/null || echo 0)
  [ "${n:-0}" -gt 0 ] && warns+=("ADR-0039 VIOLATION: $n RAG chunks from ~/.claude/projects/*/memory/ - duplicates are back in the index; purge + check build.py SOURCES")
fi

# 11. catalog surface - broken skill symlinks + live/archive name collisions
# (2026-07-23 audit: 89 broken symlinks = 30% of listing; overlap grew 120→128 in a week)
ASK_ROOT="$HOME/.agents/skills"
if [ -d "$ASK_ROOT" ]; then
  nb=$(find "$ASK_ROOT" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
  [ "${nb:-0}" -gt 0 ] && warns+=("skills catalog: $nb broken symlinks in ~/.agents/skills - delete: find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \; -delete")
  if [ -d "$ASK_ROOT/.archive" ]; then
    coll=$(comm -12 <(ls "$ASK_ROOT" 2>/dev/null | grep -v '^\.' | sort) <(ls "$ASK_ROOT/.archive" 2>/dev/null | sort) 2>/dev/null | wc -l | tr -d ' ')
    [ "${coll:-0}" -gt 0 ] && warns+=("skills catalog: $coll names exist BOTH live and archived - move .archive/ out of the skills root")
  fi
fi

# 12. phantom-guardrail check (multi-person-work-ethics 2.6): every rule that
# claims MECHANICAL enforcement must name an artifact that provably exists.
# If one of these goes missing, the rules citing it are instructions, not rails.
for art in \
  "$HOME/.claude/scripts/repo-mode.sh" \
  "$ENV_DIR/bin/sync" \
  "$HOME/.agents/skills/standards/cooperative-mode.md" \
  "$HOME/.agents/skills/standards/multi-person-work-ethics.md"; do
  [ -e "$art" ] || warns+=("enforcement artifact MISSING: $art - rules citing it are phantom guardrails")
done
# kimi-code hook only applies to operators who have kimi-code installed; skip the
# check entirely rather than false-warn on every other operator's SessionStart.
if [ -d "$HOME/.kimi-code" ]; then
  art="$HOME/.kimi-code/hooks/rtk-rewrite.sh"
  [ -e "$art" ] || warns+=("enforcement artifact MISSING: $art - rules citing it are phantom guardrails")
fi

# 13. resurrection guard - uncommitted deletions in the config repos are exactly
# what the WIP-sync restores silently (2026-07-24/27 incident: 8 skill deletions +
# 89 symlinks + .archive resurrected after the clobber-guard blocked the
# auto-snapshot and the state sat uncommitted for days). If you just deleted a
# batch intentionally, COMMIT it: CLAUDE_SYNC_MAX_DEL=500 ~/.claude-env/bin/sync push
for repo in "$HOME/.agents/skills" "$ENV_DIR"; do
  [ -d "$repo/.git" ] || continue
  dels=$(git -C "$repo" status --porcelain 2>/dev/null | grep -c '^ *D' || true)
  [ "${dels:-0}" -gt 20 ] && warns+=("resurrection risk: $dels UNCOMMITTED deletions in $repo - commit now (CLAUDE_SYNC_MAX_DEL=500 ~/.claude-env/bin/sync push) or the WIP-sync will restore them")
done

# Emit ONLY if something is off (silent-when-healthy)
if [ ${#warns[@]} -gt 0 ]; then
  printf '## ⚠ Harness vitals (%d issue%s)\n' "${#warns[@]}" "$([ ${#warns[@]} -eq 1 ] || echo s)"
  for w in "${warns[@]}"; do printf -- '- %s\n' "$w"; done
  printf 'Silent-failure check — address or it persists unseen. (harness-vitals.sh)\n'
fi
exit 0
