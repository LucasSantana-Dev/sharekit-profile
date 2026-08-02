#!/usr/bin/env bash
# regen-manifest.sh — recompute .harness/manifest.json sha256 fingerprints for
# every tracked file. Idempotent: no-op if nothing changed.
#
# Uses a targeted string replace (not a full JSON re-serialize) so unrelated
# formatting — notably the non-ASCII escapes in meta.adr_anchor — survives
# byte-for-byte. A jq roundtrip was tried before and mangled those escapes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/.harness/manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found at $MANIFEST" >&2
  exit 1
fi

# Fail closed on partial staging (CodeRabbit finding on PR #116): if a tracked
# file has unstaged changes on top of (or instead of) what's staged, hashing
# the working tree here while only re-staging manifest.json would record a
# fingerprint for content that never actually gets committed. Refuse and let
# the caller stage/resolve first rather than silently mismatching.
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r relpath; do
    [[ "$relpath" == ".harness/manifest.json" ]] && continue
    if ! git -C "$ROOT" diff --quiet -- "$relpath" 2>/dev/null; then
      echo "ERROR: $relpath has unstaged changes — stage or stash before regenerating the manifest (partial-stage would record a fingerprint for content that isn't actually committed)" >&2
      exit 1
    fi
  done < <(jq -r '.files | keys[]' "$MANIFEST")
fi

python3 - "$ROOT" "$MANIFEST" <<'PYEOF'
import sys, json, hashlib, re
from datetime import datetime, timezone

root, manifest_path = sys.argv[1], sys.argv[2]
raw = open(manifest_path, encoding="utf-8").read()
data = json.loads(raw)

changed = False
for relpath, recorded in data["files"].items():
    fpath = f"{root}/{relpath}"
    try:
        actual = hashlib.sha256(open(fpath, "rb").read()).hexdigest()
    except FileNotFoundError:
        print(f"ERROR: tracked file missing: {relpath}", file=sys.stderr)
        sys.exit(1)
    if actual != recorded:
        needle = f'"{relpath}": "{recorded}"'
        if needle not in raw:
            print(
                f"ERROR: could not locate fingerprint entry for {relpath} "
                "(unexpected manifest formatting — regenerate manually)",
                file=sys.stderr,
            )
            sys.exit(1)
        raw = raw.replace(needle, f'"{relpath}": "{actual}"', 1)
        print(f"updated: {relpath}")
        changed = True

if not changed:
    print("OK: manifest.json already up to date (no-op)")
    sys.exit(0)

m = re.search(r'"generated_at": "([^"]+)"', raw)
if m:
    new_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f+00:00")
    raw = raw.replace(f'"generated_at": "{m.group(1)}"', f'"generated_at": "{new_ts}"', 1)

open(manifest_path, "w", encoding="utf-8").write(raw)
print("manifest.json regenerated")
PYEOF

# Re-stage so the fix rides along with whatever commit triggered it (pre-commit
# hooks run after `git add`; without this the regenerated manifest would be
# left unstaged and silently excluded from the commit).
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT" diff --quiet -- .harness/manifest.json || git -C "$ROOT" add .harness/manifest.json
fi
