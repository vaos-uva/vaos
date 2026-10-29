#!/bin/sh
# ident: glagol.parser
# category: tool
# purpose: parse-and-scaffold
# role: parser-and-template-processor
# semantic: implementation
# universe: vaos
# vaos-id: VAOS.GlaGol.Parser.001
# brand: OZCO
# layer: TASK
# base-axis: Execution
# time-axis: RunTime
# purpose-axis: Knowlege
# source-rules: https://github.com/vaos-uva/architecture-models-atlas/blob/main/AGENTS.md
# source-manifest: https://github.com/vaos-uva/vaos/blob/main/vaos-portable/vaos-manifest.yaml
# GlaGol: line-oriented parser and symbolic unit builder.
# POSIX sh + POSIX awk only; no Bash syntax, eval, or runtime SymPy dependency.
#
# Concrete syntax:
#   : Name := A | B            definition with alternatives
#   : Name : Type              typed declaration
#   :directive ...             directive
#   = equation / | continuation operation
#   name <- value              binding
#   # comment / -- comment     ignored
#
# Machine records are tab-separated. Indentation uses pairs of spaces.
# Higher-level combinator terms use RPN tokens: I, K, S, APP, and @N atom refs.
# K* is leftmost-outermost repeated SKI reduction to normal form.
# portable-scaffold: vaos-shell-tool-v1
# scaffold-signature: artifact-name,unit-id,message
# scaffold-location: embedded-portable-registry-in-this-file

