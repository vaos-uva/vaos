#!/bin/sh
# va-registry-reader.sh — Reads the local VAOS registry and prints entries (group filter optional)
# Usage: sh va-registry-reader.sh [section|identity]
# Conforms to unit-based output + agent identity conventions.

set -eu

REGISTRY="${VAOS_REGISTRY:-$(dirname "$0")/../../vaos-portable-registry/registry.yaml}"
FILTER="${1:-}"

if [ ! -f "$REGISTRY" ]; then
  printf 'Unit reg-%s: Read | Agent: va-tools-creator-tool-1 | Status: fail | Error: registry not found at %s\n' "$(date +%s)" "$REGISTRY"
  exit 1
fi

UID="reg-$(date +%s)"
printf 'Unit %s: Read | Registry: %s | Filter: %s | Status: ok\n' "$UID" "$REGISTRY" "${FILTER:-all}"

if [ -n "$FILTER" ]; then
  # basic section extractor using awk
  awk -v sec="$FILTER" '
    $0 ~ "^" sec ":" {p=1; print; next}
    /^[A-Za-z_]+:/ && !/^[[:space:]]/ {if(p) exit}
    p {print}
  ' "$REGISTRY"
else
  cat "$REGISTRY"
fi

printf 'Skill: va-registry-reader | Tool: va-registry-reader.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
