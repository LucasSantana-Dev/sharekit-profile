#!/usr/bin/env bash
# shellcheck source=py-resolve.sh
. "$(dirname "${BASH_SOURCE[0]}")/py-resolve.sh" 2>/dev/null || PY=""
# No early exit when PY is empty: this hook is the silent-failure detector, so the
# python-free checks still run and the python-backed ones are skipped LOUDLY (below).
# harness-vitals.sh — SessionStart heartbeat. Surfaces SILENT failures in the harness's own
# automation (the class of bug that left the memory mirror dead 9 days undetected, 2026-06-26).
# Design: cheap checks every session, the one slow check (scorecard) only when skills changed.
# SILENT WHEN HEALTHY — emits a vitals block ONLY if something is off, so it's signal not noise.
# Never blocks (always exit 0); SessionStart context injection is advisory.
#
# 2026-07-23: checks 8-11 added (hook/plist target existence, heartbeats, ADR-0039 guard,
# catalog surface) after the moved-rag-index incident; 2026-07-24: check 12 (phantom
# guardrails) from the cooperative-mode ethics rules. EDIT THE CANONICAL COPY IN
# ~/.claude-env — ~/.claude is derived via `sync pull`; derived edits get reverted.
set -uo pipefail

# `timeout` is absent on stock macOS: use gtimeout, else a python3 stdlib shim, else no limit.
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then
    timeout() { gtimeout "$@"; }
  elif [ -n "$PY" ]; then
    timeout() {
      "$PY" -c 'import subprocess, sys
try:
    sys.exit(subprocess.run(sys.argv[2:], timeout=float(sys.argv[1])).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except OSError:
    sys.exit(127)' "$@"
    }
  else
    timeout() { shift; "$@"; }
  fi
fi

CLAUDE_DIR="$HOME/.claude"
ENV_DIR="$HOME/.claude-env"
SKILLS="$CLAUDE_DIR/skills"
# Overridable so a sandbox (harness-selftest.sh) can simulate "mounted" without a real
# external volume — real machine default is unchanged.
# DEV_ROOT is the repo root (rag-index lives directly under it); EXTERNAL_HD_DIR overrides
# only the mount check, which defaults to the dev root itself.
DEV_ROOT_DIR="${DEV_ROOT:-$HOME/dev}"
EXTERNAL_HD="${EXTERNAL_HD_DIR:-$DEV_ROOT_DIR}"
RAG_ROOT="$DEV_ROOT_DIR/rag-index"
warns=()
[ -n "$PY" ] || warns+=("no working python3/python: scorecard, hook-target, launchd-target and rag-job checks skipped")

now=$(date +%s)
age_h() { echo $(( (now - $1) / 3600 )); }   # epoch -> hours ago

# 1. claude-env mirror: unpushed commits OR last push stale (> 36h) => mirror may be silently behind
if [ -d "$ENV_DIR/.git" ]; then
  # Compare against the CURRENT branch's upstream, not origin/main: on a feature branch
  # with an open PR the origin/main baseline calls pushed work "UNPUSHED" and suggests a
  # push that the PR-required hook refuses — a warning with no resolution (2026-08-28).
  ahead_ref=$(git -C "$ENV_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo origin/main)
  ahead=$(git -C "$ENV_DIR" rev-list --count "$ahead_ref..HEAD" 2>/dev/null || echo 0)
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
  m=$(stat -c %Y "$rag_db" 2>/dev/null || stat -f %m "$rag_db" 2>/dev/null || echo "$now")
  d=$(( (now - m) / 86400 )); [ "$d" -gt 7 ] && warns+=("RAG index ${d}d old ($(basename "$rag_db")) — recall may miss recent work; reindex")
fi

# 5. scorecard delta — only when a skill changed since the committed baseline (keeps SessionStart fast)
sc="$CLAUDE_DIR/scripts/harness-skill-scorecard.py"
base="$CLAUDE_DIR/scripts/scorecard-baseline.json"
if [ -n "$PY" ] && [ -f "$sc" ] && [ -f "$base" ]; then
  changed=$(find "$SKILLS/" -maxdepth 2 -name SKILL.md -newer "$base" 2>/dev/null | head -1)
  if [ -n "$changed" ]; then
    cur=$(timeout 15 "$PY" "$sc" --json 2>/dev/null | "$PY" -c "import sys,json;print(json.load(sys.stdin)['structural_score_pct'])" 2>/dev/null || echo "")
    bscore=$("$PY" -c "import json;print(json.load(open('$base'))['structural_score_pct'])" 2>/dev/null || echo "")
    if [ -n "$cur" ] && [ -n "$bscore" ]; then
      lower=$("$PY" -c "print(1 if float('$cur')<float('$bscore') else 0)" 2>/dev/null || echo 0)
      [ "$lower" = "1" ] && warns+=("scorecard REGRESSION: ${cur}% < baseline ${bscore}% — a skill broke; run: python3 $sc")
    fi
  fi
fi

# 5a. unread eval regression alerts — REGRESSION-ALERTS.log fired daily 06-22→07-01 unseen (ADR-0052)
RALOG="$RAG_ROOT/eval/REGRESSION-ALERTS.log"
RASEEN="$RAG_ROOT/eval/.alerts-seen"
if [ -f "$RALOG" ]; then
  lm=$(stat -c %Y "$RALOG" 2>/dev/null || stat -f %m "$RALOG" 2>/dev/null || echo 0)
  sm=$(stat -c %Y "$RASEEN" 2>/dev/null || stat -f %m "$RASEEN" 2>/dev/null || echo 0)
  [ "$lm" -gt "$sm" ] && warns+=("UNREAD eval regression alert(s): $(tail -1 "$RALOG") — investigate, then: touch $RASEEN")
fi

# 5b. mount guard — External HD unmounted means RAG/brain/repos silently unreachable
# (knowledge-brain.md prescribes loud-fail; was only enforced per-skill until 2026-07-09)
[ -d "$EXTERNAL_HD" ] || warns+=("External HD NOT MOUNTED - RAG index, knowledge-brain, and dev repos unreachable; mount before any memory/graph write")

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

# 6c. hooks-tree drift — the same trap as check 6, one directory over. ~/.claude/hooks is a
# REAL, writable directory rendered from ~/.claude-env/hooks by `sync pull`, which is itself a
# SessionStart hook. An edit there is accepted, runs, passes its tests, and is gone next
# session. On 2026-08-28 three shipped hook fixes vanished exactly this way. Both directions
# matter: a differing file is an edit about to be reverted; a file only in the derived copy is
# unversioned and invisible to every other machine.
if [ -d "$ENV_DIR/hooks" ] && [ -d "$HOME/.claude/hooks" ]; then
  hd=$(diff -rq "$ENV_DIR/hooks" "$HOME/.claude/hooks" 2>/dev/null \
       | grep -vE '\.(bak|log|stamp|sha256)( |$)|\.selftest-stamp|\.rtk-hook' | head -20)
  ndiff=$(printf '%s' "$hd" | grep -c '^Files .* differ$')
  nonly=$(printf '%s' "$hd" | grep -c "^Only in $HOME/.claude/hooks")
  [ "${ndiff:-0}" -gt 0 ] && warns+=("hooks DRIFT: $ndiff file(s) differ from ~/.claude-env/hooks — the next 'sync pull' REVERTS the derived copy; port the edit to the canonical tree and commit")
  [ "${nonly:-0}" -gt 0 ] && warns+=("hooks UNVERSIONED: $nonly file(s) exist only in ~/.claude/hooks — copy to ~/.claude-env/hooks and commit, or they reach no other machine")
fi

# 7. stale active handoff (> 14d) — a forgotten resume packet
# -L on both ls and stat: latest.md is a symlink whose own mtime never changes
# after creation (2026-08-02 — was reporting "41d old" forever regardless of how
# fresh the target content actually was, a permanent false positive).
hand=$(ls -tL "$CLAUDE_DIR"/handoffs/latest.md "$CLAUDE_DIR"/handoffs/*/latest.md 2>/dev/null | head -1)
if [ -n "${hand:-}" ]; then
  m=$(stat -c %Y -L "$hand" 2>/dev/null || stat -f %m -L "$hand" 2>/dev/null || echo "$now")
  d=$(( (now - m) / 86400 )); [ "$d" -gt 14 ] && warns+=("handoff ${d}d old ($hand) — stale resume packet, clear or act on it")
fi

# 8. hook + launchd target existence — moved/deleted scripts fail SILENTLY for weeks
# (2026-07-23: 4 hooks + graph-refresh plist pointed at the pre-move rag-index path;
# 2 orphaned plists pointed at a deleted skill dir; autorecall burned a 20s timeout
# on every prompt). This check turns that class into a same-session alarm.
settings_json="$CLAUDE_DIR/settings.json"
if [ -n "$PY" ] && [ -f "$settings_json" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && [ ! -e "$p" ] && warns+=("hook target MISSING: $p (registered in settings.json) — hook errors every fire")
  done < <("$PY" - "$settings_json" 2>/dev/null <<'PY'
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
[ -n "$PY" ] || PLIST_PREFIXES=""   # ProgramArguments parsing needs python
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
    [ -e "$p" ] || warns+=("launchd target MISSING: $raw ($(basename "$plist")) — job errors every fire; unload or repoint")
  done < <(plutil -extract ProgramArguments json -o - "$plist" 2>/dev/null | "$PY" -c 'import json,sys
try:
  [print(x) for x in json.load(sys.stdin) if isinstance(x, str)]
except Exception: pass' 2>/dev/null)
done
done

# 8b. Kali lane — `kali-docker-pentesting` documented `docker exec kali-pentest <tool>` while
# no such container and no such image existed on this machine, and DOCKER_HOST pointed at a
# socket path with a literal $HOME so every call failed silently (2026-08-29). One cheap probe,
# and only when the socket is actually there: colima being off is a choice, not a defect.
KALI_SOCK="$HOME/.colima/default/docker.sock"
if [ -S "$KALI_SOCK" ] && command -v docker >/dev/null 2>&1; then
  kstate=$(timeout 5 env DOCKER_HOST="unix://$KALI_SOCK" docker inspect -f '{{.State.Status}}' kali-pentest 2>/dev/null || true)
  case "$kstate" in
    running) ;;
    "")      warns+=("kali lane: container 'kali-pentest' does not exist, but kali-docker-pentesting documents docker exec against it — recreate it or the skill is fiction (skills/kali-docker-pentesting/scripts/kali-health.sh)") ;;
    *)       warns+=("kali lane: container 'kali-pentest' is $kstate — docker start kali-pentest") ;;
  esac
fi

# 9. scheduled-job heartbeats — jobs that exit 0 while doing nothing (nightly rebuild
# logged "skipping" + exit 0 for weeks via a PATH bug) only surface via freshness.
hb_dir="$HOME/.claude/heartbeats"
check_hb() { # $1 label, $2 max-age-hours
  f="$hb_dir/$1.ok"
  if [ ! -f "$f" ]; then warns+=("heartbeat MISSING: $1 never completed since instrumentation — check job + log"); return; fi
  h=$(age_h "$(cat "$f" 2>/dev/null || echo 0)")
  [ "$h" -gt "$2" ] && warns+=("heartbeat STALE: $1 last completed ${h}h ago (expected < ${2}h) — job dead or no-op?")
}
check_hb rag-nightly-rebuild 36
check_hb memory-weekly-sync 200
# gdrive-backup runs every 4h; it logged FAIL on every target for 43 days undetected.
check_hb gdrive-backup 8
# sync-dev-assets runs every 3 days; its last line was `[ test ] && log || log`, so it
# exited 0 while the git push had been failing since 2026-08-16.
check_hb sync-dev-assets 96

# 9a. rag-jobs status files - launchd's own exit code stays 0 even when a scheduled
# job degraded (mount absent, remote sync failed) or never ran at all; each run of
# fix-drift-loop.sh / rag-nightly-rebuild.sh writes ~/.claude/state/rag-jobs/<job>.json
# with status ok|degraded|failed|skipped-no-disk. Surface anything not ok, or ok but
# stale (job stopped running silently).
RAG_JOBS_DIR="$HOME/.claude/state/rag-jobs"
if [ -n "$PY" ] && [ -d "$RAG_JOBS_DIR" ]; then
  for jf in "$RAG_JOBS_DIR"/*.json; do
    [ -f "$jf" ] || continue
    jname=$(basename "$jf" .json)
    IFS='|' read -r jstatus jfinished jdetail < <("$PY" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("status", "?") + "|" + d.get("finished", "?") + "|" + d.get("detail", "?"))
except Exception:
    print("?|?|unreadable status file")
' "$jf" 2>/dev/null)
    if [ "$jstatus" != "ok" ]; then
      warns+=("rag-job $jname: status=$jstatus - $jdetail")
      continue
    fi
    fe=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$jfinished" +%s 2>/dev/null || date -u -d "$jfinished" +%s 2>/dev/null || echo "")
    if [ -n "$fe" ]; then
      h=$(age_h "$fe")
      [ "$h" -gt 36 ] && warns+=("rag-job $jname: status=ok but finished ${h}h ago (stale, expected < 36h)")
    fi
  done
fi

# 10. ADR-0039 guard — project auto-memory copies must never re-enter the RAG index
# (they are ~84% vault duplicates that filled both retrieval slots; enforced in
# build.py 2026-07-23). Alert if any chunk reappears under a .claude/projects path.
rag_db_main="$RAG_ROOT/index.sqlite"
if [ -f "$rag_db_main" ]; then
  n=$(sqlite3 "$rag_db_main" "SELECT COUNT(*) FROM chunks WHERE path LIKE '%/.claude/projects/%/memory/%';" 2>/dev/null || echo 0)
  [ "${n:-0}" -gt 0 ] && warns+=("ADR-0039 VIOLATION: $n RAG chunks from ~/.claude/projects/*/memory/ — duplicates are back in the index; purge + check build.py SOURCES")
fi

# 11. catalog surface — broken skill symlinks + live/archive name collisions
# (2026-07-23 audit: 89 broken symlinks = 30% of listing; overlap grew 120→128 in a week)
ASK_ROOT="$HOME/.agents/skills"
if [ -d "$ASK_ROOT" ]; then
  nb=$(find "$ASK_ROOT" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
  [ "${nb:-0}" -gt 0 ] && warns+=("skills catalog: $nb broken symlinks in ~/.agents/skills — delete: find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \; -delete")
  if [ -d "$ASK_ROOT/.archive" ]; then
    # Only a LOADABLE archived copy can shadow a live skill. Archived entries carry
    # SKILL.md.archived (not SKILL.md) and sit inside a dotdir, so a bare name
    # collision is inert — counting names produced an unresolvable warning.
    coll=$(find "$ASK_ROOT/.archive" -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "${coll:-0}" -gt 0 ] && warns+=("skills catalog: $coll archived skills still carry a loadable SKILL.md — rename to SKILL.md.archived")
  fi
fi

# 12. phantom-guardrail check (cooperative-mode rule 6): every rule that
# claims MECHANICAL enforcement must name an artifact that provably exists.
# If one of these goes missing, the rules citing it are instructions, not rails.
for art in \
  "$HOME/.claude/scripts/repo-mode.sh" \
  "$HOME/.kimi-code/hooks/rtk-rewrite.sh" \
  "$ENV_DIR/bin/sync" \
  "$HOME/.agents/skills/standards/cooperative-mode.md"; do
  [ -e "$art" ] || warns+=("enforcement artifact MISSING: $art — rules citing it are phantom guardrails")
done

# 13. resurrection guard — uncommitted deletions in the config repos are exactly
# what the WIP-sync restores silently (2026-07-24/27 incident: 8 skill deletions +
# 89 symlinks + .archive resurrected after the clobber-guard blocked the
# auto-snapshot and the state sat uncommitted for days). If you just deleted a
# batch intentionally, COMMIT it: CLAUDE_SYNC_MAX_DEL=500 ~/.claude-env/bin/sync push
for repo in "$HOME/.agents/skills" "$ENV_DIR"; do
  [ -d "$repo/.git" ] || continue
  dels=$(git -C "$repo" status --porcelain 2>/dev/null | grep -c '^ *D' || true)
  [ "${dels:-0}" -gt 20 ] && warns+=("resurrection risk: $dels UNCOMMITTED deletions in $repo — commit now (CLAUDE_SYNC_MAX_DEL=500 ~/.claude-env/bin/sync push) or the WIP-sync will restore them")
done

# 14. MEMORY.md over 180 lines (folded from memory-index-size-alert.sh; the release-drift nudge was dropped, release-cadence.md retires that flow); once per day per project
MS_STATE="$CLAUDE_DIR/state/memory-size-alert"
for MD in "$CLAUDE_DIR"/projects/*/memory/MEMORY.md; do
  [ -f "$MD" ] || continue
  ml=$(wc -l < "$MD" 2>/dev/null | tr -d ' ')
  [ "${ml:-0}" -gt 180 ] || continue
  mp=$(basename "$(dirname "$(dirname "$MD")")")
  mf="$MS_STATE/$mp-$(date -u +%Y-%m-%d)"
  [ -f "$mf" ] && continue
  mkdir -p "$MS_STATE" 2>/dev/null && touch "$mf"
  warns+=("MEMORY.md of $mp has $ml lines (over 180): run /memory-prune")
done

# Emit ONLY if something is off (silent-when-healthy).
# Cache hygiene (2026-07-28): the volatile vitals block goes to systemMessage
# (user-only, never enters model context); the model gets a STATIC directive in
# additionalContext so session-prefix bytes stay stable across sessions.
if [ ${#warns[@]} -gt 0 ]; then
  MSG=$(printf '## ⚠ Harness vitals (%d issue%s)\n' "${#warns[@]}" "$([ ${#warns[@]} -eq 1 ] || echo s)"; \
        for w in "${warns[@]}"; do printf -- '- %s\n' "$w"; done; \
        printf 'Silent-failure check — address or it persists unseen. (harness-vitals.sh)\n')
  jq -n --arg m "$MSG" '{
    systemMessage: $m,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "HARNESS VITALS: issues were detected by harness-vitals.sh (shown to the operator via system message, not visible to you). Do not investigate proactively; if the operator asks about harness health, run ~/.claude/hooks/harness-vitals.sh and read its output."
    }
  }' 2>/dev/null || printf '%s' "$MSG"
fi
exit 0
