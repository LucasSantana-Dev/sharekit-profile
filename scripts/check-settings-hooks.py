#!/usr/bin/env python3
"""Gate for claude/settings.json (stdlib only).

1. Every $HOME/.claude/hooks/<x> referenced by a hook command must exist in
   claude/hooks/ and be listed in curated-hooks.txt (otherwise installers get
   a hook that points at a missing file).
2. Every "timeout" must be a positive integer number of seconds (Claude Code
   reads seconds; a value like 5000 means 83 minutes).
3. Registered bash hooks must not use constructs missing from macOS
   /bin/bash 3.2: mapfile, readarray, declare -A, ${v,,}, ${v^^}.
   Comment lines are ignored.

Usage: check-settings-hooks.py [ROOT]
"""
import json
import os
import re
import sys

root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
settings = os.path.join(root, "claude", "settings.json")
hooks_dir = os.path.join(root, "claude", "hooks")

errors = []
try:
    with open(settings) as fh:
        cfg = json.load(fh)
except Exception as exc:
    print("FAIL: cannot parse %s: %s" % (settings, exc))
    sys.exit(1)

try:
    with open(os.path.join(root, "curated-hooks.txt")) as fh:
        curated = {ln.strip() for ln in fh if ln.strip() and not ln.lstrip().startswith("#")}
except OSError:
    curated = set()

REF = re.compile(r"\$(?:\{HOME\}|HOME)/\.claude/hooks/([A-Za-z0-9._-]+)")
BASH3 = [
    (re.compile(r"\b(mapfile|readarray)\b"), "mapfile/readarray"),
    (re.compile(r"\bdeclare\s+-A\b"), "declare -A"),
    (re.compile(r"\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\}"), "${var,,} / ${var^^}"),
]

registered = set()
for event, groups in (cfg.get("hooks") or {}).items():
    for group in groups:
        for hook in group.get("hooks", []):
            t = hook.get("timeout")
            if t is not None and (not isinstance(t, int) or isinstance(t, bool) or t <= 0 or t > 600):
                errors.append("%s: timeout %r is not a sane number of seconds (1..600)" % (event, t))
            for name in REF.findall(hook.get("command", "")):
                registered.add(name)

for name in sorted(registered):
    if not os.path.isfile(os.path.join(hooks_dir, name)):
        errors.append("settings.json registers %s but claude/hooks/%s does not exist" % (name, name))
    if name not in curated:
        errors.append("settings.json registers %s but curated-hooks.txt does not list it" % name)
    path = os.path.join(hooks_dir, name)
    if os.path.isfile(path) and name.endswith(".sh"):
        with open(path, errors="replace") as fh:
            for no, line in enumerate(fh, 1):
                if line.lstrip().startswith("#"):
                    continue
                for rx, label in BASH3:
                    if rx.search(line):
                        errors.append("%s:%d uses %s (not in macOS /bin/bash 3.2)" % (name, no, label))

if errors:
    for e in errors:
        print("FAIL: " + e)
    sys.exit(1)
print("settings hooks ok: %d registered scripts verified" % len(registered))
