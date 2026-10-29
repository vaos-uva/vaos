#!/bin/sh
# va-skill-loader.sh — Loads a VA skill from the portable bundle and prints its SKILL.md
# Usage: sh va-skill-loader.sh <skill-name>
# Conforms to unit-based output + agent identity conventions.

set -eu

SKILLS_DIR="${VAOS_SKILLS_DIR:-$(dirname "$0")/../../vaos-common-skills}"
SKILL_NAME="${1:-}"

if [ -z "$SKILL_NAME" ]; then
  printf 'Unit %s: Load | Agent: va-tools-creator-tool-1 | Task: %s | Status: fail | Error: skill name required\n' "loader-$(date +%s)" "${SKILL_NAME}"
  exit 2
fi

SKILL_PATH="${SKILLS_DIR}/${SKILL_NAME}"
if [ ! -d "$SKILL_PATH" ]; then
  printf 'Unit %s: Load | Skill: %s | Agent: va-tools-creator-tool-1 | Status: fail | Error: no such skill in bundle\n' "loader-$(date +%s)" "${SKILL_NAME}"
  exit 1
fi

SKILL_FILE="${SKILL_PATH}/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
  printf 'Unit %s: Load | Skill: %s | Agent: va-tools-creator-tool-1 | Status: fail | Error: SKILL.md missing\n' "loader-$(date +%s)" "${SKILL_NAME}"
  exit 1
fi

UIDS="loader-$(date +%s)"
printf 'Unit %s: Load | Skill: %s | Path: %s | Status: ok\n' "$UIDS" "${SKILL_NAME}" "${SKILL_FILE}"
printf '%s\n' '---'
cat "$SKILL_FILE"
printf '%s\n' '---'
printf 'Skill: va-skill-loader | Tool: va-skill-loader.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
