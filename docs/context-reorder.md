# LongContextReorder Postprocessor

> PostToolUse hook that reorders retrieved chunks to fix "lost-in-the-middle" degradation.
> Source mechanism: [LlamaIndex `LongContextReorder`](https://github.com/run-llama/llamaIndex)

## Problem

Models exhibit "lost-in-the-middle" degradation (Liu et al. 2024): information placed in the center of the context window is recalled less reliably than information at the start and end. This creates model-dependent variance — models with smaller effective attention windows produce inconsistent results when critical context lands mid-window.

## Mechanism

Reorder retrieved chunks so the most relevant appear at the **start** and **end** of the context block, with decreasing relevance filling the middle. For N chunks ranked by score descending, interleave:

```
chunk[0], chunk[N-1], chunk[1], chunk[N-2], chunk[2], chunk[N-3], ...
```

This guarantees the two highest-scoring chunks occupy positions 0 and N-1 (the attention-favorable positions) regardless of model architecture.

## Hook

**File:** `hooks/reorder-context.sh`
**Trigger:** PostToolUse on retrieval-augmented tool calls (`rag_query`, `recall`, `context-pack`, `mcp__rag-index__*`)
**Behavior:** Reads the tool's JSON output, extracts chunks, reorders them, writes a sidecar digest to `.harness/runtime/reordered-chunks/`. Advisory — never blocks (exit 0).

### Edge cases

| Condition | Behavior |
|---|---|
| N=0 | No output, exit 0 |
| N=1 | Emitted as-is (already optimal) |
| N=2 | First at front, second at end (already optimal) |
| N > 50 | Skip (large windows get no benefit from reordering; model is saturated) |

## Integration

The hook writes reordered chunks to a sidecar digest file. The distill/diagnose engines read this digest instead of the raw tool response, ensuring the reordered context is what re-enters the model's context window on subsequent turns.

## Model Independence

This mechanism is deterministic and model-agnostic. It enforces the same context positioning regardless of which model is running. The harness shape — not the model's attention pattern — determines where critical context lands.

## Validation

| Check | Method |
|---|---|
| Correctness | 5 chunks with known scores → assert interleaved order matches expected |
| Idempotence | Re-running on already-reordered input returns same order |
| Determinism | Same input → same output across 100 runs (no date/random in reorder logic) |
| Performance | p95 latency < 5ms for N=20 chunks |
| No-regression | Existing eval catalog pass rate within ±2% of baseline |

See `tests/hooks/test_reorder_context.sh`.

## Wiring

Add to `claude/settings.json` PostToolUse array:

```json
{
  "matcher": "mcp__rag-index__*|*rag_query*|*recall*",
  "hooks": [{ "type": "command", "command": "hooks/reorder-context.sh" }]
}
```

## Related

- [Context Guard](../hooks/context-guard.sh) — existing lost-in-the-middle audit (advisory constraint recap)
- [Hook Firing Order](hook-firing-order.md) — PostToolUse position 5a
