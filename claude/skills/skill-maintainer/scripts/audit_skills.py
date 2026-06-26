#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

DEFAULT_ROOTS = [
    Path('~/Desenvolvimento/forge-space/.agents/skills'),
    Path('~/.agents/skills'),
    Path('~/.codex/skills'),
]
DEFAULT_OVERSIZED_LINES = 200
STANDARD_SUPPORT_ENTRIES = {
    'references',
    'scripts',
    'assets',
    'agents',
    'templates',
    'command',
    'rules',
    'evals',
    'data',
    'themes',
    'examples',
    'canvas-fonts',
}
JUNK_FILES = {'.DS_Store'}
CLASSIFIED_SUPPORT_FILES = {
    'README.md': {
        'classification': 'reference-index',
        'reason': 'Imported or vendor reference index kept intentionally.',
    },
    'AGENTS.md': {
        'classification': 'navigation-guide',
        'reason': 'Navigation guide for bundled references or upstream agent usage.',
    },
    'CLAUDE.md': {
        'classification': 'legacy-alias',
        'reason': 'Compatibility alias for upstream agent guidance.',
    },
    'SKILL.toon': {
        'classification': 'legacy-source-metadata',
        'reason': 'Legacy source metadata retained conservatively.',
    },
    'LICENSE.txt': {
        'classification': 'license-file',
        'reason': 'Licensing or provenance metadata.',
    },
    'license.txt': {
        'classification': 'license-file',
        'reason': 'Licensing or provenance metadata.',
    },
    'reference': {
        'classification': 'legacy-reference-dir',
        'reason': 'Legacy-named reference directory retained conservatively.',
    },
    'cli.md': {
        'classification': 'root-reference-doc',
        'reason': 'Focused root reference doc used by the skill.',
    },
    'customization.md': {
        'classification': 'root-reference-doc',
        'reason': 'Focused root reference doc used by the skill.',
    },
    'mcp.md': {
        'classification': 'root-reference-doc',
        'reason': 'Focused root reference doc used by the skill.',
    },
    'code-reviewer.md': {
        'classification': 'root-reference-doc',
        'reason': 'Focused root reference doc used by the skill.',
    },
    'async-patterns.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'bundling.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'data-patterns.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'debug-tricks.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'directives.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'error-handling.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'file-conventions.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'font.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'functions.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'hydration-error.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'image.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'metadata.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'parallel-routes.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'route-handlers.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'rsc-boundaries.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'runtime-selection.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'scripts.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'self-hosting.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'suspense-boundaries.md': {
        'classification': 'root-reference-doc',
        'reason': 'Split reference content for a larger skill.',
    },
    'condition-based-waiting.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'defense-in-depth.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'root-cause-tracing.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'test-academic.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'test-pressure-1.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'test-pressure-2.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'test-pressure-3.md': {
        'classification': 'root-reference-doc',
        'reason': 'Debugging reference content.',
    },
    'condition-based-waiting-example.ts': {
        'classification': 'root-example',
        'reason': 'Runnable example file.',
    },
    'find-polluter.sh': {
        'classification': 'root-script',
        'reason': 'Reusable helper script.',
    },
    'implementer-prompt.md': {
        'classification': 'prompt-asset',
        'reason': 'Prompt asset for subagent workflows.',
    },
    'code-quality-reviewer-prompt.md': {
        'classification': 'prompt-asset',
        'reason': 'Prompt asset for subagent workflows.',
    },
    'spec-reviewer-prompt.md': {
        'classification': 'prompt-asset',
        'reason': 'Prompt asset for subagent workflows.',
    },
    'testing-anti-patterns.md': {
        'classification': 'root-reference-doc',
        'reason': 'Testing reference content.',
    },
    'theme-showcase.pdf': {
        'classification': 'asset-preview',
        'reason': 'Preview asset for theme selection.',
    },
    'CREATION-LOG.md': {
        'classification': 'legacy-note',
        'reason': 'Historical note retained conservatively.',
    },
}
GENERIC_TRIGGER_PHRASE = 'use when the request is primarily about'
LOW_SIGNAL_PROMPT_PATTERNS = (
    'help with a ',
    'primarily about',
    ' workflows or outcomes',
    'skill for its intended workflow',
)
ACTION_VERBS = {
    'answer',
    'address',
    'analyze',
    'apply',
    'audit',
    'automate',
    'bootstrap',
    'build',
    'capture',
    'clean',
    'coordinate',
    'create',
    'diagnose',
    'debug',
    'deploy',
    'discover',
    'edit',
    'explain',
    'facilitate',
    'fetch',
    'find',
    'generate',
    'guide',
    'improve',
    'inspect',
    'manage',
    'migrate',
    'monitor',
    'optimize',
    'orchestrate',
    'perform',
    'plan',
    'render',
    'resume',
    'review',
    'run',
    'save',
    'scan',
    'select',
    'show',
    'style',
    'summarize',
    'sync',
    'test',
    'translate',
    'turn',
    'update',
    'watch',
    'write',
}
PROMPT_PATTERNS = (
    (re.compile(r'^(?:use when a user asks to|use when the user asks to)\s+(.+)$', re.I), 'I need to {clause}.'),
    (re.compile(r'^(?:use when a user asks|use when the user asks)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:when the user wants to|when users want to|when someone wants to)\s+(.+)$', re.I), 'I want to {clause}.'),
    (re.compile(r'^(?:when the user needs to|when users need to|when someone needs to)\s+(.+)$', re.I), 'I need to {clause}.'),
    (re.compile(r'^(?:when the user wants|when users want|when someone wants)\s+(.+)$', re.I), 'I want {clause}.'),
    (re.compile(r'^(?:when the user needs|when users need|when someone needs)\s+(.+)$', re.I), 'I need {clause}.'),
    (re.compile(r'^(?:use this(?: skill)? when(?: the user asks)? to)\s+(.+)$', re.I), 'I need to {clause}.'),
    (re.compile(r'^(?:this skill should be used when)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:use (?:this skill )?when)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:also use when)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:applies when)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:triggers on(?: tasks involving)?|triggers include|also triggers for)\s+(.+)$', re.I), 'I need help with {clause}.'),
    (re.compile(r'^(?:use for:?|perfect for)\s+(.+)$', re.I), 'I need help with {clause}.'),
)


