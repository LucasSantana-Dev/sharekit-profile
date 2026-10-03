# sharekit-profile

A portable operator harness for Claude Code: skills, agents, hooks, standards and memory, installed from tracked source into a user's `~/.claude/`.

## Language

**Flywheel**:
An experimental, opt-in loop that proposes harness edits, trials them, gates them and deploys the winners. Not a default feature of the profile.
_Avoid_: self-improvement loop, auto-evolve, learning loop

## Flagged ambiguities

- "Flywheel" was documented in the README as a core, wired feature. It is an experiment: its observe hook is not installed by default.

## Example dialogue

> **Dev:** Does a fresh install collect trajectory telemetry for the **Flywheel**?
> **Maintainer:** No. The **Flywheel** is experimental and opt-in. Nothing feeds it unless you wire it yourself.
