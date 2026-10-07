# Listing of .claude/plans/ (cwd = repo root of "atlas-dash")
- homepage-customization-2026-10-01.md   (modified 2026-10-01, status header: "Status: active. Phases 1-5 done (2026-10-02)")
- auth-rework-2026-07-02.md              (modified 2026-07-02, status: shipped)

## Contents of homepage-customization-2026-10-01.md (abridged)
# Plan: Homepage customization
**Date:** 2026-10-01
**Status:** active. Phases 1-5 done
Goal: dashboard homepage shows service tiles with custom icons and ordering.
### Phase 5: Tile ordering
Files Touched: `src/components/TileGrid.tsx`, `src/lib/order.ts`
Verify: `npm test -- order.test.ts`

## Repo facts
- Dashboard is React + Vite. Components in src/components/. API handlers in server/routes/.
- Existing Wake-on-LAN helper: server/lib/wol.ts (exports sendMagicPacket(mac)).
- Tabs component does not exist yet. Test runner: vitest (`npm test -- <file>`). Lint: `npm run lint`.
