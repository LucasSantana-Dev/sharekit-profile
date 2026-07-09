# Phase 5 — Implementation

Generate the actual runnable artifact. Choose one:

- **SKILL.md** — when invoked by human on demand
- **Workflow script** — when fully autonomous with parallel agents
- **Shell script** — when a simple linear CLI chain

For most loops: a SKILL.md (primary) + shell script (automation trigger).

See [loop-templates.md](loop-templates.md) for starter templates.

## Implementation constraints

The artifact must contain **actual runnable content** — real CLI flags, real file paths, real API commands. No placeholders like `<your-repo-here>` unless the value is genuinely unknown.

- Discovery agents: `agentType: "Explore"` (read-only)
- Checker/critic agents: `agentType: "critic"` or `"code-reviewer"`
- Memory writes: append-only — no silent overwrites
- Stop condition and escape hatch must appear explicitly in the artifact

Save as `implementation.md`.

**Done when:** implementation artifact created AND runnable (no placeholder tokens, actual CLI flags and paths).
