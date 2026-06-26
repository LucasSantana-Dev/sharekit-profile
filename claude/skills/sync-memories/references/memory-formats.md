# Reference: Memory Formats and Examples

Examples and schema for each memory system.

## Serena Memory Format

Standard key-value pair with multiline content. Update via:

```python
serena.update_memory("<key>", """
- Item 1: detail
- Item 2: detail
- Current state: description
""")
```

### `project_overview` Example

```
- Version: 2.1.4
- Tests: 412 passing, 8 suites, 0 flaky
- Latest PRs merged: #523 (perf), #521 (docs), #519 (security)
- New features (this session): dark mode toggle, API rate-limit headers
- Open PRs: #527 (pending review), #525 (draft)
- Dependencies: all up-to-date (npm audit clean)
```

### `architecture` Example

```
## Module Structure
- `/src/core/`: engine, state machine, event bus
- `/src/adapters/`: provider integrations (GitHub, Linear, Sentry)
- `/src/cli/`: command entrypoints

## Critical Files
- `src/core/engine.ts`: event loop, retry logic — touch with care
- `src/config/schema.ts`: Zod validation rules — bumps break CLI contracts
- `src/__tests__/fixtures/`: large fixture set, regenerate after schema changes

## Gotchas
- Adapter init runs async; event bus must be booted before adapter load
- Config merges shallow, not deep; environment overrides only 1 level
- Claude-mem ingestion is broken (Jun 2026) — use RAG vault for durable memory
```

### `development_workflow` Example

```
## Build & Test
- npm run build: compile TypeScript → dist/
- npm test: vitest, 8 suites, ~5s cold
- npm run lint:check: ESLint + Prettier check
- npm run lint:fix: auto-fix style issues

## Branching
- Main branch: prod releases only (tagged)
- Feature branches: feature/<name> off main
- PR required: 1 approval (code-owner), CI green

## CI Gates
- Lint must pass (ESLint, Prettier)
- Tests must pass (vitest, 100% parallel)
- Audit: no moderate+ vulns
- knip: unused exports checked
```

---

## Local Memory File Format (`.agents/memory/`)

Markdown file, repo-local checkpoint. Located in project root at `.agents/memory/<project-name>.md`.

### Template

```markdown
# Project Name

## Latest Session (YYYY-MM-DD)
- Changes: Brief 1–2 sentence summary of work completed
- Files: Key files modified (max 5 paths)
- State: Is the code in a shippable state? Any blockers?
- Gotchas: Issues discovered, workarounds, lessons learned
- Version: X.Y.Z
- Tests: N passing, M suites

## Prior Sessions

### Session 2026-06-20
- Changes: Fixed race condition in event handler
- Files: src/core/event-handler.ts, src/__tests__/event-handler.test.ts
- State: Shipped in v2.0.1
- Gotchas: Event timing is sensitive to async/await order
```

### Example Entry

```markdown
# forge-patterns

## Latest Session (2026-06-22)
- Changes: Added feature-flag validation to config schema; updated FeatureToggleSystem tests
- Files: src/config/schema.ts, src/feature-toggle/system.ts, src/__tests__/feature-toggle.test.ts
- State: Ready to merge (all tests green, CI passing, docs updated)
- Gotchas: Schema changes must bump package.json version to avoid silent contract mismatches
- Version: 1.8.0
- Tests: 312 passing, 6 suites

## Prior Sessions

### Session 2026-06-21
- Changes: Added Zod runtime validation for toggle namespaces
- Files: src/config/schema.ts, src/zod-schemas/toggle-namespace.ts
- State: Merged to main in PR #419
- Gotchas: Zod strict mode rejects unknown keys; had to add `.passthrough()` for backward compatibility
```

---

## Knowledge-Brain Vault Format

Durable cross-project decision/memory capture in `~/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory/`.

Always write via **symlink path** (not raw brain path) so the reindex hook fires: `~/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory/<name>.md`

### MEMORY.md Index Pointer

The vault's index file (`MEMORY.md`) auto-loads into RAG and lists all memory entries. Each memory you create becomes a RAG-searchable chunk. Structure as markdown with clear headers + YAML frontmatter (optional).

### Example Session Memory

**File:** `~/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory/session_2026-06-22_forge_patterns_cli.md`

```markdown
---
date: 2026-06-22
project: forge-patterns
type: session
---

# Session 2026-06-22 — Forge-Patterns CLI Refactor

## Summary
Added `validate-config` CLI subcommand + integrated Zod schema validation. All tests passing, ready to ship in v1.8.0.

## Changes
- New file: `src/cli/commands/validate-config.ts` (Zod schema validation wrapper)
- Modified: `src/config/schema.ts` (added strict mode, unknown key rejection)
- Tests: 8 new tests in `src/__tests__/cli/validate-config.test.ts`

## Decisions
- **Schema strictness:** Zod strict + passthrough (allows future backward compat)
- **CLI placement:** subcommand under `forge-patterns config` (not top-level)
- **Error output:** JSON format for tooling, human-readable fallback

## Gotchas
- Zod `.strict()` breaks existing configs with extra keys → added passthrough to recover
- CLI stdout/stderr separation: redirected validation errors to stderr to avoid breaking JSON output

## Next
- Ship in v1.8.0 (cut release branch next session)
- Update FeatureToggleSystem docs with new validation behavior
```

This memory will be searchable by:
- `search_knowledge("forge-patterns CLI validation")`
- `rag_query("forge-patterns config validate", scope_types=["memory"])`
- Future sessions can `recall` this work without re-asking
