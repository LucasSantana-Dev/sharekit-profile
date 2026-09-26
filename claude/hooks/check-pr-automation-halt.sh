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

# A SENTINEL, NOT A CHARACTER TEST. Two versions of this were wrong for opposite reasons.
# Enumerating operators (`{";", "&&", "||", "|", "&"}`) missed `|&`, which shlex glues into
# one token: `false |& git push --force origin main` never split and both invariants went
# silent. Testing "is this token made only of ;&| characters" fixed that and broke something
# worse: shlex runs posix=True, which STRIPS QUOTES, so a quoted argument `';&'` is
# indistinguishable from a bare operator by then. `git push ';&' --force origin main` split
# one argv in two, and the half carrying `--force` no longer had `git` at argv[0].
#
# Quote state only exists BEFORE shlex, so the split has to be decided there. normalize()
# already walks the text tracking quotes; it now emits SEP for an operator it sees outside
# quotes, and nothing else can produce that token. (2026-08-29, fourth pass.)
SEP = "\x01"


def normalize(text: str) -> str:
    """Make newline-separated commands visible, without corrupting quoted text.

    A NEWLINE ENDS A COMMAND, and treating it as plain whitespace was a real hole: in

        cmd1 | tail -2
        git push --force-with-lease -q

    the second line merged into the first pipeline's argv, `git` was never argv[0], and
    a force-push sailed past a gate that blocks it correctly when issued alone. Found by
    the gate failing to stop an actual force-push during a rebase.

    Two things must survive the rewrite, so it is not a blind newline replace:

    1. HEREDOC BODIES ARE DATA, not commands. Commit messages here routinely discuss
       `git push origin main`; splitting a heredoc into lines would read that prose as a
       real push and block the commit describing the fix.
    2. NEWLINES INSIDE QUOTES ARE LITERAL. `git commit -m 'x\\nCo-Authored-By: ...'`
       must stay one token, or the AI-attribution check loses the text it inspects.

    Three ways to hide a push from this were tried and none is exploitable, because bash
    does not run them either (checked by stubbing `git` and counting calls, not reasoned):
      - unbalanced quote swallowing later newlines: bash refuses the whole script,
        `unexpected EOF while looking for matching '"'`
      - a push wrapped in a heredoc: it is a real heredoc, so the body is stdin data for
        the preceding command, never executed. Removing it here matches bash.
      - backslash line-continuation before the push: the lines join, so `git push ...`
        becomes an argument to the previous command rather than a command.
    """
    # SEP is produced by this function and by nothing else; a literal one arriving in
    # the input would be an attacker splitting an argv for free.
    text = text.replace(SEP, " ")
    # Heredoc bodies (<<EOF, <<'EOF', <<-"EOF") removed wholesale.
    text = re.sub(r"<<-?\s*(['\"]?)(\w+)\1.*?^\s*\2\s*$", " ", text, flags=re.S | re.M)
    out, quote, escaped = [], None, False
    for ch in text:
        if escaped:
            out.append(ch); escaped = False; continue
        if ch == "\\" and quote != "'":
            out.append(ch); escaped = True; continue
        if quote:
            if ch == quote:
                quote = None
            out.append(ch); continue
        if ch in "'\"":
            quote = ch; out.append(ch); continue
        # `x=$(gh pr merge 5)` is a REAL merge, and it reached exit 0 having consulted
        # nothing: nothing separated `x=$(` from `gh`, so argv[0] was `x=$(gh` and the
        # gate never saw a `gh` at all. Substitution and subshell punctuation start a
        # new command, so they are separators here too (2026-08-29).
        # SPACES AROUND IT, because shlex(punctuation_chars=True) GLUES adjacent
        # punctuation into one token: two of these in a row became ";;", which is not
        # the ";" in OPS, so nothing split and the line stayed one command. A blank
        # line before `git push --force` was enough to silence the force-push gate
        # entirely, and `x=$(date)` before it did the same (2026-08-29).
        if ch in "<>":
            # A REDIRECTION ENDS THE COMMAND'S OWN ARGUMENTS; its target belongs to the
            # redirection, not to the command. `gh pr merge 27 --squash 2>&1 | tail` left
            # `2` and `>` looking like positional words, and the ambiguity rule then refused
            # a merge it should have judged (2026-08-29). The fd digit glued in front of the
            # operator goes with it.
            while out and out[-1].isdigit() and (len(out) < 2 or out[-2] == " "):
                out.pop()
            out.append(" " + SEP + " ")
            continue
        out.append(" " + SEP + " " if ch in "\n()`;&|" else ch)
    return "".join(out)


