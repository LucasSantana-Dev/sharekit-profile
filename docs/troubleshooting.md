# Troubleshooting Guide

Common problems and their solutions for the 50-skill consolidated catalog.

---

## Hooks

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Hooks not firing | Commands complete but no context injected | Inspect `~/.claude/tool-failures.log` with `bat`/`jq` | Increase timeout, debug hook directly, check dependencies |
| RAG recall not working | No `# Knowledge graph context` block | RAG chunks stale, sparse, or External HD unavailable | Run `/rag-maintenance` and verify mount guard first |
| Composite not detected | Intent matches but no `🎯 Composite match` emitted | Keyword not registered or wrapper archived | Invoke the active equivalent from `docs/composites.md` |
| Slow UserPromptSubmit | Hangs after prompt submit | RAG corpus too large or embedding slow | Run `/rag-maintenance` coverage/drift pass |
| Model tier wrong | Haiku suggested for complex task | Complexity classifier miscalibrated | Follow model-tier policy in `AGENTS.md` |
| Context bloat warnings spam | Multiple compact warnings | Too many small tool outputs | Compact earlier and prefer targeted reads/searches |
| Memory pull fails at SessionStart | Session hangs during memory sync | Network issue or malformed memory file | Inspect sync log and memory frontmatter |

---

## Skills & Composites

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Archived command appears in memory/docs | Recall suggests old wrapper name | Historical memory predates 50-skill catalog | Use the active replacement table in `docs/composites.md` |
| Composite skipped a phase | Workflow completes but phase incomplete | Blocker not surfaced correctly | Re-run active workflow and require reconciliation output |
| Broad refactor started too small | `/refactor` used for cross-module work | Planning/orchestration phase skipped | Use `/request-refactor-plan` then `/orchestrate` or `/three-man-team` |
| Agent ran out of context | Worker hits token budget mid-task | Task too large for single lane | Use `/dispatch` or `/orchestrate`; increase context-pack budget |
| Parallel agents conflicting | Same files edited by multiple agents | Missing worktree isolation | Use one worktree/branch per write-capable lane |

---

## Agents

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Agent spawn failed | "Agent type not found" or agent hangs | Agent definition missing or malformed | Verify agent file and YAML syntax |
| Analysis agent wrote files | Read-only agent modified code | permission/agentType boundary wrong | Use read-only-by-construction analysis roles |
| Subagent ignored instructions | Agent behaved differently than expected | Context not passed or agent type mismatched | Use fresh scoped agent with explicit handoff |
| Worktree cleanup didn't happen | Temporary worktree left behind | Worktree has uncommitted changes or symlinks | Inspect state, then remove only safe/merged worktrees |

---

## RAG & Retrieval

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| RAG retrieval stale | Old file versions showing in search | Files changed since last index | Run `/rag-maintenance` drift and curation phases |
| Low hit rate | Recall returns no relevant results | Corpus sparse or poorly embedded | Run `/rag-maintenance` coverage and weak-hit analysis |
| Retrieval quality dropped after refactor | Search results irrelevant | Files renamed/deleted but index not updated | Run `/rag-maintenance`; rebuild only if thresholds require it |
| Wrong document ranking | Top results lower-quality than later results | Embedding drift or weak source chunk | Curate source text through `/rag-maintenance` |

---

## Memory & Persistence

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Memory not persisting | Session ends but memory not saved | Sync failed at SessionEnd | Run `/knowledge-loop`; inspect sync log |
| Stale memory entries | Recall references merged PRs, deleted files, or archived skills | Historical memory is stale | Run `/memory-prune` or add a superseding memory |
| Memory frontmatter invalid | Memory not loaded into recall | YAML/JSON frontmatter malformed | Fix frontmatter and reindex through `/rag-maintenance` |
| Memory index oversized | SessionStart warns about index size | Too many obsolete memory files | Run `/memory-prune`; preserve history with supersession links |

---

## Git & Version Control

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| PR merge blocked by protection rule | Branch protection error | Human review or required gates missing | Address comments and run `/quality-gates` + `/pr-merge-readiness` |
| Force push warning | "No force push to main" error | Trying to rewrite protected branch | Rebase a feature branch; keep protected branches linear |
| Worktree branch conflict | Branch already exists | Branch checked out elsewhere | Inspect worktrees before removing anything |
| Stale branch detection | SessionStart warns main drifted | Upstream main has commits | Fetch/rebase according to repo policy |

---

## Deployment & CI

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| CI checks failing | PR stuck on red CI | Required check failed | Use `/ci-watch`, then `/debug` for root cause |
| Slow CI run | CI taking 15+ minutes | Cache or dependency bottleneck | Inspect CI logs and cache configuration |
| Deployment stuck | Deploy starts but does not complete | Server or health check failure | Follow project rollback/incident procedure |
| Rate limit hit | GitHub/API rate exceeded | Too many API calls | Wait or batch requests through approved tooling |

---

## Token & Performance

| Problem | Symptom | Diagnosis | Fix |
|---------|---------|-----------|-----|
| Token budget hit | Budget exhausted mid-session | Session using too many tokens | Use `/context-pack`, compact, and split work |
| Context bloat | Session slow/expensive | Large tool outputs accumulating | Prefer targeted reads and compact earlier |
| Mac resource pressure | Harness feels sluggish | CPU/memory/swap pressure | Inspect system resources and reduce parallel local agents |
| Model switching overhead | Context grows after model switches | Cache prefix disrupted | Switch only at safe boundaries |

---

## Debugging Strategies

### Before Escalating

1. Inspect logs with `bat`/`jq`.
2. Run active diagnostics: `/quality-assurance`, `/quality-gates`, `/rag-maintenance`, or `/debug` depending on the failure.
3. Isolate whether the issue is local, global, recent-change, or environment-specific.
4. Test the smallest reproducible case.

### Getting Help

- **Policy questions:** Read `docs/configuration.md`.
- **Skill reference:** Check `docs/skills/` and generated `~/.claude/SKILLS.md`.
- **Agent issue:** Verify the agent definition exists and matches the required lane.
- **Stuck:** Use `/fallback` to recover or `/scope-it` to reframe unclear work.
- **System health:** Use `/quality-assurance` and `/quality-gates`.

---

**Last updated:** 2026-07-01
