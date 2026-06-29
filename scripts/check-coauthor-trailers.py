#!/usr/bin/env python3
"""check-coauthor-trailers.py — CI gate that rejects bot Co-authored-by trailers.

Scans git log for Co-authored-by trailers matching known bot/AI patterns.
Exit 0 if clean, exit 1 with list of offending commits if found.

Patterns matched (case-insensitive):
  Claude, codex, cursor, copilot, [bot], RuFlo, AI, Generated
"""
import re
import subprocess
import sys

BOT_PATTERNS = [
    r"claude",
    r"codex",
    r"cursor",
    r"copilot",
    r"\[bot\]",
    r"ruflo",
    r"\bai\b",
    r"generated",
]

COMPILED = [re.compile(p, re.IGNORECASE) for p in BOT_PATTERNS]

TRAILER_RE = re.compile(
    r"^Co-authored-by:\s*(.+)$", re.IGNORECASE | re.MULTILINE
)


def get_log() -> str:
    """Return full git log with commit hashes and bodies."""
    result = subprocess.run(
        ["git", "log", "--all", "--format=%H%n%B%n---END---"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def scan(log: str) -> list[tuple[str, str]]:
    """Return list of (commit_sha, coauthor_value) for offending trailers."""
    offenses: list[tuple[str, str]] = []
    chunks = log.split("---END---")
    for chunk in chunks:
        lines = chunk.strip().splitlines()
        if not lines:
            continue
        sha = lines[0].strip()
        if not sha or len(sha) < 7:
            continue
        body = "\n".join(lines[1:])
        for match in TRAILER_RE.finditer(body):
            value = match.group(1).strip()
            for pattern in COMPILED:
                if pattern.search(value):
                    offenses.append((sha, value))
                    break
    return offenses


def main() -> int:
    try:
        log = get_log()
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: git log failed: {exc}", file=sys.stderr)
        return 1

    offenses = scan(log)
    if not offenses:
        print("OK: no bot Co-authored-by trailers found")
        return 0

    print(f"FAIL: {len(offenses)} bot Co-authored-by trailer(s) detected:\n")
    for sha, value in offenses:
        print(f"  {sha[:12]}  Co-authored-by: {value}")
    print()
    print("Remove these trailers before merging.")
    print("Tip: use 'git rebase -i' to edit commit messages, or configure")
    print("your AI tool to stop adding Co-authored-by trailers.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
