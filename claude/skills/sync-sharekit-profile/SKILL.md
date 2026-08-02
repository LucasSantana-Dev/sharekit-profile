---
name: sync-sharekit-profile
description: 'Sync ~/.claude/ (skills, hooks, standards, CLAUDE.md, agents) into the public sharekit profile repo, sanitize personal paths/identity, scan for secrets, show diff, and commit+push. Invoke whenever: "sync my sharekit profile", "update sharekit", "push my latest skills to sharekit", "sharekit is out of date", or after a session that significantly expanded the skill or agent library.'
triggers:
  - sync-sharekit-profile
  - sync sharekit profile
  - update sharekit
  - push skills
  - public profile
  - sanitize paths
  - share profile
user-invocable: true
auto-invoke: 'never'
metadata:
  owner: global-agents
  tier: personal
  canonical_source: ~/.claude/skills/sync-sharekit-profile
---

# sync-sharekit-profile

Mirror your live `~/.claude/` configuration into the public sharekit profile, so anyone running `npx @lucassantana/sharekit install LucasSantana-Dev` gets your latest setup.

The goal is to share what's genuinely useful to others — not your personal identity or machine-specific paths. That means copying broadly, sanitizing aggressively, and excluding anything that leaks personal context even after sanitization.

---

## Variables

```bash
# Canonical public profile = the standalone sharekit-profile repo (ADR-0039: website + npm + manifest).
# The old sharekit/sharekit-profile/.claude mirror is legacy — do NOT target it.
# Resolve from env first; fall back to the operator default. Any operator can
# point this at their own clone — no personal path is required.
PROFILE_REPO="${SHAREKIT_PROFILE_REPO:-.}"
PROFILE_DIR="$PROFILE_REPO/claude"   # standalone uses claude/ (not .claude/)
SOURCE_DIR="$HOME/.claude"
```

---

## Phase 0 — Reachability guard

```bash
# Generic: works for any operator clone, not just the original machine.
[ -d "$PROFILE_REPO/.git" ] || {
  echo "BLOCKED: profile repo not found at $PROFILE_REPO"
  echo "  set SHAREKIT_PROFILE_REPO to your clone of the profile repo and retry."
  exit 1
}
```

---

## Phase 1 — Pre-sync status

Show what's changed since the last profile push:

```bash
git -C "$PROFILE_REPO" log --oneline -1
git -C "$PROFILE_REPO" status --short
```

Surface: last sync commit + date, any uncommitted profile changes already present. If there are open changes in the repo that aren't from this session, surface them and ask whether to proceed.

---

## Phase 2 — Copy source files

> ✅ **CURATION ALLOWLIST (ADR-0039 / F1).** The standalone profile is a **curated subset**, defined
> by `curated-skills.txt` in the profile repo (one skill name per line). This phase syncs ONLY those —
> a bare `rsync --delete` of all ~238 source skills would balloon the profile and destroy curation.
> **Publishing a new skill = add a line to `curated-skills.txt`** (a deliberate curation act). If the
> allowlist is missing, this phase REFUSES to run (no silent full-mirror).

Sync each allowlisted skill from source; unpublish profile skills no longer in the allowlist; copy
`CLAUDE.md`. Skills in the allowlist but NOT in source (e.g. plugin-native) are kept, not removed.

```bash
COMMON_EXCLUDES=(--exclude='.archive/' --exclude='*-workspace/' --exclude='worktrees/' --exclude='backlog/' --exclude='__pycache__/')
ALLOWLIST="$PROFILE_REPO/curated-skills.txt"
[ -f "$ALLOWLIST" ] || { echo "BLOCKED: no curated-skills.txt — refusing to full-mirror"; exit 1; }

# 1) sync each allowlisted skill that exists in source
while IFS= read -r s; do
  case "$s" in ''|\#*) continue ;; esac
  [ -d "$SOURCE_DIR/skills/$s" ] && rsync -a --delete "${COMMON_EXCLUDES[@]}" "$SOURCE_DIR/skills/$s/" "$PROFILE_DIR/skills/$s/"
done < "$ALLOWLIST"

# 2) unpublish: remove profile skills NOT in the allowlist
for d in "$PROFILE_DIR/skills"/*/; do
  n="$(basename "$d")"; grep -qxF "$n" "$ALLOWLIST" || rm -rf "$d"
done

cmp -s "$SOURCE_DIR/CLAUDE.md" "$PROFILE_DIR/CLAUDE.md" 2>/dev/null && echo "CLAUDE.md: already done - skipping" || cp "$SOURCE_DIR/CLAUDE.md" "$PROFILE_DIR/CLAUDE.md"
```

