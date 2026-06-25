# Configuration: Hard Rules & Defaults

Reference guide for how the Claude Code operator harness is configured, including non-negotiable rules, default behaviors, and model tiering.

---

## Hard Rules (Non-Negotiable)

These rules are enforced by the CLAUDE.md global config and cannot be overridden per-project.

### 1. Never Automate PRs with Human Comments

**Rule:** Do not automate any action (merge, commit, deploy) on a PR that has comments from another human, or on any open PR authored by another person.

**Enforcement:** Hard halt — surface the blocker and tell the user.

**Scope:** Applies to every repo. Bots (Dependabot, Renovate, CodeRabbit, Sonar, etc.) do not count as "another person."

**Composites with merge logic:** If a composite skill encounters this blocker during its merge phase, it must bail with the blocker as its output. Do NOT silently skip the phase or declare partial success.

### 2. Parallel Execution Mandatory for ≥2 Independent Tasks

**Rule:** When work decomposes into 2 or more independent units (parallel investigations, multi-repo sweeps, fan-out audits, independent file edits, batch fixes), dispatch one `Agent()` per unit in a **SINGLE tool-use block** — not sequentially.

**Worktrees for same repo:** When 2+ parallel agents touch the same repo, each runs in its own git worktree: `/Volumes/External HD/Desenvolvimento/.worktrees/<task>-<n>/`

**Contract violation:** Sequential inline execution of independently-parallelizable work. If you catch yourself doing this, stop and re-dispatch as parallel agents with worktrees.

**Exemptions:** Single-unit work, trivial reads/edits (<3 files), work that genuinely depends on prior-step output.

### 3. Analysis Subagents Read-Only by Construction

**Rule:** Any subagent dispatched for an analysis phase (research, triage, spec, audit, review, investigation) must use a write-incapable `agentType` by explicit configuration, not just prompt-level "read-only" instruction.

**Write-incapable agent types:** Explore, explore, Plan, critic, code-reviewer, security-reviewer, document-specialist

**Execution subagents (write-capable):** general-purpose, debugger, test-engineer, and other implementation-focused types

**In Workflow scripts:** Set `agentType:` explicitly on every agent call. Analysis phases get read-only types; implementation phases get write-capable types.

**Why:** Agents have written to disk despite prompt-level "read-only" instructions. Structural prevention (agentType enforcement) is required.

**Edits from analysis:** Any edits derived from analysis findings are applied by the orchestrator or a separate implementer stage, never by the analysis agent.

### 4. No Big-Bang Rewrites Without Demand Measurement Gate

**Rule:** Before committing to a full rewrite OR a multi-step migration/rebuild of an existing user-facing feature, first measure its current usage/demand (telemetry, event counts, a query). If usage is *unknown*, instrument it and get data before investing — do not rebuild on the assumption it's used.

**After measurement:** Complete a 1-hour prototype of the first incremental unit. If the prototype exposes >3 friction points or requires >2 temporary shims, escalate to `/research-and-decide` (critic review) before continuing.

**Gate enforcement:** Do not skip the gate for perceived urgency.

### 5. Idempotency: State-Check Before Mutation

**Rule:** Before any write operation (file edit, API call, git push, DB upsert), query current state first. If the target state is already satisfied, skip and log "already done — skipping."

**Purpose:** Prevents double-mutations from resumed sessions or retry loops.

**Dry-run:** Optional for human preview, not mandatory.

### 6. Dispatcher ≠ Executor Boundary

**Rule:** Orchestrators (`dispatch`, `orchestrate`, composites) must not implement logic-bearing changes (adding conditions, changing data flow, modifying retry logic). Trivial inline edits (string constants, log messages, comment fixes) are allowed inline — log them as "inline edit — not logic-bearing."

**Boundary violation:** Implement logic in an orchestrator and claim it's "boundary edit." Surface the violation as output and wait; do not proceed.

### 7. Repository as Single Source of Truth

**Rule:** Any context a future agent would need to make a correct decision (ADRs, conventions, decisions, CLAUDE.md rules) must be committed before the agent acts on it. Ephemeral exploration (Slack threads, Notion drafts) may stay external.

**Test:** "Would a future agent need this to make a decision?" If yes, commit it first.

### 8. No Claude Co-Author Attribution

**Rule:** Never add `Co-Authored-By: Claude ...` trailers to commit messages, never add `🤖 Generated with [Claude Code]` trailers to PR bodies or release notes, never add any other AI-attribution marker.

**Who authors commits:** Lucas Santana (the operator). The assistant is a tool, not a contributor of record.

### 9. Storage on External HD

**Rule:** All new development, clones, worktrees, datasets, and AI artifacts live on `/Volumes/External HD/Desenvolvimento/`. Never use `~/` or `Macintosh HD` for development work.

**If External HD not mounted:** Surface that to the user before creating dev artifacts on internal disk.

### 10. Stuck Protocol

**Rule:** If the same task has been attempted >2 times without measurable progress, surface stuck state explicitly: "Stuck: [task], [attempt N], [last blocker]." Switch to a different approach or tool. After 2 approach switches fail, escalate to the user.

**Never:** Silently loop on a failing strategy.

---

## Default Behaviors

### Caveman Mode ON

**Terse, fragment-based communication.** Drop articles, filler, pleasantries, hedging. Keep all technical substance, exact terms, code blocks, quoted errors verbatim.

