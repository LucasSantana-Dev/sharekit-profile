#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def run(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'command failed')
    return result.stdout.strip()


def try_run(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        return ''
    return result.stdout.strip()


def parse_worktrees(raw: str) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in raw.splitlines():
        if not line:
            if current:
                items.append(current)
                current = {}
            continue
        key, _, value = line.partition(' ')
        current[key] = value
    if current:
        items.append(current)
    parsed: list[dict[str, str]] = []
    for item in items:
        parsed.append(
            {
                'path': item.get('worktree', ''),
                'branch': item.get('branch', '').removeprefix('refs/heads/'),
                'head': item.get('HEAD', ''),
                'bare': str('bare' in item),
                'detached': str('detached' in item),
            }
        )
    return parsed


def guidance_lines(repo_root: Path) -> list[str]:
    lines: list[str] = []
    for name in ('CLAUDE.md', 'AGENTS.md'):
        path = repo_root / name
        if not path.exists():
            continue
        for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
            if 'worktree' in line.lower():
                lines.append(f'{name}: {line.strip()}')
    return lines


def gather(repo_root: Path) -> dict[str, object]:
    status_lines = [line for line in try_run('git', 'status', '--short', cwd=repo_root).splitlines() if line]
    local_dirs = [name for name in ('.worktrees', 'worktrees') if (repo_root / name).exists()]
    suggested_dir = local_dirs[0] if local_dirs else ''
    return {
        'repo_root': repo_root.as_posix(),
        'current_branch': try_run('git', 'branch', '--show-current', cwd=repo_root),
        'dirty': bool(status_lines),
        'dirty_entries': status_lines,
        'local_worktree_dirs': local_dirs,
        'suggested_dir': suggested_dir,
        'active_worktrees': parse_worktrees(try_run('git', 'worktree', 'list', '--porcelain', cwd=repo_root)),
        'guidance_lines': guidance_lines(repo_root),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description='Inspect git worktree preflight state.')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    repo_root = Path(run('git', 'rev-parse', '--show-toplevel')).resolve()
    data = gather(repo_root)

    if args.json:
        print(json.dumps(data, indent=2))
        return 0

    print(f"repo_root: {data['repo_root']}")
    print(f"current_branch: {data['current_branch']}")
    print(f"dirty: {data['dirty']}")
    if data['dirty_entries']:
        print('dirty_entries:')
        for entry in data['dirty_entries']:
            print(f'  - {entry}')
    print(f"local_worktree_dirs: {', '.join(data['local_worktree_dirs']) or 'none'}")
    print(f"suggested_dir: {data['suggested_dir'] or 'none'}")
    print('active_worktrees:')
    for item in data['active_worktrees']:
        print(f"  - path={item['path']} branch={item['branch'] or 'detached'}")
    if data['guidance_lines']:
        print('guidance_lines:')
        for line in data['guidance_lines']:
            print(f'  - {line}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
