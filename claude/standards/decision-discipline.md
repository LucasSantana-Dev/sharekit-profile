# Decision Discipline

In-flight self-doubt scaffold for non-trivial decisions. Borrowed from
addyosmani/agent-skills/doubt-driven-development. See ADR-0003 for context and
the 90-day revisit gate (2026-08-18).

## When to apply (concrete boundary)

Apply the 5-step **when ANY of:**

- Decision affects >1 module or crosses a service / API boundary
- Change touches >150 LOC and >1 reviewer would be involved
- Decision could cause >1 day of rework or a production incident if wrong
- You have a nagging doubt (the cheapest gate — trust the discomfort)
- Asserting something the compiler / types / tests can't verify (e.g., "this
  Dexie `update()` will set the record" — see past gotchas in MEMORY.md where
  contract review would have caught the bug)
- **Acting on a subagent's numeric or usage claim** ("unused", "strict superset",
  "N tokens", "zero calls") — re-verify with ONE direct command before acting.
  Recurred 3×: ADR-0041 haiku "superset" refuted by git diff; 2026-07-09 MCP
  "unused" refuted by transcript grep (meta-ads 6 + trello 31 sessions);
  2026-07-09 fixed-cost agent invented sizes. Agents guess from proxies;
  a 10-second direct check beats a wrong decision.

**Skip when:**

- Mechanical edits (renames, formatting, file moves)
- Following clear, unambiguous user instructions
- Pure tooling operations (running tests, listing files)
- User has prioritized speed over verification
- The compiler / type system / passing tests already encode the contract you'd
  verify

## The 5-step protocol

1. **CLAIM** — Write the decision in 2–3 lines. If you can't state it compactly,
   you have a vibe, not a decision.
2. **EXTRACT** — Reduce to the smallest reviewable unit: ARTIFACT (the actual
   code or config) + CONTRACT (what the dependency / spec / docs say it should
   do). Strip your reasoning.
3. **DOUBT** — Invoke a fresh-context reviewer with an **adversarial prompt**.
   Pass ARTIFACT + CONTRACT ONLY. Never pass the CLAIM or your reasoning — that
   biases the reviewer toward agreement. Prompt shape: "given ARTIFACT and
   CONTRACT, find every way ARTIFACT could fail to satisfy CONTRACT."
4. **RECONCILE** — Re-read ARTIFACT against each finding and classify in this
   precedence:
   1. Contract misread (fix the contract, re-loop)
   2. Valid + actionable (change the artifact, re-loop)
   3. Valid trade-off (document and accept)
   4. Noise (reviewer lacked context the artifact deliberately omits)
5. **STOP** — Halt when: next iteration yields only trivial findings, OR 3
   cycles completed (escalate to user, don't grind a fourth), OR user says ship
   it. If 3 cycles feels obviously insufficient, decompose ARTIFACT rather than
   lifting the cycle bound.

## Cross-model offer (interactive contexts only)

After a doubt cycle on a high-stakes decision, OFFER (never silently skip) a
second-opinion escalation: Codex CLI, Gemini CLI, manual external review, or
skip. Before invoking any external CLI: PATH check, version test, confirm exact
invocation with the user, use stdin/heredoc (never interpolate the artifact
into shell-quoted args), prefer a read-only sandbox.

In non-interactive contexts (`/loop`, autonomous loops, CI), skip the cross-model
offer with an announcement — never silently skip.

## Red flags

- Looping past 3 cycles without escalating to user
- Prompting with "is this good?" instead of "find issues"
- Reviewer rubber-stamps repeatedly across cycles → you're validating, not
  doubting; restart with stricter adversarial framing
- Stripping CONTRACT (reviewer has no spec to check against)
- Passing CLAIM or your reasoning (reviewer is biased toward agreement)
- Treating doubt-cycle findings as authoritative without re-reading the ARTIFACT
  yourself

## Retroactive vs proactive — open question (validated 2026-05-20)

Of 9 documented past gotchas in MEMORY.md (Dexie no-op, Wrangler env inheritance,
Vercel bare URL, Docker port collision, Jest resetMocks, BSD xargs, GitHub
app_id pin, Wrangler route syntax, protect-files over-match), 7 would have been
CAUGHT by this 5-step IF the reviewer looked up the relevant docs (1 MAYBE,
1 MISSED).

The pattern has **retroactive validity**. Whether naming it as a standard
shifts the operator from "catch in post-hoc fix" to "catch in-flight" is
**currently UNVALIDATED**. ADR-0003 sets a 90-day revisit gate at 2026-08-18
to check claude-mem + git log for ≥2 documented in-flight uses.

## Where this standard is cited from

- `~/.claude/skills/verify-before-done/SKILL.md` — pre-ship gate suggests the
  5-step on the leading uncertainty before emitting READY-TO-SHIP
- `~/.claude/agents/critic.md` — adversarial-mode `<Final_Checklist>` includes
  a 5-step suggestion item
- `~/.claude/skills/research-and-decide/SKILL.md` — Phase 2 critic invocations
  reference this standard as the explicit scaffold they're operationalizing
