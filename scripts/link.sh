#!/bin/sh
# Prints the peer and the key of a board of the encrypted ESP-NOW link NAME,
# as the shell assignments of esp_now_peer, its address as six bytes
# 0xHH separated by commas, and esp_now_key, 32 hexadecimal digits:
#
#   link.sh [-p PORT] [-t TARGET] [-P PAIR] [-r] NAME ROLE PEER
#
# ROLE is the role of the board built, PEER that of the other board. A link
# file holds lines NAME=VALUE: key, the key of the link, and, under the name
# of each role, the address of its board, six bytes in hexadecimal separated
# by colons. Empty lines and lines beginning with # are ignored, as are
# spaces around the name and the value and carriage returns; any other line,
# a malformed value and a repeated name are errors.
#
# Each pair of boards of the link has a link file in the directory
# REMOTE_LINK_DIR, by default $HOME/.config/tempore/links: NAME for the
# default pair, NAME-PAIR for the pair PAIR, a name of letters, digits, '-'
# and '_'. The link file is
#
# - REMOTE_LINK_FILE if set;
# - else, under -P, that of the pair PAIR;
# - else, under -p, the link file that records the address of the board on
#   the serial port PORT under ROLE, read by esptool; it is an error if
#   several do, or if one records it under PEER;
# - else, for a board under -p that no link file records, that of the
#   default pair if it records no board under ROLE, or under -r, which
#   replaces that board; otherwise it is an error, which names the board
#   recorded and the two choices, PAIR and REPLACE=1;
# - else, without -p, that of the default pair.
#
# Under -P and -p, the other link files that record the board are reported.
# -P is an error with REMOTE_LINK_FILE, and -r with -P, with
# REMOTE_LINK_FILE and without -p.
#
# - Under -p, the address of the board is recorded under ROLE if it is
#   missing or different; it is an error if PEER has the same address.
# - The key is REMOTE_KEY if set, and else that of the link file; without
#   one, it is generated, 16 bytes of `openssl rand` or of /dev/urandom, and
#   recorded.
# - The peer is REMOTE_PEER if set, and else the address recorded under
#   PEER; without one it is an error, which names TARGET, the target that
#   records it, with the pair of the link file.
#
# The link file is written with mode 600 in a directory created with mode
# 700, by renaming a new file over it, under a lock, the directory of its
# name with the suffix .lock, so that concurrent builds agree on one key.
# esptool is the command TEMPORE_ESPTOOL if set, and else esptool.py of the
# package tool-esptoolpy of PlatformIO, run by `pio pkg exec`: pio is that
# on the PATH, or else that of _arduino/venv, with PLATFORMIO_CORE_DIR
# _arduino/platformio unless the environment sets it. The link file chosen
# and the reason, the origin of the key and what is recorded are reported on
# standard error; the key is not.

set -eu

usage() {
  echo "Usage: link.sh [-p PORT] [-t TARGET] [-P PAIR] [-r] NAME ROLE PEER" >&2
  exit 2
}

port=
target=
pair=
paired=false
replace=false
while getopts p:t:P:r option; do
  case $option in
  p) port=$OPTARG ;;
  t) target=$OPTARG ;;
  P)
    pair=$OPTARG
    paired=true
    ;;
  r) replace=true ;;
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

# Whether $1 is the name of a pair: letters, digits, '-' and '_'.
valid_pair() {
  case $1 in '' | *[!A-Za-z0-9_-]*) return 1 ;; esac
}

if $paired; then
  valid_pair "$pair" ||
    error "PAIR='$pair' is not a name of letters, digits, '-' and '_'"
  [ -z "${REMOTE_LINK_FILE:-}" ] ||
    error "PAIR=$pair and REMOTE_LINK_FILE both name a link file"
fi
if $replace; then
  [ -n "$port" ] || error "REPLACE=1 needs the port of the new board"
  ! $paired ||
    error "REPLACE=1 with PAIR=$pair: a board of the pair $pair is replaced without REPLACE=1"
  [ -z "${REMOTE_LINK_FILE:-}" ] ||
    error "REPLACE=1 with REMOTE_LINK_FILE: a board of REMOTE_LINK_FILE is replaced without REPLACE=1"
fi

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

if [ -n "${REMOTE_KEY:-}" ]; then
  valid_key "$REMOTE_KEY" || error "REMOTE_KEY is not 32 hexadecimal digits"
