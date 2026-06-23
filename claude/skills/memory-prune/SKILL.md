---
name: memory-prune
description: Keep file-based memory healthy — find duplicate and stale facts, then merge or delete them. Conservative by construction.
---

# Memory prune

Memory rots: duplicates accumulate and facts go stale. Keep it lean so `recall` stays sharp.

## Where memory lives

```
${BRAIN_ROOT:-$HOME/.claude/memory}
```

## How

1. **Find near-duplicates** — facts whose `description:` lines are similar:
   ```bash
   MEM="${BRAIN_ROOT:-$HOME/.claude/memory}"
   grep -rh '^description:' "$MEM" --include='*.md' | sort | uniq -d
   ```
   Also scan `MEMORY.md` for entries that clearly overlap.
2. **Find stale facts** — memories that name a file, flag, path, or decision that no longer exists. Verify against the real repo/filesystem before judging one stale.
3. **Merge or delete.** Prefer merging two overlapping facts into one (richer, single source) over keeping both. Delete anything disproven by newer evidence.
4. **Keep `MEMORY.md` in sync** — remove or update index lines for any fact you deleted or merged.
5. **Commit** if memory is a git repo.

## Rule

Never bulk-delete. Surface the candidates, confirm intent, then act. A wrong memory is worse than a missing one — but losing real knowledge is also a loss, so prune deliberately, not aggressively.