# normalize() runs BEFORE shlex and must stay there. shlex treats a newline as ordinary
# whitespace, so a command on its own line merges into the previous pipeline's argv and
# `git` stops being argv[0]. Do not remove this call to "simplify" the tokenizer.
try:
    lex = shlex.shlex(normalize(cmd), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except Exception:
    sys.exit()          # unparseable: fail open

simple, cur = [], []
for t in tokens:
    if t == SEP:
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
    # Leading `+` is git's force marker and belongs to the refspec, not the branch name.
    # Without stripping it, `git push origin +main` compared "+main" against "main", missed,
    # and sailed past the gate entirely in EVERY repo, exempt or not.
    ref = arg.lstrip("+").split(":")[-1]         # git push origin HEAD:main, +main, +HEAD:main
    ref = re.sub(r"^refs/heads/", "", ref)
    return ref in PROTECTED or ref.startswith("release/")


# A token that can actually be an argument to `git push`: a flag, a remote name, or a
# refspec (optionally force-marked, optionally src:dst). Anything carrying a space, quote,
# parenthesis or `$` is not one.
#
# THE EMPTY SOURCE IS DELIBERATE. `:main` is git's delete syntax, and an earlier version
# required a source, so `git push origin :main` was dropped as junk and DELETED a protected
# branch with no block at all. Destructive, and quieter than the push it was guarding.
REF = r"[A-Za-z0-9._/@~^{}-]+"
PUSH_TOKEN = re.compile(r"^-|^\+?(?:%s(?::\+?%s)?|:\+?%s)$" % (REF, REF, REF))

# Deleting a protected branch is at least as destructive as force-pushing over it, so it is
# blocked the same way: unconditionally, exemption or not. An exemption buys a repo out of
# the PR-required workflow, never out of losing its trunk.
DELETE_REFSPEC = re.compile(r"^\+?:")


def usable_push_args(rest: list) -> list:
    """Arguments up to the first token that could not come from a real `git push`.

    WHY THIS EXISTS. shlex runs with posix=True, which strips quotes, so a command that
    NESTS quoting (`echo "x $(f "cd d && git push origin main")"`) loses the inner quoting
    and its text re-tokenizes into what looks like a simple `git push`. That is how this
    gate blocked its own test script, twice: once historically (see the parsing contract
    above) and once while the exemption work was being written, where the stray fragment
    `'+ as refspec -> $(msg cd'` was read as a force-marked refspec.

    Dropping malformed tokens keeps real pushes fully evaluated (their arguments are all
    well-formed, so nothing is dropped) while parse residue evaluates to little or nothing.

    FILTER, DO NOT TRUNCATE. Stopping at the first bad token looks safer and is not:
    `git push origin ")" main` would stop at `origin` and let a protected-branch push
    through, so a single junk argument would buy an escape. Filtering keeps the `main`.

    An argument failing PUSH_TOKEN is assumed to be parse residue rather than real git
    syntax, and its presence puts the caller in safe-fallback mode: the explicit refspecs
    that survived are still judged, but the HEAD-resolution guess is skipped.
    """
    return [a for a in rest if PUSH_TOKEN.match(a)]


def forced(rest: list) -> bool:
    """Force in any spelling: the flags, or a refspec carrying git's `+` force marker.

    The `+` only counts IN REFSPEC POSITION, meaning after the remote. git itself reads it
    that way: in `git push +foo origin` the `+foo` is a remote name, not a force marker, and
    a first version that scanned every token flagged those as force pushes. Narrow beats
    eager here, since each false block trains the reader to route around the gate.
    """
    seen_remote = False
    for a in rest:
        if a in FORCE or a.startswith("--force-with-lease="):
            return True
        if a.startswith("-"):
            continue
        if not seen_remote:
            seen_remote = True          # first bare arg is the remote, never a refspec
            continue
        if a.startswith("+"):
            return True
    return False


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


# gh's own top-level commands. Anything else in that slot is a user alias, and an alias is
# a whole command wearing another name: `gh alias set m 'pr merge'` makes `gh m 5` a merge
# that spells neither "pr" nor "merge". Verified 2026-08-29: this box already defines one.
GH_CMDS = {
    "alias", "api", "attestation", "auth", "browse", "cache", "codespace", "completion",
    "config", "extension", "gist", "gpg-key", "help", "issue", "label", "org", "pr",
    "project", "release", "repo", "ruleset", "run", "search", "secret", "ssh-key",
    "status", "variable", "version", "workflow",
}


def gh_alias(name):
    """Expand a gh alias to its argv, or [] when there is no such alias.

    Returns ["!"] for a shell alias, whose body is arbitrary shell this gate never sees in
    the command text. The caller must fail closed on that, not shrug it off.
    """
    try:
        out = subprocess.run(["gh", "alias", "list"], capture_output=True, text=True,
                             timeout=5).stdout
    except Exception:
        return []
    for line in out.splitlines():
        k, sep, v = line.partition(":" if ":" in line else "\t")
        if not sep or k.strip() != name:
            continue
        v = v.strip()
        if v.startswith("!"):
            return ["!"]
        try:
            return shlex.split(v)
        except ValueError:
            return []
    return []


# A BASH KEYWORD IS NOT THE COMMAND. The gate only ever recognised a literal `git`/`gh` at
# argv[0], so `! git push --force origin main`, `{ git push --force origin main; }` and
# `time git push --force origin main` all reached exit 0 while bash really ran the push
# (proven with a stub git counting calls, 2026-08-29, fourth pass). Same for a leading
# assignment (`GIT_DIR=x git push ...`) and for sudo/env wrappers with their own flags.
WRAPPERS = {"!", "{", "}", "time", "command", "builtin", "exec", "nohup", "sudo", "env",
            "then", "else", "elif", "do", "done", "fi", "esac"}
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def real_argv(a):
    """argv with bash keywords, wrappers and leading assignments peeled off the front."""
    i, wrapped = 0, False
    while i < len(a):
        if a[i] in WRAPPERS or ASSIGN.match(a[i]):
            i, wrapped = i + 1, True
            continue
        break
    if wrapped:
        # `sudo -u alice git push ...`: a wrapper carries its own flags AND their values, and
        # guessing which flags take one is a losing game. Inside a wrapper prefix only, look
        # ahead for the command this gate actually judges. Finding a `git` that is merely an
        # argument (`sudo apt install git`) is harmless: it lands with no subcommand and
        # matches none of the rules below.
        #
        # NO CEILING ON THE SCAN. It was capped at 8, counted from where the peel stopped
        # rather than from `git`, so a wrapper plus a flag plus filler pushed the real
        # command out of the window: `exe` became `-i`, nothing fired, exit 0 on a live
        # force-push (2026-08-29, fifth pass). A cap here only ever loses the command.
        for j in range(i, len(a)):
            if a[j].rsplit("/", 1)[-1] in ("git", "gh"):
                return a[j:]
    return a[i:]


cwd_hint = ""
for argv in simple:
    if not argv:
        continue
    argv = real_argv(argv)
    if not argv:
        continue
    exe, args = argv[0], argv[1:]
    exe = exe.rsplit("/", 1)[-1]

    if exe == "cd" and args and not args[0].startswith("-"):
        cwd_hint = args[0]

    if exe == "git" and args[:1] == ["push"]:
        raw = args[1:]
        rest = usable_push_args(raw)
        # Something was dropped: this "command" is parse residue from a quoted mention, not
        # a push anyone is running. Judge only what survived, and never fall through to
        # resolving HEAD, which would block on the checked-out branch of whatever directory
        # the session happens to sit in.
        #
        # THIS IS NOT AN ESCAPE HATCH, and it was checked rather than assumed. Adding a junk
        # argument to dodge the HEAD path also stops git from running the command at all:
        # `git push ""` gives `fatal: bad repository ''`, `git push ")"` gives `fatal: ')'
        # does not appear to be a git repository`. Nothing is pushed. And junk sitting
        # ALONGSIDE a real target still blocks, because filtering keeps the real tokens:
        # `git push origin ")" main` is evaluated as `origin main`.
        residue = len(rest) < len(raw)
        if forced(rest):
            print("BLOCK\tforce-push rewrites shared history (protected invariant: no force-push).")
            break
        if any(DELETE_REFSPEC.match(a) and protected_ref(a) for a in rest):
            print("BLOCK\tdeleting a protected branch (main/release/*) is not permitted; "
                  "this is unconditional and a push exemption does not lift it.")
            break
        # `--delete`/`-d` turn every following refspec into a deletion.
        if any(a in ("--delete", "-d") for a in rest) and any(
                protected_ref(a) for a in rest if not a.startswith("-")):
            print("BLOCK\tdeleting a protected branch (main/release/*) is not permitted; "
                  "this is unconditional and a push exemption does not lift it.")
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
        # `--all` / `--mirror` push every local ref, so the checked-out branch says nothing
        # about what actually travels: from a feature branch they still deliver local `main`.
        # Treat them as touching a protected ref and let the exemption decide.
        if any(a in ("--all", "--mirror") for a in rest):
            hits = ["(--all/--mirror: every local ref)"]
        elif refspecs:
            hits = [a for a in refspecs if protected_ref(a)]
        elif residue:
            hits = []                   # truncated parse: no refspec to trust, do not guess
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

    # `gh` TAKES ITS FLAGS WHEREVER IT LIKES, and matching by argv POSITION missed all of
    # it: `gh -R acme/repo pr merge 5` left args[0] == "-R", and the first fix for that
    # still missed `gh pr -R acme/repo merge 5`. Both fell through to the final exit 0
    # having consulted NOTHING. So: skip flags wherever they sit and read what remains.
    #
    # BUT A FLAG'S VALUE IS NOT A POSITIONAL WORD. Dropping only the flag left the value
    # behind, and the value took the PR's place: `gh pr merge -b 42 5` merges #5 and this
    # gate cleared it by reading #42 instead — a false-CLEAR that needs no coincidence, just
    # a body text. Which flags carry a value is PER VERB, not global: `-m` is boolean
    # `--merge` under `merge` and `--milestone` under `edit`, and `-t` is `--subject` there
    # and `--title` here. Read off `gh pr <verb> --help`, gh 2.97.0, 2026-08-29.
    GH_VERB_VALUE_FLAGS = {
        "merge":   {"-A", "--author-email", "-b", "--body", "-F", "--body-file",
                    "--match-head-commit", "-t", "--subject"},
        "comment": {"-b", "--body", "-F", "--body-file"},
        "close":   {"-c", "--comment"},
        "review":  {"-b", "--body", "-F", "--body-file"},
        "ready":   set(),
        "edit":    {"--add-assignee", "--add-label", "--add-project", "--add-reviewer",
                    "-B", "--base", "-b", "--body", "-F", "--body-file",
                    "-m", "--milestone", "-t", "--title",
                    "--remove-assignee", "--remove-label", "--remove-project",
                    "--remove-reviewer"},
    }
    # `-R`/`--repo` is inherited, so it is the only value-taking flag gh accepts BEFORE the
    # verb; a non-persistent flag there is an error gh itself refuses.
    REPO_FLAGS = {"-R", "--repo"}

    def positionals(a, value_flags):
        """(word, index) for every token that is neither a flag nor a flag's value."""
        out, i = [], 0
        while i < len(a):
            t = a[i]
            if t == "--":                 # end of flags: everything after is positional
                out.extend((w, i + 1 + k) for k, w in enumerate(a[i + 1:]))
                break
            if t.startswith("-") and t != "-":
                i += 2 if (t in value_flags and i + 1 < len(a)) else 1
                continue
            out.append((t, i))
            i += 1
        return out

    def expand_aliases(a):
        """argv with a leading user alias replaced by what it stands for; None to block.

        An alias may expand to another alias, so this settles rather than expanding once.
        Bounded, and a name seen twice is a cycle.
        """
        pos = positionals(a, REPO_FLAGS)
        if not pos:
            return a
        i, seen = pos[0][1], set()
        while a[i] not in GH_CMDS and a[i] not in seen and len(seen) < 8:
            seen.add(a[i])
            expansion = gh_alias(a[i])
            if expansion == ["!"]:
                return None
            if not expansion:
                break
            a = a[:i] + expansion + a[i + 1:]
        return a

    eff = expand_aliases(args) if exe == "gh" else []
    if exe == "gh" and eff is None:
        print("BLOCK\tThat `gh` alias is a shell alias, whose body this gate never sees in "
              "the command text. Run the underlying gh command directly.")
        break
    pos = positionals(eff, REPO_FLAGS) if exe == "gh" else []
    words = [w for w, _ in pos]
    if exe == "gh" and words[:2] and words[0] == "pr" and words[1] in GH_VERB_VALUE_FLAGS:
        verb, verb_at = words[1], pos[1][1]
        # An explicit `--repo owner/name` is what gh itself will target, so it
        # outranks whatever repo the cwd happens to sit in. Without it the gate
        # reads PR #N's comments in the WRONG repo: that false-blocks a
        # cross-repo merge, and worse, it can clear a PR in the target repo
        # because a same-numbered PR in the cwd repo looked clean.
        repo_flag = ""
        for i, a in enumerate(eff):
            if a in REPO_FLAGS and i + 1 < len(eff):
                repo_flag = eff[i + 1]
            elif a.startswith("--repo="):
                repo_flag = a.split("=", 1)[1]
        # Re-read the tail with THIS verb's flags, so a body or a title stops looking like
        # a PR number.
        rest = [w for w, _ in positionals(eff[verb_at + 1:],
                                          GH_VERB_VALUE_FLAGS[verb] | REPO_FLAGS)]
        if len(rest) != 1:
            # Bare `gh pr merge` is "the PR of the current branch", which this hook cannot
            # see from outside your shell; two candidates means the flag table is behind
            # this gh. Neither is a cleared PR.
            print("BLOCK\t`gh pr " + verb + "`: this gate could not tell which PR that is "
                  "(candidates: " + repr(rest) + "). Pass the PR number explicitly.")
            break
        # gh documents `<number> | <url> | <branch>` for the PR argument. Taking the first
        # all-digit token read only the first of the three, and `#5` (which gh also accepts)
        # is not all-digit either: each of those walked out at exit 0. Carry the reference
        # through as gh wrote it and let gh resolve what gh accepts.
        ref = rest[0]
        m = re.search(r"github\.com/([^/\s]+/[^/\s]+)/pull/(\d+)", ref)
        if m:
            # The URL names the repo. Trusting the cwd instead is how PR #5 of one repo
            # gets vouched for by PR #5 of another.
            repo_flag = repo_flag or m.group(1)
            ref = m.group(2)
        elif ref.startswith("#") and ref[1:].isdigit():
            ref = ref[1:]
        print("CHECKPR\t" + ref + "\t" + cwd_hint + "\t" + repo_flag)
        break
PY
)"

