# Spec: CI-native review pack (2026-07-31)

## L0

**Goal:** ship a CI-native multi-agent code-review pack for sharekit-profile:
risk-tiered reviewer fan-out + coordinator emitting one structured
severity-rated GitHub review with incremental re-review, installable into any
team repo.

**User:** teams adopting the profile (Phase 2+ of the rollout playbook) who
want Cloudflare-class automated review without building it themselves.

**Why now:** the team-expansion brief (opp 7) deferred this pending an
orchestration decision; research now pins every decision with VERIFIED sources.
Cloudflare's published pattern is the only large-scale validated design
(131k reviews/30d, $0.98 median, 0.6% override).

**Success criteria:**
- A consuming repo adds one workflow file + marketplace pin and gets reviews on PRs.
- Noise floor: <=2 findings/review average on this repo's own PRs (Cloudflare: 1.2).
- Critical-only blocking: REQUEST_CHANGES fires only on critical findings.
- Re-review on a force-push flags only new/unfixed findings (fingerprints stable).

**Constraints:** marketplace-distributable (no hosted service, no ops); cost
per review governed by `.harness/llm-policy.json`; fork PRs get read-only
GITHUB_TOKEN.

## Design decisions (each cited)

**D1 — Orchestration: GitHub Actions + claude-code-action@v1, ephemeral per job.**
The review pack ships as (a) a marketplace plugin carrying agents/prompts and
(b) an `ai-review.yml` workflow template. `claude-code-action@v1` natively
accepts `plugin_marketplaces`/`plugins` inputs and emits `--json-schema`
structured output. Cloudflare's "server" is itself an ephemeral per-CI-job
process, so this IS their model ported to GitHub. A long-running server fails
the marketplace constraint; a manual-only skill has no merge-gate integration.
VERIFIED: claude-code-action usage docs (fetched 2026-07-31);
blog.cloudflare.com/ai-code-review (2026-04-20).
OpenCode headless vs claude-code-action: claude-code-action wins on the native
plugins input; noted as an open fork to re-benchmark at pilot.

**D2 — Risk tiering: deterministic code classification, Cloudflare thresholds.**
`full` if >50 files OR security-sensitive path (`auth/`, `crypto/`, migrations
exempt from noise filtering); `trivial` if <=10 changed lines AND <=20 files;
`lite` if <=100 lines AND <=20 files. No author-based downgrading (trust bias,
gaming risk); escape hatch is a `break-glass` label (0.6% verified usage).
VERIFIED: Cloudflare assessRiskTier (same source).

**D3 — Fan-out + model mapping per tier.**
trivial: coordinator + 1 general reviewer (coordinator downgraded one tier).
lite: coordinator + 3 reviewers. full: all specialists. Coordinator on the
strongest model, reviewers Sonnet-tier, text-heavy reviewers (docs/release)
Haiku-tier, per `.harness/llm-policy.json` role tiers. Reuses existing
read-only role agents (critic, code-reviewer, security-reviewer) with added
"What NOT to Flag" sections (verified as Cloudflare's noise-control lever).
VERIFIED: Cloudflare tier-to-agent mapping; INTERNAL-CITED: role agents +
llm-policy.json already exist.

**D4 — Output contract: 3 severities, one batched review, critical-only blocking.**
Severities: critical (outage/exploitable), warning (measurable regression),
suggestion. Coordinator dedupes, re-categorizes, drops speculation (judge
pass verifies against source when unsure). Emits ONE `POST /pulls/{n}/reviews`
call with batched `comments[]`; event mapping: any critical ->
REQUEST_CHANGES; warnings -> COMMENT; else APPROVE. Findings only on lines
present in the posted diff (422 otherwise); pre-filter lockfiles, `.min.*`,
`.map`, `@generated` (migrations exempt).
VERIFIED: Cloudflare coordinator contract; GitHub reviews API (2026-03-10).

**D5 — Re-review state: PR comment threading + hidden fingerprint block.**
Store of record = the bot's own prior review + inline threads (fetched each
run, injected as `<previous_review>`); resolution via review-thread
`isResolved`. Hidden HTML-comment JSON inside the summary comment carries
finding fingerprints = `hash(file_path + rule_id + snippet_hash)` (NOT line
numbers; survives force-push/rebase). Fixed findings omitted + auto-resolved;
"won't fix" replies mark resolved. Actions cache/artifacts rejected as store
(7-day eviction, immutable, expiry). Fork PRs: GITHUB_TOKEN is read-only ->
degrade gracefully to full review.
VERIFIED: Cloudflare re-review mechanism; GitHub cache/checks/thread docs.
[SPECULATION: snippet-hash fingerprinting is synthesized, not from a published
scheme; Cloudflare does not disclose theirs.]

