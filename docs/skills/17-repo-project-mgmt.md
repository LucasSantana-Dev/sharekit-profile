# Repository & Project Management Skills

`onboard-new-repo` on first touch of an unfamiliar codebase. `backlog` to turn audit findings into a prioritized issue board. `audit-deep` (composite) for a full health check. `triage` to process incoming issues through the state machine.

---

## /onboard-new-repo ⭐⭐ **Composite**

First-touch workflow: adt-repo-intake → audit-deep → config-drift-detect → init CLAUDE.md.

**Phases:**
1. **Intake:** Rapid repo survey (tools, patterns, owner expectations)
2. **Audit:** Full health check (tests, config, security, MCP, plugins)
3. **Drift:** Audit gates (jest thresholds, tsconfig, ESLint, branch protection)
4. **Init:** Create `.claude/CLAUDE.md` with project-specific rules

**When to use:** First touch of an unfamiliar codebase

**Output:** Onboarded repo + ready to work

---

## /adt-repo-intake

Onboard into an unfamiliar repository fast before making any changes.

**Survey:**
- Tools + frameworks (Next.js? Express? etc.)
- Project structure (monorepo? packages?)
- Development workflow (local, docker, cloud?)
- Owner expectations (style guide, contribution process)
- Blocking work (failing tests, open PRs, security issues)

**When to use:** Starting work in unknown repo

**Output:** Quick repo orientation + next actions

---

## /backlog ⭐⭐ **Composite**

End-to-end backlog builder: audit-deep → ROI-rank → specs → plan → GitHub issues → project board.

**Phases:**
1. **Audit:** Full health report (7 dimensions)
2. **Rank:** ROI-rank findings (impact × effort)
3. **Spec:** Write specs for top items
4. **Plan:** Create implementation plans
5. **Issues:** Convert plans to GitHub issues
6. **Board:** Populate project board with issues + labels + milestone

**When to use:** "What should I work on?" — need prioritized backlog with clear specs

**Output:** GitHub Project board ready for parallel work

---

## /triage

Triage issues through a state machine driven by triage roles.

**States:**
- **needs-triage** → gather info + classify
- **needs-info** → ask reporter for details
- **ready-for-agent** → clear spec + estimated effort
- **ready-for-human** → needs human judgment or external coordination
- **wontfix** → out of scope or duplicate

**When to use:** Processing incoming issues

**Output:** Issue classified + triaged

---

## /to-issues

Break a plan, spec, or PRD into independently-grabbable GitHub issues using vertical slices.

**Vertical slices:**
- User-facing value (feature works end-to-end)
- Small enough for one task (<1 day)
- Independent from other slices

**When to use:** Converting plan to issue board

**Output:** GitHub issues (one per slice)

---

## /to-prd

Turn the current conversation context into a PRD and publish it to the project issue tracker.

**PRD sections:**
- Problem statement
- User personas
- Success criteria
- Proposed solution
- Out of scope
- Timeline + constraints

**When to use:** Feature proposal needs formal spec

**Output:** PRD published to GitHub issue

---

## /plan-to-issues

Take a phased plan file and create one GitHub issue per task with phase-labels and milestone.

**Process:**
1. Read plan file
2. Extract tasks + phases
3. Create issue per task
4. Label with phase + priority
5. Link to milestone

**When to use:** Converting written plan to issue board

**Output:** GitHub issues + board populated

---

## /audit-deep ⭐⭐ **Composite**

Full project health check across testing, config, hooks, performance, security, MCP, and plugins.

**Dimensions:**
1. **Testing:** test-health (coverage, flakiness, runtime)
2. **Config:** config-drift-detect (gates, branch protection)
3. **Hooks:** hook-effectiveness (fire frequency, latency)
4. **Performance:** performance-audit (latency, resource usage)
5. **Security:** security-audit (secrets, dependencies, OWASP)
6. **MCP:** mcp-audit (which servers/tools used?)
7. **Plugins:** plugin-audit (zero-use or broken?)

**Output:** 7-dimension health report + prioritized remediation

---

## /ecosystem-health

Scan a workspace or monorepo and return a raw health snapshot of repos, packages, and CI.

**Scans:**
- Repo health (test coverage, CI status)
- Dependency health (outdated, vulnerable)
- CI health (build passing, flakiness)
- Developer productivity (PR cycle time, merge frequency)

**When to use:** Multi-repo workspace overview

**Output:** Ecosystem health snapshot

---

## /repo-state-snapshot

Take a labeled snapshot of repo state (SHA, open issues, open PRs, latest release) and diff against prior.

**Captures:**
- Current branch + SHA
- Open issue count
- Open PR count
- Latest release tag + date

**When to use:** Tracking progress over time; before/after comparisons

**Output:** Repo state snapshot + diff against prior

---

## /adt-specs-spec-new

Create a committed per-feature spec under `docs/specs/` with frontmatter. Promotes ephemeral plans to persistent artifacts.

**Frontmatter:**
```yaml
---
title: Feature name
status: proposed | approved | in-progress | done
effort: hours estimate
priority: high | medium | low
---
```

**When to use:** Feature spec needs to be durable + tracked

**Output:** Committed spec file

---

## /adt-specs-roadmap-refresh

Regenerate `docs/roadmap.md` from all specs under `docs/specs/`.

**Process:**
1. Read all `docs/specs/*.md`
2. Extract title, status, effort, priority
3. Group by status
4. Generate roadmap table

**When to use:** After adding/updating feature specs

**Output:** Updated roadmap.md

---

## /adt-specs-aggregate-roadmap

Regenerate cross-repo roadmap aggregate in Claude memory by walking every curated repo's `docs/specs/`.

**When to use:** Multi-repo roadmap overview

**Output:** Aggregated roadmap in memory

---

**Last updated:** 2026-06-25
