---
name: bootstrap-project
description: "Set up a new project's centralized knowledge-brain presence in one ritual: memory scaffold (One-Brain symlink), seed memories, context docs, and centralized graph. Registers in brain index and ships with sharekit-profile for identical bootstrapping across machines. Auto-chains /onboard-new-repo for non-greenfield projects."
triggers:
  - bootstrap project
  - bootstrap this project
  - set up the brain
  - initialize knowledge
  - new project memory
---

# bootstrap-project

One command to give a new project structure instead of an empty void: a place in the
centralized brain (ADR-0029), seed memories, initial context, and a centralized graph —
consistent across machines via `sharekit-profile`.

**This skill is part of:** the centralized `knowledge-brain` vault AND the distributable
`sharekit-profile` (so `sharekit applyProfile` installs it everywhere). See *Distribution*.

## Auto-invocation triggers

- "bootstrap this project", "set up the brain for this", "initialize knowledge for <repo>"
- Starting a brand-new/greenfield repo, or any repo with no brain presence yet
- After `git init` on a new project, or first time entering a repo you'll own long-term
- NOT for understanding an existing unfamiliar repo → that's `/onboard-new-repo` (this
  auto-chains it when the target already has code)

## Preconditions

- External HD mounted (the brain + RAG embedder live there — standards/knowledge-brain.md §1).
- A project path (defaults to cwd). A git repo is helpful (name + inference) but not required.

## Workflow — 6 phases

The deterministic, idempotent structure is done by `scripts/bootstrap.sh`; the **content**
(seed-memory text, context) is filled by you (the agent) via repo inference between phases.