set -eu
LC_ALL=C
export LC_ALL
PROGRAM=${0##*/}
ACTIVE_TMP=
ACTIVE_DIR=

cleanup() {
    [ -z "$ACTIVE_TMP" ] || rm -f "$ACTIVE_TMP"
    [ -z "$ACTIVE_DIR" ] || rm -rf "$ACTIVE_DIR"
}
trap cleanup 0 HUP INT TERM

usage() {
    cat <<EOF_USAGE
Usage:
  sh $PROGRAM [parse|classify|tokens] [file]
  sh $PROGRAM lift <Lang-N> <Lang-N+1>
  sh $PROGRAM metastep <Lang-N> <term-file>
  sh $PROGRAM metaclose <Lang-N> <term-file> [max-steps]
  sh $PROGRAM scaffolds
  sh $PROGRAM scaffold <template-id> <artifact-name> <unit-id> <message> <output.sh>
  sh $PROGRAM use-scaffold <template-id> <artifact-name> <unit-id> <message> <output.sh>
  sh $PROGRAM selfhost <level-2-script.sh>
  sh $PROGRAM selftest

M2M help scaffold example:
  sh $PROGRAM scaffold m2m-dev-root-cli-v1 m2m-dev-root-cli VAOS.M2M.DevRoot.001 'M2M-DEV-ROOT Development CLI' ./m2m-dev-root.sh

parse     parse file or stdin into machine-readable GlaGol records (default)
classify  report line number, indentation, type, and original content
tokens    emit a simple token stream
selftest  run built-in tests against the Nat example
lift      make each whole Lang[lvl:N] member one framed Lang[lvl:N+1] atom
metastep  apply one leftmost-outermost SKI combinator rewrite
metaclose compute K* closure until normal form (cycle/fuel is an error)
selfhost  lift a seeded script to level 2, normalize its atom refs, write, check, and execute it
scaffolds list the registered portable scaffold templates
scaffold  render a registered template into a new POSIX shell tool
use-scaffold alias for scaffold; always binds explicit template parameters
M2M markers classify @ patterns, ! instructions/sections, and $ variables.

Definition lines begin ': Name :='. Body alternatives split on '|'. Following
'=' or '|' lines attach as operations until a new top-level unit begins.
Combinator terms are one RPN expression per line. APP applies the preceding
two stack terms; @N refers to zero-based atom N in the selected Lang file.
Examples: 'I @0 APP', 'K @0 APP @1 APP', 'S @0 APP @1 APP @2 APP'.
K* repeatedly applies I x=x, K x y=x, and S f g x=f x (g x) to normal form.
EOF_USAGE
}

run_engine() {
    mode=$1
    input=${2:--}
    if [ "$input" != "-" ]; then
        [ -r "$input" ] || {
            printf '%s: not readable: %s\n' "$PROGRAM" "$input" >&2
            return 2
        }
    fi

    # awk treats '-' as standard input on POSIX implementations commonly in
    # use; both file and stdin inputs pass through this single parser engine.
    awk -v mode="$mode" '
        function trim(s) {
            sub(/^[ \t\r]+/, "", s)
            sub(/[ \t\r]+$/, "", s)
            return s
        }
        function classify(raw, s) {
            s = trim(raw)
            if (s == "") return "Empty"
            if (s ~ /^#/ || s ~ /^--/) return "Comment"
            if (s == "@ patterns:") return "PatternRegistry"
            if (s ~ /^@[ \t]*:[ \t]*[A-Za-z_][A-Za-z0-9_]*([ \t]*,[ \t]*[A-Za-z_][A-Za-z0-9_]*)*$/) return "Pattern"
            if (s ~ /^![ \t]*:[ \t]*/) return "InstructionPattern"
            if (s ~ /^![ \t]*[A-Za-z_][A-Za-z0-9_-]*:[ \t]*$/) return "InstructionSection"
            if (s ~ /^![ \t]*/) return "Instruction"
            if (s ~ /^\$[ \t]*(vars|[A-Za-z_][A-Za-z0-9_]*)[ \t]*$/) return "VariablePattern"
            if (s ~ /^:[ \t]*\$\{[A-Za-z_][A-Za-z0-9_]*\}/) return "TemplateHeader"
            if (s ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*\}/) return "TemplateContent"
            if (s ~ /^:[ \t]*[^:]+[ \t]*:=/) return "Definition"
            if (s ~ /^:[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*:[^=]/) return "Declaration"
            if (s ~ /^:/) return "Directive"
            if (s ~ /^[=|]/) return "Operation"
            if (index(s, "<-") || index(s, "←") || index(s, ":=")) return "Binding"
            return "Declaration"
        }
        function scaffold_type(type) {
            return type == "PatternRegistry" || type == "Pattern" || \
                   type == "InstructionPattern" || type == "InstructionSection" || \
                   type == "Instruction" || type == "VariablePattern" || \
                   type == "TemplateHeader" || type == "TemplateContent"
        }
        function scaffold_unit_type(type) {
            if (type == "PatternRegistry") return "ScaffoldPatternRegistryUnit"
            if (type == "Pattern") return "ScaffoldPatternUnit"
            if (type == "InstructionPattern") return "ScaffoldInstructionPatternUnit"
            if (type == "InstructionSection") return "ScaffoldInstructionSectionUnit"
            if (type == "Instruction") return "ScaffoldInstructionUnit"
            if (type == "VariablePattern") return "ScaffoldVariablePatternUnit"
            if (type == "TemplateHeader") return "ScaffoldTemplateHeaderUnit"
            return "ScaffoldTemplateContentUnit"
        }
        function indentation(raw,    s,n) {
            s = raw
            sub(/[^ ].*$/, "", s)
            n = length(s)
            if (n % 2 != 0) {
                printf "GlaGol: line %d: indentation must use pairs of spaces\n", NR > "/dev/stderr"
                failed = 1
                return -1
            }
            return n / 2
        }
        function store(key, value,    old,newsize) {
            old = memory[key]
            memory_used -= length(key) + length(old)
            newsize = length(key) + length(value)
            if (memory_used + newsize > memory_capacity) {
                printf "GlaGol: memory capacity exceeded storing '%s'\n", key > "/dev/stderr"
                failed = 1
                return 0
            }
            memory[key] = value
            memory_used += newsize
            return 1
        }
        function add_source(line_no, raw) {
            raw_count++
            source_line[raw_count] = line_no
            source_text[raw_count] = raw
        }
        function add_alternatives(text,    n,a,i,item) {
            n = split(text, a, /[|]/)
            for (i = 1; i <= n; i++) {
                item = trim(a[i])
                if (item != "") body[++body_count] = item
            }
        }
        function emit_unit(    i,summary,unit_id) {
            if (!active) return
            unit_sequence++
            unit_id = sprintf("VAOS.GlaGol.Parser.Unit.%03d", unit_sequence)
            printf "UNIT\tBEGIN\t%s\t%s\tID\t%s\tLINE\t%d\n", unit_type, unit_name, unit_id, unit_line
            for (i = 1; i <= body_count; i++) printf "BODY\t%s\n", body[i]
            for (i = 1; i <= operation_count; i++) printf "OPERATION\t%s\n", operations[i]
            for (i = 1; i <= binding_count; i++) printf "BINDING\t%s\n", bindings[i]
            for (i = 1; i <= source_count; i++) printf "SOURCE\t%d\t%s\n", source_line[i], source_text[i]
            printf "UNIT\tEND\n"
            summary = unit_type ":" unit_name ":" unit_line
            store("last_unit", summary)
            active = 0
            body_count = operation_count = binding_count = source_count = 0
        }
        function start_unit(kind, name, line_no, raw) {
            emit_unit()
            active = 1
            unit_type = kind
            unit_name = name
            unit_line = line_no
            source_count++
            source_line[source_count] = line_no
            source_text[source_count] = raw
        }
        function tokenize(raw,    s,n,a,i,t) {
            s = raw
            gsub(/:=/, " __OP_DEFINE__ ", s)
            gsub(/<-/, " __OP_BIND__ ", s)
            gsub(/←/, " __OP_BIND__ ", s)
            gsub(/([@!$])/, " & ", s)
            gsub(/([()|,:=])/, " & ", s)
            n = split(s, a, /[ \t]+/)
            for (i = 1; i <= n; i++) {
                t = a[i]
                if (t == "") continue
                if (t == "__OP_DEFINE__") t = ":="
                else if (t == "__OP_BIND__") t = "<-"
                printf "TOKEN\t%d\t%s\n", NR, t
            }
        }
        BEGIN {
            memory_capacity = 2048
            memory_used = 0
            root_spec = "RootUnit/1.0.0;memory=2048;parser=9;processor=8;builder=1"
            if (mode == "parse") {
                printf "ROOT\troot\tID\tVAOS.GlaGol.Root.001\tPHASE\tinit\tSTATUS\tready\n"
                printf "GOVERNANCE\tBRAND\tOZCO\tLAYER\tTASK\tBASE_AXIS\tExecution\tTIME_AXIS\tRunTime\tPURPOSE_AXIS\tKnowlege\n"
                printf "COMPONENT\tmemory\tID\tVAOS.GlaGol.Memory.001\tCAPACITY\t2048\n"
                printf "COMPONENT\tparser\tID\tVAOS.GlaGol.ParserComponent.001\tRULES\t9\n"
                printf "COMPONENT\tprocessor\tID\tVAOS.GlaGol.Processor.001\tREGISTERS\t8\n"
                printf "COMPONENT\tbuilder\tID\tVAOS.GlaGol.Builder.001\tUNITS\t1\n"
                if (store("root_spec", root_spec)) printf "STORE\troot_spec\t%s\n", root_spec
            }
        }
        {
            raw = $0
            type = classify(raw)
            indent = indentation(raw)
            if (indent < 0) next

            if (mode == "classify") {
                printf "LINE\t%d\tINDENT\t%d\tTYPE\t%s\tCONTENT\t%s\n", NR, indent, type, raw
                next
            }
            if (mode == "tokens") {
                tokenize(raw)
                next
            }
            if (type == "Empty") {
                printf "MATCH\t%d\tRule_Empty\tACTION\tCLEAR_CURRENT_LINE\n", NR
                next
            }
            if (type == "Comment") {
                printf "MATCH\t%d\tRule_Comment\tACTION\tSTORE_COMMENT\n", NR
                next
            }

            # Dedent closes an active unit only when indentation decreases.
            # Equal-indent operation clauses remain part of the same unit.
            if (active && indent < previous_indent) {
                printf "MATCH\t%d\tRule_Dedent\tACTION\tFLUSH_AND_EMIT\n", NR
                emit_unit()
            }

            if (type == "Definition") {
                printf "MATCH\t%d\tRule_Definition\tACTION\tCLEAR_AND_START_DEFINITION\n", NR
                s = trim(raw)
                sub(/^:[ \t]*/, "", s)
                sub(/[ \t]*:=.*/, "", s)
                name = trim(s)
                if (name == "") {
                    printf "GlaGol: line %d: empty definition name\n", NR > "/dev/stderr"
                    failed = 1
                    next
                }
                start_unit("DefinitionUnit", name, NR, raw)
                s = raw
                sub(/^.*:=/, "", s)
                add_alternatives(s)
                previous_indent = indent
                next
            }

            if (type == "Declaration" || scaffold_type(type)) {
                printf "MATCH\t%d\tRule_Accumulate\tACTION\tACCUMULATE_DECLARATION\n", NR
                s = trim(raw)
                if (scaffold_type(type)) {
                    start_unit(scaffold_unit_type(type), s, NR, raw)
                    body[++body_count] = s
                    previous_indent = indent
                    next
                }
                sub(/^:[ \t]*/, "", s)
                split(s, pieces, /[ \t:]+/)
                name = pieces[1]
                rest = s
                sub(/^[^:]*:[ \t]*/, "", rest)
                start_unit("DeclarationUnit", name, NR, raw)
                if (trim(rest) != "") body[++body_count] = trim(rest)
                previous_indent = indent
                next
            }

            if (type == "Directive") {
                printf "MATCH\t%d\tRule_Directive\tACTION\tFLUSH_AND_STORE_DIRECTIVE\n", NR
                emit_unit()
                printf "DIRECTIVE\t%d\t%s\n", NR, trim(raw)
                previous_indent = indent
                next
            }

            if (type == "Operation") {
                if (indent > previous_indent)
                    printf "MATCH\t%d\tRule_Nested\tACTION\tENTER_SCOPE_AND_ACCUMULATE\n", NR
                else
                    printf "MATCH\t%d\tRule_Operation\tACTION\tSTORE_AND_PARSE_OPERATION\n", NR
                if (!active) start_unit("OperationUnit", "", NR, raw)
                else {
                    source_count++
                    source_line[source_count] = NR
                    source_text[source_count] = raw
                }
                s = trim(raw)
                sub(/^[=|][ \t]*/, "", s)
                operations[++operation_count] = s
                previous_indent = indent
                next
            }

            if (type == "Binding") {
                printf "MATCH\t%d\tRule_Binding\tACTION\tSTORE_AND_PARSE_BINDING\n", NR
                if (!active) start_unit("BindingUnit", "", NR, raw)
                else {
                    source_count++
                    source_line[source_count] = NR
                    source_text[source_count] = raw
                }
                bindings[++binding_count] = trim(raw)
                previous_indent = indent
                next
            }
        }
        END {
            if (mode == "parse") {
                emit_unit()
                printf "MEMORY\tUSED\t%d\tCAPACITY\t%d\n", memory_used, memory_capacity
            }
            if (failed) exit 2
        }
    ' "$input"
}

lift_language() {
    source_lang=$1
    target_lang=$2
    [ -r "$source_lang" ] || { printf '%s: not readable: %s\n' "$PROGRAM" "$source_lang" >&2; return 2; }
    [ ! -e "$target_lang" ] || { printf '%s: refusing to overwrite: %s\n' "$PROGRAM" "$target_lang" >&2; return 2; }
    ACTIVE_TMP=${target_lang}.tmp.$$
    [ ! -e "$ACTIVE_TMP" ] || { printf '%s: temporary path exists: %s\n' "$PROGRAM" "$ACTIVE_TMP" >&2; ACTIVE_TMP=; return 2; }
    awk '
        {
            if ($0 == "") {
                printf "GlaGol: empty symbols cannot be lifted (line %d)\n", NR > "/dev/stderr"
                failed = 1
                next
            }
            if (seen[$0]++) {
                printf "GlaGol: duplicate symbol cannot be lifted (line %d)\n", NR > "/dev/stderr"
                failed = 1
                next
            }
            # LC_ALL=C makes length() a byte count, matching the frame format.
            printf "%d:%s\n", length($0), $0
            count++
        }
        END {
            if (count == 0) {
                printf "GlaGol: cannot lift an empty language\n" > "/dev/stderr"
                failed = 1
            }
            if (failed) exit 2
        }
    ' "$source_lang" > "$ACTIVE_TMP" || { rm -f "$ACTIVE_TMP"; ACTIVE_TMP=; return 2; }
    if ! ln "$ACTIVE_TMP" "$target_lang" 2>/dev/null; then
        printf '%s: cannot create target without overwrite: %s\n' "$PROGRAM" "$target_lang" >&2
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    fi
    rm -f "$ACTIVE_TMP"
    ACTIVE_TMP=
    printf 'UNIT\tVAOS.GlaGol.Meta.Lift.001\tOperation\tLangLift\tFrom\t%s\tTo\t%s\tStatus\tcompleted\n' "$source_lang" "$target_lang"
}

run_combinator() {
    mode=$1
    language=$2
    terms=$3
    fuel=${4:-64}
    [ -r "$language" ] || { printf '%s: not readable: %s\n' "$PROGRAM" "$language" >&2; return 2; }
    [ -r "$terms" ] || { printf '%s: not readable: %s\n' "$PROGRAM" "$terms" >&2; return 2; }
    case $fuel in ''|*[!0-9]*) printf '%s: max-steps must be a positive integer\n' "$PROGRAM" >&2; return 2 ;; esac
    [ "$fuel" -gt 0 ] || { printf '%s: max-steps must be positive\n' "$PROGRAM" >&2; return 2; }

    awk -v mode="$mode" -v language="$language" -v fuel="$fuel" '
        function make_atom(value,    id) {
            id = ++node_count
            kind[id] = "atom"
            value_of[id] = value
            return id
        }
        function make_app(left, right,    id) {
            id = ++node_count
            kind[id] = "app"
            left_of[id] = left
            right_of[id] = right
            return id
        }
        function serialize(id) {
            if (kind[id] == "atom") return value_of[id]
            return serialize(left_of[id]) " " serialize(right_of[id]) " APP"
        }
        function parse_rpn(line,    count,tokens,i,token,index_num,left,right,id) {
            node_count = 0
            stack_count = 0
            count = split(line, tokens, /[ \t]+/)
            for (i = 1; i <= count; i++) {
                token = tokens[i]
                if (token == "") continue
                if (token == "APP") {
                    if (stack_count < 2) {
                        parse_error = "APP requires two stack operands"
                        return 0
                    }
                    right = stack[stack_count--]
                    left = stack[stack_count--]
                    stack[++stack_count] = make_app(left, right)
                } else if (token == "I" || token == "K" || token == "S") {
                    stack[++stack_count] = make_atom(token)
                } else if (token ~ /^@[0-9]+$/) {
                    index_num = substr(token, 2) + 0
                    if (index_num >= alphabet_count) {
                        parse_error = "atom reference outside Lang alphabet: " token
                        return 0
                    }
                    stack[++stack_count] = make_atom(token)
                } else {
                    parse_error = "invalid RPN token: " token
                    return 0
                }
            }
            if (stack_count != 1) {
                parse_error = "term must reduce to exactly one RPN stack item"
                return 0
            }
            return stack[1]
        }
        function contract(id,    cursor,head,n,i,j,arity,result,extra) {
            n = 0
            cursor = id
            while (kind[cursor] == "app") {
                reversed[++n] = right_of[cursor]
                cursor = left_of[cursor]
            }
            head = cursor
            if (kind[head] != "atom") return 0
            for (i = 1; i <= n; i++) argument[i] = reversed[n - i + 1]
            combinator = value_of[head]
            if (combinator == "I" && n >= 1) {
                arity = 1
                result = argument[1]
            } else if (combinator == "K" && n >= 2) {
                arity = 2
                result = argument[1]
            } else if (combinator == "S" && n >= 3) {
                arity = 3
                result = make_app(make_app(argument[1], argument[3]), make_app(argument[2], argument[3]))
            } else return 0
            for (j = arity + 1; j <= n; j++) result = make_app(result, argument[j])
            return result
        }
        function reduce_once(id,    root_result,reduced) {
            if (kind[id] != "app") return id
            root_result = contract(id)
            if (root_result != 0) {
                changed = 1
                return root_result
            }
            reduced = reduce_once(left_of[id])
            if (changed) return make_app(reduced, right_of[id])
            reduced = reduce_once(right_of[id])
            if (changed) return make_app(left_of[id], reduced)
            return id
        }
        function seen_before(term,    i) {
            for (i = 1; i <= history_count; i++) if (history[i] == term) return 1
            return 0
        }
        function process_seed(line,    root,current,next_term,step,seed_id,unit_id) {
            parse_error = ""
            root = parse_rpn(line)
            if (!root) {
                printf "GlaGol: term line %d: %s\n", NR, parse_error > "/dev/stderr"
                failed = 1
                return
            }
            current = serialize(root)
            if (mode == "metastep") {
                changed = 0
                root = reduce_once(root)
                unit_id = sprintf("VAOS.GlaGol.Meta.Step.%03d", ++meta_step_sequence)
                if (changed) printf "UNIT\t%s\tOperation\tSKIReduce\tFrom\t%s\tTo\t%s\tStatus\trewrite\n", unit_id, current, serialize(root)
                else printf "UNIT\t%s\tOperation\tSKIReduce\tTerm\t%s\tStatus\tnormal\n", unit_id, current
                return
            }

            seed_id = ++seed_sequence
            printf "SEED\t%s\n", current
            printf "UNIT\tVAOS.GlaGol.Meta.Orbit.%03d.seed\tOperation\tKStarState\tTerm\t%s\tStep\t0\tStatus\tseed\n", seed_id, current
            history_count = 1
            history[1] = current
            step = 0
            while (1) {
                changed = 0
                root = reduce_once(root)
                if (!changed) {
                    printf "NORMAL\t%s\tSTEPS\t%d\n", current, step
                    printf "UNIT\tVAOS.GlaGol.Meta.Orbit.%03d.%03d.normal\tOperation\tKStarState\tTerm\t%s\tStep\t%d\tStatus\tnormal\n", seed_id, step, current, step
                    return
                }
                next_term = serialize(root)
                if (seen_before(next_term)) {
                    printf "CYCLE\t%s\tSTEP\t%d\n", next_term, step + 1
                    printf "UNIT\tVAOS.GlaGol.Meta.Orbit.%03d.%03d.cycle\tOperation\tKStarState\tTerm\t%s\tStep\t%d\tStatus\tcycle\n", seed_id, step + 1, next_term, step + 1
                    failed = 1
                    return
                }
                if (step >= fuel) {
                    printf "FUEL\t%s\tLIMIT\t%d\n", current, fuel
                    printf "UNIT\tVAOS.GlaGol.Meta.Orbit.%03d.%03d.fuel\tOperation\tKStarState\tTerm\t%s\tStep\t%d\tStatus\tfuel\n", seed_id, step, current, step
                    failed = 1
                    return
                }
                step++
                printf "STEP\t%d\t%s\n", step, next_term
                printf "UNIT\tVAOS.GlaGol.Meta.Orbit.%03d.%03d.rewrite\tOperation\tKStarState\tTerm\t%s\tStep\t%d\tStatus\trewrite\n", seed_id, step, next_term, step
                current = next_term
                history[++history_count] = current
            }
        }
        BEGIN {
            while ((getline atom < language) > 0) {
                if (atom == "") {
                    printf "GlaGol: empty Lang alphabet symbol\n" > "/dev/stderr"
                    failed = 1
                } else if (known[atom]++) {
                    printf "GlaGol: duplicate Lang alphabet symbol\n" > "/dev/stderr"
                    failed = 1
                }
                alphabet_count++
            }
            close(language)
            if (alphabet_count == 0) {
                printf "GlaGol: Lang alphabet is empty\n" > "/dev/stderr"
                failed = 1
            }
        }
        {
            if (failed) next
            if ($0 == "") {
                printf "GlaGol: empty term at line %d\n", NR > "/dev/stderr"
                failed = 1
                next
            }
            process_seed($0)
        }
        END {
            if (mode == "metaclose" && !failed) printf "UNIT\tVAOS.GlaGol.Meta.Close.001\tOperation\tKStar\tLanguageAtoms\t%d\tStatus\tcompleted\n", alphabet_count
            if (failed) exit 2
        }
    ' "$terms"
}

materialize_level2() {
    level2=$1
    references=$2
    output_script=$3
    [ -r "$level2" ] && [ -r "$references" ] || {
        printf '%s: unreadable Lang[level:2] or reference file\n' "$PROGRAM" >&2
        return 2
    }
    [ ! -e "$output_script" ] || {
        printf '%s: refusing to overwrite: %s\n' "$PROGRAM" "$output_script" >&2
        return 2
    }
    ACTIVE_TMP=${output_script}.tmp.$$
    [ ! -e "$ACTIVE_TMP" ] || { ACTIVE_TMP=; return 2; }
    awk -v language="$level2" '
        function decode_frame(frame,    colon,length_text,payload) {
            colon = index(frame, ":")
            if (colon < 2) return 0
            length_text = substr(frame, 1, colon - 1)
            if (length_text !~ /^[0-9]+$/) return 0
            frame_length = length_text + 0
            payload = substr(frame, colon + 1)
            if (length(payload) != frame_length) return 0
            decoded = payload
            return 1
        }
        BEGIN {
            while ((getline symbol < language) > 0) symbols[++symbol_count] = symbol
            close(language)
            if (symbol_count == 0) failed = 1
        }
        {
            if ($0 !~ /^@[0-9]+$/) {
                printf "GlaGol: invalid materialization reference at line %d\n", NR > "/dev/stderr"
                failed = 1
                next
            }
            index_num = substr($0, 2) + 0
            if (index_num >= symbol_count) {
                printf "GlaGol: materialization reference out of range at line %d\n", NR > "/dev/stderr"
                failed = 1
                next
            }
            outer_frame = symbols[index_num + 1]
            if (!decode_frame(outer_frame)) {
                printf "GlaGol: invalid outer level frame at atom %d\n", index_num > "/dev/stderr"
                failed = 1
                next
            }
            inner_frame = decoded
            if (!decode_frame(inner_frame)) {
                printf "GlaGol: invalid inner level frame at atom %d\n", index_num > "/dev/stderr"
                failed = 1
                next
            }
            print decoded
            emitted++
        }
        END {
            if (emitted == 0) {
                printf "GlaGol: no level-2 script lines selected\n" > "/dev/stderr"
                failed = 1
            }
            if (failed) exit 2
        }
    ' "$references" > "$ACTIVE_TMP" || {
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    }
    /bin/sh -n "$ACTIVE_TMP" || {
        printf '%s: generated level-2 script failed sh -n\n' "$PROGRAM" >&2
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    }
    chmod 700 "$ACTIVE_TMP"
    if ! ln "$ACTIVE_TMP" "$output_script" 2>/dev/null; then
        printf '%s: cannot create script without overwrite: %s\n' "$PROGRAM" "$output_script" >&2
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    fi
    rm -f "$ACTIVE_TMP"
    ACTIVE_TMP=
}

