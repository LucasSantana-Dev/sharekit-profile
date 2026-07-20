# Composite Skill Contract

The rules every composite skill (`~/.claude/skills/<name>/SKILL.md`) must follow
so the composite-first principle in `~/.claude/CLAUDE.md` actually pays off.
Without a shared contract, composites drift into one-off scripts and the
"chain enforced, no silent bail-out" property evaporates.

## Frontmatter (mandatory)

```yaml
---
name: <kebab-case>                       # matches dir name
description: <one paragraph: WHAT it chains, WHY, WHEN to use>
user-invocable: true                     # composites are always user-invocable
auto-invoke: <comma-separated phrases + signal triggers>
metadata:
  owner: global-agents                   # or repo / org as appropriate
  tier: contextual                       # contextual | always-on | scheduled
  canonical_source: ~/.claude/skills/<name>
---
```

The `description` must name at least one composite this composite *replaces*
when the trigger fires (e.g. "use instead of running test-cleanup + mutation-test
separately"). This is what makes the composite-first principle enforceable —
without it, sub-skills get invoked anyway.

## Required sections

Every composite SKILL.md must have, in this order:

1. **Title (`# Name`)** + one-paragraph purpose
2. **When this fires** — explicit trigger list (user phrases, auto-queue
   conditions, other composites that chain in). Mirrors the
   `auto-invoke` frontmatter row but with full context.
3. **Workflow** — numbered phases. Each phase:
   - One verb in the heading (`### Phase N — <verb> (<sub-skill> | conditional)`)
   - Exact sub-skill invoked (or "n/a — composite logic only")
   - What feeds in from the previous phase
   - What feeds the next phase
   - Skip condition if conditional
4. **Reconciliation block** — the literal template for the mandatory output
   (see below)
5. **Stop conditions** — what aborts the chain vs. what is surfaced and continued
6. **Negative rules** — explicit "do NOT do X" list to prevent drift

Optional but recommended: **Configuration** section if the composite reads a
`.claude/<name>-config.json` (e.g., `dep-sweep`).

## Reconciliation block — canonical format

Every composite must emit a reconciliation block at the end of execution to
report the outcome of every phase. This block must follow a strict format to
enable downstream parsing by `/skill-effectiveness-audit` and handoff automation.

### Structure

The reconciliation block lives in a markdown code fence and has three parts:

1. **Header line** (mandatory)
   - Format: `<COMPOSITE-NAME-UPPERCASE> — <subject>`
   - Example: `HOTFIX — Lucky v2.10.0 → v2.10.1`
   - Subject must uniquely identify what was operated on (repo, feature, bug,
     etc.). No empty subjects.

2. **Phase results** (mandatory, one row per declared phase)
   - Format: Choose **one** of:
     - **Option A: Key:value pairs** (preferred for most composites)
       ```
       Phase name:       <result> [emoji status token]
       ```
     - **Option B: Markdown table** (use only when phase results benefit from
       columnar display, e.g., per-file or per-PR results)
       ```
       | Phase | Summary | Status |
       | ----- | ------- | ------ |
       | <phase> | <result> | [emoji] |
       ```
   - Every declared phase from the Workflow section must appear in results.
     No silent omission.
   - **Skipped phase**: `Phase name: (skipped: <reason>)` — e.g.
     `(skipped: precondition not met)`
   - **Failed phase**: `Phase name: (failed: <reason>)` — e.g.
     `(failed: out of quota)`. Chain halts per Stop conditions section.
   - **Successful phase**: `Phase name: <one-line summary>`

3. **Status tokens** (mandatory, appended to each phase result)
   - `✅ DONE` — phase completed successfully
   - `🚧 BLOCKED` — phase hit a blocker; composite may continue or halt per
     Stop conditions
   - `🚫 DECLINED` — precondition unmet; phase skipped intentionally
   - `⚠️ DONE_WITH_CONCERNS` — phase completed but produced warnings / partial
     outcomes
   - Token placement: END of the line (after the summary), never at start of
     prose paragraph

4. **Metadata lines** (mandatory when applicable)
   - `Snapshot:` — path to handoff, memory file, or state snapshot; or
     `(none — task ongoing)` if async work continues
   - `Open watch:` — future obligation (e.g., "check deploy health in 24h",
     "re-run tests on v2.0 release"); or `(none)` if this session closes the
     story
   - Any other metadata required by the composite spec (e.g., `Severity:`,
     `Queued:`, `Backport:`, `Deploy:`)

### Canonical template (key:value format)

```
COMPOSITE NAME — <subject>
  Phase 1:         <result summary> ✅ DONE
  Phase 2:         <result summary> ✅ DONE
  Phase N:         (skipped: <reason>) 🚫 DECLINED
  Snapshot:        ~/.claude/handoffs/latest.md
  Open watch:      check <condition> in <timeframe>
```

### Canonical template (table format)

```
COMPOSITE NAME — <subject>

| Phase | Summary | Status |
| ----- | ------- | ------ |
| Phase 1 | <result> | ✅ DONE |
| Phase 2 | <result> | ✅ DONE |

  Snapshot:        ~/.claude/projects/repo/memory/task.md
  Open watch:      (none)
```

### Parsing guarantees

A properly formatted reconciliation block enables these operations:
- Extract composite name from header via regex `^([A-Z][A-Z\s]+) — `
- Parse phase results via `^\s*[\w\s]+:\s` for key:value or `^|` for table
- Extract status tokens via regex `(✅|🚧|🚫|⚠️)\s*[A-Z_]+` at end of line
- Locate snapshot path via grep `^Snapshot:`, extract path or parse "(none)"
- Locate future obligations via grep `^Open watch:`, extract condition or "(none)"

## No silent bail-out

The contract a composite breaks most often is "phase N had no work to do, so I
just stopped." This produces invisible incomplete chains.

Rules:
- If a phase has nothing to do because its precondition isn't met, mark it
  `(skipped: precondition <X> not met)` — do not omit
- If a phase fails partway through, the composite continues to the
  reconciliation block and reports the failure there. Only abort the rest of
  the chain if Stop conditions explicitly allow it.
- A composite that "ran to completion" without a reconciliation block printed
  is considered to have failed the contract regardless of side-effects

## Chain integrity

- Sub-skills inside a composite MUST be invoked via the Skill tool (not
  emulated inline) so their guidelines run. Exception: pure shell phases
  (e.g., `git switch` in `/pr-to-release` Phase 2) which are too thin to wrap.
- Output of phase N feeds phase N+1 explicitly — name what passes through (PR
  URL, ADR path, test path, memory file, etc.). "Implicit context" doesn't
  count.
- If two composites overlap on intent, the precedence rules in
  `skill-auto-invoke.md` (Precedence section) decide. Composites must not
  silently re-invoke each other; if `/hotfix` queues `/incident-response` (Phase 3
  post-mortem), that queue is explicit and visible in the reconciliation block.

## Auto-queue declarations

If composite A auto-queues skill/composite B at the end (e.g., `/hotfix` →
`/incident-response` Phase 3), this must be:
- Declared in A's "When this fires" of B (auto-queued by A)
- Declared in A's reconciliation block as `Queued: /<B>`
- Listed in `skill-auto-invoke.md`'s "Auto-chain pairs" section

Implicit auto-queues are forbidden — they make the chain unobservable.

## Configuration files

When a composite reads a config file (e.g., `dep-sweep-config.json`), it must:
- Document every field in its Configuration section
- Provide a defaulted fallback when the file is absent — never refuse silently
- Live under the consuming repo's `.claude/` directory (never `~/.claude/`),
  because configuration is per-repo

## Validation checklist (run before merging a new composite)

- [ ] Frontmatter has all required fields
- [ ] Description names the composite(s) or sub-skills it replaces
- [ ] All 6 required sections present, in order
- [ ] Reconciliation block template literal-text matches the format above
- [ ] Stop conditions cover: precondition-fail, mid-chain-fail, indefinite-defer
- [ ] Negative rules include at least "do NOT skip the reconciliation block"
- [ ] Trigger row added to `skill-auto-invoke.md`
- [ ] Pattern added to `composite-router.sh` (if intent is detectable from a
      free-text prompt)
- [ ] If composite auto-queues another, both ends declare it
- [ ] Composite-first row added to `CLAUDE.md` if it replaces 2+ common
      sub-skills

## Versioning + deprecation

When a composite is replaced by a more specific one (e.g., `/merge-confidently`
→ `/pr-to-release` in release-branch repos), the older composite is NOT deleted
— it keeps its trigger for repos where the new one doesn't apply. The router
must branch on environment (presence of `release` branch, monorepo flag, etc.)
to pick.

Deletion only happens when:
- The composite has had zero invocations across all tracked repos for ≥90 days
  (check `skill-effectiveness-audit` output)
- AND a replacement covers every documented trigger phrase
- AND a deletion ADR is written under `~/.claude/projects/<project>/adr/`

## Migration tracking

The audit list of existing composites and their WAVE2 migration status lives in
[archive/composite-contract-migration-wave2.md](archive/composite-contract-migration-wave2.md)
— transitional tracking, not canonical contract material.
