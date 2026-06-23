---
name: session-bootstrap
description: Composite skill — start-of-day routine. Chains wake-up (compact brief) → next-priority (decide) → pr-snapshot (PR queue) → context-pack (load relevant context if work-intent). Replaces "what was I doing", "what's next", "load context" with one invocation. Auto-fires on the first non-trivial prompt of a fresh session.
user-invocable: true
auto-invoke: first-prompt-of-session + post-resume + post-handoff-load
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: $HOME/.claude/skills/session-bootstrap
---

# Session Bootstrap

The single command for "I just sat down, get me oriented and ready to work."
Replaces the manual `/wake-up` → `/next-priority` → `/pr-snapshot` sequence.

## Auto-invocation triggers

- First non-trivial prompt of a fresh session (no prior conversation context)
- User says "where are we", "what's next", "catch me up", "good morning"
- After `/resume` or session restart
- After loading a `/handoff` from another machine/session

## Workflow

### Phase 1 — Brief (always)
Invoke `wake-up` for the compact 600-900 token bootstrap:
- Latest handoff
- Top 3 RAG hits scoped to current repo
- Git status one-liner
- Most recent memory note

### Phase 2 — Decide priority (always)
Invoke `next-priority` to rank the highest-value safe action:
- Open PRs awaiting your action
- Failing CI on your branches
- Recently committed work that needs verification
- Drafted plans that haven't started

### Phase 3 — PR queue (always — quick, batched)
Invoke `pr-snapshot` for one-line status across all open PRs:
- Color-coded ready / waiting / blocked
- Ages per PR
- Third-party reviewer status

### Phase 4 — Context pack (conditional)
If `next-priority` returned a work item AND prompt mentions implement/refactor/fix:
- Invoke `context-pack` (or note that `auto-context-pack` already fired this prompt)
to load relevant code, standards, prior decisions

### Phase 5 — Recommend the first action
Synthesize Phase 1-4 into one recommendation:
```
Today's first move: <specific action>
  Why: <reason from priority + PR state>
  Skill to invoke: </specific-skill>
  Expected effort: <small/medium/large>
```

## Reconciliation

Single one-page brief:
```
SESSION BOOTSTRAP — <date>

Where you left off (wake-up):
  Last handoff: <path, age> ✅ DONE
  Recent commits: <3 bullets> ✅ DONE
  Recent decisions: <1-2 from memory> ✅ DONE

Top priority (next-priority):
  <ranked action with reason> ✅ DONE

PR queue (pr-snapshot):
  ✓ #234 MERGE-ready    PR title ✅ DONE
  ⏳ #235 awaiting review ✅ DONE
  ⚠️ #236 CI failing ✅ DONE

Recommended first action:
  <specific concrete action> ✅ DONE
  Suggested skill: </skill-name>
  Snapshot:              (none — bootstrap is orientation only)
  Open watch:            (none)
```

## Outputs / Evidence

- One-page bootstrap brief (target ≤1500 tokens including embedded RAG hits)
- Specific recommended next action with skill suggestion
- No commits, no edits, no merges — purely orientation

## Failure / Stop Conditions

- No active repo / project detected → minimal brief with "no context to bootstrap"
- All sub-skills error → fall back to bare git status + git log -5
- Never invoke any work-doing skill from inside session-bootstrap — it's
  recommendation-only; user (or auto-chain follow-up) drives execution

Snapshot:
Open watch:            (none)
