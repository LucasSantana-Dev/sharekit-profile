# Agents: Specialized Worker Types

~40 agent types for different tasks. You rarely invoke agents directly — skills dispatch them and reconcile results. This is the reference guide.

---

## Analysis Agents (Read-Only)

These agents perform investigation, design, and review work. They **cannot write files** (structural enforcement via `agentType`), so edits derived from their findings are applied by the operator or a separate execution agent.

### architect
- **Purpose:** Audit and improve codebase architecture
- **Workflow:** Chains coupling analysis → orphan hunt → deepening opportunities → domain sharpening → critic gate → ADR recording
- **Use when:** Planning a refactor, evaluating architectural health, or audit-flagged structural debt
- **Output:** Architecture audit report (read-only)

### code-reviewer
- **Purpose:** Expert code review with severity-rated feedback
- **Coverage:** Logic defects, SOLID principle violations, style, performance, quality strategy
- **Use when:** Reviewing code before merge or as a second opinion on implementation
- **Output:** Findings organized by severity (bugs > regressions > security > style)

### critic
- **Purpose:** Work plan and code review expert — thorough, structured, multi-perspective (Opus-tier)
- **Use when:** Complex decisions requiring ≥5-step reasoning chains or architectural choices
- **Output:** Structured critique with recommendations

### decision-critic
- **Purpose:** Adversarial reviewer for decisions and analysis (Opus)
- **Constraint:** Has **no evidence-gathering tools** — reasons solely on provided artifacts
- **Use when:** Research-and-decide Phase 2 after analysis subagents complete
- **Output:** Challenge to proposed decision + alternative framings

### document-specialist
- **Purpose:** External documentation and reference specialist
- **Use when:** Reviewing external docs, API contracts, or design documents
- **Output:** Documentation audit or reference

### efficiency-advisor
- **Purpose:** Analyze workflows for token waste and time bottlenecks
- **Findings:** Model-tier mismatches, sequential work that should be parallel, re-read waste, context bloat
- **Use when:** Before spawning large agent fleets or when session burns budget faster than expected
- **Output:** Improvement recommendations with estimated savings

### Explore
- **Purpose:** Fast read-only search agent for locating code
- **Searches:** Files by pattern, grep for symbols/keywords, "where is X defined / which files reference Y"
- **Use when:** Finding code patterns across codebase
- **Scope options:** "quick" (single targeted lookup), "medium" (moderate exploration), "very thorough" (multiple locations)
- **Output:** File paths and excerpts

### scientist
- **Purpose:** Data analysis and research execution
- **Use when:** Analyzing metrics, running experiments, or synthesizing research findings
- **Output:** Data-driven recommendations

### security-reviewer
- **Purpose:** Security vulnerability detection specialist
- **Coverage:** OWASP Top 10, secrets, unsafe patterns
- **Use when:** Code touches auth, secrets, or infra; before security-relevant merges
- **Output:** Vulnerabilities organized by severity + remediation

---

## Execution Agents (Write-Capable)

These agents implement changes, write code, and run builds. They have full tool access.

### backlog-manager
- **Purpose:** Build ROI-ranked, deduped backlogs from parallel repo analysis
- **Workflow:** 8 phases: discover → rank → propose (approval gate) → spec → plan → issues → board → snapshot
- **Use when:** Starting a new work session or when "what should I work on" needs structured answer
- **Output:** GitHub Project board with issues

### ci-fixer
- **Purpose:** Diagnose and fix failing GitHub CI
- **Workflow:** Fetches Actions logs, queries repo CI history, summarizes failures, drafts fix plan
- **Gating:** Hard stop if PR belongs to someone else or has human reviewer comments
- **Use when:** PR checks fail and you need root-cause analysis and repair
- **Output:** Fixed CI + commit to PR

### code-simplifier
- **Purpose:** Simplifies and refines code for clarity and maintainability
- **Focus:** Recently modified code (unless instructed otherwise)
- **Use when:** After writing code to improve clarity while preserving all functionality
- **Output:** Simplified code committed to branch

