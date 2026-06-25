# Sync & Documentation Skills

`docs-sync` after editing any skill, standard, or hook — prevents silent drift across the three-location sync map. `dev-assets-sync` to back up Claude configs and memories. `graphify` to turn a codebase or docs folder into a queryable knowledge graph.

---

## /docs-sync

Detect and reconcile drift between canonical skills/standards and their mirrored copies (~/.claude-env, ~/.claude, ~/.agents).

**Synchronizes:**
- SKILL.md files (canonical → mirrors)
- Standard policies (canonical → mirrors)
- Agent definitions
- Hook scripts

**Locations:**
- Canonical: `~/.agents/skills/`
- Local: `~/.claude/skills/` (symlink)
- Env: `~/.claude-env/skills/`

**When to use:** After editing any skill/standard/hook; prevent drift

**Output:** Synced copies + drift report

---

## /adt-bilingual-readme-sync

Keep EN/PT README.md pairs in parity across a repo (and across twin repos).

**When to use:** Maintaining EN/PT documentation pairs

**Process:**
1. Read EN README
2. Check PT README for same structure
3. Flag sections missing in PT
4. Sync structure, update content markers

**Output:** Bilingual README parity maintained

---

## /adt-sync-pt-parity

Sync files from EN canonical repo to PT mirror, inserting "Tradução pendente" blockquote, then open PR.

**Process:**
1. Identify files in EN not in PT
2. Copy files to PT repo
3. Insert "Tradução pendente" blockquote
4. Open PR on PT repo

**When to use:** Adding EN content that needs PT translation

**Output:** PT PR with placeholder + translation marker

---

## /dev-assets-sync

Run the dev-assets backup sync — rsyncs Claude configs, memories, standards, hooks, and per-project files to dev-assets repo.

**Backs up:**
- ~/.claude/ (configs, memories, hooks)
- ~/.agents/ (skills, standards, agents)
- ~/.claude-env/ (ADRs, env-specific state)
- Per-project .claude/ folders

**When to use:** Backup Claude state; periodic sync

**Output:** Backup complete + sync log

---

## /graphify

Turn any folder of files into a navigable knowledge graph. Use for any codebase or document question.

**Creates:**
- Knowledge graph (nodes = files/concepts, edges = references)
- Query interface (ask questions about relationships)
- Visualization (graph layout)

**When to use:** Any codebase or document question; graph-based search

**Output:** Queryable knowledge graph

---

## /audit-website

Audit websites with the squirrelscan CLI and turn results into an actionable report.

**Audits:**
- Links (broken, redirects)
- Performance (page load, Core Web Vitals)
- Accessibility (WCAG compliance)
- SEO (meta tags, structured data)
- Security (HTTPS, CSP, etc.)

**When to use:** Website health check; pre-launch audit

**Output:** Audit report + remediation checklist

---

**Last updated:** 2026-06-25
