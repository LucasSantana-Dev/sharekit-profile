# Gathered state (fictional repo "orbit-api")

$ git log --oneline -5
4c1e9aa feat: cursor pagination for /v2/events (#88)
e02b7d1 chore: release 2.4.1
9f3a2c8 fix: limiter off-by-one (#86)
1ab44de docs: update README
77c0d3f test: add events fixtures

$ git branch --show-current
main

$ node -p "require('./package.json').version"
2.4.1

$ npm test | grep Tests:
Tests:       312 passed, 312 total

## Existing memory dir (~/.claude/projects/orbit-api/memory/)
MEMORY.md:
- [Orbit overview](project_orbit_overview.md) - version, test count, recent PRs

project_orbit_overview.md:
---
name: project_orbit_overview
type: project
valid_from: 2026-09-20
---
Version 2.3.0. 280 tests. Recent PRs: #80, #84. Open work: cursor pagination.

## New things learned this session
- Cursor pagination shipped (PR #88). Cursor is an opaque base64 of (created_at, id).
- Gotcha: `npm run test:int` fails silently when DATABASE_URL has a trailing slash.
- AGENTS.md already states: "Never create empty commits." (static rule)
