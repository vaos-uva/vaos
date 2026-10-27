---
name: va-experts
description: Senior/Servant delegation framework for domain-specific work.
va_framework: true
depends_on:
  - skill:va-base
---

# VA Experts

VA Experts framework — SeniorClub + ServantClub hierarchy for domain-specific delegation. **Depends on `va-base`**.

## Domain

- **Domain Identifier:** `experts`
- **Senior Club:** Senior.Anatoly (development), Senior.Alexandr (architecture), Senior.Natasha (strict_ops)
- **Servant Club (representative):** Expert.Schema (Dmitry), Expert.BNF (grammar/DSL), Expert.FOL_utf8 (Elena)

## Process — Delegate a Task

1. Match target domain to an expert in the registry
2. Bound senior to the expert capacity
3. Delegate the work
4. Return to senior for validation

## Senior/Expert Routing

| Domain Need | Expert |
|-------------|--------|
| JSON/YAML schema | Expert.Schema (Dmitry) |
| Grammar / DSL / BNF | Expert.BNF |
| Formal logic / FOL | Expert.FOL_utf8 (Elena) |
| Development code | Senior.Anatoly |
| Architecture / ADR | Senior.Alexandr |
| Strict operations / compliance | Senior.Natasha |

## Validation Checklist

- [ ] Conforms to va-base conventions
- [ ] Correct expert/senior chosen for domain
- [ ] Unit-based output
- [ ] Deterministic
