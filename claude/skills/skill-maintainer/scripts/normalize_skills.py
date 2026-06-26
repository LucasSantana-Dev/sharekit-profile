#!/usr/bin/env python3
from __future__ import annotations

import argparse
import filecmp
import json
import re
import shutil
from pathlib import Path
from typing import Any

import yaml

ROOTS = [
    Path('~/Desenvolvimento/forge-space/.agents/skills'),
    Path('~/.agents/skills'),
    Path('~/.codex/skills'),
]
GLOBAL_ROOT = Path('~/.agents/skills')
CODEX_ROOT = Path('~/.codex/skills')
FORGE_ROOT = Path('~/Desenvolvimento/forge-space/.agents/skills')
SKILL_MAINTAINER_ROOT = GLOBAL_ROOT / 'skill-maintainer'
SMOKE_PROMPTS_PATH = SKILL_MAINTAINER_ROOT / 'references' / 'smoke-prompts.md'

REPO_DUPLICATES = ('brand-guidelines', 'mcp-builder', 'webapp-testing')
MANUAL_REWRITE_NAMES = {
    'agent-browser',
    'browser-use',
    'competitor-alternatives',
    'skill-guide',
    'skill-creator',
    'dependency-pr-hygiene-batch',
    'forge-ops-guard-cycle',
    'forge-required-context-audit',
    'frontend-design-specialist',
    'backend-testing',
    'content-strategy',
    'launch-strategy',
    'nextjs-app-router-patterns',
    'nodejs-backend-patterns',
    'remotion-render',
    'seo-audit',
    'shadcn-ui',
    'tailwind-design-system',
    'turborepo',
    'video-to-website',
    'webapp-testing',
    'skill-maintainer',
}
STATEFUL_NAMES = {
    'automation-workflows',
    'chain-release',
    'ci-watch',
    'claude-mem-resume',
    'context-save',
    'dependency-pr-hygiene-batch',
    'ecosystem-health',
    'forge-ops-guard-cycle',
    'forge-required-context-audit',
    'next-priority',
    'plan',
    'pr-flow',
    'resume',
    'session-wrap-up',
    'ship',
    'skill-maintainer',
    'sync-memories',
}
EPHEMERAL_HINTS = (
    'image', 'art', 'slides', 'spreadsheets', 'theme', 'canvas', 'video', 'brainstorming'
)
JUNK_FILES = {'.DS_Store'}
TRIGGER_OVERRIDES = {
    'agent-browser': 'Run ref-based browser automation with `agent-browser` for quick navigation, form interaction, screenshots, and scripted web flows. Use when the task is quick scripted interaction rather than profile-heavy browsing or Playwright verification. Route profile-heavy or cloud browser-use tasks to `browser-use` and app verification to `webapp-testing`.',
    'audit-website': 'Audit websites with the squirrelscan CLI and turn the results into an actionable SEO, performance, security, or technical health report. Use when someone wants a website or webapp audited, scanned, or benchmarked across multiple quality dimensions.',
    'brainstorming': 'Facilitate collaborative idea exploration and turn rough concepts into a validated design direction before implementation starts. Use when the user is still shaping the solution and should not be pushed into code yet.',
    'brand-guidelines': "Apply Anthropic's official brand colors, typography, and visual language to an artifact that needs brand-consistent styling. Use when the task is about Anthropic-aligned presentation, formatting, or visual system decisions rather than generic theming.",
    'browser-use': 'Run persistent `browser-use` CLI workflows with saved profiles, cloud tasks, and session-aware web automation. Use when the task needs persistent sessions, profile reuse, or browser-use-specific cloud flows. Route quick ref-based interaction to `agent-browser` and Playwright verification to `webapp-testing`.',
    'chain-release': 'Coordinate a multi-repo release sequence by detecting unreleased changes, ordering repos by dependency, and shipping them in the correct order. Use when release work spans multiple packages or repositories and the order matters.',
    'ci-watch': 'Monitor GitHub PR checks in the background and report when required CI finishes green or fails. Use when the user wants you to watch a PR and come back with the result instead of manually polling checks.',
    'code-review': 'Perform a code review that prioritizes bugs, regressions, security issues, performance risks, and missing tests. Use when the user asks for a review of code, a diff, or a change set rather than implementation.',
    'competitor-alternatives': 'Route alternative-page and comparison-page requests into the canonical `programmatic-seo` workflow while keeping a clear boundary for non-scaled editorial strategy. Use when the request is about "[x] alternatives", competitor comparison pages, "x vs y" landing strategy, or alternatives-page acquisition frameworks.',
    'content-strategy': 'Plan a content strategy, topic architecture, and evidence-backed publishing backlog for a product or brand. Use when the task is deciding what to publish and why, not writing a single asset or auditing an existing site.',
    'context-save': 'Capture the current task state so the work can be resumed later without losing key decisions, blockers, or next steps. Use when the session may be interrupted or the user explicitly wants resumable context saved.',
    'deploy-staging': 'Build, validate, and deploy UIForge MCP changes to staging with rollback-aware checks. Use when the task is specifically about preparing or running a staging deployment for UIForge MCP.',
    'design-md': 'Analyze a Stitch project and synthesize its design tokens, components, and semantics into a `DESIGN.md` system document. Use when the user needs structured design-system extraction from an existing Stitch codebase.',
    'docker-expert': 'Provide production-focused Docker guidance for image design, multi-stage builds, compose setups, security hardening, and deployment packaging. Use when the task is mainly about containerizing, optimizing, or shipping software with Docker.',
    'ecosystem-health': 'Scan a workspace or monorepo and return a raw health snapshot of repos, packages, and current operational state. Use when the user wants a quick ecosystem status view rather than a ranked priority decision.',
    'find-skills': 'Discover relevant installable skills from the available skill ecosystem and suggest the best fit for the user request. Use when the user asks whether a skill exists, wants help finding one, or wants to extend the agent with a new capability.',
    'generate-tests': 'Analyze code changes and propose or generate meaningful tests that cover business behavior, edge cases, and regressions. Use when the user wants test additions driven by a concrete implementation or diff.',
    'insights': 'Generate a productivity or usage insights report for Claude Code sessions from the available telemetry and history. Use when the user wants higher-level session analysis instead of raw counters.',
    'launch-strategy': 'Plan product launches, feature announcements, and release momentum across channels. Use when the task is deciding how to launch, sequence channels, and sustain attention after release.',
    'metrics': 'Show concrete productivity metrics and session analytics such as tokens, trends, efficiency, or usage breakdowns. Use when the user asks for raw or summarized Claude Code metrics.',
    'Nano Banana 2 Image Generation Master': 'Generate tightly controlled image prompts for Nano Banana 2 so the resulting images are realistic, specific, and bias-resistant. Use when the request is about high-control Gemini image generation rather than general design advice.',
    'next-best-practices': 'Apply practical Next.js engineering rules covering file conventions, RSC boundaries, async data patterns, metadata, route handlers, and bundling. Use when writing or reviewing Next.js code and you need framework-specific guidance, not generic React advice.',
    'next-cache-components': 'Guide the use of Next.js 16 Cache Components features such as PPR, `use cache`, `cacheLife`, `cacheTag`, and `updateTag`. Use when the task is specifically about Next.js cache-component behavior or cache invalidation strategy.',
    'next-priority': 'Scan one or more projects, rank the real next tasks, and recommend the highest-value option to tackle next. Use when the user asks what to work on next across a repo, monorepo, or multi-repo workspace.',
    'performance-test': 'Run a performance-testing workflow for UIForge MCP to identify bottlenecks, gather benchmarks, and recommend optimizations. Use when the task is specifically about performance validation or tuning for UIForge MCP.',
    'plan': 'Build a structured implementation plan by combining repo context, instructions, and memory into a concrete execution roadmap. Use when the user wants a plan, sequencing, or design spec before code changes begin.',
    'pr-flow': 'Create a branch, commit changes, push them, and open a PR in one coordinated workflow. Use when the user wants to package current work into a reviewable PR with minimal manual git overhead.',
    'quality-gates': 'Run the repository-native verification gates such as lint, type-check, tests, docs, build, and security checks. Use when the user wants confidence before a commit, PR, merge, or release.',
    'remotion-render': 'Render code-driven videos from React and Remotion TSX through inference.sh. Use when the deliverable is a rendered video artifact from component code rather than an interactive website or a generic frontend build.',
    'resume': 'Bootstrap a session by loading repo state, task queues, memories, and open work so the agent can continue productively. Use when the user says to resume, continue, or recover what was already in progress.',
    'seo-audit': 'Route SEO audit requests into the canonical `audit-website` workflow and frame the output around technical SEO, on-page issues, indexability, and remediation priorities. Use when the user asks for an SEO audit, technical SEO review, on-page SEO check, or site SEO health report.',
    'security-audit': 'Perform a broad security audit across secrets, dependencies, code paths, and OWASP-style risks. Use when the user wants a security review of a codebase or system rather than a narrow scan command.',
    'security-scan': 'Run concrete security scanning steps for the current project, including secrets, dependency, code, or config checks. Use when the user wants executable security verification before merge or release.',
    'session-cleanup': 'Clean up the current session state so work can transition cleanly to a new topic or finish without leaving loose context behind. Use when the user wants to reset, compact, or end a working context after a major task.',
    'session-wrap-up': 'Close out a development session by shipping work, capturing memory, and identifying follow-up improvements. Use when the session is ending and the user wants a disciplined wrap-up.',
    'ship': 'Merge a PR, tag the release, publish the GitHub release, and clean up the release branches in one flow. Use when the user wants to complete shipping for a prepared change set.',
    'smart-model-select': 'Classify task complexity and choose an appropriate model tier so simple work stays cheap and complex work gets enough capability. Use when the decision is which model class should handle a task.',
    'sync-memories': 'Sync durable project or session knowledge into the available memory systems so future sessions have accurate context. Use when meaningful work is complete and the user wants the result remembered.',
    'theme-factory': 'Select or generate a coherent visual theme with coordinated colors and fonts for an artifact such as slides, docs, or landing pages. Use when the task is to style an existing artifact rather than invent the artifact itself.',
    'video-to-website': 'Turn source video into a scroll-driven website with extracted frames, section choreography, and browser-delivered motion. Use when the deliverable is an interactive website built from video material rather than a rendered video export.',
    'webapp-testing': 'Test a local web application with Playwright-based scripts, screenshots, browser logs, and reproducible checks. Use when the task is browser-level verification of a web UI rather than quick CLI automation or profile-driven browsing.',
    'slides': 'Create, edit, render, import, or export presentation decks with the artifacts tool. Use when the user wants help producing or modifying slide decks through the JavaScript artifact surface.',
    'spreadsheets': 'Create, edit, recalculate, import, or export spreadsheet workbooks with the artifacts tool. Use when the user wants workbook operations through the JavaScript artifact surface.',
    'gh-address-comments': 'Address review comments on the open GitHub PR for the current branch using `gh` and the repo context. Use when the task is to fetch, interpret, and resolve GitHub PR feedback rather than review code from scratch.',
}
SMOKE_PROMPT_OVERRIDES = {
    'agent-browser': 'Open the site, inspect the DOM refs, click through the login flow, and capture the resulting page state.',
    'audit-website': 'Audit this production website for SEO, performance, security, and broken pages, then summarize the biggest issues.',
    'brainstorming': 'I have three rough product ideas and need help turning them into one validated direction before we write code.',
    'brand-guidelines': 'Restyle this landing-page draft so it follows Anthropic brand colors and typography.',
    'browser-use': 'Use browser-use to log into the app with a saved profile, navigate a multi-step flow, and capture evidence from the final page.',
    'chain-release': 'Figure out which repos in this workspace need releasing and give me the correct release order.',
    'ci-watch': 'Watch PR #128 in this repo and tell me as soon as all required checks are green or if one fails.',
    'code-review': 'Review this change set and list the highest-risk bugs, regressions, and missing tests first.',
    'competitor-alternatives': 'Plan a set of competitor alternatives pages and decide whether they should be a scalable SEO system or a smaller editorial strategy.',
    'context-save': 'Save the current task state so I can resume this exact work later without losing blockers or next steps.',
    'deploy-staging': 'Deploy the current UIForge MCP branch to staging and verify the rollout before reporting back.',
    'design-md': 'Analyze this Stitch project and produce a DESIGN.md that captures its design tokens and component language.',
    'docker-expert': 'Help me turn this service into a secure multi-stage Docker image and explain the key deployment tradeoffs.',
    'ecosystem-health': 'Give me a quick health snapshot of the repos in this workspace without turning it into a priority ranking.',
    'find-skills': 'Is there already a skill that can help with browser automation and screenshots, or do I need a new one?',
    'generate-tests': 'Look at this implementation change and generate the most valuable regression tests to add.',
    'insights': 'Summarize my Claude Code usage trends and highlight the most important productivity insights.',
    'metrics': 'Show me token usage, session counts, and efficiency metrics for recent Claude Code work.',
    'Nano Banana 2 Image Generation Master': 'Generate a highly controlled prompt for a realistic product photo using Nano Banana 2.',
    'next-best-practices': 'I am reviewing a Next.js route and need the framework-specific best-practices checklist that applies here.',
    'next-cache-components': 'Explain how to use cache components and invalidation tags on this Next.js 16 page.',
    'next-priority': 'Scan this workspace and tell me the single best next task to tackle.',
    'performance-test': 'Run the UIForge MCP performance workflow and tell me where the real bottlenecks are.',
    'plan': 'I need a detailed implementation plan for this feature before anyone starts coding.',
    'pr-flow': 'Take the current changes, create a branch, commit them cleanly, push, and open the PR.',
    'quality-gates': 'Run the full quality gates for this project before I open the PR.',
    'resume': 'Resume the work I was doing in this repo and tell me what was in progress.',
    'seo-audit': 'Audit this site for canonicals, crawlability, metadata, headings, schema, and indexability issues, then prioritize the fixes.',
    'security-audit': 'Audit this service for secrets, dependency risks, and obvious application security issues.',
    'security-scan': 'Run the project security scans before we merge this branch.',
    'session-cleanup': 'Clean up this session so I can switch to a different task without stale context hanging around.',
    'session-wrap-up': 'Wrap up this session by shipping what is ready and syncing the important follow-up context.',
    'ship': 'Merge PR #42, tag the release, publish the GitHub release, and clean up the release branch.',
    'smart-model-select': 'Given this task description, which model tier should handle it?',
    'sync-memories': 'Sync the durable outcomes of this session into the available memory systems.',
    'theme-factory': 'Apply a strong theme to this deck and give me a coherent color and font system.',
    'video-to-website': 'Turn this product teaser video into a scroll-driven landing page.',
    'webapp-testing': 'Open the local app in Playwright, click through the main flows, and capture any regressions.',
    'slides': 'Create a short presentation deck for this feature launch using the artifacts tool.',
    'spreadsheets': 'Build a spreadsheet that tracks roadmap status and automatically recalculates totals.',
    'gh-address-comments': 'Fetch the review comments on the open PR for this branch and help me address them one by one.',
}
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
OUTPUT_SECTION = '## Outputs / Evidence\n\n'
STOP_SECTION = '## Failure / Stop Conditions\n\n'
MEMORY_SECTION = '## Memory Hooks\n\n'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Normalize installed skill metadata and support docs.')
    parser.add_argument('--roots', nargs='*', type=Path, default=ROOTS)
    parser.add_argument('--smoke-prompts-path', type=Path, default=SMOKE_PROMPTS_PATH)
    parser.add_argument('--write', action='store_true')
    return parser.parse_args()


