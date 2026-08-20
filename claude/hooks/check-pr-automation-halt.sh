#!/usr/bin/env bash
# check-pr-automation-halt.sh: PreToolUse hook.
# Enforces the "PR automation halt" + "No AI attribution" invariants
# against git push / gh CLI operations. Blocks (exit 2) on:
#   - push to main/release/* (protected branches; PR-required)
#   - force-push to any branch
#   - --admin bypass attempts on a real `gh` invocation
#   - git commit messages containing AI-attribution markers
#   - gh pr automations (comment/merge/close/review) when the PR has comments
#     from another person (halt + tell the user)
#
# Author of record is the human operator; bots (dependabot, renovate,
# coderabbit, greptile, sonar) are not "another person."
#
# WHERE THESE INVARIANTS ARE WRITTEN DOWN. There is no RULES.md. Earlier versions of this file
# pointed five error messages at one, and it has never existed, so every block sent the reader to
# a ghost document. The real sources:
#   - branch policy, merge method, --admin ban ... standards/pr-conventions.md
#   - no AI attribution ....................... CLAUDE.md "Commit + PR attribution", standards/identity.md
#   - halt on another person's PR ............. CLAUDE.md "Hard rules", standards/autonomy-tiers.md
#   - push exemptions ......................... standards/pr-conventions.md "Exempt repos"
#
# PARSING CONTRACT (this is the whole point of the rewrite): detection tokenizes the command with
# shlex and inspects the argv of each simple command. It does NOT substring-grep the raw text.
# The grep version blocked its own commit (the MESSAGE named a flag) and its own test script (the
# FIXTURES contained `git push origin main` as quoted strings). A quoted mention is one token and
# can never be argv[0], so mention and use are now distinguishable.
#
# Fails OPEN (exit 0) on unparseable input: a blocking hook that wedges on odd quoting is worse
# than one that misses an edge case, and the operator still has branch protection server-side.
#
# KNOWN GAP, stated so this is not mistaken for full coverage: a bare `git push` with no refspec
# is NOT caught, because the target branch is implicit and the hook cannot know the command's
# working directory reliably enough to resolve HEAD. So a silent detection log here means "no
# EXPLICIT protected-ref push", not "no push to main". This hook is a fast local tripwire, not a
# replacement for server-side branch protection.
#
# DO NOT READ THAT AS "the server will catch it." This comment used to promise exactly that, and
# the promise was false for at least one repo: a personal memory vault synced by an automated
# Stop-hook script had `protected: false` on its main branch, so the documented gap led somewhere
# nobody was watching. Verify, never assume:
#     gh api repos/<owner>/<repo>/branches/main --jq .protected
#
# PUSH_EXEMPTIONS below is the response: a repo that legitimately takes direct pushes gets named
# in a local file, resolved by remote identity, instead of being exempt by accident of command
# shape. See standards/pr-conventions.md "Exempt repos".
set -uo pipefail

input="$(cat)"
[[ -n "$input" ]] || exit 0

verdict="$(HOOK_INPUT="$input" python3 - <<'PY' 2>/dev/null
import json, os, re, shlex, subprocess, sys

try:
    d = json.loads(os.environ.get("HOOK_INPUT", ""))
except Exception:
    sys.exit()
if not isinstance(d, dict) or d.get("tool_name", "") not in ("Bash", "bash"):
    sys.exit()
ti = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
cmd = ti.get("command") or d.get("command") or ""
if not cmd.strip():
    sys.exit()

OPS = {";", "&&", "||", "|", "&"}
try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except Exception:
    sys.exit()          # unparseable: fail open

simple, cur = [], []
for t in tokens:
    if t in OPS:
        if cur:
            simple.append(cur); cur = []
    else:
        cur.append(t)
if cur:
    simple.append(cur)

PROTECTED = {"main", "master"}
FORCE = {"--force", "-f", "--force-with-lease"}
ATTRIB = re.compile(r"co-authored-by:.*(claude|bot)|generated (with|by) .*claude|\U0001F916", re.I)


