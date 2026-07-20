# Session Resume

On session start or task re-entry:
1. Check `~/.claude/handoffs/<project>/latest.md`.
2. Check `~/.claude/handoffs/latest.md`.
3. Check the latest plan in `.claude/plans/` or `.agents/plans/`.
4. Check `.agents/memory/in-progress.md` if it exists.

If a handoff exists, continue from the stated next action.
Do not treat a clean working tree as proof that work is complete.
