# Release & Deployment Skills

`ship` for tagging a release after merge; `ship-it` (composite) for the full bump → changelog → tag → deploy chain. `release-cut` when batching many PRs into one release. `hotfix` only for production emergencies that can't wait.

---

## /ship

Ship validated changes — tag, GitHub release, and post-ship verification.

**Process:**
1. Verify PR merged to main
2. Bump version (package.json, etc.)
3. Create git tag
4. Create GitHub release
5. Monitor post-deploy (Sentry errors, uptime)

**When to use:** PR merged, ready for production

**Output:** Tagged release + GitHub release page

---

## /ship-it ⭐ **Composite**

Take a merged PR all the way to production: version-bump → changelog → tag → deploy → verify.

**Phases:**
1. Verify all gates pass (verify-before-done)
2. Bump version in package.json + tag
3. Update CHANGELOG.md
4. Create GitHub release + tag
5. Deploy to production
6. Monitor Sentry + verify not broken

**When to use:** PR merged, ready to production

**Output:** Live release + tag

---

## /release-cut ⭐ **Composite**

Promote release branch to main, cut a version, clean up. Batches many PRs into one release.

**Workflow:**
1. Merge release branch → main
2. Bump version
3. Create CHANGELOG entry
4. Tag version
5. Clean up release branch

**When to use:** Batching many PRs into one release

**Output:** New version + tag on main

---

## /hotfix ⭐⭐ **Composite**

Emergency bypass of release branch when production is broken and can't wait for next release.

**Workflow:**
1. Create emergency hotfix branch from main (bypassing release branch)
2. Implement fix
3. Test thoroughly
4. Ship to production immediately
5. Backport to release branch

**When to use:** Production is broken AND can't wait for next release

**Output:** Production fixed + release branch updated

---

## /version-bump

Automate version bumping in npm monorepos with CHANGELOG promotion and PR automation.

**Process:**
1. Read current version
2. Determine next version (semver: major/minor/patch)
3. Update package.json
4. Promote [Unreleased] section in CHANGELOG
5. Create PR with bumped version

**When to use:** Before release; automate version bump

**Output:** Version bump PR

---

## /changelog-update

Update CHANGELOG.md by promoting [Unreleased] content to a versioned section.

**Process:**
1. Read [Unreleased] section
2. Group by type (Breaking, Features, Fixes, Security)
3. Create versioned section with date
4. Link to release tag

**When to use:** Before release; update changelog

**Output:** Updated CHANGELOG.md

---

## /chain-release

Coordinate a multi-repo release sequence by detecting unreleased changes.

**When to use:** Monorepo or multi-repo ecosystem with dependencies

**Process:**
1. Detect unreleased changes per repo
2. Build release order (respect dependencies)
3. Release each repo in sequence
4. Verify dependent repos get updated

**Output:** Released all repos in dependency order

---

## /adt-release-flow

Ship validated changes with repeatable release evidence — version bump, changelog, tag, optional GitHub release.

**Phases:**
1. Pre-release validation (verify-before-done)
2. Version bump
3. CHANGELOG update
4. Git tag + GitHub release
5. Post-release monitoring

**When to use:** Defining repeatable release process

**Output:** Release checklist + evidence

---

## /deployment-automation

Automate application deployment to cloud platforms and servers.

**Targets:**
- Vercel (Next.js, static)
- Cloudflare (Workers, Pages)
- Docker (Kubernetes, servers)
- AWS/GCP/Azure (EC2, functions, etc.)

**Automates:**
- Build process
- Deploy to staging
- Deploy to production
- Rollback if needed
- Health checks

**When to use:** Setting up CI/CD deployment pipeline

**Output:** Automated deployment pipeline

---

## /vercel-deploy

Deploy applications and websites to Vercel.

**Process:**
1. Connect GitHub repo
2. Configure Vercel project (env vars, build settings)
3. Deploy preview on PR
4. Deploy production on main
5. Monitor deployment health

**When to use:** Deploying Next.js or static apps to Vercel

**Output:** Deployed application + URL

---

## /cloudflare-deploy

Deploy applications and infrastructure to Cloudflare — Workers, Pages, KV, R2.

**Services:**
- **Workers:** Serverless compute at edge
- **Pages:** Static site hosting + edge middleware
- **KV:** Edge-accessible key-value storage
- **R2:** Object storage (S3-compatible)

**When to use:** Deploying to Cloudflare ecosystem

**Output:** Deployed service + configuration

---

## /prod-rebuild

Rebuild and restart production Docker services on remote server with async monitoring.

**When to use:** Need to rebuild/restart prod without downtime

**Process:**
1. Connect to remote server
2. Stop old containers
3. Rebuild images
4. Start new containers
5. Verify health checks pass
6. Monitor logs + uptime

**Output:** Restarted services + health monitoring

---

## /deploy-staging

Build, validate, and deploy UIForge MCP changes to staging with rollback-aware steps.

**Phases:**
1. Build staging image
2. Run smoke tests
3. Deploy to staging
4. Verify endpoints
5. Create rollback marker

**When to use:** UIForge MCP changes ready for staging validation

**Output:** Staging deployment + validation report

---

## /repo-bootstrap ⭐ **Composite**

Configure a fresh repo for the release-branch workflow: create release branch, CHANGELOG, dep-sweep config, PR.

**Phases:**
1. Create release branch
2. Initialize CHANGELOG.md
3. Configure Dependabot/Renovate dep-sweep
4. Open PR with bootstrap config

**When to use:** Fresh repo needs release infrastructure

**Output:** Release-ready repo infrastructure

---

**Last updated:** 2026-06-25