list_scaffolds() {
    printf 'SCAFFOLD\tID\tvaos-shell-tool-v1\tLANG\tsh\tPORTABLE\ttrue\tSIGNATURE\tartifact-name,unit-id,message\n'
    printf 'SCAFFOLD\tID\tm2m-dev-root-cli-v1\tLANG\tsh\tPORTABLE\ttrue\tSIGNATURE\tartifact-name,unit-id,title\n'
}

render_portable_scaffold() {
    scaffold_output=$1
    artifact_name=$2
    scaffold_unit_id=$3
    scaffold_message=$4
    case $artifact_name in
        [a-z]* ) ;;
        *) printf '%s: artifact-name must start with a lowercase ASCII letter\n' "$PROGRAM" >&2; return 2 ;;
    esac
    case $artifact_name in *[!a-z0-9-]*) printf '%s: artifact-name must be lowercase-hyphenated\n' "$PROGRAM" >&2; return 2 ;; esac
    case $scaffold_unit_id in ''|*[!A-Za-z0-9.]*) printf '%s: unit-id must contain only ASCII letters, digits, and dots\n' "$PROGRAM" >&2; return 2 ;; esac
    case $scaffold_message in ''|*[!A-Za-z0-9_.-]*) printf '%s: message must be a non-empty safe token\n' "$PROGRAM" >&2; return 2 ;; esac

    {
        printf '%s\n' '#!/bin/sh'
        printf '# ident: %s\n' "$artifact_name"
        printf '%s\n' '# category: tool' '# purpose: execute' '# role: standalone-shell-tool'
        printf '%s\n' '# semantic: implementation' '# universe: vaos'
        printf '# vaos-id: %s\n' "$scaffold_unit_id"
        printf '%s\n' '# brand: OZCO' '# layer: TASK' '# base-axis: Execution'
        printf '%s\n' '# time-axis: RunTime' '# purpose-axis: Knowlege'
        printf '%s\n' '# generated-from: vaos-shell-tool-v1' 'set -eu'
        printf '%s\n' "printf 'UNIT\\t${scaffold_unit_id}\\tOperation\\tScaffoldRun\\tMessage\\t${scaffold_message}\\tStatus\\tcompleted\\n'"
    } > "$scaffold_output"
}