def infer_owner(skill_dir: Path) -> str:
    path = skill_dir.as_posix()
    if path.startswith(CODEX_ROOT.as_posix()):
        return 'global-codex'
    if path.startswith(FORGE_ROOT.as_posix()):
        return 'forge-space'
    return 'global-agents'


def infer_tier(name: str, description: str) -> str:
    lowered = f'{name} {description}'.lower()
    if name in STATEFUL_NAMES:
        return 'stateful'
    if any(hint in lowered for hint in EPHEMERAL_HINTS):
        return 'ephemeral'
    if any(word in lowered for word in ('monitor', 'resume', 'queue', 'watch', 'memory', 'priority', 'audit cycle')):
        return 'stateful'
    if any(word in lowered for word in ('generate', 'poster', 'art', 'mockup', 'visual', 'image', 'slides', 'spreadsheet')):
        return 'ephemeral'
    return 'contextual'


def infer_high_signal_description(name: str, description: str) -> str:
    if name in TRIGGER_OVERRIDES:
        return TRIGGER_OVERRIDES[name]
    lowered = description.lower().strip()
    if (
        any(
            phrase in lowered
            for phrase in ('use when', 'use this', 'triggers on', 'use for', 'applies when', 'trigger')
        )
        and 'primarily about' not in lowered
    ):
        return description.strip()
    readable = name.replace('-', ' ')
    if any(word in lowered for word in ('review', 'audit', 'scan')):
        return (
            f"{description.strip().rstrip('.')}."
            ' Use when the task is to inspect existing code, systems, or outputs and return concrete findings.'
        )
    if any(word in lowered for word in ('deploy', 'ship', 'release', 'ci')):
        return (
            f"{description.strip().rstrip('.')}."
            ' Use when the user wants a deployment, release, or verification workflow executed end to end.'
        )
    if any(word in lowered for word in ('generate', 'poster', 'art', 'mockup', 'visual', 'image', 'slides', 'spreadsheet')):
        return (
            f"{description.strip().rstrip('.')}."
            ' Use when the user wants an artifact created, styled, or transformed rather than a generic explanation.'
        )
    return (
        f"{description.strip().rstrip('.')}."
        f' Use when the request clearly maps to {readable} and the skill provides the most direct workflow.'
    )


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str, bool]:
    if text.startswith('---\n'):
        match = re.match(r'^---\n(.*?)\n---\n?', text, re.S)
        if match:
            data = yaml.safe_load(match.group(1)) or {}
            body = text[match.end():]
            return data if isinstance(data, dict) else {}, body, True
    return {}, text, False


