# Session Resume

Several sessions may work the same repo at once, so there is no single `latest.md`.
Each session writes its own `~/.claude/handoffs/<repo>/<date>-<slug>.md` (`/handoff`).

On session start or task re-entry:
1. `~/.claude/skills/handoff/bin/handoffs list` shows the open handoffs of this repo (the SessionStart hook prints it too).
2. `/resume N` (or `/resume <part of name>`) loads one. Several open and no choice: ask, never guess.
3. Finished topic: `~/.claude/skills/handoff/bin/handoffs done <part-of-name>` moves it to `<repo>/done/`.
4. Then the latest plan in `.claude/plans/` or `.agents/plans/`, and `.agents/memory/in-progress.md`.

PreCompact writes `<repo>/auto/<session_id>.md`, one per session, never a shared slot.
Do not treat a clean working tree as proof that work is complete.
