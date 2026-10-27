#!/usr/bin/env sh
# va-multiline-scan.sh — VA Multiline WSSSW Pattern Scanner
#
# Pattern: WSSSW (Whitespace-Separator-Separator-Separator-Whitespace)
# Mode    : multiline — state across lines via STR
# W       : whitespace (space / tab)
# S       : separator symbol, one of: # * @ %
#
# Algorithm:
#   1. Build STR = concatenation of the FIRST CHARACTER of every input line,
#      in document order. Blank lines contribute a space to STR (as whitespace).
#   2. Find WSSSW matches inside STR:
#        optional whitespace (W1), run of 3+ identical separator chars (SSS),
#        optional whitespace (W2).
#   3. Each match groups the consecutive lines whose first char is the same
#      separator into a section break. Notation = separator repeated (###).
#
# Formal (POSIX BRE): [[:space:]]*\([#*@%]\)\1\1+[[:space:]]*
#
# Examples:
#   # end area
#   ### title ...
#   # start area
#     first chars: # # #  ->  STR="###"  ->  WSSSW match, notation "###"
#
#   # ---
#   # ---
#   # ---
#     first chars: # # #  ->  STR="###"  ->  WSSSW match, notation "###"
#
# Usage: sh va-multiline-scan.sh <file>|-

set -u

AGENT_ID="va-pattern-multiline-tool-1"
AGENT_TOOL="va-multiline-scan.sh"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TMPDIR="${TMPDIR:-/tmp}"
TMP="$TMPDIR/va-multiline-scan.$$.txt"
CHARLIST="$TMPDIR/va-multiline-chars.$$.txt"
trap 'rm -f "$TMP" "$CHARLIST"' EXIT INT TERM HUP

# --- argument validation ---
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  printf 'Unit multiline-scan-000: Scan | Agent: %s | Status: fail | Error: no argument (file or -)\n' "$AGENT_ID"
  printf 'Skill: va-multiline-scan | Tool: %s | Timestamp: %s | Validation: fail\n' "$AGENT_TOOL" "$TS"
  exit 1
fi

if [ "$TARGET" = "-" ]; then
  INPUT="<stdin>"
  exec 0<&0
elif [ -f "$TARGET" ]; then
  INPUT="$TARGET"
  exec < "$TARGET"
else
  printf 'Unit multiline-scan-000: Scan | Agent: %s | File: %s | Status: fail | Error: file not found\n' "$AGENT_ID" "$TARGET"
  printf 'Skill: va-multiline-scan | Tool: %s | Timestamp: %s | Validation: fail\n' "$AGENT_TOOL" "$TS"
  exit 1
fi

# --- pass 1: build STR (first char of each line) and CHARLIST (one char per line) ---
STR=""
> "$CHARLIST"

while IFS= read -r LINE || [ -n "$LINE" ]; do
  # Literal first character of this line
  # Use printf to safely extract char 1; for empty LINE result is empty (we add space for blank)
  FIRST="$(printf '%s' "$LINE" | cut -c1)"
  # Empty first char = blank line → add space (whitespace, valid W in WSSSW)
  [ -z "$FIRST" ] && FIRST=" "
  STR="${STR}${FIRST}"
  # Write each char of STR (or at least each char of FIRST) to CHARLIST
  # FIRST is a single char, so:
  printf '%s\n' "$FIRST"
done >> "$CHARLIST"

# --- pass 2: scan CHARLIST for WSSSW runs ---
# WSSSW: 3+ consecutive identical separator chars in STR.
# Blank lines add spaces (whitespace) that break runs — this is correct W-bounded behavior.
PREV=""
RUNLEN=0
RUNSTART=0
MATCH_COUNT=0
CHNUM=0

while IFS= read -r CH; do
  CHNUM=$((CHNUM + 1))
  case "$CH" in
    '#'|'*'|'@'|'%')
      if [ "$CH" = "$PREV" ]; then
        RUNLEN=$((RUNLEN + 1))
      else
        # Run ended — check if previous run was WSSSW (len >= 3)
        if [ "$RUNLEN" -ge 3 ]; then
          MATCH_COUNT=$((MATCH_COUNT + 1))
          NOTATION="$(printf '%s' "$PREV" && printf '%s' "$PREV" && printf '%s' "$PREV")"
          printf 'Unit multiline-%04d: WSSSW | Agent: %s | StrPos: %d-%d | Sep: %s | Run: %d | Notation: %s | Class: section-break | Status: ok\n' \
            "$MATCH_COUNT" "$AGENT_ID" "$RUNSTART" "$((CHNUM - 1))" "$PREV" "$RUNLEN" "$NOTATION"
        fi
        PREV="$CH"
        RUNLEN=1
        RUNSTART=$CHNUM
      fi
      ;;
    ' '|'	')
      # whitespace — breaks any run (correct for WSSSW where W must be bounded)
      if [ "$RUNLEN" -ge 3 ]; then
        MATCH_COUNT=$((MATCH_COUNT + 1))
        NOTATION="$(printf '%s' "$PREV" && printf '%s' "$PREV" && printf '%s' "$PREV")"
        printf 'Unit multiline-%04d: WSSSW | Agent: %s | StrPos: %d-%d | Sep: %s | Run: %d | Notation: %s | Class: section-break | Status: ok\n' \
          "$MATCH_COUNT" "$AGENT_ID" "$RUNSTART" "$((CHNUM - 1))" "$PREV" "$RUNLEN" "$NOTATION"
      fi
      PREV=""
      RUNLEN=0
      RUNSTART=0
      ;;
    *)
      # non-separator, non-whitespace char — breaks any run
      if [ "$RUNLEN" -ge 3 ]; then
        MATCH_COUNT=$((MATCH_COUNT + 1))
        NOTATION="$(printf '%s' "$PREV" && printf '%s' "$PREV" && printf '%s' "$PREV")"
        printf 'Unit multiline-%04d: WSSSW | Agent: %s | StrPos: %d-%d | Sep: %s | Run: %d | Notation: %s | Class: section-break | Status: ok\n' \
          "$MATCH_COUNT" "$AGENT_ID" "$RUNSTART" "$((CHNUM - 1))" "$PREV" "$RUNLEN" "$NOTATION"
      fi
      PREV=""
      RUNLEN=0
      RUNSTART=0
      ;;
  esac
done < "$CHARLIST"

# Flush trailing run
if [ "$RUNLEN" -ge 3 ]; then
  MATCH_COUNT=$((MATCH_COUNT + 1))
  NOTATION="$(printf '%s' "$PREV" && printf '%s' "$PREV" && printf '%s' "$PREV")"
  printf 'Unit multiline-%04d: WSSSW | Agent: %s | StrPos: %d-%d | Sep: %s | Run: %d | Notation: %s | Class: section-break | Status: ok\n' \
    "$MATCH_COUNT" "$AGENT_ID" "$RUNSTART" "$CHNUM" "$PREV" "$RUNLEN" "$NOTATION"
fi

printf '\n'
# Truncate STR display to 60 chars to avoid bloating output
STRDISP="${STR}"
[ "${#STRDISP}" -gt 60 ] && STRDISP="${STRDISP%???}..."
printf 'Unit multiline-summary: WSSSW-Summary | Agent: %s | File: %s | Lines: %d | STR: [%s] | Matched: %d | Status: ok\n' \
  "$AGENT_ID" "$INPUT" "$CHNUM" "$STRDISP" "$MATCH_COUNT"
printf 'Skill: va-multiline-scan | Tool: %s | Timestamp: %s | Validation: pass\n' "$AGENT_TOOL" "$TS"
exit 0
