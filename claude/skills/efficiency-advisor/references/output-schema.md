# Output Schema for Full Analysis

When using Full Analysis Mode, output JSON in this schema (as plain text, not via a tool call):

```json
{
  "analysis_type": "workflow | session | decision",
  "status": "OPTIMAL | FIXABLE | EXPENSIVE",
  "efficiency_class": "sequential-re-read | model-tier-mismatch | parallelism-waste | hybrid-waste | active-session | other",
  "savings_tokens_pct": <integer 0–100, estimated % reduction, 0 if OPTIMAL>,
  "savings_time_multiplier": <float, e.g. 7.0 for 7× faster, 1.0 if OPTIMAL>,
  "findings": [
    {
      "impact": "HIGH | MED | LOW",
      "title": "<one-line finding>",
      "current": "<what the plan does>",
      "better": "<concrete change, include code/dispatch pattern if parallelism or tier change>",
      "saves_tokens_pct": <integer or null>,
      "saves_time_multiplier": <float or null>,
      "tradeoff": "<resource traded, or empty string if none>"
    }
  ],
  "next_action": "<one sentence: apply finding #1, or 'no changes needed'>",
  "additional_findings_available": <boolean>
}
```

**Cap findings at 3 inline.** Set `additional_findings_available: true` if more exist; offer to expand on request.
