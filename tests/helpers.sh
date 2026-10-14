# Shell functions shared by the cram tests of the subdirectories of tests/,
# sourced by them as ../helpers.sh; paths are relative to such a directory.

# The output of the interpreter without the final states of the resources of
# its runs.
strip_state () { awk '/^State:/ { skip = 1 } /^$/ { skip = 0 } !skip'; }

# [from_header FILE] defines [tempore], the interpreter under the grades named
# in the header of FILE, and [packages], the interpreter under all the options
# of the run command of that header: its grades, packages and board.
from_header () {
  header_grades=$(../support/header_options.exe -grades "$1")
  header_options=$(../support/header_options.exe "$1")
  tempore () { ../../tempore --grades "$header_grades" "$@"; }
  packages () { ../../tempore $header_options "$@"; }
}
