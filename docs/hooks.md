# Hooks: Automation Lifecycle

Hooks are shell scripts wired to Claude Code tool events. They are **zero-overhead on success** (exit 0 = silent), **auto-killed at timeout** (3-5s default), and logged on failure.

This document describes every hook event and what fires.

---

## SessionStart (fires once per session)

Runs when you open Claude Code CLI. Prepares the operator environment.

### Event Order
1. **Check session lock** — warn if another live session owns this checkout (not in a worktree)
2. **Log session start** — timestamp + branch + context size
3. **Merge stale RAG chunks** — integrate recent file changes into live retrieval index
4. **Pull latest memories + ADRs** — sync from `~/.claude-env` to local working state
5. **Detect and reindex drifted files** — if files changed outside the session, update index
6. **Alert if main branch has drifted** — warn if upstream main has commits not in local
7. **Alert if memory index oversized** — flag if memory database >N entries (suggest `/memory-prune`)

### Purpose
Ensure the operator starts with fresh context — no stale RAG chunks, up-to-date memories, and awareness of upstream changes.

### When It Fails
- **Concurrent session warning** — another session is using this checkout; switch to a worktree or stash uncommitted work
- **Slow pull (>3s)** — network or large memory sync; increase timeout in `settings.json`
- **RAG reindex fails** — corrupted chunks or missing files; run `/rag-maintenance` and rebuild only when thresholds require it
- **Memory pull fails** — check `~/.claude/.sync.log`; verify frontmatter

---

## UserPromptSubmit (fires on every prompt)

Runs when you submit a prompt. Injects context and routes to the right model/skill.

### Event Order
1. **Auto-recall** — semantic search on RAG index, inject `# Knowledge graph context` block if hits found
2. **Classify prompt complexity** — scan for keywords (multi-agent, debug, refactor, etc.) → simple/moderate/complex/xcomplex
3. **Emit model tier hint** — Haiku/Sonnet/Opus suggestion based on complexity
4. **Log turn count** — increment session turn counter
5. **Warn if context >85%** — emit "compact available" hint
6. **Composite detection** — if intent matches a composite skill, emit `🎯 Composite match: /<name>`
7. **Warn if on release branch** — alert before making commits to release branches

### What Gets Injected

If RAG finds hits, a block like this appears above your prompt:
```
# Knowledge graph context
[Similar doc 1]: relevance 0.89 — excerpt
[Similar doc 2]: relevance 0.76 — excerpt
...
```

Use this as a starting point; the assistant may still need to Read files for full context.

### Purpose
- Accelerate decision-making by pre-loading relevant prior reasoning
- Route to right model tier automatically
- Detect composite skills so you don't bypass phases
- Warn about context/branch state before commits

### When It Fails
- **RAG recall slow** — too many chunks or poor embedding; run `/rag-maintenance` to measure coverage and drift
- **Composite not detected** — check if intent maps to an active workflow in `docs/composites.md`
- **Model tier hint wrong** — follow `AGENTS.md` model-tier policy and tune the classifier if the mismatch repeats

---

## PreToolUse (safety gates)

Runs before each tool is executed. Blocks dangerous or wasteful operations.

### Filters

**Dangerous bash:**
- `rm -rf`, `sudo rm`, `dd`, destructive patterns
- **Action:** Block and warn

**Protected paths:**
- `~/.ssh`, `~/.aws`, `/etc`, system files
- **Action:** Block and require explicit user confirmation

**Re-read same file:**
- Detects `Read` on a file already read in this session
- **Action:** Block and suggest using context from prior read

### Purpose
Prevent accidental data loss, credential exposure, and token waste.

### When It Triggers
- Trying to delete uncommitted work: "Use `git stash` first"
- Reading a 100MB file: "File >25KB; consider grep or Edit instead"
- Re-reading same file twice: "Already read; use prior output"

---

## PostToolUse (observe & learn)

Runs after each tool completes. Logs usage, detects patterns, reindexes changes.

### By Tool Type

**[Bash]**
- Detect bash that could use Read/Search tools (e.g., `bat -p file.ts | rg pattern`, or direct Read/rg when available)
- Flag missed optimization opportunities

**[Read]**
- Warn if >25KB
- Log which files were read
- Detect if same file read twice (redundancy warning)