def protected_ref(arg: str) -> bool:
    ref = arg.split(":")[-1]                    # git push origin HEAD:main
    ref = re.sub(r"^refs/heads/", "", ref)
    return ref in PROTECTED or ref.startswith("release/")


# Repos where a direct push to a protected branch IS the intended workflow.
#
# READ FROM A FILE, NOT HARDCODED HERE, for two reasons. This hook is published to a public
# profile, so a repo name baked into it would both leak the owner's setup and get rewritten by
# the publisher's sanitizer into a placeholder, turning the list into a string that matches
# nothing: a security-relevant behaviour change disguised as a cosmetic one. Whoever installs
# this profile gets an empty list and therefore no exemptions until they write their own, which
# is the correct default.
#
# PATH IS HARNESS-NEUTRAL. PUSH_EXEMPTIONS_FILE wins if set; otherwise it sits next to whatever
# config dir the running harness uses (CLAUDE_CONFIG_DIR, else ~/.claude), so this works under
# OpenCode and other Claude-compatible CLIs instead of assuming one layout.
#
# Format: one `owner/name` per line, `#` comments allowed. Absent file = no exemptions.
PUSH_EXEMPTIONS = os.environ.get("PUSH_EXEMPTIONS_FILE") or os.path.join(
    os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"),
    "push-exemptions.txt",
)


def exempt_remotes() -> tuple:
    try:
        with open(PUSH_EXEMPTIONS) as fh:
            out = []
            for line in fh:
                line = line.split("#", 1)[0].strip()
                # Require a single owner/name segment; anything else is a config typo, and a
                # typo in an allowlist must not widen it.
                if re.fullmatch(r"[A-Za-z0-9._-]+/[A-Za-z0-9._-]+", line):
                    out.append(line)
            return tuple(out)
    except Exception:
        return ()


def git_out(cwd_hint: str, *args) -> str:
    """Run a read-only git command, returning "" on any failure. 2s cap because this runs
    inside a PreToolUse hook: a hung `git` would stall the tool call, not just mis-answer."""
    try:
        out = subprocess.run(
            ["git", "-C", cwd_hint or os.getcwd(), *args],
            capture_output=True, text=True, timeout=2,
        )
    except Exception:
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def push_remote(rest: list) -> str:
    """The remote a `git push` actually targets: first non-flag argument, else the configured
    default. Reading this from the command matters. An earlier version always resolved
    `origin`, so in a repo whose origin was exempt, `git push upstream main` inherited the
    exemption and reached a completely different repository."""
    for i, a in enumerate(rest):
        if a.startswith("-"):
            continue
        # `--repo <name>` and refspecs are not remotes; the remote is the first bare arg.
        if i and rest[i - 1] in ("--repo", "-o", "--push-option", "--exec", "--receive-pack"):
            continue
        return a
    return ""


