#!/usr/bin/env bash
# check-pr-automation-halt.sh — PreToolUse hook.
# Enforces the RULES.md "PR automation halt" + "No AI attribution" invariants
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
# EXPLICIT protected-ref push", not "no push to main". Server-side branch protection remains the
# authoritative control; this hook is a fast local tripwire, not a replacement for it.
set -uo pipefail

input="$(cat)"
[[ -n "$input" ]] || exit 0

verdict="$(HOOK_INPUT="$input" python3 - <<'PY' 2>/dev/null
import json, os, re, shlex, sys

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


for argv in simple:
    if not argv:
        continue
    exe, args = argv[0], argv[1:]
    exe = exe.rsplit("/", 1)[-1]

    if exe == "git" and args[:1] == ["push"]:
        rest = args[1:]
        if any(a in FORCE or a.startswith("--force-with-lease=") for a in rest):
            print("BLOCK\tforce-push rewrites shared history (protected invariant: no force-push).")
            break
        if any(not a.startswith("-") and protected_ref(a) for a in rest):
            print("BLOCK\tdirect push to protected branch (main/release/*); open a PR instead "
                  "(branch_policy: feature=pr-required).")
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
            print("CHECKPR\t" + num)
            break
PY
)"

kind="${verdict%%$'\t'*}"
detail="${verdict#*$'\t'}"

if [[ "$kind" == "BLOCK" ]]; then
  echo "BLOCKED by harness PR-automation-halt invariant (RULES.md):" >&2
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
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  if [[ -z "$me" || -z "$repo" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (RULES.md):" >&2
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
      echo "BLOCKED by harness PR-automation-halt invariant (RULES.md):" >&2
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

  pr_author="$(gh pr view "$pr" --json author --jq '.author.login' 2>/dev/null || true)"

  if [[ -n "$humans" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (RULES.md):" >&2
    echo "  PR #$pr has input from another person: $(echo "$humans" | tr '\n' ' ')" >&2
    echo "  Halt and ask the human." >&2
    exit 2
  fi
  if [[ "$pr_author" != "$me" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (RULES.md):" >&2
    echo "  PR #$pr is authored by '${pr_author:-unknown}', not by you ('$me'). Halt and ask the human." >&2
    exit 2
  fi
fi

exit 0
