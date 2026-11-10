# Conversation excerpt (fictional repo "ledgerly")

Assistant: Production incident at 14:02: the nightly invoice job double-charged 41 customers. Cause: the job was retried by the scheduler after a timeout and the idempotency key was generated per attempt, not per invoice. Hotfix PR #512 merged 15:10 (commit a91f3be) now derives the key from invoice id. Refunds were issued by finance.
Assistant: Searching the incident log: the same missing-idempotency-key root cause also hit the payout job on 2026-10-01 (5 days ago) and was patched there only.
Assistant: There is no ADR and no incident-log entry for either event yet. No memory note exists either.
User: I am out of context budget. Hand off, the next session should only do the post-mortem cleanup.
