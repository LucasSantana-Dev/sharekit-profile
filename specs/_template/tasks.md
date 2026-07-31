# Tasks: <feature name>

Traces to: `requirements.md`, `design.md`

| # | Task | Requirement | Acceptance | Status |
|---|------|-------------|------------|--------|
| 1 | <smallest verifiable step> | REQ-1 | AC-1.1 | pending |
| 2 | <next step> | REQ-1 | AC-1.2 | pending |
| 3 | <next step> | REQ-2 | AC-2.1 | pending |

Rule: every task carries a requirement ID and the AC(s) that prove it done.
The AC-coverage gate (`hooks/check-ac-coverage.sh`) fails tasks that do not
trace to a requirement.
