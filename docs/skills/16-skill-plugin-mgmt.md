# Skill & Plugin Management Skills

`write-a-skill` to create a new skill; `skill-maintainer` to audit and normalize the local catalog. `skill-effectiveness-audit` when you suspect a skill is being bypassed or bailing silently. `docs-sync` after editing any skill to propagate changes.

---

## /write-a-skill

Create new agent skills with proper structure, progressive disclosure, and bundled resources.

**Structure:**
- SKILL.md (description, when to use)
- Implementation (bash, agent dispatch, or MCP)
- References folder (templates, checklists)
- Tests (optional)

**Progressive disclosure:**
- Short title + one-line description
- "When to use" section
- Multi-part skill explanation

**When to use:** Creating new reusable skill

**Output:** New skill with structure + documentation

---

## /skill-creator

Create or update installed skills with clear trigger descriptions, stable naming, and SKILL.md structure.

**Fields:**
- Skill name (kebab-case)
- Description (one-line)
- Trigger pattern (when user would type this)
- Argument hint (optional)
- SKILL.md (full documentation)

**When to use:** Formalizing new skill; integrating into catalog

**Output:** Registered skill in skill catalog

---

## /skill-guide

Explain how to create, organize, and maintain installed skills.

**Topics:**
- Skill structure (SKILL.md, code, references)
- Naming conventions (kebab-case, prefixes)
- Documentation best practices
- Testing skills
- Publishing + maintenance

**When to use:** Learning to write skills

**Output:** Skill creation reference guide

---

## /skill-maintainer

Audit, normalize, merge, and improve the local skill catalog so routing stays clear and useful.

**Audits:**
- Naming consistency (are skills kebab-case?)
- Description quality (clear + specific?)
- Duplication (are there redundant skills?)
- Coverage gaps (are there unmet use cases?)

**Operations:**
- Rename for consistency
- Merge duplicate skills
- Improve descriptions
- Remove obsolete skills

**When to use:** Skill catalog maintenance; quarterly audit

**Output:** Normalized skill catalog

---

## /skill-effectiveness-audit

Scan session JSONLs for skills that bailed, returned "out of scope", or ran diagnostics without action.

**Flags:**
- Skills that bailed (couldn't help)
- Skills returning "out of scope"
- Diagnostic skills without action (ran but didn't implement)
- Skills with high failure rate

**When to use:** Suspect skill is broken or being misused

**Output:** Effectiveness audit + recommendations

---

## /find-skills

Discover relevant installable skills from the available skill ecosystem.

**Searches:**
- By keyword (e.g., "database", "testing", "deployment")
- By category (e.g., "testing", "debugging", "release")
- By use case (e.g., "add feature", "fix bug")

**When to use:** Looking for a skill; unsure what's available

**Output:** Matching skills with descriptions + links

---

## /plugin-audit

Read-only diagnostic — flag enabled plugins with zero usage, unregistered plugins, and disabled-but-installed plugins.

**Flags:**
- Zero-use plugins (installed but never used)
- Unregistered plugins (in settings but no SKILL.md)
- Disabled-but-installed (could be removed)
- Performance issues (plugins slowing down harness)

**When to use:** Optimize plugin configuration; identify bloat

**Output:** Plugin audit report

---

## /adt-auto-invoke

Meta-skill — defines when to apply other skills automatically without being asked.

**Configuration:**
- Intent keywords that trigger skill
- Composite-router mapping
- Hook wiring
- Auto-invoke rules

**When to use:** Setting up automatic skill invocation

**Output:** Auto-invoke rule configuration

---

## /adt-learn

Auto-extract reusable patterns from the current session into skills or memory.

**Extracts:**
- Repeated code snippets → potential utility function
- Common problem-solving pattern → potential skill
- Key lesson → memory file
- Architecture pattern → ADR

**When to use:** After completing complex work; capture learnings

**Output:** Extracted skill + memory files

---

## /adt-toolkit-sync

Bump the ai-dev-toolkit version pin in a downstream consumer repo and verify the sync path.

**When to use:** Distributing toolkit updates to dependent repos

**Process:**
1. Bump version in toolkit
2. Update version pin in consumer
3. Verify imports resolve
4. Test integration

**Output:** Synced toolkit version + verification

---

## /create-skill

Translate legacy skill-authoring requests into the canonical `skill-creator` workflow.

**Legacy → modern:**
- Hand-written description → skill-creator frontmatter
- Loose structure → SKILL.md structure
- Undocumented skill → documented + indexed

**When to use:** Modernizing old skill definitions

**Output:** Modernized skill with structure

---

## /create-subagent

Design and author reusable subagents for specialized AI tasks.

**Design:**
- Define role + capabilities
- Specify input/output schemas
- Write system prompt
- Test + validate

**When to use:** Creating specialized agent for repeated task

**Output:** Subagent definition + templates

---

## /docs-sync

Detect and reconcile drift between canonical skills/standards and their mirrored copies (~/.claude-env, ~/.claude, ~/.agents).

**Synchronizes:**
- SKILL.md files (canonical → mirrors)
- Standard policies (canonical → mirrors)
- Agent definitions
- Hook scripts

**When to use:** After editing any skill/standard/hook; prevent drift

**Output:** Synced copies + drift report

---

**Last updated:** 2026-06-25
