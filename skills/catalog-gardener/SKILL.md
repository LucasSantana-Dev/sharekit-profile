---
name: catalog-gardener
description: "Audit skill catalog for rot, dead links, oversize files, and orphans. Detect stale generated artifacts, skills exceeding size limits, and skills not referenced by any composite or routing rule. Output severity-ranked report with remediation hints."
triggers:
  - catalog gardener
  - skill rot
  - dead links
  - oversize skills
  - orphan skills
  - skill audit
---

# catalog-gardener

Audit the skill catalog for health issues that accumulate over time.

## Checks

### 1. Dead links (CRITICAL)
Scan all SKILL.md files for broken references:
- Markdown links `[text](path)` where path does not exist
- Relative paths to references/, agents/, scripts/ that are missing
- URLs that return 404 (optional, network-dependent)

### 2. Stale generated artifacts (HIGH)
Detect files that look generated but are outdated:
- Files with `generated_at` or `auto-generated` headers older than 30 days
- Lock files or manifests referencing deleted skills
- Cached data files with stale timestamps

### 3. Oversize skills (MEDIUM)
Flag skills exceeding size limits:
- Body >8KB (excluding frontmatter and references/)
- Context file >150 lines (the skill's main SKILL.md)
- Total skill directory >50KB (including references/)

### 4. Orphan skills (MEDIUM)
Skills not referenced by any composite or routing rule:
- Not mentioned in any composite skill's phase list
- Not in the auto-invoke trigger map
- Not referenced by any agent's dispatch logic
- Not in the curated-skills.txt showcase

### 5. Frontmatter completeness (LOW)
Skills missing required frontmatter fields:
- `name` (required)
- `description` (required, >20 chars)
- `triggers` (required, at least 1)

## Execution

```bash
# Run full audit
./skills/catalog-gardener/run.sh

# Or invoke via skill
/catalog-gardener
```

## Output format

Severity-ranked report:

```
CATALOG AUDIT — 2026-06-29

CRITICAL (2):
  - claude/skills/old-tool/SKILL.md:3 — dead link to references/old-api.md
  - claude/skills/broken-ref/SKILL.md:12 — dead link to ../agents/retired.md

HIGH (1):
  - claude/skills/stale-cache/SKILL.md — generated artifact 45 days old

MEDIUM (3):
  - claude/skills/huge-skill/SKILL.md — body 12.4KB (limit 8KB)
  - claude/skills/long-context/SKILL.md — 187 lines (limit 150)
  - claude/skills/orphan-skill/SKILL.md — not referenced by any composite

LOW (5):
  - claude/skills/no-triggers/SKILL.md — missing triggers field
  ...

Remediation:
  - Dead links: update or remove broken references
  - Stale artifacts: regenerate or delete
  - Oversize: split into references/ or trim content
  - Orphans: add to composite routing or archive
  - Frontmatter: add missing fields
```

## Remediation hints

- **Dead links**: Update the link target or remove the reference. If the target was renamed, update the path.
- **Stale artifacts**: Regenerate the artifact or delete it if no longer needed. Add a regeneration trigger if it should stay fresh.
- **Oversize skills**: Move detailed content to `references/` subdirectory. Keep SKILL.md under 8KB body, 150 lines.
- **Orphan skills**: Either add the skill to a composite's phase list, add it to the auto-invoke map, or archive it if no longer useful.
- **Frontmatter**: Add the missing fields. Use the skill-creator skill for proper frontmatter format.

## When to run

- Quarterly (scheduled via launchd or cron)
- After large skill refactors or merges
- When skill discovery feels slow or inaccurate
- Before releasing a new harness version