def dump_frontmatter(data: dict[str, Any]) -> str:
    return '---\n' + yaml.safe_dump(data, sort_keys=False, allow_unicode=True).strip() + '\n---\n\n'


def load_ui_ux_expert(path: Path) -> tuple[dict[str, Any], str]:
    raw = json.loads(path.read_text(encoding='utf-8'))
    references = path.parent / 'references'
    references.mkdir(exist_ok=True)
    (references / 'input-schema.json').write_text(json.dumps(raw, indent=2) + '\n', encoding='utf-8')
    frontmatter = {
        'name': 'ui-ux-expert',
        'description': 'Focused UI and UX review guidance for modern SaaS and product interfaces. Use when auditing existing dashboards, pricing pages, onboarding flows, forms, or navigation and the goal is to identify concrete visual, usability, or conversion improvements.',
        'metadata': {
            'owner': 'global-agents',
            'tier': 'contextual',
            'canonical_source': path.parent.as_posix(),
        },
    }
    body = '''# UI / UX Expert

Use this skill to review an existing interface and return concrete improvements instead of generic taste commentary.

## Inputs / Prereqs

- `screen_type`
- `goal`
- `ui_description`
- Optional `product_context`
- Optional `design_tokens`

## Workflow

1. Identify the screen's primary user task and success condition.
2. Evaluate hierarchy, layout rhythm, contrast, navigation clarity, and interaction cost.
3. Flag generic or vibe-coded patterns and replace them with concrete alternatives.
4. Tailor suggestions to the product context instead of applying generic SaaS conventions.

## Outputs / Evidence

- A prioritized list of UI and UX findings.
- Concrete layout, component, copy, or token changes.
- Clear reasoning tied to the screen goal.

## Failure / Stop Conditions

- Do not redesign the product around a different audience or business model.
- Do not suggest aesthetic changes that weaken clarity, accessibility, or conversion.

## Load These Resources

- `references/input-schema.json`

## Memory Hooks

- Read memory only if product or design-system history materially affects the review.
- Do not write memory unless the review establishes a durable UI policy.
'''
    return frontmatter, body


