# Parallel Discovery Execution (Phase 1)

Reference for Phase 1 of `/secure` — dispatching 4 independent read-only discovery agents in parallel.

## When this fires

Phase 1 is mandatory in every `/secure` run. It uses parallel dispatch to:
- Run discovery scans concurrently (not sequentially)
- Enforce read-only access on all discoverers (agentType: Explore)
- Collect normalized findings for ranking in Phase 3

## Agent dispatch pattern

All 4 agents must be spawned in a single message with concurrent tool calls (not sequential).

### Agents

1. **Credential scan** (agentType: Explore)
   - Search for: API keys, tokens, bearer headers, hardcoded passwords, private keys, .env/.pem/.p12 modifications
   - Output: findings list `[{title, severity: critical/high, file, line, evidence, suggested_fix}]`
   
2. **Code security analysis** (agentType: Explore)
   - Search for: SQL injection, XSS, command injection, code injection (eval), path traversal, deserialization, XXE
   - References: `references/secure-coding.md` language-specific patterns
   - Output: findings list (same schema)
   
3. **Config/infrastructure audit** (agentType: Explore)
   - Search for: CORS misconfigs, IAM wildcards, unencrypted transit/rest, missing rate limits, root containers, unsafe defaults
   - References: `references/best-practices.md` HTTPS/CORS/CSRF/headers/infrastructure sections
   - Output: findings list (same schema)
   
4. **Dependency & supply-chain scan** (agentType: Explore)
   - Search for: CVE audit (npm/pip/cargo), typosquatting, unmaintained packages, license violations
   - Commands: `npm audit --json`, `pip audit`, `cargo audit`
   - Output: findings list (same schema)

## Read-only enforcement (Explore agent type)

Each agent MUST use `agentType: "Explore"` — this is not advisory, it is structural:
- Explore agents do NOT have Write/Edit tools
- They cannot modify code or files
- They can only Read, Bash (for safe queries like git diff, npm audit, git log), and search
- Prevents accidental mutations during analysis

## Concurrent execution

Dispatch all 4 agents in a single Agent() tool call with subagent_type:

```
Agent({
  description: "Parallel security discovery: credential, code, config, supply-chain scans",
  prompt: "Run these 4 scans in parallel as Explore agents..."
})
```

The parent orchestrator receives all 4 results together.

## Halt conditions

If ANY agent finds a live credential exposure (API key, token, password in code):
- STOP all other phases
- Jump directly to Phase 2 (containment)
- Do not continue discovery, ranking, or proposal

## Findings normalization

All agents output findings in the same schema for Phase 3 consolidation:

```json
{
  "source": "credential|code|config|supply-chain",
  "title": "string (50–80 chars)",
  "severity": "critical|high|medium|low",
  "file": "path/to/file",
  "line": "number or range",
  "evidence": "code snippet, log excerpt, or config value",
  "suggested_fix": "one-sentence approach"
}
```

## Deduplication

After all 4 agents complete, Phase 3 deduplicates findings:
- Same root cause across sources (e.g., "SQL concat" from code + config audit) → merge, keep highest severity, annotate source list
- Conflicting severities → report both, add `[CONFLICT: code-review says high, config-scan says medium]` to title for Phase 4 user review

## Output feeds

All findings feed into Phase 3 (ranking & critic gate) as a consolidated list, ordered by severity.
