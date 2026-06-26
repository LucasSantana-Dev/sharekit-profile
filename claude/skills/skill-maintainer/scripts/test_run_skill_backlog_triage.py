#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

SCRIPT = Path('~/.agents/skills/skill-maintainer/scripts/run_skill_backlog_triage.py')


BACKLOG_TEXT = """# Post Wave 3 Gap Backlog

- `copywriting`: backlog baseline only.
- `email-sequence`: backlog baseline only.
- `social-content`: backlog baseline only.
- `ai-seo`: backlog baseline only.
- `free-tool-strategy`: backlog baseline only.
- `referral-program`: backlog baseline only.
- `page-cro`: backlog baseline only.
- `marketing-psychology`: backlog baseline only.
"""


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def run_command(args: list[str]) -> dict:
    subprocess.run(args, check=True, capture_output=True, text=True)
    payload_path = Path(args[args.index('--output-json') + 1])
    return json.loads(payload_path.read_text(encoding='utf-8'))


def base_args(tmp: str, scope: str = 'full', mode: str = 'on-demand') -> list[str]:
    root = Path(tmp)
    return [
        'python3', str(SCRIPT),
        '--mode', mode,
        '--scope', scope,
        '--roots', str(root / 'skills'),
        '--backlog-path', str(root / 'backlog.md'),
        '--memory-path', str(root / 'memory.md'),
        '--reports-dir', str(root / 'reports'),
        '--queue-path', str(root / 'task-queue.json'),
        '--automations-root', str(root / 'automations'),
        '--state-dir', str(root / 'state'),
        '--output-json', str(root / 'out.json'),
        '--output-md', str(root / 'out.md'),
    ]


def seed_queue(path: Path, tasks: list[dict]) -> None:
    write(path, json.dumps({'version': 1, 'stale_after_hours': 4, 'tasks': tasks}, indent=2) + '\n')


def seed_skill(path: Path, name: str) -> None:
    write(
        path / name / 'SKILL.md',
        f"---\nname: {name}\ndescription: Use when the user asks to work with {name}.\nmetadata:\n  owner: global-agents\n  tier: contextual\n  canonical_source: {(path / name).as_posix()}\n---\n\n# {name}\n\n## Outputs / Evidence\n\n- Evidence.\n\n## Failure / Stop Conditions\n\n- Stop.\n\n## Memory Hooks\n\n- Read memory when needed.\n",
    )


def test_monthly_gate_skip() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / 'backlog.md', BACKLOG_TEXT)
        write(root / 'memory.md', '')
        seed_queue(root / 'task-queue.json', [])
        payload = run_command(base_args(tmp, mode='recurring') + ['--today', '2026-03-14'])
        assert payload['monthly_gate'] == 'monthly_gate_skip'
        assert payload['queue_actions'] == []
        queue = json.loads((root / 'task-queue.json').read_text(encoding='utf-8'))
        assert queue['tasks'] == []


def test_keep_backlog_with_one_demand_source() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / 'backlog.md', BACKLOG_TEXT)
        write(root / 'memory.md', 'Need a `copywriting` capability later.\n')
        seed_queue(root / 'task-queue.json', [])
        payload = run_command(base_args(tmp, mode='recurring') + ['--today', '2026-03-02'])
        assert payload['results']['copywriting']['classification'] == 'keep_backlog'
        assert payload['results']['copywriting']['demand_source_count'] == 1
        queue = json.loads((root / 'task-queue.json').read_text(encoding='utf-8'))
        assert queue['tasks'] == []


def test_promote_with_two_demand_sources() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / 'backlog.md', BACKLOG_TEXT)
        write(root / 'memory.md', 'Need an `email-sequence` skill soon.\n')
        write(root / 'reports' / 'report.md', 'Repeated request for `email-sequence` keeps coming up.\n')
        seed_queue(root / 'task-queue.json', [])
        payload = run_command(base_args(tmp, mode='recurring') + ['--today', '2026-03-02'])
        assert payload['results']['email-sequence']['classification'] == 'promote_to_queue'
        queue = json.loads((root / 'task-queue.json').read_text(encoding='utf-8'))
        task = next(item for item in queue['tasks'] if item['id'] == 'skill-backlog-triage-email-sequence')
        assert task['status'] == 'pending'


def test_resolved_no_action() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / 'backlog.md', BACKLOG_TEXT)
        write(root / 'memory.md', 'Need `social-content`.\n')
        seed_queue(root / 'task-queue.json', [])
        seed_skill(root / 'skills', 'social-content')
        payload = run_command(base_args(tmp, mode='recurring') + ['--today', '2026-03-02'])
        assert payload['results']['social-content']['classification'] == 'resolved/no-action'
        queue = json.loads((root / 'task-queue.json').read_text(encoding='utf-8'))
        assert queue['tasks'] == []


def test_update_existing_open_task() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / 'backlog.md', BACKLOG_TEXT)
        write(root / 'memory.md', 'Need `ai-seo`.\n')
        write(root / 'reports' / 'report.md', 'Evaluate `ai-seo` soon.\n')
        seed_queue(
            root / 'task-queue.json',
            [
                {
                    'id': 'skill-backlog-triage-ai-seo',
                    'project': 'forge-space-workspace',
                    'title': 'Existing ai-seo task',
                    'status': 'blocked',
                    'notes': 'old',
                    'meta': {},
                }
            ],
        )
        payload = run_command(base_args(tmp, mode='recurring') + ['--today', '2026-03-02'])
        assert payload['results']['ai-seo']['classification'] == 'promote_to_queue'
        queue = json.loads((root / 'task-queue.json').read_text(encoding='utf-8'))
        matches = [item for item in queue['tasks'] if item['id'] == 'skill-backlog-triage-ai-seo']
        assert len(matches) == 1
        assert matches[0]['status'] == 'blocked'
        assert 'Demand sources:' in matches[0]['notes']
        assert 'memory' in matches[0]['notes']
        assert 'reports' in matches[0]['notes']


def main() -> int:
    test_monthly_gate_skip()
    test_keep_backlog_with_one_demand_source()
    test_promote_with_two_demand_sources()
    test_resolved_no_action()
    test_update_existing_open_task()
    print('run_skill_backlog_triage tests passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
