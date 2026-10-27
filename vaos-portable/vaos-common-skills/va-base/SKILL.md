---
name: va-base
description: Entry point and router for all VA skills. Contains routing, workflow, and shared conventions. All VA skills depend on this base.
va_framework: true
depends_on: []
---

# VA Base — Entry Point & Router

Entry point for all VA skills. Contains **routing**, **workflow**, and **shared conventions** in `common.md`.

## Mandatory Dependency Rule

**Every VA skill MUST declare `depends_on: ["va-base"]` in its frontmatter.**
This ensures:
- Shared conventions (`common.md`) are loaded
- Routing table is available
- Unit-response format is enforced
- Agent introduction protocol is active

## Routing

Local routing — all targets are present in the portable bundle:

| Request | Skill | Location |
|---------|-------|----------|
| `create skill` | va-skill-creator | vaos-common-skills/va-skill-creator |
| `create tool` | va-tools-creator | vaos-common-skills/va-tools-creator |
| `senior`, `expert`, `delegate` | va-experts | vaos-common-skills/va-experts |
| `anything else` | handle directly | — |

> Note: `supervisor`, `prompt`, `ozco`, `role`, `agency` routes removed — no local implementation in this portable bundle; handle directly as fallback.

## Workflow

1. **Read** the request
2. **Match** to a routing entry
3. **Load** the target skill via the `skill` tool
4. **Delegate** the work to that skill

## Rules

- **Every response must include** the `path name` and `id` of the artifact/unit.
- **Unit-based output** — all responses emit discrete units with inline `|` delimiter.
- **Determinism** — identical inputs produce identical outputs.
- **Introduce on every response** — every response MUST start with agent introduction line:
  `🔹 Agent: <agent-id> | Task: <task-id> | Cycle: <cycle-n> | Status: <status>`
- **Response info block required** — every response MUST end with a trailing info block:
  ```
  Skill: <skill-name>
  Tool: <tool-name>
  Timestamp: <ISO8601>
  Validation: <pass|fail>
  ```
- **Agent identity** — the agent-id follows `<skill-name>-<role>-<instance>` format (e.g., `va-auditor-auditor-1`)
- **Use templates, not manual** — always create artifacts from templates in `.agents/registry/templates/` (see `MANIFEST.yaml`). Do **not** recommend or write manual boilerplate; use the template registry via `va-tools-creator` or `va-skill-creator`.

## Shared Conventions

See `common.md` for:
- Unit response templates
- Lambda signature standard
- Validation patterns
- Naming conventions

---

**Document Version:** 3.1.0  
**Status:** Formal Specification