### Phase 0 — Detect & guard
Run `bash scripts/bootstrap.sh --dry-run [<path>]` first to print the plan: detected name
(git remote basename → dir name), slug (`<abs-path>` with `/`→`-`, matching the
`~/.claude/projects/<slug>` convention), and what each phase would create. Mount-guard +
idempotency check (already in `knowledge-brain/PROJECTS.md` → "already bootstrapped; pass
`--update`").
**Done when:** plan printed, name/slug confirmed, not-already-bootstrapped (or `--update`).

### Phase 1 — Memory scaffold (One-Brain)
The script ensures `~/.claude/projects/<slug>/memory` is a **symlink** to the vault
`knowledge-brain/memory/` (every project shares one memory pool, tagged by `project/<name>` —
ADR-0029). No per-project memory dir is created; that would fork the brain.
**Done when:** symlink exists (created or already present); never clobbers a real dir.

### Phase 2 — Seed initial memories (infer → confirm)
The script writes three **stub** notes tagged `project/<name>`: `<name>-overview.md`,
`<name>-conventions.md`, `<name>-decisions.md`. **You then fill them by inference:**
- Read `README*`, `package.json`/`pyproject.toml`/`go.mod`/`Cargo.toml`, the entry points,
  the dir tree, and recent `git log` to draft: what the project is, its stack, how it's run,
  conventions, and any decisions already visible.
- Apply the taxonomy (`standards/memory-vs-documentation.md`): only **portable / how-we-work**
  facts go in memory. Project-specific canonical facts belong in the repo (Phase 3), not memory.
- **Show the drafts for a quick edit before finalizing** (the chosen "infer, then confirm" mode).
  Truly-empty greenfield dir → leave the stubs as templates to fill later.
- Add ONE curated pointer per project to `MEMORY.md` (One-Brain: the index stays small — do
  NOT mass-add pointers; see the knowledge-brain memory note).
**Done when:** the 3 seed notes have real (or intentionally-stub) content; `MEMORY.md` has a
single project pointer; `case_quality`-clean (no imperative/placeholder labels).

### Phase 3 — Initial context (repo-side, per the taxonomy)
Scaffold the repo's `CLAUDE.md` (or `CONTEXT.md` if `CLAUDE.md` exists) IF missing: project
identity, stack, run/test commands, conventions, and a back-link to the brain
(`knowledge-brain` + `project/<name>` tag). This is **project documentation** → it lives in
the repo and is committed there (not the vault). If `CLAUDE.md` already exists, augment, don't
overwrite. (Reuse `/init` if you prefer its template.)
**Done when:** repo has a CLAUDE.md/CONTEXT with identity + brain back-link; committed or staged.

### Phase 4 — Centralized graph
The script creates `knowledge-brain/graphs/<name>/` and symlinks the repo's `graphify-out` →
that central dir (mirroring the memory One-Brain pattern), so the graph is built locally but
**stored centrally** and synced. Then run the graph build:
```bash
graphify                      # builds into graphify-out → resolves to knowledge-brain/graphs/<name>/
```
If the repo already has a real `graphify-out/`, the script leaves it and tells you to move it
once (then it becomes the central copy). Per graphify-discipline: a graph existing means future
sessions query it before wide greps.
**Done when:** `knowledge-brain/graphs/<name>/graph.json` exists (built) OR the symlink + a
"run graphify to populate" note is in place.

### Phase 5 — Register + distribute + sync
- Script appends the project to `knowledge-brain/PROJECTS.md` (the centralized registry: name,
  path, graph, date).
- Push the brain (memory + graph + registry): `git -C "$BRAIN" add memory graphs PROJECTS.md && commit && push` (mount-guarded).
- **If the target repo already has code** → auto-chain `/onboard-new-repo` (understand + health
  + config-drift) so a non-greenfield bootstrap also gets the intake pass.
**Done when:** registry updated; brain pushed (or push deferred with reason); onboard-new-repo
queued iff repo has code.

## Reconciliation (signal-first)

```
BOOTSTRAP-PROJECT — <name>
  Detect:   name=<name> slug=<slug> path=<path>  [new | already-bootstrapped(--update)]
  Memory:   symlink <created|exists> ; seeds <3 filled | stubs | skipped> ; MEMORY.md +1
  Context:  CLAUDE.md <created|augmented|exists> (repo)
  Graph:    graphs/<name>/ <built N nodes | symlinked, run graphify> 
  Register: PROJECTS.md +<name> ; brain push <pushed <sha> | deferred: <reason>>
  Chain:    /onboard-new-repo <queued (repo has code) | skipped (greenfield)>
  Open:     <next action | (none)>
```

## Stop / failure conditions

- **External HD unmounted** → BLOCKED (brain unreachable). Surface; do not write a partial brain.
- **Target already bootstrapped** (in `PROJECTS.md`) and no `--update` → stop structural setup,
  report it; offer `--update` to refresh seeds/graph.
- **Existing real `memory/` dir** at the project (not a symlink) → do NOT clobber; surface for
  manual reconciliation (a forked brain must be merged deliberately).
- **Empty greenfield (no repo signals)** → seeds stay as stubs (don't hallucinate content);
  note "fill seeds after first real work".

## Distribution (keep the kit in sync)

This skill must exist in three places (the orchestrator/`/docs-sync` keeps them aligned):
1. **Live:** `~/.claude/skills/bootstrap-project/` (this file) — runs now.
2. **Shared kit source:** `~/.claude-env/skills/bootstrap-project/` — synced across machines.
3. **Distributable profile:** `sharekit-profile/claude/skills/bootstrap-project/` — what
   `sharekit applyProfile` installs on a fresh machine.
After editing here, copy to (2) and (3) and commit both (per CLAUDE.md docs-sync chaining).

## Related

- `standards/memory-vs-documentation.md` — what's memory vs repo-doc (Phases 2–3).
- ADR-0029 — centralized shared brain (the One-Brain symlink model).
- ADR-0038 — knowledge-index taxonomy + card-only ephemeral.
- `/onboard-new-repo` — understand an existing repo (auto-chained in Phase 5).
- `/repo-bootstrap` — **different concern, don't confuse:** release branch + CI + `.claude/`
  config (DevOps scaffolding). bootstrap-project does KNOWLEDGE (memory/graph/context); the two
  complement and can both run on a fresh repo. Keep them separate skills.
- `/graphify`, `standards/graphify-discipline.md` — graph build + query-first discipline.
- `/sync-memories`, `/handoff` — ongoing capture after bootstrap.
