#!/bin/bash
# Push to knowledge-brain after memory or graph change (phase5-routing.md)
#
# Usage: push-protocol.sh [project-memory-dir] [project-name]
#   With no args, the memory dir is derived from the current directory the same
#   way Claude Code names it (~/.claude/projects/<cwd with : \ / . as ->/memory)
#   and the project name is the cwd basename.
#
# Why the copy step: the brain only receives what is already inside
# $BRAIN/memory. Per-project memory lives in ~/.claude/projects/<slug>/memory,
# and nothing copied it over, so a session that only wrote project memory got
# "nothing to push" while its notes stayed on this machine (seen 2026-11-09).
# Earlier projects had been copied by hand.

set -e  # fail loud

# An unset env var is not an unmounted disk; the reachability test is the guard.
DEV_ROOT="${DEV_ROOT:-$HOME/dev}"
BRAIN="${DEV_ROOT}/knowledge-brain"

# Mount guard (standards/knowledge-brain.md §1): fail loud, never silent.
if [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: knowledge-brain unreachable at $BRAIN. Skip push." >&2
  exit 1
fi

# --- Copy this project's memory into the brain -------------------------------
if [ -n "$1" ]; then
  PROJ_MEM="$1"
else
  cwd_win="$(pwd -W 2>/dev/null || pwd)"
  slug="$(printf '%s' "$cwd_win" | sed 's#[:\\/.]#-#g')"
  PROJ_MEM="$HOME/.claude/projects/$slug/memory"
fi
PROJ_NAME="${2:-$(basename "$(pwd)")}"
INDEX="$BRAIN/memory/INDEX_${PROJ_NAME}.md"

if [ -d "$PROJ_MEM" ] && [ -d "$BRAIN/memory" ]; then
  copiados=0
  for f in "$PROJ_MEM"/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    [ "$n" = "MEMORY.md" ] && continue
    alvo="$BRAIN/memory/$n"
    if [ -e "$alvo" ] && ! cmp -s "$f" "$alvo"; then
      # Same name, different content: only overwrite our own earlier copy,
      # never another project's note that happens to share the file name.
      if ! { [ -e "$INDEX" ] && grep -q "($n)" "$INDEX"; }; then
        echo "BLOCKED: $n already exists in the brain from another source; rename it in $PROJ_MEM. Nothing was pushed." >&2
        exit 1
      fi
    fi
    cmp -s "$f" "$alvo" 2>/dev/null || { cp "$f" "$alvo"; copiados=$((copiados + 1)); }
  done
  # The project index becomes INDEX_<project>.md, the brain's convention.
  if [ -e "$PROJ_MEM/MEMORY.md" ]; then
    { printf '# %s\n\nCopied from the project memory index by push-protocol.sh.\n\n' "$PROJ_NAME"
      cat "$PROJ_MEM/MEMORY.md"; } > "$INDEX.tmp"
    if cmp -s "$INDEX.tmp" "$INDEX" 2>/dev/null; then rm "$INDEX.tmp"; else mv "$INDEX.tmp" "$INDEX"; fi
    # Link the index from the brain's root index once.
    if [ -e "$BRAIN/memory/MEMORY.md" ] && ! grep -q "(INDEX_${PROJ_NAME}.md)" "$BRAIN/memory/MEMORY.md"; then
      printf -- '- [%s: índice](INDEX_%s.md) · memórias do projeto, copiadas pelo push-protocol\n' \
        "$PROJ_NAME" "$PROJ_NAME" >> "$BRAIN/memory/MEMORY.md"
    fi
  fi
  echo "knowledge-brain: $copiados nota(s) de $PROJ_NAME copiada(s)"
else
  echo "knowledge-brain: sem memória de projeto em $PROJ_MEM, só o que já está no brain"
fi

# --- Stage, commit, push -------------------------------------------------------
# Stage one pathspec at a time, and only the ones that exist: `git add memory/
# graphs/` is all-or-nothing and, with stderr hidden, looked like "nothing to
# push" (measured 2026-09-16). Never swallow git's stderr here.
staged_algo=0
for alvo in memory graphs; do
  [ -e "$BRAIN/$alvo" ] || continue
  git -C "$BRAIN" add "$alvo" || {
    echo "BLOCKED: git add falhou em $alvo, nada foi enviado." >&2
    exit 1
  }
  staged_algo=1
done

if [ "$staged_algo" -eq 0 ]; then
  echo "BLOCKED: nem memory/ nem graphs/ existem em $BRAIN, nada a enviar." >&2
  exit 1
fi

if git -C "$BRAIN" diff --cached --quiet; then
  echo "knowledge-brain: nothing to push"
else
  n=$(git -C "$BRAIN" diff --cached --name-only | wc -l | tr -d ' ')
  git -C "$BRAIN" commit -q -m "chore: knowledge-brain sync from ${PROJ_NAME} session"
  git -C "$BRAIN" push -q
  echo "knowledge-brain pushed: $n arquivo(s), commit $(git -C "$BRAIN" rev-parse --short HEAD)"
fi
