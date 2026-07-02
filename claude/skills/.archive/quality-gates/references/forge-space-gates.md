# Forge Space Repo-Specific Gates

When inside a Forge Space repo, use these exact commands:

## core (@forgespace/core)

```bash
npm run build                    # tsc compilation
npm run lint:check               # ESLint (7 warnings acceptable: magic-numbers in scripts)
npm run format:check             # Prettier
npm run test:coverage            # Jest with 80% coverage threshold
npm run test:validation          # Plugin, feature toggle, shared constants
npm run check:tenant-decoupling  # Tenant-agnostic guardrails
# Full validation shortcut:
npm run validate                 # lint:check + format:check + test:validation + tenant-decoupling
```

**Done when:** all commands exit with code 0 and validation shortcut runs clean.

## siza-gen (@forgespace/siza-gen)

```bash
npm run build && npm test        # TS build + 465 tests
python -m pytest                 # Python sidecar tests
```

**Done when:** all 465 tests pass and Python tests pass.

## mcp-gateway

```bash
npm run build && npm test        # 1567 tests, 91%+ coverage
python -m pytest                 # Python components
```

**Done when:** all 1567 tests pass with ≥91% coverage and Python tests pass.

## ui-mcp (@forgespace/ui-mcp)

```bash
NODE_OPTIONS=--experimental-vm-modules npm run build  # tsup ESM bundle
NODE_OPTIONS=--experimental-vm-modules npm test       # 55+ suites, 638+ tests, 81%+ coverage
npm run lint                                          # ESLint — must be 0 warnings
npx tsc --noEmit                                      # strictNullChecks + noUncheckedIndexedAccess
npm run registry:check                                # server.json ↔ package.json alignment
npm run validate:all                                  # lint + format + tsc + test + build (full)
```

Key gotchas:

- `NODE_OPTIONS=--experimental-vm-modules` required for Jest (ESM modules)
- Coverage threshold: branches 55%, functions 55%, lines 60%
- Bump BOTH `package.json` AND `server.json` when releasing
- Zero lint warnings is the target (run `npm run lint` not just `npm run lint:check`)

**Done when:** all tests pass with ≥81% coverage, lint warnings = 0, registry check passes.

## branding-mcp

```bash
npm run build && npm test        # Standard TS pipeline
```

**Done when:** build completes and all tests pass.

## siza

```bash
npm run build && npm test        # Next.js build
npm run lint                     # Next.js ESLint
```

**Done when:** build succeeds, all tests pass, lint warnings = 0.
