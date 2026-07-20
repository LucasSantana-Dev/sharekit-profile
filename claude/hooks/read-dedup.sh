#!/usr/bin/env bash
# PostToolUse hook: deduplicate repeat Reads of UNCHANGED files within a
# compaction window. The #1 uncompressed token surface is the native Read tool
# (31.5MB measured), and ~30% of it is the same file re-read unchanged — content
# that is provably still in live context (state is cleared on PostCompact by
# post-compact-reset.sh, so a hit means no compaction has dropped it).
#
# Two modes via CLAUDE_READ_DEDUP:
#   off       → disabled entirely (kill switch)
#   measure   → DEFAULT. Detect + log would-be savings to ~/.claude/read-dedup.log.
#               Replaces NOTHING — zero correctness risk. Prototype/verify phase.
#   active    → replace duplicate-unchanged Read output with a loud pointer stub
#               via hookSpecificOutput.updatedToolOutput.
#
# Fail-safe: on ANY uncertainty (unparseable payload, missing file, small read,
# changed mtime/size) the hook passes through unchanged. It NEVER blocks a Read
# and never replaces unless every condition is unambiguously met.
set -uo pipefail
command -v python3 &>/dev/null || exit 0

MODE="${CLAUDE_READ_DEDUP:-measure}"
[[ "$MODE" == "off" ]] && exit 0

_HOOK_INPUT=$(cat 2>/dev/null || true)
[[ -z "$_HOOK_INPUT" ]] && exit 0
export _HOOK_INPUT _HOOK_MODE="$MODE"

python3 <<'PYEOF' 2>/dev/null || exit 0
import json, os, hashlib, time

mode = os.environ.get("_HOOK_MODE", "measure")
raw = os.environ.get("_HOOK_INPUT", "")
try:
    d = json.loads(raw)
except Exception:
    raise SystemExit(0)

if d.get("tool_name") != "Read":
    raise SystemExit(0)

sid = d.get("session_id") or d.get("sessionId") or ""
if not sid:
    raise SystemExit(0)

ti = d.get("tool_input") or {}
path = ti.get("file_path") or ""
if not path or not os.path.isabs(path):
    raise SystemExit(0)
offset = ti.get("offset", 0)
limit = ti.get("limit", "all")

# Measure the current output size (serialize whatever shape tool_response is).
resp = d.get("tool_response")
if resp is None:
    raise SystemExit(0)
out_text = resp if isinstance(resp, str) else json.dumps(resp, ensure_ascii=False)
out_bytes = len(out_text)

MIN_BYTES = 2000  # only dedup reads carrying ~500+ tokens

# Current on-disk identity. If we cannot stat, do not dedup (fail safe).
try:
    st = os.stat(path)
    ident = f"{int(st.st_mtime)}:{st.st_size}"
except OSError:
    raise SystemExit(0)

key = hashlib.sha1(f"{path}::{offset}::{limit}".encode()).hexdigest()[:16]
state = f"/tmp/claude-read-dedup-{sid}.json"
try:
    db = json.load(open(state)) if os.path.exists(state) else {}
except Exception:
    db = {}

prev = db.get(key)
is_dup_unchanged = (
    prev is not None
    and prev.get("ident") == ident
    and out_bytes >= MIN_BYTES
)

db[key] = {"ident": ident, "bytes": out_bytes,
           "n": (prev.get("n", 1) + 1) if prev else 1,
           "path": path}
try:
    json.dump(db, open(state, "w"))
except Exception:
    pass

if not is_dup_unchanged:
    raise SystemExit(0)

n = db[key]["n"]
log = os.path.expanduser("~/.claude/read-dedup.log")
try:
    with open(log, "a") as f:
        f.write(json.dumps({
            "ts": int(time.time()), "mode": mode, "file": path,
            "range": f"{offset}:{limit}", "n": n,
            "saveable_bytes": out_bytes,
        }) + "\n")
except Exception:
    pass

if mode != "active":
    raise SystemExit(0)  # measure-only: detected + logged, replaced nothing.

short = os.path.basename(path)
stub = (f"[read-dedup] {short} (range {offset}:{limit}) is UNCHANGED since you "
        f"read it earlier in this context window (read #{n}) — its full content "
        f"is already above. Skipped re-sending {out_bytes} bytes. If you no "
        f"longer have it (state resets on compaction, so you should), edit the "
        f"file or set CLAUDE_READ_DEDUP=off to force a fresh read.")
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "updatedToolOutput": stub,
    }
}))
PYEOF
exit 0