@dataclass
class SkillRecord:
    root: str
    path: Path
    skill_dir: Path
    name: str | None
    description: str | None
    metadata: dict[str, Any]
    headings: list[str]
    support_dirs: list[str]
    line_count: int
    has_frontmatter: bool
    has_memory_hooks: bool
    has_outputs_section: bool
    has_stop_conditions: bool
    body: str


TRACKED_SECTIONS = {
    'outputs': re.compile(r'^##\s+(outputs?|outputs\s*/\s*evidence|output format)', re.I | re.M),
    'memory': re.compile(r'^##\s+memory hooks', re.I | re.M),
    'stop': re.compile(r'^##\s+(failure / stop conditions|failure conditions|stop conditions|constraints|guardrails|red flags)', re.I | re.M),
}
RELATED_SKILLS_SECTION = re.compile(
    r'^##\s+Related Skills\s*$\n(?P<body>.*?)(?=^##\s+|\Z)',
    re.I | re.M | re.S,
)
RELATED_SKILL_ENTRY = re.compile(r'^\s*[-*]\s+(?:\*\*([^*]+)\*\*|`([^`]+)`)', re.M)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Audit installed skill folders.')
    parser.add_argument('--roots', nargs='*', type=Path, default=DEFAULT_ROOTS)
    parser.add_argument('--output-json', type=Path)
    parser.add_argument('--output-md', type=Path)
    parser.add_argument('--oversized-lines', type=int, default=DEFAULT_OVERSIZED_LINES)
    return parser.parse_args()