**[Write|Edit]**
- Reindex changed files into RAG
- Detect skill writes (validate against skill manifest)
- Warn if >3 edits in one turn (context bloat indicator)

**[*]**
- Log turn count
- Check token budget
- Warn if approaching API rate limits

### Purpose
- Learn usage patterns for model tier routing
- Keep RAG index fresh
- Warn about inefficient patterns (wasteful reads, edit spam)
- Catch token budget overruns early

---

## PreCompact / PostCompact (context snapshots)

Runs before and after context compaction (when >85% full).

### PreCompact
- Snapshot current conversation state
- Log what will be compressed
- Save to `.claude/compaction-snapshots/`

### PostCompact
- Snapshot compressed state
- Log compression ratio (e.g., "85% → 40%")
- Verify no critical context was lost

### Purpose
Track compaction effectiveness and enable recovery if compression loses important context.

---

## Stop (session interrupt)

Runs when you stop the session (^C or explicit stop).

### Actions
1. Log session token usage
2. Check API rate limits
3. Capture any uncommitted state
4. Write to `~/.claude/session-log.jsonl`

### Purpose
Accurate token accounting + rate limit awareness.

---

## SessionEnd (cleanup)

Runs when session closes (normal or timeout).

### Actions
1. Sync RAG chunks to persistent storage
2. Sync memories to `~/.claude-env`
3. Archive session transcript to `~/.claude/transcripts/`
4. Log final token count

### Purpose
Persist all state so work can resume without loss.

---

## Hook Configuration

Hooks are registered at two levels:

**`.claude/settings.json` (project-level, version-controlled, ACTIVE)**
- Loaded automatically by Claude Code from the `.claude/` directory
- **This is the file that must exist for live sessions to wire hooks and collect telemetry**
- Currently enables the essential PostToolUse trajectory logging hook
- See [`.claude/settings.json`](../.claude/settings.json)

**`claude/settings.json` (shipping artifact, reference only)**
- Used by harness installers to seed hooks into new deployments
- NOT loaded by Claude Code in live sessions (only `.claude/` variants are auto-loaded)
- Contains full reference implementations of all available hooks
- Reference for hook definitions and configurations

### Currently Active Hooks (in `.claude/settings.json`)

| Event | Script(s) | Blocks? |
|-------|-----------|---------|
| `PostToolUse` | `trajectory-log.sh` (observe all tool calls for the self-improvement flywheel — ADR wave 4 telemetry clock) | no |

Additional hooks can be added to `.claude/settings.json` as needed for safety gates (PreToolUse), session logging (SessionStart/SessionEnd), etc. See `claude/settings.json` for reference implementations.

Exit code 2 is the only blocking code; all other exits are advisory/log-only. See [`hook-firing-order.md`](hook-firing-order.md) for the positional contract and [`flywheel.md`](flywheel.md) for how the observe hooks feed the self-improvement loop.

### Timing Out
Hooks timeout at 2-10s per the `timeout` field in `settings.json`. To increase:

### Debugging

View hook output:
```bash
bat ~/.claude/tool-failures.log | jq '.hooks | last'
```

Run a hook manually:
```bash
bash ~/.claude/hooks/autorecall-hook.sh
echo "Exit code: $?"
```

### Disabling

To disable a hook temporarily:
```bash
# In ~/.claude/settings.local.json
{
  "disabledHooks": ["adt-smart-model-route"]
}
```

---

## Common Hook Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Concurrent session warning | Warning at SessionStart / PreToolUse about another session | Use a separate worktree: `git worktree add '/Volumes/External HD/Desenvolvimento/.worktrees/<task>' -b <branch>` |
| RAG not recalling | No `# Knowledge graph context` block | Run `/rag-maintenance` |
| Composite not detected | Intent matches but no `🎯` emitted | Use active workflow table in `docs/composites.md` |
| Slow UserPromptSubmit | Hangs after prompt submit | Reduce RAG corpus size through `/rag-maintenance` |
| Model tier wrong | Haiku suggested for complex task | Check `adt-smart-model-route` keyword tuning |
| Context bloat warning spam | Too many warnings per turn | Compact earlier; run `/compact` |
| Memory pull fails | SessionStart hangs on memory sync | Verify network; check `~/.claude/.sync.log` |

---

**Last updated:** 2026-07-01 (added check-session-lock.sh for concurrent session detection)
