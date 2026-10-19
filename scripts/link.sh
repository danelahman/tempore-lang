#!/bin/sh
# Prints the peer and the key of a board of the encrypted ESP-NOW link NAME,
# as the shell assignments of esp_now_peer, its address as six bytes
# 0xHH separated by commas, and esp_now_key, 32 hexadecimal digits:
#
#   link.sh [-p PORT] [-t TARGET] NAME ROLE PEER
#
# ROLE is the role of the board built, PEER that of the other board. The link
# file, REMOTE_LINK_FILE if set and else $HOME/.config/tempore/links/NAME,
# holds lines NAME=VALUE: key, the key of the link, and, under the name of
# each role, the address of its board, six bytes in hexadecimal separated by
# colons. Empty lines and lines beginning with # are ignored, as are spaces
# around the name and the value and carriage returns; any other line, a
# malformed value and a repeated name are errors.
#
# - Under -p, the address of the board on the serial port PORT is read by
#   esptool and recorded under ROLE if it is missing or different; it is an
#   error if PEER has the same address.
# - The key is REMOTE_KEY if set, and else that of the link file; without
#   one, it is taken from the key file REMOTE_KEY_FILE, by default
#   $HOME/.config/tempore/keys/NAME.key, if it exists, and else generated,
#   16 bytes of `openssl rand` or of /dev/urandom, and recorded.
# - The peer is REMOTE_PEER if set, and else the address recorded under
#   PEER; without one it is an error, which names TARGET, the target that
#   records it.
#
# The link file is written with mode 600 in a directory created with mode
# 700, by renaming a new file over it, under a lock, the directory of its
# name with the suffix .lock, so that concurrent builds agree on one key.
# esptool is the command TEMPORE_ESPTOOL if set, and else esptool.py of the
# package tool-esptoolpy of PlatformIO, run by `pio pkg exec`: pio is that
# on the PATH, or else that of _arduino/venv, with PLATFORMIO_CORE_DIR
# _arduino/platformio unless the environment sets it. What is recorded, and
# the link file, are reported on standard error; the key is not.

set -eu

usage() {
  echo "Usage: link.sh [-p PORT] [-t TARGET] NAME ROLE PEER" >&2
  exit 2
}

port=
target=
while getopts p:t: option; do
  case $option in
  p) port=$OPTARG ;;
  t) target=$OPTARG ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 3 ] || usage
name=$1
role=$2
peer_role=$3

error() {
  echo "Error: $*" >&2
  exit 1
}

report() {
  echo "ESP-NOW link $name: $*" >&2
}

# Whether $1 is a name of an entry: a letter followed by letters, digits,
# '-' and '_'.
valid_name() {
  case $1 in '' | [!A-Za-z]* | *[!A-Za-z0-9_-]*) return 1 ;; esac
}

for r in "$role" "$peer_role"; do
  valid_name "$r" && [ "$r" != key ] || error "the role '$r' is not a name"
done
[ "$role" != "$peer_role" ] || error "the role and the peer are both '$role'"

# Whether $1 is 32 hexadecimal digits.
valid_key() {
  case $1 in *[!0-9A-Fa-f]*) return 1 ;; esac
  [ ${#1} -eq 32 ]
}

# The address $1, six bytes of two hexadecimal digits separated by ':' or
# '-', in upper case separated by ':', or nothing if it is malformed.
address() {
  printf '%s\n' "$1" | awk '{
    n = split($0, b, /[:-]/)
    if (n != 6 || length($0) != 17) exit
    for (i = 1; i <= 6; i++)
      if (b[i] !~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) exit
    print toupper($0)
  }' | tr - :
}

