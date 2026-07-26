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

# --- vault guard: a mounted volume does not prove the brain exists ---
# Without this, Phase 1 happily creates a symlink to a nonexistent
# "$BRAIN/memory" and Phase 2 then dies writing seeds, leaving the project
# half-bootstrapped. Refuse rather than create: auto-creating the vault would
# silently turn a typo in KNOWLEDGE_BRAIN into a second, empty brain.
[ -d "$BRAIN" ] || { echo "BLOCKED: brain not found at '$BRAIN' — set KNOWLEDGE_BRAIN or create it"; exit 2; }
[ -d "$BRAIN/memory" ] || { echo "BLOCKED: '$BRAIN' has no memory/ dir — not a knowledge-brain vault (mkdir it if this is a fresh vault)"; exit 2; }

# --- detect name + slug ---
if [ -z "$NAME" ]; then
  NAME="$(git -C "$PROJ" remote get-url origin 2>/dev/null | sed -E 's#.*[:/]##; s#\.git$##' || true)"
  [ -z "$NAME" ] && NAME="$(basename "$PROJ")"
fi
SLUG="$(printf '%s' "$PROJ" | sed 's#[/ ]#-#g')"   # matches ~/.claude/projects/<slug> convention (spaces also dashed)
GRAPHDIR="$BRAIN/graphs/$NAME"
REG="$BRAIN/PROJECTS.md"
DATE="$(date +%Y-%m-%d)"

# act CMD ARG... — run unless --dry-run.
# Takes the command and its arguments as separate words and runs them directly.
# It used to take one string and `eval` it, which re-parsed embedded command
# substitutions: BRAIN and PROJ come from flags and NAME defaults to a basename
# of `git remote get-url origin`, so a path or remote containing $(...) executed
# during bootstrap. Cloning a hostile repo and bootstrapping it was enough.
act() { if [ "$DRY" = 1 ]; then echo "  [dry] $*"; else "$@"; fi; }

echo "bootstrap-project: name=$NAME  slug=$SLUG  path=$PROJ  (dry=$DRY update=$UPDATE)"

# --- name collision: same NAME, different project path ---
# NAME is a bare remote basename, so org-a/api.git and org-b/api.git both
# resolve to "api" and would silently share seed files, graph dir and registry
# row. The registry already records the path, so compare against it and stop
# instead of merging two projects into one identity. Detection rather than
# auto-renaming: changing NAME's shape would rewrite paths for every project
# already bootstrapped, and the operator is better placed to pick the new name.
reg_row="$(grep -F "| \`$NAME\` " "$REG" 2>/dev/null | head -1 || true)"
if [ -n "$reg_row" ]; then
  reg_path="$(printf '%s' "$reg_row" | awk -F' *\\| *' '{print $3}')"
  if [ -n "$reg_path" ] && [ "$reg_path" != "$PROJ" ]; then
    echo "BLOCKED: name collision — '$NAME' is already registered for a different path:"
    echo "  registered: $reg_path"
    echo "  this repo:  $PROJ"
    echo "  Re-run with an explicit unique name, e.g. --name <owner>-$NAME"
    exit 1
  fi
fi

# --- idempotency: already bootstrapped? ---
if [ -n "$reg_row" ] && [ "$UPDATE" = 0 ]; then
  echo "ALREADY-BOOTSTRAPPED: '$NAME' is in PROJECTS.md — pass --update to refresh. No structural changes."
  exit 0
fi

# --- Phase 1: memory symlink (One-Brain) ---
PMEM="$PROJECTS_DIR/$SLUG/memory"
if [ -L "$PMEM" ]; then
  # -L only proves it is a symlink. A stale or mispointed link silently splits
  # this project's memory from the central vault, which looks identical to
  # success from the outside.
  pmem_target="$(cd "$(dirname "$PMEM")" && readlink "$PMEM")"
  case "$pmem_target" in
    "$BRAIN/memory") echo "  P1 memory: symlink exists ✓" ;;
    *) echo "  P1 memory: ⚠ symlink points at '$pmem_target', expected '$BRAIN/memory' — reconcile manually"
       echo "BLOCKED: refusing to register a project whose memory link bypasses the vault"
       exit 1 ;;
  esac
elif [ -d "$PMEM" ]; then
  # Documented stop condition, so actually stop. Continuing here wrote seeds, a
  # graph link and a registry row, marking the project bootstrapped while its
  # One-Brain link was absent.
  echo "  P1 memory: ⚠ REAL dir at $PMEM (not a symlink) — NOT clobbering; reconcile manually"
  echo "BLOCKED: stopping before Phase 2 so the project is not registered as bootstrapped"
  exit 1
else
  act mkdir -p "$PROJECTS_DIR/$SLUG"
  act ln -s "$BRAIN/memory" "$PMEM"
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
act mkdir -p "$GRAPHDIR"
if [ -L "$PROJ/graphify-out" ]; then
  # Same reasoning as Phase 1: a symlink pointing somewhere else means graph
  # output is not landing in the central vault.
  gout_target="$(cd "$PROJ" && readlink graphify-out)"
  if [ "$gout_target" = "$GRAPHDIR" ]; then
    echo "  P4 graph: repo graphify-out symlink exists ✓"
  else
    echo "  P4 graph: ⚠ graphify-out points at '$gout_target', expected '$GRAPHDIR' — graph output is not centralized; reconcile manually"
  fi
elif [ -e "$PROJ/graphify-out" ]; then
  echo "  P4 graph: ⚠ repo has a REAL graphify-out — move it to $GRAPHDIR once to centralize, then symlink"
else
  act ln -s "$GRAPHDIR" "$PROJ/graphify-out"
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

# --- chain signal: does this project already have code? ---
# Git presence was the wrong test on both sides: an empty initialized repo
# printed the hint, and a code-bearing directory without git printed nothing,
# even though the skill documents git as optional. Test for content instead,
# and emit a fixed token the orchestrator can branch on rather than prose.
has_content=0
for m in package.json pyproject.toml requirements.txt Cargo.toml go.mod pom.xml \
         build.gradle build.gradle.kts Gemfile composer.json Makefile CMakeLists.txt; do
  [ -e "$PROJ/$m" ] && { has_content=1; break; }
done
if [ "$has_content" = 0 ]; then
  # No manifest: fall back to counting non-hidden files in the top two levels.
  # Above three means something more than a README and a licence is here.
  n="$(find "$PROJ" -maxdepth 2 -type f -not -path '*/.*' 2>/dev/null | head -40 | wc -l | tr -d ' ')"
  [ "${n:-0}" -gt 3 ] && has_content=1
fi

if [ "$has_content" = 1 ]; then
  echo "CHAIN: /onboard-new-repo — project has existing content; run it after seeding."
else
  echo "CHAIN: none — greenfield project, nothing to onboard."
fi
