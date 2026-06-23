---
name: refactor
description: 'Surgical code refactoring to improve maintainability without changing behavior. Triggers: "refactor this", "clean up this code", "extract functions", "improve maintainability", "fix code smells". Covers god functions, code smells, type safety, design patterns. Gradual evolution, not revolution—use for improving existing code without rewriting.'
license: MIT
---

# Refactor

Improve code structure and readability without changing external behavior. Refactoring is gradual evolution, not revolution.

## Core Principle

**Behavior is preserved.** Refactoring changes *how* code works, not *what* it does. Small steps, tests after each, commit when tests pass.

## When NOT to Refactor

- Code that works and won't change again
- Critical production code without tests (add tests first)
- Under tight deadline
- "Just because" — need clear purpose

## Safe Refactoring Process

1. **PREPARE** — Ensure tests exist (write if missing). Commit current state. Create feature branch.  
   *Done when:* Tests all passing, baseline committed.

2. **IDENTIFY** — Find the code smell. Understand what code does. Plan the refactoring.  
   *Done when:* Smell identified, refactoring strategy documented.

3. **REFACTOR** (small steps) — Make one small change, run tests, commit if pass, repeat.  
   *Done when:* All changes atomic and test-verified.

4. **VERIFY** — All tests pass. Manual testing if user-facing. Performance unchanged or improved.  
   *Done when:* Full test suite green, benchmarks stable (or better).

5. **CLEAN UP** — Update comments/docs. Final commit with summary.  
   *Done when:* Docs synced, commit message captures why.

## Quick Smell Reference

See `REFERENCE.md` for full catalog:

- **10 Common Code Smells & Fixes** — Long methods, duplicated code, god objects, long parameter lists, feature envy, primitive obsession, magic numbers, nested conditionals, dead code, inappropriate intimacy
- **Design Patterns** — Strategy, Chain of Responsibility, and when to apply them
- **Extract Method walkthrough** — Detailed before/after example
- **Type Safety progression** — Untyped → typed refactoring
- **Safe Refactoring Process** — Step-by-step checklist

## Refactoring Checklist

**Code Quality:**
- [ ] Functions < 50 lines  
- [ ] Each function does one thing  
- [ ] No duplicated code  
- [ ] Descriptive names (vars, functions, classes)  
- [ ] No magic numbers/strings  
- [ ] Dead code removed  

**Structure:**
- [ ] Related code together  
- [ ] Clear module boundaries  
- [ ] Dependencies one-directional  
- [ ] No circular deps  

**Type Safety:**
- [ ] Types on all public APIs  
- [ ] No `any` without justification  
- [ ] Nullable types explicitly marked  

**Testing:**
- [ ] Refactored code tested  
- [ ] Tests cover edge cases  
- [ ] All tests pass before and after  

## Common Refactoring Operations

| Operation | Goal |
|-----------|------|
| Extract Method | Turn code fragment into named method |
| Extract Class | Move behavior to new class |
| Extract Interface | Create interface from implementation |
| Inline Method | Move method body back to caller |
| Pull Up Method | Move method to superclass |
| Push Down Method | Move method to subclass |
| Rename Method/Variable | Improve clarity |
| Introduce Parameter Object | Group related parameters |
| Replace Conditional with Polymorphism | Use polymorphism instead of switch/if |
| Replace Magic Number with Constant | Named constants |
| Decompose Conditional | Break complex conditions |
| Replace Nested Conditional with Guard Clauses | Early returns |
| Replace Type Code with Class/Enum | Strong typing |
| Replace Inheritance with Delegation | Composition over inheritance |
