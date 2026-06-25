# Composites: Chained Skills & Gatekeeping

**Composite skills** auto-chain multiple sub-skills with validation gates and reconciliation between phases. They exist to enforce discipline and prevent phase-skipping.

**Rule: Always prefer a composite when available.** Running sub-skills manually bypasses critical phases and violates the composite contract.

---

## When Composite Router Fires

When you submit a prompt, the `composite-router.sh` hook evaluates your intent. If it matches a composite skill, you'll see:

```
🎯 Composite match: /refactor-pipeline
```

**Action:** Invoke that composite directly. Do not run sub-skills individually.

---

## Session & Context Composites

### /session-bootstrap ⭐
**Chains:** wake-up → next-priority → pr-snapshot → context-pack

**When:** Start of day or first task in a session

**What it does:**
1. Recall last session's context (wake-up)
2. Identify the highest-value safe thing to work on (next-priority)
3. Show status of open PRs (pr-snapshot)
4. Build a task-aware context bundle (context-pack)

**Output:** Brief of blocking work + what's ready to start

### /session-wrap-up ⭐
**Chains:** verify → ship → memory-sync → handoff

**When:** End of day or before context switch

**What it does:**
1. Run pre-ship verification gates
2. Ship merged work (tag + GitHub release)
3. Sync memories + ADRs to persistent storage
4. Write handoff document for resumption

**Output:** Shipped work + resumable handoff

---

## Planning & Execution Composites

### /scope-and-execute ⭐
**Chains:** plan → execute → verify → ship

**When:** "Build a feature / fix a bug / refactor this" with unclear scope

**What it does:**
1. Understand the problem + scope work
2. Create an implementation plan
3. Execute the plan
4. Verify completion
5. Ship the work

**Output:** Completed, shipped feature

### /parallel-phases ⭐
**Chains:** phase-runner (built-in)

**When:** Your plan has independent tasks per phase (e.g., "Phase 1: 3 independent tests; Phase 2: integration")

**What it does:**
1. Fan out N agents per wave (phase)
2. Reconcile results per wave
3. Gate between phases (manual or automated verify)

**Output:** Phased completion report

### /feature-from-zero ⭐⭐ (Mega-Composite)
**Chains:** research → scope → design → test → merge → ship

**When:** Full greenfield feature from idea to production

**What it does:**
1. Research the feature space (similar features, tech choices)
2. Scope the MVP
3. Design the interface
4. Implement with tests (TDD)
5. Open PR + get review
6. Merge to main
7. Tag + deploy

**Output:** Live feature

---

## Code Quality Composites

### /refactor-pipeline ⭐⭐
**Chains:** refactor-plan → [architect, builder, reviewer] → test-cleanup → mutation-test → adr-write → docs-sync

**When:** Multi-file refactor (>5 files or cross-module)

**Phases:**
1. **Discovery:** RAG search for prior context + protected scopes
2. **Planning:** Create refactor plan with rollback steps
3. **Critic gate:** Verify plan is safe before execution
4. **Execution:** 3-agent team (architect owns strategy, builder writes code, reviewer checks quality)
5. **Testing:** Audit + clean test suite, run mutation testing
6. **ADR:** Write architecture decision record
7. **Sync:** Propagate docs to all mirror locations

**Output:** Refactored code + ADR

### /verify-before-done ⭐
**Chains:** quality-gates → lint → type-check → build → tests → coverage → sonar → ci → sentry

**When:** Before merge or release

**What it does:**
1. Run lint + type-check
2. Build the project
3. Run test suite
4. Check coverage thresholds
5. Run SonarCloud gate
6. Verify CI checks pass
7. Monitor Sentry for post-deploy errors

**Output:** Binary PASS/FAIL verdict

---

## Testing Composites

### /fix-the-suite ⭐⭐
**Chains:** test-health → config-drift → test-cleanup → mutation-test → adr-write

**When:** Test suite is slow, flaky, or has low signal (high coverage but low confidence)

**Phases:**
1. **Diagnosis:** Read-only health report (count, coverage, runtime, flakiness)
2. **Config drift:** Audit jest/vitest thresholds, ESLint, tsconfig
3. **Cleanup:** Prune dead tests, refocus on behavior
4. **Mutation:** Verify survivors actually catch failures
5. **ADR:** Document why tests are structured this way

**Output:** Healthier, faster, higher-signal test suite

---

## Debugging Composites

### /debug-deep ⭐⭐
**Chains:** systematic-debugging → tracer → sentry → ci-watch → incident-response

**When:** Bug spans multiple services/CI/production (complex)

