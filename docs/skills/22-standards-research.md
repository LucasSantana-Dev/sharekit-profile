# Standards & Research Skills

`adt-research` for deep investigation before a decision. `standards` to load and apply repo-specific coding standards. `adt-plan-change` before any multi-file edit to sequence and de-risk the work.

---

## /standards

Access and apply project coding and workflow standards.

**Standards:**
- Code style (linting, formatting)
- Architecture patterns (accepted, anti-patterns)
- Testing standards (coverage, strategy)
- PR conventions (title, body, review process)
- Commit message format
- Documentation standards

**Files:** Read from `~/.agents/skills/standards/` or project `.claude/standards/`

**When to use:** Before writing code; during code review

**Output:** Standards reference applicable to current work

---

## /adt-research

Deep research on a topic using web search, docs, and codebase analysis.

**Process:**
1. Web search for state of art
2. Read official docs (if library/framework)
3. Search codebase for prior decisions
4. Synthesize findings

**When to use:** Researching before decision (library choice, architecture pattern, etc.)

**Output:** Research summary + options

---

## /adt-plan-change

Plan a code change before editing — identify files, sequence steps, set verification criteria.

**Plan:**
- Files to modify + reason
- Sequence (which changes depend on prior changes?)
- Verification criteria (how to verify each step?)
- Rollback steps (if change needs to be undone)

**When to use:** Before multi-file edit; de-risk the work

**Output:** Change plan + sequencing

---

## /automation-workflows

Design reusable automation for repetitive development loops.

**Workflows:**
- CI/CD pipelines
- Recurring quality checks
- Dependency updates
- Release processes

**Designs:**
- Trigger conditions
- Task sequence
- Error handling
- Notifications

**When to use:** Automating repeated developer tasks

**Output:** Automation workflow design + implementation

---

**Last updated:** 2026-06-25
