# Tier-B skill removals (audit follow-through)

- Date: 2026-05-28
- Status: Accepted
- Decision pipeline: `/research-and-decide` (re-examination → ref-verification → critic adjudication → this ADR)

## Context

The skill audit (workflow `w27xmrkj5`) flagged 17 real-skill KILL candidates. Two were already resolved this session: `adr-gap` reclassified KEEP (feeds `decide`), `api-consistency` removed. The remaining 15 were re-examined. A re-examination agent walked most back to KEEP/HOLD on "foundational / session machinery" grounds — but inbound-reference verification (grep across all SKILL.md + CLAUDE.md + standards, excluding the *generated* `performance-test/skills-map.md`) showed those claims were unfounded, and a critic adjudicated the two competing biases (audit over-kill vs re-exam over-keep).

Key evidence: all 15 have zero direct invocations; only `insights` has real referencers (`session-wrap-up`, `ui-audit`); `adt-plan-change`'s claimed "feeds /plan" reference was verified FALSE.

## Decision

**REMOVE 14** (zero refs + zero usage + poor fit or named overlap):
`api-design-principles`, `architecture-patterns`, `adt-context`, `adt-context-hygiene`, `adt-cost`, `adt-learn`, `adt-checkpoint`, `adt-plan-change`, `adt-compress-assets`, `adt-mcp-readiness`, `adt-sync-pt-parity`, `autofix`, `force-merge-self-pr`, `plugin-supabase-supabase-postgres-best-practices`.

**KEEP 1**: `insights` — referenced by `session-wrap-up` + `ui-audit` (ADR-0001 protects referenced skills).

Overlap map for the removed (why redundant, not just unused): `adt-context`/`adt-context-hygiene` ↔ session-compaction hooks; `adt-cost` ↔ `token-audit`; `adt-learn` ↔ `knowledge-loop`/`sync-memories`; `adt-checkpoint` ↔ git-worktrees + `.claude/plans/`; `adt-plan-change` ↔ `plan`/`scope-and-execute`; `adt-mcp-readiness` ↔ `adt-mcp-health`/`mcp-audit`.

## Alternatives considered

- **Re-examination's keep-7** (`adt-context`/`adt-cost` KEEP + 5 HOLD on "foundational") — rejected: zero refs, zero usage, named overlaps; "foundational" without a referencer or usage is catalog bloat (the over-keep failure mode).
- **Audit's kill-all-15 (incl. `insights`)** — rejected: `insights` is genuinely referenced (ADR-0001).

## Consequences

- (+) Leaner, more navigable catalog (~275 skills); removes speculative session-management skills superseded by hooks/composites.
- (−) Lost capability is recoverable from git (canonical claude-env history) if a need surfaces.
- (~) `performance-test/skills-map.md` (generated) lists `api-design-principles`/`architecture-patterns` — regenerate it post-removal to drop the stale entries.

## Revisit when

- A removed skill's capability is actually needed in a session → restore from git rather than rebuild.
- `insights`' referencers (`session-wrap-up`/`ui-audit`) drop the dependency → re-evaluate `insights` for removal.
