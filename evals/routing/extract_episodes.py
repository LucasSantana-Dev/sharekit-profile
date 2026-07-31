#!/usr/bin/env python3
"""extract_episodes.py — mine skill-routing episodes from agent session JSONLs.

An episode = (user prompt, skill the agent invoked). Ground truth for the routing
eval gate. Explicit slash-invocations (/skillname) carry no routing signal and are
tagged explicit=True so the dataset builder can drop them.

Session logs come from CLAUDE_PROJECTS_DIR (default ~/.claude/projects) — point
this at YOUR OWN harness's session logs to generate team-local ground truth.
Never commit the raw output: episodes.jsonl contains real prompts. Only the
human-verified, sanitized routing_v*.jsonl distillate is publishable.

Output: dataset/episodes.jsonl, one {"prompt", "skill", "args", "explicit", "ts",
"session"} per line.
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys

PROJECTS = os.environ.get("CLAUDE_PROJECTS_DIR",
                          os.path.expanduser("~/.claude/projects"))
OUT = os.path.join(os.path.dirname(__file__), "dataset", "episodes.jsonl")

_SLASH_RX = re.compile(r"^/([a-z][\w-]*)")
_CMD_RX = re.compile(r"<command-name>/([a-z][\w:-]*)</command-name>")
_META_RX = re.compile(r"^<(system-reminder|command-name|command-message|local-command|task-notification)")
# Skill bodies get injected as user messages when a skill loads — they are not
# prompts and must not become routing ground truth for the NEXT skill call.
_SKILL_BODY_MARKERS = (
    "Base directory for this skill:",
    "<kimi-skill-loaded",
    "Follow the loaded skill instructions",
    "kimi-skill-loaded",
)


def user_text(d: dict) -> str | None:
    """Extract real user prompt text; None for tool results / meta lines."""
    if d.get("type") != "user":
        return None
    msg = d.get("message") or {}
    content = msg.get("content")
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        parts = [c.get("text", "") for c in content
                 if isinstance(c, dict) and c.get("type") == "text"]
        text = "\n".join(parts)
    else:
        return None
    text = text.strip()
    if not text or _META_RX.match(text):
        return None
    if len(text) < 20:
        return None
    if any(m in text for m in _SKILL_BODY_MARKERS):
        return None
    # Tool results arrive as user messages with content list of tool_result blocks.
    if isinstance(content, list) and any(
        isinstance(c, dict) and c.get("type") == "tool_result" for c in content
    ):
        return None
    return text


def extract_file(path: str) -> list[dict]:
    episodes: list[dict] = []
    last_prompt: str | None = None
    last_ts: str | None = None
    for line in open(path, errors="replace"):
        if '"Skill"' not in line and '"user"' not in line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        t = d.get("type")
        if t == "user":
            text = user_text(d)
            if text:
                last_prompt = text
                last_ts = d.get("timestamp")
        elif t == "assistant":
            for c in (d.get("message") or {}).get("content", []):
                if not (isinstance(c, dict) and c.get("type") == "tool_use"
                        and c.get("name") == "Skill"):
                    continue
                if not last_prompt:
                    continue
                inp = c.get("input") or {}
                skill = inp.get("skill")
                if not skill:
                    continue
                m = _SLASH_RX.match(last_prompt)
                cmd = _CMD_RX.search(last_prompt)
                inline = re.search(r"(?<![\w-])/" + re.escape(skill) + r"(?![\w-])",
                                   last_prompt)
                explicit = bool((m and m.group(1) == skill)
                                or (cmd and cmd.group(1).split(":")[-1] == skill)
                                or inline)
                episodes.append({
                    "prompt": last_prompt[:1000],
                    "skill": skill,
                    "args": (inp.get("args") or "")[:300],
                    "explicit": explicit,
                    "ts": last_ts,
                    "session": os.path.basename(path),
                })
                # One prompt grounds ONE skill call. Composite children invoked
                # after the first call are the parent's routing, not the user's.
                last_prompt = None
                break
    return episodes


def main() -> int:
    files = sorted(glob.glob(os.path.join(PROJECTS, "*", "*.jsonl")),
                   key=os.path.getmtime)
    all_eps: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for path in files:
        for ep in extract_file(path):
            key = (ep["prompt"][:200].lower().strip(), ep["skill"])
            if key in seen:
                continue
            seen.add(key)
            all_eps.append(ep)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        for ep in all_eps:
            f.write(json.dumps(ep, ensure_ascii=False) + "\n")
    auto = sum(1 for e in all_eps if not e["explicit"])
    explicit = len(all_eps) - auto
    print(f"{len(all_eps)} episodes ({auto} auto-routed, {explicit} explicit) "
          f"from {len(files)} session files -> {OUT}")
    print("REMINDER: episodes.jsonl contains real prompts — do not commit it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
