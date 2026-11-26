"""Count real Skill invocations across Claude Code transcripts.

Reads every ~/.claude/projects/**/*.jsonl, finds assistant tool_use blocks named
"Skill" plus user slash commands (<command-name>/x</command-name>), and compares
against the skills installed in ~/.claude/skills.

Usage: python ~/.claude/scripts/skill-usage.py [--days N] [--json out.json]
Stdlib only.
"""
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path

HOME = Path.home() / ".claude"
days = None
if "--days" in sys.argv:
    days = int(sys.argv[sys.argv.index("--days") + 1])
cutoff = time.time() - days * 86400 if days else 0

model_calls = Counter()
user_calls = Counter()
CMD = re.compile(r"<command-name>/?([\w:.-]+)</command-name>")

for f in (HOME / "projects").rglob("*.jsonl"):
    try:
        if f.stat().st_mtime < cutoff:
            continue
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        continue
    for line in lines:
        if '"Skill"' not in line and "command-name" not in line:
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        msg = ev.get("message") or {}
        content = msg.get("content")
        if isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Skill":
                    s = (b.get("input") or {}).get("skill", "")
                    if s:
                        model_calls[s] += 1
        text = content if isinstance(content, str) else json.dumps(content) if content else ""
        if ev.get("type") == "user":
            for m in CMD.findall(text):
                user_calls[m] += 1


def base(name):
    return name.split(":", 1)[-1]


installed = sorted(p.parent.name for p in (HOME / "skills").glob("*/SKILL.md"))
used = Counter()
for k, v in (model_calls + user_calls).items():
    used[base(k)] += v
never = [s for s in installed if used.get(s, 0) == 0]

print(f"transcripts window: {'all' if not days else f'{days} days'}")
print(f"installed skills: {len(installed)}  used at least once: {len(installed) - len(never)}  never: {len(never)}")
print("top 15:", ", ".join(f"{k}={v}" for k, v in used.most_common(15)))
if "--json" in sys.argv:
    out = Path(sys.argv[sys.argv.index("--json") + 1])
    out.write_text(json.dumps({"used": used, "never": never, "installed": installed}, indent=1), encoding="utf-8")
    print(f"written {out}")
