---
name: phase-0-audit
description: "Pre-build audit with dedup checks before creating new skills or agents. Check existing agents/skills before creating new ones. Change-type→phases matrix: full containment→reuse, partial+generalizable→extend, intentional domain-specific→new, completely different→new. Dedup checks before skill/agent creation."
triggers:
  - phase 0 audit
  - dedup check
  - before creating skill
  - before creating agent
  - skill overlap
  - agent overlap
---

# phase-0-audit

Pre-build audit to prevent duplication and ensure reuse before creating new skills or agents.

## Philosophy

**Search First, Reuse Always, Create Only When Necessary.**

Before creating any new skill or agent, audit what already exists. Most "new" capabilities are variations of existing ones.

## Change-type → phases matrix

| Change type | Phase | Action |
|-------------|-------|--------|
| **Full containment** | Reuse | Existing skill/agent already does this. Invoke it. |
| **Partial + generalizable** | Extend | Existing skill covers 60%+ of the need. Extend it with the missing capability. |
| **Intentional domain-specific** | New (justified) | Existing skill is close but intentionally different for a specific domain. Create new skill with clear differentiation. |
| **Completely different** | New | No overlap with existing skills. Create new skill. |

## Audit steps

### Step 1: Keyword search

Search existing skills and agents for keywords related to the proposed capability:

```bash
# Search skill names and descriptions
grep -r "keyword" ~/.claude/skills/*/SKILL.md
grep -r "keyword" ~/.claude/agents/*/AGENT.md

# Search triggers
grep -r "trigger phrase" ~/.claude/skills/*/SKILL.md
```

### Step 2: Semantic search (RAG)

Use RAG to find semantically similar skills:

```
/rag-recall "proposed capability description"
```

### Step 3: Manual review

Read the top 3-5 candidates. For each:
- What does it do?
- How much overlap with the proposed capability?
- Can it be extended, or is it intentionally different?

### Step 4: Decision matrix

Fill out the decision matrix:

```
Proposed: <skill/agent name>
Capability: <what it does>

Candidates found:
1. <existing-skill-1> — 80% overlap, missing X
2. <existing-skill-2> — 40% overlap, different domain
3. <existing-skill-3> — 10% overlap, completely different

Decision: EXTEND <existing-skill-1> with capability X
Rationale: 80% overlap, missing piece is small and generalizable
```

## Dedup checks

### Skill dedup

Before creating a new skill:

1. **Name collision**: Does a skill with this name already exist?
2. **Trigger collision**: Do the proposed triggers match an existing skill?
3. **Capability overlap**: Does an existing skill cover 60%+ of the proposed capability?
4. **Domain overlap**: Is there a skill for the same domain, even if named differently?

### Agent dedup

Before creating a new agent:

1. **Role collision**: Does an existing agent have this role?
2. **Tool overlap**: Does an existing agent use the same tools for the same purpose?
3. **Workflow overlap**: Does an existing agent follow a similar workflow?

## Output

```
PHASE 0 AUDIT — <proposed skill/agent name>
============================================

Search results:
  Keyword matches: 3
  Semantic matches: 5
  Manual review: 3 candidates

Decision matrix:
  Candidate 1: <name> — 80% overlap → EXTEND
  Candidate 2: <name> — 40% overlap → NEW (justified)
  Candidate 3: <name> — 10% overlap → NEW

Recommendation: EXTEND <candidate-1>
  - Add capability X to existing skill
  - Update triggers to include <new triggers>
  - No new skill needed

Alternative: CREATE NEW <proposed-name>
  - Justification: intentionally different domain
  - Differentiation: <what makes it different>
```

## When to use

- Before creating any new skill
- Before creating any new agent
- When asked to "add a feature" that might overlap existing skills
- During skill catalog maintenance

## Anti-patterns

- **Creating a new skill without auditing**: Always search first.
- **Extending when you should create new**: If the existing skill is intentionally different (different domain, different workflow), create new rather than bloating the existing one.
- **Creating when you should extend**: If 60%+ overlap exists, extend rather than duplicating.

## References

- See AGENTS.md "Pattern Discovery Protocol"
- See standards/skill-catalog-topology.md