**Auto-Clarity Exception:** Temporarily drop caveman for:
- Security warnings
- Irreversible-action confirmations
- Multi-step sequences where fragment order risks misread

Then resume caveman.

**Override:** `/stop caveman` or `/normal mode` (that session only; next session defaults back to ON).

### Skill-First Execution

Skills are not waiting for you to invoke them — they are tools invoked autonomously when a description matches the work. Default to invoking; you only type a slash command when the choice isn't obvious.

**Composite-first principle:** When `composite-router` hook emits `🎯 Composite match: /<name>`, invoke that composite immediately. Do NOT run sub-skills manually.

### Graph-First Token Discipline

If `graphify-out/graph.json` exists in the active repo, query the graph **before** wide Grep/Read sweeps:
```
graphify query "<question>" --budget 500
```

Treat injected `# Knowledge graph context` blocks as the primary map.

### Signal-First Output

**Present:** verdict + top-3 findings inline. If there are >3 non-critical (P2/P3) findings, list top 3 then: "X more — ask for full list."

**Composite reconciliation blocks and plans with <4 phases:** Show all inline (exempt from signal-first rule).

**Never:** Dump full detail when a summary serves the decision.

---

## Model Tiering

### Main Loop (Default)
- **Model:** Claude Sonnet 4.6
- **Use for:** Implementation, feature work, code review, test generation, single-phase sub-agent dispatch

### Subagents (Mechanical)
- **Model:** Claude Haiku 4.5
- **Use for:** Formatting, symbol lookups, grep/regex searches, simple renames, transcription, batch mechanical work

### Opus (Explicit)
- **Model:** Claude Opus 4.8
- **Use for:**
  - Orchestration layer (composite skill entrypoints)
  - Critic role (architecture review, decision challenges)
  - Cross-session synthesis
  - Architectural decisions requiring ≥5-step reasoning chains
  - ADR writing

### Smart Model Select

Use `/smart-model-select` when task category is ambiguous. **Do not override tier for speculative speed gains.**

---

## Session Configuration

### Context Compaction

- **Trigger:** 85% context fill
- **Behavior:** Auto-warn with `/compact` suggestion
- **Savings:** ~30-40% tokens

### Token Budget

- Default: No limit (sessions run until natural completion)
- **Override:** Use `+500k` directive in prompt to set hard ceiling
- **Enforcement:** Once spent → further agent calls throw

### Read Deduplication

- **Pre-read hook:** Blocks re-reading same file twice in one session
- **Bypass:** Rarely needed; use context from prior read instead

### Large File Warning

- **Trigger:** File >25KB
- **Suggestion:** Use grep, Edit tool, or task-aware Read instead

---

## Git & Storage

### Branch Protection
- **Protected:** main, release (via GitHub)
- **Release branch workflow:** Enabled by default
- **Force push:** Blocked to main/release

### Worktree Cleanup
- **Auto-cleanup:** If agent makes no changes, worktree auto-removed
- **Path pattern:** `/Volumes/External HD/Desenvolvimento/.worktrees/<task>-<n>/`

### Sync & Memory

- **Sync interval:** SessionEnd (automatic)
- **Destinations:** `~/.claude-env` (canonical), `~/.claude` (local), `~/.agents` (shared)
- **Manual sync:** `/sync-memories` for immediate persistence

---

## Safety Gates

### Pre-Tool-Use Filters

**Dangerous bash:** `rm -rf`, `sudo rm`, `dd`, destructive patterns → blocked + warning

**Protected paths:** `~/.ssh`, `~/.aws`, `/etc`, system files → requires explicit confirmation

**Re-read same file:** Blocks + suggests using prior read output

### Post-Tool-Use Validation

**[Bash]:** Detect missed read-tool opportunities (e.g., `cat file | grep` → should use Read)

**[Read]:** Log which files read, warn if >25KB

**[Write|Edit]:** Reindex into RAG, validate skill writes

**[Edit]:** Warn if >3 edits in one turn

---

## Performance & Cost

### Rate Limit Monitoring
- Auto-fires during session (no manual invoke)
- Tracks API rate limit headers in real time
- Warns when approaching limit

### Token Audit
- Run `/token-audit` for weekly spend review
- Analyzes session JSONL files for cache hit rates, trends

### Mac Optimization
- Use `/mac-optimize` when Claude Code feels slow or machine is under pressure
- Diagnoses: CPU, swap, zombie processes, Node heap

---

## Standards & Policies

Key policy documents in `~/.agents/skills/standards/`:

- **agent-routing.md** — when to use which agent type, read-only enforcement
- **composite-contract.md** — composite-first principle, bail-out detection
- **pr-conventions.md** — PR title/body/attribution standards
- **graphify-discipline.md** — graph-first token discipline
- **decision-discipline.md** — research-before-deciding rules
- **artifact-schema.md** — structured artifact formats
- **workflow.md** — parallel execution, worktree usage, skill-first execution
- **durable-execution.md** — resumable work, checkpoints, handoffs
- **release-cadence.md** — versioning, changelog, deployment workflow
- **code-standards.md** — linting, formatting, type safety
- **testing.md** — test strategy, TDD discipline, coverage expectations
- **documentation.md** — README, API docs, inline comment standards
- **security.md** — OWASP Top 10, credential handling, audit logging
- **gotchas.md** — Common mistakes and how to avoid them

---

**Last updated:** 2026-06-25
