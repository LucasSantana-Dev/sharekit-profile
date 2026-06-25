# Troubleshooting Guide

Common problems and their solutions.

---

## Hooks

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Hooks not firing | Commands complete but no context injected | Check `~/.claude/tool-failures.log \| jq` | Increase timeout in settings.json, debug hook directly, check dependencies |
| RAG recall not working | No `# Knowledge graph context` block | RAG chunks stale or sparse | Run `/adt-rag-drift` to clean stale chunks, then `/adt-rag-index-rebuild` |
| Composite not detected | Intent matches but no `🎯 Composite match` emitted | Keyword not registered in router | Check `~/.claude/hooks/composite-router.sh`, add intent keyword |
| Slow UserPromptSubmit | Hangs 2-3s after prompt submit | RAG corpus too large or embedding slow | Reduce corpus; run `/adt-rag-coverage` to find sparse regions |
| Model tier wrong | Haiku suggested for complex task | Complexity classifier miscalibrated | Check `adt-smart-model-route` keyword tuning |
| Context bloat warnings spam | Multiple "compact available" per turn | Too many small tool outputs | Run `/compact` earlier; check if too many Read/Edit calls |
| Memory pull fails at SessionStart | Session hangs during memory sync | Network issue or corrupted memory file | Check `~/.claude/.sync.log`; verify frontmatter on memory files |

---

## Skills & Composites

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Skill bails with "out of scope" | Skill runs but returns no action | Skill definition mismatch or over-specific guard | Run `/skill-effectiveness-audit` to flag bail patterns |
| Composite skipped a phase | Composite completes but phase incomplete | Blocker not surfaced correctly | Check composite's reconciliation output; should say "Phase N blocked" |
| Sub-skill invoked instead of composite | You ran `/refactor` when `/refactor-pipeline` was available | Composite-router didn't fire or you overrode | Let composite-router guide you; invoke `/refactor-pipeline` next time |
| Agent ran out of context | Agent hits token budget mid-task | Task too large for single agent | Use `/dispatch` or `/orchestrate` to split across agents; increase context-pack budget |
| Parallel agents conflicting | Same files being edited by multiple agents | Missing worktree isolation | Ensure `isolation: "worktree"` on all parallel agents |

---

## Agents

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Agent spawn failed | "Agent type not found" or agent hangs | Agent definition missing or malformed | Check if agent exists: `ls ~/.claude/agents/ \| grep name`; verify YAML syntax |
| Analysis agent wrote files | Read-only agent modified code | agentType not set correctly | Verify agent uses write-incapable agentType (Explore, Plan, code-reviewer, etc.) |
| Subagent ignored instructions | Agent behaved differently than expected | Context not passed or agent type mismatched | Use fork for complex context; use fresh agent for simple work |
| Worktree cleanup didn't happen | Temporary worktree left behind | Worktree had uncommitted changes or symlinks | Manually clean: `rm -rf /Volumes/External\ HD/Desenvolvimento/.worktrees/<task>/` |

---

## RAG & Retrieval

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| RAG retrieval stale | Old file versions showing in search | Files changed since last index | Run `/adt-rag-drift` to detect + clean stale chunks |
| Low hit rate | Recall returns no relevant results | Corpus sparse or poorly embedded | Run `/adt-rag-coverage` to audit distribution by source type |
| Retrieval quality dropped after refactor | Search results became irrelevant | Files renamed/deleted but index not updated | Full reindex: `/adt-rag-index-rebuild` |
| Wrong document ranking | Top results are lower-relevance than lower-ranked | Embedding model drift or domain mismatch | Check if embeddings reflect current domain; consider `/rag-curate` for manual corpus improvement |

---

## Memory & Persistence

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Memory not persisting | Session ends but memory not saved | Sync failed at SessionEnd | Manually sync: `/sync-memories`; check `~/.claude/.sync.log` |
| Stale memory entries | Recalled memory references merged PRs or deleted files | Memory file has old entries | Run `/memory-prune` to audit + clean stale entries |
| Memory frontmatter invalid | Memory not loaded into recall | YAML/JSON frontmatter malformed | Check `~/.claude/memory/*.md` for proper format (see memory-structure/) |
| Memory index oversized | SessionStart warns "memory index >N entries" | Too many memory files accumulated | Run `/memory-prune`; delete obsolete project memories |

