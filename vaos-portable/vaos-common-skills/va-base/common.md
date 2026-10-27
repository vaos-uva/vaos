# VA Common — Shared Conventions

Shared data for all VA skills. Loaded by `va-base`.

## Unit Response Template

```
Unit {unitID}: <Operation> | Field1: {{ value1 }} | Field2: {{ value2 }} | Status: {{ status }} | Agent: {{ agent-id }} | Task: {{ task-id }} | Cycle: {{ cycle-n }} | Status: {{ status }} | Skill: {{ skill-name }} | Tool: {{ tool-name }} | Timestamp: {{ timestamp }} | Validation: {{ validation }}
```

Fields MUST NOT be on separate lines. Use inline field concatenation with `|` delimiter.

## Lambda Signature

```
Lambda<Ctx, Usr, Cfg, R>
  ctx: { registry, validator, log }
  usr: { spec: <Spec> }
  cfg: { <config> }
  R: { unit: UnitResponse, validation: ValidationResult }
```

## Validation Checklist

- [ ] Unit-based output
- [ ] **Every entity prints with its unique `id`** (r16) — unit responses carry `Unit {id}`, registry entries carry manifest `id`/`identity`, artifacts carry report ids
- [ ] **Every entity is produced from a registered template, never manual boilerplate** (r16) — pull from `.agents/registry/templates/` and bind `spec` + `params`
- [ ] Deterministic behavior
- [ ] Domain-isolated
- [ ] Schema-validated
- [ ] Agent state line present: `Agent: <id> | Task: <id> | Cycle: <n> | Status: <status>`
- [ ] Response info block present: `Skill: <name> | Tool: <name> | Timestamp: <ISO8601> | Validation: <pass|fail>`

## Naming Conventions

- **Skill names**: lowercase, hyphenated (e.g., `va-skill-creator`)
- **Senior IDs**: `Senior.<Name>` (e.g., `Senior.Anatoly`)
- **Expert IDs**: `Expert.<Domain>` (e.g., `Expert.Math`)
- **Unit IDs**: `{SeniorOrExpert}.{sequence}`

## VAOS Layers

| Layer | Responsibility |
|-------|----------------|
| VORK | Orchestration, Senior/Expert selection |
| VAOS | Lifecycle management, context binding |
| COMPONENTS | Registry, templates, schemas |
| TASK | Execution, delegation sequences |

---

**Document Version:** 1.0.0  
**Framework:** VAOS / TheVaGroup
