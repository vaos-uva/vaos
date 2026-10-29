#!/bin/sh
# K* symbolic self-rewrite kernel.
# Deliberately POSIX sh: no Bash arrays, [[ ]], source, eval, or extensions.

set -eu
LC_ALL=C
export LC_ALL

PROGRAM=${0##*/}
TMP_BASE=${TMPDIR:-/tmp}/kstar.$$
TMP_INDEX=0
NEW_TMP=

cleanup() {
    rm -f "${TMP_BASE}".*
}
trap cleanup 0 HUP INT TERM

fail() {
    printf '%s: %s\n' "$PROGRAM" "$*" >&2
    exit 1
}

usage() {
    cat <<EOF_USAGE
Usage:
  sh $PROGRAM pack <language-file> <atoms-file>
  sh $PROGRAM unpack <word-file>
  sh $PROGRAM check <language-file> <words-file>
  sh $PROGRAM step <language-file> <rules-file> <word-file>
  sh $PROGRAM close <language-file> <rules-file> <seeds-file> [max-steps]
  sh $PROGRAM evolve <language-file> <rules-file> <seeds-file> <next-language-file> [max-steps]
  sh $PROGRAM demo <output-directory>

A language file contains one non-empty atomic symbol per line. A word is a
canonical concatenation of frames: <byte-length>:<atom>.  At level N + 1,
each complete line of Lang[lvl:N] is one atomic symbol.

A rule is: <packed-left><TAB>=><TAB><packed-right>
EOF_USAGE
}

require_file() {
    [ -f "$1" ] || fail "not a regular file: $1"
    [ -r "$1" ] || fail "not readable: $1"
}

new_tmp() {
    TMP_INDEX=$((TMP_INDEX + 1))
    NEW_TMP=${TMP_BASE}.${TMP_INDEX}
}

validate_language() {
    language=$1
    require_file "$language"
    awk '
        function bad(message) {
            printf "kstar: invalid language: %s (line %d)\n", message, NR > "/dev/stderr"
            exit 2
        }
        {
            if ($0 == "") bad("empty symbols are not allowed")
            if (index($0, "\t") != 0) bad("tab is reserved for the rule separator")
            if (seen[$0]++) bad("duplicate symbol")
            count++
        }
        END {
            if (NR == 0) {
                printf "kstar: invalid language: no symbols\n" > "/dev/stderr"
                exit 2
            }
        }
    ' "$language" || fail "language validation failed: $language"
}

# Pack a vertical list of already-known atoms into a canonical word.  The
# length prefix means an old word can become one new-level atom without any
# escaping or delimiter collision.
pack_word() {
    language=$1
    atoms=$2
    validate_language "$language"
    require_file "$atoms"
    awk -v language="$language" '
        function bad(message) {
            printf "kstar: pack: %s (atoms line %d)\n", message, NR > "/dev/stderr"
            failed = 1
            exit 2
        }
        BEGIN {
            while ((getline item < language) > 0) known[item] = 1
            close(language)
        }
        {
            if ($0 == "") bad("empty atoms are not allowed")
            if (!($0 in known)) bad("atom is not in the supplied language")
            result = result length($0) ":" $0
            count++
        }
        END {
            if (!failed) {
                if (count == 0) {
                    printf "kstar: pack: no atoms\n" > "/dev/stderr"
                    exit 2
                }
                print result
            }
        }
    ' "$atoms"
}

# Check that all lines in a word file are well framed words over language.
check_words() {
    language=$1
    words=$2
    validate_language "$language"
    require_file "$words"
    awk -v language="$language" '
        function die(message) {
            printf "kstar: malformed word: %s (word line %d)\n", message, NR > "/dev/stderr"
            failed = 1
            exit 2
        }
        function parse(s, a,    n,pos,start,num,needed,atom,count,ch) {
            n = length(s)
            pos = 1
            count = 0
            if (n == 0) die("empty word")
            while (pos <= n) {
                start = pos
                while (pos <= n) {
                    ch = substr(s, pos, 1)
                    if (ch < "0" || ch > "9") break
                    pos++
                }
                if (start == pos) die("frame length is missing")
                if (pos > n || substr(s, pos, 1) != ":") die("frame length lacks colon")
                num = substr(s, start, pos - start)
                if (length(num) > 1 && substr(num, 1, 1) == "0") die("non-canonical leading zero")
                needed = num + 0
                if (needed < 1) die("empty atoms are not supported")
                pos++
                if (pos + needed - 1 > n) die("frame extends beyond word")
                atom = substr(s, pos, needed)
                a[++count] = atom
                pos += needed
            }
            return count
        }
        BEGIN {
            while ((getline item < language) > 0) known[item] = 1
            close(language)
        }
        {
            for (i in atom) delete atom[i]
            amount = parse($0, atom)
            for (i = 1; i <= amount; i++) {
                if (!(atom[i] in known)) die("atom is outside the supplied language")
            }
            words_seen++
        }
        END {
            if (!failed && words_seen == 0) {
                printf "kstar: malformed word: no words\n" > "/dev/stderr"
                exit 2
            }
        }
    ' "$words" || fail "word validation failed: $words"
}

unpack_words() {
    words=$1
    require_file "$words"
    awk '
        function die(message) {
            printf "kstar: unpack: %s (word line %d)\n", message, NR > "/dev/stderr"
            failed = 1
            exit 2
        }
        function parse(s, a,    n,pos,start,num,needed,atom,count,ch) {
            n = length(s); pos = 1; count = 0
            if (n == 0) die("empty word")
            while (pos <= n) {
                start = pos
                while (pos <= n) {
                    ch = substr(s, pos, 1)
                    if (ch < "0" || ch > "9") break
                    pos++
                }
                if (start == pos || pos > n || substr(s, pos, 1) != ":") die("bad frame header")
                num = substr(s, start, pos - start)
                if (length(num) > 1 && substr(num, 1, 1) == "0") die("non-canonical frame length")
                needed = num + 0
                if (needed < 1) die("empty atom")
                pos++
                if (pos + needed - 1 > n) die("truncated frame")
                atom = substr(s, pos, needed)
                a[++count] = atom
                pos += needed
            }
            return count
        }
        {
            for (i in atom) delete atom[i]
            amount = parse($0, atom)
            printf "word %d:\n", NR
            for (i = 1; i <= amount; i++) printf "  %d. %s\n", i, atom[i]
        }
    ' "$words"
}

# A single deterministic K application.  The first rule in file order whose
# left side matches at the leftmost possible term position wins.  It prints
# the resulting packed word and exits 10 on a rewrite, 0 at normal form.
step_once() {
    language=$1
    rules=$2
    word=$3
    require_file "$rules"
    printf '%s\n' "$word" | awk -v language="$language" -v rules="$rules" '
        function die(message) {
            printf "kstar: rule/kernel error: %s\n", message > "/dev/stderr"
            failed = 1
            exit 2
        }
        function parse(s, a,    n,pos,start,num,needed,atom,count,ch) {
            n = length(s); pos = 1; count = 0
            if (n == 0) die("empty packed term")
            while (pos <= n) {
                start = pos
                while (pos <= n) {
                    ch = substr(s, pos, 1)
                    if (ch < "0" || ch > "9") break
                    pos++
                }
                if (start == pos || pos > n || substr(s, pos, 1) != ":") die("bad frame header")
                num = substr(s, start, pos - start)
                if (length(num) > 1 && substr(num, 1, 1) == "0") die("non-canonical frame length")
                needed = num + 0
                if (needed < 1) die("empty atoms are not supported")
                pos++
                if (pos + needed - 1 > n) die("truncated packed term")
                atom = substr(s, pos, needed)
                if (!(atom in known)) die("atom outside current language")
                a[++count] = atom
                pos += needed
            }
            return count
        }
        function encode(atom) {
            return length(atom) ":" atom
        }
        BEGIN {
            while ((getline item < language) > 0) known[item] = 1
            close(language)

            while ((getline line < rules) > 0) {
                rule_line++
                if (line == "" || substr(line, 1, 1) == "#") continue
                split_at = index(line, "\t=>\t")
                if (split_at == 0) die("rule " rule_line " must use TAB => TAB")
                if (index(substr(line, split_at + 4), "\t=>\t") != 0) die("rule " rule_line " has multiple separators")
                left = substr(line, 1, split_at - 1)
                right = substr(line, split_at + 4)
                if (left == "" || right == "") die("rule " rule_line " has an empty side")

                for (i in scratch) delete scratch[i]
                left_count = parse(left, scratch)
                rule_count++
                left_size[rule_count] = left_count
                for (i = 1; i <= left_count; i++) left_atom[rule_count, i] = scratch[i]

                for (i in scratch) delete scratch[i]
                right_count = parse(right, scratch)
                right_size[rule_count] = right_count
                for (i = 1; i <= right_count; i++) right_atom[rule_count, i] = scratch[i]
            }
            close(rules)
            if (rule_count == 0) die("no executable rules")
        }
        {
            if (input_seen++) die("step expects exactly one word")
            for (i in term) delete term[i]
            term_size = parse($0, term)
            for (r = 1; r <= rule_count; r++) {
                if (left_size[r] > term_size) continue
                for (at = 1; at <= term_size - left_size[r] + 1; at++) {
                    matches = 1
                    for (j = 1; j <= left_size[r]; j++) {
                        if (term[at + j - 1] != left_atom[r, j]) {
                            matches = 0
                            break
                        }
                    }
                    if (matches) {
                        result = ""
                        for (j = 1; j < at; j++) result = result encode(term[j])
                        for (j = 1; j <= right_size[r]; j++) result = result encode(right_atom[r, j])
                        for (j = at + left_size[r]; j <= term_size; j++) result = result encode(term[j])
                        print result
                        exit 10
                    }
                }
            }
            print $0
            exit 0
        }
        END {
            if (!failed && input_seen != 1) die("step expects one input word")
        }
    '
}

# Emit the trace of K*.  A non-normal terminal state (cycle or fuel) gives a
# nonzero result, so callers cannot mistake a truncated orbit for a language.
close_words() {
    language=$1
    rules=$2
    seeds=$3
    limit=${4:-32}

    validate_language "$language"
    require_file "$rules"
    check_words "$language" "$seeds"
    case $limit in
        ''|*[!0-9]*) fail "max-steps must be a positive integer" ;;
    esac
    [ "$limit" -gt 0 ] || fail "max-steps must be greater than zero"

    seed_number=0
    status=0
    while IFS= read -r current || [ -n "$current" ]; do
        seed_number=$((seed_number + 1))
        step_number=0
        new_tmp
        seen=$NEW_TMP
        : > "$seen"
        printf '%s\n' "$current" >> "$seen"
        printf 'seed=%s\tstep=%s\tstatus=seed\tword=%s\n' "$seed_number" "$step_number" "$current"

        while [ "$step_number" -lt "$limit" ]; do
            if next=$(step_once "$language" "$rules" "$current"); then
                printf 'seed=%s\tstep=%s\tstatus=normal\tword=%s\n' "$seed_number" "$step_number" "$next"
                break
            else
                code=$?
                [ "$code" -eq 10 ] || fail "K kernel failed while processing seed $seed_number"
            fi
            step_number=$((step_number + 1))
            current=$next
            if grep -F -x -e "$current" "$seen" >/dev/null 2>&1; then
                printf 'seed=%s\tstep=%s\tstatus=cycle\tword=%s\n' "$seed_number" "$step_number" "$current"
                status=1
                break
            fi
            printf '%s\n' "$current" >> "$seen"
            printf 'seed=%s\tstep=%s\tstatus=rewrite\tword=%s\n' "$seed_number" "$step_number" "$current"
        done
        if [ "$step_number" -ge "$limit" ]; then
            # If the loop stopped exactly at the fuel boundary, determine
            # whether that word is already normal before declaring fuel used.
            if next=$(step_once "$language" "$rules" "$current"); then
                printf 'seed=%s\tstep=%s\tstatus=normal\tword=%s\n' "$seed_number" "$step_number" "$next"
            else
                code=$?
                [ "$code" -eq 10 ] || fail "K kernel failed at fuel boundary"
                printf 'seed=%s\tstep=%s\tstatus=fuel\tword=%s\n' "$seed_number" "$step_number" "$current"
                status=1
            fi
        fi
    done < "$seeds"
    return "$status"
}