**Phases:**
1. **Systematic debugging:** 4-phase root-cause analysis
2. **Tracing:** Competing hypotheses + evidence weighting
3. **Sentry inspection:** Production error context + stack traces
4. **CI analysis:** Failed check logs + history
5. **Incident coordination:** Triage + tracking

**Output:** Root cause + fix + incident record

---

## Git & PR Composites

### /pr-to-release ⭐⭐
**Chains:** pr-flow → pr-merge-readiness → [CodeRabbit review] → ci-watch → changelog-update → merge

**When:** Branch ready → merged → release

**What it does:**
1. Create PR with title/body
2. Check merge readiness (MERGE/WAIT/FIX verdict)
3. Let CodeRabbit review
4. Monitor CI until green
5. Promote unreleased changes to CHANGELOG
6. Merge to release branch

**Output:** Merged PR on release branch

### /merge-confidently ⭐
**Chains:** pr-merge-readiness → [gh-address-comments] → [gh-fix-ci] → merge

**When:** "I think it's ready" but not 100% sure

**What it does:**
1. Aggregate every merge signal (readiness, CI, coverage, Sonar)
2. Address reviewer comments if blocked
3. Fix failing CI checks
4. Merge when all signals green

**Output:** Merged PR

### /branch-hygiene ⭐
**Chains:** [cleanup local] → [cleanup remote] → [cleanup worktrees]

**When:** Branches accumulating and getting messy

**What it does:**
1. Delete merged local branches
2. Delete abandoned remote PR branches (merged into main)
3. Remove dead worktrees

**Output:** Clean branch state

### /first-pr ⭐
**Chains:** onboard-new-repo → context-pack → scope → tdd → pr-flow

**When:** Landing first PR in an unfamiliar repo

**What it does:**
1. Rapid repo intake (tools, patterns, owner expectations)
2. Build task-aware context bundle
3. Scope the contribution
4. Write test first (TDD)
5. Implement + open PR

**Output:** Safe first PR

---

## Release & Deployment Composites

### /ship-it ⭐
**Chains:** verify-before-done → version-bump → changelog-update → ship → deploy → [verify]

**When:** PR merged, ready to production

**What it does:**
1. Final verification (all gates from verify-before-done)
2. Bump version in package.json + tag
3. Update CHANGELOG.md
4. Create GitHub release + tag
5. Deploy to production
6. Monitor Sentry + verify not broken

**Output:** Live release + tag

### /release-cut ⭐
**Chains:** [promote release branch] → version-bump → changelog → tag → cleanup

**When:** Batching many PRs into one release (release branch workflow)

**What it does:**
1. Promote release branch to main
2. Bump version
3. Create CHANGELOG entry
4. Tag version
5. Clean up release branch

**Output:** New version + tag on main

### /hotfix ⭐⭐
**Chains:** [emergency branch from main] → fix → test → ship-it → [backport to release]

**When:** Production is broken and can't wait for next release

**What it does:**
1. Create emergency hotfix branch from main (bypassing release branch)
2. Implement fix
3. Test thoroughly
4. Ship to production immediately
5. Backport to release branch

**Output:** Production fixed + release branch updated

### /repo-bootstrap ⭐
**Chains:** [init release branch] → [create CHANGELOG] → [setup dep-sweep config] → [open PR]

**When:** Fresh repo needs release infrastructure

**What it does:**
1. Create release branch
2. Initialize CHANGELOG.md
3. Configure Dependabot/Renovate dep-sweep
4. Open PR with bootstrap config

**Output:** Release-ready repo infrastructure

---

## Security Composites

### /security-sweep ⭐⭐
**Chains:** security-audit + socket-audit + semgrep + code-security (in parallel)

**When:** Code touches auth, secrets, or infra; before security-relevant deploy

**Parallel audits:**
- **security-audit:** Secrets, dependencies, code paths, OWASP risks
- **socket-audit:** Supply-chain security (Socket.dev on npm deps)
- **semgrep:** Pattern-based static analysis
- **code-security:** OWASP Top 10 implementation

**Output:** Security findings organized by severity + remediation

---

## Repository & Project Composites

### /onboard-new-repo ⭐⭐
**Chains:** adt-repo-intake → audit-deep → config-drift-detect → init CLAUDE.md

**When:** First touch of an unfamiliar codebase

**Phases:**
1. **Intake:** Rapid repo survey (tools, patterns, owner expectations)
2. **Audit:** Full health check (tests, config, security, MCP, plugins)
3. **Drift:** Audit gates (jest thresholds, tsconfig, ESLint, branch protection)
4. **Init:** Create `.claude/CLAUDE.md` with project-specific rules

**Output:** Onboarded repo + ready to work

