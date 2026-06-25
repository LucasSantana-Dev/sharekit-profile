# CI Pipeline Design (Mode B)

Use this guide when you need to add, fix, or restructure a CI pipeline (not just diagnose a failure). This is a companion to the main `ci-watch` skill.

## Steps

1. **Audit existing CI**: Read all workflow files in `.github/workflows/`. List jobs, triggers, and what each job does.
2. **Map requirements**: Identify what the pipeline needs — build, test, lint, type-check, publish, deploy, security scan.
3. **Identify gaps or broken patterns**: Missing jobs, incorrect step ordering, wrong event triggers, deprecated action versions.
4. **Implement or fix**: Edit workflow YAML. Follow GitHub Actions conventions.
5. **Validate**: Push or use `act` locally; confirm checks pass.

## Common fixes

- `Error: Not Found` on an action → verify the `@version` tag uses `v` prefix (`@v4`, not `@4`)
- `setup-node` with `cache: 'npm'` fails → `package-lock.json` missing; either remove the cache option or add the lockfile
- Matrix job reports as skipped → check `if:` conditions and matrix include/exclude filters
- Artifact not found in a dependent job → confirm `upload-artifact` runs before `needs:` resolves
- `permissions: contents: write` needed for tags/releases; missing by default on fork PRs
