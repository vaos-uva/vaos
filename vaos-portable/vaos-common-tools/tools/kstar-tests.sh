#!/bin/sh
# POSIX-sh smoke tests for the K* kernel.
set -eu
LC_ALL=C
export LC_ALL

root=$(CDPATH= cd "$(dirname "$0")" && pwd)
work=${TMPDIR:-/tmp}/kstar-test.$$
trap 'rm -rf "$work"' 0 HUP INT TERM
mkdir -p "$work"

sh "$root/kstar.sh" demo "$work/demo" >/dev/null

# The L0 closure must have seed plus four ordered rewrites.
[ "$(wc -l < "$work/demo/Lang-lvl-1.lang" | tr -d ' ')" -eq 5 ]
# The L1 closure is the two-state level-2 rewrite orbit.
[ "$(wc -l < "$work/demo/Lang-lvl-2.lang" | tr -d ' ')" -eq 2 ]

sh "$root/kstar.sh" check "$work/demo/Lang-lvl-0.lang" "$work/demo/seed-lvl-1.word" | grep -qx 'valid'
sh "$root/kstar.sh" close "$work/demo/Lang-lvl-0.lang" "$work/demo/Rules-lvl-0.k" "$work/demo/seed-lvl-1.word" 16 | grep -q 'status=normal'

# A lift must retain closure terms from every seed, not only the final seed.
printf '%s\n%s\n' "$(cat "$work/demo/seed-lvl-1.word")" "$(tail -n 1 "$work/demo/Lang-lvl-1.lang")" > "$work/multi.seed"
sh "$root/kstar.sh" evolve "$work/demo/Lang-lvl-0.lang" "$work/demo/Rules-lvl-0.k" "$work/multi.seed" "$work/multi.lang" 16 >/dev/null
[ "$(wc -l < "$work/multi.lang" | tr -d ' ')" -eq 5 ]

# Ensure the program has no Bash-only syntax by running via /bin/sh directly.
/bin/sh "$root/kstar.sh" unpack "$work/demo/seed-lvl-2.word" | grep -q '^word 1:$'

# A non-terminating K orbit must be identified as a cycle and must not be
# materialized as a completed next language.
printf 'A\nB\n' > "$work/cycle.lang"
printf 'A\n' > "$work/a.atoms"
printf 'B\n' > "$work/b.atoms"
a=$(sh "$root/kstar.sh" pack "$work/cycle.lang" "$work/a.atoms")
b=$(sh "$root/kstar.sh" pack "$work/cycle.lang" "$work/b.atoms")
printf '%s\n' "$a" > "$work/cycle.seed"
printf '%s\t=>\t%s\n%s\t=>\t%s\n' "$a" "$b" "$b" "$a" > "$work/cycle.k"
if sh "$root/kstar.sh" close "$work/cycle.lang" "$work/cycle.k" "$work/cycle.seed" 8 > "$work/cycle.trace"; then
    printf '%s\n' 'expected cycle-producing close to fail' >&2
    exit 1
fi
grep -q 'status=cycle' "$work/cycle.trace"
if sh "$root/kstar.sh" evolve "$work/cycle.lang" "$work/cycle.k" "$work/cycle.seed" "$work/cycle-output.lang" 8; then
    printf '%s\n' 'expected cyclic evolve to refuse next-language output' >&2
    exit 1
fi
[ ! -e "$work/cycle-output.lang" ]

printf 'PASS: POSIX sh K* hierarchy and closure checks\n'
