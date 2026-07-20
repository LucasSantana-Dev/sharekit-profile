# Skill Quality Spec

Contract for improving skills (SKILL.md files). An implementer applies it; a
reviewer verifies compliance criterion-by-criterion. Source: /skill-maintainer +
/research-and-decide session 2026-06-22 (research agent + verified RAG commands).

**Hard constraint — preserve behavior.** Improvements may not change what a skill
*does*, its name's invocation contract, or (for composites) its phase chain /
reconciliation contract. Efficiency and clarity only. If a "fix" would alter
behavior, surface it instead of applying.

## Checklist (verifiable, yes/no per criterion)

1. **Trigger-rich description** — frontmatter `description:` names ≥3 distinct
   trigger branches/synonyms; words recur in the body. Verify: read frontmatter,
   count "when/use when"-separated branches.
2. **Progressive disclosure** — only immediately-actionable steps in SKILL.md;
   reference material in `references/`. Target SKILL.md < ~150 lines (reference-heavy
   skills); inline lists > ~10 items move to `references/`. Verify: line count + scan.
3. **RAG-first discovery** — if the skill answers "what did we decide / where did we
   hit this / how did we do X", Step 1 queries RAG BEFORE wide grep/read. Verify:
   Step 1 invokes one of the patterns below.
4. **No-ops eliminated** — every sentence overrides a model default. Cut "be thorough"
   filler. Verify: 3 random sentences — would skipping each weaken output?
5. **Explicit completion criteria** — each step ends with a checkable done-condition
   ("all N tests passing", not "ready"). Verify: last sentence of each step.
6. **Signal-first output** — findings/reports lead with verdict + top-3 inline; bulk
   gated ("ask for full list") or in a reference file. (CLAUDE.md signal-first rule.)
7. **Stop/failure conditions named** — ≥1 explicit "if X missing → surface blocker,
   halt" (no silent fallback). Mount guard where external drive is touched.
8. **Cross-link, don't duplicate** — cite `standards/<file>.md §N` instead of copying
   rules inline; name auto-chain skills + their condition.
9. **Exact RAG snippets embedded** — search/lookup steps show real command syntax (not
   "search for X"). Use the verified patterns below.
10. **Metadata complete** — `name`, `description` present; `metadata.owner`/`tier`/
    `canonical_source` where the skill is an overlay.
11. **Parallelism signaled** — when dispatching ≥2 independent units, say "in a single
    message"; parallel git ops note worktrees (CLAUDE.md parallel-execution rule).
12. **No stale refs** — no retired tools / broken paths. NOTE: claude-mem ingestion is
    currently broken (218k stuck); don't add new hard dependencies on it — prefer
    `rag_query`/`search_knowledge`.
13. **Reference naming convention** — `references/workflow.md`, `output-patterns.md`,
    `schemas.md`, etc.; no duplication with SKILL.md.

## Model-Independence Gate (deterministic floor)

The 13 points above lift quality but require a *capable reviewer* to verify — a weaker model
grading them may pass a broken skill. Beneath them sits a deterministic floor that holds
**regardless of which model is involved**, because a script enforces it, not judgment:

| Check | Severity | Enforced by |
|---|---|---|
| Frontmatter parses as valid YAML | **HARD** (won't load) | `hooks/skill-quality-gate.sh` (PostToolUse, exit 2 blocks) |
| Frontmatter present (`---` block) | **HARD** | same |
| Code-fence parity (no unclosed ```` ``` ````) | **HARD** | same |
| `name` matches dir (or intentional `adt-*`/`plugin-*` namespace) | SOFT | same (warn) |
| Size / Done-when / Stop-conditions / workflow structure | SOFT | same (warn) |

- **On edit**, the hook blocks a structurally-broken SKILL.md from being saved — a weak model
  *cannot* ship one even if it doesn't notice the breakage. `SKILL_GATE_BYPASS=1` for intentional WIP.
- **Across the catalog**, `scripts/harness-skill-scorecard.py` runs the same checks over every
  skill and emits `structural_score_pct` — the harness's first objective, model-independent quality
  number. Re-run after any batch change to prove a delta (baseline 2026-06-26: 85.4% → 100% after
  the invalid-YAML + frontmatter sweep). Use it as a regression gate: a PR that lowers the score
  introduced broken skills.

This is point 7 of the model-independence research (component eval gates / regression baselines) —
the structural gate is *why* skill quality no longer depends on the reviewing model noticing the
defect. The 13 points are the ceiling; this gate is the floor that never drops.

## Verified RAG / knowledge invocation patterns

Canonical reference: `~/.claude/skills/recall/SKILL.md`. Skills should point to it
rather than re-documenting all four sources.

```
# 1. RAG index — semantic, repo-scoped (memory, plans, handoffs, skills, code, commits)
rag_query(query="<question>", top=5)               # MCP (rag-index server)
rag_query(query="<q>", top=5, scope_types=["memory","handoffs"])  # decisions only
# shell equivalent:
python3 ~/.claude/rag-index/query.py "<question>" --top 5 [--scope memory] [--format json] [--fast]

# 2. Knowledge-brain vault — cross-project decisions/memory (preferred for "what did we decide")
search_knowledge(query="<question>", top=5)        # MCP; vault-only, no code/commits

# 3. claude-mem observations — full text / project-scoped (ingestion currently broken; read OK)
mcp__plugin_claude-mem_mcp-search__search(query="<keywords>", limit=5)

# 4. Serena LSP — exact symbol defs + call edges (before refactor / wide grep)
mcp__serena__find_symbol(name="<symbol>")
mcp__serena__find_referencing_symbols(name="<symbol>")

# 5. graphify — codebase relationships when graphify-out/graph.json exists (graphify-discipline.md)
graphify query "<codebase question>" --budget 500
```

**Mount guard (required before brain/RAG reliance — knowledge-brain.md §1):**
```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: external drive unmounted — RAG/vault unreachable"; }
```
If unmounted: `rag_query` (embedder cache on external drive) and `search_knowledge`
degrade; say so plainly, fall back to claude-mem + grep, do not return empty/misleading.

## Anti-patterns to cut

grep-before-RAG · rules copied from standards (cite instead) · SKILL.md/reference
duplication · vague completion ("ready", "looks good") · silent fallback on blocked
ops · explaining a concept fresh instead of a leading word · obsolete tool names ·
sequential dispatch of independent work.

## How to apply (implementer)

Copy-pasteable templates for every pattern below live in
`standards/skill-patterns.md` (cite by anchor, don't re-explain).

1. Run the 13-point checklist (yes/no).
2. For each "no", apply the fix from `skill-patterns.md §<pattern>`; for RAG steps paste the exact pattern above.
3. Replace inline duplicated rules with `standards/<file>.md §N` pointers.
4. Move bulk > ~150 lines to `references/`.
5. Confirm behavior/contract unchanged (esp. composite phase chains).
6. Output a before/after line-count + checklist delta.
