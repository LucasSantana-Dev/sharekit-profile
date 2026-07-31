# Team Onboarding

Get a developer productive with this harness on a team repo in under an hour.
For the rollout-quarter view (champions, RACI, metrics), see
`docs/team-rollout-playbook.md` (Phase 4). For the governance model, see
`docs/configuration.md` (precedence contract).

## 1. Install

Two supported paths:

- **Marketplace (recommended for teams):** add to the team repo's committed
  `.claude/settings.json`:

  ```json
  {
    "extraKnownMarketplaces": ["LucasSantana-Dev/sharekit-profile"],
    "enabledPlugins": ["core-skills@sharekit-profile", "security-hooks@sharekit-profile"]
  }
  ```

  Claude Code prompts each teammate to install on folder trust; plugins
  arrive versioned, no fork drift. Conservative teams pin the `stable`
  channel (`"ref": "v0.10.0"` tag); pilot teams track `latest` (main).
  See "Update channels" in `docs/configuration.md`.
- **npm installer:** `npx @lucassantana/sharekit install LucasSantana-Dev`
  (the installer lives in the separate `sharekit` repo; use the marketplace
  path if you do not want that dependency).

OpenCode users: this repo's `opencode/opencode.jsonc` is the reference config;
copy the agent/model sections, point providers at your org gateway
(`docs/gateway-mapping.md`).

## 2. Declare yourself

```bash
bash scripts/bootstrap-team.sh   # seeds .harness/operators.json from your git identity
git add .harness/operators.json .claude/settings.json .agents/mode
git commit -m "chore: harness bootstrap (<your name>)"
```

`hooks/check-identity.sh` (pre-commit) then enforces that every committer is
declared in `.harness/operators.json`: wrong-identity commits are the most
common multi-operator accident.

## 3. Posture marker

`.agents/mode` says how the harness behaves here: `cooperative` (team repos:
guest posture, no personal-vault recall, convention deference) or `solo`.
`scripts/repo-mode.sh` resolves it; gitignore the marker: it is a personal
posture flag, not team config.

## 4. Starter profile (week 1)

Do NOT enable everything. Rollout evidence says teams stall when week 1 ships
dozens of hooks. Start with:

- **Hooks:** `check-identity.sh`, `check-dangerous-patterns.sh`, `policy-gate.sh`
- **Skills:** `plan`, `verify`, `tdd`

Add one hook/skill per recurring pain after that. The full catalog is in
`curated-skills.txt` / `curated-hooks.txt`.

## 5. Week-1 checklist

- [ ] Install path chosen and plugins visible (`/plugin` list)
- [ ] `.harness/operators.json` contains you; a test commit passes the identity gate
- [ ] `.agents/mode` set and `repo-mode.sh` prints the expected posture
- [ ] Starter hooks fire (make one trivial commit; watch pre-commit output)
- [ ] Read `docs/ai-attribution.md`: know your repo's `attributionPolicy` mode
- [ ] One real task shipped through `plan` → `verify` end to end

## 6. Spec-anchored work (team features)

Features with a spec live in `specs/<feature>/` (template: `specs/_template/`).
The spec is the cross-operator source of truth, not personal memory:

- Reference the spec in your PR body: `Spec: specs/<feature>/`
- `hooks/check-spec-drift.sh` fails commits that change `requirements.md`
  without `tasks.md` (traceability went stale) and warns on spec-less code
  changes while feature specs exist.
- Extend the existing spec; never start a second one for the same feature.

## Troubleshooting

- **Identity gate blocks your commit:** your `git config user.email` is not in
  `.harness/operators.json`: add it, or fix the config.
- **Personal memories leaking into a team repo:** the mode marker is missing
  or set to `solo`; set `cooperative`.
- **Too noisy:** you enabled more than the starter profile. Disable back to it.
