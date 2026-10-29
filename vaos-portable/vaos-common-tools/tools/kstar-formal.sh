#!/bin/sh
# K* machine-formal symbolic self-rewriter.
# Generated termination certificate: SymPy rank r = 2*phase + version.
# Exact deltas: SELF_V0_TO_V1=-1, DRAFT_TO_CHECK=-2,
#               CHECK_TO_EMIT=-2, EMIT_TO_HALT=-2.
# POSIX sh only. No Python/SymPy runtime dependency; no eval/source.
set -eu
LC_ALL=C
export LC_ALL

usage() {
    printf '%s\n' "Usage: sh $0 [run|rules|languages]" \
      'run       emit the K* trace and the level-2 lift (default)' \
      'rules     emit the machine-readable transition relation' \
      'languages emit the finite alphabets Lang[lvl:0..2]'
}

# Machine state is the ordered pair (version, phase).
# version: V0=1, V1=0; phase: DRAFT=3, CHECK=2, EMIT=1, HALT=0.
phase_of() {
    case $1 in
        V0:DRAFT|V1:DRAFT) printf '3\n' ;;
        V1:CHECK) printf '2\n' ;;
        V1:EMIT) printf '1\n' ;;
        V1:HALT) printf '0\n' ;;
        *) return 1 ;;
    esac
}

version_of() {
    case $1 in
        V0:DRAFT) printf '1\n' ;;
        V1:DRAFT|V1:CHECK|V1:EMIT|V1:HALT) printf '0\n' ;;
        *) return 1 ;;
    esac
}

rank_of() {
    state=$1
    phase=$(phase_of "$state") || return 1
    version=$(version_of "$state") || return 1
    printf '%s\n' "$((2 * phase + version))"
}

# K is a total, deterministic transition on valid nonterminal states.
# The arrow is one symbolic rewrite, not shell evaluation.
K() {
    case $1 in
        V0:DRAFT) printf 'V1:DRAFT\n' ;;
        V1:DRAFT) printf 'V1:CHECK\n' ;;
        V1:CHECK) printf 'V1:EMIT\n' ;;
        V1:EMIT) printf 'V1:HALT\n' ;;
        V1:HALT) return 1 ;;
        *) printf '%s\n' 'K*: invalid machine state' >&2; return 2 ;;
    esac
}

# K* emits every member of the orbit, including its seed and normal form.
close() {
    state=$1
    fuel=${2:-8}
    case $fuel in ''|*[!0-9]*) printf '%s\n' 'K*: fuel must be an integer' >&2; return 2 ;; esac
    [ "$fuel" -gt 0 ] || { printf '%s\n' 'K*: fuel must be positive' >&2; return 2; }
    count=0
    while :; do
        before=$(rank_of "$state") || { printf '%s\n' 'K*: invalid state' >&2; return 2; }
        printf 'ORBIT\t%s\tRANK\t%s\n' "$state" "$before"
        if next=$(K "$state"); then
            after=$(rank_of "$next") || return 2
            [ "$after" -lt "$before" ] || {
                printf '%s\n' 'K*: ranking invariant violated' >&2
                return 2
            }
            count=$((count + 1))
            [ "$count" -le "$fuel" ] || {
                printf '%s\n' 'K*: fuel exhausted; closure is incomplete' >&2
                return 2
            }
            printf 'STEP\t%s\tTO\t%s\tDELTA\t%s\n' "$state" "$next" "$((after - before))"
            state=$next
        else
            code=$?
            [ "$code" -eq 1 ] || return "$code"
            printf 'NORMAL\t%s\n' "$state"
            return 0
        fi
    done
}

rules() {
    printf '%s\n' \
      'KSTAR-RULES/1' \
      'V0:DRAFT -> V1:DRAFT' \
      'V1:DRAFT -> V1:CHECK' \
      'V1:CHECK -> V1:EMIT' \
      'V1:EMIT -> V1:HALT' \
      'V1:HALT -> NORMAL'
}

# In the lifted representation, one whole lower-level word is one atom.
# Length-prefix framing makes this embedding unambiguous.
frame() {
    printf '%s:%s' "${#1}" "$1"
}

languages() {
    l0='K'
    printf 'Lang[lvl:0]/SYMBOL\t%s\n' "$l0"
    printf '%s\n' 'Lang[lvl:1]/ATOM_IS_WHOLE_TERM'
    for term in 'V0:DRAFT' 'V1:DRAFT' 'V1:CHECK' 'V1:EMIT' 'V1:HALT'; do
        printf 'Lang[lvl:1]/ATOM\t%s\n' "$(frame "$term")"
    done
    printf '%s\n' 'Lang[lvl:2]/ATOM_IS_WHOLE_L1_ATOM'
    printf 'Lang[lvl:2]/ATOM\t%s\n' "$(frame "$(frame 'V0:DRAFT')")"
    printf 'Lang[lvl:2]/ATOM\t%s\n' "$(frame "$(frame 'V1:HALT')")"
}

run() {
    printf 'KSTAR-MACHINE/1\nLEVEL\t0\tSEED\tV0:DRAFT\n'
    close 'V0:DRAFT' 8
    printf 'LEVEL\t1\tRULE\tWHOLE-L1-DRAFT-ATOM -> WHOLE-L1-HALT-ATOM\n'
    printf 'LEVEL\t1\tFROM\t%s\n' "$(frame 'V0:DRAFT')"
    printf 'LEVEL\t1\tTO\t%s\n' "$(frame 'V1:HALT')"
    printf 'LEVEL\t1\tSTATUS\tNORMAL\n'
    printf 'HIERARCHY\tLang[lvl:N] is the alphabet for Lang[lvl:N+1]\n'
}

command=${1:-run}
case $command in
    run) [ "$#" -le 1 ] || { usage >&2; exit 2; }; run ;;
    rules) [ "$#" -eq 1 ] || { usage >&2; exit 2; }; rules ;;
    languages) [ "$#" -eq 1 ] || { usage >&2; exit 2; }; languages ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
esac
