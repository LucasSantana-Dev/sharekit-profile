# MCP Development Skills

`adt-mcp-patterns` for building a new MCP server; `hook-development` / `command-development` for extending Claude Code. `mcp-care` (composite) for a full health check. `adt-mcp-doctor` when a server fails to start.

---

## /adt-mcp-patterns

Build robust MCP servers — tool schemas, stateful interactions, error handling, tool composition.

**Patterns:**
- **Tool schemas:** Zod for validation, clear descriptions
- **Stateful interactions:** Resource memory between tool calls
- **Error handling:** Graceful degradation + user feedback
- **Tool composition:** One tool enables others (e.g., list, then get)
- **Authentication:** API keys, OAuth, token management

**When to use:** Building new MCP server

**Output:** MCP patterns reference + templates

---

## /mcp-builder

Guide for creating high-quality MCP servers from scratch.

**Covers:**
- Server bootstrapping (Node.js, Rust, Python)
- Tool definition (name, description, schema)
- Resource registration
- Prompt management
- Testing + validation
- Publishing + documentation

**When to use:** MCP server development end-to-end

**Output:** MCP server guide + starter code

---

## /mcp-audit

Read-only diagnostic — scan session transcripts to surface which MCP servers/tools you actually use. Flag zero-use servers.

**Finds:**
- Active servers (tools used in session)
- Zero-use servers (configured but never invoked)
- Under-used servers (rarely invoked)
- Performance metrics (latency, failures)

**When to use:** Optimize MCP configuration; identify bloat

**Output:** MCP usage audit report

---

## /mcp-care ⭐⭐ **Composite**

Full MCP server lifecycle audit and repair: mcp-audit → mcp-health → mcp-doctor → mcp-builder suggestions.

**Phases:**
1. **Audit:** Session transcript scan (which servers used?)
2. **Health:** Validate live provider health (config vs. auth vs. connectivity)
3. **Doctor:** Diagnose + repair failing servers
4. **Builder:** Suggest improvements to server implementations

**When to use:** MCP server not working or full lifecycle audit

**Output:** Healthy MCP servers + recommendations

---

## /adt-mcp-doctor

Diagnose and repair failing MCP servers. Captures real launch tracebacks, identifies stale config, prunes bad entries.

**Diagnoses:**
- Missing dependencies
- Invalid configuration (JSON errors)
- Authentication failures
- Network connectivity issues
- Process failures (crashes)

**Repairs:**
- Fix configuration
- Update dependencies
- Reset credentials
- Restart server

**When to use:** MCP server failing to start or connect

**Output:** Diagnosed issue + repair steps

---

## /adt-mcp-health

Validate live MCP provider health — separate config issues from auth and connectivity failures.

**Checks:**
- Configuration validity (JSON/YAML parse)
- Server startup (process starts without errors)
- Authentication (credentials accepted)
- Connectivity (can reach remote service)
- Tool availability (tools listed + callable)

**When to use:** MCP server acting up; health check

**Output:** Health report per check

---

## /adt-mcp-readiness

Check whether MCP-backed workflows are usable on this machine.

**Checks:**
- All MCP servers running
- All dependencies installed
- Network connectivity
- Authentication credentials valid

**When to use:** Before running MCP-dependent workflow

**Output:** Readiness verdict (ready or blocked)

---

## /hook-development

Create hooks for Claude Code plugins — hook events, config, exit codes, stdin/stdout contracts.

**Hook events:**
- SessionStart (once per session)
- UserPromptSubmit (every prompt)
- PreToolUse (before tool execution)
- PostToolUse (after tool execution)
- SessionEnd (cleanup)

**Config:**
- Timeout (ms)
- Silent on success (exit 0)
- Log on failure
- Environment variables

**When to use:** Creating Claude Code hook plugin

**Output:** Hook script + configuration

---

## /command-development

Create, write, or organize slash commands — frontmatter, dynamic arguments, file references, bash execution.

**Frontmatter:**
```markdown
---
name: command-name
description: One-line description
argument: optional argument syntax
---
```

**Features:**
- Dynamic arguments (file paths, selections)
- Bash execution
- Output formatting
- Error handling

**When to use:** Creating Claude Code slash command skill

**Output:** Command script with proper structure

---

## /hook-effectiveness

Audit Claude Code hooks for fire frequency, latency, exit codes, and output value. Required after wiring new hooks.

**Audits:**
- Fire frequency (does hook run when expected?)
- Latency (how long does hook take?)
- Exit codes (success vs. failure)
- Output value (does output help user?)
- Noise (false positives, spam)

**When to use:** After wiring new hook; optimize existing hooks

**Output:** Hook effectiveness report + recommendations

---

**Last updated:** 2026-06-25
