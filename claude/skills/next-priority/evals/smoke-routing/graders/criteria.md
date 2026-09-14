---
type: llm
weight: 1
---

Pass if the agent invoked the Skill tool with skill "next-priority" (this
plugin's skill that decides the highest-value safe next action in a repo)
before answering, rather than answering purely from its own judgment without
consulting that skill. The description of "next-priority" is: "Decide the
highest-value safe thing to do right now in the active repo or workspace."

Fail if the agent answered the question without ever calling the Skill tool,
or called a clearly unrelated skill instead.
