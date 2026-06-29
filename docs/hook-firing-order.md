# Hook Firing Order — Execution Contract

> Numbered contract for hook/skill firing order with positional justifications.
> Each entry: position, trigger, what it does, why it is at this position.
>
> **Wiring:** hooks are registered to lifecycle events in
> [`claude/settings.json`](../claude/settings.json). Before that file existed,
> the `hooks/` scripts were orphan artifacts and the contract below was
> advisory-only. Exit code 2 is the only blocking code.
>
> **Self-improvement:** the PostToolUse/SessionEnd entries here are the
> "observe" half of the flywheel — see [`flywheel.md`](flywheel.md).

---

## Overview

Hooks fire in a deterministic order tied to lifecycle events. The order matters: safety gates must run before execution, observation must run after execution, and session-level setup/teardown bookends everything.

---

## 1. SessionStart

**Position:** 1 (first)
**Trigger:** Session opens (CLI launch or resume)
**What it does:**
1. Log session start — timestamp, branch, context size
2. Merge stale RAG chunks — integrate recent file changes into live retrieval index
3. Pull latest memories and ADRs — sync from `~/.claude-env` to local working state
4. Detect and reindex drifted files — if files changed outside the session, update index
5. Alert if main branch has drifted — warn if upstream main has commits not in local
6. Alert if memory index is oversized — flag if memory database exceeds threshold

**Why first:** The agent needs fresh context before doing anything. Stale RAG chunks, outdated memories, or drifted upstream state will cause every subsequent decision to be based on wrong information. This is the foundation — nothing else works correctly without it.

---

## 2. UserPromptSubmit

**Position:** 2 (on every user prompt)
**Trigger:** User submits a prompt
**What it does:**
1. Auto-recall — semantic search on RAG index, inject knowledge graph context if hits found
2. Classify prompt complexity — scan for keywords to determine simple/moderate/complex/xcomplex
3. Emit model tier hint — Haiku/Sonnet/Opus suggestion based on complexity
4. Log turn count — increment session turn counter
5. Warn if context exceeds 85% — emit "compact available" hint
6. Composite detection — if intent matches a composite skill, emit composite match
7. Warn if on release branch — alert before making commits to release branches

**Why second:** Every prompt needs context injection and routing before the agent starts thinking. RAG recall must happen before the agent formulates a response. Complexity classification must happen before model selection. This is the "prepare the agent for this specific turn" step.

---

## 3. PreToolUse — Bash Safety Gate

**Position:** 3a (first PreToolUse filter)
**Trigger:** Before any Bash tool execution
**What it does:**
- Block dangerous patterns: `rm -rf`, `sudo rm`, `dd`, `git reset --hard`, `git push --force`, `DROP TABLE`, `curl|bash`, `chmod -R 777`, `pkill`, `kill -9`
- Match against `dangerousPatterns` regex list in `mcp-policy.json`
- Block and warn — never silently allow

**Why first in PreToolUse:** Destructive shell commands are the highest-risk, fastest-executing threat. A `rm -rf /` takes milliseconds. This gate must run before any other PreToolUse check because shell safety is the most time-critical constraint.

---

## 4. PreToolUse — Dangerous Pattern Detection

**Position:** 3b (second PreToolUse filter)
**Trigger:** Before any tool execution (all tools)
**What it does:**
- Block access to protected paths: `~/.ssh`, `~/.aws`, `/etc`, system files
- Detect credential exposure: reads of `.env`, `credentials.json`, `*.pem`
- Block SSRF patterns: URLs matching internal IP ranges (`10.*`, `172.16.*`, `192.168.*`, `169.254.*`)
- Require explicit user confirmation for sensitive operations

**Why second in PreToolUse:** After shell safety, path/credential/SSRF protection is the next highest priority. These patterns span all tool types (Bash, Read, Write, webfetch, MCP) and must be checked before any tool-specific logic runs.

---

## 5. PreToolUse — Commit Format Validation

**Position:** 3c (third PreToolUse filter)
**Trigger:** Before Bash tool execution containing `git commit`
**What it does:**
- Validate conventional commit format (feat, fix, refactor, chore, docs, style, ci, test)
- Enforce subject-case rules (project-specific: sentence-case, lower-case, etc.)
- Enforce header length limits (e.g., max 72 chars)
- Block commits with AI attribution markers (`Co-Authored-By:`, `Generated with`)
- Block commits containing secrets (pattern match for API keys, tokens)

**Why third in PreToolUse:** Commit format is important for history hygiene but not safety-critical. It runs after shell safety and credential protection because a badly formatted commit is recoverable; a leaked secret is not.

---