def push_is_exempt(cwd_hint: str, rest: list) -> bool:
    """True only when the remote THIS push targets is explicitly exempt.

    MATCHED ON owner/name FROM THE GIT REMOTE URL, never on the directory name: a fork, or any
    local directory that merely shares the name, must not inherit the exemption.

    FAILS CLOSED on every uncertainty (no repo, git missing, timeout, unknown remote name,
    unparseable URL). Returning False just keeps the normal block, the safe direction.

    Does NOT understand `git -C <dir> push` (cwd_hint only tracks a literal `cd`), which
    resolves to the session cwd and so fails closed. Wrong in the harmless direction; use
    `cd <dir> && git push`.
    """
    allow = exempt_remotes()
    if not allow:
        return False
    name = push_remote(rest)
    if not name:
        # No remote named: ask git which one this branch would push to, rather than assuming.
        name = git_out(cwd_hint, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{push}")
        name = name.split("/")[0] if "/" in name else (git_out(cwd_hint, "remote").split("\n")[0])
    if not name:
        return False
    url = git_out(cwd_hint, "remote", "get-url", name)
    if not url:
        return False
    remote = re.sub(r"\.git$", "", url)
    # Anchor on the separator so `.../evil-<name>` cannot satisfy `<name>`.
    return any(remote.endswith("/" + r) or remote.endswith(":" + r) for r in allow)


cwd_hint = ""
for argv in simple:
    if not argv:
        continue
    exe, args = argv[0], argv[1:]
    exe = exe.rsplit("/", 1)[-1]

    if exe == "cd" and args and not args[0].startswith("-"):
        cwd_hint = args[0]

    if exe == "git" and args[:1] == ["push"]:
        rest = args[1:]
        if any(a in FORCE or a.startswith("--force-with-lease=") for a in rest):
            print("BLOCK\tforce-push rewrites shared history (protected invariant: no force-push).")
            break
        # Explicit refspec, else ask git what this command would actually push. `git push`
        # and `git push origin` name no ref, and used to sail past this check entirely: the
        # gap the header documents. Resolving @{push}/HEAD closes the common case. When git
        # cannot answer (no repo, detached, git absent) the old permissive behaviour stands,
        # because failing closed here would wedge every push in any directory git cannot read.
        # First bare arg is the REMOTE, the rest are refspecs. Conflating the two made
        # `git push origin my-feature` resolve HEAD and block on the checked-out branch.
        bare = [a for a in rest if not a.startswith("-")]
        refspecs = bare[1:] if bare else []
        if refspecs:
            hits = [a for a in refspecs if protected_ref(a)]
        else:
            implied = git_out(cwd_hint, "rev-parse", "--abbrev-ref", "HEAD")
            hits = [implied] if implied and protected_ref(implied) else []
        if hits:
            # Force-push above is unconditional and stays that way; only the PR-required
            # rule yields, and only for a remote listed in push-exemptions.txt.
            if not push_is_exempt(cwd_hint, rest):
                print("BLOCK\tdirect push to protected branch (main/release/*); open a PR instead "
                      "(branch_policy: feature=pr-required). See standards/pr-conventions.md.")
                break

    if exe == "gh" and args[:1] and args[0] in ("pr", "repo", "api", "release") and "--admin" in args:
        print("BLOCK\t--admin bypass is not permitted; branch protection is authoritative.")
        break

    if exe == "git" and args[:1] == ["commit"]:
        msgs = [args[i + 1] for i, a in enumerate(args)
                if a in ("-m", "--message") and i + 1 < len(args)]
        msgs += [a.split("=", 1)[1] for a in args if a.startswith("--message=")]
        if any(ATTRIB.search(m) for m in msgs):
            print("BLOCK\tAI-attribution marker in commit message (protected invariant: "
                  "no-ai-attribution). Author of record is the human operator.")
            break

    if exe == "gh" and args[:2] and args[0] == "pr" and args[1] in (
            "comment", "merge", "close", "review", "ready", "edit"):
        num = next((a for a in args[2:] if a.isdigit()), "")
        if num:
            print("CHECKPR\t" + num + "\t" + cwd_hint)
            break
PY
)"

kind="${verdict%%$'\t'*}"
rest="${verdict#*$'\t'}"
detail="${rest%%$'\t'*}"
cwd_hint="${rest#*$'\t'}"

if [[ "$kind" == "BLOCK" ]]; then
  echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
  echo "  $detail" >&2
  exit 2
fi

