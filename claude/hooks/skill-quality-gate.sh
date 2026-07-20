#!/usr/bin/env bash
# skill-quality-gate.sh — PostToolUse hook (SELF-CONTAINED, no external script dep).
# Derived from SkillSpector's CI-gate concept (ADR repo-list, 2026-06-24). No emoji (CLAUDE.md).
#
# DETERMINISTIC quality gate — makes skill quality MODEL-INDEPENDENT (a weaker model cannot
# ship a structurally-broken skill; the harness blocks it regardless of the model's judgment).
#   HARD (exit 2, blocks: model must fix): invalid YAML frontmatter, unclosed code fence.
#     These are unambiguous breakage — an invalid-YAML skill won't load; an odd fence breaks rendering.
#   SOFT (systemMessage warn, exit 0): name!=dir, missing mcp_servers, size, Done-when,
#     stop-conditions, workflow structure. Strong nudges, not breakage — kept non-blocking so
#     edits to the 245-skill legacy corpus aren't retroactively wedged.
#   Bypass: SKILL_GATE_BYPASS=1 (emergencies / intentional WIP).
set -e
[ "${SKILL_GATE_BYPASS:-0}" = "1" ] && exit 0

HOOK_JSON=$(cat); [ -n "$HOOK_JSON" ] || exit 0   # $(cat): robust to stdin without a trailing newline
TOOL=$(printf '%s' "$HOOK_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
FILE=$(printf '%s' "$HOOK_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# only SKILL.md Write/Edit/MultiEdit
case "$TOOL" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
case "$FILE" in */SKILL.md) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0

hard=""; warn=""
hadd(){ hard="${hard}${hard:+; }$1"; }
add(){ warn="${warn}${warn:+; }$1"; }

# ===== HARD checks (block) =====
# H1. frontmatter parses as strict YAML (the 19-skill bug class) — invalid YAML => skill won't load
python3 - "$FILE" <<'PY' 2>/dev/null || hadd "frontmatter not valid YAML (quote colon/list values)"
import re,sys,yaml
t=open(sys.argv[1]).read()
m=re.match(r'^---\n(.*?)\n---\n',t,re.S)
if not m: sys.exit(1)
yaml.safe_load(m.group(1))
PY
# H2. backtick fence parity — odd count => unclosed code block, breaks rendering
[ $(( $(grep -c '^```' "$FILE") % 2 )) -eq 0 ] || hadd "odd code-fence count (unclosed \`\`\`)"

# ===== SOFT checks (warn) =====
# S1. frontmatter name must match dir (composite-contract; caught the adt-auto-invoke drift 2026-06-26)
DIR="${FILE%/SKILL.md}"; DIR="${DIR##*/}"
NM=$(python3 - "$FILE" <<'PY' 2>/dev/null
import re,sys,yaml
t=open(sys.argv[1]).read()
m=re.match(r'^---\n(.*?)\n---\n',t,re.S)
try:
    d=yaml.safe_load(m.group(1)) if m else {}
    print((d or {}).get('name','') or '')
except Exception:
    print('')
PY
)
[ -n "$NM" ] && [ "$NM" != "$DIR" ] && add "frontmatter name '$NM' != dir '$DIR' (name should match dir)"
# S2. mcp_servers declared-vs-available (delegate to checker if present)
if [ -x "$HOME/.claude/scripts/skill-mcp-check.py" ]; then
  MCPOUT=$(python3 "$HOME/.claude/scripts/skill-mcp-check.py" "$FILE" 2>/dev/null | grep -iE 'MISSING|undeclared' | head -1 || true)
  [ -n "$MCPOUT" ] && add "mcp: ${MCPOUT}"
fi
# S3. size > 30 lines
[ "$(wc -l < "$FILE")" -gt 30 ] || add "under 30 lines (likely incomplete)"
# S4. Done-when present (broadened 2026-06-26 — composite "## Reconciliation" block is a
# completion contract; keep identical to harness-skill-scorecard.py)
grep -iqE "done when|^##+ .*(reconciliation|completion criteria|success criteria|definition of done|exit criteria|acceptance criteria)|^##+ .*\bdone\b" "$FILE" || add "no 'Done when:' criterion"
# S5. negative-rules / rationalizations / stop conditions (broadened 2026-06-26 — matches
# "Stop / escalation conditions", "Preconditions (hard-fail)", "bail out" etc; narrow literal
# false-flagged ~7 composites that DO halt — keep identical to harness-skill-scorecard.py)
grep -iqE "^##+ .*(stop|halt|escalat|precondition|hard.?fail|hard rule|negative rule|rationaliz|bail|abort|failure mode)" "$FILE" || add "no Hard rules / Common Rationalizations / Stop conditions section"
# S6. structured workflow (Phase/Step/Process/Workflow/Modes/Cycle headers OR numbered list)
grep -iqE "^##+ .*(Phase|Step|Process|Workflow|Mode|Cycle|Recipe|Pipeline)|^\*\*Step|^[0-9]+\. " "$FILE" || add "no structured workflow (Phase/Step/Process/Modes section or numbered steps)"

name="${FILE##*/skills/}"; name="${name%%/*}"
if [ -n "$hard" ]; then
  # exit 2 => blocking feedback surfaced to the model (PostToolUse); fix-or-bypass required
  echo "skill-quality-gate BLOCK ($name): ${hard}${warn:+ | also: $warn}. Fix, or set SKILL_GATE_BYPASS=1 if intentional." >&2
  exit 2
fi
if [ -n "$warn" ]; then
  printf '{"systemMessage": "skill-quality-gate (%s): %s"}' "$name" "$warn"
fi
exit 0
