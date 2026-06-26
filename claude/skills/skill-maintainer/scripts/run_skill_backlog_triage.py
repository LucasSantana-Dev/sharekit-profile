#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import audit_skills

DEFAULT_ROOTS = [
    Path('~/Desenvolvimento/forge-space/.agents/skills'),
    Path('~/.agents/skills'),
    Path('~/.codex/skills'),
]
DEFAULT_BACKLOG_PATH = (
    Path('~/.agents/skills/skill-maintainer/references')
    / 'post-wave3-gap-backlog.md'
)
DEFAULT_MEMORY_PATH = Path('~/Desenvolvimento/forge-space/.agents/memory/forge-space.md')
DEFAULT_REPORTS_DIR = Path('~/Desenvolvimento/forge-space/.agents/reports')
DEFAULT_QUEUE_PATH = Path('~/Desenvolvimento/forge-space/.agents/task-queue.json')
DEFAULT_AUTOMATIONS_ROOT = Path('~/.codex/automations')
DEFAULT_STATE_DIR = DEFAULT_AUTOMATIONS_ROOT / 'monthly-skill-backlog-triage' / 'state'
DEFAULT_CANDIDATES = (
    'copywriting',
    'email-sequence',
    'social-content',
    'ai-seo',
    'free-tool-strategy',
    'referral-program',
    'page-cro',
    'marketing-psychology',
)
OPEN_TASK_STATUSES = {'pending', 'blocked', 'in-progress'}
QUEUE_PROJECT = 'forge-space-workspace'


@dataclass
class EvidenceItem:
    source: str
    path: str
    line: int | None
    kind: str
    excerpt: str


@dataclass
class TriageContext:
    mode: str
    scope: str
    candidate: str | None
    roots: list[Path]
    backlog_path: Path
    memory_path: Path
    reports_dir: Path
    queue_path: Path
    automations_root: Path
    state_dir: Path
    output_json: Path
    output_md: Path
    today: date
    update_state: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Run monthly skill backlog triage.')
    parser.add_argument('--mode', choices=('recurring', 'on-demand'), default='on-demand')
    parser.add_argument('--scope', choices=('full', 'candidate', 'report-only'), default='full')
    parser.add_argument('--candidate', help='Capability name for --scope candidate.')
    parser.add_argument('--roots', nargs='*', type=Path, default=DEFAULT_ROOTS)
    parser.add_argument('--backlog-path', type=Path, default=DEFAULT_BACKLOG_PATH)
    parser.add_argument('--memory-path', type=Path, default=DEFAULT_MEMORY_PATH)
    parser.add_argument('--reports-dir', type=Path, default=DEFAULT_REPORTS_DIR)
    parser.add_argument('--queue-path', type=Path, default=DEFAULT_QUEUE_PATH)
    parser.add_argument('--automations-root', type=Path, default=DEFAULT_AUTOMATIONS_ROOT)
    parser.add_argument('--state-dir', type=Path, default=DEFAULT_STATE_DIR)
    parser.add_argument('--today', help='ISO date override for gate checks (YYYY-MM-DD).')
    parser.add_argument('--output-json', type=Path)
    parser.add_argument('--output-md', type=Path)
    parser.add_argument('--update-state', action='store_true')
    parser.add_argument('--no-update-state', action='store_true')
    return parser.parse_args()


def resolve_today(value: str | None) -> date:
    if value:
        return date.fromisoformat(value)
    return datetime.now().astimezone().date()


def resolve_update_state(mode: str, args: argparse.Namespace) -> bool:
    if args.update_state:
        return True
    if args.no_update_state:
        return False
    return mode == 'recurring'


def make_timestamp() -> str:
    return datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')


