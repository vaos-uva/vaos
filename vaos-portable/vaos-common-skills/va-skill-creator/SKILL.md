---
name: va-skill-creator
description: Creates VA framework skills. Delegates to va-base for conventions.
va_framework: true
depends_on:
  - skill:va-base
---

# VA Skill Creator

Creates VA skills conforming to TheVaGroup VA framework. **Depends on `va-base`** — load and follow conventions before creating any skill.

## Process

1. Load `va-base` skill for conventions
2. Parse the skill specification (name, description, domain, senior ownership, depends_on)
3. Generate `SKILL.md` from template with frontmatter + body
4. Generate `common.md` if shared conventions are needed
5. Validate against skill-schema.yaml
6. Register in local registry

## Skill Spec Template

```yaml
name: <skill-name>
description: <description>
va_framework: true
depends_on:
  - skill:va-base
---
# <Skill Title>

<description>

## Domain
- **Domain:** <domain>
- **Senior:** <Senior.Name>
```

## Validation Checklist

- [ ] Conforms to va-base conventions
- [ ] Unit-based output
- [ ] Deterministic
- [ ] Registered in registry.yaml
