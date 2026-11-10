#!/bin/sh
# Prints help text wrapped to 80 columns:
#
#   help.sh wrap FIRST REST TEXT   the words of TEXT, FIRST before the first
#                                  line and REST before each further line
#   help.sh row KEY TEXT           KEY, and TEXT in the column 32, wrapped
#                                  there; TEXT below KEY if KEY is wider
#
# Words are broken at blanks only, so a word wider than a line is kept.

set -eu

case "${1:-}:$#" in
wrap:4 | row:3) ;;
*)
  echo "Usage: help.sh wrap FIRST REST TEXT | help.sh row KEY TEXT" >&2
  exit 2
  ;;
esac
mode=$1
shift
if [ "$mode" = row ]; then
  set -- "$1" "" "$2"
fi
HELP_FIRST=$1 HELP_REST=$2 HELP_TEXT=$3 HELP_MODE=$mode awk 'BEGIN {
  width = 80; col = 32
  first = ENVIRON["HELP_FIRST"]; rest = ENVIRON["HELP_REST"]
  if (ENVIRON["HELP_MODE"] == "row") {
    rest = sprintf("%" col "s", "")
    if (length(first) < col) first = sprintf("%-" col "s", first)
    else { print first; first = rest }
  }
  n = split(ENVIRON["HELP_TEXT"], word, " ")
  line = first; fresh = 1
  for (i = 1; i <= n; i++) {
    if (!fresh && length(line) + 1 + length(word[i]) > width) {
      print line; line = rest; fresh = 1
    }
    line = line (fresh ? "" : " ") word[i]; fresh = 0
  }
  if (!fresh || n == 0) print line
}'
