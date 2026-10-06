#!/bin/bash
# Detect whether the active cwd belongs to a client vault (client purge, ADR 2026-09-24).
# Source of truth: ~/.claude/rag-index/clients.json ({"<id>": {"roots": [...]}}, outside git).
# stdout: "general" or "client:<id>". Exit 0 always; unreadable registry => "general" + warning on stderr.
# The client's memory dir is the project memory dir, usually a symlink into the client repo
# (e.g. rcc-brain/memoria-operador). Both are resolved with `pwd -P` so symlinks match.
python3 - "${1:-$PWD}" <<'PY'
import json, os, sys
reg = os.path.expanduser("~/.claude/rag-index/clients.json")
try:
    clients = json.load(open(reg))
except Exception as e:
    print("general"); sys.stderr.write(f"warn: clients.json unreadable ({e}); treating as general\n"); sys.exit(0)
cwd = os.path.realpath(sys.argv[1])
for cid, cfg in clients.items():
    for r in cfg.get("roots", []):
        for cand in {r, os.path.realpath(r)}:
            if cwd == cand or cwd.startswith(cand.rstrip("/") + "/"):
                print(f"client:{cid}"); sys.exit(0)
print("general")
PY
