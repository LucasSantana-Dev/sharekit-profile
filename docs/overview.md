# Claude Code Harness: Overview

**Quick reference guide for the complete Claude Code operator environment with 162+ skills, ~40 agents, automated hooks, RAG retrieval, and persistent memory.**

---

## What This Is

A fully-configured Claude Code harness profile named **sharekit-profile** (v0.7.0) that provides:
- **162+ skills** across 18 categories — autonomous entry points for common tasks
- **~40 specialized agents** for analysis, execution, and multi-agent orchestration
- **30+ automated hooks** wired to development events (session start, prompt submission, tool use)
- **Persistent memory system** (file-based, queryable across sessions)
- **RAG index** for semantic code and documentation search
- **6 local MCP servers** + 15+ cloud-based integrations
- **ADR vault** for architecture decision capture and recall

---

## Getting Started

### First Time

```bash
claude   # Opens Claude Code CLI
```

The SessionStart hook automatically:
- Pulls latest memories and ADRs from `~/.claude-env`
- Reindexes any drifted RAG chunks
- Alerts if main branch has diverged
- Alerts if memory index is oversized

### Every Prompt

When you submit a prompt, UserPromptSubmit hooks fire in sequence:
1. **Auto-recall** — semantic search injects `# Knowledge graph context` block
2. **Model tier routing** — Haiku/Sonnet/Opus selected by complexity
3. **Composite detection** — if your intent matches a composite skill, emits `🎯 Composite match: /<name>`
4. **Context packing** — if >85% full, warns and suggests `/compact`

---

## Daily Workflow

| Goal | Use This | Why |
|------|----------|-----|
| Understand blocking work | `/session-bootstrap` | Chains wake-up → next-priority → pr-snapshot → context-pack |
| Plan multi-step work | `/plan` | Validation-gated planning with rollback identification |
| Execute parallel tasks | `/dispatch` or `/orchestrate` | Fans out independent work, reconciles results |
| Review before merge | `/code-review` | Severity-rated findings (bugs > security > style) |
| Debug production issue | `/debug` or `/debug-deep` | Systematic root-cause analysis with Sentry/CI triage |
| Full health check | `/audit-deep` | 7-dimensional project audit (tests, config, hooks, security, MCP, plugins) |
| Refactor a module | `/refactor-pipeline` | Full chain: plan → 3-agent team → test cleanup → ADR → docs-sync |
| Ship work | `/session-wrap-up` | Full chain: verify → ship → memory-sync → handoff |

---

## Directory Structure

### Local (`~/.claude/`)
```
CLAUDE.md              # Global operator configuration
SKILLS.md              # Skill index + descriptions (162 skills)
settings.json          # Hook definitions + env config
settings.local.json    # Local overrides + project hooks
agents/                # ~40 specialized agent definitions
hooks/                 # ~30 shell scripts for automation
memory/                # Persistent memory database
handoffs/              # Session checkpoint packets
plans/                 # Implementation plan files
tasks/                 # Task tracker state
rag-index/             # RAG corpus + reindex hooks
workflows/             # Saved Workflow() scripts
plugins/               # Installed Claude Code plugins
templates/             # Reusable artifact templates
standards/             # Policy and discipline docs (symlink)
skills/                # Skill catalog (symlink)
```

### Canonical (`~/.agents/`)
```
skills/                # 162 skill folders (canonical)
standards/             # Policy and discipline docs (~20 files)
agents/                # Agent definition mirrors
memory/                # Memory archive
bin/                   # Utilities (sync binary)
scripts/               # Helper scripts
```

### Environment (`~/.claude-env/`)
```
adrs/                  # Architecture Decision Records
bin/sync               # Sync push/pull for memories + ADRs
hooks/                 # Env-level hooks
... (config, memory, scripts)
```

---

## Key Concepts

### Skills vs. Agents

**Skills** are entry points you invoke directly (via `/skill-name`). They are routing + orchestration layers that chain other skills or dispatch agents.

**Agents** are autonomous workers you rarely invoke directly. They run in their own context and write code. Skills dispatch agents and reconcile results.

### Composites

Skills marked with `*` are **composites** — they auto-chain multiple sub-skills with gates and validation between phases. Always prefer a composite when available; running sub-skills manually bypasses critical phases.

Example: `/refactor-pipeline` chains:
- **discovery** → `/refactor-plan` 
- **execution** → 3-agent team (architect, builder, reviewer)
- **testing** → `/test-cleanup` → `/mutation-test`
- **capture** → `/adr-write` → `/docs-sync`

If you run `/refactor` directly, you skip the planning and ADR phases — wrong.

