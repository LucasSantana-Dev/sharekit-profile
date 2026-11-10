#!/usr/bin/env bash
# PreToolUse hook for mcp__computer-use__request_access (<project-a>, local-only).
# Computer use drives the real desktop, so every other PreToolUse guard (block-secret-reads,
# bash-prefilter, check-pr-automation-halt) is blind to it: an approved Terminal is an
# unhooked shell, an approved Finder/Quick Look shows a .env on screen, a password manager
# shows the vault. request_access is the single gate every session passes before any click,
# so the deny list lives here. Exit 2 = deny (stderr shown to model). Exit 0 = allow; the
# built-in approval dialog still runs after this. Calls are already logged by tool-logger.sh.
# Matching is EXACT on the lowercased name or bundle id (".app" stripped), never substring:
# "zed" as a substring would hit "authorized", "terminal" would hit unrelated app names.
set -euo pipefail

payload="$(cat)"
command -v python3 >/dev/null 2>&1 || { echo "computer-use-guard: python3 missing, denying request_access (fail closed)" >&2; exit 2; }

IFS= read -r -d '' PYSRC <<'PYEOF' || true
import sys, json, unicodedata
try:
    d = json.loads(sys.stdin.read() or '{}')
except Exception:
    print("computer-use-guard: unparseable payload, denying request_access")
    sys.exit(2)
if d.get('tool_name') != 'mcp__computer-use__request_access':
    sys.exit(0)
ti = d.get('tool_input') or {}

DENY = {
    # Shell-equivalent: bypasses every Bash/Read hook.
    'terminal': 'shell', 'com.apple.terminal': 'shell',
    'iterm': 'shell', 'iterm2': 'shell', 'com.googlecode.iterm2': 'shell',
    'warp': 'shell', 'dev.warp.warp-stable': 'shell',
    'ghostty': 'shell', 'com.mitchellh.ghostty': 'shell',
    'kitty': 'shell', 'net.kovidgoyal.kitty': 'shell',
    'alacritty': 'shell', 'org.alacritty': 'shell',
    'wezterm': 'shell', 'com.github.wez.wezterm': 'shell',
    'visual studio code': 'shell', 'code': 'shell', 'com.microsoft.vscode': 'shell',
    'code - insiders': 'shell', 'visual studio code - insiders': 'shell', 'com.microsoft.vscodeinsiders': 'shell',
    'vscodium': 'shell', 'com.vscodium': 'shell',
    'cursor': 'shell', 'com.todesktop.230313mzl4w4u92': 'shell',
    'intellij idea': 'shell', 'intellij idea ce': 'shell', 'pycharm': 'shell', 'pycharm ce': 'shell',
    'webstorm': 'shell', 'goland': 'shell', 'rider': 'shell', 'android studio': 'shell',
    'docker': 'shell', 'docker desktop': 'shell', 'com.docker.docker': 'shell',
    # Another agent with its own shell and tools, outside this session's hooks.
    'claude': 'agent shell', 'com.anthropic.claudefordesktop': 'agent shell',
    # Remote control of another machine.
    'screen sharing': 'remote control', 'com.apple.screensharing': 'remote control',
    'remote desktop': 'remote control', 'com.apple.remotedesktop': 'remote control',
    'zed': 'shell', 'dev.zed.zed': 'shell',
    'script editor': 'shell', 'com.apple.scripteditor2': 'shell',
    'automator': 'shell', 'com.apple.automator': 'shell',
    'shortcuts': 'shell', 'com.apple.shortcuts': 'shell',
    # Any file on disk, Quick Look of .env/.pem.
    'finder': 'filesystem', 'com.apple.finder': 'filesystem',
    # Security and system configuration.
    'system settings': 'system settings', 'system preferences': 'system settings',
    'com.apple.systempreferences': 'system settings',
    # Credential stores.
    'keychain access': 'credentials', 'com.apple.keychainaccess': 'credentials',
    'passwords': 'credentials', 'com.apple.passwords': 'credentials',
    '1password': 'credentials', '1password 7': 'credentials', 'com.1password.1password': 'credentials',
    'bitwarden': 'credentials', 'com.bitwarden.desktop': 'credentials',
    'dashlane': 'credentials', 'lastpass': 'credentials', 'keepassxc': 'credentials',
}

def norm(a):
    # NFKC folds full-width and compatibility forms; then drop invisible format/control/mark
    # characters ("Ter<U+200B>minal") and fold every Unicode space to one ASCII space.
    # Decompose, strip, then NFKC, then strip again: NFKC alone composes "l"+U+0301 into one
    # letter that the strip would miss.
    strip = lambda s: ''.join(' ' if unicodedata.category(c).startswith('Z') else c
                              for c in s if unicodedata.category(c) not in ('Cc', 'Cf', 'Mn'))
    a = strip(unicodedata.normalize('NFKC', strip(unicodedata.normalize('NFD', a))))
    a = ' '.join(a.split()).lower().rstrip('/')
    a = a.rsplit('/', 1)[-1]              # /System/Applications/Utilities/Terminal.app
    while a.endswith('.app'):
        a = a[:-4].rstrip()
    return a

if not isinstance(ti, dict):
    ti = {}
apps = ti.get('apps')
if not isinstance(apps, list):
    apps = [apps] if apps else []
reasons = []
# The schema says string[]; anything else ([["Terminal"]], {"name": ...}) is not worth parsing.
if any(not isinstance(a, str) for a in apps):
    reasons.append("non-string entry in apps")
hits = sorted({f"{a} ({DENY[norm(a)]})" for a in apps if isinstance(a, str) and norm(a) in DENY})
if hits:
    reasons.append("denied apps: " + ", ".join(hits))
# Any value other than absent/false counts as a request ("true", 1).
if ti.get('clipboardRead') not in (None, False):
    reasons.append("clipboardRead (clipboard may hold a copied password or token)")
if ti.get('systemKeyCombos') not in (None, False):
    reasons.append("systemKeyCombos (Cmd+Space/Spotlight launches apps outside the allowlist)")
if reasons:
    print("BLOCKED computer-use request_access: " + "; ".join(reasons) +
          ". These bypass the harness hooks. Request only the app under test, or ask the operator to do this step by hand.")
    sys.exit(2)
sys.exit(0)
PYEOF

rc=0
msg="$(printf '%s' "$payload" | python3 -c "$PYSRC")" || rc=$?
[ "$rc" -eq 0 ] && exit 0
# Fail closed: a crashed guard must not wave through desktop control.
[ "$rc" -eq 2 ] || msg="computer-use-guard: internal error rc=$rc, denying request_access"
echo "$msg" >&2
exit 2