# --- PR automation halt on human-commented PRs ---
#
# THREE SURFACES, NOT TWO. `gh pr view --json comments,reviews` reads issue-level
# comments and review BODIES. It never reads `pulls/N/comments`, the inline
# comments attached to lines of the diff. A human review that leaves only line
# comments (with an empty body, which is the common shape of "some notes on the
# diff") was therefore invisible to the exact check whose job is to notice it.
# Read all three.
#
# BOTS BY ACCOUNT TYPE, NOT BY NAME. The REST API exposes `user.type == "Bot"`,
# which is authoritative and never goes stale. The old name blocklist had to be
# amended by hand every time a new bot showed up (it missed `socket-security`
# and would have missed the next one). The name list is kept only as a second
# line for anything that reports an odd type, plus the `[bot]` suffix.
#
# IDENTITY IS A GITHUB LOGIN ON BOTH SIDES. An earlier version compared the PR
# author login against `git config user.name`, a DISPLAY name. Different
# namespaces, never equal, so the gate fired on every PR on every repo,
# including the operator's own with zero human comments. A gate that always
# fires teaches people to bypass it, which is worse than no gate.
#
# THE OPERATOR'S OWN COMMENTS ARE NOT "ANOTHER PERSON" and are filtered out.
#
# FAILS CLOSED. If the login or the repo cannot be resolved, block. For a gate
# whose job is to stop automation on someone else's PR, "I could not tell" has
# to mean stop, not proceed.
if [[ "$kind" == "CHECKPR" ]] && command -v gh >/dev/null 2>&1; then
  pr="$detail"
  me="$(gh api user --jq '.login' 2>/dev/null || true)"
  # A PreToolUse hook doesn't inherit the command's own `cd` (it runs in its own
  # process before the tool's shell starts), so `gh repo view` here resolves
  # against the SESSION's cwd, not wherever the command's `cd` points, empty
  # when the session started outside any repo. If the command itself led with
  # `cd <dir> && gh pr ...` (the common shape), retry resolution from that dir
  # before giving up; still fails closed if that yields nothing either.
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  if [[ -z "$repo" && -n "$cwd_hint" && -d "$cwd_hint" ]]; then
    repo="$(cd "$cwd_hint" 2>/dev/null && gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  fi
  if [[ -z "$me" || -z "$repo" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
    echo "  Could not resolve GitHub login (got '$me') or repo (got '$repo')." >&2
    echo "  Refusing to automate PR #$pr without knowing whose PR it is; check \`gh auth status\`." >&2
    exit 2
  fi

  NAME_BOTS='^(dependabot|renovate|coderabbit|coderabbitai|greptile|sonar|sonarcloud|github-actions|mergify|semantic-release-bot|allcontributors|socket-security|snyk-bot|codecov|netlify|vercel)(\[bot\])?$'
  # CADA CHAMADA E CONFERIDA SEPARADAMENTE. Num 404 (ou token sem escopo) o
  # `gh api --jq` imprime o JSON DE ERRO no stdout, e agrupar as tres com `{ }`
  # jogava esse JSON direto na lista de "humanos": o hook bloqueava dizendo
  # `input from another person: {"message":"Not Found",...}`. Bloquear era o
  # lado certo, mas pela razao errada e com uma mensagem que manda o operador
  # procurar um comentarista que nao existe.
  logins=""
  for endpoint in "issues/$pr/comments" "pulls/$pr/reviews" "pulls/$pr/comments"; do
    if ! saida="$(gh api "repos/$repo/$endpoint" --paginate --jq '.[] | select(.user.type != "Bot") | .user.login' 2>/dev/null)"; then
      echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
      echo "  Could not read $endpoint for PR #$pr (API error, or the PR does not exist)." >&2
      echo "  Refusing to automate a PR whose comments I cannot verify." >&2
      exit 2
    fi
    logins="$logins$saida"$'\n'
  done
  # Filtro de FORMA de login como ultima rede: um login do GitHub e so
  # alfanumerico e hifen, entao qualquer coisa com chave, aspa ou espaco nao e
  # gente, e sim resto de payload que vazou.
  humans="$(printf '%s' "$logins" \
    | grep -E '^[A-Za-z0-9][A-Za-z0-9-]*$' \
    | grep -vE '\[bot\]$' \
    | grep -viE "$NAME_BOTS" \
    | grep -vxF "$me" \
    | sort -u || true)"

  pr_author="$(gh pr view "$pr" -R "$repo" --json author --jq '.author.login' 2>/dev/null || true)"

  if [[ -n "$humans" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
    echo "  PR #$pr has input from another person: $(echo "$humans" | tr '\n' ' ')" >&2
    echo "  Halt and ask the human." >&2
    exit 2
  fi
  if [[ "$pr_author" != "$me" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
    echo "  PR #$pr is authored by '${pr_author:-unknown}', not by you ('$me'). Halt and ask the human." >&2
    exit 2
  fi
fi

exit 0
