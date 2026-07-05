# Examples: Parallel Work Coordinator

## Example 1: Multi-repo security audit

**User request:** "Audit repos A, B, C for security issues."

**Phase 1 output:** 3 independent units (repos don't depend on each other).

**Phase 2 plan:**
- Unit 1: Repo A security scan → worktree: `repo-a-sec`
- Unit 2: Repo B security scan → worktree: `repo-b-sec`
- Unit 3: Repo C security scan → worktree: `repo-c-sec`

**Phase 3:** Dispatch 3 agents in one message.

**Phase 5 reconciliation:**
```
PARALLEL WORK COORDINATOR
Units: 3 / 3 complete
Blockers: 0

Status:
  1. repo-a-sec: ✓ Found 2 SQL injection risks in login handler
  2. repo-b-sec: ✓ Found 1 XSS in comment field; 3 deps outdated
  3. repo-c-sec: ✓ No critical issues; 1 recommendation: rotate API keys

Consolidated: 3 actionable issues + 1 hygiene recommendation
Next: Review each finding; prioritize fixes
```

## Example 2: Batch file translation

**User request:** "Translate these 3 file groups (1–50, 51–100, 101–150) from English to PT-BR."

**Phase 1:** 3 independent units (file groups don't depend on each other).

**Phase 2:**
- Unit 1: Files 1–50 → no worktree (files are not in a shared git repo being edited; plain filesystem work)
- Unit 2: Files 51–100 → no worktree
- Unit 3: Files 101–150 → no worktree

**Phase 3:** Dispatch 3 translation agents.

**Phase 5:**
```
PARALLEL WORK COORDINATOR
Units: 3 / 3 complete
Blockers: 0

Status:
  1. files-1-50: ✓ 47 files translated; 2 skipped (already translated)
  2. files-51-100: ✓ 48 files translated; 1 needs review (ambiguous term)
  3. files-101-150: ✓ 50 files translated

Consolidated: 145 files translated; 1 file flagged for review
Next: Review flagged file; commit batch
```