**D6 — Cost + reliability guards.**
Shared context file per MR (avoids N-x token duplication); stdin/file-based
context (never CLI args, ARG_MAX); heartbeat every ~30s; per-task 5-10min,
25min hard cap; retry only 429/503; strip XML boundary tags from PR content
(prompt-injection hygiene); batch all comments into one call (secondary rate
limits). VERIFIED: Cloudflare constraints + GitHub API docs.

**D7 — Packaging: marketplace plugin `review-pack` + workflow template.**
New plugin entry in `.claude-plugin/marketplace.json`; template at
`.github/workflows-templates/ai-review.yml` copied by `bootstrap-team.sh`;
marketplace version gate (`check-marketplace.sh`) already enforces sync.
INTERNAL-CITED: packaging machinery shipped in Phase 3.

## Acceptance criteria (testable)

- AC-1: GIVEN a consuming repo with the workflow + marketplace pin, WHEN a PR
  opens, THEN exactly one review is posted with severities from the 3-level
  taxonomy and findings only on diff lines. (D1, D4)
- AC-2: GIVEN a PR with a critical finding, WHEN the coordinator judges, THEN
  the review event is REQUEST_CHANGES; warnings-only produces COMMENT. (D4)
- AC-3: GIVEN a <=10-line docs PR, WHEN tiered, THEN only coordinator + 1
  reviewer run and the coordinator model is downgraded one tier. (D2, D3)
- AC-4: GIVEN a force-push fixing one of two prior findings, WHEN re-review
  runs, THEN the fixed finding is omitted and the unfixed one re-emitted with
  the same fingerprint. (D5)
- AC-5: GIVEN a lockfile-only diff, WHEN reviewed, THEN zero inline findings
  (noise pre-filter). (D4)
- AC-6: GIVEN a fork PR, WHEN the workflow runs, THEN it degrades to full
  review without failing on token permissions. (D5)

## Out of scope

- [OUT OF SCOPE: hosted/persistent review server or dashboard (marketplace
  constraint; revisit if a control plane ever ships)]
- [OUT OF SCOPE: autofix/suggestion application (`suggestion` blocks limited
  to diff hunks; v1 posts findings only)]
- [OUT OF SCOPE: AGENTS.md-freshness reviewer (Cloudflare has one; orthogonal,
  candidate for v1.1)]
- [OUT OF SCOPE: Agent Teams orchestration (experimental upstream, per brief)]

## Open questions (executor must resolve in-pilot, not mid-build)

1. claude-code-action vs OpenCode headless on cost/latency for the fan-out;
   re-benchmark at pilot, spec assumes claude-code-action (D1).
2. Cloudflare's 10/100-line thresholds are tuned to their fleet; validate
   against our 3-model stack in the pilot and adjust in ONE place (tier fn).
3. GraphQL `resolveReviewThread` end-to-end behavior on outdated threads
   (assumed, not verified).

## Mid-task rule

Unknowns discovered during implementation go back INTO this spec (Phase 2
loop), never into ad-hoc mid-task research. Amend the decision + citation.