> ✅ **CURATION ALLOWLIST for agents/hooks/standards (ADR-0062).** agents/hooks/standards were
> in scope wholesale since 2026-07-20 with no gate — a real leak (`standards/decisions/`, then
> `discord-bot-specialist.md`) proved that's a **denylist** posture (relies on remembering every
> private-project name), not safe against an unknown future one. Now gated the same way skills/
> already is: `curated-agents.txt`, `curated-hooks.txt`, `curated-standards.txt` (one filename
> per line; `standards/decisions/<name>.md` entries include the subdirectory prefix). Publishing
> something new in these trees = add a line (deliberate curation act), same as skills.

```bash
for pair in "agents:curated-agents.txt" "hooks:curated-hooks.txt" "standards:curated-standards.txt"; do
  tree="${pair%%:*}"; list="${pair##*:}"
  ALLOWLIST="$PROFILE_REPO/$list"
  [ -f "$ALLOWLIST" ] || { echo "BLOCKED: no $list — refusing to full-mirror $tree/"; exit 1; }

  # 1) sync each allowlisted file that exists in source
  while IFS= read -r n; do
    case "$n" in ''|\#*) continue ;; esac
    # Reject path traversal / absolute paths — an allowlist entry controls what
    # gets read from $SOURCE_DIR and written into $PROFILE_DIR; don't let it escape either.
    case "$n" in
      /*|.|..|./*|../*|*/./*|*/../*|*/..)
        echo "BLOCKED: unsafe allowlist entry in $list: $n" >&2; exit 1 ;;
    esac
    src="$SOURCE_DIR/$tree/$n"
    dest="$PROFILE_DIR/$tree/$n"
    if [ -f "$src" ]; then
      if cmp -s "$src" "$dest" 2>/dev/null; then
        echo "$tree/$n: already done - skipping"
      else
        mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"
      fi
    fi
  done < "$ALLOWLIST"

  # 2) unpublish: remove profile files NOT in the allowlist
  /usr/bin/find "$PROFILE_DIR/$tree" -type f | while read -r f; do
    n="${f#"$PROFILE_DIR/$tree/"}"
    grep -qxF "$n" "$ALLOWLIST" || rm -f "$f"
  done
done
```

After copying, count and surface what was synced:
```bash
echo "Skills: $(ls "$PROFILE_DIR/skills/" | wc -l) directories"
echo "Hooks:  $(ls "$PROFILE_DIR/hooks/" | wc -l) files"
echo "Standards: $(ls "$PROFILE_DIR/standards/" | wc -l) files"
echo "Agents: $(ls "$PROFILE_DIR/agents/" | wc -l) files"
```

**Agent vs. Skill distinction:** Agents and skills publish to separate namespaces — `~/.claude/skills/` → `sharekit-profile/skills/` and `~/.claude/agents/` → `sharekit-profile/agents/`. Always explicitly surface this in the count summary (e.g. "42 agents synced from ~/.claude/agents/, not skills/") so the caller knows where each type lives.

### Phase 2a — Agent namespace clarity

Before proceeding to sanitization, explicitly state which agents and skills were identified:

**Important:** Agent files and skill files are **not interchangeable**.
- **Skills** (e.g., `loop`, `mutation-test`, `parallel-phases`) live in `~/.claude/skills/` and sync to `sharekit-profile/skills/`
- **Agents** (e.g., `loop-engineer`, `tdd-practitioner`, `mutation-tester`, `parallel-implementer`) live in `~/.claude/agents/` and sync to `sharekit-profile/agents/`

