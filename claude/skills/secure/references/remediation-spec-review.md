# Remediation Spec Review Process (Phase 5)

Used in Phase 5 of `/secure` to review security remediation specs before implementation begins.

## When this fires

Phase 5 is triggered when ≥1 finding is approved for remediation in Phase 4. If multiple findings are approved, specs are generated in parallel (one subagent per spec, single message). Each spec goes through two sequential review stages.

## Spec generation subagent

**agentType:** `general-purpose` (write-capable)

Generates remediation spec for a single approved finding.

### Output structure

```markdown
# Remediation Spec: <finding-title>

## Finding Summary
- **Severity:** <critical/high/medium>
- **File/Line:** <file:line or file pattern>
- **Root cause:** <one-sentence description>
- **Risk:** <what could go wrong if not fixed?>

## Remediation Steps
1. [specific code change per references/secure-coding.md pattern]
2. [if multi-file, list each file explicitly]
3. [test command(s)]
4. [verification step]

## Verification Criteria
- [ ] [specific, testable assertion per finding's evidence]
- [ ] [test coverage for the fix]
- [ ] [no regressions in related functionality]

## Risks & Side Effects
- [if any: changed behavior, performance impact, migration needs]

## Implementation Language/Framework
- [Python/JS/Java/Go pattern citation from references/secure-coding.md]
```

## Stage 1 review: Completeness (code-reviewer)

**agentType:** `code-reviewer` (read-only)

Check that the spec is:
- **Specific:** does it name files, line numbers, exact code patterns to change?
- **Testable:** are verification criteria expressed as binary assertions?
- **Actionable:** can an implementation agent follow the remediation steps without gaps?
- **Patterns correct:** does the suggested fix match the language-specific pattern in `references/secure-coding.md`?

Reviewer output (JSON):
```json
{
  "spec_id": "<finding-id>",
  "completeness_verdict": "ready" | "revise",
  "gaps": ["gap 1", "gap 2"],
  "reviewer_note": "<feedback if revise>"
}
```

**Rules:**
- If verdict == "revise" → spec subagent fixes gaps and re-submits to this reviewer only (not Stage 2 yet)
- Only when completeness_verdict == "ready" → move to Stage 2

## Stage 2 review: Security-Correctness (critic)

**agentType:** `critic` (read-only)

Challenge the spec's remediation approach:
- **Does the fix close the gap?** If the finding is "SQL concat in login query", does the fix actually use parameterized queries?
- **Side effects?** Could the fix introduce a new risk (e.g., disabling a security check to fix a performance bug)?
- **Compliance match?** Does the fix follow the pattern cited in references/secure-coding.md?
- **Completeness in scope?** If the finding is "4 db files", does the spec address all 4?

Reviewer output (JSON):
```json
{
  "spec_id": "<finding-id>",
  "security_verdict": "sound" | "needs_revision",
  "risks": ["risk 1", "risk 2"],
  "critic_note": "<feedback if needs_revision>"
}
```

**Rules:**
- If security_verdict == "needs_revision" → spec subagent fixes and re-submits to both Stage 1 and Stage 2 again
- Only when BOTH reviewers return "ready"/"sound" → spec is approved for implementation (Phase 6)

## Parallel dispatch (for ≥2 specs)

When multiple specs are generated (≥2 findings approved), dispatch in single message:
- One spec-generation subagent per spec (parallel writers)
- After all specs generated, dispatch reviewers in sequence per spec (Stage 1 then Stage 2 serial per spec, but all specs' reviewers run in parallel across specs)

Example:
```
Spec 1: Generation → Stage 1 review → Stage 2 review ↘
                                                        } All done before Phase 6
Spec 2: Generation → Stage 1 review → Stage 2 review ↗
Spec 3: Generation → Stage 1 review → Stage 2 review ↗
```

## Spec approval criteria

A spec is approved for Phase 6 (implementation) when:
1. Stage 1 (code-reviewer): completeness_verdict == "ready"
2. Stage 2 (critic): security_verdict == "sound"
3. All iterations complete (if revisions needed, both stages must re-approve)

## Output reconciliation

In Phase 5 reconciliation line, report:
```
Spec:        <F specs generated; X approved after Stage 1+2 review | (skipped: <reason>)>
```

Examples:
- `Spec:        3 specs generated; 3 approved (all passed Stage 1+2)`
- `Spec:        2 specs generated; 1 approved (finding #3 rejected: spec approach unsound per critic)`
- `Spec:        (skipped: no findings approved)`

## References

- `references/secure-coding.md` — language-specific remediation patterns (SQL, command execution, XSS, etc.)
- `references/best-practices.md` — infrastructure and web security patterns