render_m2m_cli_scaffold() {
    scaffold_output=$1
    artifact_name=$2
    scaffold_unit_id=$3
    cli_title=$4
    case $artifact_name in [a-z]* ) ;; *) printf '%s: artifact-name must start with a lowercase ASCII letter\n' "$PROGRAM" >&2; return 2 ;; esac
    case $artifact_name in *[!a-z0-9-]*) printf '%s: artifact-name must be lowercase-hyphenated\n' "$PROGRAM" >&2; return 2 ;; esac
    case $scaffold_unit_id in ''|*[!A-Za-z0-9.]*) printf '%s: unit-id must contain only ASCII letters, digits, and dots\n' "$PROGRAM" >&2; return 2 ;; esac
    case $cli_title in ''|*[!A-Za-z0-9_.:\ -]*) printf '%s: title contains unsupported characters\n' "$PROGRAM" >&2; return 2 ;; esac
    {
        printf '%s\n' '#!/bin/sh' '# @ patterns:' '#   @ : pAT, META' '#   !  :   instructs' '#   $   vars'
        printf '# ident: %s\n' "$artifact_name"
        printf '%s\n' '# category: tool' '# purpose: development-cli-help' '# role: standalone-shell-scaffold'
        printf '%s\n' '# semantic: cli-scaffold' '# universe: vaos'
        printf '# vaos-id: %s\n' "$scaffold_unit_id"
        printf '%s\n' '# brand: OZCO' '# layer: TASK' '# base-axis: Execution' '# time-axis: RunTime' '# purpose-axis: Knowlege'
        printf '%s\n' '# generated-from: m2m-dev-root-cli-v1'
        printf "CLI_TITLE='%s'\n" "$cli_title"
        cat <<'EOF_M2M_BODY'
set -eu
CYAN=
GREEN=
NC=
if [ -t 1 ] && [ "${NO_COLOR+x}" != x ]; then
    CYAN=$(printf '\033[36m')
    GREEN=$(printf '\033[32m')
    NC=$(printf '\033[0m')
fi

show_help() {
    printf '\n%s%s%s\n\n' "$CYAN" "$CLI_TITLE" "$NC"
    printf '%sCommands:%s\n' "$GREEN" "$NC"
    printf '\n  %sProject Operations (research02)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    sync                 Sync projects: prj-artifact → STATE-PRJ/ds-projects
    build [project]      Build all DS projects (or just [project])
    projects             List all DS Engine projects

EOF_HELP
    printf '  %sTerra App (terra-trunk-one)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    terra dev            Start Terra dev servers (Vite + NestJS concurrently)
    terra build          Build Terra (web + nest)
    terra test           Run Terra Jest tests
    terra playwright     Run Playwright E2E pipeline (full)
    terra playwright --skip-servers   Skip server start/stop
    terra playwright --lms-only       LMStudio review only
    terra health         Health check: web (5173) + API (3000)

EOF_HELP
    printf '  %sDS CLI (research01 cli.sh)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    ds info              Show project info (via ds-cli)
    ds project list      List projects
    ds schema <cmd>      Schema operations (validate, generate, inspect)
    ds artifact <cmd>    Artifact operations (list, download, upload)

EOF_HELP
    printf '  %sRemote Operations%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    deploy <src> [dst]   SCP to remote /home/administrator/projects
                         Env: REMOTE_HOST, REMOTE_USER, SSH_KEY

EOF_HELP
    printf '  %sWorkspace%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    status               Show status of all services and projects
    activity             Mark agent activity (suppress self-monitor)
    config               Show current project-config.yaml summary
    self-monitor         Run self-monitor health checks
    help                 Show this help
EOF_HELP
}

case ${1:-help} in
    help|-h|--help) show_help ;;
    *)
        printf '%s: this scaffold documents command groups; wire project-specific handlers before use: %s\n' "$CLI_TITLE" "$*" >&2
        exit 2
        ;;