def looks_operational(name: str, description: str, body: str) -> bool:
    haystack = f'{name} {description} {body}'.lower()
    keywords = ('deploy', 'audit', 'review', 'testing', 'test', 'ci', 'browser', 'ops', 'watch', 'security', 'ship', 'lint', 'build')
    return any(keyword in haystack for keyword in keywords)


def outputs_template(name: str, description: str) -> str:
    lowered = f'{name} {description}'.lower()
    if any(word in lowered for word in ('review', 'audit', 'test', 'debug', 'security', 'browser', 'deploy', 'ci')):
        return OUTPUT_SECTION + '- Return the checks run, evidence captured, blockers found, and the next required action.\n'
    if any(word in lowered for word in ('image', 'art', 'theme', 'video', 'slides', 'spreadsheet')):
        return OUTPUT_SECTION + '- Return the requested artifact or a concise shortlist of viable options and note any required follow-up assets.\n'
    return OUTPUT_SECTION + '- Return the concrete deliverable requested, the main decisions made, and any unresolved constraints.\n'


def stop_template(name: str, description: str) -> str:
    lowered = f'{name} {description}'.lower()
    if any(word in lowered for word in ('deploy', 'ship', 'release', 'ci', 'audit', 'security', 'browser', 'test', 'review')):
        return STOP_SECTION + '- Stop if required credentials, environment access, or prerequisite context are missing.\n- Stop if the workflow would report unverified work as complete.\n- Do not bypass required gates or safeguards unless the user explicitly asks for it.\n'
    return STOP_SECTION + '- Stop if key prerequisites are missing or the request changes scope enough that the current workflow no longer fits.\n'


