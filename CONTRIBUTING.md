# Contributing to sharekit-profile

Thanks for considering a contribution. This doc covers how to get set up, what
gets checked before merge, and where things live.

## Before you start

- **Small fix (typo, doc drift, single-hook bug):** open a PR directly.
- **Anything bigger (new skill, new hook, behavior change):** open an issue
  first so the approach can be discussed before you invest the work. This
  repo enforces a behavioral eval gate (see below) — a design that regresses
  routing accuracy won't merge no matter how well-written the code is, so it's
  worth confirming direction early.

See [`README.md § Repository Structure`](README.md#repository-structure) for
what each top-level directory is for, and [`AGENTS.md`](AGENTS.md) for the
governance model (`.harness/constitution.json`, hard rules, hook firing order).

## Dev setup

```bash
git clone https://github.com/LucasSantana-Dev/sharekit-profile.git
cd sharekit-profile
git config core.hooksPath .husky
```

`git config core.hooksPath .husky` wires the local pre-commit checks (manifest
fingerprint verify, harness-boundary check, skill-validate, catalog-canonical,
shellcheck, co-author-trailer scan) so you catch what CI catches before you
push. No npm/husky package required — `.husky/pre-commit` is a plain
executable script and `core.hooksPath` is native git.

## Where your change goes

- Fixing/adding a hook that governs **this repo's own commits** → `hooks/`.
- Fixing/adding a hook that ships to **end users who install this profile** →
  `claude/hooks/`. It must work with only `grep`/`cat` — no `rg` or other
  tools this repo can't guarantee on an installer's machine.
- New skill → `claude/skills/<name>/SKILL.md`. Run
  `scripts/check-catalog.sh` after adding one (enforces a skill-count
  guardrail and keeps `index.html`'s showcase list in sync).
- Docs → `docs/`. Governance/constitution changes → `.harness/`.

See [`AGENTS.md § Harness files`](AGENTS.md#harness-files) for the full
`hooks/` vs `claude/hooks/` split if you're touching either.

## Testing

```bash
bats tests/                      # hook/gate test suite (what CI runs)
```

If you're adding a new hook that participates in a gate, add a `.bats` file
under `tests/` for it — coverage is currently thin (tracked in #127) and
new hooks without tests make that worse, not better.

For changes touching skill routing, the eval gate
(`evals/routing/`) runs 40 frozen tasks against a fingerprinted baseline;
`--validate-only` runs offline, the full gate needs `OPENROUTER_API_KEY`
(CI has it, you likely don't locally — that's expected, CI will catch a
regression).

## Commit and PR conventions

- Conventional commit format for the subject line (`feat:`, `fix:`,
  `docs:`, `chore:`, etc.) — this repo uses `release-please` for versioning,
  which parses commit types.
- No AI co-author trailers (`Co-Authored-By: Claude ...` etc.) — the
  pre-commit hook checks for this and CI blocks on it.
- Keep PRs scoped to one concern. A hook fix and a doc typo in the same PR
  makes review slower for both.

## What CI checks

- `harness-gates.yml` — bats suite (`tests/`) + the behavioral eval gate.
- CodeRabbit — required review check on `main` (repo ruleset, not classic
  branch protection). Merge stays blocked until review threads resolve;
  CodeRabbit auto-resolves its own threads once you push a fix.
- `main` is protected — no direct pushes, PR only.

## Questions

Open an issue, or start a discussion on an existing one. There's no separate
chat/forum for this project yet.

## License

MIT — see [`LICENSE`](LICENSE).
