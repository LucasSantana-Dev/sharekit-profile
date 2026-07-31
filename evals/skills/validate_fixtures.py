#!/usr/bin/env python3
"""validate_fixtures.py — offline schema validation for per-skill eval fixtures.

Fixtures live at <skills-root>/<skill>/evals/*.json and follow the repo's
skill-creator shape:
  {"skill_name": str, "evals": [{"id", "prompt", "expected_output", "files"}]}
Optional top-level "substance_assertions" and "metadata" are allowed.

Exit 0 when every fixture is valid; exit 2 listing problems.
"""
from __future__ import annotations

import glob
import json
import os
import sys

ROOTS = ["claude/skills", "skills"]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ALLOWED_TOP = {"skill_name", "evals", "substance_assertions", "metadata"}


def validate_file(path: str) -> list[str]:
    problems: list[str] = []
    rel = os.path.relpath(path, REPO)
    try:
        data = json.load(open(path))
    except Exception as e:
        return [f"{rel}: invalid JSON: {e}"]
    unknown = set(data) - ALLOWED_TOP
    if unknown:
        problems.append(f"{rel}: unknown top-level keys {sorted(unknown)}")
    for field in ("skill_name", "evals"):
        if field not in data:
            problems.append(f"{rel}: missing '{field}'")
    if problems:
        return problems
    # Fixture must live under a directory matching its declared skill.
    parent = os.path.basename(os.path.dirname(os.path.dirname(path)))
    if data["skill_name"] != parent:
        problems.append(f"{rel}: skill_name '{data['skill_name']}' != dir '{parent}'")
    if not isinstance(data["evals"], list) or not data["evals"]:
        problems.append(f"{rel}: 'evals' must be a non-empty list")
        return problems
    ids: set = set()
    for case in data["evals"]:
        cid = case.get("id")
        if cid is None:
            problems.append(f"{rel}: case missing 'id'")
            continue
        if cid in ids:
            problems.append(f"{rel}: duplicate case id {cid}")
        ids.add(cid)
        if not case.get("prompt"):
            problems.append(f"{rel}: case {cid} missing 'prompt'")
        if not case.get("expected_output"):
            problems.append(f"{rel}: case {cid} missing 'expected_output'")
    return problems


def main() -> int:
    all_problems: list[str] = []
    n_files = 0
    for root in ROOTS:
        for path in sorted(glob.glob(os.path.join(REPO, root, "*", "evals", "*.json"))):
            n_files += 1
            all_problems.extend(validate_file(path))
    print(f"validate-fixtures: {n_files} fixture files, {len(all_problems)} problems")
    for p in all_problems:
        print(f"  PROBLEM: {p}")
    return 2 if all_problems else 0


if __name__ == "__main__":
    sys.exit(main())