def build_context(args: argparse.Namespace) -> TriageContext:
    if args.scope == 'candidate' and not args.candidate:
        raise SystemExit('--candidate is required when --scope candidate')
    stamp = make_timestamp()
    json_path = args.output_json or Path(f'/tmp/skill-backlog-triage-{stamp}.json')
    md_path = args.output_md or Path(f'/tmp/skill-backlog-triage-{stamp}.md')
    return TriageContext(
        mode=args.mode,
        scope=args.scope,
        candidate=args.candidate,
        roots=[root.expanduser().resolve() for root in args.roots],
        backlog_path=args.backlog_path.expanduser().resolve(),
        memory_path=args.memory_path.expanduser().resolve(),
        reports_dir=args.reports_dir.expanduser().resolve(),
        queue_path=args.queue_path.expanduser().resolve(),
        automations_root=args.automations_root.expanduser().resolve(),
        state_dir=args.state_dir.expanduser().resolve(),
        output_json=json_path,
        output_md=md_path,
        today=resolve_today(args.today),
        update_state=resolve_update_state(args.mode, args),
    )


def is_first_monday(day: date) -> bool:
    return day.weekday() == 0 and day.day <= 7


def state_path(state_dir: Path) -> Path:
    return state_dir / 'last-success.json'


def load_previous_state(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding='utf-8'))


def save_state(ctx: TriageContext, payload: dict[str, Any]) -> None:
    ctx.state_dir.mkdir(parents=True, exist_ok=True)
    state = {
        'saved_at': payload['finished_at'],
        'mode': payload['mode'],
        'scope': payload['scope'],
        'today': payload['today'],
        'classifications': payload['classifications'],
        'demand_source_counts': payload['demand_source_counts'],
        'queue_actions': payload['queue_actions'],
    }
    state_path(ctx.state_dir).write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')


def compute_delta(current: dict[str, Any], previous: dict[str, Any] | None) -> dict[str, Any]:
    if not previous:
        return {'status': 'bootstrap', 'changes': {}}
    previous_classifications = previous.get('classifications', {})
    previous_counts = previous.get('demand_source_counts', {})
    changes: dict[str, Any] = {}
    for candidate, classification in current['classifications'].items():
        prior_classification = previous_classifications.get(candidate)
        prior_count = int(previous_counts.get(candidate, 0))
        current_count = int(current['demand_source_counts'].get(candidate, 0))
        if prior_classification != classification or prior_count != current_count:
            changes[candidate] = {
                'before': {
                    'classification': prior_classification,
                    'demand_source_count': prior_count,
                },
                'after': {
                    'classification': classification,
                    'demand_source_count': current_count,
                },
            }
    return {'status': 'delta', 'changes': changes}


