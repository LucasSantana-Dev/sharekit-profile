# QA Routing Matrix

| Need | Default route | Why |
|---|---|---|
| Repo-native verification before commit or merge | `quality-gates` | Fastest path to the current project's standard gate set |
| Backend test design or coverage strategy | `backend-testing` | Best fit for test-level guidance and realistic backend coverage |
| Broad security review | `security-audit` | Best fit for risk-oriented security inspection |
| Executable security checks | `security-scan` | Best fit for running concrete secrets, dependency, code, or config scans |
| Performance workflow in a dedicated domain | domain-specific performance skill | Use only when performance is actually in scope |

## Rule

Use this skill only when choosing or sequencing multiple QA skills adds value. Otherwise, route directly to the narrower skill.