Each agent is a **separate, independent definition** in the `agents/` namespace — not a subdirectory within `skills/`. When reporting counts in the output, explicitly note:
```
Agents: 42 files synced from ~/.claude/agents/ (published as agents/, not skills/)
```

---

## Phase 3 — Sanitize personal references

Replace machine-specific and identity references with generic placeholders. Apply to all copied files.

> `sync-sharekit-profile`'s own directory is excluded from this pass, same reason as Phase 4:
> its source code literally CONTAINS the identity strings as sed pattern operands (its subject
> matter is describing these exact strings) — blindly sanitizing them turns the pattern
> operands into no-ops (`s|${DEV_ROOT}|${DEV_ROOT}|g`) and breaks the negated-address
> protection above them (found 2026-07-10, caught in PR review before merge).

```bash
# Use /usr/bin/find explicitly — RTK's find wrapper silently drops compound -o predicates
/usr/bin/find "$PROFILE_DIR" -type f \( -name "*.md" -o -name "*.sh" -o -name "*.py" -o -name "*.json" -o -name "*.toml" -o -name "*-gate" -o -name "*-reminder" \) | while read f; do
  case "$f" in */sync-sharekit-profile/*) continue ;; esac

  # Personal paths (specific BEFORE bare so the prefix isn't half-replaced)
  sed -i '' 's|/Volumes/External HD/Desenvolvimento|${DEV_ROOT}|g' "$f"
  sed -i '' 's|/Volumes/External HD|${DEV_ROOT}|g' "$f"   # bare external-drive mount (catches mount-guard lines)
  sed -i '' 's|/Volumes/External\\ HD|${DEV_ROOT}|g' "$f"   # backslash-escaped-space variant (found 2026-07-26,
                                                              # recall/SKILL.md: the literal-space sed above doesn't
                                                              # match this form at all - a real backslash character
                                                              # sits where the sed pattern expects a bare space)
  sed -i '' 's|/Users/lucassantana|~|g' "$f"
  
  # GitHub identity (with and without -Dev suffix) — EXCEPT the real `npx @lucassantana/sharekit
  # install <user>` command: that's the actual public npm package name/install syntax, not
  # personal identity to scrub (found 2026-07-10: scrubbing it breaks the tool's own install docs).
  sed -i '' '/npx @lucassantana\/sharekit install/!s|LucasSantana-Dev|<github-user>|g' "$f"
  sed -i '' '/npx @lucassantana\/sharekit install/!s|LucasSantana|<github-user>|g' "$f"
  sed -i '' '/npx @lucassantana\/sharekit install/!s|lucassantana|<github-user>|g' "$f"

  # Real human name (distinct from the CamelCase GitHub handle above — this is prose like
  # "authored by Lucas Santana (the operator)", not a path or handle). Found 2026-07-25:
  # this was never sanitized, so it leaked into the published profile on claude/CLAUDE.md,
  # dispatch/SKILL.md's owner field, etc. for as long as the skill has existed. BSD sed's
  # -E ignores \b entirely (verified empirically — silently matches nothing, not even the
  # false positives it's meant to avoid); use [[:<:]]/[[:>:]] instead, BSD's own
  # word-boundary syntax, which behaves correctly on this platform.
  sed -i '' 's|Lucas Santana (the operator)|the operator|g' "$f"
  sed -i '' 's|Lucas Santana|the operator|g' "$f"
  sed -i '' 's|[[:<:]]Lucas[[:>:]]|the operator|g' "$f"   # bare first name, incl. possessive "Lucas's" -> "the operator's"

  # Personal email
  sed -i '' 's|your\.name@example\.com|<your-email>|g' "$f"   # placeholder — swap in YOUR real email pattern when actually running this
  
  # Homelab paths
  sed -i '' 's|/home/your-server/homelab|${HOMELAB_ROOT}|g' "$f"   # placeholder — swap in YOUR homelab path
  sed -i '' 's|your-homelab-host|<homelab-host>|g' "$f"   # bare homelab host (catches any remaining ref)
