---
name: memory-promote
description: Promote a personal-scope session learning into team scope through curated review. Strips private-tagged content and secret-shaped strings, then produces a reviewable artifact (PR-style proposal) instead of writing shared memory directly. Use when a personal memory note is worth sharing with the team. Enforces .harness/memory-scopes.json promotion rules.
triggers:
  - promote memory
  - share this learning
  - move to team memory
  - publish memory note
metadata:
  owner: global-agents
  tier: contextual
---

# Memory Promote

Extends cooperative-mode memory isolation from "never leak" to "curated
sharing". Personal memory stays private by default; sharing is an explicit,
reviewable act. Policy: `.harness/memory-scopes.json` (promotion requires
review; private tags never promote).

## Flow

1. **Select.** Identify the personal-scope note to promote
   (`~/.claude/projects/<slug>/memory/` or `.agents/memory/personal/`). If the
   user gave no path, list recent personal notes and let them pick.
2. **Strip.** Remove, in order:
   - `<private>...</private>` tagged spans entirely (never promoted, per policy)
   - secret-shaped strings (tokens, keys, emails, internal hostnames, personal
     paths) — replace with a `[redacted: <kind>]` placeholder
   - names of people not on the team, unless the user confirms
3. **Propose.** Write the stripped note to a review artifact, never directly
   to shared memory:
   - target: `.agents/memory/proposals/<YYYY-MM-DD>-<slug>.md`
   - include a header: source scope, author, date, what was stripped
4. **Review gate.** Run `hooks/memory-scope-gate.sh` semantics against the
   proposal: if any `<private>` tag or personal-scope path reference survives,
   stop and report — do not submit. Present the diff to the user for explicit
   approval.
5. **Submit.** Only after user approval: push the proposal through the team
   vault — `bash scripts/team-memory-sync.sh push <proposal.md>` (requires
   `.harness/team-vault.json`; the transport re-checks for `<private>` tags
   and refuses them). The note lands in the shared vault repo; teammates
   receive it on their next `team-memory-sync.sh pull`. If the team vault is
   a PR-governed repo, open the vault PR instead of a direct push. Record the
   promotion in the note header.

## Hard rules

- Never write to team/org scope directly; the proposal artifact is the only
  path.
- Never promote `<private>`-tagged content, even if the user asks — strip or
  refuse.
- If `.harness/memory-scopes.json` is absent, behave as solo: warn that no
  team scope is declared and stop after step 3.
- Batch promotion (>5 notes) requires one approval per note, not a blanket yes.
