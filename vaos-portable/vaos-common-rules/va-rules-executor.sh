#!/usr/bin/env sh
# va-rules-executor.sh — Executable VA governance rules engine (r01–r10)
# Encodes vaos-common-rules/rules.yaml as runnable algorithmic entities.
# Usage: sh va-rules-executor.sh [rule_id ... | all | list]
#   all (default) — run every rule
#   r03 r05       — run specific rules
#   list          — list available rules
# Emits unit-based output; exit 0 = pass, 1 = any rule failed.
# Runtime: sh (POSIX) per vaos-manifest.yaml infrastructure policy.

set -u

# resolve bundle root (vaos-common-rules is one level under vaos-portable)
RULES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PORTABLE_ROOT="$(CDPATH= cd -- "$RULES_DIR/.." && pwd)"

STATUS_OK=0
STATUS_FAIL=0

emit() {
  # emit: <unit> <op> <rule_id> <rule_name> <status> [detail]
  printf 'Unit %s: Execute | Rule: %s | RuleId: %s | Status: %s | Skill: va-rules | Tool: va-rules-executor.sh | Timestamp: %s | Validation: %s\n' \
    "$1" "$2" "$3" "$4" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$([ "$4" = pass ] && echo pass || echo fail)"
}

rule_list() {
  cat <<'EOF'
r01 mandatory-va-base-dependency
r02 unit-based-output
r03 determinism
r04 domain-isolation
r05 schema-validation
r06 agent-introduction
r07 response-info-block
r08 path-and-id-mandatory
r09 templates-not-manual
r10 registry-location
EOF
}

run_rule() {
  case "$1" in
    r01) rule_r01 ;;
    r02) rule_r02 ;;
    r03) rule_r03 ;;
    r04) rule_r04 ;;
    r05) rule_r05 ;;
    r06) rule_r06 ;;
    r07) rule_r07 ;;
    r08) rule_r08 ;;
    r09) rule_r09 ;;
    r10) rule_r10 ;;
    *)   printf 'Unknown rule: %s\n' "$1"; return 2 ;;
  esac
}

