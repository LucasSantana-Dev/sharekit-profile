---
name: next-priority
description: Decide the highest-value safe thing to do right now in the active repo or workspace. Use when triaging repo state, deciding what to work on next, or when a plan's phase completes.
triggers:
  - next priority
  - what should happen now
  - triage this repo
  - what's blocking
  - what comes next
---

# next-priority

Choose the next action using evidence and repo priority rules, not intuition.

## Procedure

### 1. Stop/failure conditions — halt if met

- **Mount guard** — External HD required for RAG queries. Verify:
  ```bash
  mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG unreachable"; exit 1; }
  ```
- **No repo detected** — `git rev-parse --show-toplevel` fails → surface "not in a repo" and halt.
- **Ambiguous state** (simultaneous merge conflicts, uncommitted deletions, detached HEAD + active PR) → surface exact conflicts; do not guess intent.

### 2. Query prior decisions (RAG first)

Before wide repo scans, search for known priorities, ongoing work, or recent ADRs:
```bash
# Search knowledge-brain vault for prior priorities / handoffs / decisions
python3 ~/.claude/rag-index/query.py "priorities current work blockers" --top 5 --scope memory --format json
```

If handoff or active plan found: surface it; confirm if still valid before scanning.

### 3. Gather evidence (in order)

1. **Active handoff** — check `~/.claude/handoffs/<project>/latest.md` and `~/.claude/handoffs/latest.md`
2. **Active plan** — check `.claude/plans/` and `.agents/plans/`
3. **Current branch and open PRs** — `git branch --show-current`, `gh pr list --state open --limit 10`
4. **CI status on HEAD** — `gh pr list --json number,mergeStateStatus,statusCheckRollup`; verify required checks against ruleset (see `references/priority-rules.md` §mergeStateStatus)
5. **Review blockers** — `gh pr view <number> --json reviews` for `CHANGES_REQUESTED` or unresolved comments
6. **Working tree state** — `git status`, `git log --oneline -5`

### 4. Rank against priority order

Apply ranking rules from `references/priority-rules.md`: merge-ready PRs → blockers → CI failures → security issues → features → tech debt → speculative work.

### 5. Output reconciliation — verdict first

**ALWAYS return:**
- **Chosen action** (exact task, file, PR number, branch name)
- **Why it ranks highest** (which rule, what blocking it)
- **Top 2 alternatives** (why they rank lower)
- **Blocking evidence** (e.g., CI check, review comment, merge conflict)
- **Stop condition triggered?** (if yes, say so and surface the blocker; halt)

If nothing safe to do: "No actionable next step — repo is waiting on [external condition]."