esac
EOF_M2M_BODY
    } > "$scaffold_output"
}

use_scaffold() {
    template_id=$1
    artifact_name=$2
    scaffold_unit_id=$3
    scaffold_message=$4
    scaffold_target=$5
    case $template_id in
        vaos-shell-tool-v1|m2m-dev-root-cli-v1) ;;
        *) printf '%s: unknown portable scaffold template: %s\n' "$PROGRAM" "$template_id" >&2; return 2 ;;
    esac
    [ ! -e "$scaffold_target" ] || {
        printf '%s: refusing to overwrite: %s\n' "$PROGRAM" "$scaffold_target" >&2
        return 2
    }
    ACTIVE_TMP=${scaffold_target}.tmp.$$
    [ ! -e "$ACTIVE_TMP" ] || { ACTIVE_TMP=; return 2; }
    if [ "$template_id" = "vaos-shell-tool-v1" ]; then
        render_portable_scaffold "$ACTIVE_TMP" "$artifact_name" "$scaffold_unit_id" "$scaffold_message"
    else
        render_m2m_cli_scaffold "$ACTIVE_TMP" "$artifact_name" "$scaffold_unit_id" "$scaffold_message"
    fi || {
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    }
    /bin/sh -n "$ACTIVE_TMP" || {
        printf '%s: rendered scaffold failed sh -n\n' "$PROGRAM" >&2
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    }
    chmod 700 "$ACTIVE_TMP"
    if ! ln "$ACTIVE_TMP" "$scaffold_target" 2>/dev/null; then
        printf '%s: cannot create scaffold target without overwrite: %s\n' "$PROGRAM" "$scaffold_target" >&2
        rm -f "$ACTIVE_TMP"
        ACTIVE_TMP=
        return 2
    fi
    rm -f "$ACTIVE_TMP"
    ACTIVE_TMP=
    printf 'UNIT\tVAOS.GlaGol.Scaffold.%s\tOperation\tRenderTemplate\tTemplate\t%s\tPath\t%s\tStatus\tcreated_and_validated\n' "$artifact_name" "$template_id" "$scaffold_target"
}

