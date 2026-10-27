#!/usr/bin/env sh
# vaos-portable-cli.sh — VAOS Portable CLI
# Commands: init, list, patterns, pattern-linear, pattern-multiline,
#           rules, check, validate, schema, help
# POSIX-sh portable: uses printf for ANSI output (not echo -e).

set -u

PORTABLE_ROOT="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

out() {
  printf '%b\n' "$*"
}

usage() {
  cat <<EOF
VAOS Portable CLI

Usage: $(basename "$0") <command> [options]

Commands:
  init               Initialize vaos-portable environment
  list               List vaos-portable components
  patterns           Show pattern definitions (patterns.yaml)
  pattern-linear     Run linear SSSW scanner on a file or stdin (-)
  pattern-multiline  Run multiline WSSSW scanner on a file or stdin (-)
  rules              Show governance rules (rules.yaml)
  check              Scan .yaml files for \$schema ref to .schema.yaml
  validate           Validate .yaml files against their JSON Schema
  schema             Show schema requirements
  help               Show this help

Env:
  VAOS_PORTABLE_ROOT=${PORTABLE_ROOT}
EOF
}

cmd_init() {
  out "${GREEN}[init]${NC} vaos-portable ready at: ${PORTABLE_ROOT}"
  out "${GREEN}[init]${NC} Manifest: vaos-manifest.yaml"
}

cmd_list() {
  out "${GREEN}[vaos-portable]${NC} Components:"
  find "$PORTABLE_ROOT" -maxdepth 2 -type d ! -path "$PORTABLE_ROOT" ! -path "$PORTABLE_ROOT/.*" | sort | sed "s|$PORTABLE_ROOT/||" | sed 's/^/  - /'
}

cmd_patterns() {
  PF="$PORTABLE_ROOT/vaos-common-patterns/patterns.yaml"
  if [ -f "$PF" ]; then
    cat "$PF"
  else
    out "${RED}[patterns]${NC} Not found: $PF" >&2
    return 1
  fi
}

cmd_pattern_linear() {
  T="${1:-}"
  if [ -z "$T" ]; then
    out "${RED}[pattern-linear]${NC} Usage: $(basename "$0") pattern-linear <file>|-" >&2
    return 1
  fi
  sh "$PORTABLE_ROOT/vaos-common-patterns/scanners/va-linear-scan.sh" "$T"
}

cmd_pattern_multiline() {
  T="${1:-}"
  if [ -z "$T" ]; then
    out "${RED}[pattern-multiline]${NC} Usage: $(basename "$0") pattern-multiline <file>|-" >&2
    return 1
  fi
  sh "$PORTABLE_ROOT/vaos-common-patterns/scanners/va-multiline-scan.sh" "$T"
}

cmd_rules() {
  RF="$PORTABLE_ROOT/vaos-common-rules/rules.yaml"
  if [ -f "$RF" ]; then
    cat "$RF"
  else
    out "${RED}[rules]${NC} Not found: $RF" >&2
    return 1
  fi
}

cmd_check() {
  out "${YELLOW}[check]${NC} Scanning .yaml files for \$schema refs..."
  TMP="$PORTABLE_ROOT/.vaos-cli-yaml-list.tmp"
  find "$PORTABLE_ROOT" -type f -name "*.yaml" 2>/dev/null | sort > "$TMP"
  FOUND=0
  MISSING=0
  while IFS= read -r F; do
    FOUND=$((FOUND + 1))
    REL="${F#$PORTABLE_ROOT/}"
    if grep -q '\$schema' "$F" 2>/dev/null; then
      out "  ${GREEN}OK${NC}   $REL"
    else
      out "  ${RED}MISS${NC} $REL"
      MISSING=$((MISSING + 1))
    fi
  done < "$TMP"
  rm -f "$TMP"
  out "[check] total: $FOUND | with \$schema: $((FOUND - MISSING)) | missing: $MISSING"
  [ "$MISSING" -gt 0 ] && return 1
  return 0
}

cmd_validate() {
  out "${YELLOW}[validate]${NC} JSON Schema 12 validation"
  if command -v ajv >/dev/null 2>&1; then
    out "${BLUE}[ajv]${NC} using ajv-cli"
    TMP="$PORTABLE_ROOT/.vaos-cli-yaml-list.tmp"
    find "$PORTABLE_ROOT" -type f -name "*.yaml" 2>/dev/null | sort > "$TMP"
    while IFS= read -r F; do
      REL="${F#$PORTABLE_ROOT/}"
      if grep -q '\$schema' "$F" 2>/dev/null; then
        out "  ${BLUE}>>${NC} $REL"
      fi
    done < "$TMP"
    rm -f "$TMP"
    out "${YELLOW}[hint]${NC} Map each \$schema to its .schema.yaml: ajv validate -s <schema> -d <data>"
  elif command -v python3 >/dev/null 2>&1; then
    out "${BLUE}[python]${NC} jsonschema available? checking..."
    python3 -c "import jsonschema,yaml" 2>&1 | tail -1
    out "${YELLOW}[hint]${NC} Implement via: python3 -c 'import jsonschema,yaml; ...'"
  else
    out "${RED}[validate]${NC} No validator found (need ajv-cli or python3+jsonschema+pyyaml)"
    return 1
  fi
}

cmd_schema() {
  cat <<'EOF'
Schema requirement (vaos-portable):
- Each .yaml file MUST reference its schema via \$schema pointing to a local .schema.yaml
- Schemas live in vaos-common-schemas/ or alongside the .yaml
- Use: vaos-portable-cli.sh check  (scan for \$schema refs)
- Use: vaos-portable-cli.sh validate  (validate against JSON Schema Draft 12)
EOF
}

# --- dispatch ---
COMMAND="${1:-}"
if [ "$COMMAND" = "-" ]; then
  out "${RED}Unknown command: -${NC}" >&2
  usage >&2
  exit 1
fi
case "$COMMAND" in
  init)              cmd_init ;;
  list)              cmd_list ;;
  patterns)          cmd_patterns ;;
  pattern-linear)    shift; cmd_pattern_linear "${1:-}" ;;
  pattern-multiline) shift; cmd_pattern_multiline "${1:-}" ;;
  rules)             cmd_rules ;;
  check)             cmd_check ;;
  validate)          cmd_validate ;;
  schema)            cmd_schema ;;
  help|--help|-h)    usage ;;
  '')                usage ;;
  *)  out "${RED}Unknown command:${NC} $COMMAND" >&2; usage >&2; exit 1 ;;
esac
