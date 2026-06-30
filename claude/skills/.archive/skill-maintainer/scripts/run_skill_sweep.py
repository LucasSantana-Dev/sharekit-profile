#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import audit_skills
import normalize_skills

DEFAULT_ROOTS = [
    Path('~/Desenvolvimento/forge-space/.agents/skills'),
    Path('~/.agents/skills'),
    Path('~/.codex/skills'),
]
DEFAULT_STATE_DIR = Path('~/.codex/automations/weekly-skill-sweep-2/state')
DEFAULT_FIXTURES_PATH = (
    Path('~/.agents/skills/skill-maintainer/references')
    / 'routing-smoke-fixtures.json'
)
DEFAULT_BACKLOG_PATH = (
    Path('~/.agents/skills/skill-maintainer/references')
    / 'post-wave3-gap-backlog.md'
)
DEFAULT_SMOKE_PROMPTS_PATH = normalize_skills.SMOKE_PROMPTS_PATH
SAFE_CATEGORY_KEYS = (
    'missing_frontmatter',
    'missing_name',
    'missing_description',
    'missing_metadata',
    'weak_descriptions',
    'generic_trigger_descriptions',
    'low_signal_smoke_prompts',
    'junk_files',
    'missing_memory_hooks',
    'missing_outputs_sections',
    'missing_stop_conditions',
)
MANUAL_CATEGORY_KEYS = (
    'missing_related_skill_refs',
    'stale_overlay_targets',
    'oversized_skills',
    'unresolved_duplicates',
)
COUNT_KEYS = (
    'unresolved_duplicates',
    'missing_metadata',
    'weak_descriptions',
    'generic_trigger_descriptions',
    'low_signal_smoke_prompts',
    'missing_related_skill_refs',
    'stale_overlay_targets',
    'junk_files',
    'missing_memory_hooks',
    'missing_outputs_sections',
    'missing_stop_conditions',
    'oversized_skills',
    'oversized_split',
    'oversized_exempted',
)


@dataclass
class SweepArtifacts:
    json_path: Path
    md_path: Path


@dataclass
class SweepContext:
    mode: str
    scope: str
    roots: list[Path]
    state_dir: Path
    smoke_prompts_path: Path
    fixtures_path: Path
    backlog_path: Path
    self_heal: str
    artifacts: SweepArtifacts
    update_state: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Run recurring or on-demand skill-maintainer sweeps.')
    parser.add_argument('--mode', choices=('weekly', 'on-demand'), default='on-demand')
    parser.add_argument(
        '--scope',
        choices=('full', 'aliases', 'wrappers', 'routing', 'backlog'),
        default='full',
    )
    parser.add_argument('--roots', nargs='*', type=Path, default=DEFAULT_ROOTS)
    parser.add_argument('--state-dir', type=Path, default=DEFAULT_STATE_DIR)
    parser.add_argument('--fixtures-path', type=Path, default=DEFAULT_FIXTURES_PATH)
    parser.add_argument('--backlog-path', type=Path, default=DEFAULT_BACKLOG_PATH)
    parser.add_argument('--smoke-prompts-path', type=Path, default=DEFAULT_SMOKE_PROMPTS_PATH)
    parser.add_argument('--self-heal', choices=('auto', 'none', 'safe'), default='auto')
    parser.add_argument('--output-json', type=Path)
    parser.add_argument('--output-md', type=Path)
    parser.add_argument('--update-state', action='store_true')
    parser.add_argument('--no-update-state', action='store_true')
    return parser.parse_args()


def resolve_self_heal(mode: str, value: str) -> str:
    if value != 'auto':
        return value
    return 'safe' if mode == 'weekly' else 'none'


def resolve_update_state(mode: str, args: argparse.Namespace) -> bool:
    if args.update_state:
        return True
    if args.no_update_state:
        return False
    return mode == 'weekly'


def make_timestamp() -> str:
    return datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')


def make_artifact_paths(args: argparse.Namespace, stamp: str) -> SweepArtifacts:
    json_path = args.output_json or Path(f'/tmp/skill-sweep-{stamp}.json')
    md_path = args.output_md or Path(f'/tmp/skill-sweep-{stamp}.md')
    return SweepArtifacts(json_path=json_path, md_path=md_path)


def build_context(args: argparse.Namespace) -> SweepContext:
    stamp = make_timestamp()
    return SweepContext(
        mode=args.mode,
        scope=args.scope,
        roots=[root.resolve() for root in args.roots],
        state_dir=args.state_dir.expanduser().resolve(),
        smoke_prompts_path=args.smoke_prompts_path.expanduser().resolve(),
        fixtures_path=args.fixtures_path.expanduser().resolve(),
        backlog_path=args.backlog_path.expanduser().resolve(),
        self_heal=resolve_self_heal(args.mode, args.self_heal),
        artifacts=make_artifact_paths(args, stamp),
        update_state=resolve_update_state(args.mode, args),
    )