selfhost_demo() {
    script_out=$1
    [ ! -e "$script_out" ] || {
        printf '%s: refusing to overwrite: %s\n' "$PROGRAM" "$script_out" >&2
        return 2
    }
    work=${TMPDIR:-/tmp}/glagol-selfhost.$$
    mkdir "$work" 2>/dev/null || {
        printf '%s: cannot create self-host workspace: %s\n' "$PROGRAM" "$work" >&2
        return 2
    }
    ACTIVE_DIR=$work

    render_portable_scaffold "$work/Lang0" glagol-level-2-demo VAOS.GlaGol.Level2.001 GLAGOL_LEVEL_2_EXECUTED || return 2

    lift_language "$work/Lang0" "$work/Lang1" >/dev/null || return 2
    lift_language "$work/Lang1" "$work/Lang2" >/dev/null || return 2
    # K* runs at level 2: each reference is normalized by I and decoded only
    # after closure. No eval is used; execution is the explicit /bin/sh call.
    line_count=$(awk 'END { print NR + 0 }' "$work/Lang0")
    line_index=0
    : > "$work/terms"
    while [ "$line_index" -lt "$line_count" ]; do
        printf 'I @%s APP\n' "$line_index" >> "$work/terms"
        line_index=$((line_index + 1))
    done
    run_combinator metaclose "$work/Lang2" "$work/terms" 16 > "$work/orbit" || return 2
    awk -F '\t' '$1 == "NORMAL" { print $2 }' "$work/orbit" > "$work/refs"
    ref_count=$(awk 'END { print NR + 0 }' "$work/refs")
    [ "$ref_count" -eq "$line_count" ] || {
        printf '%s: K* normalized %s of %s level-2 atoms\n' "$PROGRAM" "$ref_count" "$line_count" >&2
        return 2
    }
    materialize_level2 "$work/Lang2" "$work/refs" "$script_out" || return 2

    printf 'LEVEL\tLang[lvl:0]\t%s\n' "$work/Lang0"
    printf 'LEVEL\tLang[lvl:1]\t%s\n' "$work/Lang1"
    printf 'LEVEL\tLang[lvl:2]\t%s\n' "$work/Lang2"
    cat "$work/orbit"
    printf 'UNIT\tVAOS.GlaGol.Meta.SelfHost.001\tOperation\tWriteLevel2Script\tPath\t%s\tSourceLevel\t2\tStatus\twritten_and_syntax_checked\n' "$script_out"
    execution_result=$(/bin/sh "$script_out")
    expected_execution=$(printf 'UNIT\tVAOS.GlaGol.Level2.001\tOperation\tScaffoldRun\tMessage\tGLAGOL_LEVEL_2_EXECUTED\tStatus\tcompleted')
    [ "$execution_result" = "$expected_execution" ] || {
        printf '%s: level-2 script returned unexpected output\n' "$PROGRAM" >&2
        return 2
    }
    printf 'UNIT\tVAOS.GlaGol.Meta.SelfHost.002\tOperation\tExecuteLevel2Script\tPath\t%s\tOutput\t%s\tStatus\tcompleted\n' "$script_out" "$execution_result"
}