done
```

### Phase 3b — Private project names

Originally scoped to `standards/decisions/` only (found 2026-07-26: its ADR-style logs cite
real internal projects as case-study context, e.g. "Lucky has `review-tools.yml`") because a
global pass risked mangling files where the same names were *core documented subject matter*
(e.g. `agents/discord-bot-specialist.md` was explicitly the Lucky-monorepo bot agent). ADR-0062
resolved that collision at the root: `discord-bot-specialist.md` is now excluded from
`curated-agents.txt` entirely (never copied to `$PROFILE_DIR`, so never at risk from this pass),
and every other file that reaches `$PROFILE_DIR` is human-curated onto its allowlist — meaning a
private-project mention that survives to this point is by definition a passing example, not a
file's whole reason to exist. Safe to broaden to the full profile dir.

The pattern is deliberately case-sensitive and word-boundary-matched (capitalized proper nouns
only) — this is not incidental. `hooks/check-harness-drift.sh` has the lowercase compound
`criativaria-brain-[a-z]+\.sh` as a literal regex operand in an exclusion pattern; a
case-insensitive or substring match would silently corrupt that regex. The pattern below leaves
lowercase compound occurrences untouched by design — audit those by hand per file (as done for
`check-harness-drift.sh` itself, 2026-07-26: fixed with a literal-prefix-only replacement that
left the regex metacharacters `[a-z]+\.` intact).

```bash
/usr/bin/find "$PROFILE_DIR" -type f \( -name "*.md" -o -name "*.sh" \) | while read f; do
  case "$f" in */sync-sharekit-profile/*) continue ;; esac
  sed -i '' 's|[[:<:]]Lucky[[:>:]]|<project-a>|g' "$f"
  sed -i '' 's|[[:<:]]Criativaria[[:>:]]|<project-b>|g' "$f"
  sed -i '' 's|[[:<:]]homelab[[:>:]]|<homelab>|g' "$f"
  sed -i '' 's|[[:<:]]CoJam[[:>:]]|<project-c>|g' "$f"
done
```

After this pass, grep for lowercase compound forms (`criativaria-`, `lucky-`, etc.) across the
profile and hand-review any hit before deciding sed vs. manual fix — the regex-operand risk
above means these can't be safely automated.

### Phase 3c — Executable redaction review + regression re-check (round-trip rules 1.1/1.4)

Sanitization rewrites tokens inside executable code, not just prose. A placeholder
that lands inside a regex, path, command, or comparison is a functional change
disguised as a cosmetic one: the file still parses, the filter quietly stops
filtering. After Phase 3/3b:

1. **Placeholder-in-pattern audit.** Grep executable files for placeholder tokens
   and hand-review every hit that sits inside a pattern, path, command, or
   comparison (`${DEV_ROOT}` in a path is usually fine; `<project-a>` inside a
   regex usually is not):

   ```bash
   /usr/bin/find "$PROFILE_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.json" -o -name "*.toml" \) \
     | xargs grep -ln '\${DEV_ROOT}\|<github-user>\|<project-a>\|<project-b>\|<project-c>\|<homelab>' 2>/dev/null
   ```

2. **Mechanical verification of the published result.** Any failure = release blocker:

   ```bash
   /usr/bin/find "$PROFILE_DIR" -name "*.sh" -print0 | xargs -0 -n1 bash -n
   /usr/bin/find "$PROFILE_DIR" -name "*.py" -print0 | xargs -0 -I{} python3 -c "import ast; ast.parse(open('{}').read())"
   /usr/bin/find "$PROFILE_DIR" -name "*.json" -print0 | xargs -0 -I{} python3 -c "import json; json.load(open('{}'))"
   ```

3. **Regression re-check.** Sanitization regresses when a sync runs from an older
   or differently-configured source (a scrubbed string reappears publicly). Diff
   the last published commit against the staged result and grep ADDED lines for
   identity strings; a reappearing personal string blocks the sync. Fix at the
   source, never by hand-editing the profile copy:

   ```bash
   if git -C "$PROFILE_REPO" diff --cached -U0 | grep -E '^\+' | \
     grep -Ei '<your-real-identity-patterns>'; then
     echo "BLOCKER: sanitization regressed" >&2
     exit 1
   fi
   ```

---

## Phase 4 — Dynamic exclusion (detect un-sanitizable files)

After sanitization, grep for any remaining personal references. Show actual results — don't speculate.

> Two known false-positive classes, both audited manually (2026-07-10), not chased with more
> regex:
> 1. The protected `npx @lucassantana/sharekit install <user>` lines (Phase 3's deliberate
>    exception — real product name, not a leak).
> 2. `sync-sharekit-profile`'s own SKILL.md, which documents the redaction patterns themselves
>    (e.g. the placeholder pattern text in ITS Phase 3/4 rules describes what to redact — it's
>    not real leaked data). This skill is structurally self-referential — no other skill's
>    subject matter is "describe these exact identity strings" — so it's excluded from this
>    scan by directory, not by chasing every self-mention. When actually RUNNING Phase 3/4 for
>    real, substitute your own real identity values for the placeholders below — this file
>    intentionally ships with fake examples, not real ones, since it's published publicly.

```bash
PERSONAL_REFS=""
while IFS= read -r f; do
  case "$f" in */sync-sharekit-profile/*) continue ;; esac
  if grep -v "npx @lucassantana/sharekit install" "$f" | grep -q \
      "<your-real-identity-patterns-here>"; then   # substitute your real GH user/email/hostname patterns when running for real
    PERSONAL_REFS="$PERSONAL_REFS
$f"
  fi
done < <(/usr/bin/find "$PROFILE_DIR" -type f \( -name "*.md" -o -name "*.sh" -o -name "*.py" \))

echo "Phase 4 scan: $(echo "$PERSONAL_REFS" | grep -c . || echo 0) files with residual personal refs"
```

For each file found:
- If it's a skill's SKILL.md → remove the entire skill directory, log: `Excluded (personal-ref): skills/<name>/`
- If it's an agent file → remove the agent file, log: `Excluded (personal-ref): agents/<name>.md`
- If it's a reference/asset within a skill → remove the file, log: `Excluded (personal-ref): <path>`

Report the full exclusion list, even if empty: `Phase 4: 0 files excluded` is a valid and useful result.

---

## Phase 5 — Secret scan

Run the local sharekit scanner (the published npm package doesn't include `scan` yet).
The scanner lives in the **sharekit** repo, not the profile repo (path fixed 2026-07-18:
`$PROFILE_REPO/src/index.ts` doesn't exist → `ERR_MODULE_NOT_FOUND`); the scan target is
the profile's `claude/` dir:

```bash
SHAREKIT_REPO="${SHAREKIT_REPO:-/Volumes/External HD/Desenvolvimento/sharekit}"
cd "$SHAREKIT_REPO"
npx tsx src/index.ts scan "$PROFILE_DIR" 2>&1
```

Classify findings by severity:
- **HIGH** (API keys, private keys, real bearer tokens): stop, show findings, ask whether to fix or `--force`
- **MED/LOW** (env-var names like `CLOUDFLARE_API_TOKEN='your-token'`, template placeholders, example paths): surface them, don't block — these are documentation examples

Report as: `CLEAN (HIGH: 0, MED: 0, LOW: N)` — use CLEAN, not PASS.

---

## Phase 6 — Diff + confirmation gate

Show what actually changed:

```bash
git -C "$PROFILE_REPO" diff --stat
git -C "$PROFILE_REPO" diff --name-only | head -30
```

Emit a summary table:
```
Changes ready to commit:
  Skills:    N added, N updated, N removed
  Hooks:     N changed
  Standards: N changed
  Agents:    N added, N updated, N removed
  Excluded:  <list each item with reason, e.g. "skills/sync-memories/ (personal-ref)">
```

Then emit:
```
Proceed to commit? (10s without objection = yes)
```

Wait. If user objects or requests changes, revise. Otherwise proceed.

---

## Phase 7 — Branch and PR

> `main` requires the `CodeRabbit` status check with `enforce_admins: true` (2026-07-10 —
> parity with the org's other rulesets). Direct pushes to `main`, including from the repo
> owner, are rejected. Push a branch and open a PR instead — merging is a separate,
> explicit step, not automated by this skill.

```bash
cd "$PROFILE_REPO"
BRANCH="sync/profile-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"
git add claude/
git commit -m "chore(profile): sync skills, CLAUDE.md — $(date +%Y-%m-%d)"
git push -u origin "$BRANCH"

PR_URL=$(gh pr create --title "chore(profile): sync — $(date +%Y-%m-%d)" \
  --body "Automated sync from sync-sharekit-profile skill." --base main --head "$BRANCH")
echo "PR: $PR_URL"
```

Report the PR as open, pending review/merge:
```
PR opened: <PR_URL> (waiting on CodeRabbit; merge is a separate manual step)
Install (once merged): npx @lucassantana/sharekit install LucasSantana-Dev
```

Do not merge the PR as part of this skill — surface it and stop. Do not retry with a bypass
flag (`--admin`) without the user explicitly asking; that reintroduces the exact bypass this
migration closed.

---

## Pull-back procedure (public profile -> live setup)

The round trip is NOT symmetric. Publishing sanitizes; pulling back can revert
portability fixes, delete machine-local settings, and reintroduce placeholders
into executable code. NEVER rsync/mirror the profile back over the live tree.

1. **Backup first:** snapshot before any write. `cp -a` preserves symlinks, so
   snapshot canonical targets, not the symlinked runtime view: `~/.claude/skills`
   points at `~/.agents/skills`, so copy `~/.agents` (canonical) plus the
   non-symlinked parts of `~/.claude`
   (`cp -a ~/.agents ~/.agents.bak-$(date +%Y%m%d-%H%M)`), or use a git snapshot
   of the trees in scope.
2. **Three-way classification per changed file** — compare the last-applied public
   version (A), the new public version (B), and the live version (C):

   | Live (C) matches | Meaning | Action |
   |---|---|---|
   | B | already current | skip |
   | A | clean fast-forward | apply B |
   | neither | local divergence | inspect by hand, never auto-apply |
   | (file absent locally) | new addition | apply, then placeholder-audit |

   Divergent files resolve in favor of the LOCAL copy by default: portability
   fixes flow toward the machine that needs them (rule 1.2), and a blind
   overwrite reverts them.
3. **Settings files are merge targets, never copy targets.** Absence of a key in
   the incoming version is not an instruction to remove it. Merge by key; keep
   machine-local values (model, UI prefs, locally registered hooks).
4. **Post-apply verification + rollback:** `bash -n` every script touched, parse every
   config file, grep the applied set for placeholder tokens (a placeholder inside
   a pattern/path/command/comparison is a defect until reviewed). If any check
   fails, restore the step-1 backup over every applied file and stop with a
   failure status; never leave the live tree partially updated.

---

## Reconciliation

Always output this block, even on stop/failure:

```
SYNC-SHAREKIT-PROFILE
  Source:       ~/.claude/ (skills: N dirs, hooks: N files, standards: N files, agents: N files)
  Profile repo: <last-commit-sha> (<date>) → <new-sha | pending | unchanged>
  Excluded:     <each item with reason — "none" if clean>
                  skills/foo/ — personal-ref (homelab-host path)
                  agents/bar.md — personal-ref (email)
  Scan:         CLEAN (HIGH: 0, MED: 0, LOW: N)
  Diff:         N files changed, N added, N removed
  Status:       PR opened (<PR_URL>) | Blocked (<reason>) | Pending confirmation

Install: npx @lucassantana/sharekit install LucasSantana-Dev
```

---

## Stop conditions

- External HD not mounted → halt at Phase 0
- HIGH-severity scan findings → halt at Phase 5, await human decision
- Profile repo has unexpected uncommitted changes → surface and confirm before overwriting
- `git push` fails → surface error, leave commit local