append_unique() {
    item=$1
    destination=$2
    if [ ! -s "$destination" ] || ! grep -F -x -e "$item" "$destination" >/dev/null 2>&1; then
        printf '%s\n' "$item" >> "$destination"
    fi
}

# Lift a closure to the next language.  Every reached packed word becomes one
# atomic line of Lang[lvl:N+1], therefore exactly the alphabet for level N+2.
evolve_language() {
    language=$1
    rules=$2
    seeds=$3
    output=$4
    limit=${5:-32}

    validate_language "$language"
    require_file "$rules"
    check_words "$language" "$seeds"
    case $limit in
        ''|*[!0-9]*) fail "max-steps must be a positive integer" ;;
    esac
    [ "$limit" -gt 0 ] || fail "max-steps must be greater than zero"

    [ ! -e "$output" ] || fail "refusing to overwrite existing output: $output"
    new_tmp
    collected=$NEW_TMP
    : > "$collected"
    seed_number=0

    while IFS= read -r current || [ -n "$current" ]; do
        seed_number=$((seed_number + 1))
        step_number=0
        new_tmp
        seen=$NEW_TMP
        : > "$seen"
        printf '%s\n' "$current" >> "$seen"
        append_unique "$current" "$collected"

        while [ "$step_number" -lt "$limit" ]; do
            if next=$(step_once "$language" "$rules" "$current"); then
                break
            else
                code=$?
                [ "$code" -eq 10 ] || fail "K kernel failed while evolving seed $seed_number"
            fi
            step_number=$((step_number + 1))
            current=$next
            if grep -F -x -e "$current" "$seen" >/dev/null 2>&1; then
                fail "cycle found while evolving seed $seed_number; no next language emitted"
            fi
            printf '%s\n' "$current" >> "$seen"
            append_unique "$current" "$collected"
        done
        if [ "$step_number" -ge "$limit" ]; then
            if next=$(step_once "$language" "$rules" "$current"); then
                :
            else
                code=$?
                [ "$code" -eq 10 ] || fail "K kernel failed at fuel boundary"
                fail "fuel exhausted while evolving seed $seed_number; no next language emitted"
            fi
        fi
    done < "$seeds"

    [ -s "$collected" ] || fail "no terms collected for next language"
    mv "$collected" "$output"
}