def load_records(roots: list[Path]) -> list[audit_skills.SkillRecord]:
    return [
        audit_skills.parse_skill(path, roots)
        for root in roots
        for path in sorted(root.rglob('SKILL.md'))
    ]


def run_audit(roots: list[Path]) -> dict[str, Any]:
    records = load_records(roots)
    summary = audit_skills.build_summary(records, audit_skills.DEFAULT_OVERSIZED_LINES)
    return {'records': records, 'summary': summary}


def count_summary(summary: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for key in COUNT_KEYS:
        value = summary[key]
        counts[key] = len(value) if hasattr(value, '__len__') else int(value)
    return counts


def load_smoke_prompt_map(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    lines = path.read_text(encoding='utf-8').splitlines()
    prompts: dict[str, str] = {}
    current: str | None = None
    for line in lines:
        if line.startswith('## '):
            current = line[3:].strip()
            continue
        if current and line.startswith('- Prompt: `'):
            prompts[current] = line[len('- Prompt: `'):-1]
            current = None
    return prompts


def apply_safe_self_heal(roots: list[Path], smoke_prompts_path: Path) -> list[str]:
    applied = [
        'normalize_skills',
        'smoke_prompts_regenerated',
        'junk_files_removed',
    ]
    normalize_skills.remove_junk_files(roots)
    for root in roots:
        for skill in sorted(root.rglob('SKILL.md')):
            frontmatter, body = normalize_skills.normalize_skill(skill)
            normalize_skills.write_skill(skill, frontmatter, body)
    normalize_skills.generate_smoke_prompts(roots, smoke_prompts_path)
    return applied


def load_fixtures(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def scope_matches(group: str, scope: str) -> bool:
    if scope in {'full', 'routing'}:
        return True
    if scope == 'aliases':
        return group == 'alias'
    if scope == 'wrappers':
        return group in {'wrapper', 'router'}
    return False


def is_preferred_record(candidate: audit_skills.SkillRecord, current: audit_skills.SkillRecord) -> bool:
    candidate_is_canonical = (
        candidate.metadata.get('canonical_source') == candidate.skill_dir.as_posix()
        and not candidate.metadata.get('overlay_of')
    )
    current_is_canonical = (
        current.metadata.get('canonical_source') == current.skill_dir.as_posix()
        and not current.metadata.get('overlay_of')
    )
    return candidate_is_canonical and not current_is_canonical


def build_record_map(records: list[audit_skills.SkillRecord]) -> dict[str, audit_skills.SkillRecord]:
    mapped: dict[str, audit_skills.SkillRecord] = {}
    for record in records:
        if not record.name:
            continue
        current = mapped.get(record.name)
        if current is None or is_preferred_record(record, current):
            mapped[record.name] = record
    return mapped


def family_description_failures(
    family: dict[str, Any],
    record_map: dict[str, audit_skills.SkillRecord],
) -> list[str]:
    failures: list[str] = []
    descriptions = family.get('descriptions', {})
    for skill_name, fragments in descriptions.items():
        record = record_map.get(skill_name)
        if not record or not record.description:
            failures.append(f'{skill_name}: missing description')
            continue
        lowered = record.description.lower()
        missing = [fragment for fragment in fragments if fragment.lower() not in lowered]
        if missing:
            failures.append(f'{skill_name}: missing description fragments {missing}')
    return failures


def family_overlay_failures(
    family: dict[str, Any],
    record_map: dict[str, audit_skills.SkillRecord],
) -> list[str]:
    overlay = family.get('overlay')
    if not overlay:
        return []
    source = record_map.get(overlay['source'])
    target = record_map.get(overlay['target'])
    if not source or not target:
        return [f"overlay pair missing installed skill: {overlay['source']} -> {overlay['target']}"]
    actual = source.metadata.get('overlay_of')
    expected = target.skill_dir.as_posix()
    if actual != expected:
        return [f"{overlay['source']}: overlay_of {actual!r} != {expected!r}"]
    return []


def family_prompt_failures(
    family: dict[str, Any],
    prompts: dict[str, str],
) -> list[str]:
    failures: list[str] = []
    for skill_name in family['skills']:
        prompt = prompts.get(skill_name)
        if not prompt:
            failures.append(f'{skill_name}: missing smoke prompt entry')
            continue
        if audit_skills.is_low_signal_smoke_prompt(prompt):
            failures.append(f'{skill_name}: low-signal smoke prompt')
    return failures


def family_related_failures(
    family: dict[str, Any],
    record_map: dict[str, audit_skills.SkillRecord],
) -> list[str]:
    failures: list[str] = []
    installed = set(record_map)
    for skill_name in family['skills']:
        record = record_map.get(skill_name)
        if not record:
            continue
        missing = [name for name in audit_skills.extract_related_skills(record) if name not in installed]
        if missing:
            failures.append(f'{skill_name}: missing related skill refs {missing}')
    return failures


def run_routing_smoke(
    scope: str,
    records: list[audit_skills.SkillRecord],
    smoke_prompts_path: Path,
    fixtures_path: Path,
) -> dict[str, Any]:
    if scope == 'backlog':
        return {'families': [], 'failed_families': [], 'status': 'skipped'}
    fixtures = load_fixtures(fixtures_path)
    prompts = load_smoke_prompt_map(smoke_prompts_path)
    record_map = build_record_map(records)
    results: list[dict[str, Any]] = []
    failed: list[str] = []
    for family in fixtures['families']:
        if not scope_matches(family['group'], scope):
            continue
        failures: list[str] = []
        missing_skills = [name for name in family['skills'] if name not in record_map]
        if missing_skills:
            failures.extend(f'missing installed skill: {name}' for name in missing_skills)
        failures.extend(family_description_failures(family, record_map))
        failures.extend(family_overlay_failures(family, record_map))
        failures.extend(family_prompt_failures(family, prompts))
        failures.extend(family_related_failures(family, record_map))
        status = 'pass' if not failures else 'fail'
        if failures:
            failed.append(family['id'])
        results.append({'id': family['id'], 'group': family['group'], 'status': status, 'failures': failures})
    return {
        'families': results,
        'failed_families': failed,
        'status': 'pass' if not failed else 'fail',
    }


def collect_followups(summary: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    safe: list[dict[str, Any]] = []
    manual: list[dict[str, Any]] = []
    for key in SAFE_CATEGORY_KEYS:
        items = summary.get(key, [])
        if items:
            safe.append({'category': key, 'count': len(items), 'items': items})
    for key in MANUAL_CATEGORY_KEYS:
        items = summary.get(key, [])
        if items:
            manual.append({'category': key, 'count': len(items), 'items': items})
    return safe, manual


def parse_backlog(path: Path) -> list[str]:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r'^- `(.*?)`:(.*)$', re.M)
    return [f'{name}: {desc.strip()}' for name, desc in pattern.findall(text)]


def load_previous_state(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding='utf-8'))


def compute_delta(current: dict[str, int], previous: dict[str, Any] | None) -> dict[str, Any]:
    if not previous:
        return {'status': 'bootstrap', 'changes': {}}
    prior = previous.get('after_counts', {})
    changes = {}
    for key, value in current.items():
        old = int(prior.get(key, 0))
        if old != value:
            changes[key] = {'before': old, 'after': value, 'delta': value - old}
    return {'status': 'delta', 'changes': changes}


def state_path(state_dir: Path) -> Path:
    return state_dir / 'last-success.json'


def save_state(ctx: SweepContext, payload: dict[str, Any]) -> None:
    ctx.state_dir.mkdir(parents=True, exist_ok=True)
    state = {
        'saved_at': payload['finished_at'],
        'mode': payload['mode'],
        'scope': payload['scope'],
        'after_counts': payload['after_counts'],
        'manual_followup_count': len(payload['manual_followup']),
        'routing_smoke_status': payload['routing_smoke']['status'],
    }
    state_path(ctx.state_dir).write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')


def trim_item(item: Any) -> str:
    if isinstance(item, dict):
        if 'path' in item and 'related_skill' in item:
            return f"{item['path']} -> {item['related_skill']}"
        if 'path' in item and 'overlay_of' in item:
            return f"{item['path']} -> {item['overlay_of']}"
        if 'path' in item and 'description' in item:
            return f"{item['path']}"
        if 'path' in item:
            return item['path']
    return str(item)


def render_followup_markdown(title: str, entries: list[dict[str, Any]]) -> list[str]:
    lines = [f'## {title}']
    if not entries:
        lines.append('- none')
        return lines
    for entry in entries:
        lines.append(f"- `{entry['category']}`: {entry['count']}")
        for item in entry['items'][:5]:
            lines.append(f'  - `{trim_item(item)}`')
    return lines


def render_summary(payload: dict[str, Any]) -> str:
    lines = ['# Skill Sweep Summary', '']
    lines.append(f"- Mode: `{payload['mode']}`")
    lines.append(f"- Scope: `{payload['scope']}`")
    lines.append(f"- Self-heal: `{payload['self_heal']}`")
    lines.append(f"- Delta state: `{payload['delta_from_previous_success']['status']}`")
    lines.append('')
    lines.append('## Audit Counts')
    for key in COUNT_KEYS:
        lines.append(
            f"- `{key}`: before `{payload['before_counts'][key]}` -> after `{payload['after_counts'][key]}`"
        )
    lines.append('')
    lines.extend(render_followup_markdown('Safe Self-Heal Candidates', payload['safe_self_heal']['before']))
    lines.append('')
    lines.append('## Safe Self-Heal Applied')
    if payload['safe_self_heal']['applied']:
        for item in payload['safe_self_heal']['applied']:
            lines.append(f'- `{item}`')
    else:
        lines.append('- none')
    lines.append('')
    lines.extend(render_followup_markdown('Manual Follow-Up', payload['manual_followup']))
    lines.append('')
    lines.append('## Routing Smoke')
    lines.append(f"- Status: `{payload['routing_smoke']['status']}`")
    if payload['routing_smoke']['failed_families']:
        lines.append(
            '- Failed families: ' + ', '.join(f'`{name}`' for name in payload['routing_smoke']['failed_families'])
        )
    else:
        lines.append('- Failed families: none')
    lines.append('')
    lines.append('## Next Actions')
    if payload['manual_followup']:
        lines.append('- Review the manual follow-up categories before making structural skill changes.')
    else:
        lines.append('- No manual follow-up required from this sweep.')
    if payload['scope'] == 'backlog':
        lines.append('- Review backlog-only capabilities and decide whether demand justifies new skills.')
    lines.append('')
    lines.append('## Artifacts')
    lines.append(f"- JSON: `{payload['artifacts']['json']}`")
    lines.append(f"- Markdown: `{payload['artifacts']['md']}`")
    lines.append(f"- State dir: `{payload['state_dir']}`")
    return '\n'.join(lines) + '\n'


def write_artifacts(ctx: SweepContext, payload: dict[str, Any], markdown: str) -> None:
    ctx.artifacts.json_path.parent.mkdir(parents=True, exist_ok=True)
    ctx.artifacts.md_path.parent.mkdir(parents=True, exist_ok=True)
    ctx.artifacts.json_path.write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    ctx.artifacts.md_path.write_text(markdown, encoding='utf-8')


def main() -> int:
    ctx = build_context(parse_args())
    previous = load_previous_state(state_path(ctx.state_dir))
    started_at = datetime.now(timezone.utc).isoformat()

    before = run_audit(ctx.roots)
    safe_before, manual_followup = collect_followups(before['summary'])
    applied: list[str] = []
    if ctx.self_heal == 'safe' and safe_before:
        applied = apply_safe_self_heal(ctx.roots, ctx.smoke_prompts_path)

    after = run_audit(ctx.roots)
    routing_smoke = run_routing_smoke(
        ctx.scope,
        after['records'],
        ctx.smoke_prompts_path,
        ctx.fixtures_path,
    )
    if routing_smoke['failed_families']:
        manual_followup.append(
            {
                'category': 'routing_smoke_failures',
                'count': len(routing_smoke['failed_families']),
                'items': routing_smoke['failed_families'],
            }
        )
    if ctx.scope == 'backlog':
        manual_followup.append(
            {
                'category': 'backlog_review',
                'count': len(parse_backlog(ctx.backlog_path)),
                'items': parse_backlog(ctx.backlog_path),
            }
        )

    payload = {
        'mode': ctx.mode,
        'scope': ctx.scope,
        'roots': [root.as_posix() for root in ctx.roots],
        'started_at': started_at,
        'finished_at': datetime.now(timezone.utc).isoformat(),
        'self_heal': ctx.self_heal,
        'artifacts': {
            'json': ctx.artifacts.json_path.as_posix(),
            'md': ctx.artifacts.md_path.as_posix(),
        },
        'state_dir': ctx.state_dir.as_posix(),
        'before_counts': count_summary(before['summary']),
        'after_counts': count_summary(after['summary']),
        'safe_self_heal': {
            'before': safe_before,
            'applied': applied,
        },
        'manual_followup': manual_followup,
        'routing_smoke': routing_smoke,
        'delta_from_previous_success': compute_delta(count_summary(after['summary']), previous),
        'input_gate_pause': {
            'status': 'not_triggered',
            'message': 'This sweep performed no browser, auth, signup, or personal-data steps.',
        },
    }
    markdown = render_summary(payload)
    write_artifacts(ctx, payload, markdown)
    if ctx.update_state:
        save_state(ctx, payload)
    print(markdown)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
