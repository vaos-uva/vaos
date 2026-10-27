#!/usr/bin/env sh
# va-linear-scan.sh — VA Linear SSSW Pattern Scanner
#
# Pattern: SSSW  (Separator-Separator-Separator-[Whitespace/content])
# Mode    : linear — each line is checked independently (no state between lines)
# S       : separator symbol, one of: # * @ %
# W       : whitespace and/or any content after the SSS run (may be empty)
#
# A line matches when it STARTS with a run of 3+ identical separator chars.
# Formal (POSIX BRE): ^\([#*@%]\)\1\1+.*
#
# Examples:
#   "### vasily was here"  -> SSS="###", W="vasily was here", class=heading
#   "----------"           -> SSS="----------", W="",        class=ruler
#   "*** note"             -> SSS="***",        W="note",    class=heading
#   "# plain comment"      -> no match (only 1 leading #)
#
# Usage: sh va-linear-scan.sh <file>|-

set -u

AGENT_ID="va-pattern-linear-tool-1"
AGENT_TOOL="va-linear-scan.sh"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- argument validation ---
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  printf 'Unit linear-scan-000: Scan | Agent: %s | Status: fail | Error: no argument (file or -)\n' "$AGENT_ID"
  printf 'Skill: va-linear-scan | Tool: %s | Timestamp: %s | Validation: fail\n' "$AGENT_TOOL" "$TS"
  exit 1
fi

if [ "$TARGET" = "-" ]; then
  INPUT="<stdin>"
  exec 0<&0
elif [ -f "$TARGET" ]; then
  INPUT="$TARGET"
  exec < "$TARGET"
else
  printf 'Unit linear-scan-000: Scan | Agent: %s | File: %s | Status: fail | Error: file not found\n' "$AGENT_ID" "$TARGET"
  printf 'Skill: va-linear-scan | Tool: %s | Timestamp: %s | Validation: fail\n' "$AGENT_TOOL" "$TS"
  exit 1
fi

LINENUM=0
MATCH_COUNT=0
NO_MATCH=0

while IFS= read -r LINE || [ -n "$LINE" ]; do
  LINENUM=$((LINENUM + 1))

  # Extract the leading run of separator chars (if any) using awk (POSIX):
  #   - FS = "" (per-char), print the consecutive leading run of one symbol
  #   - $runlength >= 3 -> match
  # We use sed to pull the separator prefix: match ^[#*@%]+ and length it.
  SSS="$(printf '%s' "$LINE" | sed -n 's/^\([#*@%]\)\1\1.*/\1/p')"
  if [ -z "$SSS" ]; then
    NO_MATCH=$((NO_MATCH + 1))
    continue
  fi

  # Count the exact run length of SSS chars at line start
  RUN=""
  I=1
  LINELEN="${#LINE}"
  while [ $I -le "$LINELEN" ]; do
    CH="$(printf '%s' "$LINE" | cut -c$I)"
    case "$CH" in
      '#') RUN="${RUN}#" ;;
      '*') RUN="${RUN}*" ;;
      '@') RUN="${RUN}@" ;;
      '%') RUN="${RUN}%" ;;
      *) break ;;
    esac
    I=$((I + 1))
  done
  if [ "${#RUN}" -lt 3 ]; then
    NO_MATCH=$((NO_MATCH + 1))
    continue
  fi
  MATCH_COUNT=$((MATCH_COUNT + 1))

  # W = content after the SSS run
  W="$(printf '%s' "${LINE#"${RUN}"}" | sed 's/^[[:space:]]*//')"

  # Classify: content after run => heading, nothing => ruler
  if [ -z "$W" ]; then
    PAT="ruler"
  else
    PAT="heading"
  fi

  printf 'Unit linear-%04d: SSSW | Agent: %s | Line: %d | SSS: [%s] | W: [%s] | Class: %s | Status: ok\n' \
    "$LINENUM" "$AGENT_ID" "$LINENUM" "$RUN" "$W" "$PAT"
done

printf '\n'
printf 'Unit linear-summary: SSSW-Summary | Agent: %s | File: %s | Total: %d | Matched: %d | NoMatch: %d | Status: ok\n' \
  "$AGENT_ID" "$INPUT" "$LINENUM" "$MATCH_COUNT" "$NO_MATCH"
printf 'Skill: va-linear-scan | Tool: %s | Timestamp: %s | Validation: pass\n' "$AGENT_TOOL" "$TS"
exit 0
