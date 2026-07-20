# Session Budget

- Prefer narrow reads over broad context dumps.
- Compact when the task changes substantially or the context becomes noisy.
- Before switching tasks or models, checkpoint first.
- Around 70% of usable context, prefer compacting or handing off rather than continuing to accumulate noise.
- Around 90% of usable context, write a durable handoff and switch cleanly.
- Use retrieval, plans, and handoffs to rehydrate context instead of carrying everything inline.
