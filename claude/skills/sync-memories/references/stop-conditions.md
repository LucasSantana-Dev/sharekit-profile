# Reference: Stop/Failure Conditions

When to halt the skill and surface a blocker.

## Mandatory Halts

### 1. external drive Unmounted (Pre-flight Mount Guard)

**Condition:** `mount | grep -q "${DEV_ROOT}"` returns false.

**Action:** Surface immediately:
```
BLOCKED: external drive not mounted — knowledge-brain vault unreachable.
Defer full sync or fall back to local .agents/memory/ capture only.
```

**Why:** The vault + RAG embedder cache live on external drive. Writing blind during unmount corrupts state (stale checks read present files as "absent"). Never push, delete, or reconcile on unmount.

**Escalation:** Ask user to remount; resume sync after mount confirmed.

---

### 2. No Repo Detected

**Condition:** No `.git/` directory AND not a recognized monorepo (no `package.json` workspaces or `pnpm-workspace.yaml`).

**Action:** Surface:
```
BLOCKED: No git repo or monorepo detected.
Cannot gather state (no git log, commits, branch info).
Document manually if this is a non-git project, or init git first.
```

**Escalation:** Ask user to init git or provide manual context.

---

### 3. Version / Test Metadata Unavailable

**Condition:** Cannot read version from `package.json`, `setup.py`, VERSION file, or equivalent; cannot run tests (test suite fails, no test runner).

**Action:** Surface (non-blocking, defer test data):
```
WARNING: Could not gather test counts (test suite failed or missing).
Skipping test count sync. If this is a test-driven project, fix suite first.
Continuing with version + commit metadata only.
```

**Escalation:** None required — version alone is useful. Flag in memory as "test data incomplete."

---

### 4. Serena Not Configured (Project Activation Fails)

**Condition:** `.serena/` missing or `serena.activate_project()` returns error.

**Action:** Fall back gracefully:
```
INFO: Serena not configured for this project.
Skipping Serena memory update. Proceeding to local .agents/memory/ capture only.
```

**Escalation:** None — local memory still captures state.

---

### 5. Knowledge-Brain Git State Corrupted

**Condition:** `git -C "$BRAIN"` commands fail (not a git repo, corrupted index, permission denied).

**Action:** Surface:
```
BLOCKED: knowledge-brain git state corrupted or inaccessible at ${DEV_ROOT}/knowledge-brain.
Cannot commit/push memory changes. Local .agents/memory/ capture succeeded.
```

**Escalation:** Ask user to repair knowledge-brain repo (or re-clone from remote).

---

## Warnings (Non-Blocking)

### Memory Already Current

**Condition:** Step 1 (list existing memories) returns exact match to new data (version, test count, PR list identical).

**Action:** Skip update:
```
INFO: Project memory already current (version X.Y.Z, test count N matches existing).
No update needed. Proceeding with local memory + vault push only.
```

---

### Partial Failures (Continue)

**Condition:** Serena update succeeds; local `.agents/memory/` write fails (permission denied).

**Action:** Continue and flag:
```
WARNING: Serena memory updated; local .agents/memory/ write failed (permission denied).
Vault push skipped (incomplete state). Recommend manual fix to .agents/memory/ permissions.
```

**Escalation:** Ask user to check `.agents/` permissions.

---

### Vault Push Deferred (Session Continuing)

**Condition:** Session is not ending (user continues work after sync); push is optional.

**Action:** Offer, don't force:
```
INFO: Memory sync complete (Serena + local). Vault push deferred (session continues).
Memories will push automatically at session end via sync push-memories hook.
To push now: git -C ${DEV_ROOT}/Desenvolvimento/knowledge-brain push
```

---

## Output Template

Always signal halt vs. continue:

- **BLOCKED:** Fatal condition. Stop. Surface blocker + escalation to user.
- **WARNING:** Non-fatal condition. Continue with reduced scope. Flag in output.
- **INFO:** Informational only. Continue normally.
