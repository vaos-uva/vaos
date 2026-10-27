#!/bin/sh
# va-unit-validator.sh — Validates that input text conforms to the VA unit-output format.
# Usage: sh va-unit-validator.sh <file-or-stdin>
# Checks: presence of "Unit <id>:", " | " delimiter, "Status:", and closing "Validation:" block.
# Conforms to unit-based output + agent identity conventions.

set -eu

INPUT="${1:-}"
if [ -n "$INPUT" ]; then
  CONTENT="$(cat "$INPUT")"
else
  CONTENT="$(cat)"
fi

UID="val-$(date +%s)"
FAIL=0

if printf '%s' "$CONTENT" | grep -qE '^Unit [^:]+:'; then
  HAS_UNIT="ok"
else
  HAS_UNIT="missing"; FAIL=1
fi

if printf '%s' "$CONTENT" | grep -q '|'; then
  HAS_DELIM="ok"
else
  HAS_DELIM="missing"; FAIL=1
fi

if printf '%s' "$CONTENT" | grep -q 'Status:'; then
  HAS_STATUS="ok"
else
  HAS_STATUS="missing"; FAIL=1
fi

if printf '%s' "$CONTENT" | grep -q 'Validation: pass\|Validation: fail'; then
  HAS_VALIDATION="ok"
else
  HAS_VALIDATION="missing"; FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  printf 'Unit %s: Validate | UnitHeader: %s | Delimiter: %s | Status: %s | InfoBlock: %s | Agent: va-unit-validator-tool-1 | Validation: pass\n' \
    "$UID" "$HAS_UNIT" "$HAS_DELIM" "$HAS_STATUS" "$HAS_VALIDATION"
  exit 0
else
  printf 'Unit %s: Validate | UnitHeader: %s | Delimiter: %s | Status: %s | InfoBlock: %s | Agent: va-unit-validator-tool-1 | Validation: fail\n' \
    "$UID" "$HAS_UNIT" "$HAS_DELIM" "$HAS_STATUS" "$HAS_VALIDATION"
  exit 1
fi