# The entries of the link file $1, one per line, NAME VALUE, the addresses
# normalised; an error at the first malformed line.
entries() {
  awk '
    function fail(message) {
      printf "Error: the link file %s, line %d: %s\n", FILENAME, FNR, message > "/dev/stderr"
      failed = 1
      exit 1
    }
    {
      line = $0
      sub(/\r$/, "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      if (line == "" || line ~ /^#/) next
      i = index(line, "=")
      if (i == 0) fail("not NAME=VALUE")
      n = substr(line, 1, i - 1); v = substr(line, i + 1)
      sub(/[ \t]+$/, "", n); sub(/^[ \t]+/, "", v)
      if (n !~ /^[A-Za-z][A-Za-z0-9_-]*$/) fail("the name \"" n "\" is not a name")
      if (n in seen) fail("the name " n " is repeated")
      seen[n] = 1
      if (n == "key") {
        if (length(v) != 32 || v ~ /[^0-9A-Fa-f]/) fail("the key is not 32 hexadecimal digits")
        print n, v
      } else {
        a = v
        k = split(a, b, /[:-]/)
        ok = k == 6 && length(a) == 17
        for (j = 1; ok && j <= 6; j++) ok = b[j] ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/
        if (!ok) fail("the address of " n " is not six bytes in hexadecimal separated by colons")
        gsub(/-/, ":", a)
        print n, toupper(a)
      }
    }
    END { if (failed) exit 1 }' "$1"
}

# The value of the entry $1 of $entries, or nothing.
lookup() {
  printf '%s\n' "$entries" | awk -v n="$1" '$1 == n { print $2 }'
}

# The address of the board on $port, read by esptool.
read_address() {
  if [ -n "${TEMPORE_ESPTOOL:-}" ]; then
    set -- $TEMPORE_ESPTOOL
  else
    root=$(cd "$(dirname "$0")/.." && pwd)
    if command -v pio > /dev/null 2>&1; then
      set -- pio
    elif [ -x "$root/_arduino/venv/bin/pio" ]; then
      PLATFORMIO_CORE_DIR=${PLATFORMIO_CORE_DIR:-$root/_arduino/platformio}
      export PLATFORMIO_CORE_DIR
      set -- "$root/_arduino/venv/bin/pio"
    else
      error "PlatformIO pio was not found on the PATH or in _arduino/venv, to read the address of the board on $port; 'make arduino-deps' installs it"
    fi
    set -- "$@" pkg exec -p tool-esptoolpy -- esptool.py
  fi
  out=$("$@" --port "$port" read_mac 2>&1) || {
    printf '%s\n' "$out" >&2
    if [ -n "${TEMPORE_ESPTOOL:-}" ]; then
      error "the address of the board on $port was not read by $TEMPORE_ESPTOOL"
    fi
    error "the address of the board on $port was not read by esptool, of the package tool-esptoolpy that PlatformIO installs at the first build for an ESP32 board"
  }
  mac=$(printf '%s\n' "$out" | sed -n 's/^MAC: *\([0-9A-Fa-f:]*\).*/\1/p' | head -n 1)
  mac=$(address "$mac")
  [ -n "$mac" ] || {
    printf '%s\n' "$out" >&2
    error "esptool did not print the address of the board on $port"
  }
  printf '%s\n' "$mac"
}

file=${REMOTE_LINK_FILE:-${HOME:?}/.config/tempore/links/$name}
old_key_file=${REMOTE_KEY_FILE:-$HOME/.config/tempore/keys/$name.key}

if [ -n "${REMOTE_KEY:-}" ]; then
  valid_key "$REMOTE_KEY" || error "REMOTE_KEY is not 32 hexadecimal digits"
fi
if [ -n "${REMOTE_PEER:-}" ]; then
  [ -n "$(address "$REMOTE_PEER")" ] ||
    error "REMOTE_PEER is not six bytes in hexadecimal separated by colons"
fi

own=
[ -z "$port" ] || own=$(read_address)

umask 077
dir=$(dirname "$file")
mkdir -p "$dir"
lock=$file.lock
tmp=
cleanup() {
  [ -z "$tmp" ] || rm -f "$tmp"
  rmdir "$lock" 2> /dev/null || true
}
tries=0
until mkdir "$lock" 2> /dev/null; do
  tries=$((tries + 1))
  [ $tries -lt 300 ] ||
    error "the link file $file is locked by $lock; remove it if no build is running"
  sleep 0.1
done
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

entries=
[ ! -e "$file" ] || entries=$(entries "$file") || exit 1
changed=false

key=$(lookup key)
if [ -n "${REMOTE_KEY:-}" ]; then
  key=$REMOTE_KEY
  report "key of REMOTE_KEY"
elif [ -n "$key" ]; then
  report "key of $file"
elif [ -e "$old_key_file" ]; then
  key=$(tr -d ' \r\n' < "$old_key_file")
  valid_key "$key" ||
    error "the key file $old_key_file is not 32 hexadecimal digits"
  entries=$(printf 'key %s\n%s' "$key" "$entries")
  changed=true
  report "key taken over from $old_key_file into $file"
else
  if command -v openssl > /dev/null 2>&1; then
    key=$(openssl rand -hex 16)
  else
    key=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
  fi
  valid_key "$key" || error "no key was generated"
  entries=$(printf 'key %s\n%s' "$key" "$entries")
  changed=true
  report "key generated in $file"
fi

if [ -n "$own" ]; then
  recorded=$(lookup "$role")
  [ "$own" != "$(lookup "$peer_role")" ] ||
    error "the board on $port, $own, is recorded as the $peer_role in $file"
  if [ "$own" != "$recorded" ]; then
    entries=$(printf '%s\n' "$entries" |
      awk -v n="$role" -v a="$own" '$1 == n { $2 = a; f = 1 } NF { print } END { if (!f) print n, a }')
    changed=true
    if [ -z "$recorded" ]; then
      report "the $role $own recorded in $file"
    else
      report "the $role changed from $recorded to $own in $file"
    fi
  fi
fi

if $changed; then
  tmp=$(mktemp "$dir/.$name.XXXXXX")
  {
    echo "# The ESP-NOW link $name: its key and the address of the board of each role."
    printf '%s\n' "$entries" | awk 'NF { print $1 "=" $2 }'
  } > "$tmp"
  mv -f "$tmp" "$file"
  tmp=
fi

if [ -n "${REMOTE_PEER:-}" ]; then
  peer=$(address "$REMOTE_PEER")
  report "peer $peer of REMOTE_PEER"
else
  peer=$(lookup "$peer_role")
  [ -n "$peer" ] || error "the link file $file has no address of the $peer_role: connect the $peer_role and upload to it first${target:+ (make $target)}, or set REMOTE_PEER"
  report "peer $peer, the $peer_role"
fi

printf 'esp_now_peer=0x%s\n' "$(printf '%s' "$peer" | sed 's/:/,0x/g')"
printf 'esp_now_key=%s\n' "$key"
