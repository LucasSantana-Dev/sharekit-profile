// Debate workflow template — fill in ARTIFACT, LENSES, and optionally OPENROUTER_MODELS,
// then invoke via the Workflow tool (script: this file's contents, or scriptPath if saved).
// Do not hand-roll a fresh debate script each time - copy this one and fill the three
// blanks below. See ~/.claude/skills/debate/SKILL.md for the full method.

export const meta = {
  name: 'debate',
  description: 'FILL ME: one-line description of the question being debated',
  phases: [
    { title: 'Round 1 - Independent lenses' },
    { title: 'Round 2 - Rebuttal with peers visible' },
    { title: 'Synthesis' },
  ],
}

// --- FILL IN 1: the full context every lens argues from ---------------------------
const ARTIFACT = `
FILL ME: what's been built/decided so far, what evidence exists, what's genuinely
uncertain. Include open questions - lenses should be free to disagree about them.
Keep this complete but not bloated; every lens prompt re-sends it, so trim ruthlessly
before adding more.
`

// --- FILL IN 2: 3 genuinely distinct critical lenses (the skill's floor) -----------
// Default: omit `model` entirely (inherits the session model) - only set it for a
// SPECIFIC lens you're highly confident needs a different tier, and say why. Do not
// tier-diversify by default; measured to burn apex-tier tokens (opus/fable) on routine
// non-apex decisions. See SKILL.md Phase 1 escalation rule.
const LENSES = [
  {
    key: 'lens-key-1',
    label: 'Human-readable lens name',
    // model: omit by default - see escalation rule above
    prompt: `You are <role/lens framing>. Read the ARTIFACT below and answer: <the
specific question this lens should argue>. Give a clear verdict, not just tradeoffs.
Under 350 words. Respond with the required fields: verdict, key_points (3-5 items),
priority_recommendation.\n\nARTIFACT:\n${ARTIFACT}`,
  },
  // ...repeat for each lens (3 minimum - fewer is not a real debate, see SKILL.md)
]

// --- FILL IN 3 (optional): only if the user explicitly asked for other providers ---
// Leave empty to run Claude-tier lenses only. See scripts/openrouter_call.py - call it
// via a Bash step OUTSIDE this workflow (the workflow sandbox has no network access),
// then merge its output into the synthesis prompt below as extra text. Do not attempt
// to call OpenRouter from inside agent()/parallel() - only Claude-tier models are
// dispatchable there.
// const OPENROUTER_MODELS = ['openai/gpt-5.5', 'deepseek/deepseek-v4-pro']

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'One-paragraph clear verdict' },
    key_points: { type: 'array', items: { type: 'string' }, description: '3-5 concrete points' },
    priority_recommendation: { type: 'string', description: 'The single concrete next action this lens argues for' },
  },
  required: ['verdict', 'key_points', 'priority_recommendation'],
}

phase('Round 1 - Independent lenses')
const round1 = await parallel(LENSES.map(l => () =>
  agent(l.prompt, { label: `r1:${l.key}`, phase: 'Round 1 - Independent lenses', schema: VERDICT_SCHEMA, ...(l.model ? { model: l.model } : {}) })
    .then(r => ({ ...l, round1: r }))
))
log(`Round 1 done: ${round1.filter(Boolean).length}/${LENSES.length} lenses responded`)

phase('Round 2 - Rebuttal with peers visible')
const peerSummary = round1.filter(Boolean).map(r =>
  `[${r.label}] verdict: ${r.round1.verdict}\nkey points: ${r.round1.key_points.join(' | ')}\npriority: ${r.round1.priority_recommendation}`
).join('\n\n')

const round2 = await parallel(round1.filter(Boolean).map(r => () =>
  agent(
    `You previously argued (as the "${r.label}" lens) on this question:\n\n${r.prompt}\n\nYour Round 1 position was:\nVerdict: ${r.round1.verdict}\nKey points: ${r.round1.key_points.join(' | ')}\nPriority: ${r.round1.priority_recommendation}\n\nHere is what ALL lenses (including you) argued in Round 1:\n\n${peerSummary}\n\nNow REBUT or REFINE your position given what the other lenses argued. Where do you disagree with another lens and why? Where do they change your mind? Do NOT just restate Round 1 - engage directly with at least 2 other lenses' arguments by name. Under 350 words. Respond with the required fields: verdict, key_points (3-5 items), priority_recommendation.`,
    { label: `r2:${r.key}`, phase: 'Round 2 - Rebuttal with peers visible', schema: VERDICT_SCHEMA, ...(r.model ? { model: r.model } : {}) }
  ).then(r2 => ({ ...r, round2: r2 }))
))
log(`Round 2 done: ${round2.filter(Boolean).length}/${LENSES.length} lenses rebutted`)

phase('Synthesis')
const allPositions = round2.filter(Boolean).map(r =>
  `## ${r.label}\nRound 1 verdict: ${r.round1.verdict}\nRound 1 priority: ${r.round1.priority_recommendation}\n\nRound 2 (after seeing peers): ${r.round2.verdict}\nRound 2 priority: ${r.round2.priority_recommendation}\nRound 2 key points: ${r.round2.key_points.join(' | ')}`
).join('\n\n')

// Synthesis model: omit by default (inherits session model). Only set 'claude-fable-5'
// when the disagreement being reconciled independently clears the apex-tier bar (see
// SKILL.md Phase 1 escalation rule) - not as a fixed default for every debate.
const synthesis = await agent(
  `${LENSES.length} independent reviewers debated what to do next (full context below), each arguing from a distinct lens, then rebutted each other after seeing all Round 1 positions.\n\nORIGINAL ARTIFACT:\n${ARTIFACT}\n\nALL LENSES' FULL POSITIONS (Round 1 and Round 2 after seeing peers):\n\n${allPositions}\n\nSynthesize this into a single structured plan. Explicitly state: (1) where the lenses converged/agreed, (2) where they genuinely disagreed and how you're resolving it (or flagging it as needing the user's decision, not yours to resolve) - name which lens's argument won and why, never average, (3) a concrete phased plan with the smallest safe next action first. Under 600 words.`,
  { label: 'synthesis', phase: 'Synthesis' }
)

return { round1: round1.filter(Boolean), round2: round2.filter(Boolean), synthesis }
