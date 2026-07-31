#!/usr/bin/env python3
"""router_eval.py — replay routing tasks through a pinned model and gate the result.

Simulates the harness's skill-routing surface: the model sees the skill listing
(name + description, exactly as parsed from SKILL.md files) plus a user prompt,
and must answer with one skill name or "none". Regression gate: aggregate
accuracy must not drop more than GATE_TOLERANCE below the baseline.

Skill listing source (in priority order):
  1. --skills-dir PATH (repeatable)
  2. SKILLS_DIRS env (os.pathsep-separated)
  3. repo-relative default: <repo>/claude/skills and <repo>/skills

Usage:
  python3 router_eval.py                 # run + gate against baseline
  python3 router_eval.py --set-baseline  # run + store as the new baseline
  python3 router_eval.py --validate-only # offline: schema/baseline checks only
  ROUTER_EVAL_MODEL=moonshotai/kimi-k2.6 python3 router_eval.py

OPENROUTER_BASE_URL overrides the API base (used by tests with a mock server).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATASET_GLOB = os.path.join(HERE, "dataset", "routing_*.jsonl")
BASELINE = os.path.join(HERE, "baseline", "routing_baseline.json")
DEFAULT_SKILLS_DIRS = [
    os.path.join(REPO_ROOT, "claude", "skills"),
    os.path.join(REPO_ROOT, "skills"),
]
MODEL = os.environ.get("ROUTER_EVAL_MODEL", "moonshotai/kimi-k2.6")
BASE_URL = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
GATE_TOLERANCE = 0.05  # allowed accuracy drop vs baseline

_FM_RX = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)


def resolve_skills_dirs(cli_dirs: list[str]) -> list[str]:
    if cli_dirs:
        return cli_dirs
    env = os.environ.get("SKILLS_DIRS")
    if env:
        return [d for d in env.split(os.pathsep) if d]
    return [d for d in DEFAULT_SKILLS_DIRS if os.path.isdir(d)]


def load_skill_listing(skills_dirs: list[str]) -> list[tuple[str, str]]:
    """(name, description) from every SKILL.md, deduped by name."""
    listing: dict[str, str] = {}
    for root in skills_dirs:
        for path in sorted(glob.glob(os.path.join(root, "**", "SKILL.md"),
                                     recursive=True)):
            try:
                text = open(path, errors="replace").read()
            except OSError:
                continue
            m = _FM_RX.match(text)
            if not m:
                continue
            name = re.search(r"^name:\s*(.+)$", m.group(1), re.M)
            desc = re.search(r"^description:\s*(.+)$", m.group(1), re.M)
            if not name:
                continue
            n = name.group(1).strip()
            d = (desc.group(1).strip() if desc else "")[:200]
            listing.setdefault(n, d)
        # Flat single-file skills (*.md at root, not SKILL.md)
        for path in sorted(glob.glob(os.path.join(root, "*.md"))):
            n = os.path.splitext(os.path.basename(path))[0]
            if n not in listing and not n.startswith(("README", "CATALOG")):
                listing.setdefault(n, "")
    return sorted(listing.items())


def load_tasks() -> list[dict]:
    tasks: list[dict] = []
    seen: set[str] = set()
    for path in sorted(glob.glob(DATASET_GLOB)):
        for line in open(path):
            d = json.loads(line)
            if d["id"] in seen:
                continue
            seen.add(d["id"])
            tasks.append(d)
    return tasks


def validate(tasks: list[dict], listing: list[tuple[str, str]]) -> list[str]:
    """Offline schema checks; returns a list of problems (empty = OK)."""
    problems: list[str] = []
    ids: set[str] = set()
    for t in tasks:
        for field in ("id", "prompt", "expected"):
            if field not in t:
                problems.append(f"task missing '{field}': {t!r:.80}")
                break
        else:
            if t["id"] in ids:
                problems.append(f"duplicate task id: {t['id']}")
            ids.add(t["id"])
            if not isinstance(t["prompt"], str) or not t["prompt"].strip():
                problems.append(f"empty prompt: {t['id']}")
            if not isinstance(t["expected"], str) or not t["expected"].strip():
                problems.append(f"empty expected: {t['id']}")
    if not tasks:
        problems.append(f"no tasks matched {DATASET_GLOB}")
    if not listing:
        problems.append("skill listing is empty (check --skills-dir/SKILLS_DIRS)")
    if not os.path.exists(BASELINE):
        problems.append(f"no baseline at {BASELINE}")
    return problems


def build_router_prompt(listing: list[tuple[str, str]], prompt: str) -> str:
    skills = "\n".join(f"- {n}: {d}" for n, d in listing)
    return (
        "You are the skill router of an AI agent harness. Given the available "
        "skills and a user request, answer with EXACTLY ONE skill name that "
        "should handle the request, or exactly 'none' if no skill applies "
        "(simple edits, plain questions, direct commands need no skill).\n\n"
        f"Available skills:\n{skills}\n\n"
        f"User request:\n{prompt}\n\n"
        "Answer with only the skill name or 'none'. No explanation."
    )


def call_model(prompt: str, api_key: str) -> str:
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        # Reasoning models burn output tokens on thinking; disable it (gate
        # needs the verdict only) and keep headroom for models that ignore
        # the switch.
        "reasoning": {"enabled": False},
        "max_tokens": 1024,
    }).encode()
    last_err: Exception | None = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(
                BASE_URL.rstrip("/") + "/chat/completions",
                data=body,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
            )
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.loads(resp.read())
            msg = data["choices"][0]["message"]
            content = msg.get("content") or ""
            if not content.strip():
                raise ValueError("empty content (reasoning consumed budget?)")
            return content.strip()
        except Exception as e:
            last_err = e
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
    raise last_err or RuntimeError("call failed")


def normalize(answer: str) -> str:
    a = answer.strip().strip("`'\".").split()[0] if answer.strip() else ""
    return a.strip()


# Documented alias pairs in the skill catalog (one skill, two names).
ALIASES = {
    "tdd": "test-driven-development",
    "test-driven-development": "tdd",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--set-baseline", action="store_true")
    ap.add_argument("--validate-only", action="store_true",
                    help="offline schema/baseline checks, no model calls")
    ap.add_argument("--skills-dir", action="append", default=[],
                    help="skill root (repeatable); overrides SKILLS_DIRS")
    args = ap.parse_args()

    skills_dirs = resolve_skills_dirs(args.skills_dir)
    listing = load_skill_listing(skills_dirs)
    tasks = load_tasks()

    if args.validate_only:
        problems = validate(tasks, listing)
        print(f"validate-only: {len(listing)} skills, {len(tasks)} tasks, "
              f"{len(problems)} problems")
        for p in problems:
            print(f"  PROBLEM: {p}")
        return 2 if problems else 0

    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print("OPENROUTER_API_KEY not set", file=sys.stderr)
        return 2

    print(f"{len(listing)} skills listed, {len(tasks)} tasks, model {MODEL}")

    listed = {n for n, _ in listing} | set(ALIASES) | set(ALIASES.values())
    results: list[dict] = []
    correct = 0
    scored = 0
    uncoverable = 0
    for t in tasks:
        expected = t["expected"]
        # Catalog coverage vs routing quality: a task whose expected skill is
        # not in the listing under test cannot be routed correctly. Report it
        # separately and exclude it from the gate denominator, so the gate
        # measures routing on THIS catalog (portable across repos/teams).
        if expected != "none" and expected not in listed:
            uncoverable += 1
            results.append({"id": t["id"], "expected": expected,
                            "answer": None, "ok": None})
            print(f"  {t['id']} SKIP expected={expected} (not in listing)")
            continue
        prompt = build_router_prompt(listing, t["prompt"])
        try:
            answer = normalize(call_model(prompt, api_key))
        except Exception as e:
            answer = f"ERROR:{e}"
        # Accept plugin-qualified names both ways (code-review vs code-review:code-review)
        ok = (answer == expected
              or answer.split(":")[-1] == expected.split(":")[-1]
              or ALIASES.get(answer) == expected
              or answer == ALIASES.get(expected))
        correct += ok
        scored += 1
        results.append({"id": t["id"], "expected": expected,
                        "answer": answer, "ok": ok})
        mark = "ok" if ok else "MISS"
        print(f"  {t['id']} {mark:4s} expected={expected} answer={answer}")
        time.sleep(0.2)

    acc = correct / scored if scored else 0.0
    print(f"\naccuracy: {correct}/{scored} = {acc:.3f}"
          f"  ({uncoverable} tasks skipped: expected skill not in listing)")

    run = {"model": MODEL, "accuracy": acc, "n": scored,
           "n_tasks": len(tasks), "n_uncoverable": uncoverable,
           "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "results": results}

    if args.set_baseline:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        with open(BASELINE, "w") as f:
            json.dump(run, f, indent=2)
        print(f"baseline written -> {BASELINE}")
        return 0

    if not os.path.exists(BASELINE):
        print("no baseline found; run with --set-baseline first", file=sys.stderr)
        return 2
    base = json.load(open(BASELINE))
    floor = base["accuracy"] - GATE_TOLERANCE
    print(f"baseline: {base['accuracy']:.3f} ({base['model']}, {base['ts']})"
          f"  gate floor: {floor:.3f}")
    if acc < floor:
        misses = [r for r in results if r["ok"] is False]
        print(f"GATE FAIL: accuracy {acc:.3f} < floor {floor:.3f}")
        print("regressions:")
        for m in misses:
            print(f"  {m['id']} expected={m['expected']} answer={m['answer']}")
        return 1
    print("GATE PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
