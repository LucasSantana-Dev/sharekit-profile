# Model Tier Fit Reference

Tiers are generic — cheap/mechanical, standard/execution, heavy-reasoning — so this applies
regardless of provider. Claude names are the worked example; substitute your provider's
equivalent (e.g. GLM-4-Flash/Air/Plus, DeepSeek-chat/reasoner, Kimi's smaller/larger context
models).

| Task | Right tier | Claude example | Wrong signals |
|------|-----------|-----------------|----------------|
| Symbol lookup, grep, rename, format | Cheap/mechanical | Haiku | Standard/heavy tier |
| Feature impl, test gen, code review, analysis | Standard/execution | Sonnet | Heavy tier (cost waste), cheap tier (quality risk) |
| Architecture, ADR writing, ≥5-step reasoning, composite orchestration | Heavy-reasoning | Opus | Standard/cheap tier |
| Read-only analysis (Explore agentType) | Cheap or standard | Haiku or Sonnet | Heavy tier |
