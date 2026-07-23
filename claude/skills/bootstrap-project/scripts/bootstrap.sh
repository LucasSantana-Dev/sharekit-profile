#!/usr/bin/env bash
# bootstrap-project — idempotent STRUCTURAL backbone for standing up a new project in the
# centralized knowledge-brain. Content (seed-memory text, context) is filled by the skill agent.
#
# Usage: bootstrap.sh [<project-path>] [--name NAME] [--update] [--dry-run]
#   <project-path>  defaults to $PWD
#   --name NAME     override detected project name
#   --update        re-run even if already registered (refresh stubs/graph/registry)
#   --dry-run       print the plan, write nothing
#
# Exit: 0 ok/already-done · 1 bad args/path · 2 mount guard (External HD unmounted)
set -euo pipefail

# Portable: the centralized brain location is configurable. Set KNOWLEDGE_BRAIN to your vault
# (e.g. an external drive); defaults to ~/knowledge-brain so the skill works on any machine.
BRAIN="${KNOWLEDGE_BRAIN:-$HOME/knowledge-brain}"
PROJECTS_DIR="$HOME/.claude/projects"

DRY=0; UPDATE=0; NAME=""; PROJ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --update)  UPDATE=1 ;;
    --name)    NAME="${2:-}"; shift ;;
    -*)        echo "unknown flag: $1" >&2; exit 1 ;;
    *)         PROJ="$1" ;;
  esac
  shift
done

PROJ="${PROJ:-$PWD}"
PROJ="$(cd "$PROJ" 2>/dev/null && pwd)" || { echo "BLOCKED: project path not found: $PROJ"; exit 1; }

# --- mount guard: only when the brain lives on a mounted volume (external drive etc.) ---
case "$BRAIN" in
  /Volumes/*|/mnt/*|/media/*)
    vol="$(printf '%s\n' "$BRAIN" | cut -d/ -f1-3)"
    mount | grep -q "$vol" || { echo "BLOCKED: '$vol' not mounted — brain unreachable"; exit 2; } ;;
esac

# --- detect name + slug ---
if [ -z "$NAME" ]; then
  NAME="$(git -C "$PROJ" remote get-url origin 2>/dev/null | sed -E 's#.*[:/]##; s#\.git$##' || true)"
  [ -z "$NAME" ] && NAME="$(basename "$PROJ")"
fi
SLUG="$(printf '%s' "$PROJ" | sed 's#[/ ]#-#g')"   # matches ~/.claude/projects/<slug> convention (spaces also dashed)
GRAPHDIR="$BRAIN/graphs/$NAME"
REG="$BRAIN/PROJECTS.md"
DATE="$(date +%Y-%m-%d)"

# act FILE_OP — run unless --dry-run
act() { if [ "$DRY" = 1 ]; then echo "  [dry] $*"; else eval "$*"; fi; }

echo "bootstrap-project: name=$NAME  slug=$SLUG  path=$PROJ  (dry=$DRY update=$UPDATE)"

# --- idempotency: already bootstrapped? ---
if grep -qF "| \`$NAME\` " "$REG" 2>/dev/null && [ "$UPDATE" = 0 ]; then
  echo "ALREADY-BOOTSTRAPPED: '$NAME' is in PROJECTS.md — pass --update to refresh. No structural changes."
  exit 0
fi

# --- Phase 1: memory symlink (One-Brain) ---
PMEM="$PROJECTS_DIR/$SLUG/memory"
if [ -L "$PMEM" ]; then
  echo "  P1 memory: symlink exists ✓"
elif [ -d "$PMEM" ]; then
  echo "  P1 memory: ⚠ REAL dir at $PMEM (not a symlink) — NOT clobbering; reconcile manually"
else
  act "mkdir -p \"$PROJECTS_DIR/$SLUG\""
  act "ln -s \"$BRAIN/memory\" \"$PMEM\""
  echo "  P1 memory: symlink created → vault/memory"
fi

# --- Phase 2: seed memory stubs (agent fills content) ---
for kind in overview conventions decisions; do
  f="$BRAIN/memory/${NAME}-${kind}.md"
  if [ -e "$f" ]; then
    echo "  P2 seed $kind: exists ✓"
  elif [ "$DRY" = 1 ]; then
    echo "  [dry] write stub $f"
  else
    cat > "$f" <<EOF
---
name: ${NAME}-${kind}
tags:
  - project/${NAME}
  - type/${kind}
  - status/active
description: "FILL: one-line summary of ${NAME} ${kind}"
---
# ${NAME} — ${kind}

<!-- bootstrap stub — agent fills from repo inference (README, manifest, entrypoints, git log).
     Keep ONLY portable / how-we-work facts here; project-specific canonical facts -> repo CLAUDE.md. -->
EOF
    echo "  P2 seed $kind: stub created"
  fi
done

# --- Phase 4: centralized graph dir + repo graphify-out symlink ---
act "mkdir -p \"$GRAPHDIR\""
if [ -L "$PROJ/graphify-out" ]; then
  echo "  P4 graph: repo graphify-out symlink exists ✓"
elif [ -e "$PROJ/graphify-out" ]; then
  echo "  P4 graph: ⚠ repo has a REAL graphify-out — move it to $GRAPHDIR once to centralize, then symlink"
else
  act "ln -s \"$GRAPHDIR\" \"$PROJ/graphify-out\""
  echo "  P4 graph: graphify-out → vault graphs/$NAME (run 'graphify' to build)"
fi

# --- Phase 5: registry ---
if grep -qF "| \`$NAME\` " "$REG" 2>/dev/null; then
  echo "  P5 registry: present ✓"
elif [ "$DRY" = 1 ]; then
  echo "  [dry] append '$NAME' row to PROJECTS.md"
else
  if [ ! -f "$REG" ]; then
    printf '# Projects — centralized knowledge-brain registry\n\nProjects bootstrapped into the One-Brain (memory symlink + central graph). See bootstrap-project skill.\n\n| project | path | graph | bootstrapped |\n|---|---|---|---|\n' > "$REG"
  fi
  printf '| `%s` | %s | graphs/%s/ | %s |\n' "$NAME" "$PROJ" "$NAME" "$DATE" >> "$REG"
  echo "  P5 registry: added '$NAME' to PROJECTS.md"
fi

echo "DONE (structural). Next (agent): fill seed memories + repo CLAUDE.md; run 'graphify' for the central graph."
if [ -n "$(git -C "$PROJ" rev-parse --is-inside-work-tree 2>/dev/null || true)" ]; then
  echo "HINT: repo has git — if it already has code, auto-chain /onboard-new-repo after seeding."
fi