kind="${verdict%%$'\t'*}"
rest="${verdict#*$'\t'}"
detail="${rest%%$'\t'*}"
tail="${rest#*$'\t'}"
cwd_hint="${tail%%$'\t'*}"
# `cd ~/.claude-env && gh pr merge ...` used to fall through to the session cwd, because the
# literal `~` is not a directory and the `[ -d "$cwd_hint" ]` test below rejected it. The
# hook then resolved a DIFFERENT repo, could not read that PR's comments, and failed closed
# on a clean PR (2026-08-29). Expand a leading ~ the way the shell would.
#
# `$HOME` is the SAME BUG and the first fix missed it: the command text is shlex-split, which
# strips the quotes of `cd "$HOME/.claude-env"` but expands nothing, so the hint arrives as a
# literal `$HOME/...` and fails `[ -d ]` exactly like `~` did. It blocked a `gh pr comment` on
# a clean PR the same afternoon. Anything the shell would have expanded before `cd` saw it has
# to be expanded here too, because this hook reads the command as TEXT, never as a shell runs it.
case "$cwd_hint" in
  "~")   cwd_hint="$HOME" ;;
  "~/"*) cwd_hint="$HOME/${cwd_hint#\~/}" ;;
  "\$HOME")      cwd_hint="$HOME" ;;
  "\$HOME/"*)    cwd_hint="$HOME/${cwd_hint#\$HOME/}" ;;
  "\${HOME}")    cwd_hint="$HOME" ;;
  "\${HOME}/"*)  cwd_hint="$HOME/${cwd_hint#\$\{HOME\}/}" ;;