def memory_template(tier: str) -> str:
    if tier == 'stateful':
        return MEMORY_SECTION + '- Read memory before acting when queue state, repo history, or prior operational decisions affect correctness.\n- Write back only durable conventions, confirmed outcomes, or workflow state worth reusing later.\n'
    if tier == 'contextual':
        return MEMORY_SECTION + '- Read memory when product, repo, or workflow history affects correctness.\n- Write memory only if this work establishes a durable policy or convention.\n'
    return ''


def ensure_sections(name: str, description: str, body: str, tier: str) -> str:
    result = body.rstrip() + '\n'
    if re.search(r'^##\s+(Outputs?|Output format|Outputs\s*/\s*Evidence)', result, re.I | re.M) is None:
        result += '\n' + outputs_template(name, description)
    if looks_operational(name, description, result) and re.search(r'^##\s+(Failure / Stop Conditions|Failure Conditions|Stop Conditions|Constraints|Guardrails|Red Flags)', result, re.I | re.M) is None:
        result += '\n' + stop_template(name, description)
    if tier in {'stateful', 'contextual'} and re.search(r'^##\s+Memory Hooks', result, re.I | re.M) is None:
        result += '\n' + memory_template(tier)
    return result.rstrip() + '\n'


def compare_dirs(left: Path, right: Path) -> bool:
    comparison = filecmp.dircmp(left, right)
    if comparison.left_only or comparison.right_only or comparison.funny_files or comparison.diff_files:
        return False
    return all(compare_dirs(left / subdir, right / subdir) for subdir in comparison.common_dirs)


