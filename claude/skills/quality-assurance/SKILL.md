---
name: quality-assurance
description: Choose and sequence the right QA skills and checks for a change, release,
  or maintenance sweep. Use when the task is to plan or orchestrate QA strategy across
  testing, security, and verification rather than run one narrow check.
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/quality-assurance
  overlay_of: ~/.agents/skills/quality-gates
---









# Quality Assurance

Use this skill as the high-level QA router and composer.

## Use When

- The task needs a QA strategy across multiple checks or skill families.
- A release, risky change, or maintenance sweep needs ordered verification and evidence.
- The user wants to know which QA checks matter most before work is considered safe.

## Do Not Use When

- The user already wants one specific execution skill such as `quality-gates`, `backend-testing`, `security-audit`, or `security-scan`.
- The task is just to run repository-native verification once.
- The problem is narrow enough that orchestration adds no value.

## Inputs / Prereqs

- The target change, release, or audit scope.
- The main risks: correctness, regression, security, performance, or compliance.
- The available narrower QA skills in the workspace.
- Load `references/routing-matrix.md`, `references/checklists.md`, or `references/evidence-model.md` when needed.

## Workflow

1. Classify the QA goal: pre-commit, pre-merge, release, incident response, or maintenance sweep.
2. Choose the smallest set of narrower QA skills that can prove the required confidence.
3. Order them so cheap high-signal checks run before expensive or deep verification.
4. Route execution to the selected skills and consolidate the evidence they should return.
5. Report residual risk and what still blocks completion.

## Outputs / Evidence

- A QA plan or sequence with the narrower skills that should run.
- The reason each selected skill is in scope.
- The evidence required before the work can be considered safe enough.

## Failure / Stop Conditions

- Stop if the task only needs one narrow QA skill and no orchestration.
- Stop if required execution skills or environment access are missing.
- Do not restate the full body of the narrower QA skills here.

## Load These Resources

- `references/routing-matrix.md`
- `references/checklists.md`
- `references/evidence-model.md`

## Memory Hooks

- Read memory when the workspace already has release gates, QA conventions, or known risk patterns.
- Write memory only if the session establishes a durable QA workflow or gating rule.
