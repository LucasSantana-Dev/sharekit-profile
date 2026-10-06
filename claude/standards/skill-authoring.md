# Skill Authoring

One standard for writing, checking, routing and cataloging skills. Sections: Quality checklist, Patterns (cite by `standards/skill-authoring.md §<anchor>`), Catalog topology, MCP manifest, Trigger map.

## Quality checklist

**Hard constraint: preserve behavior.** Improvements may not change what a skill does, its invocation contract, or (composites) its phase chain / reconciliation contract. If a fix would alter behavior, surface it, do not apply it.

1. **Trigger-rich description**: `description:` names >=3 distinct trigger branches; words recur in the body.
2. **Progressive disclosure**: only actionable steps in SKILL.md (target < ~150 lines); lists > ~10 items and reference material go to `references/`.
3. **RAG-first discovery**: a skill answering "what did we decide / where did we hit this" queries RAG in Step 1, BEFORE wide grep/read.
4. **No-ops eliminated**: every sentence overrides a model default; cut "be thorough" filler.
5. **Explicit completion criteria**: each step ends on a checkable done-condition.
6. **Signal-first output**: verdict + top-3 inline; bulk gated or in a reference file.
7. **Stop/failure conditions named**: >=1 explicit "if X missing, surface blocker, halt" (no silent fallback). Mount guard where External HD is touched.
8. **Cross-link, don't duplicate**: cite `standards/<file>.md §N`; name auto-chain skills and their condition.
9. **Exact RAG snippets embedded**: real command syntax (see RAG patterns), not "search for X".
10. **Metadata complete**: frontmatter name and description; metadata.owner, metadata.tier, metadata.canonical_source for overlays.
11. **Parallelism signaled**: >=2 independent units, say "in a single message"; parallel git ops note worktrees.
12. **No stale refs**: no retired tools or broken paths. Use rag_query / search_knowledge for memory lookup.
13. **Reference naming**: `references/workflow.md`, `output-patterns.md`, `schemas.md`; no duplication with SKILL.md.

Anti-patterns: grep-before-RAG, rules copied from standards, SKILL.md/reference duplication, vague completion, silent fallback on blocked ops, obsolete tool names, sequential dispatch of independent work.

**Apply:** run the 13 checks; for each "no" apply the matching pattern below; replace duplicated rules with pointers; confirm behavior unchanged; output before/after line count and checklist delta.

**Deterministic floor:** `hooks/skill-quality-gate.sh` (PostToolUse, exit 2 blocks) HARD-fails invalid frontmatter YAML, missing `---` block, unclosed code fence; SOFT-warns on name/dir mismatch (an intentional adt-* or plugin-* namespace is allowed) and structure. `SKILL_GATE_BYPASS=1` for WIP. `scripts/harness-skill-scorecard.py` emits `structural_score_pct`; a PR that lowers it introduced broken skills.

## Patterns

### completion-criteria
End each step with a bold `**Done when:**` line checkable without judgement, exhaustive ("every modified model accounted for"), never "ready" / "looks good".

### stop-conditions
At least one named blocker per skill, never a silent fallback returning misleading output: a preventative guard (before work) and a reactive blocker (mid-work). Format: `**Stop if:** <precondition> missing` then `BLOCKED: <condition> / Missing: <what resolves it> / Next: <how to proceed>`.

### progressive-disclosure
Move each table / config block / >15-line example to `references/<name>.md` and leave one `See [references/<name>.md](references/<name>.md).` line. No content in both places; every file in `references/` is cited at least once (no orphans). Inline what every run needs.

### parallelism-signaling
Independent steps: "Dispatch both in a single message (one Agent() call each)". Parallel git-touching work: each agent in its own worktree under `${DEV_ROOT}/.worktrees/<task>-<n>/`; read-only fan-out needs none.

### rag-first
Skills answering prior-decision / prior-result questions add a **Step 0** querying memory before grep. Done when RAG was queried and prior work cited or confirmed absent.
```bash
python3 ~/.claude/rag-index/query.py "<topic> prior result" --top 5 --scope memory   # prior result
python3 ~/.claude/rag-index/query.py "<name> existing" --top 5                        # name collision check
```
```
rag_query(query="<q>", top=5, scope_types=["memory","handoffs"])  # MCP rag-index, decisions only
search_knowledge(query="<question>", top=5)   # knowledge-brain vault, cross-project decisions
mcp__serena__find_symbol(name="<symbol>")     # exact defs / call edges before refactor
graphify query "<codebase question>" --budget 500   # when graphify-out/graph.json exists
```
Canonical reference: `~/.claude/skills/recall/SKILL.md`.

### mount-guard
**Mandatory** before any RAG-index or knowledge-brain reliance (embedder cache and vault live on External HD, knowledge-brain.md §1). Place before the first `rag_query` / `search_knowledge`:
```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted, RAG/vault unreachable"; exit 1; }
```
If unmounted: say so plainly, fall back to grep, never return a confident-looking empty result.

