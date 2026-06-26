# Loop Templates

Ready-to-adapt cycle designs for the most common loop types.

## Coding loop

```
TRIGGER: Manual (/loop-engineer) or on PR open (webhook)
  ↓
Discover: Read VISION.md + ARCHITECTURE.md + failing tests / open issue
  ↓
Plan: Draft change plan (files to touch, approach, tests to write/update)
  ↓
Execute: Write code changes (maker agent, worktree isolated if parallel)
  ↓
Verify: Run test suite — pass = done; fail = read error
  ↓ fail
Iterate: Read error, patch code, re-test (max 3 retries)
  ↓ pass (or escalate after 3 failures)
DONE: Summarize changes, write memory note, open PR if configured
```

**Stop condition**: All tests pass (or specified subset)
**Escape hatch**: 3 consecutive failures → escalate with error summary

## Research loop

```
TRIGGER: Manual or scheduled (daily topic digest)
  ↓
Discover: Search for sources on the research question (Explore agent)
  ↓
Plan: Select top N most relevant sources, outline answer structure
  ↓
Execute: Summarize + synthesize sources (maker agent)
  ↓
Verify: Critic agent checks: claims supported? sources cited? conflicts noted?
  ↓ fail (unverified claims, weak sources)
Iterate: Researcher re-runs targeted search to fill gaps, re-synthesizes
  ↓ pass (confidence threshold met)
DONE: Save final answer to memory / markdown file
```

**Stop condition**: Critic confidence ≥ 80% or all claims source-verified
**Escape hatch**: 2 verify failures → surface to human with open questions

## Content loop

```
TRIGGER: Manual with topic + audience + goal
  ↓
Discover: Load style guide, prior content examples, audience context
  ↓
Plan: Outline (headline, key points, CTA, word count target)
  ↓
Execute: Write draft (maker agent)
  ↓
Verify: Critic agent scores against success criteria (clarity, CTA, length)
  ↓ fail (score < threshold)
Iterate: Rewrite weak sections based on critique
  ↓ pass (score ≥ threshold, max 2 rewrites)
DONE: Save final draft to file, note which criteria passed
```

**Stop condition**: Score ≥ threshold (define per project, e.g. 7/10)
**Escape hatch**: 2 rewrites → present best version to human for manual edit

## Outreach / sales loop

```
TRIGGER: New lead list or scheduled (weekly ICP sweep)
  ↓
Discover: Find leads matching ICP from source (LinkedIn, GitHub, CRM)
  ↓
Plan: Enrich + qualify each lead (company size, tech stack, fit score)
  ↓
Execute: Personalize message per lead (maker agent, one subagent per lead)
  ↓
Verify: Quality reviewer checks: personalized? clear value prop? tone right?
  ↓ fail (generic, wrong tone)
Iterate: Rewrite flagged messages
  ↓ pass (or escalate low-confidence leads)
DONE: Send approved messages (or queue for human approval), log to CRM
```

**Stop condition**: All qualified leads have approved messages
**Escape hatch**: Leads with fit score < 60 → escalate to human for manual review

## Daily audit loop (fleet)

```
TRIGGER: Scheduled daily at 03:00
  ↓
Orchestrator: Load prior audit snapshot from memory, list today's scope
  ↓
Parallel specialists (fleet):
  - Security scanner (Explore agent)
  - Test health checker (Explore agent)
  - Dependency auditor (Explore agent)
  ↓
Critic: Challenges top findings — severity calibration, accepted risks
  ↓
Verify: Any P0/P1 findings? → alert human immediately
  ↓ no critical findings
Iterate: (not applicable — audit is one-pass)
  ↓
DONE: Write audit snapshot to memory, post summary to Slack/Linear
```

**Stop condition**: All specialist agents complete + critic pass
**Escape hatch**: Any P0 finding → immediate human alert, skip rest of loop
