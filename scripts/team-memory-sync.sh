#!/usr/bin/env bash
# team-memory-sync.sh — git-backed shared memory vault for the team scope.
#
# Implements the team tier of .harness/memory-scopes.json: a dedicated vault
# git repo shared by the team; this script clones/updates it locally and
# moves notes in both directions. Promotion into the vault goes through the
# memory-promote skill (strip + proposal + review) — this script is the
# transport, and refuses to push <private>-tagged content as a second line
# of defense (hooks/memory-scope-gate.sh is the first).
#
# Config: .harness/team-vault.json in the consuming repo:
#   {"repo": "git@github.com:org/team-memory-vault.git",
#    "dir":  ".agents/memory/.vault",      # local checkout (gitignore it)
#    "branch": "main",
#    "notes_subdir": "notes"}               # subdir inside the vault repo
#
# Usage:
#   team-memory-sync.sh pull             # clone/update vault -> .agents/memory/team/
#   team-memory-sync.sh push <note.md>   # copy note into vault, commit, push
#   team-memory-sync.sh status
#
# Idempotent; fail-closed with clear errors. Never rewrites vault history
# (plain merge pull, no rebase, no force).

set -euo pipefail

usage() { grep '^#' "$0" | head -20; exit 2; }
[ $# -ge 1 ] || usage
CMD="$1"; shift || true

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "team-memory-sync: not a git repo" >&2; exit 2; }
CONF="$ROOT/.harness/team-vault.json"
[ -f "$CONF" ] || { echo "team-memory-sync: no .harness/team-vault.json - declare the vault repo first" >&2; exit 2; }

VAULT_REPO="$(jq -r '.repo // empty' "$CONF")"
VAULT_DIR="$ROOT/$(jq -r '.dir // ".agents/memory/.vault"' "$CONF")"
BRANCH="$(jq -r '.branch // "main"' "$CONF")"
SUBDIR="$(jq -r '.notes_subdir // "notes"' "$CONF")"
TEAM_DIR="$ROOT/.agents/memory/team"
[ -z "$VAULT_REPO" ] && { echo "team-memory-sync: .repo missing in $CONF" >&2; exit 2; }

ensure_clone() {
  if [ ! -d "$VAULT_DIR/.git" ]; then
    mkdir -p "$(dirname "$VAULT_DIR")"
    git clone --quiet --branch "$BRANCH" "$VAULT_REPO" "$VAULT_DIR"
    echo "team-memory-sync: cloned vault -> $VAULT_DIR"
  fi
}

case "$CMD" in
  pull)
    ensure_clone
    git -C "$VAULT_DIR" fetch --quiet origin
    git -C "$VAULT_DIR" merge --quiet --no-edit "origin/$BRANCH" || {
      echo "team-memory-sync: vault merge conflict - resolve in $VAULT_DIR then re-run pull" >&2
      exit 1
    }
    mkdir -p "$TEAM_DIR"
    if [ -d "$VAULT_DIR/$SUBDIR" ]; then
      cp -n "$VAULT_DIR/$SUBDIR"/*.md "$TEAM_DIR/" 2>/dev/null || true
    fi
    echo "team-memory-sync: pulled $(ls "$TEAM_DIR" 2>/dev/null | wc -l | tr -d ' ') team notes -> $TEAM_DIR"
    ;;
  push)
    [ $# -eq 1 ] && [ -f "$1" ] || { echo "usage: team-memory-sync.sh push <note.md>" >&2; exit 2; }
    NOTE="$1"
    # Second line of defense: private-tagged content never enters the vault.
    if grep -qi '<private>' "$NOTE"; then
      echo "team-memory-sync: BLOCK - <private>-tagged content never promotes (memory-scopes invariant)" >&2
      exit 1
    fi
    ensure_clone
    git -C "$VAULT_DIR" pull --quiet --no-edit
    mkdir -p "$VAULT_DIR/$SUBDIR"
    dest="$VAULT_DIR/$SUBDIR/$(basename "$NOTE")"
    if [ -f "$dest" ] && cmp -s "$NOTE" "$dest"; then
      echo "team-memory-sync: already done - skipping (identical note in vault)"
      exit 0
    fi
    cp "$NOTE" "$dest"
    git -C "$VAULT_DIR" add "$SUBDIR/$(basename "$NOTE")"
    git -C "$VAULT_DIR" commit --quiet -m "memory: promote $(basename "$NOTE" .md) (${HARNESS_AUTHOR:-$(git config user.email)})"
    git -C "$VAULT_DIR" push --quiet origin "$BRANCH"
    echo "team-memory-sync: pushed $(basename "$NOTE") -> vault $BRANCH"
    ;;
  status)
    if [ -d "$VAULT_DIR/.git" ]; then
      git -C "$VAULT_DIR" log --oneline -3
      git -C "$VAULT_DIR" status --short
    else
      echo "team-memory-sync: vault not cloned yet (run: pull)"
    fi
    ;;
  *) usage ;;
esac