### signal-first-output
Verdict line first (READY / NOT READY / PASS / N issues), then Top 3 with evidence, then "(N more, ask or see <path>)". Exempt: composite reconciliation blocks and plans with <4 phases.

### trigger-design
The description field lists >=3 genuinely distinct trigger branches (different intents, not synonyms; collapse triggers that always co-occur). Front-load the leading word: `<lead verb + what>. Use when <b1>; when <b2>; or when <b3>.`

### reasoning-scaffold
Scaffold any delegated prompt, any prompt with >=3 ordered steps, or any with a skippable gate (`standards/prompting-discipline.md`). Fields: Goal (observable end state); Steps (numbered, name file/command, last step is a verification: run <cmd>, expect <result>; non-optional); Constraints; Output (exact shape); Stop when <success>, escalate if <blocker> instead of guessing.

### structured-output
Force result shape: in `Workflow`, pass a JSON schema to `agent()` (validated, retried on mismatch); for inline subagents name the exact output contract. Done when the result is consumed as data, never regex-scraped from prose.

### read-only-agent
Make "does not edit" structural, not prose. Analysis phases (research, triage, audit, review, spec) dispatch a write-incapable `agentType`: `Explore | Plan | critic | code-reviewer | security-reviewer | overengineering-auditor`. Only explicit implementer stages get general-purpose / debugger / test-engineer. Done when every findings-returning agent is write-incapable and edits are applied by the orchestrator or a separate implementer stage.

## Catalog topology

Canonical is the only source of truth: `~/.agents/skills/` (`skills.git`) for skills + standards (`~/.claude/skills`, `~/.claude/standards`, `~/.codex/skills` symlink into it). Mirror: `~/.claude-env/skills|standards/` (downstream only; claude-env stays canonical for non-skill dotfiles). Export: the sharekit-profile repo (curated via `curated-skills.txt`; never hand-edit).

- Skill/standard edit = edit `~/.agents/skills/...` AND commit+push `skills.git` in the same session. Do not rely on the SessionStart WIP auto-commit.
- Mirror-only commits are incomplete: commit canonical first, mirror follows via sync.
- Multi-machine divergence: 3-way merge, never "keep newer local"; verify superset claims with `git diff`, not subagent summaries.
- Dead symlinks: delete on BOTH roots or they return (`sync pull` rsyncs without `--delete`): `for d in ~/.agents/skills ~/.claude-env/skills; do (cd "$d" && find . -maxdepth 1 -type l ! -exec test -e {} \; -delete); done`
- Never copy a `.git` dir between roots; never commit the live set into the export repo.

## MCP manifest

Declare needed MCP servers in frontmatter so a skill never silently runs degraded: `mcp_servers: [rag-index, serena]` (flow or block list; omit when none). Names from `python3 ~/.claude/scripts/skill-mcp-check.py --list-available`. Validate with `skill-mcp-check.py <skill>` or `--all` (exit 1 on MISSING); run `--all` as a lint (pre-commit, `/skill-effectiveness-audit` step 0, before forgekit). MISSING means the skill will malfunction here: fix the declaration or configure the MCP. `scripts/forgekit-package-mcp.py` emits `mcp.json` from the field.

## Trigger map

Workflows auto-trigger on task shape, not only slash commands. Pruned skills stay invocable by explicit `/name`. Standing reactive watch: if a real intent stops auto-routing to `incident-response`, `debug-deep` or `pr-to-release` (kept despite zero use), restore its row from git immediately.

### Composite-first principle
**When multiple skills could fit and one is a composite chaining them, ALWAYS prefer the composite.** Composites enforce auto-chaining, reconciliation and stop conditions that single skills lack. Example: "the test suite is bad" invokes `fix-the-suite`, NOT `test-cleanup`.

### Composite triggers
Overlap: "prod is down" appears under both `hotfix` and `incident-response`; the router checks production-impact language first (incident-response), then hotfix on P0/SEV/emergency wording. See Precedence below.