def parse_skill(path: Path, roots: list[Path]) -> SkillRecord:
    text = path.read_text(encoding='utf-8', errors='ignore')
    has_frontmatter = text.startswith('---\n')
    frontmatter: dict[str, Any] = {}
    body = text
    if has_frontmatter:
        match = re.match(r'^---\n(.*?)\n---\n?', text, re.S)
        if match:
            frontmatter = yaml.safe_load(match.group(1)) or {}
            body = text[match.end():]
    headings = [line.strip() for line in body.splitlines() if line.startswith('#')]
    root = next((candidate for candidate in roots if candidate in path.parents), path.parent)
    support_dirs = sorted(
        entry.name for entry in path.parent.iterdir() if entry.name != 'SKILL.md'
    )
    metadata = frontmatter.get('metadata') or {}
    return SkillRecord(
        root=root.as_posix(),
        path=path,
        skill_dir=path.parent,
        name=frontmatter.get('name'),
        description=frontmatter.get('description'),
        metadata=metadata if isinstance(metadata, dict) else {},
        headings=headings,
        support_dirs=support_dirs,
        line_count=text.count('\n') + 1,
        has_frontmatter=has_frontmatter,
        has_memory_hooks=bool(TRACKED_SECTIONS['memory'].search(body)) or 'memory' in body.lower(),
        has_outputs_section=bool(TRACKED_SECTIONS['outputs'].search(body)),
        has_stop_conditions=bool(TRACKED_SECTIONS['stop'].search(body)),
        body=body,
    )


def classify_duplicates(records: list[SkillRecord]) -> dict[str, list[dict[str, Any]]]:
    by_name: dict[str, list[SkillRecord]] = defaultdict(list)
    for record in records:
        if record.name:
            by_name[record.name].append(record)

    duplicates: dict[str, list[dict[str, Any]]] = {}
    for name, family in sorted(by_name.items()):
        if len(family) < 2:
            continue
        entries: list[dict[str, Any]] = []
        canonical_candidates = [
            item for item in family if item.metadata.get('canonical_source') == item.skill_dir.as_posix()
        ]
        for item in family:
            entries.append(
                {
                    'path': item.skill_dir.as_posix(),
                    'owner': item.metadata.get('owner'),
                    'overlay_of': item.metadata.get('overlay_of'),
                    'canonical_source': item.metadata.get('canonical_source'),
                }
            )
        unresolved = not canonical_candidates or any(
            item.metadata.get('overlay_of') is None and item.metadata.get('canonical_source') != item.skill_dir.as_posix()
            for item in family
            if item not in canonical_candidates
        )
        if unresolved:
            duplicates[name] = entries
    return duplicates


def infer_owner(root: str) -> str:
    if root.endswith('/.codex/skills'):
        return 'global-codex'
    if '/forge-space/.agents/skills' in root:
        return 'forge-space'
    return 'global-agents'


def classify_support_entries(record: SkillRecord) -> tuple[list[dict[str, Any]], list[str]]:
    entries: list[dict[str, Any]] = []
    junk: list[str] = []
    for entry in record.support_dirs:
        path = (record.skill_dir / entry).as_posix()
        if entry in STANDARD_SUPPORT_ENTRIES:
            continue
        if entry in JUNK_FILES:
            junk.append(path)
            continue
        policy = CLASSIFIED_SUPPORT_FILES.get(entry)
        entries.append(
            {
                'path': path,
                'entry': entry,
                'classification': (
                    policy['classification'] if policy else 'unclassified'
                ),
                'reason': (
                    policy['reason']
                    if policy
                    else 'No support-file policy classification found.'
                ),
            }
        )
    return entries, junk


