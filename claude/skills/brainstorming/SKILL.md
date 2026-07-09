---
name: brainstorming
description: Facilitate collaborative idea exploration and turn rough concepts into
  a validated design direction before implementation starts. Use when the user is
  still shaping the solution and should not be pushed into code yet.
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.agents/skills/brainstorming
triggers:
  - brainstorm
  - idea exploration
  - design direction
  - rough concepts
---

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs through natural collaborative dialogue.

## Hard Gate

Do NOT write any code or take any implementation action until a design is presented and the user approves it.

## Process

### 1. Explore Context
- Check current project state (files, docs, recent commits)
- Understand existing architecture

### 2. Ask Clarifying Questions
- One question at a time
- Prefer multiple choice when possible
- Focus on: purpose, constraints, success criteria

### 3. Propose Approaches
- Present 2-3 different approaches with trade-offs
- Lead with your recommendation and reasoning

### 4. Present Design
- Scale each section to its complexity
- Ask after each section whether it looks right
- Cover: architecture, components, data flow, error handling, testing

### 5. Document
- Write validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Commit the design document

### 6. Transition to Implementation
- Create an implementation plan (use `plan` skill)

## Key Principles

- **One question at a time** — Don't overwhelm
- **YAGNI ruthlessly** — Remove unnecessary features
- **Explore alternatives** — Always propose 2-3 approaches
- **Incremental validation** — Present design, get approval
- **Be flexible** — Go back and clarify when needed

## Outputs / Evidence

- Return the concrete deliverable requested, the main decisions made, and any unresolved constraints.

## Failure / Stop Conditions

- Stop if key prerequisites are missing or the request changes scope enough that the current workflow no longer fits.
