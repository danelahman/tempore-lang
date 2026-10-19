#!/bin/sh
# Prints the key of the ESP-NOW link NAME, 32 hexadecimal digits, shared by
# the paired builds of its two boards:
#
#   link-key.sh NAME
#
# The key is REMOTE_KEY if it is set, and otherwise that of the key file,
# REMOTE_KEY_FILE if it is set and else $HOME/.config/tempore/keys/NAME.key.
# An absent key file is first written with 16 bytes of `openssl rand`, or of
# /dev/urandom without openssl: in a new file of mode 600, in a directory
# created with mode 700, linked to the name of the key file only if no file
# has it, so that concurrent builds read the same key. A malformed key is an
# error. The source of the key, and the key file, are reported on standard
# error; the key is not.

set -eu

[ $# -eq 1 ] || {
  echo "Usage: link-key.sh NAME" >&2
  exit 2
}
name=$1

# Whether $1 is 32 hexadecimal digits.
valid() {
  case $1 in *[!0-9A-Fa-f]*) return 1 ;; esac
  [ ${#1} -eq 32 ]
}

if [ -n "${REMOTE_KEY:-}" ]; then
  valid "$REMOTE_KEY" || {
    echo "Error: REMOTE_KEY is not 32 hexadecimal digits" >&2
    exit 1
  }
  echo "ESP-NOW link $name: key of REMOTE_KEY" >&2
  printf '%s\n' "$REMOTE_KEY"
  exit 0
fi

file=${REMOTE_KEY_FILE:-${HOME:?}/.config/tempore/keys/$name.key}
umask 077
if [ -e "$file" ]; then
  verb=reused
else
  dir=$(dirname "$file")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.$name.key.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  if command -v openssl > /dev/null 2>&1; then
    openssl rand -hex 16 > "$tmp"
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > "$tmp"
    echo >> "$tmp"
  fi
  if ln "$tmp" "$file" 2> /dev/null; then verb=generated; else verb=reused; fi
fi

key=$(tr -d ' \r\n' < "$file")
valid "$key" || {
  echo "Error: the key file $file is not 32 hexadecimal digits" >&2
  exit 1
}
echo "ESP-NOW link $name: key $verb, in $file" >&2
printf '%s\n' "$key"