---

## Git & Version Control

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| PR merge blocked by protection rule | "Branch protection" error on merge | Human review required or other gates | Address all review comments; run `/verify-before-done` to pass all gates |
| Force push warning | "No force push to main" error | Trying to rebase main | Rebase against release branch instead; keep main linear |
| Worktree branch conflict | "Branch already exists" when creating worktree | Branch already checked out elsewhere | Remove old worktree first: `git worktree remove <path>` |
| Stale branch detection | SessionStart warns "main branch has drifted" | Upstream main has commits | Pull upstream: `git fetch origin main && git rebase origin/main` |

---

## Deployment & CI

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| CI checks failing | PR stuck on red CI | Check which step failed | Run `/gh-fix-ci` for automated triage + fix attempt |
| Slow CI run | CI taking 15+ minutes | Build cache stale or dependencies slow | Check CI logs; enable caching; upgrade hardware if bottleneck |
| Deployment stuck | Deploy starts but doesn't complete | Server unreachable or health checks failing | SSH into server; check logs; run rollback if needed |
| Rate limit hit | "Rate limit exceeded" error from GitHub API | Too many API calls in short window | Wait 1 hour or use `/smart-commands` to batch requests |

---

## Token & Performance

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Token budget hit | "Budget exhausted" mid-session | Session using too many tokens | Run `/token-audit` to analyze spend; use `/compact` for relief |
| Context bloat | Session becoming slow + expensive | Large tool outputs accumulating | `/compact` to compress (saves 30-40%); check if too many Bash calls |
| Mac resource pressure | Claude Code feels sluggish or hangs | CPU/memory/swap under stress | Run `/mac-optimize` to diagnose; check Activity Monitor for zombie processes |
| Model switching overhead | Context grows when switching models | Each model tier has different efficiency | Stick to Sonnet for most work; use Haiku for batch tasks; Opus only for reasoning |

---

## Mac & System

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| External HD not mounted | "Storage on External HD" error | Disk disconnected or not visible | Reconnect External HD; check `ls /Volumes/` |
| Git permission denied | SSH or HTTPS auth fails | Keys not loaded or wrong key | Load SSH key: `ssh-add ~/.ssh/id_ed25519`; check GitHub account settings |
| Node process high memory | Node heap >1GB (Claude Code slowdown) | Long session or memory leak | Restart Claude Code; check for zombie Node processes: `ps aux \| grep node` |
| Zsh profile issue | Hooks not running or env vars missing | Shell profile not loading | Check `~/.zshrc`; add to PATH if needed: `export PATH="$HOME/.claude/bin:$PATH"` |

---

## Debugging Strategies

### Before Escalating

1. **Check logs:**
   ```bash
   cat ~/.claude/tool-failures.log | jq '.[] | select(.type=="hook")' | tail -5
   ```

2. **Run diagnostic skill:**
   ```bash
   /audit-deep     # Full 7-dimension health check
   /token-audit    # Token spend analysis
   /skill-effectiveness-audit  # Skill bailing patterns
   ```

3. **Isolate the issue:**
   - Does it happen every time or intermittently?
   - What changed recently (hook update, file move, etc.)?
   - Is the issue local (this session) or global (all sessions)?

4. **Test minimal case:**
   - Try the same operation in a fresh session
   - Try with different model tier
   - Try with context compaction

### Getting Help

- **Policy questions:** Read `docs/configuration.md`
- **Skill not working:** `/find-skills <keyword>` or check `docs/skills/`
- **Agent issue:** Verify agent exists: `ls ~/.claude/agents/<name>`
- **Stuck:** Use `/route` to disambiguate intent or `/fallback` to recover
- **System health:** `/audit-deep` for comprehensive check

---

**Last updated:** 2026-06-25