# r01 — every VA skill (except va-base) declares depends_on: skill:va-base
rule_r01() {
  local_fail=0
  for sk in "$PORTABLE_ROOT"/vaos-common-skills/*/; do
    [ -d "$sk" ] || continue
    name=$(basename "$sk")
    [ "$name" = va-base ] && continue
    if [ -f "$sk/SKILL.md" ] && grep -q 'depends_on' "$sk/SKILL.md" && grep -q 'va-base' "$sk/SKILL.md"; then
      :
    else
      printf '  FAIL %s/SKILL.md missing depends_on: skill:va-base\n' "$name"
      local_fail=1
    fi
  done
  if [ "$local_fail" -eq 0 ]; then
    emit "r01-$(date +%s)" mandatory-va-base-dependency r01 pass
  else
    emit "r01-$(date +%s)" mandatory-va-base-dependency r01 fail
  fi
  return $local_fail
}

# r02 — tool/runner/pattern-scanner scripts emit unit-based output with | delimiter and Status:
rule_r02() {
  local_fail=0
  for f in "$PORTABLE_ROOT"/vaos-common-tools/tools/*.sh "$PORTABLE_ROOT"/vaos-common-runners/runners/*.sh "$PORTABLE_ROOT"/vaos-common-patterns/scanners/*.sh; do
    [ -f "$f" ] || continue
    if grep -q 'Unit ' "$f" && grep -q '|' "$f" && grep -q 'Status:' "$f"; then
      :
    else
      printf '  FAIL %s does not emit unit-formatted output\n' "$(basename "$f")"
      local_fail=1
    fi
  done
  if [ "$local_fail" -eq 0 ]; then
    emit "r02-$(date +%s)" unit-based-output r02 pass
  else
    emit "r02-$(date +%s)" unit-based-output r02 fail
  fi
  return $local_fail
}

# r03 — determinism: no $RANDOM / nondeterministic constructs in scripts
rule_r03() {
  local_fail=0
  for f in "$PORTABLE_ROOT"/vaos-common-tools/tools/*.sh "$PORTABLE_ROOT"/vaos-common-runners/runners/*.sh "$PORTABLE_ROOT"/vaos-common-patterns/scanners/*.sh; do
    [ -f "$f" ] || continue
    if grep -q 'RANDOM\|mktemp[^ ]*[d]' "$f"; then
      printf '  WARN %s contains RANDOM/mktemp (may be nondeterministic)\n' "$(basename "$f")"
      local_fail=1
    fi
  done
  emit "r03-$(date +%s)" determinism r03 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r04 — domain isolation: each vaos-common-* component dir exists and holds only its domain
rule_r04() {
  local_fail=0
  for d in skills schemas specs templates standards tools runners rules installers patterns; do
    if [ -d "$PORTABLE_ROOT/vaos-common-$d" ]; then
      :
    else
      printf '  FAIL vaos-common-%s missing\n' "$d"
      local_fail=1
    fi
  done
  emit "r04-$(date +%s)" domain-isolation r04 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r05 — schema-validation: at least one schema present and each schema has $id
rule_r05() {
  local_fail=0
  if ls "$PORTABLE_ROOT"/vaos-common-schemas/*.yaml >/dev/null 2>&1; then
    for s in "$PORTABLE_ROOT"/vaos-common-schemas/*.yaml; do
      grep -q '\$id' "$s" || { printf '  FAIL %s missing $id\n' "$(basename "$s")"; local_fail=1; }
    done
  else
    printf '  FAIL vaos-common-schemas is empty\n'
    local_fail=1
  fi
  emit "r05-$(date +%s)" schema-validation r05 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r06 — agent-introduction: every script emits an Agent identity line
rule_r06() {
  local_fail=0
  for f in "$PORTABLE_ROOT"/vaos-common-tools/tools/*.sh "$PORTABLE_ROOT"/vaos-common-runners/runners/*.sh "$PORTABLE_ROOT"/vaos-common-patterns/scanners/*.sh; do
    [ -f "$f" ] || continue
    grep -q 'Agent:' "$f" || { printf '  FAIL %s missing Agent: identity line\n' "$(basename "$f")"; local_fail=1; }
  done
  emit "r06-$(date +%s)" agent-introduction r06 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r07 — response-info-block: every script ends with Validation: pass|fail block
rule_r07() {
  local_fail=0
  for f in "$PORTABLE_ROOT"/vaos-common-tools/tools/*.sh "$PORTABLE_ROOT"/vaos-common-runners/runners/*.sh "$PORTABLE_ROOT"/vaos-common-patterns/scanners/*.sh; do
    [ -f "$f" ] || continue
    grep -q 'Validation: pass\|Validation: fail' "$f" || { printf '  FAIL %s missing Validation: info block\n' "$(basename "$f")"; local_fail=1; }
  done
  emit "r07-$(date +%s)" response-info-block r07 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r08 — path-and-id-mandatory: schemas carry $id; rules carry id
rule_r08() {
  local_fail=0
  grep -q '^id:' "$PORTABLE_ROOT/vaos-common-rules/rules.yaml" || { printf '  FAIL rules.yaml missing id\n'; local_fail=1; }
  for s in "$PORTABLE_ROOT"/vaos-common-schemas/*.yaml; do
    [ -f "$s" ] || continue
    grep -q '\$id' "$s" || { printf '  FAIL %s missing $id\n' "$(basename "$s")"; local_fail=1; }
  done
  emit "r08-$(date +%s)" path-and-id-mandatory r08 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r09 — templates-not-manual: template files present and non-empty
rule_r09() {
  local_fail=0
  for t in "$PORTABLE_ROOT"/vaos-common-templates/*.template.yaml; do
    [ -f "$t" ] || continue
    grep -q '{{' "$t" || { printf '  FAIL %s empty or no placeholders\n' "$(basename "$t")"; local_fail=1; }
  done
  emit "r09-$(date +%s)" templates-not-manual r09 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# r10 — registry-location: portable registry present at bundle root
rule_r10() {
  local_fail=0
  if [ -f "$PORTABLE_ROOT/vaos-portable-registry/registry.yaml" ]; then
    grep -q 'vaos-portable' "$PORTABLE_ROOT/vaos-portable-registry/registry.yaml" || { printf '  FAIL registry missing workspace id\n'; local_fail=1; }
  else
    printf '  FAIL vaos-portable-registry/registry.yaml missing\n'
    local_fail=1
  fi
  emit "r10-$(date +%s)" registry-location r10 "$([ "$local_fail" -eq 0 ] && echo pass || echo fail)"
  return $local_fail
}

# dispatch
command="${1:-all}"
case "$command" in
  list)
    rule_list
    exit 0
    ;;
  all|'')
    for r in $(rule_list | awk '{print $1}'); do
      if run_rule "$r"; then
        STATUS_OK=$((STATUS_OK+1))
      else
        STATUS_FAIL=$((STATUS_FAIL+1))
      fi
    done
    ;;
  *)
    if [ $# -gt 0 ]; then
      for r do
        if run_rule "$r"; then
          STATUS_OK=$((STATUS_OK+1))
        else
          STATUS_FAIL=$((STATUS_FAIL+1))
        fi
      done
    fi
    ;;
esac

printf '\nSkill: va-rules | Tool: va-rules-executor.sh | Timestamp: %s | Rules: %s pass / %s fail | Validation: %s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STATUS_OK" "$STATUS_FAIL" "$([ "$STATUS_FAIL" -eq 0 ] && echo pass || echo fail)"

[ "$STATUS_FAIL" -eq 0 ] || exit 1
exit 0
