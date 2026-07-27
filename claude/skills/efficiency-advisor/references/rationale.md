# Why This Matters

Token cost and wall-clock time pull opposite directions. Parallel cuts time but multiplies tokens per agent. Sequential cuts tokens but blocks. Getting this wrong by one order of magnitude is the most common runaway budget. Model tier mismatches multiply this: Opus for symbol lookup costs ~6× more than Haiku with identical output. Right tier + parallelism structure beats any prompt optimization.

Re-read waste is the hidden multiplier: 5 agents each reading the same 10k-token file = 50k input; one orchestrator reading once, injecting a 1k summary = ~6k total. Fresh agents inherit zero cache on content orchestrators already hold.
