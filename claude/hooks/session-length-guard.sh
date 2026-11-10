#!/usr/bin/env bash
# session-length-guard.sh - UserPromptSubmit hook. Warns when a session got
# expensive to keep: every request re-reads the whole context, and after an
# idle gap longer than the prompt-cache TTL (1h) the next request re-WRITES it.
#
# Measured 2026-09-29: 93% of usage came from sessions active 8h+, one session
# stayed open 7 days ($335). This hook is advisory (always exit 0): it shows
# the operator a systemMessage and asks the model to offer a handoff.
#
# Per-session state (throttle) lives in ~/.claude/.session-guard/<session_id>.
# Thresholds (env overrides):
#   SESSION_GUARD_IDLE_MIN  (60)      idle minutes before the cache is cold
#   SESSION_GUARD_IDLE_CTX  (60000)   min context tokens for the idle warning
#   SESSION_GUARD_AGE_H     (8)       session age in hours
#   SESSION_GUARD_AGE_CTX   (100000)  min context tokens for the age warning
#   SESSION_GUARD_EVERY_MIN (120)     re-warn interval for the age warning
set -uo pipefail
command -v python3 >/dev/null 2>&1 || exit 0

IFS= read -r -d '' PY <<'PY' || true
import json, os, sys, time
from datetime import datetime

try:
    hook = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sid = str(hook.get("session_id") or "")
path = hook.get("transcript_path") or ""
if not sid or not path or not os.path.isfile(path):
    sys.exit(0)

env = os.environ.get
IDLE_MIN = float(env("SESSION_GUARD_IDLE_MIN", "60"))
IDLE_CTX = int(env("SESSION_GUARD_IDLE_CTX", "60000"))
AGE_H = float(env("SESSION_GUARD_AGE_H", "8"))
AGE_CTX = int(env("SESSION_GUARD_AGE_CTX", "100000"))
EVERY_MIN = float(env("SESSION_GUARD_EVERY_MIN", "120"))

def ts(entry):
    t = entry.get("timestamp")
    if not t:
        return None
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None

def entries(chunk):
    for line in chunk.splitlines():
        try:
            yield json.loads(line)
        except ValueError:
            continue

first = None
with open(path, "rb") as f:
    for e in entries(f.read(65536).decode("utf-8", "replace")):
        first = ts(e)
        if first:
            break
    f.seek(0, 2)
    size = f.tell()
    f.seek(max(0, size - 524288))
    tail = f.read().decode("utf-8", "replace")

last, ctx = None, 0
for e in entries(tail):
    t = ts(e)
    if t and e.get("type") in ("user", "assistant"):
        last = t
    u = (e.get("message") or {}).get("usage") if e.get("type") == "assistant" else None
    if u:
        ctx = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
               + u.get("cache_creation_input_tokens", 0))
if not first or not last or not ctx:
    sys.exit(0)

now = time.time()
idle_min = (now - last) / 60
age_h = (now - first) / 3600
k = ctx // 1000

state_dir = os.path.expanduser("~/.claude/.session-guard")
os.makedirs(state_dir, exist_ok=True)
for name in os.listdir(state_dir):
    p = os.path.join(state_dir, name)
    try:
        if now - os.path.getmtime(p) > 7 * 86400:
            os.remove(p)
    except OSError:
        pass
state = os.path.join(state_dir, "".join(c for c in sid if c.isalnum() or c in "-_"))
try:
    last_warn = float(open(state).read().strip() or 0)
except (OSError, ValueError):
    last_warn = 0.0

msg = None
if idle_min >= IDLE_MIN and ctx >= IDLE_CTX:
    msg = (f"Sessão parada há {idle_min / 60:.1f}h com {k}k de contexto: o cache expirou "
           f"e esta resposta reescreve os {k}k inteiros. Mais barato: handoff + sessão nova.")
elif age_h >= AGE_H and ctx >= AGE_CTX and (now - last_warn) / 60 >= EVERY_MIN:
    msg = (f"Sessão aberta há {age_h:.0f}h com {k}k de contexto: cada turno relê tudo. "
           f"Mais barato: handoff + sessão nova.")
if not msg:
    sys.exit(0)
try:
    with open(state, "w") as fh:
        fh.write(str(now))
except OSError:
    pass
print(json.dumps({
    "systemMessage": "⏱ " + msg,
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": (
            "SESSION-LENGTH-GUARD: " + msg + " Atenda o pedido normalmente; se ele "
            "abre trabalho novo, ofereça em uma linha escrever o handoff e seguir em "
            "sessão nova. Não repita o aviso."),
    },
}, ensure_ascii=False))
PY
python3 -c "$PY"
exit 0
