# Typed Result Schema Standard

Executable contracts for skill and agent outputs. Inspired by lm-eval-harness EvalResults and CodeWhale typed receipts.

## SkillResult

TypedDict-style schema for skill execution results.

```python
from typing import TypedDict, Literal
from datetime import datetime

class Finding(TypedDict):
    severity: Literal["critical", "high", "medium", "low", "info"]
    description: str
    fix: str  # Remediation hint or action

class Metrics(TypedDict):
    tokens_used: int
    duration_ms: int
    # Optional fields
    model: str  # e.g., "haiku", "sonnet", "opus"
    layers_run: list[str]  # e.g., ["static", "llm-judge", "monte-carlo"]

class SkillResult(TypedDict):
    status: Literal["pass", "fail", "partial", "skip", "timeout"]
    artifacts: list[str]  # File paths generated or modified
    metrics: Metrics
    findings: list[Finding]
    exit_state: str  # Machine-readable exit contract
    
    # Optional fields
    summary: str  # Human-readable summary
    timestamp: str  # ISO 8601
    skill_name: str
    skill_version: str
```

### Status values

- **pass**: All checks passed, no issues found
- **fail**: One or more critical/high issues found
- **partial**: Some checks passed, some failed or skipped
- **skip**: Skill did not run (preconditions not met, already done)
- **timeout**: Skill exceeded time limit

### Exit state contracts

Exit state is a machine-readable string that downstream tools can parse:

```
exit_state: "clean"              # No issues, safe to proceed
exit_state: "issues-found"       # Findings present, review needed
exit_state: "blocked"            # Cannot proceed, blocker found
exit_state: "already-done"       # Idempotent skip
exit_state: "timeout"            # Exceeded time limit
exit_state: "error"              # Unexpected error
```

## AgentRunResult

Schema for agent execution results (extends SkillResult with agent-specific fields).

```python
class AgentRunResult(TypedDict):
    # Inherits all SkillResult fields
    status: Literal["pass", "fail", "partial", "skip", "timeout"]
    artifacts: list[str]
    metrics: Metrics
    findings: list[Finding]
    exit_state: str
    
    # Agent-specific fields
    agent_name: str
    agent_type: Literal["analysis", "execution", "orchestrator"]
    read_only: bool  # True for analysis agents
    subagents_dispatched: list[str]  # Names of subagents spawned
    phases_completed: list[str]  # For multi-phase agents
    
    # Optional
    summary: str
    timestamp: str
    handoff: str  # Path to handoff file if session ended
```

## Examples

### SkillResult example

```json
{
  "status": "fail",
  "artifacts": [
    "audit-report.md",
    "findings.json"
  ],
  "metrics": {
    "tokens_used": 4500,
    "duration_ms": 12300,
    "model": "sonnet",
    "layers_run": ["static", "llm-judge"]
  },
  "findings": [
    {
      "severity": "critical",
      "description": "Dead link in SKILL.md:3",
      "fix": "Update references/old-api.md → references/new-api.md"
    },
    {
      "severity": "medium",
      "description": "Skill body exceeds 8KB limit (12.4KB)",
      "fix": "Move detailed content to references/ subdirectory"
    }
  ],
  "exit_state": "issues-found",
  "summary": "2 issues found: 1 critical, 1 medium",
  "timestamp": "2026-06-29T15:30:00Z",
  "skill_name": "catalog-gardener",
  "skill_version": "1.0.0"
}
```

### AgentRunResult example

```json
{
  "status": "pass",
  "artifacts": [
    "output/module.py",
    "output/tests/test_module.py"
  ],
  "metrics": {
    "tokens_used": 15000,
    "duration_ms": 45000,
    "model": "sonnet"
  },
  "findings": [],
  "exit_state": "clean",
  "agent_name": "refactor-orchestrator",
  "agent_type": "orchestrator",
  "read_only": false,
  "subagents_dispatched": [
    "code-reviewer",
    "test-engineer"
  ],
  "phases_completed": [
    "discover",
    "plan",
    "refactor",
    "review",
    "test"
  ],
  "summary": "Refactor complete, all phases passed",
  "timestamp": "2026-06-29T15:35:00Z"
}
```

## Implementation notes

### Python (TypedDict)

```python
from typing import TypedDict

class SkillResult(TypedDict):
    status: str
    artifacts: list[str]
    # ...
```

### TypeScript

```typescript
interface SkillResult {
  status: 'pass' | 'fail' | 'partial' | 'skip' | 'timeout';
  artifacts: string[];
  metrics: {
    tokens_used: number;
    duration_ms: number;
  };
  findings: Array<{
    severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
    description: string;
    fix: string;
  }>;
  exit_state: string;
}
```

### JSON Schema

Generate JSON Schema from TypedDict for validation:

```python
from typing import get_type_hints
import json

def skill_result_schema() -> dict:
    hints = get_type_hints(SkillResult)
    return {
        "type": "object",
        "properties": {
            "status": {"type": "string", "enum": ["pass", "fail", "partial", "skip", "timeout"]},
            "artifacts": {"type": "array", "items": {"type": "string"}},
            # ...
        },
        "required": ["status", "artifacts", "metrics", "findings", "exit_state"]
    }
```

## Usage

Skills and agents should return these typed results to:

1. **Enable downstream automation**: Composite skills can parse results and decide next steps
2. **Standardize reporting**: All skills/agents use the same format
3. **Facilitate debugging**: Structured findings are easier to parse than free-text
4. **Support idempotency**: `exit_state: "already-done"` signals skips

## References

- lm-eval-harness EvalResults: https://github.com/EleutherAI/lm-evaluation-harness
- CodeWhale typed receipts: internal pattern for structured agent outputs
- See skills/three-layer-eval/SKILL.md for Layer 1/2/3 output format
