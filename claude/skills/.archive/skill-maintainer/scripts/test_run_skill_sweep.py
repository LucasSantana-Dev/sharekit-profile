#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

SCRIPT = Path('~/.agents/skills/skill-maintainer/scripts/run_skill_sweep.py')
REAL_ROOTS = [
    '~/Desenvolvimento/forge-space/.agents/skills',
    '~/.agents/skills',
    '~/.codex/skills',
]


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def run_command(args: list[str]) -> dict:
    subprocess.run(args, check=True, capture_output=True, text=True)
    payload_path = Path(args[args.index('--output-json') + 1])
    return json.loads(payload_path.read_text(encoding='utf-8'))


def test_safe_self_heal() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / 'skills'
        write(
            root / 'demo-skill' / 'SKILL.md',
            "---\nname: demo-skill\ndescription: Demo skill.\n---\n\n# Demo\n",
        )
        write(root / 'demo-skill' / '.DS_Store', 'junk')
        out = Path(tmp) / 'weekly.json'
        md = Path(tmp) / 'weekly.md'
        smoke = Path(tmp) / 'smoke.md'
        payload = run_command([
            'python3', str(SCRIPT),
            '--mode', 'weekly',
            '--scope', 'full',
            '--roots', str(root),
            '--state-dir', str(Path(tmp) / 'state'),
            '--fixtures-path', str(Path('~/.agents/skills/skill-maintainer/references/routing-smoke-fixtures.json')),
            '--backlog-path', str(Path('~/.agents/skills/skill-maintainer/references/post-wave3-gap-backlog.md')),
            '--smoke-prompts-path', str(smoke),
            '--output-json', str(out),
            '--output-md', str(md),
        ])
        assert payload['after_counts']['missing_metadata'] == 0
        assert payload['after_counts']['junk_files'] == 0
        assert payload['safe_self_heal']['applied']


def test_manual_missing_related_skill() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / 'skills'
        write(
            root / 'manual-skill' / 'SKILL.md',
            "---\nname: manual-skill\ndescription: Use when the user wants to review a manual skill.\nmetadata:\n  owner: global-agents\n  tier: contextual\n  canonical_source: " + str(root / 'manual-skill') + "\n---\n\n# Manual Skill\n\n## Outputs / Evidence\n\n- Something.\n\n## Failure / Stop Conditions\n\n- Stop.\n\n## Memory Hooks\n\n- Read memory when needed.\n\n## Related Skills\n\n- **ghost-skill**: Missing on purpose\n",
        )
        out = Path(tmp) / 'manual.json'
        md = Path(tmp) / 'manual.md'
        smoke = Path(tmp) / 'smoke.md'
        payload = run_command([
            'python3', str(SCRIPT),
            '--mode', 'on-demand',
            '--scope', 'full',
            '--self-heal', 'none',
            '--roots', str(root),
            '--state-dir', str(Path(tmp) / 'state'),
            '--fixtures-path', str(Path('~/.agents/skills/skill-maintainer/references/routing-smoke-fixtures.json')),
            '--backlog-path', str(Path('~/.agents/skills/skill-maintainer/references/post-wave3-gap-backlog.md')),
            '--smoke-prompts-path', str(smoke),
            '--output-json', str(out),
            '--output-md', str(md),
        ])
        categories = {item['category'] for item in payload['manual_followup']}
        assert 'missing_related_skill_refs' in categories


def test_manual_stale_overlay() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / 'skills'
        write(
            root / 'overlay-skill' / 'SKILL.md',
            "---\nname: overlay-skill\ndescription: Use when the user wants an overlay skill.\nmetadata:\n  owner: global-agents\n  tier: contextual\n  canonical_source: " + str(root / 'overlay-skill') + "\n  overlay_of: " + str(root / 'missing-target') + "\n---\n\n# Overlay Skill\n\n## Outputs / Evidence\n\n- Something.\n\n## Failure / Stop Conditions\n\n- Stop.\n\n## Memory Hooks\n\n- Read memory when needed.\n",
        )
        out = Path(tmp) / 'overlay.json'
        md = Path(tmp) / 'overlay.md'
        smoke = Path(tmp) / 'smoke.md'
        payload = run_command([
            'python3', str(SCRIPT),
            '--mode', 'on-demand',
            '--scope', 'full',
            '--self-heal', 'none',
            '--roots', str(root),
            '--state-dir', str(Path(tmp) / 'state'),
            '--fixtures-path', str(Path('~/.agents/skills/skill-maintainer/references/routing-smoke-fixtures.json')),
            '--backlog-path', str(Path('~/.agents/skills/skill-maintainer/references/post-wave3-gap-backlog.md')),
            '--smoke-prompts-path', str(smoke),
            '--output-json', str(out),
            '--output-md', str(md),
        ])
        categories = {item['category'] for item in payload['manual_followup']}
        assert 'stale_overlay_targets' in categories


def test_routing_smoke_real_roots() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / 'routing.json'
        md = Path(tmp) / 'routing.md'
        payload = run_command([
            'python3', str(SCRIPT),
            '--mode', 'on-demand',
            '--scope', 'routing',
            '--self-heal', 'none',
            '--roots', *REAL_ROOTS,
            '--state-dir', str(Path(tmp) / 'state'),
            '--fixtures-path', str(Path('~/.agents/skills/skill-maintainer/references/routing-smoke-fixtures.json')),
            '--backlog-path', str(Path('~/.agents/skills/skill-maintainer/references/post-wave3-gap-backlog.md')),
            '--smoke-prompts-path', str(Path('~/.agents/skills/skill-maintainer/references/smoke-prompts.md')),
            '--output-json', str(out),
            '--output-md', str(md),
        ])
        assert payload['routing_smoke']['status'] == 'pass'
        assert not payload['routing_smoke']['failed_families']


def main() -> int:
    test_safe_self_heal()
    test_manual_missing_related_skill()
    test_manual_stale_overlay()
    test_routing_smoke_real_roots()
    print('run_skill_sweep tests passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