def build_summary(records: list[SkillRecord], oversized_lines: int) -> dict[str, Any]:
    installed_skill_names = {record.name for record in records if record.name}
    missing_frontmatter = [record.skill_dir.as_posix() for record in records if not record.has_frontmatter]
    missing_name = [record.skill_dir.as_posix() for record in records if not record.name]
    missing_description = [record.skill_dir.as_posix() for record in records if not record.description]
    missing_metadata = [
        record.skill_dir.as_posix()
        for record in records
        if not all(record.metadata.get(key) for key in ('owner', 'tier'))
    ]
    weak_descriptions = [
        {
            'path': record.skill_dir.as_posix(),
            'description': record.description,
        }
        for record in records
        if not has_trigger_language(record.description)
    ]
    generic_trigger_descriptions = [
        {
            'path': record.skill_dir.as_posix(),
            'description': record.description,
        }
        for record in records
        if is_generic_trigger_description(record.description)
    ]
    missing_memory = [
        record.skill_dir.as_posix()
        for record in records
        if record.metadata.get('tier') in {'stateful', 'contextual'} and not record.has_memory_hooks
    ]
    missing_outputs = [
        record.skill_dir.as_posix() for record in records if not record.has_outputs_section
    ]
    missing_stop_conditions = [
        record.skill_dir.as_posix()
        for record in records
        if looks_operational(record) and not record.has_stop_conditions
    ]
    oversized_unresolved = [
        {
            'path': record.skill_dir.as_posix(),
            'lines': record.line_count,
            'support_dirs': record.support_dirs,
            'progressive_disclosure': record.metadata.get('progressive_disclosure'),
        }
        for record in records
        if record.line_count >= oversized_lines
        and record.metadata.get('progressive_disclosure') not in {'split', 'exempted'}
    ]
    oversized_split = [
        {
            'path': record.skill_dir.as_posix(),
            'lines': record.line_count,
            'support_dirs': record.support_dirs,
        }
        for record in records
        if record.line_count >= oversized_lines
        and record.metadata.get('progressive_disclosure') == 'split'
    ]
    oversized_exempted = [
        {
            'path': record.skill_dir.as_posix(),
            'lines': record.line_count,
            'reason': record.metadata.get('progressive_disclosure_reason'),
        }
        for record in records
        if record.line_count >= oversized_lines
        and record.metadata.get('progressive_disclosure') == 'exempted'
    ]
    nonstandard_support_entries: list[dict[str, Any]] = []
    junk_files: list[str] = []
    low_signal_smoke_prompts: list[dict[str, Any]] = []
    missing_related_skill_refs: list[dict[str, Any]] = []
    stale_overlay_targets: list[dict[str, Any]] = []
    for record in records:
        classified_entries, junk_entry_paths = classify_support_entries(record)
        nonstandard_support_entries.extend(classified_entries)
        junk_files.extend(junk_entry_paths)
        prompt = infer_smoke_prompt(record.name or record.skill_dir.name, record.description)
        if is_low_signal_smoke_prompt(prompt):
            low_signal_smoke_prompts.append(
                {
                    'path': record.skill_dir.as_posix(),
                    'prompt': prompt,
                }
            )
        for related_skill in extract_related_skills(record):
            if related_skill not in installed_skill_names:
                missing_related_skill_refs.append(
                    {
                        'path': record.skill_dir.as_posix(),
                        'related_skill': related_skill,
                    }
                )
        overlay_of = record.metadata.get('overlay_of')
        if overlay_of and not overlay_target_exists(str(overlay_of)):
            stale_overlay_targets.append(
                {
                    'path': record.skill_dir.as_posix(),
                    'overlay_of': overlay_of,
                }
            )
    owner_counts: dict[str, int] = defaultdict(int)
    tier_counts: dict[str, int] = defaultdict(int)
    for record in records:
        owner_counts[infer_owner(record.root)] += 1
        tier_counts[str(record.metadata.get('tier') or 'missing')] += 1
    return {
        'total_skills': len(records),
        'owner_counts': dict(sorted(owner_counts.items())),
        'tier_counts': dict(sorted(tier_counts.items())),
        'missing_frontmatter': missing_frontmatter,
        'missing_name': missing_name,
        'missing_description': missing_description,
        'missing_metadata': missing_metadata,
        'weak_descriptions': weak_descriptions,
        'generic_trigger_descriptions': generic_trigger_descriptions,
        'low_signal_smoke_prompts': low_signal_smoke_prompts,
        'missing_related_skill_refs': missing_related_skill_refs,
        'stale_overlay_targets': stale_overlay_targets,
        'nonstandard_support_entries': nonstandard_support_entries,
        'junk_files': sorted(junk_files),
        'missing_memory_hooks': missing_memory,
        'missing_outputs_sections': missing_outputs,
        'missing_stop_conditions': missing_stop_conditions,
        'oversized_skills': oversized_unresolved,
        'oversized_split': oversized_split,
        'oversized_exempted': oversized_exempted,
        'unresolved_duplicates': classify_duplicates(records),
    }