make_demo() {
    out=$1
    [ ! -e "$out" ] || fail "demo output path already exists: $out"
    mkdir -p "$out"

    cat > "$out/Lang-lvl-0.lang" <<'EOF_L0'
K
:
SELF
RULES
v0
v1
STATE
DRAFT
CHECK
EMIT
HALT
EOF_L0

    cat > "$out/seed-lvl-1.atoms" <<'EOF_SEED'
K
:
SELF
:
RULES
:
v0
K
:
STATE
:
DRAFT
EOF_SEED
    pack_word "$out/Lang-lvl-0.lang" "$out/seed-lvl-1.atoms" > "$out/seed-lvl-1.word"

    cat > "$out/self-v0.atoms" <<'EOF_V0'
K
:
SELF
:
RULES
:
v0
EOF_V0
    cat > "$out/self-v1.atoms" <<'EOF_V1'
K
:
SELF
:
RULES
:
v1
EOF_V1
    cat > "$out/state-draft.atoms" <<'EOF_DRAFT'
K
:
STATE
:
DRAFT
EOF_DRAFT
    cat > "$out/state-check.atoms" <<'EOF_CHECK'
K
:
STATE
:
CHECK
EOF_CHECK
    cat > "$out/state-emit.atoms" <<'EOF_EMIT'
K
:
STATE
:
EMIT
EOF_EMIT
    cat > "$out/state-halt.atoms" <<'EOF_HALT'
K
:
STATE
:
HALT
EOF_HALT

    self_v0=$(pack_word "$out/Lang-lvl-0.lang" "$out/self-v0.atoms")
    self_v1=$(pack_word "$out/Lang-lvl-0.lang" "$out/self-v1.atoms")
    state_draft=$(pack_word "$out/Lang-lvl-0.lang" "$out/state-draft.atoms")
    state_check=$(pack_word "$out/Lang-lvl-0.lang" "$out/state-check.atoms")
    state_emit=$(pack_word "$out/Lang-lvl-0.lang" "$out/state-emit.atoms")
    state_halt=$(pack_word "$out/Lang-lvl-0.lang" "$out/state-halt.atoms")

    # Rules are word rewrites over Lang[lvl:0].  TAB is intentionally the
    # meta-level separator; it is not part of the symbolic language.
    {
        printf '%s\t=>\t%s\n' "$self_v0" "$self_v1"
        printf '%s\t=>\t%s\n' "$state_draft" "$state_check"
        printf '%s\t=>\t%s\n' "$state_check" "$state_emit"
        printf '%s\t=>\t%s\n' "$state_emit" "$state_halt"
    } > "$out/Rules-lvl-0.k"

    close_words "$out/Lang-lvl-0.lang" "$out/Rules-lvl-0.k" "$out/seed-lvl-1.word" 16 > "$out/trace-lvl-1.tsv"
    evolve_language "$out/Lang-lvl-0.lang" "$out/Rules-lvl-0.k" "$out/seed-lvl-1.word" "$out/Lang-lvl-1.lang" 16

    # A level-2 word uses the complete level-1 self-description as *one* atom.
    printf '%s\n' "$(sed -n '1p' "$out/Lang-lvl-1.lang")" > "$out/seed-lvl-2.atoms"
    pack_word "$out/Lang-lvl-1.lang" "$out/seed-lvl-2.atoms" > "$out/seed-lvl-2.word"

    # The first and last closure terms are respectively the draft description
    # and its stable, halted self-description.  At level 2 they are atomic.
    level1_first=$(sed -n '1p' "$out/Lang-lvl-1.lang")
    level1_last=$(sed -n '$p' "$out/Lang-lvl-1.lang")
    printf '%s\n' "$level1_last" > "$out/normal-lvl-2.atoms"
    pack_word "$out/Lang-lvl-1.lang" "$out/normal-lvl-2.atoms" > "$out/normal-lvl-2.word"
    printf '%s\t=>\t%s\n' "$(cat "$out/seed-lvl-2.word")" "$(cat "$out/normal-lvl-2.word")" > "$out/Rules-lvl-1.k"

    close_words "$out/Lang-lvl-1.lang" "$out/Rules-lvl-1.k" "$out/seed-lvl-2.word" 8 > "$out/trace-lvl-2.tsv"
    evolve_language "$out/Lang-lvl-1.lang" "$out/Rules-lvl-1.k" "$out/seed-lvl-2.word" "$out/Lang-lvl-2.lang" 8

    {
        cat <<'EOF_DEMO'
# K* generated example

`Lang[lvl:0]` is the raw symbol inventory. `Rules-lvl-0.k` transforms a
level-1 word that says `K : SELF : RULES : v0 K : STATE : DRAFT` into a stable
self-description at `v1` with state `HALT`.

`Lang[lvl:1]` is the entire K* orbit, one packed word per line. Therefore each
of its complete lines is an atomic alphabet symbol for level 2. The level-2
rule changes the first level-1 description atom into the final stable
level-1 description atom. This is the hierarchy in executable form:

    Lang[lvl:N]  = alphabet for Lang[lvl:N+1]

The `.word` and `.k` files are framed machine notation. Use `unpack` to view
one structural layer; repeated `unpack` peels nested levels.

## Level-1 trace

```text
EOF_DEMO
        cat "$out/trace-lvl-1.tsv"
        cat <<'EOF_RENDER'
```

## Seed, unpacked at level 1

```text
EOF_RENDER
        unpack_words "$out/seed-lvl-1.word"
        cat <<'EOF_RENDER2'
```

## Seed, unpacked at level 2

```text
EOF_RENDER2
        unpack_words "$out/seed-lvl-2.word"
        cat <<'EOF_RENDER3'
```
EOF_RENDER3
    } > "$out/README.md"

    # Keep the variables referenced above intentional: they document that the
    # L1 endpoints have been calculated before the L2 lift.
    : "$level1_first" "$level1_last"
    printf 'Created K* demo in %s\n' "$out"
}

