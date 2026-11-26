"""Hide plugin skills that have a same-named local skill in ~/.claude/skills.

Adds `disable-model-invocation: true` to the plugin copy, so the model's skill
listing carries one entry per skill (the local one). Plugin updates restore the
original files: run this again after `claude plugin update`.

Usage: python dedup-plugin-skills.py <plugin installPath>
Stdlib only.
"""
import sys
from pathlib import Path

FLAG = "disable-model-invocation: true"
local = Path.home() / ".claude" / "skills"
base = Path(sys.argv[1]) / "skills"
hidden = []
for skill in sorted(base.glob("*/SKILL.md")):
    name = skill.parent.name
    if not (local / name / "SKILL.md").exists():
        continue
    t = skill.read_text(encoding="utf-8", errors="replace")
    if not t.startswith("---"):
        continue
    end = t.find("\n---", 3)
    if end < 0 or FLAG in t[:end]:
        continue
    skill.write_text(t[:end] + "\n" + FLAG + t[end:], encoding="utf-8", newline="")
    hidden.append(name)
print(f"hidden {len(hidden)} plugin duplicates: {', '.join(hidden)}")
