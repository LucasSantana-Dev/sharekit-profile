# RULES.md — Constraints Layer

> Hard rules. Non-negotiable. Split from AGENTS.md to separate constraints from operations.
> For identity, see `SOUL.md`. For operational instructions, see `AGENTS.md`.
>
> **Source of truth:** this file is the full, human-authoritative rule set.
> `.harness/constitution.json` (`protected_invariants`) is the machine-enforced
> *subset* — the rules currently gated by hooks/CI plus the self-modification
> contract (`self-mod-*`, `storage-policy`) that has no prose entry here. The two
> must never conflict: when they differ, RULES.md is authoritative for intent and
> constitution.json for what is mechanically enforced. Rules in RULES.md absent
> from `protected_invariants` (parallel-execution, repository-single-truth,
> knowledge-supersession, stuck-protocol, dispatcher-not-implementer,
> post-incident-capture) are advisory/behavioral, not yet gated.

---

## Must Always

### State-check before mutation (idempotency)
Before any write — file edit, API call, git push, DB upsert — query current state. If already satisfied, skip and log "already done." Never mutate blindly.

### Parallel execution for >=2 independent units
When 2 or more independent units of work exist, run them in parallel (separate subagents or worktrees) rather than sequentially. Sequential execution of independently-parallelizable work is a contract violation.

### Read-only-by-construction for analysis agents
Any subagent dispatched for analysis (review, explore, plan, audit) must deny write/edit tools in its `permission` block — not just a prompt instruction. Edits from analysis are applied by the orchestrator or a separate implementer stage.

### Independence gate for review/security/critic agents
Review, security, and critic agents MUST be independent subagents — never collapsed into the implementer lane. Read-only is about tool permissions; independence is about lane separation. A reviewer running in the same context as the implementer has compromised objectivity.

### No AI attribution
Never add `Co-Authored-By:`, "Generated with...", or any AI-attribution marker to commits, PRs, issues, or release notes. Author of record is Lucas Santana. Agents are tools, not contributors of record.

### PR automation halt
Never automate any action on a PR with comments from another person, or any open PR authored by another person. Halt and tell the user. Bots (dependabot, renovate, coderabbit, greptile, sonar) do not count as "another person."

### Repository is the single source of truth
ADRs, conventions, decisions — all committed to the repo. Not in someone's head, not in a Slack thread. If it is not committed, it does not exist.

### Lean catalog preservation
Keep the active sharekit skill catalog lean. Do not restore archived wrapper skills just to recover wording; fold durable capability into active skills, standards, or docs first. Archived skills remain recoverable evidence, not active commands.

### Knowledge supersession
Historical memories may be stale. Preserve them as history and add superseding notes for current state instead of rewriting old decisions as if they never happened.

### Stuck protocol
If the same task is attempted more than 2 times without measurable progress, surface "Stuck: [task], [attempt N], [last blocker]" and switch approach. After 2 approach switches fail, escalate. Never silently loop on a failing strategy.

### Dispatcher does not implement logic
Orchestrators must not implement logic-bearing changes (new conditions, data-flow changes, retry logic). Surface the boundary and wait. Trivial inline edits (string constants, log messages, comments) are allowed.

### Post-incident capture
After any P0/P1 failure, commit a root-cause artifact (ADR or incident-log entry) before the next task. P2/P3 becomes a memory note plus handoff flag.

---

## Must Never

These commands are blocked at the shell level. Refuse even if asked.

| Command | Reason |
|---------|--------|
| `rm -rf /` | Catastrophic filesystem destruction |
| `git reset --hard` | Destroys uncommitted work irreversibly |
| `git push --force` | Rewrites shared history |
| `git push origin main --force` | Force-push to protected branch |
| `DROP TABLE` | Destroys database tables |
| `DROP DATABASE` | Destroys entire databases |
| `DELETE FROM` (unbounded) | Mass data deletion |
| `curl ... \| sh` / `curl ... \| bash` | Remote code execution from untrusted source |
| `sudo rm` | Privileged file deletion |
| `docker rm -f` | Force-removes running containers |
| `docker rmi` | Removes images (may break running services) |
| `chmod -R 777` | Opens all permissions — security disaster |
| `pkill` | Kills processes by name — unpredictable |
| `kill -9` | Force-kills without cleanup |
| `dd if=/dev/zero` | Overwrites disks |
| `mkfs` | Formats filesystems |

---

## Escalation Triggers

Stop and ask the human before proceeding when:

- **Security-sensitive** — auth, secrets, credentials, infra permissions
- **Production-impacting** — affects live systems or user-facing behavior
- **Irreversible** — destructive operations that cannot be undone
- **Ambiguous intent** — task could mean multiple things, wrong choice is costly

---

*Rules are stable. When constraints change, update this file deliberately.*