esac
repo_flag=""
[[ "$tail" == *$'\t'* ]] && repo_flag="${tail#*$'\t'}"

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
  # Order matters: the command's own `cd` wins over the session cwd. Resolving the
  # session cwd FIRST made the hook read a DIFFERENT repo than the command targets,
  # which both blocks legitimate merges and can falsely clear a PR in another repo
  # (2026-08-28). --repo > command `cd` > session cwd, fail-closed if all empty.
  # THE PAYLOAD CARRIES THE SESSION cwd, ALREADY EXPANDED BY THE SHELL THAT RAN IT.
  # That is the authoritative directory. Reading a directory out of the command TEXT is what
  # produced three separate blocks on clean PRs in one afternoon (2026-08-29): `cd ~/x`, then
  # `cd "$HOME/x"`, then `--repo $R`. Each is something the shell expands and this hook, which
  # only ever sees text, cannot. Every one of them was patched with another `case` arm; the
  # arms are kept below because they still spare a needless block, but they are no longer
  # what the resolution rests on.
  session_cwd="$(HOOK_INPUT="$input" python3 - <<'PY' 2>/dev/null
import json, os
try:
    print(json.loads(os.environ.get("HOOK_INPUT", "")).get("cwd", "") or "")
except Exception:
    pass
PY
)"

  # An unexpanded --repo must NEVER fall through to a directory. Falling through reads PR #N
  # in the WRONG repo, and a same-numbered PR there can look clean: false-CLEAR is the
  # expensive side of this coin, and it is why --repo wins in the first place.
  repo="$repo_flag"
  if [[ -n "$repo" && ! "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules):" >&2
    echo "  --repo was given as '$repo', which is not a literal <owner>/<name>." >&2
    echo "  This hook reads the command as text and cannot expand a variable. Pass the literal." >&2
    exit 2
  fi
  # A `cd` target the hook cannot read is the same danger wearing the other hat: the command
  # aims somewhere else, and answering from the session cwd would vouch for the wrong repo.
  if [[ -z "$repo" && -n "$cwd_hint" && ! -d "$cwd_hint" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules):" >&2
    echo "  The command cd's to '$cwd_hint', which is not a directory I can read (an unexpanded" >&2
    echo "  variable, most likely). I will not answer for PR #$pr from the session directory." >&2
    echo "  Pass --repo <owner>/<name> explicitly." >&2
    exit 2
  fi
  if [[ -z "$repo" && -n "$cwd_hint" ]]; then
    repo="$(cd "$cwd_hint" 2>/dev/null && gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  fi
  if [[ -z "$repo" && -n "$session_cwd" && -d "$session_cwd" ]]; then
    repo="$(cd "$session_cwd" 2>/dev/null && gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  fi
  [[ -z "$repo" ]] && repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  # A branch name is a PR reference gh accepts, so the gate has to accept it too — but it
  # can only be turned into a number by asking gh, and only once the repo is known. Fails
  # closed: an unresolvable reference is not a cleared one.
  if [[ -n "$repo" && ! "$pr" =~ ^[0-9]+$ ]]; then
    resolved="$(gh pr view "$pr" --repo "$repo" --json number --jq '.number' 2>/dev/null || true)"
    if [[ -z "$resolved" ]]; then
      echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules):" >&2
      echo "  Could not resolve '$pr' to a PR number in $repo. Refusing to automate a PR I" >&2
      echo "  cannot identify. Pass the PR number." >&2
      exit 2
    fi
    pr="$resolved"
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

  # Login AND bot flag in one call. `is_bot` from the API is authoritative for the
  # author-identity check below, same as `user.type == "Bot"` is for commenters above.
  pr_author_info="$(gh pr view "$pr" -R "$repo" --json author --jq '[.author.login, (.author.is_bot // false | tostring)] | join(" ")' 2>/dev/null || true)"
  pr_author="${pr_author_info%% *}"
  pr_author_is_bot="${pr_author_info##* }"

  if [[ -n "$humans" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
    echo "  PR #$pr has input from another person: $(echo "$humans" | tr '\n' ' ')" >&2
    echo "  Halt and ask the human." >&2
    exit 2
  fi
  # BOT AUTHORS ARE NOT "ANOTHER PERSON" (CLAUDE.md Hard rules; the header of this file
  # already said so, but this check never implemented it: it blocked `gh pr close 333`
  # on a dependabot PR whose CI had failed, forcing a manual close). ONLY `is_bot`
  # from the API decides authorship, deliberately NOT the NAME_BOTS name list used for
  # commenters: a human who registers a login matching that regex (`sonar`, `codecov`,
  # `netlify` are plain words) must not have their PR automated. An EMPTY author still
  # fails closed: "" != "$me" and is_bot never resolves to "true".
  if [[ "$pr_author" != "$me" && "$pr_author_is_bot" != "true" ]]; then
    echo "BLOCKED by harness PR-automation-halt invariant (CLAUDE.md Hard rules; standards/pr-conventions.md):" >&2
    echo "  PR #$pr is authored by '${pr_author:-unknown}', not by you ('$me') and not a bot. Halt and ask the human." >&2
    exit 2
  fi
fi

exit 0
