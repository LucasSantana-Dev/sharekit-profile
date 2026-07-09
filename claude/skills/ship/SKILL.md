---
name: ship
description: End-to-end shipping — version bump, changelog update, tag, GitHub release, deploy, and post-deploy verification. Validates PR goal, checks, review state, and risk. Refuses admin bypasses or force options against main.
triggers:
  - ship
  - prepare to merge
  - prepare release
  - cut a release
  - merge this PR
  - release-ready check
  - shippable
---

# ship

Use only when the branch is plausibly ready.

## Preconditions

- goal is clear
- diff is understood
- required checks are green or a failure is proven unrelated
- no unresolved blocking review comments
- no obvious security or migration risk

## Rollback gate (release/prod deploys only)

Before merge-and-tag for any main/release branch ship or production infra change (Cloudflare, homelab, Dockerfile rewrite), surface a rollback plan:

```
Rollback plan:
  Revert steps: [e.g. git revert <tag>, re-deploy previous tag]
  Commands: [exact commands]
  Estimated recovery time: [~X minutes]
```

If no rollback plan can be formulated, halt and ask the user before proceeding. Exempt: feature-branch preview deploys, staging-only changes, hotfixes reverting a prior bad deploy.

## Steps

1. run `verify`
2. inspect review and CI state
3. update docs or changelog if needed
4. prepare commit / push / PR or release step
5. if anything is unclear, step back to the smallest unblock

## See also

- `standards/red-flags.md` — operator-action red flags to halt on before shipping (force-merge, unclear CI/review, uncommitted context)