fi
if [ -n "${REMOTE_PEER:-}" ]; then
  [ -n "$(address "$REMOTE_PEER")" ] ||
    error "REMOTE_PEER is not six bytes in hexadecimal separated by colons"
fi

own=
[ -z "$port" ] || own=$(read_address)

links=${REMOTE_LINK_DIR:-${HOME:?}/.config/tempore/links}
default=$links/$name

# The link files of NAME in $links, one per line: that of the default pair
# and those of the named pairs.
link_files() {
  for f in "$default" "$default"-*; do
    [ -f "$f" ] || continue
    [ "$f" = "$default" ] || valid_pair "${f#"$default"-}" || continue
    printf '%s\n' "$f"
  done
}

# The lines ROLE FILE of the link files that record the address $own under
# $role or $peer_role.
records() {
  link_files | while IFS= read -r f; do
    e=$(entries "$f") || exit 1
    printf '%s\n' "$e" | awk -v a="$own" -v r="$role" -v p="$peer_role" -v f="$f" \
      '$2 == a && ($1 == r || $1 == p) { print $1, f }'
  done
}

# The files of the lines $1 of the role $2, separated by ", ".
files_of() {
  printf '%s\n' "$1" | awk -v r="$2" '$1 == r {
    sub(/^[^ ]* /, ""); printf "%s%s", s, $0; s = ", "
  }'
}

if [ -n "${REMOTE_LINK_FILE:-}" ]; then
  file=$REMOTE_LINK_FILE
  report "the link file $file of REMOTE_LINK_FILE"
elif $paired; then
  file=$default-$pair
  report "the link file $file, PAIR=$pair"
  if [ -n "$own" ]; then
    found=$(records) || exit 1
    others=$(printf '%s\n' "$found" | awk -v f="$file" '$0 != "" && substr($0, index($0, " ") + 1) != f')
    for r in "$role" "$peer_role"; do
      o=$(files_of "$others" "$r")
      [ -z "$o" ] || report "the board on $port, $own, is also recorded as the $r in $o"
    done
  fi
elif [ -z "$own" ]; then
  file=$default
  report "the link file $file of the default pair"
else
  found=$(records) || exit 1
  peers=$(files_of "$found" "$peer_role")
  [ -z "$peers" ] ||
    error "the board on $port, $own, is recorded as the $peer_role in $peers: it is the $peer_role of that pair, not a $role"
  owned=$(files_of "$found" "$role")
  case $owned in
  *', '*)
    error "the board on $port, $own, is recorded as the $role in several link files, $owned: choose one by PAIR=<name>, or remove the board from the others"
    ;;
  ?*)
    file=$owned
    report "the link file $file, found by the address of the $role"
    ;;
  *)
    file=$default
    recorded=
    if [ -e "$file" ]; then
      entries=$(entries "$file") || exit 1
      recorded=$(lookup "$role")
    fi
    if [ -z "$recorded" ]; then
      report "the link file $file, first pairing"
    elif $replace; then
      report "the link file $file, replacing the $role $recorded"
    else
      pairs=$(link_files | while IFS= read -r f; do
        [ "$f" = "$default" ] || printf '%s\n' "${f#"$default"-}"
      done | tr '\n' ' ' | sed 's/ $//; s/ /, /g')
      error "the board on $port, $own, is in no link file of $name as the $role, and the default pair, $file, has the $role $recorded: run with PAIR=<name> to start or join another pair${pairs:+ (pairs: $pairs)}, or with REPLACE=1 to replace the $role $recorded in the default pair"
    fi
    ;;
  esac
fi

# The pair of the link file, given to the target that records the peer.
hint=
if [ -z "${REMOTE_LINK_FILE:-}" ]; then
  case $file in "$default"-*) hint=" PAIR=${file#"$default"-}" ;; esac
fi

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
  [ -n "$peer" ] || error "the link file $file has no address of the $peer_role: connect the $peer_role and upload to it first${target:+ (make $target$hint)}, or set REMOTE_PEER"
  report "peer $peer, the $peer_role"
fi

printf 'esp_now_peer=0x%s\n' "$(printf '%s' "$peer" | sed 's/:/,0x/g')"
printf 'esp_now_key=%s\n' "$key"
