# Cross-tool hard-rule parity (CLAUDE.md ↔ Codex AGENTS.md)

- Date: 2026-05-28
- Status: Accepted
- Decision pipeline: `/research-and-decide` (4-surface env sweep → verify → critic → this ADR)

## Context

An environment-organization sweep (4 parallel research agents) surfaced many candidate improvements; Phase-1 verification deflated most of them (PR-toolchain "absent" was false — Lucky has `review-tools.yml`; memory "208 snapshots / 49% orphaned" was a miscount; RAG "flat 0.55" ignored a 0.821-MRR config). One finding survived verification and matters:

**`~/.codex/AGENTS.md` (634 lines) is missing 5 hard rules that exist in `~/.claude/CLAUDE.md`:**
1. **PR-automation-halt** — the operator's ABSOLUTE rule (never automate on a PR with another person's comments / another's open PR). Safety-critical.
2. Parallel-execution-mandatory.
3. Idempotency state-check-before-mutation.
4. No-Co-Authored-By / no AI-attribution.
5. Storage policy (external drive).

Skills (250/250) and `standards/` are already in parity via symlink (`~/.codex/standards → ~/.claude/standards`). The drift is isolated to the **hand-maintained top-level rules files** — CLAUDE.md's "Hard rules" were copied into AGENTS.md once and diverged since. Codex loads AGENTS.md as its system prompt and could currently violate these rules.

## Decision

**Hand-copy the 5 rules from CLAUDE.md into AGENTS.md now** (adapting #2 for Codex, which lacks Claude's `Agent()` — keep the decompose-independent-work principle, drop the Claude-specific mechanism). Closes the safety gap immediately.

## Alternatives considered

- **Canonical `standards/hard-rules.md` referenced by both** — superior on DRY, **but REJECTED**: verified 2026-05-28 (high confidence, per OpenAI Codex CLI docs + setup inspection) that Codex loads ONLY AGENTS.md + the dir hierarchy — there is **no `@import`/reference mechanism**. A referenced canonical file is inert; the rules must be physically present in AGENTS.md regardless of the symlinked `standards/`. The only viable DRY path is extending `~/.codex/scripts/sync-claude-mirror.py` to copy rule *content* on sync — an automation addition, pull-gated.
- **Automated drift-check / CI** — **rejected**: over-engineered for ~100 lines of stable rules; new tooling fails the pull-signal bar (no documented past-tense drift friction; this is the first surfaced instance).
- **Accept the drift** — **rejected**: PR-halt is the ABSOLUTE safety rule; a Codex incident (auto-acting on a human-commented PR) is unacceptable.

## Consequences

- (+) Codex immediately carries the operator's safety/behavioral rules.
- (−) Dual hand-maintenance of the rules persists — mitigated by a human checklist ("rule edit → update BOTH CLAUDE.md and AGENTS.md"), not automation.
- (~) The canonical-shared-file refactor is off the table — Codex cannot load referenced files. Hand-copy is the permanent model; dual-maintenance is mitigated by the checklist + (if pull emerges) a content-copying sync script.

## Revisit when

- Rule drift recurs within 30 days → escalate to option 3 (automation now has pull).
- Rule drift recurs ≥2× → extend `sync-claude-mirror.py` to copy rule content (automation now has pull).
- A new hard rule is added to CLAUDE.md → apply the checklist, update AGENTS.md in the same change.
