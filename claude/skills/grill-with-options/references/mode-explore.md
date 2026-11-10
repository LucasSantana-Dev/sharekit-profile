# Explore mode (from brainstorming)

Turn rough ideas into a validated design direction through collaborative dialogue, before implementation starts.

## Hard gate

Do NOT write any code or take any implementation action until a design direction is presented and the user approves it. If the user says "skip the discussion and just write it" while the design is undecided, hold the gate: say a direction must be agreed first, then ask one clarifying question or offer 2-3 approaches. Name at least one domain-specific constraint to decide (for example, for retries: idempotency, backoff, max attempts, dead-letter handling).

## Process

1. **Explore context.** Read what the user pointed at (notes, files, docs, recent commits). Surface constraints you find (budget, deadlines, trust in existing material).
2. **Ask clarifying questions.** One at a time, multiple choice when possible (`AskUserQuestion`, 2-4 options). Focus on purpose, constraints, success criteria. At most one question per turn.
3. **Propose approaches.** Present 2-3 distinct approaches, each with at least one trade-off. Lead with your recommendation and the reasoning.
4. **Present the design in sections.** Scale each section to its complexity; ask after each section whether it looks right. Cover architecture, components, data flow, error handling, testing.
5. **Document.** Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md` (only after approval) and commit it to the repo.
6. **Transition.** Hand off to the `plan` skill for an implementation plan.

## Principles

- One question at a time
- YAGNI ruthlessly: remove unnecessary features
- Always explore 2-3 alternatives
- Incremental validation: present, get approval, continue
- Be flexible: go back and clarify when needed

## Outputs

Return the concrete deliverable requested (approaches, design direction), the main decisions made, and unresolved constraints.

## Stop conditions

Stop if key prerequisites are missing or the request changes scope so much that exploration no longer fits. Do not commit to anything until the user approves a direction.
