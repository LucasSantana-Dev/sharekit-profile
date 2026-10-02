# Model tiering and token-cost discipline

Moved from CLAUDE.md (Wave A, 2026-10-02). Cache reads are billed at the model's rate and dominate session cost, so session and agent model choice is the first cost lever.

## Tiers

- **Fable 5** (apex, first choice for hard reasoning): hardest architecture decisions, cross-session synthesis, critic-of-critical work, consequential ADRs, multi-layer refactor planning, chains of 5+ reasoning steps. Gate on task difficulty, not on vibes: apex-priced cache reads apply to the whole session, so a Fable session should do apex work, not routine edits. In doubt, `/smart-model-select`.
- **Opus** (fallback, heavy but not apex): composite orchestration entrypoints, standard critic role, routine ADR writing. Use when Fable is unavailable or degraded. Demoted to second rung 2026-07-08.
- **Sonnet** (execution, default session): implementation, feature work, code review, test generation, single-phase sub-agent dispatch. Run routine execution sessions on Sonnet.
Subagent default comes from `CLAUDE_CODE_SUBAGENT_MODEL` in settings (sonnet here); agent frontmatter overrides it. Without that env var, subagents inherit the session model. Haiku is retired (2026-09-17): do not route new work to it.

**Changing the session model.** Only at a task boundary, after a handoff, in a fresh session: a changed model rewrites the whole cache. The one mid-session exception is low rate-limit headroom (advisory: `rate-limit-watch.sh` is currently unwired). Subagent models are unaffected; they come from frontmatter.

`/fast` is Opus with faster output, not a downgrade. Reasoning effort: `xhigh` for architecture, multi-layer refactors and ADR chains; lower for routine generation (settings default `high`).

## Token-lean turns and sessions

Every request re-reads the whole context, so turn count, context size and session length are the cost (measured 2026-09-29: 93% of usage came from sessions open 8h+, one open 7 days).

- One task per session. When it ships (PR merged, question answered), write the handoff and continue in a fresh session.
- Never resume a session idle past the 1h cache TTL for new work: the first reply re-writes the whole context. Start fresh from the handoff. `session-length-guard.sh` warns on both cases.
- Never spend a turn only to acknowledge an agent notification or say "still waiting". Act on the result or stay silent.
- `/code-review` runs one pass by default. Panel only above its size gate (~600 LOC or ~15 files) or on security-sensitive diffs.
- Batch independent tool calls into one message. Read only the lines needed.

## Provider rule

Bulk or batch agent work runs only on cache-capable Claude endpoints. No bulk runs on uncached third-party providers (glm, qwen, kimi via opencode, warp) without explicit user request: uncached input at scale caused four-figure single-day spend.