selftest() {
    result=$(printf '%s\n' \
        ': Nat := Zero | Succ(Nat)' \
        '= add Zero n = n' \
        '= add (Succ m) n = Succ(add m n)' | run_engine parse -) || return 1
    printf '%s\n' "$result" | grep -F -q "$(printf 'UNIT\tBEGIN\tDefinitionUnit\tNat')" || {
        printf '%s\n' 'FAIL: Nat definition unit missing' >&2; return 1;
    }
    printf '%s\n' "$result" | grep -F -q "$(printf 'BODY\tZero')" || {
        printf '%s\n' 'FAIL: Zero alternative missing' >&2; return 1;
    }
    printf '%s\n' "$result" | grep -F -q "$(printf 'BODY\tSucc(Nat)')" || {
        printf '%s\n' 'FAIL: Succ(Nat) alternative missing' >&2; return 1;
    }
    [ "$(printf '%s\n' "$result" | grep -c '^OPERATION')" -eq 2 ] || {
        printf '%s\n' 'FAIL: expected two attached equations' >&2; return 1;
    }
    test_dir=${TMPDIR:-/tmp}/glagol-test.$$
    mkdir "$test_dir" || { printf '%s\n' 'FAIL: cannot create self-test directory' >&2; return 1; }
    list_scaffolds | grep -F -q 'vaos-shell-tool-v1' || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: portable scaffold registry' >&2; return 1;
    }
    list_scaffolds | grep -F -q 'm2m-dev-root-cli-v1' || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: M2M portable scaffold registry' >&2; return 1;
    }
    use_scaffold vaos-shell-tool-v1 selftest-tool VAOS.GlaGol.SelfTest.001 GLAGOL_SCAFFOLD_OK "$test_dir/scaffold.sh" >/dev/null || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold rendering' >&2; return 1;
    }
    /bin/sh -n "$test_dir/scaffold.sh" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold syntax validation' >&2; return 1;
    }
    /bin/sh "$test_dir/scaffold.sh" | grep -F -q 'GLAGOL_SCAFFOLD_OK' || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold execution' >&2; return 1;
    }
    use_scaffold m2m-dev-root-cli-v1 m2m-dev-root-cli VAOS.M2M.DevRoot.001 'M2M-DEV-ROOT Development CLI' "$test_dir/m2m-cli.sh" >/dev/null || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: M2M CLI scaffold rendering' >&2; return 1;
    }
    /bin/sh -n "$test_dir/m2m-cli.sh" && /bin/sh "$test_dir/m2m-cli.sh" help > "$test_dir/m2m-help" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: M2M CLI scaffold execution' >&2; return 1;
    }
    grep -F -q 'Project Operations (research02)' "$test_dir/m2m-help" &&
        grep -F -q 'terra playwright --skip-servers' "$test_dir/m2m-help" &&
        grep -F -q 'Env: REMOTE_HOST, REMOTE_USER, SSH_KEY' "$test_dir/m2m-help" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: M2M grouped help content' >&2; return 1;
    }
    printf '%s\n' '@ patterns:' '    @ : pAT, META' '    !  :   instructs' '    $   vars' ': ${CYAN}M2M-DEV-ROOT Development CLI${NC}' '! Commands:' '${GREEN}Project Operations (research02)${NC}' > "$test_dir/patterns.ggl"
    run_engine classify "$test_dir/patterns.ggl" > "$test_dir/classifications" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold pattern classification' >&2; return 1;
    }
    for expected_type in PatternRegistry Pattern InstructionPattern VariablePattern TemplateHeader InstructionSection TemplateContent; do
        grep -F -q "$(printf 'TYPE\t%s\t' "$expected_type")" "$test_dir/classifications" || {
            rm -rf "$test_dir"; printf '%s\n' "FAIL: scaffold marker classification: $expected_type" >&2; return 1;
        }
    done
    run_engine parse "$test_dir/patterns.ggl" > "$test_dir/pattern-units" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold pattern parsing' >&2; return 1;
    }
    grep -F -q 'ScaffoldPatternRegistryUnit' "$test_dir/pattern-units" &&
        grep -F -q 'ScaffoldInstructionSectionUnit' "$test_dir/pattern-units" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold pattern unit records' >&2; return 1;
    }
    run_engine tokens "$test_dir/patterns.ggl" > "$test_dir/pattern-tokens" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: scaffold marker tokenization' >&2; return 1;
    }
    grep -F -q "$(printf 'TOKEN\t1\t@')" "$test_dir/pattern-tokens" &&
        grep -F -q "$(printf 'TOKEN\t3\t!')" "$test_dir/pattern-tokens" &&
        grep -F -q "$(printf 'TOKEN\t4\t$')" "$test_dir/pattern-tokens" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: @/!/$ scaffold marker tokens' >&2; return 1;
    }
    printf 'alpha\nbeta\ngamma\n' > "$test_dir/Lang0"
    if ! lift_language "$test_dir/Lang0" "$test_dir/Lang1" >/dev/null; then
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: level lift' >&2; return 1
    fi
    grep -F -x -q '5:alpha' "$test_dir/Lang1" && grep -F -x -q '4:beta' "$test_dir/Lang1" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: framed higher-level alphabet' >&2; return 1;
    }
    grep -F -x -q '5:gamma' "$test_dir/Lang1" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: third higher-level atom' >&2; return 1;
    }
    lift_language "$test_dir/Lang1" "$test_dir/Lang2" >/dev/null || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: recursive level lift' >&2; return 1;
    }
    grep -F -x -q '7:5:alpha' "$test_dir/Lang2" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: recursive framing' >&2; return 1;
    }
    printf '%s\n' 'K @0 APP @1 APP' 'S @0 APP @1 APP @2 APP' > "$test_dir/terms"
    if ! run_combinator metaclose "$test_dir/Lang1" "$test_dir/terms" 8 > "$test_dir/trace"; then
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: K* closure' >&2; return 1
    fi
    grep -F -q "$(printf 'STEP\t1\t@0')" "$test_dir/trace" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: K combinator reduction' >&2; return 1;
    }
    grep -F -q "$(printf 'STEP\t1\t@0 @2 APP @1 @2 APP APP')" "$test_dir/trace" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: S combinator reduction' >&2; return 1;
    }
    printf '%s\n' 'I @1 APP' > "$test_dir/one-step"
    run_combinator metastep "$test_dir/Lang1" "$test_dir/one-step" > "$test_dir/step" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: I combinator step' >&2; return 1;
    }
    grep -F -q "$(printf 'To\t@1\tStatus\trewrite')" "$test_dir/step" || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: I combinator result' >&2; return 1;
    }
    if ! demo_result=$(selfhost_demo "$test_dir/glagol-level-2-demo.sh"); then
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: level-2 self-host demonstration' >&2; return 1
    fi
    printf '%s\n' "$demo_result" | grep -F -q 'GLAGOL_LEVEL_2_EXECUTED' || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: generated level-2 script did not execute' >&2; return 1;
    }
    [ -x "$test_dir/glagol-level-2-demo.sh" ] || {
        rm -rf "$test_dir"; printf '%s\n' 'FAIL: generated script is not executable' >&2; return 1;
    }
    rm -rf "$test_dir"
    printf '%s\n' 'PASS: GlaGol parser, scaffold-marker conformance, M2M CLI portable scaffold, recursive Lang lift, I/K/S, K* closure, level-2 script execution'
}

command=${1:-parse}
case $command in
    parse|classify|tokens)
        [ "$#" -le 2 ] || { usage >&2; exit 2; }
        run_engine "$command" "${2:--}"
        ;;
    lift)
        [ "$#" -eq 3 ] || { usage >&2; exit 2; }
        lift_language "$2" "$3"
        ;;
    metastep)
        [ "$#" -eq 3 ] || { usage >&2; exit 2; }
        run_combinator metastep "$2" "$3" 1
        ;;
    metaclose)
        [ "$#" -eq 3 ] || [ "$#" -eq 4 ] || { usage >&2; exit 2; }
        run_combinator metaclose "$2" "$3" "${4:-64}"
        ;;
    scaffolds)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        list_scaffolds
        ;;
    scaffold|use-scaffold)
        [ "$#" -eq 6 ] || { usage >&2; exit 2; }
        use_scaffold "$2" "$3" "$4" "$5" "$6"
        ;;
    selfhost)
        [ "$#" -eq 2 ] || { usage >&2; exit 2; }
        selfhost_demo "$2"
        ;;
    selftest)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        selftest
        ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
esac
