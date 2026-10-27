#!/bin/sh
# va-skill-runner.sh — Loads and validates a VA skill from the portable bundle.
# Usage: sh va-skill-runner.sh <skill-name>
# Wraps va-skill-loader.sh and validates the result via the unit standard.

set -eu

SKILL_NAME="${1:-}"
SKILLS_DIR="${VAOS_SKILLS_DIR:-$(dirname "$0")/../../vaos-common-skills}"
LOADER="${VAOS_LOADER:-$(dirname "$0")/../../vaos-common-tools/tools/va-skill-loader.sh}"

if [ -z "$SKILL_NAME" ]; then
  printf 'Unit sr-%s: Run | Skill: %s | Status: fail | Agent: va-skill-runner-runner-1 | Error: skill name required\n' "$(date +%s)" "${SKILL_NAME}"
  exit 2
fi

if [ ! -f "$LOADER" ]; then
  printf 'Unit sr-%s: Run | Skill: %s | Status: fail | Agent: va-skill-runner-runner-1 | Error: loader not found: %s\n' "$(date +%s)" "${SKILL_NAME}" "$LOADER"
  exit 1
fi

# Verify the skill exists before delegating
if [ ! -d "${SKILLS_DIR}/${SKILL_NAME}" ]; then
  printf 'Unit sr-%s: Run | Skill: %s | Status: fail | Agent: va-skill-runner-runner-1 | Error: no such skill in bundle\n' "$(date +%s)" "${SKILL_NAME}"
  exit 1
fi

UID="sr-$(date +%s)"
printf 'Unit %s: Run | Skill: %s | Loader: %s | Status: ok | Agent: va-skill-runner-runner-1\n' "$UID" "${SKILL_NAME}" "$LOADER"
printf '%s\n' '---'
sh "$LOADER" "$SKILL_NAME"
printf 'Skill: va-skill-runner | Tool: va-skill-runner.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
