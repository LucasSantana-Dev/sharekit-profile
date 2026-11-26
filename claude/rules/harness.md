---
paths:
  - "**/.claude/**"
  - "**/claude/hooks/**"
  - "**/claude/skills/**"
  - "**/claude/standards/**"
  - "**/SKILL.md"
---

# Ao mexer no harness (skills, hooks, standards, settings)

- Regra geral do perfil muda no repo sharekit-profile por PR. O `~/.claude/CLAUDE.md` é gerado por `scripts/sync-claude-md.sh`: não edite à mão. Regra pessoal vai em `~/.claude/CLAUDE.local.md`.
- Hook novo ou editado em `~/.claude/hooks/` leva a linha de interruptor `CLAUDE_DISABLED_HOOKS` no topo. Depois rode `python ~/.claude/scripts/hooks-inventory.py`.
- Caminho de arquivo chega com `\` no Windows: normalize antes de comparar padrões.

@~/.claude/standards/skill-authoring.md
