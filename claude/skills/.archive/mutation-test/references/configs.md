# Stryker Configuration & CI Integration

## Stryker Configuration (stryker.conf.json)

If `stryker.conf.json` doesn't exist, create one. **Default to per-file mode** for the
first run; full-suite mutation can take hours on a large codebase.

```json
{
  "mutate": ["src/**/*.ts", "!src/**/*.spec.ts", "!src/**/*.test.ts"],
  "testRunner": "jest",
  "reporters": ["clear-text", "progress", "html"],
  "coverageAnalysis": "perTest",
  "concurrency": 4,
  "timeoutMS": 30000,
  "thresholds": { "high": 80, "low": 60, "break": 50 }
}
```

For Vitest replace `"jest"` with `"vitest"` and install `@stryker-mutator/vitest-runner`.

## CI Integration Workflow

For modules below the project's mutation threshold, add a CI job that runs mutation
testing on changed files in PRs. This keeps full-suite mutation cost out of CI while
catching new shallow tests at PR time.

```yaml
# .github/workflows/mutation.yml
on: pull_request
jobs:
  mutation:
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - name: Find changed source files
        run: |
          git diff --name-only origin/main...HEAD \
            | grep -E "^src/.*\.ts$" \
            | grep -v "\.spec\.\|\.test\." > changed.txt
      - name: Mutate changed files
        run: npx stryker run --mutate "$(cat changed.txt | tr '\n' ',')"
```
