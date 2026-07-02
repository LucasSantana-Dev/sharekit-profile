# Strict Rules

- Do NOT skip the reconciliation block. Every run outputs status for all 4 phases (DONE, DECLINED, or BLOCKED).
- Do NOT curate without the Phase 1–3 context. Run phases 1–3 first; Phase 4 consumes their reports.
- Do NOT delete chunks from the index without checking the mount guard. Mounted-drive-only operation; missing files during unmount are unknown state, not deleted.
- Do NOT report "curation complete" without re-querying Phase 1's zero-hit queries and confirming cosine ≥0.25 on the rewrite.
- Do NOT skip Phase 2 just because Phase 1 shows good quality. Coverage and quality are independent; excellent retrieval on a thin corpus is fragile.