command_name=${1:-}
case $command_name in
    pack)
        [ "$#" -eq 3 ] || { usage >&2; exit 1; }
        pack_word "$2" "$3"
        ;;
    unpack)
        [ "$#" -eq 2 ] || { usage >&2; exit 1; }
        unpack_words "$2"
        ;;
    check)
        [ "$#" -eq 3 ] || { usage >&2; exit 1; }
        check_words "$2" "$3"
        printf 'valid\n'
        ;;
    step)
        [ "$#" -eq 4 ] || { usage >&2; exit 1; }
        validate_language "$2"
        check_words "$2" "$4"
        [ "$(wc -l < "$4" | tr -d ' ')" -eq 1 ] || fail "step requires a file containing exactly one word"
        word=$(cat "$4")
        if result=$(step_once "$2" "$3" "$word"); then
            printf 'status=normal\tword=%s\n' "$result"
        else
            code=$?
            [ "$code" -eq 10 ] || fail "K kernel failed"
            printf 'status=rewrite\tword=%s\n' "$result"
        fi
        ;;
    close)
        [ "$#" -eq 4 ] || [ "$#" -eq 5 ] || { usage >&2; exit 1; }
        close_words "$2" "$3" "$4" "${5:-32}"
        ;;
    evolve)
        [ "$#" -eq 5 ] || [ "$#" -eq 6 ] || { usage >&2; exit 1; }
        evolve_language "$2" "$3" "$4" "$5" "${6:-32}"
        printf 'created %s\n' "$5"
        ;;
    demo)
        [ "$#" -eq 2 ] || { usage >&2; exit 1; }
        make_demo "$2"
        ;;
    -h|--help|help|'')
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
