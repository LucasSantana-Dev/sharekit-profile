# Support File Policy

Use this policy when auditing support files inside skill folders.

## Immediate junk

Delete these immediately when found:

- `.DS_Store`

## Standard support entries

These are standard and do not need extra classification:

- `references/`
- `scripts/`
- `assets/`
- `agents/`
- `templates/`
- `command/`
- `rules/`
- `evals/`
- `data/`
- `themes/`
- `examples/`
- `canvas-fonts/`

## Conservatively allowed non-standard entries

Keep these when they are genuinely supporting the skill and classify them in the audit:

- `README.md`: imported or vendor reference index
- `AGENTS.md`: navigation guide for bundled references
- `CLAUDE.md`: compatibility alias for upstream agent guidance
- `SKILL.toon`: legacy source metadata from imported skills
- `LICENSE.txt` / `license.txt`: provenance or licensing metadata
- focused root docs such as `cli.md`, `customization.md`, `testing-anti-patterns.md`
- root examples or helper scripts that are directly used by the skill

## Cleanup rules

- Do not mass-delete non-standard files just because they are unusual.
- Remove only clear junk in this wave.
- Leave ambiguous but useful files in place and classify them with a reason.
- If a future refactor moves a non-standard file into `references/`, update the classification policy accordingly.