def looks_operational(record: SkillRecord) -> bool:
    haystack = ' '.join([record.name or '', record.description or '', *record.headings]).lower()
    keywords = ('deploy', 'audit', 'review', 'testing', 'test', 'ci', 'browser', 'ops', 'watch', 'security', 'ship')
    return any(word in haystack for word in keywords)


def has_trigger_language(description: str | None) -> bool:
    if not description:
        return False
    lowered = description.lower()
    phrases = ('use when', 'use this', 'triggers on', 'use for', 'applies when', 'trigger')
    return any(phrase in lowered for phrase in phrases)


def is_generic_trigger_description(description: str | None) -> bool:
    return bool(description and GENERIC_TRIGGER_PHRASE in description.lower())


def split_sentences(description: str) -> list[str]:
    return [part.strip() for part in re.split(r'(?<=[.!?])\s+', description.strip()) if part.strip()]


def normalize_clause(clause: str) -> str:
    clause = re.sub(r'^the user (?:asks|mentions)\s+', '', clause.strip(), flags=re.I)
    clause = clause.replace('`', '')
    clause = re.sub(r'\s+', ' ', clause).rstrip('.')
    if clause.startswith('to '):
        clause = clause[3:]
    return clause


def sentence_to_prompt(sentence: str) -> str | None:
    cleaned = sentence.strip().rstrip('.')
    if not cleaned:
        return None
    first_word = cleaned.split()[0].strip('`"\'():,').lower()
    if first_word in ACTION_VERBS:
        return f'{cleaned}.'
    for pattern, template in PROMPT_PATTERNS:
        match = pattern.match(cleaned)
        if not match:
            continue
        clause = normalize_clause(match.group(1))
        if clause:
            return template.format(clause=clause)
    return None


def infer_smoke_prompt(name: str, description: str | None) -> str:
    for sentence in split_sentences(description or ''):
        prompt = sentence_to_prompt(sentence)
        if prompt:
            return prompt
    readable = name.replace('-', ' ')
    return f'Use the {name} skill for a request about {readable}.'


def is_low_signal_smoke_prompt(prompt: str) -> bool:
    lowered = prompt.lower()
    return any(fragment in lowered for fragment in LOW_SIGNAL_PROMPT_PATTERNS)


def extract_related_skills(record: SkillRecord) -> list[str]:
    match = RELATED_SKILLS_SECTION.search(record.body)
    if not match:
        return []
    names: list[str] = []
    for entry in RELATED_SKILL_ENTRY.finditer(match.group('body')):
        name = entry.group(1) or entry.group(2)
        if name:
            names.append(name.strip())
    return names


def overlay_target_exists(overlay_of: str) -> bool:
    target = Path(overlay_of)
    if target.is_dir():
        return (target / 'SKILL.md').exists()
    return target.is_file()


