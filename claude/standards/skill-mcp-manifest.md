# Skill MCP Manifest (`mcp_servers:` frontmatter)

Ported from compozy's MCP-first agent shape ([[external_repo_eval_compozy_2026-06-18]]):
a skill declares the MCP servers it depends on, so it never silently runs degraded
because a required MCP isn't configured, and so subagent dispatch + forgekit
packaging know what to wire up.

## The field

In `SKILL.md` frontmatter, list the MCP server names the skill needs:

```yaml
---
name: recall
mcp_servers: [rag-index, claude-mem, serena]
---
```

Flow list `[a, b]` or block list (`- a` / `- b`) both parse. Omit the field for
skills that need no MCP (most skills). Use the canonical server names from
`skill-mcp-check.py --list-available` (sources: `settings.json` mcpServers,
`.mcp.json` mcpServers, and plugin-provided MCPs: claude-mem, serena, github,
playwright, supabase).

## Validate

```bash
python3 ~/.claude/scripts/skill-mcp-check.py recall      # one skill
python3 ~/.claude/scripts/skill-mcp-check.py --all       # every declaring skill; exit 1 if any MISSING
python3 ~/.claude/scripts/skill-mcp-check.py --list-available
```

Run `--all` as a lint (pre-commit / `/skill-effectiveness-audit` / before shipping
forgekit). A `MISSING` result means the skill will malfunction in this environment —
fix the declaration or configure the MCP before relying on the skill.

## Why it matters (three consumers)

1. **Validation** — catch "skill needs an MCP that isn't here" before runtime, not after a confusing empty/degraded result (the recall-during-unmount class of silent failure).
2. **Subagent dispatch** — when dispatching a subagent to run a skill, the manifest tells the orchestrator which MCPs to surface (ToolSearch hints) so the subagent isn't blind to them.
3. **forgekit packaging** — when packaging a skill for distribution, emit an `mcp.json` from `mcp_servers` (compozy's reusable-agent shape: `SKILL.md` + `mcp.json` in one directory) so installers know the dependencies. This is the highest-leverage forgekit portability win.

## Adoption status (2026-06-18)

- [OK] Field + parser + validator (`scripts/skill-mcp-check.py`).
- [OK] forgekit packager (`scripts/forgekit-package-mcp.py`) — emits `mcp.json` from the field (full config for configured servers; `{"plugin": ...}` marker for plugin MCPs).
- [OK] Lint wired into `/skill-effectiveness-audit` step 0 (`--all`, exit 1 on MISSING).
- [OK] Backfilled across all MCP-using skills (manifest computed by a discovery workflow that distinguishes real MCP-tool calls from CLI/script usage).
- Declared on: recall, sync-memories, rag-curate, + the backfilled set.
