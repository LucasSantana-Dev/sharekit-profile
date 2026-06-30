#!/usr/bin/env bash
# install-scheduler.sh — install / uninstall the nightly flywheel launchd agent.
#
# The flywheel cycle writes to .harness/runtime/ which is per-project, so this
# installs the scheduler for ONE project checkout. Run it from the project root
# you want the flywheel to improve. Opt-in: sharekit install does NOT call this.
#
# Usage:
#   scripts/install-scheduler.sh install [project-root]   # default: pwd
#   scripts/install-scheduler.sh uninstall
#   scripts/install-scheduler.sh status
#   scripts/install-scheduler.sh run                       # trigger one cycle now
set -euo pipefail

LABEL="dev.sharekit.flywheel"
PLIST_DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$ROOT/scripts/launchd/flywheel.plist.template"

cmd="${1:-status}"; shift || true

case "$cmd" in
  install)
    project_root="${1:-$(pwd)}"
    [[ -d "$project_root" ]] || { echo "install: project root not found: $project_root" >&2; exit 1; }
    [[ -f "$TEMPLATE" ]] || { echo "install: template not found: $TEMPLATE" >&2; exit 1; }
    mkdir -p "$(dirname "$PLIST_DEST")"
    # Expand placeholders. Use python for cross-version sed safety on paths
    # with spaces (the project lives under /Volumes/External HD/...).
    python3 - "$TEMPLATE" "$PLIST_DEST" "$HOME" "$project_root" <<'PY'
import sys
src, dst, home, root = sys.argv[1:5]
with open(src) as f:
    text = f.read()
text = text.replace("__HOME__", home).replace("__ROOT__", root)
with open(dst, "w") as f:
    f.write(text)
print(f"installed: {dst}")
print(f"  project root: {root}")
print(f"  schedule: nightly 02:00 (see StartCalendarInterval in the plist)")
PY
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    launchctl load "$PLIST_DEST"
    echo "loaded: $LABEL"
    echo "next run: 02:00 local (or 'scripts/install-scheduler.sh run' to trigger now)"
    ;;

  uninstall)
    if [[ -f "$PLIST_DEST" ]]; then
      launchctl unload "$PLIST_DEST" 2>/dev/null || true
      rm -f "$PLIST_DEST"
      echo "uninstalled: $PLIST_DEST"
    else
      echo "not installed: $PLIST_DEST"
    fi
    ;;

  status)
    if launchctl list "$LABEL" >/dev/null 2>&1; then
      echo "status: loaded ($LABEL)"
      launchctl list "$LABEL" | sed 's/^/  /'
    else
      echo "status: not loaded ($LABEL)"
      [[ -f "$PLIST_DEST" ]] && echo "  (plist present at $PLIST_DEST but not loaded)"
    fi
    ;;

  run)
    # Trigger one cycle immediately without waiting for the schedule.
    launchctl start "$LABEL" 2>/dev/null && echo "triggered: $LABEL" || {
      echo "run: $LABEL not loaded; run 'scripts/install-scheduler.sh install' first" >&2
      exit 1
    }
    ;;

  *)
    echo "install-scheduler: unknown command: $cmd" >&2
    echo "usage: install-scheduler.sh install [project-root] | uninstall | status | run" >&2
    exit 1
    ;;
esac