### Model Tiering

- **Haiku** — Mechanical tasks (formatting, grep, symbol lookup, simple renames), subagent batch work
- **Sonnet** (default) — Implementation, feature work, code review, test generation
- **Opus** — Orchestration, critic role, architectural decisions, ADR writing

Use `/smart-model-select` before multi-agent or long-running work. Never override for speculative speed.

### Parallel Execution

For ≥2 independent tasks:
1. Dispatch one **Agent** per task in a **SINGLE tool-use block**
2. If same repo, use worktrees: `/Volumes/External HD/Desenvolvimento/.worktrees/<task>-<n>/`
3. Set correct `agentType` (analysis agents: read-only; execution agents: write)
4. In Workflow scripts: use `parallel()` for barriers, `pipeline()` for independent stages

Running independent work sequentially is a contract violation.

---

## Hooks: What Fires When

### SessionStart (once per session)
- Log session start
- Merge stale RAG chunks into live index
- Pull latest memories + ADRs from env
- Detect and reindex drifted files
- Alert if main branch has drifted
- Alert if memory index oversized

### UserPromptSubmit (every prompt)
- Auto-recall: semantic search, inject `# Knowledge graph context`
- Classify prompt complexity (simple/moderate/complex/xcomplex)
- Emit model tier hint (Haiku → Sonnet → Opus)
- Log turn count
- Warn if context >85%, suggest `/compact`
- Emit `🎯 Composite match: /<name>` if intent matches composite
- Warn if on release branch

### PreToolUse (safety)
- Filter dangerous bash (rm -rf, sudo rm, etc.)
- Block writes to protected paths
- Block re-reading same file twice

### PostToolUse (observe)
- `[Bash]` → detect missed read-tool-kick opportunities
- `[Read]` → warn if >25KB, log which files read
- `[Write|Edit]` → reindex changed files
- `[Edit]` → warn if >3 edits in one turn

### SessionEnd (cleanup)
- Sync RAG and memories to persistent storage
- Log session token usage

---

## Configuration Highlights

### Hard Rules (Non-Negotiable)
1. **Never automate PRs with human reviewer comments** — must be manual
2. **Parallel execution mandatory for ≥2 independent tasks** — use worktrees for same-repo
3. **Analysis subagents read-only by agentType** — not just prompt ("read-only" doesn't prevent writes)
4. **No big-bang rewrites without demand measurement gate** — measure usage first
5. **Idempotency: state-check before mutation** — skip if target state already satisfied
6. **Dispatcher ≠ executor boundary** — no logic in orchestrators
7. **Repository as single source of truth** — commit decisions before agents act
8. **No Claude co-author attribution** — commits/PRs authored by Lucas Santana
9. **Storage on External HD** — `/Volumes/External HD/Desenvolvimento/`
10. **Stuck protocol** — >2 attempts without progress → surface, switch approach, escalate

### Default Behaviors
- **Caveman mode ON** — terse, drop filler, keep technical substance
- **Skill-first execution** — skills invoked autonomously when matching
- **Composite-first** — composite-router detects intent, emits `🎯 Composite match: /<name>`
- **Graph-first token discipline** — query graph before file reads
- **Signal-first output** — verdict + top-3 findings; "X more — ask for full list" if >3

---

## MCP Servers & Integrations

### Local
- **rag-index** — semantic search on local knowledge base
- **tavily** — web search
- **fetch** — fetch URLs
- **firecrawl** — web scraping/crawling
- **sonarqube** — code quality analysis
- **graphify** — knowledge graph queries

### Cloud (via claude.ai)
Context7, Gmail, Google Calendar, Google Drive, Hugging Face, Jam, Linear, Sentry, Vercel, Cloudflare, GitHub, Playwright, Supabase, Serena, codebase-memory-mcp, filesystem, claude-mem

### Plugins Installed
Vercel, GitHub, Firecrawl, Supabase, CodeRabbit, Skill Creator, Claude Code Setup, Claude MD Management, Claude Mem, LLM Docs Optimizer, Plugin Dev

---

## Getting Help

- **Skill reference** — `/find-skills <keyword>` or browse `docs/skills/`
- **Policy questions** — Read `docs/configuration.md` and `docs/troubleshooting.md`
- **Hook debugging** — Check `~/.claude/tool-failures.log`
- **Token analysis** — `/token-audit` for weekly spend review
- **System health** — `/audit-deep` for full project + harness check
- **Stuck** — `/route` to disambiguate intent or `/fallback` to recover

---

**Last updated:** 2026-06-25  
**Harness version:** Agent-OS v6+, 162 skills, ~40 agents, 30+ hooks