### /backlog ⭐⭐
**Chains:** audit-deep → [roi-rank] → [specs] → [plan] → plan-to-issues → [board]

**When:** "What should I work on?" — need prioritized backlog with clear specs

**Phases:**
1. **Audit:** Full health report (7 dimensions)
2. **Rank:** ROI-rank findings (impact × effort)
3. **Spec:** Write specs for top items
4. **Plan:** Create implementation plans
5. **Issues:** Convert plans to GitHub issues
6. **Board:** Populate project board with issues + labels + milestone

**Output:** GitHub Project board ready for parallel work

---

## MCP & Observability Composites

### /mcp-care ⭐⭐
**Chains:** mcp-audit → adt-mcp-health → adt-mcp-doctor → mcp-builder suggestions

**When:** MCP server not working or need full lifecycle audit

**Phases:**
1. **Audit:** Session transcript scan — which servers/tools actually used, flag zero-use
2. **Health:** Validate live provider health (config vs. auth vs. connectivity issues)
3. **Doctor:** Diagnose + repair failing servers
4. **Builder:** Suggest improvements to server implementations

**Output:** Healthy MCP servers + recommendations

### /observability-bootstrap ⭐⭐
**Chains:** [implement pillars] → [define SLOs] → [setup alerts] → [smoke-test]

**When:** New service with no instrumentation

**What it does:**
1. Implement all 4 observability pillars (logs, metrics, traces, errors)
2. Define SLOs/SLIs
3. Set up alert rules
4. Run smoke test to verify signals

**Output:** Service with complete observability

### /observability-audit ⭐⭐
**Chains:** analyze → debug → tune → implement-gaps → monitoring-setup

**When:** Existing service with observability gaps

**Phases:**
1. **Analyze:** Read dashboards, correlate signals
2. **Debug:** Diagnose broken observability
3. **Tune:** Reduce cost without losing signal
4. **Implement:** Add missing signals
5. **Setup:** Configure alerts + SLOs

**Output:** Improved observability

---

## Incident Management Composites

### /production-incident ⭐⭐
**Chains:** sentry → debug-deep → incident-response → ship-it → adr-write

**When:** Production issue confirmed + requires immediate fix

**Phases:**
1. **Sentry:** Inspect issue + correlate with deploys
2. **Debug:** Deep systematic root-cause analysis
3. **Response:** Coordinate fix + tracking
4. **Ship:** Get fix to production immediately
5. **ADR:** Document incident + prevention

**Output:** Fixed production + incident record

### /incident-followup ⭐⭐
**Chains:** adt-research → adr-write → regression-test → [security-sweep if applicable] → knowledge-loop

**When:** Incident is resolved; need post-mortem

**Phases:**
1. **Research:** Deep dive into what went wrong
2. **ADR:** Document root cause + prevention measures
3. **Test:** Write regression test
4. **Security:** If security-relevant, run full sweep
5. **Knowledge:** Capture lessons into memory + documentation

**Output:** Post-mortem + prevention measures

---

## Research & Decision Composites

### /research-and-decide ⭐⭐ (Critical)
**Chains:** adt-research → decision-critic → [plan] → adr-write → [vault index]

**When:** Evaluating library/pattern/architecture choices with lock-in risk

**Forces:** Research-to-decision pairing (prevents decisions-without-evidence)

**Phases:**
1. **Research:** Deep investigation of candidates
2. **Critic:** Adversarial challenge to proposed choice
3. **Plan:** Adoption strategy if decision survives critique
4. **ADR:** Document decision + when to revisit
5. **Index:** Add to memory vault for future recall

**Output:** Durable ADR + indexed decision

---

## Knowledge & Memory Composites

### /knowledge-loop ⭐
**Chains:** recall → sync-memories → rag-curate → handoff

**When:** Capturing lessons learned or updating knowledge base

**What it does:**
1. Semantic search for related prior reasoning (recall)
2. Sync findings into structured memory types
3. Manually improve corpus quality (rag-curate)
4. Write handoff for next session

**Output:** Updated knowledge base + handoff

---

## Composite Contract Violations

**Violation pattern:** Using a sub-skill when a composite covers the same intent.

❌ **Wrong:**
```
User: "I need to refactor this module."
Assistant: Invoke `/refactor` directly, bypassing discovery and plan phases.
```

✅ **Correct:**
```
User: "I need to refactor this module."
composite-router emits: 🎯 Composite match: /refactor-pipeline
Assistant: Invoke `/refactor-pipeline` (enforces all phases).
```

**Bail-out detection:** If a composite cannot complete a phase, emit the blocker as reconciliation output and mark the phase incomplete. Do NOT silently switch to a sub-skill or skip the phase.

---

**Last updated:** 2026-06-25
