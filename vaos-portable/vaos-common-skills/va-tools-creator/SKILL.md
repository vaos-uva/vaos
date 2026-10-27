---
name: va-tools-creator
description: Creates VA tools (scripts, utilities, components) conforming to VA standards.
va_framework: true
depends_on:
  - skill:va-base
---

# VA Tools Creator

Creates VA tools that conform to TheVaGroup VA framework. **Depends on `va-base`** — load and follow conventions before creating any tool.

## Process

1. Load `va-base` for conventions
2. Define tool spec (identity, domain, role, spec, config, output)
3. Conform to Lambda pattern
4. Build following template(p, o) -> result
5. Validate at every boundary
6. Register in registry

## Tool Spec Template

```yaml
tool:
  identity: <tool-name>
  domain: <domain>
  role: <role>
  spec: <Spec>
  config: <Conf>
  output: <UnitResponse>
```

## Lambda Signature

```
Lambda<Ctx, Usr, Cfg, R>
  ctx: { registry, validator, log }
  usr: { spec: <Spec> }
  cfg: { <config> }
  R: { unit: UnitResponse, validation: ValidationResult }
```

## Validation Checklist

- [ ] Conforms to va-base conventions
- [ ] Unit-based output
- [ ] Deterministic
- [ ] Domain-isolated
- [ ] Schema-validated
- [ ] Registered in COMPONENTS