def render_markdown(summary: dict[str, Any]) -> str:
    lines = ['# Skill Audit Report', '']
    lines.append(f"- Total skills: `{summary['total_skills']}`")
    lines.append(f"- Owner counts: `{json.dumps(summary['owner_counts'], sort_keys=True)}`")
    lines.append(f"- Tier counts: `{json.dumps(summary['tier_counts'], sort_keys=True)}`")
    lines.append(f"- Unresolved duplicates: `{len(summary['unresolved_duplicates'])}`")
    lines.append(f"- Missing metadata: `{len(summary['missing_metadata'])}`")
    lines.append(f"- Weak descriptions: `{len(summary['weak_descriptions'])}`")
    lines.append(f"- Generic trigger descriptions: `{len(summary['generic_trigger_descriptions'])}`")
    lines.append(f"- Low-signal smoke prompts: `{len(summary['low_signal_smoke_prompts'])}`")
    lines.append(f"- Missing related-skill refs: `{len(summary['missing_related_skill_refs'])}`")
    lines.append(f"- Stale overlay targets: `{len(summary['stale_overlay_targets'])}`")
    lines.append(f"- Non-standard support entries: `{len(summary['nonstandard_support_entries'])}`")
    lines.append(f"- Junk files: `{len(summary['junk_files'])}`")
    lines.append(f"- Missing memory hooks: `{len(summary['missing_memory_hooks'])}`")
    lines.append(f"- Missing outputs sections: `{len(summary['missing_outputs_sections'])}`")
    lines.append(f"- Missing stop conditions: `{len(summary['missing_stop_conditions'])}`")
    lines.append(f"- Oversized skills: `{len(summary['oversized_skills'])}`")
    lines.append(f"- Oversized already split: `{len(summary['oversized_split'])}`")
    lines.append(f"- Oversized explicitly exempted: `{len(summary['oversized_exempted'])}`")
    lines.append('')

    def section(title: str, values: list[Any], formatter=str) -> None:
        lines.append(f'## {title}')
        if not values:
            lines.append('- none')
        else:
            for value in values:
                lines.append(f'- {formatter(value)}')
        lines.append('')

    section('Missing Metadata', summary['missing_metadata'])
    section('Weak Descriptions', summary['weak_descriptions'], lambda item: f"`{item['path']}` :: {item['description']!r}")
    section('Generic Trigger Descriptions', summary['generic_trigger_descriptions'], lambda item: f"`{item['path']}` :: {item['description']!r}")
    section('Low-Signal Smoke Prompts', summary['low_signal_smoke_prompts'], lambda item: f"`{item['path']}` :: {item['prompt']!r}")
    section('Missing Related-Skill Refs', summary['missing_related_skill_refs'], lambda item: f"`{item['path']}` :: {item['related_skill']}")
    section('Stale Overlay Targets', summary['stale_overlay_targets'], lambda item: f"`{item['path']}` :: {item['overlay_of']}")
    section('Non-Standard Support Entries', summary['nonstandard_support_entries'], lambda item: f"`{item['path']}` ({item['classification']}: {item['reason']})")
    section('Junk Files', summary['junk_files'])
    section('Missing Memory Hooks', summary['missing_memory_hooks'])
    section('Missing Outputs Sections', summary['missing_outputs_sections'])
    section('Missing Stop Conditions', summary['missing_stop_conditions'])
    section('Oversized Skills', summary['oversized_skills'], lambda item: f"`{item['path']}` ({item['lines']} lines; support={','.join(item['support_dirs']) or 'none'})")
    section('Oversized Already Split', summary['oversized_split'], lambda item: f"`{item['path']}` ({item['lines']} lines; support={','.join(item['support_dirs']) or 'none'})")
    section('Oversized Explicitly Exempted', summary['oversized_exempted'], lambda item: f"`{item['path']}` ({item['lines']} lines; reason={item['reason']})")
    lines.append('## Unresolved Duplicates')
    if not summary['unresolved_duplicates']:
        lines.append('- none')
    else:
        for name, entries in summary['unresolved_duplicates'].items():
            lines.append(f'- `{name}`')
            for entry in entries:
                lines.append(
                    f"  - `{entry['path']}` owner={entry['owner']!r} canonical_source={entry['canonical_source']!r} overlay_of={entry['overlay_of']!r}"
                )
    lines.append('')
    return '\n'.join(lines)


def main() -> int:
    args = parse_args()
    roots = [root.resolve() for root in args.roots]
    records = [parse_skill(path, roots) for root in roots for path in sorted(root.rglob('SKILL.md'))]
    summary = build_summary(records, args.oversized_lines)
    payload = {
        'roots': [root.as_posix() for root in roots],
        'summary': summary,
        'skills': [
            {
                'name': record.name,
                'path': record.skill_dir.as_posix(),
                'owner': record.metadata.get('owner'),
                'tier': record.metadata.get('tier'),
                'description': record.description,
                'line_count': record.line_count,
                'support_dirs': record.support_dirs,
            }
            for record in records
        ],
    }
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    if args.output_md:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        args.output_md.write_text(render_markdown(summary), encoding='utf-8')
    if not args.output_json and not args.output_md:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
    'install',
