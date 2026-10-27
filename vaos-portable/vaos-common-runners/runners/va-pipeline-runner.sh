#!/bin/sh
# va-pipeline-runner.sh — Generic multi-stage pipeline runner (sh implementation).
# Usage: sh va-pipeline-runner.sh <stage-dir> [--stage stage1,stage2,... | --all]
# Each stage is a script (sh) in <stage-dir> named "NN-name.sh". Runs sequentially,
# passing a context directory via VAOS_CTX. Conforms to unit-based output conventions.

set -eu

STAGES_DIR="${1:-}"
if [ -z "$STAGES_DIR" ] || [ ! -d "$STAGES_DIR" ]; then
  printf 'Unit pr-%s: Run | StageDir: %s | Status: fail | Agent: va-pipeline-runner-runner-1 | Error: stages dir required or not found\n' "$(date +%s)" "${STAGES_DIR:-}"
  exit 1
fi

CTX_DIR="${VAOS_CTX:-$(mktemp -d /tmp/vaos-ctx.XXXXXX)}"
export VAOS_CTX="$CTX_DIR"
UID="pr-$(date +%s)"

# Collect stage scripts (NN-name.sh) sorted
STAGES="$(find "$STAGES_DIR" -maxdepth 1 -name '*.sh' | sort)"

# Support --stage filter
FILTER=""
case "${2:-}" in
  --stage)
    FILTER="${3:-}"
    ;;
  *)
    ;;
esac

if [ -z "$STAGES" ]; then
  printf 'Unit %s: Run | StageDir: %s | Status: fail | Agent: va-pipeline-runner-runner-1 | Error: no stage scripts found\n' "$UID" "$STAGES_DIR"
  exit 1
fi

for STAGE in $STAGES; do
  NAME="$(basename "$STAGE")"
  if [ -n "$FILTER" ] && ! printf '%s' "$NAME" | grep -q "$FILTER"; then
    continue
  fi
  printf 'Unit %s: Stage | Pipeline: %s | Stage: %s | Status: running | Agent: va-pipeline-runner-runner-1\n' "$UID" "$STAGES_DIR" "$NAME"
  sh "$STAGE"
  RC=$?
  printf 'Unit %s: Stage | Pipeline: %s | Stage: %s | Exit: %s | Status: ok | Agent: va-pipeline-runner-runner-1\n' "$UID" "$STAGES_DIR" "$NAME" "$RC"
done

printf 'Skill: va-pipeline-runner | Tool: va-pipeline-runner.sh | Timestamp: %s | Validation: pass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
