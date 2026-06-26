# Duplicate Policy

## Canonical owners

- `~/.agents/skills` is the canonical shared skill store.
- `~/.codex/skills` is reserved for Codex/system-specific skills.
- `~/Desenvolvimento/forge-space/.agents/skills` is for Forge Space-only skills or thin overlays.

## Resolution rules

1. If repo-local and global copies are identical, remove the repo-local copy.
2. If a repo-local copy adds real Forge Space behavior, keep it as an overlay and set `metadata.overlay_of` to the canonical global path.
3. If a Codex or system copy must differ for platform reasons, keep the duplicate only when the difference is documented and `overlay_of` points to the canonical shared skill.
4. A duplicate family is unresolved when multiple copies share a name and none declares a canonical relationship.

## Canonicalization checklist

- Compare `SKILL.md` and support directories, not just filenames.
- Prefer shared canonical content over silent divergence.
- Do not keep parallel copies that differ only by wording drift.
- When a duplicate family has unusual support files, classify them with the support-file policy before removing anything.

## Thin wrappers

- Not every overlap is a duplicate family. If two skills have different public names but one is the canonical deeper workflow, keep the older name as a thin wrapper.
- Thin wrappers should keep only the trigger translation, delta, and canonical pointer. Do not mirror the canonical skill's full body.
- Use `metadata.overlay_of` on the wrapper to point at the canonical sibling when that relationship should stay explicit.

## Oversized skill handling

- If a large skill already uses `references/`, `scripts/`, or `assets/`, mark it as `progressive_disclosure: split` only when it remains oversized after the split.
- If a large skill becomes small enough after refactoring, remove the progressive-disclosure marker instead of keeping a meaningless annotation.
- If a large skill is intentionally kept dense, mark it as `progressive_disclosure: exempted` and add a reason.
- Do not leave large single-file skills unclassified.