def normalize_skill(path: Path) -> tuple[dict[str, Any], str]:
    if path.parent.name == 'ui-ux-expert' and path.read_text(encoding='utf-8', errors='ignore').lstrip().startswith('{'):
        return load_ui_ux_expert(path)

    text = path.read_text(encoding='utf-8', errors='ignore')
    frontmatter, body, _ = parse_frontmatter(text)
    name = frontmatter.get('name') or path.parent.name
    description = infer_high_signal_description(
        name,
        str(frontmatter.get('description') or f"{name.replace('-', ' ')} skill."),
    )
    metadata = frontmatter.get('metadata') if isinstance(frontmatter.get('metadata'), dict) else {}
    tier = infer_tier(name, description)
    canonical_source = metadata.get('canonical_source') or path.parent.as_posix()
    overlay_of = metadata.get('overlay_of')
    if path == CODEX_ROOT / '.system' / 'skill-creator' / 'SKILL.md':
        canonical_source = (GLOBAL_ROOT / 'skill-creator').as_posix()
        overlay_of = canonical_source
    metadata.update(
        {
            'owner': infer_owner(path.parent),
            'tier': tier,
            'canonical_source': canonical_source,
        }
    )
    if overlay_of:
        metadata['overlay_of'] = overlay_of
    elif 'overlay_of' in metadata:
        metadata.pop('overlay_of', None)

    frontmatter['name'] = name
    frontmatter['description'] = description
    frontmatter['metadata'] = metadata

    if name not in MANUAL_REWRITE_NAMES:
        body = ensure_sections(name, description, body, tier)
    else:
        body = body.rstrip() + '\n'
    return frontmatter, body


