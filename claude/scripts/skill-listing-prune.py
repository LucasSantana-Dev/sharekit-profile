"""Hide never-used skills from the model's skill listing (reversible).

Adds `disable-model-invocation: true` to the frontmatter of skills that:
  - never ran in the transcripts (skill-usage.py --json output),
  - were not modified in the last 14 days,
  - are not named by any used skill, CLAUDE.md, CLAUDE.local.md or rules/*.md
    (a composite calling a sub-skill through the Skill tool needs it visible).
The skill still works as /name. Writes the changed list to
~/.claude/backups/skill-listing-prune-<date>.txt; --revert <file> undoes it.

Usage:
  python skill-listing-prune.py <usage.json> [--apply]
  python skill-listing-prune.py --revert <list.txt>
Stdlib only.
"""
import json
import re
import sys
import time
from pathlib import Path

HOME = Path.home() / ".claude"
SK = HOME / "skills"
FLAG = "disable-model-invocation: true"


def split_fm(text):
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end < 0:
        return None, text
    return text[: end + 4], text[end + 4 :]


if "--revert" in sys.argv:
    lst = Path(sys.argv[sys.argv.index("--revert") + 1]).read_text(encoding="utf-8").split()
    for name in lst:
        p = SK / name / "SKILL.md"
        t = p.read_text(encoding="utf-8")
        p.write_text(t.replace(FLAG + "\n", "", 1), encoding="utf-8", newline="")
    print(f"reverted {len(lst)}")
    sys.exit(0)

usage = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
used = {k for k, v in usage["used"].items() if v}
never = usage["never"]

refs = ""
for name in used:
    p = SK / name / "SKILL.md"
    if p.exists():
        refs += p.read_text(encoding="utf-8", errors="replace")
for extra in [HOME / "CLAUDE.md", HOME / "CLAUDE.local.md", *(HOME / "rules").glob("*.md")]:
    if extra.exists():
        refs += extra.read_text(encoding="utf-8", errors="replace")

recent = time.time() - 14 * 86400
todo, skipped = [], {"already": 0, "recent": 0, "referenced": 0, "no_frontmatter": 0}
for name in never:
    p = SK / name / "SKILL.md"
    t = p.read_text(encoding="utf-8", errors="replace")
    fm, _ = split_fm(t)
    if fm is None:
        skipped["no_frontmatter"] += 1
        continue
    if re.search(r"^disable-model-invocation:\s*true", fm, re.M):
        skipped["already"] += 1
        continue
    if max(f.stat().st_mtime for f in p.parent.rglob("*") if f.is_file()) > recent:
        skipped["recent"] += 1
        continue
    if re.search(r"(?<![\w-])/?" + re.escape(name) + r"(?![\w-])", refs):
        skipped["referenced"] += 1
        continue
    todo.append(name)

print(f"never used: {len(never)}  to hide: {len(todo)}  skipped: {skipped}")
if "--apply" not in sys.argv:
    sys.exit(0)

for name in todo:
    p = SK / name / "SKILL.md"
    t = p.read_text(encoding="utf-8", errors="replace")
    fm, body = split_fm(t)
    p.write_text(fm[:-4] + "\n" + FLAG + fm[-4:] + body if not fm[:-4].endswith("\n") else fm[:-3] + FLAG + "\n---" + body, encoding="utf-8", newline="")
out = HOME / "backups" / f"skill-listing-prune-{time.strftime('%Y%m%d-%H%M%S')}.txt"
out.parent.mkdir(exist_ok=True)
out.write_text("\n".join(todo) + "\n", encoding="utf-8")
print(f"hidden {len(todo)}; revert with: python {Path(__file__).as_posix()} --revert {out.as_posix()}")
