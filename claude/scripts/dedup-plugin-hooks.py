"""Drop from a plugin hooks.json every hook script also registered in ~/.claude/settings.json."""
import json
import sys
from pathlib import Path


def script(cmd):
    tok = cmd.replace("\\", "/").split("/")[-1].split()
    return tok[0].strip('"') if tok else ""


def names(hooks):
    return {script(x.get("command", "")) for a in hooks.values() for m in a for x in m["hooks"]}


plugin = Path(sys.argv[1])
data = json.loads(plugin.read_text(encoding="utf-8"))
hooks = data.get("hooks", data)
local = json.loads((Path.home() / ".claude" / "settings.json").read_text(encoding="utf-8"))["hooks"]
dup = names(local)
removed = []
for ev in list(hooks):
    for m in hooks[ev]:
        keep = []
        for x in m["hooks"]:
            n = script(x.get("command", ""))
            if n in dup:
                removed.append(f"{ev}:{n}")
            else:
                keep.append(x)
        m["hooks"] = keep
    hooks[ev] = [m for m in hooks[ev] if m["hooks"]]
    if not hooks[ev]:
        del hooks[ev]
plugin.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print("removidos:", removed)
print("ficam:", sorted(names(hooks)))
