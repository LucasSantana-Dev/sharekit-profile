# 2026-05-13 — auto-context-pack: bump timeout, monitor for 1 week, then kill if unused

## Status

Accepted. Sets a 1-week experiment window.

## Context

`~/.claude/hooks/auto-context-pack.sh` is a `UserPromptSubmit` hook that
queries the local RAG index (12,499 chunks, 45MB sqlite) for prompts
matching action verbs (`implement|refactor|fix|debug|...`) and injects a
1,800-token context pack into the response.

The hook log shows only `timeout` entries dating back to **2026-04-20**.
The internal `timeout 12 "$PACK_TOOL" "$PACK_SCRIPT" "$PROMPT" --budget
1800 --diff` is hitting its 12-second wall every time, so the hook exits
silently. Context packs haven't been injected on prompts for 3+ weeks.

Despite this, the 30-day cache hit rate is 97.4% and the token-audit
shows healthy session shapes. **So the question is: was the hook ever
actually adding value, or was it a placebo?**

## Research

### What `pack.py` does

1. Embeds the prompt
2. Cosine-similarity searches the local sqlite RAG (~12.5k chunks)
3. Reranks top-K results
4. Returns the top hits as a "code + standards + ADR" pack within a
   token budget

This is real work — for a 45MB index, the embedding + search + rerank
takes typically 8–20s on local CPU (no GPU). 12s is too tight.

### Why might it be obsolete

- **`autorecall-hook.sh`** (also on UserPromptSubmit) already injects
  smaller `<!-- Auto-recall -->` blocks pulled from RAG. We see those in
  every session. So a portion of the value `auto-context-pack` was
  designed to deliver is **already shipping via autorecall**.
- **`composite-router.sh`** intercepts intent and triggers composites that
  themselves load relevant context (e.g., `/context-pack`, `/route`).
- **Long sessions accumulate context anyway** — at 90%+ cache hit, most
  references are already warm in the prompt.

### Options

| Option | Cost | Risk | When it pays |
|---|---|---|---|
| **Bump timeout to 25s + monitor for 1 week** | trivial | hook eats 15–25s on every implementation prompt | if it materially improves task starts (subjective) |
| Rewrite `pack.py` to incremental (precomputed nightly cache) | medium (a few hours) | breaks if index schema changes | high-volume usage |
| Replace with `/context-pack` slash skill (user-invoked) | trivial | loses the auto- benefit | if users actually invoke it |
| Kill the hook entirely | trivial | lose unused capability | if 1-week experiment shows no value |

## Critic challenge

What changes the answer:

1. **The hook may be redundant.** `autorecall-hook.sh` runs on the same
   event and IS firing (`<!-- Auto-recall -->` blocks visible in this
   session). Two RAG-based hooks on the same event is suspicious overlap.
   Worth measuring whether `auto-context-pack` adds anything *beyond*
   what autorecall already injects.
2. **A 25s timeout on UserPromptSubmit is user-hostile.** Adds 25s to
   the first response of every action prompt. If the value is marginal,
   the latency cost outweighs the token cost.
3. **Bumping timeout doesn't prove value.** It just makes the hook fire.
   The 1-week experiment must include an explicit kill-if-unused gate,
   or this becomes another silently-dead hook.

The critic tightens but doesn't flip: bump-and-measure with a kill-gate
is the right shape.

## Decision

**Three-step rescue with a kill-gate:**

1. **Now:** bump `timeout 12` → `timeout 20` in
   `~/.claude/hooks/auto-context-pack.sh`. Also add explicit success
   logging so the hook reports when it does inject context vs when it
   times out.
2. **For 1 week (until 2026-05-20):** monitor the hook log. If it fires
   green on ≥5 prompts and the injected context is non-trivially used
   by the response (subjective judgement), keep.
3. **If at 2026-05-20 the log shows <5 green fires OR the injections
   were noise, kill the hook entirely.** Remove from `~/.claude/settings.json`'s
   `UserPromptSubmit` handler chain. `autorecall-hook.sh` carries the
   load.

The kill-gate is non-negotiable — that's what prevents this from
joining the silently-dead-hook category permanently.

## Consequences

### Positive (if it works)
- Restores the auto-context-pack behavior that was silently lost on Apr 20
- Verifies whether the hook adds value beyond autorecall

### Negative
- 20s latency added to every implementation prompt for 1 week
- The 25s cap doesn't account for slow days (network, swap pressure)
- If autorecall already covers the use case, this is dead weight

### Neutral
- Reversible at any time
- Doesn't affect other hooks

## Revisit when

- **2026-05-20** (1-week experiment ends — mandatory revisit)
- If the user explicitly notices missing context (positive signal — keep)
- If the 20s wait is itself flagged as friction (negative signal — kill
  early)

## Pairs with

- ADR `2026-05-13-model-tier-strategy.md` (Sonnet's faster output makes
  the 20s wait proportionally larger — accelerates the kill decision if
  hook value is marginal)
- ADR `2026-05-13-session-handoff-cadence.md` (fresh sessions are where
  this hook would have the most value — cold prompts on warm RAG)

## Implementation update — 2026-05-13T23:00Z

**Measurement fix:** original log only distinguished `green` vs `timeout-or-empty`,
so prompts that fell out at the short-prompt or regex-miss guards were invisible.
The kill-gate criteria "≥5 green fires by 2026-05-20" was therefore unmeasurable —
a "0 greens" reading couldn't distinguish "hook is broken" from "user wrote no
coding-intent prompts that week."

Rewrote `auto-context-pack.sh` to log five distinct exit paths:
`short` / `no-match` / `no-tool` / `timeout` / `green`. Also widened the trigger
regex from 11 → 19 keywords (added `optimize|audit|analyze|build|trace|verify|
harden|wire`). Backup at `auto-context-pack.sh.bak-2026-05-13b`.

**Revised kill-gate criteria for 2026-05-20 decision:**
- KEEP if `green_count >= 5` AND `green / (green + timeout) >= 0.7`
- KILL if `green_count < 5` AND `no-match` dominates (means regex still wrong,
  fix that instead of removing the hook)
- KILL if `timeout` dominates with `green_count < 5` (RAG pack tool too slow)

Synthetic test confirms the pipeline (RAG venv → pack.py → 1800-token output)
is healthy; first green entry produced at `2026-05-13T22:52:04Z`.
