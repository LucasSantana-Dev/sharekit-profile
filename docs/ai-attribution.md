# AI Attribution Policy

How this harness handles authorship attribution for AI-assisted commits.
Source of truth: `.harness/constitution.json` -> `attributionPolicy.mode`.

## Modes

| Mode | Behavior | When |
|------|----------|------|
| `strip` (default, solo) | AI co-author trailers rejected by `check-coauthor-trailers.py`; commits are authored by the human operator | Solo repos, clean-history norms |
| `trailer` | AI co-author trailers allowed/recorded (`Co-Authored-By: <tool>`); the gate does not fail them | Cooperative/enterprise repos where compliance requires recording agent authorship |
| `signed` | Reserved: cryptographic agent-attribution (ed25519 line-level provenance tools). Currently behaves as `strip` plus a warning | Future; provenance tooling is 2026-emerging |

Default is per repo-mode: solo = `strip`, cooperative = `trailer`.

## The DCO position

Human certifies, tool allowed. Regardless of mode, the human signs off
(`Signed-off-by` where a DCO applies) and attests rights over the
contribution. AI authorship does not transfer that responsibility: the Linux
kernel keeps its DCO while explicitly not being "an anti-AI project"; OpenStack
moved all contributions to DCO. Adopt the same posture.

## Regulatory pressure

- **EU AI Act Article 50** transparency obligations apply from **2026-08-02**
  (not Dec 2026; December is only a transitional marking deadline for systems
  already on the market). Organizations in scope need a defensible answer to
  "which content is AI-generated"; `trailer` mode plus PR-based agent
  workflows (draft PRs, human review requested) is the lightweight answer.
- Enterprise provenance tooling (git-native, line-level, signed attribution)
  is an emerging 2026 category. `signed` mode reserves the slot without
  committing to a vendor.

## Trade-offs (defend either choice)

Trailers help: audit trails, compliance, research. Trailers hurt: history
noise, some orgs rewrite history to strip them, the trailer is unauthenticated
plaintext (anyone can add or remove it). Pick per repo; record the choice in
`constitution.json`; do not mix modes across a repo's history without a note
in the PR that flips it.

## Enforcement

`scripts/check-coauthor-trailers.py` reads `attributionPolicy.mode` from
`.harness/constitution.json`: `strip`/`signed` = reject AI co-author trailers
(current behavior, dependency bots always allowlisted); `trailer` = pass.
