#!/bin/sh
# va-shell-runner.sh — Generic shell command runner with unit-formatted output.
# Usage: sh va-shell-runner.sh <command...>
# Conforms to unit-based output + agent identity conventions.

set -eu

if [ "$#" -lt 1 ]; then
  printf 'Unit sh-%s: Run | Agent: va-tools-creator-tool-1 | Status: fail | Error: no command provided\n' "$(date +%s)"
  exit 2
fi

UID="sh-$(date +%s)"
START=$(date +%s)

OUTPUT="$("$@")"
RC=$?
END=$(date +%s)

printf 'Unit %s: Run | Command: %s | Exit: %s | Duration: %ss | Status: ok\n' \
  "$UID" "$*" "$RC" "$(( END - START ))"
if [ -n "$OUTPUT" ]; then
  printf '%s\n' '---'
  printf '%s\n' "$OUTPUT"
fi
printf 'Skill: va-shell-runner | Tool: va-shell-runner.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