## 6. PreToolUse — Push-to-Main Block

**Position:** 3d (fourth PreToolUse filter)
**Trigger:** Before Bash tool execution containing `git push`
**What it does:**
- Block direct push to `main` or `release/*` branches
- Block `--force` push to any branch
- Block `--admin` bypass flags
- Verify PR automation halt invariant (no automation on PRs with human comments)

**Why fourth in PreToolUse:** Push protection is the last line of defense before changes reach shared history. It runs after commit format validation because the commit must be valid before it can be pushed. This is the gate that prevents bad commits from reaching protected branches.

---

## 7. PostToolUse — Documentation Update Detection

**Position:** 7a (first PostToolUse filter)
**Trigger:** After Write or Edit tool execution
**What it does:**
- Detect if changed files are documentation (`.md`, `docs/`, `README`)
- If specs changed (`docs/specs/**`), trigger `docs/roadmap.md` regeneration
- If skills or standards changed, trigger docs-sync to `~/.claude` and `~/.agents`
- Log which files were changed for session transcript

**Why first in PostToolUse:** Documentation drift is the most common form of knowledge decay. Detecting doc changes immediately after they happen ensures the roadmap and synced copies stay current. This runs before formatting because content correctness matters more than style.

---

## 8. PostToolUse — Prettier / Markdownlint

**Position:** 7b (second PostToolUse filter)
**Trigger:** After Write or Edit tool execution on formattable files
**What it does:**
- Run Prettier on changed `.js`, `.ts`, `.json`, `.yaml`, `.md` files
- Run markdownlint on changed `.md` files
- Auto-fix formatting issues (trailing whitespace, heading levels, list style)
- Report unfixable issues as warnings

**Why second in PostToolUse:** Formatting must run after content changes are detected but before the file is considered "done." Running it after doc-update detection ensures that any doc-triggered regeneration also gets formatted. Running it before rtk-miss-detector ensures the file is clean before usage analysis.

---

## 9. PostToolUse — RTK Miss Detector

**Position:** 7c (third PostToolUse filter)
**Trigger:** After Bash tool execution
**What it does:**
- Detect Bash commands that should have used `rtk` prefix for token savings
- Flag commands like `git status`, `git diff`, `gh pr view`, `npm ls`, `docker ps`
- Suggest `rtk <cmd>` equivalent for 60-90% token reduction
- Log missed opportunities for efficiency tracking

**Why third in PostToolUse:** RTK detection is an optimization hint, not a correctness check. It runs after doc updates and formatting because those are correctness/style concerns. RTK savings are valuable but not blocking — the command already succeeded.

---

## 10. SessionEnd

**Position:** 10 (last)
**Trigger:** Session closes (normal exit, timeout, or interrupt)
**What it does:**
1. Sync RAG chunks to persistent storage
2. Sync memories to `~/.claude-env`
3. Archive session transcript to `~/.claude/transcripts/`
4. Log final token count
5. Generate handoff file if work is incomplete

**Why last:** Session end is the cleanup phase. Everything that happened during the session must be persisted — RAG updates, memory changes, transcripts, handoffs. This runs after all other hooks have completed because it is the final consistency check. If the session crashed, this hook may not run — which is why SessionStart merges stale chunks on the next launch.

---

## Firing Order Summary

```
 1. SessionStart          — fresh context foundation
 2. UserPromptSubmit      — per-turn context injection and routing
 3. PreToolUse:
    3a. Bash safety       — block destructive shell commands
    3b. Dangerous patterns — block credential/SSRF/path traversal
    3c. Commit format      — validate conventional commits
    3d. Push-to-main block — protect shared history
 4. [Tool executes]
 5. PostToolUse:
    5a. Doc-update detect  — catch documentation drift
    5b. Prettier/mdlint    — auto-format changed files
    5c. RTK miss detector  — flag token-saving opportunities
 6. SessionEnd            — persist all state, generate handoff
```

---

## Design Principles

1. **Safety before execution.** All PreToolUse gates run before the tool executes. No tool runs without passing safety checks.
2. **Observation after execution.** All PostToolUse hooks run after the tool completes. They observe and learn but never block.
3. **Bookends are stable.** SessionStart and SessionEnd fire once per session. Everything else fires per-prompt or per-tool.
4. **Order within PreToolUse is risk-ranked.** Shell safety > credential protection > commit format > push protection. Higher risk runs first.
5. **Order within PostToolUse is correctness-ranked.** Content detection > formatting > optimization. Correctness runs first.

---

*This contract is version-controlled. Changes to firing order require updating this document and the hook configuration in `settings.json`.*

**Last updated:** 2026-06-29
