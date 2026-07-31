# Output Examples

## Example 1: Quick Decision

**User input:** "Should I use Opus or Sonnet to triage issues and apply labels?"

**Output (plain text, no headers, no tool call):**
```
Sonnet. Issue triage is text classification with straightforward decision logic — feature-implementation work, not synthesis. Sonnet costs 1/3× Opus per request with no quality loss on categorical edge cases.
```

---

## Example 2: Full Analysis — Sequential Re-read

**User input:** "I'm dispatching 8 agents sequentially, each reading a 400-line SKILL.md file independently. Is this efficient?"

**Output:** One-line summary + JSON:

```
Analysis: 8 agents are independent but sequential — parallelism-waste + re-read-waste pattern.

{
  "analysis_type": "workflow",
  "status": "EXPENSIVE",
  "efficiency_class": "parallelism-waste",
  "savings_tokens_pct": 72,
  "savings_time_multiplier": 7.0,
  "findings": [
    {
      "impact": "HIGH",
      "title": "Sequential dispatch of independent agents",
      "current": "8 agents run one after another, each waiting for prior to finish.",
      "better": "Dispatch all 8 in parallel via single Agent() batch. Each analyzes its section; no output dependencies.",
      "saves_tokens_pct": null,
      "saves_time_multiplier": 7.0,
      "tradeoff": ""
    },
    {
      "impact": "HIGH",
      "title": "Re-read waste — 8× file load",
      "current": "Each of 8 agents independently reads 400-line file.",
      "better": "Orchestrator reads once, injects per-section summary to each agent or full file if small.",
      "saves_tokens_pct": 75,
      "saves_time_multiplier": null,
      "tradeoff": ""
    }
  ],
  "next_action": "Dispatch 8 agents in parallel; pre-read file and inject summaries.",
  "additional_findings_available": false
}
```

---

## Example 3: Full Analysis — Opus Misuse + Parallelism

**User input:** "Plan: Step 1 - security audit (Opus agent). Step 2 - wait, then test health (Opus agent). Step 3 - wait, then config drift (Opus agent). Step 4 - synthesize findings + write ADR (Opus agent)."

**Output:** One-line summary + JSON:

```
Analysis: Steps 1-3 are independent audits but sequential + using Opus for read-only analysis — parallelism-waste + model-tier-mismatch pattern.

{
  "analysis_type": "workflow",
  "status": "EXPENSIVE",
  "efficiency_class": "hybrid-waste",
  "savings_tokens_pct": 68,
  "savings_time_multiplier": 3.2,
  "findings": [
    {
      "impact": "HIGH",
      "title": "Steps 1-3 are independent but sequential",
      "current": "Step 1 → wait → Step 2 → wait → Step 3 → wait → Step 4",
      "better": "Dispatch Steps 1-3 in parallel via single Agent() batch call. Collect results as summaries. Pass to Step 4 orchestrator.",
      "saves_tokens_pct": null,
      "saves_time_multiplier": 3.0,
      "tradeoff": "Parallel dispatch increases total tokens per agent (3 agents simultaneous) but cuts wall time 3×."
    },
    {
      "impact": "HIGH",
      "title": "Opus misused on read-only analysis tasks",
      "current": "Steps 1-3 use Opus for audit/fact-extraction",
      "better": "Downgrade Steps 1-3 to Sonnet/Haiku (agentType='Explore'). Reserve Opus for Step 4 (synthesis + ADR).",
      "saves_tokens_pct": 65,
      "saves_time_multiplier": null,
      "tradeoff": ""
    }
  ],
  "next_action": "Apply both findings: parallelize Steps 1-3 and downgrade to Sonnet/Haiku.",
  "additional_findings_available": false
}
```
