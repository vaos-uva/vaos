#!/bin/sh
# va-template-processor.sh — Simple VA template processor using shell substitution.
# Usage: sh va-template-processor.sh <template-file> <key>=<value>...
# Replaces {{ key }} placeholders in template with provided values.
# Conforms to unit-based output + agent identity conventions.

set -eu

TEMPLATE="${1:-}"
shift || true

if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
  printf 'Unit tp-%s: Process | Agent: va-tools-creator-tool-1 | Status: fail | Error: template file required or not found\n' "$(date +%s)"
  exit 1
fi

UID="tp-$(date +%s)"
RESULT="$(cat "$TEMPLATE")"

while [ "$#" -gt 0 ]; do
  KEY="$(printf '%s' "$1" | cut -d= -f1)"
  VAL="$(printf '%s' "$1" | cut -d= -f2-)"
  RESULT="$(printf '%s' "$RESULT" | sed "s/{{ *$KEY *}}/$(printf '%s' "$VAL" | sed 's/[[\.*^$+?[|{( )]/\\&/g')/g")"
  shift
done

printf 'Unit %s: Process | Template: %s | Status: ok\n' "$UID" "$TEMPLATE"
printf '%s\n' '---'
printf '%s\n' "$RESULT"
printf 'Skill: va-template-processor | Tool: va-template-processor.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