### debugger
- **Purpose:** Root-cause analysis, regression isolation, stack trace analysis
- **Use when:** Investigating bugs, test failures, or build errors
- **Output:** Root cause + proposed fix

### deep-auditor
- **Purpose:** Composite health audit across 7 dimensions
- **Runs:** test-health, config-drift-detect, hook-effectiveness, security-audit, mcp-audit, plugin-audit, socket-audit in parallel
- **Reconciles:** Severity-ranked findings, cross-checks against prior decisions via RAG
- **Use when:** Full health check before releases or weekly on active repos
- **Output:** Prioritized remediation plan

### designer
- **Purpose:** UI/UX designer-developer for building stunning interfaces
- **Model:** Sonnet
- **Use when:** Building or redesigning user-facing UI
- **Output:** Built components + Playwright verification

### git-master
- **Purpose:** Git expert for atomic commits, rebasing, history management
- **Focus:** Style detection + best practices
- **Use when:** Complex rebase scenarios or history cleanup
- **Output:** Clean commit history

### handoff-writer
- **Purpose:** Capture active work state before budget runs low or context switches
- **Output:** Durable resume packet at `~/.claude/handoffs/<project>/latest.md` with exact next actions, file paths, and copy-pasteable commands
- **Use when:** Before context switches, approaching token budget, or end-of-day

### issue-triager
- **Purpose:** Move issues through triage state machine
- **States:** needs-triage → needs-info | ready-for-agent | ready-for-human | wontfix
- **Use when:** Triaging backlog of issues or preparing issues for autonomous execution
- **Output:** Issues properly classified

### mcp-tool-dev
- **Purpose:** MCP tool development specialist
- **Expertise:** Implementing, registering, debugging MCP protocol tools; UIForge MCP patterns, Zod schemas
- **Use when:** Creating new tools, modifying tool handlers, or troubleshooting MCP protocol issues
- **Output:** Working MCP tool with registration

### mutation-tester
- **Purpose:** Run mutation testing to verify tests actually catch failures
- **Detects:** Shallow suites where coverage looks healthy but assertions are missing
- **Use when:** After major test changes or before declaring suite production-ready
- **Output:** Mutation report + targeted test fixes

### parallel-implementer
- **Purpose:** Execute implementation plans by dispatching fresh subagent per task
- **Gating:** Mandatory two-stage review (spec compliance then code quality) after each task
- **Use when:** Written plan with mostly independent tasks, want high-quality same-session execution
- **Output:** Implemented + reviewed tasks

### phase-runner
- **Purpose:** Execute phased plans by fanning out agents per task per wave
- **Reconciles:** Per wave, with verify gates between phases
- **Use when:** Plans with ≥3 total tasks or ≥2 tasks in a single phase involving writes
- **Output:** Phase × outcome report

### Plan
- **Purpose:** Software architect agent for designing implementation plans
- **Identifies:** Critical files, architectural trade-offs
- **Use when:** Planning strategy for a task before execution
- **Output:** Step-by-step implementation plan

### pr-reviewer
- **Purpose:** Two-axis review of git diff — Standards and Spec (run as parallel sub-agents)
- **Standards:** Does code follow this repo's documented conventions?
- **Spec:** Does it match what the issue/PRD asked for?
- **Use when:** Reviewing a branch, PR, or work-in-progress changes
- **Output:** Side-by-side findings without merging

### rag-evaluator
- **Purpose:** Run retrieval regression gates (hitgate)
- **Metrics:** Hit@5, MRR, per-intent metrics
- **Use when:** Shipping retrieval code changes, validating retuning before merge, measuring refactor impact
- **Output:** Comparison report (helped/regressed/held steady)

### refactor-orchestrator
- **Purpose:** Orchestrate end-to-end refactors across 6 phases
- **Phases:** RAG pre-flight (prior context + protected scopes) → plan with rollback → critic scope gate → parallel 3-agent execution → two-stage review → test cleanup → ADR capture → sync
- **Use when:** Scope >5 files, cross-module boundaries, or audit-flagged structural issues
- **Output:** Refactored code + ADR

