#!/bin/sh
# Prints the serial port of the connected board of the profile BOARD:
#
#   port.sh BOARD
#
# The ports are those listed by `pio device list --serial --json-output`; a
# port matches if the USB identifier VID:PID of its hardware identifier, in
# either case, is one of the member "usb" of the board profile
# src/05-backends/arduino/boards/BOARD.json. A single match is printed, and
# reported on standard error with the title of the profile; no match, several
# matches and a profile without the member are errors, which name PORT and
# the port variable PORT_BOARD, the name of the board in upper case with '-'
# replaced by '_'.
#
# The list is printed by the command TEMPORE_DEVICE_LIST if set, and else by
# pio: that on the PATH, or else that of _arduino/venv, with
# PLATFORMIO_CORE_DIR _arduino/platformio unless the environment sets it.

set -eu

[ $# -eq 1 ] || {
  echo "Usage: port.sh BOARD" >&2
  exit 2
}
board=$1
root=$(cd "$(dirname "$0")/.." && pwd)
profile=$root/src/05-backends/arduino/boards/$board.json
variable=PORT_$(printf '%s' "$board" | tr a-z- A-Z_)

error() {
  echo "Error: $*" >&2
  exit 1
}

case $board in '' | *[!a-z0-9-]*) error "the board '$board' is not a name" ;; esac
[ -f "$profile" ] || error "no board profile $board"

title=$(sed -n 's/^ *"title": *"\([^"]*\)".*/\1/p' "$profile")
ids=$(sed -n 's/^ *"usb": *\[\(.*\)\].*/\1/p' "$profile" | tr -d '" ' | tr , ' ')
[ -n "$ids" ] ||
  error "the profile $board has no USB identifiers to find the port of the $title by; set PORT or $variable"

if [ -n "${TEMPORE_DEVICE_LIST:-}" ]; then
  set -- $TEMPORE_DEVICE_LIST
elif command -v pio > /dev/null 2>&1; then
  set -- pio device list --serial --json-output
elif [ -x "$root/_arduino/venv/bin/pio" ]; then
  PLATFORMIO_CORE_DIR=${PLATFORMIO_CORE_DIR:-$root/_arduino/platformio}
  export PLATFORMIO_CORE_DIR
  set -- "$root/_arduino/venv/bin/pio" device list --serial --json-output
else
  error "PlatformIO pio was not found on the PATH or in _arduino/venv, to list the serial ports; 'make arduino-deps' installs it, or set PORT or $variable"
fi
list=$("$@" 2>&1) || {
  printf '%s\n' "$list" >&2
  error "the serial ports were not listed by $*"
}

# The ports of the list whose identifier VID:PID, in lower case, is one of
# $ids, one per line. Each object of the list has the members "port" and
# "hwid", the latter of the form "USB VID:PID=10C4:EA60 SER=... LOCATION=...".
ports=$(printf '%s\n' "$list" | awk -v ids="$ids" '
  BEGIN { RS = "}"; n = split(ids, a, " "); for (i = 1; i <= n; i++) id[a[i]] = 1 }
  {
    if (!match($0, /"port": *"[^"]*"/)) next
    port = substr($0, RSTART, RLENGTH); sub(/^"port": *"/, "", port); sub(/"$/, "", port)
    if (!match($0, /VID:PID=[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) next
    if (tolower(substr($0, RSTART + 8, 9)) in id) print port
  }')

count=$(printf '%s' "$ports" | grep -c . || true)
case $count in
0)
  error "no $title is connected (USB $(printf '%s' "$ids" | sed 's/ / or /g')); connect it, or set PORT or $variable"
  ;;
1)
  echo "$title on $ports" >&2
  printf '%s\n' "$ports"
  ;;
*)
  error "several ports match the $title: $(printf '%s' "$ports" | tr '\n' ' ' | sed 's/ $//; s/ /, /g'); set PORT or $variable to one of them"
  ;;
esac
