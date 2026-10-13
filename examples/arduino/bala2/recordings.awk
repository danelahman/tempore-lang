# The recordings of bindings.cpp in a serial output, as CSV: of each
# recording, by its sequence number, the last copy read in full, from its line
# "# Recording" to its line "# End of recording", in the order in which the
# recordings are first read. The lines of the log, which begin with "[", and
# the other lines outside the recordings are skipped.

/^# Recording / {
  number = $3
  sub(/,$/, "", number)
  copy = $0 ORS
  next
}

copy == "" || /^\[/ { next }

{ copy = copy $0 ORS }

/^# End of recording / {
  if ($5 == number) {
    if (!(number in last)) order[++count] = number
    last[number] = copy
  }
  copy = ""
}

END { for (i = 1; i <= count; i++) printf "%s", last[order[i]] }
