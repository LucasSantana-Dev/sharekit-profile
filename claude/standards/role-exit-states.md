# Role Exit-State Contract

Exit states create a clear handoff contract between orchestrator and subagents. Each role has a defined exit state that signals "my work is complete and here's what I'm handing back." The orchestrator gates on these states before advancing to dependent work.

## Exit-State Contract Table

| Role | Exit State | Required Artifacts | Gate Condition |
|------|-----------|-------------------|----------------|
| **explorer** | "Map complete" | File paths + line refs, symbol locations, summarized findings | At least 1 concrete path/symbol cited; no unresolved "I couldn't find" without stating what was searched |
| **fixer** | "Implementation complete + tests pass" | Files changed (paths + line ranges), test command run + result, build/lint status | Tests actually executed (not claimed); diff is bounded to the task scope |
| **code-reviewer** | "P0-P3 findings + verdict" | Severity-rated findings (P0/P1/P2/P3), each with file:line evidence + fix recommendation; overall verdict (APPROVE/REQUEST_CHANGES/BLOCK) | At least 1 finding has evidence; verdict present; read-only — no file mutations |
| **debugger** | "Root cause + fix verified" | Root-cause hypothesis with evidence chain, fix applied, regression test added, test suite green | Hypothesis traces to specific code; fix is minimal; regression test exists |
| **oracle** | "Recommendation + rationale" | Clear recommendation, alternatives considered, trade-offs, risk assessment | Recommendation is unambiguous; at least 1 alternative considered; risk named |
| **designer** | "Design complete + intent preserved" | Files changed, design decisions (layout/hierarchy/motion/color/affordances), interaction intent documented | Visual structure described, not just code; copy is flagged for orchestrator review |
| **librarian** | "Sources + synthesis" | URLs/docs cited, version-specific behavior noted, synthesis answering the question | At least 1 primary source (official docs/GitHub); version numbers where relevant |
| **critic** | "Multi-perspective verdict" | Findings from at least 2 perspectives (e.g., correctness + maintainability), adversarial challenges, overall verdict | At least 2 distinct perspectives; challenges are substantive not nitpicks |
| **test-engineer** | "Tests written + suite green" | Test files added/modified, coverage delta, test names + what they assert, suite result | Tests assert behavior not implementation; suite actually ran green |
| **security-reviewer** | "OWASP findings + verdict" | Severity-rated findings mapped to OWASP category, file:line evidence, remediation | Findings map to OWASP Top 10; read-only — no file mutations |

## Principles

1. **Exit states are contracts, not suggestions.** A subagent that returns without its exit state has not completed its lane. The orchestrator should re-prompt or escalate.

2. **Gate conditions are checked by the orchestrator, not trusted from the subagent's claim.** "Tests pass" means the orchestrator saw the test output, not that the fixer said so.

3. **Read-only roles (code-reviewer, critic, security-reviewer) must not mutate files.** Their exit state is findings-only. Edits flow through the orchestrator or a separate implementer.

4. **Exit states enable parallel lanes.** When lane A's exit state satisfies lane B's precondition, B can start. The orchestrator tracks this dependency graph.

5. **Failure is a valid exit state.** "Blocked: [reason]" or "No findings" are legitimate exits — they carry information, not shame.

## Integration

This standard is referenced by:
- The orchestrator's delegation workflow (gate on exit states before advancing)
- AGENTS.md (the role-routing section points here)
- The `brief-and-drill` skill (briefs should specify the expected exit state)