def parse_backlog(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        stripped = line.strip()
        if not stripped.startswith('- '):
            continue
        names = re.findall(r'`([^`]+)`', stripped)
        if not names:
            continue
        for name in names:
            if name in DEFAULT_CANDIDATES:
                entries[name] = stripped[2:].strip()
    return entries


def selected_candidates(ctx: TriageContext, backlog_entries: dict[str, str]) -> list[str]:
    if ctx.scope == 'candidate':
        if ctx.candidate not in backlog_entries:
            raise SystemExit(f'candidate not found in backlog scope: {ctx.candidate}')
        return [ctx.candidate]
    return [name for name in DEFAULT_CANDIDATES if name in backlog_entries]


def load_installed_skills(roots: list[Path]) -> dict[str, audit_skills.SkillRecord]:
    records = [
        audit_skills.parse_skill(path, roots)
        for root in roots
        for path in sorted(root.rglob('SKILL.md'))
    ]
    mapped: dict[str, audit_skills.SkillRecord] = {}
    for record in records:
        if record.name and record.name not in mapped:
            mapped[record.name] = record
    return mapped


def add_evidence(
    evidence: dict[str, list[EvidenceItem]],
    source: str,
    path: Path,
    line: int | None,
    kind: str,
    excerpt: str,
) -> None:
    evidence[source].append(
        EvidenceItem(
            source=source,
            path=path.as_posix(),
            line=line,
            kind=kind,
            excerpt=excerpt.strip(),
        )
    )


def markdown_patterns(candidate: str) -> list[tuple[re.Pattern[str], str]]:
    escaped = re.escape(candidate)
    human = re.escape(candidate.replace('-', ' '))
    return [
        (re.compile(rf'`{escaped}`', re.I), 'explicit_token'),
        (re.compile(rf'\*\*{escaped}\*\*', re.I), 'explicit_token'),
        (re.compile(rf'\b(?:see|route to|use|evaluate|promote|missing|dedicated)\s+{human}\b', re.I), 'routing_gap'),
        (re.compile(rf'\b{human}\s+(?:skill|capability)\b', re.I), 'routing_gap'),
    ]


def scan_markdown_file(path: Path, candidate: str, source: str, evidence: dict[str, list[EvidenceItem]]) -> None:
    if not path.exists():
        return
    patterns = markdown_patterns(candidate)
    for number, line in enumerate(path.read_text(encoding='utf-8', errors='ignore').splitlines(), start=1):
        for pattern, kind in patterns:
            if pattern.search(line):
                add_evidence(evidence, source, path, number, kind, line)
                break


def scan_memory(path: Path, candidate: str, evidence: dict[str, list[EvidenceItem]]) -> None:
    scan_markdown_file(path, candidate, 'memory', evidence)


def scan_reports(root: Path, candidate: str, evidence: dict[str, list[EvidenceItem]]) -> None:
    if not root.exists():
        return
    for path in sorted(root.rglob('*')):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {'.md', '.json', '.txt'}:
            continue
        scan_markdown_file(path, candidate, 'reports', evidence)


def scan_queue(path: Path, candidate: str, evidence: dict[str, list[EvidenceItem]]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    if not path.exists():
        return {'version': 1, 'stale_after_hours': 4, 'tasks': []}, []
    queue = json.loads(path.read_text(encoding='utf-8'))
    human = candidate.replace('-', ' ')
    pattern = re.compile(rf'(?<![A-Za-z0-9])(?:{re.escape(candidate)}|{re.escape(human)})(?![A-Za-z0-9])', re.I)
    matched_tasks: list[dict[str, Any]] = []
    for task in queue.get('tasks', []):
        blob = ' '.join(
            str(task.get(key, ''))
            for key in ('id', 'title', 'notes')
        )
        if pattern.search(blob):
            matched_tasks.append(task)
            add_evidence(evidence, 'queue', path, None, 'demand_signal', task.get('title', task['id']))
    return queue, matched_tasks


def scan_skills(records: dict[str, audit_skills.SkillRecord], candidate: str, evidence: dict[str, list[EvidenceItem]]) -> None:
    for record in records.values():
        scan_markdown_file(record.path, candidate, 'skills', evidence)


def scan_automations(root: Path, candidate: str, evidence: dict[str, list[EvidenceItem]]) -> None:
    if not root.exists():
        return
    for path in sorted(root.rglob('automation.toml')):
        scan_markdown_file(path, candidate, 'automations', evidence)


def evidence_to_dict(items: list[EvidenceItem]) -> list[dict[str, Any]]:
    return [
        {
            'source': item.source,
            'path': item.path,
            'line': item.line,
            'kind': item.kind,
            'excerpt': item.excerpt,
        }
        for item in items
    ]


def classify_candidate(
    candidate: str,
    backlog_entries: dict[str, str],
    installed_skills: dict[str, audit_skills.SkillRecord],
    ctx: TriageContext,
) -> tuple[str, dict[str, list[EvidenceItem]], list[str]]:
    evidence: dict[str, list[EvidenceItem]] = {
        'backlog': [],
        'memory': [],
        'reports': [],
        'queue': [],
        'skills': [],
        'automations': [],
    }
    if candidate in backlog_entries:
        add_evidence(evidence, 'backlog', ctx.backlog_path, None, 'backlog_baseline', backlog_entries[candidate])
    if candidate in installed_skills:
        record = installed_skills[candidate]
        add_evidence(
            evidence,
            'skills',
            record.path,
            None,
            'resolved_alias_or_skill',
            f'Installed skill `{candidate}` already exists.',
        )
        return 'resolved/no-action', evidence, []
    scan_memory(ctx.memory_path, candidate, evidence)
    scan_reports(ctx.reports_dir, candidate, evidence)
    _, _ = scan_queue(ctx.queue_path, candidate, evidence)
    scan_skills(installed_skills, candidate, evidence)
    scan_automations(ctx.automations_root, candidate, evidence)

    demand_sources = [
        source
        for source in ('memory', 'reports', 'queue')
        if any(item.kind in {'explicit_token', 'routing_gap', 'demand_signal'} for item in evidence[source])
    ]
    if len(demand_sources) >= 2:
        return 'promote_to_queue', evidence, demand_sources
    return 'keep_backlog', evidence, demand_sources


def render_evidence_summary(candidate: str, classification: str, demand_sources: list[str]) -> str:
    if classification == 'promote_to_queue':
        return (
            f'Promoted by monthly backlog triage for `{candidate}` with repeated demand '
            f'from {", ".join(demand_sources)}.'
        )
    if classification == 'resolved/no-action':
        return f'No queue action for `{candidate}` because the capability is already installed.'
    return f'Kept `{candidate}` in backlog; repeated demand threshold not met.'


def upsert_queue_task(
    queue: dict[str, Any],
    candidate: str,
    classification: str,
    demand_sources: list[str],
    finished_at: str,
    artifact_path: Path,
) -> dict[str, Any] | None:
    if classification != 'promote_to_queue':
        return None
    task_id = f'skill-backlog-triage-{candidate}'
    notes = (
        f'Automated monthly backlog triage promoted `{candidate}` on {finished_at}. '\
        f'Demand sources: {", ".join(demand_sources)}. '\
        f'Report: {artifact_path.as_posix()}. '
        'Scope remains queue-only until a supervised implementation session decides whether a new skill is justified.'
    )
    existing = next((task for task in queue.get('tasks', []) if task.get('id') == task_id), None)
    action = 'created'
    if existing is None:
        existing = {
            'id': task_id,
            'project': QUEUE_PROJECT,
            'title': f'Evaluate demand and routing contract for missing skill `{candidate}`',
            'status': 'pending',
            'notes': notes,
            'meta': {
                'candidate': candidate,
                'automation': 'monthly-skill-backlog-triage',
                'evidence_sources': demand_sources,
            },
            'updated_at': finished_at,
        }
        queue.setdefault('tasks', []).append(existing)
    else:
        action = 'updated'
        if existing.get('status') == 'done':
            existing['status'] = 'pending'
            existing.pop('completed_at', None)
        elif existing.get('status') not in OPEN_TASK_STATUSES:
            existing['status'] = 'pending'
        existing['notes'] = notes
        meta = existing.setdefault('meta', {})
        meta['candidate'] = candidate
        meta['automation'] = 'monthly-skill-backlog-triage'
        meta['evidence_sources'] = demand_sources
        existing['updated_at'] = finished_at
    return {
        'task_id': task_id,
        'action': action,
        'status': existing['status'],
    }


def write_queue(path: Path, queue: dict[str, Any]) -> None:
    path.write_text(json.dumps(queue, indent=2) + '\n', encoding='utf-8')


def render_markdown(payload: dict[str, Any]) -> str:
    lines = ['# Monthly Skill Backlog Triage', '']
    lines.append(f"- Mode: `{payload['mode']}`")
    lines.append(f"- Scope: `{payload['scope']}`")
    lines.append(f"- Date: `{payload['today']}`")
    lines.append(f"- Monthly gate: `{payload['monthly_gate']}`")
    lines.append(f"- Delta state: `{payload['delta_from_previous_success']['status']}`")
    lines.append('')
    if payload['monthly_gate'] == 'monthly_gate_skip':
        lines.append('## Result')
        lines.append('- Recurring run skipped because today is not the first Monday of the month.')
        lines.append('')
        lines.append('## Candidate Summary')
        lines.append('- Evaluation skipped before candidate classification.')
        lines.append('')
        lines.append('## Queue Actions')
        lines.append('- none')
        lines.append('')
        lines.append('## Evidence Counts')
        lines.append('- Evaluation skipped before evidence collection.')
        lines.append('')
        lines.append('## Artifacts')
        lines.append(f"- JSON: `{payload['artifacts']['json']}`")
        lines.append(f"- Markdown: `{payload['artifacts']['md']}`")
        lines.append(f"- State dir: `{payload['state_dir']}`")
        return '\n'.join(lines) + '\n'
    lines.append('## Candidate Summary')
    for candidate in payload['candidates']:
        result = payload['results'][candidate]
        lines.append(
            f"- `{candidate}`: `{result['classification']}` "
            f"(demand sources: `{result['demand_source_count']}`)"
        )
    lines.append('')
    lines.append('## Queue Actions')
    if payload['queue_actions']:
        for action in payload['queue_actions']:
            lines.append(
                f"- `{action['task_id']}`: `{action['action']}` -> `{action['status']}`"
            )
    else:
        lines.append('- none')
    lines.append('')
    lines.append('## Evidence Counts')
    for candidate in payload['candidates']:
        result = payload['results'][candidate]
        counts = ', '.join(
            f"{source}={len(result['evidence'][source])}"
            for source in ('backlog', 'memory', 'reports', 'queue', 'skills', 'automations')
        )
        lines.append(f'- `{candidate}`: {counts}')
    lines.append('')
    lines.append('## Artifacts')
    lines.append(f"- JSON: `{payload['artifacts']['json']}`")
    lines.append(f"- Markdown: `{payload['artifacts']['md']}`")
    lines.append(f"- State dir: `{payload['state_dir']}`")
    return '\n'.join(lines) + '\n'


def write_artifacts(ctx: TriageContext, payload: dict[str, Any], markdown: str) -> None:
    ctx.output_json.parent.mkdir(parents=True, exist_ok=True)
    ctx.output_md.parent.mkdir(parents=True, exist_ok=True)
    ctx.output_json.write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    ctx.output_md.write_text(markdown, encoding='utf-8')


def main() -> int:
    ctx = build_context(parse_args())
    previous = load_previous_state(state_path(ctx.state_dir))
    backlog_entries = parse_backlog(ctx.backlog_path)
    candidates = selected_candidates(ctx, backlog_entries)
    started_at = datetime.now(timezone.utc).isoformat()

    payload: dict[str, Any] = {
        'mode': ctx.mode,
        'scope': ctx.scope,
        'today': ctx.today.isoformat(),
        'started_at': started_at,
        'finished_at': datetime.now(timezone.utc).isoformat(),
        'monthly_gate': 'ran',
        'candidates': candidates,
        'results': {},
        'classifications': {},
        'demand_source_counts': {},
        'queue_actions': [],
        'artifacts': {
            'json': ctx.output_json.as_posix(),
            'md': ctx.output_md.as_posix(),
        },
        'state_dir': ctx.state_dir.as_posix(),
    }

    if ctx.mode == 'recurring' and not is_first_monday(ctx.today):
        payload['monthly_gate'] = 'monthly_gate_skip'
        payload['delta_from_previous_success'] = {'status': 'skipped', 'changes': {}}
        markdown = render_markdown(payload)
        write_artifacts(ctx, payload, markdown)
        return 0

    installed_skills = load_installed_skills(ctx.roots)
    queue = json.loads(ctx.queue_path.read_text(encoding='utf-8'))
    finished_at = datetime.now(timezone.utc).isoformat()
    queue_actions: list[dict[str, Any]] = []

    for candidate in candidates:
        classification, evidence, demand_sources = classify_candidate(
            candidate,
            backlog_entries,
            installed_skills,
            ctx,
        )
        payload['results'][candidate] = {
            'classification': classification,
            'demand_source_count': len(demand_sources),
            'demand_sources': demand_sources,
            'summary': render_evidence_summary(candidate, classification, demand_sources),
            'evidence': {
                source: evidence_to_dict(items)
                for source, items in evidence.items()
            },
        }
        payload['classifications'][candidate] = classification
        payload['demand_source_counts'][candidate] = len(demand_sources)
        if ctx.scope != 'report-only':
            action = upsert_queue_task(
                queue,
                candidate,
                classification,
                demand_sources,
                finished_at,
                ctx.output_md,
            )
            if action:
                queue_actions.append(action)

    if queue_actions:
        write_queue(ctx.queue_path, queue)

    payload['finished_at'] = finished_at
    payload['queue_actions'] = queue_actions
    payload['delta_from_previous_success'] = compute_delta(payload, previous)
    markdown = render_markdown(payload)
    write_artifacts(ctx, payload, markdown)
    if ctx.update_state:
        save_state(ctx, payload)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