def write_skill(path: Path, frontmatter: dict[str, Any], body: str) -> None:
    path.write_text(dump_frontmatter(frontmatter) + body, encoding='utf-8')


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


def smoke_prompt(name: str, description: str) -> str:
    if name in SMOKE_PROMPT_OVERRIDES:
        return SMOKE_PROMPT_OVERRIDES[name]
    for sentence in split_sentences(description):
        prompt = sentence_to_prompt(sentence)
        if prompt:
            return prompt
    return f'I need help using the {name} skill for its intended workflow.'


def remove_junk_files(roots: list[Path]) -> None:
    for root in roots:
        for pattern in JUNK_FILES:
            for target in root.rglob(pattern):
                if target.is_file():
                    target.unlink()


def generate_smoke_prompts(roots: list[Path], smoke_prompts_path: Path = SMOKE_PROMPTS_PATH) -> None:
    entries: list[tuple[str, str, str]] = []
    for root in roots:
        for skill in sorted(root.rglob('SKILL.md')):
            frontmatter, _, _ = parse_frontmatter(skill.read_text(encoding='utf-8', errors='ignore'))
            if not frontmatter.get('name'):
                continue
            entries.append((frontmatter['name'], skill.parent.as_posix(), str(frontmatter.get('description', ''))))
    lines = ['# Skill Smoke Prompts', '', 'Use one representative prompt per installed skill to confirm trigger behavior and expected outputs.', '']
    for name, path, description in sorted(entries, key=lambda item: (item[0], item[1])):
        lines.append(f'## {name}')
        lines.append(f'- Path: `{path}`')
        lines.append(f'- Prompt: `{smoke_prompt(name, description)}`')
        lines.append('')
    smoke_prompts_path.parent.mkdir(parents=True, exist_ok=True)
    smoke_prompts_path.write_text('\n'.join(lines), encoding='utf-8')


def main() -> int:
    args = parse_args()
    roots = [root.resolve() for root in args.roots]

    for name in REPO_DUPLICATES:
        local_dir = FORGE_ROOT / name
        global_dir = GLOBAL_ROOT / name
        if local_dir.exists() and global_dir.exists() and compare_dirs(local_dir, global_dir):
            shutil.rmtree(local_dir)

    if not args.write:
        return 0

    remove_junk_files(roots)

    for root in roots:
        for skill in sorted(root.rglob('SKILL.md')):
            frontmatter, body = normalize_skill(skill)
            write_skill(skill, frontmatter, body)

    generate_smoke_prompts(roots, args.smoke_prompts_path.resolve())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
    'install',
