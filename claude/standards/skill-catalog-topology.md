# Skill Catalog Topology

Three tiers. Canonical is the only source of truth. (Corrected 2026-07-09 per ADR-0041 — the previous version of this file inverted canonical/mirror and caused mirror-only commits.)

| Tier | Path | Role |
|------|------|------|
| **Canonical** | `~/.agents/skills/` (`skills.git`, github.com/<github-user>/skills) | Source of truth for **skills + standards**. `~/.claude/skills`, `~/.claude/standards`, `~/.codex/skills` are symlinks into it. |
| **Mirror** | `~/.claude-env/skills/`, `~/.claude-env/standards/` (`claude-env.git`) | Downstream mirror only — sync propagates canonical→mirror. claude-env stays canonical for NON-skill dotfiles (hooks, settings, bin, adrs). |
| **Export** | `sharekit-profile` repo `claude/skills/` | Public curated subset (allowlist: `curated-skills.txt`, ADR-0039) — synced from canonical + sanitized; never hand-edit the export. |

## Rules
- **Skill/standard edit = edit `~/.agents/skills/...` AND commit+push `skills.git` in the same session.** Uncommitted edits survive only via the SessionStart pre-flight WIP auto-commit (ADR-0041) — don't rely on it.
- Mirror-only commits (claude-env) are incomplete: canonical drifts and the next `sync pull` from another machine can conflict. Commit canonical first; mirror follows via sync.
- **Multi-machine divergence → 3-way merge, never "keep newer local"** — verify superset claims with `git diff`, not subagent summaries (ADR-0041 lesson 1).
- **Dead symlinks accumulate** in `~/.claude/skills` from plugin-cache churn. Untracked, safe to delete: `find ~/.claude/skills -maxdepth 1 -xtype l`.
- Never copy a `.git` dir between roots; never commit the live set into the export repo — curation flows through `curated-skills.txt` only.

Decision record: `~/.claude-env/adrs/0041-*` + memory `adr_0041_skills_canonical_reconcile`. Supersedes `decisions/2026-05-28-skill-catalog-topology-governance.md`.