- `merge-confidently`: "merge this", "ship this PR", "is this ready to merge"; DIRECT-TO-MAIN repos only (no release branch).
- `pr-to-release`: "open a PR", "merge this", "ship this change" when a release branch exists (the router probes origin for it, so "merge this" routes here, not to merge-confidently). Lands the change on release with a single `[Unreleased]` changelog line; does NOT cut a version. Kept despite zero direct use as the conditional target of the still-used merge intent.
- `release-cut`: "cut the release", "tag a version"; MANUAL fire only; nudge when `main..release` >= 5 commits.
- `hotfix`: "prod is down", "hotfix", "emergency fix", "P0", "SEV-1/2", "users can't X right now"; bypasses release branch, patches main directly, cherry-picks back to release.
- `ship-it`: "deploy to prod", "release this" (post-merge).
- `debug-deep`: bug already tried once, "intermittent", "prod but not local".
- `research-and-decide`: "X or Y", "is X worth adopting", library/SaaS choice.
- `knowledge-loop`: "remember this", "what did we decide", end-of-task, and the `STOP checkpoint` line from `knowledge-loop-nudge.sh` (an invocation, not a suggestion).
- `incident-response`: "prod is down", "users reporting X", "Sentry firing", post-deploy new errors, intermittent in prod (Phases 1-2: triage + mitigate); "postmortem", "incident review", "what did we learn", "write up the incident" (Phase 3, auto-queued by `/hotfix` Phase 10 and after any rollback).
- `branch-hygiene`: "clean up branches", "stale worktrees"; suggest when local branches > 30.
- `backlog`: "build a backlog", "what should I work on", "audit and plan".
- `spec-driven-develop`: **default for non-trivial build/add/fix/implement/refactor** with no more specific composite; check BEFORE `scope-and-execute`/`parallel-phases` (fallback only for e.g. read-only analysis). Skip for trivial edits (<3 files, mechanical).
- `audit-deep`: "is this project healthy", weekly per active repo, pre-release.
- `kali-docker-pentesting`: exploitation, cracking, AD/SMB, wireless, RE (Linux-only lane). NOT recon: `bugbounty-recon` and `hack` stay on host.
- `silent-failure-hunt`: "audit the harness", job/hook/gate suspected not firing, stale artifact, harness-vitals warning.
- `docs-sync`: after editing any skill / standard / hook.

### Core single skills (only when no composite matches)
`route` (workflow not obvious), `next-priority` (entering a repo), `plan` (multi-step/risky), `secure` (config/auth/credentials/deps), `ci-watch` (failing checks), `verify` (before merge/release/handoff), `ship` (merge-ready; ONLY if `merge-confidently` fits worse), `handoff` (context tight / session switch).

- `repaint` is the route for ANY non-trivial UI work (build, restyle, polish, audit); its Phase 4 audits inline. `observe` is the single observability skill (instrument/debug/tune/analyze/monitor/bootstrap/audit, one mode per invocation); do NOT wire the full stack on local-only or hobby code with no production-shaped target; not for `/debug-deep`, `/incident-response`, `/sentry`, `/langfuse-observe`.

### Hook-routed individual skills
composite-router emits ` Skill match: /<name>` only when no composite matches first; invoke it when seen. To add one: append a matcher in `composite-router.sh` before the `scope-and-execute` catch-all, add the name to the non-composite case at the bottom, mirror and commit. Current: `code-review` (chat report by default; posts to a PR only with explicit `--pr N --comment`), `adr-write`, `performance-audit`, `config-drift-detect`, `handoff`.

### Auto-chain pairs (when one fires, queue the next)
- `test-cleanup` outputs: ALWAYS chain `mutation-test`.
- Any skill edit: ALWAYS chain `docs-sync`.
- Pre-`ship`: ALWAYS chain `pr-merge-readiness` (or use `merge-confidently`).
- Pre-`refactor`: ALWAYS chain `config-drift-detect`.
- After hook wiring: ALWAYS queue `hook-effectiveness` for next session.
- Bail-out from any skill: ALWAYS queue `skill-effectiveness-audit`.
- Major decision: ALWAYS chain `adr-write`.
- After every `pr-to-release` merge or `dep-sweep` auto-merge: check `main..release`; if >= 5 surface the `/release-cut` nudge.
- After `hotfix` merges to main: ALWAYS cherry-pick back to release (Phase 10).
- After `hotfix` Phase 10 (defer if <6h since incident) or any revert/rollback to main: ALWAYS queue `/incident-response` Phase 3.
- `repaint` audits inline (Phase 4); do not declare UI done while criticals remain; it authors `DESIGN.md` in token-spec when missing.

### Release-branch model
With a long-lived release branch: work to `/pr-to-release`, bot PRs to `/dep-sweep`, batch to `/release-cut`, unwaitable breakage to `/hotfix` (only acceptable bypass). First contribution to a new repo: `/onboard-new-repo` then `/pr-to-release`. `/pr-to-release` does NOT call `version-bump` or `ship`; only `/release-cut` and `/hotfix` create tags.

### Negative rules
- Diagnostic skills run on a launchd schedule (Sundays 03:00). Do not invoke them unless asked.
- Do NOT auto-invoke specialized domain skills unless the task clearly matches.
- Do NOT auto-invoke mega-composites (e.g. feature-from-zero) for trivial one-file edits.
- Do NOT invoke `session-bootstrap` mid-session, only on the first non-trivial prompt.
- Do NOT invoke `incident-response` for dev-time bugs; use `debug-deep`.
- Do NOT invoke sub-skills when their composite covers the intent.

### Precedence when multiple match
1. Prefer the more specific (`incident-response` over `debug-deep` if production-impacting).
2. Build/add/fix/implement/refactor with no lifecycle composite matched: `spec-driven-develop` over `scope-and-execute`/`parallel-phases`.
3. Prefer the more contained scope (`scope-and-execute` over feature-from-zero if not greenfield).
4. Prefer the read-only diagnostic before the action (`test-health` before `fix-the-suite` if state unknown).

If unsure, invoke `route`.
