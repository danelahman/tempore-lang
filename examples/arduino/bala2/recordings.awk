# The recordings of bindings.cpp in a serial output, as CSV: of each
# recording, by its sequence number, the last complete copy, in the order in
# which the recordings are first read. A copy runs from its line
# "# Recording N, run R, L of S samples ..." to its line
# "# End of recording N"; it is complete if the line of its columns follows
# its header and is followed by L rows, each of as many numbers as there are
# columns. Carriage returns are removed, and text before the "#" of a header
# or an end line, such as the bytes read when the port is opened, is
# ignored. The lines of the log, which begin with "[", and the other lines
# outside the copies are skipped. Each incomplete copy is reported on the
# standard error.
#
# The output is read byte by byte under the locale C, which the bytes of a
# port that is opened mid-transmission may otherwise not satisfy: run as
# LC_ALL=C awk -f recordings.awk.

function skip(reason) {
  printf "Skipped an incomplete copy of recording %s: %s\n", number, reason \
    > "/dev/stderr"
  copy = ""
}

{ gsub(/\r/, "") }

/^$/ { next }

/# Recording [0-9]+, / {
  if (copy != "") skip("no end line")
  sub(/^.*# Recording /, "# Recording ")
  number = $3
  sub(/,$/, "", number)
  length_ = $6
  copy = $0 ORS
  columns = 0
  rows = 0
  next
}

copy == "" || /^\[/ { next }

/# End of recording [0-9]+/ {
  sub(/^.*# End of recording /, "# End of recording ")
  if ($5 != number) skip("the end line of recording " $5)
  else if (rows != length_) skip(rows " of " length_ " rows")
  else {
    if (!(number in last)) order[++count] = number
    last[number] = copy $0 ORS
    copy = ""
  }
  next
}

columns == 0 {
  if ($0 !~ /^[a-z_]+(,[a-z_]+)*$/) { skip("no line of columns"); next }
  columns = split($0, names, ",")
  copy = copy $0 ORS
  next
}

{
  if (split($0, fields, ",") != columns ||
      $0 !~ /^-?[0-9.]+(,-?[0-9.]+)*$/) {
    skip("a malformed row after " rows " rows")
    next
  }
  rows++
  copy = copy $0 ORS
}

END {
  if (copy != "") skip("no end line")
  for (i = 1; i <= count; i++) printf "%s", last[order[i]]
}