### research-decider
- **Purpose:** Evaluate library, pattern, or architecture choices end-to-end
- **Workflow:** Research candidates → challenge with decision-critic → plan adoption → write ADR with revisit-when condition → index for future recall
- **Use when:** Any choice where wrong decision creates technical debt or lock-in
- **Output:** Durable ADR

### systematic-debugger
- **Purpose:** Apply 4-phase systematic debugging to any bug or test failure
- **Disciplines:** Enforces root-cause investigation before proposing fix, tracks turn efficiency
- **Blocks:** Rationalization attempts
- **Use when:** Encountering technical failure (especially under time pressure or after multiple failed attempts)
- **Output:** Root cause + fix

### tdd-practitioner
- **Purpose:** Enforce test-driven development discipline
- **Cycle:** Red (write failing test) → Green (minimal code) → Refactor (improve under green)
- **Use when:** Writing production code — blocks implementation until failing test exists
- **Output:** Tested implementation

### team-coordinator
- **Purpose:** Decompose large task into parallel workstreams, assign agent ownership
- **Workflow:** Fan out agents, run integration at dependency boundaries, synthesize results
- **Use when:** Task large enough that parallel agents save time or add confidence, clear handoffs possible
- **Output:** Team plan + final integrated outcome

### test-engineer
- **Purpose:** Test strategy, integration/e2e coverage, flaky test hardening, TDD workflows
- **Use when:** Planning test architecture or hardening flaky suites
- **Output:** Test strategy + implementation

### tracer
- **Purpose:** Evidence-driven causal tracing with competing hypotheses
- **Method:** Evidence for/against, uncertainty tracking, next-probe recommendations
- **Use when:** Complex production issues with unclear root cause
- **Output:** Causal hypothesis ranked by evidence

### writer
- **Purpose:** Technical documentation writer for README, API docs, and comments (Haiku-tier)
- **Use when:** Writing or improving documentation
- **Output:** Written documentation

### xp-navigator
- **Purpose:** Drive Extreme Programming pair development cycles with AI-human pair
- **Manages:** plan → test → implement → refactor → release cadence
- **Enforces:** TDD discipline, role boundaries
- **Use when:** Structured incremental development with continuous feedback loops
- **Output:** Delivered features through XP cycle

---

## Forge Ecosystem Agents

Specialized agents for the Forge Space ecosystem and UIForge infrastructure.

### ecosystem-coordinator
- **Purpose:** Master coordinator for Forge Space ecosystem
- **Orchestrates:** forge-patterns, mcp-gateway, uiforge-mcp, and webapp specialists for cross-repository tasks

### forge-patterns-expert
- **Purpose:** Specialized expert for forge-patterns repository
- **Focus:** Pattern library, shared configurations, MCP context server, security framework, ecosystem standards

### mcp-gateway-specialist
- **Purpose:** Expert for forge-mcp-gateway — central hub for MCP aggregation
- **Focus:** Routing, authentication, API management

### uiforge-mcp-architect
- **Purpose:** Expert for uiforge-mcp — specialized MCP server for UI generation
- **Focus:** Template management, AI-powered component creation

### webapp-developer
- **Purpose:** Expert for uiforge-webapp — management interface for UIForge ecosystem
- **Focus:** Supabase integration, React development, UX design

---

## When to Fork vs. Use Main Agent

A **fork** (`Agent` with `subagent_type: "fork"`) inherits your full conversation context and runs in the background, keeping tool output out of your context.

Use fork when:
- Intermediate tool output isn't worth keeping in your context
- Research or multi-step work would otherwise flood context
- You want to keep chatting with the user while work runs

Use regular subagent (fresh agent) when:
- Work is scoped and independent
- You want agent to start fresh without distraction from prior conversation
- Task is straightforward enough that lack of context doesn't hurt

---

**Last updated:** 2026-06-25
