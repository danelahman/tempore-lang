# Typechecking benchmark

Times the typechecking of every file of the examples and the tests under the
grades its header names, with the packages and board of the examples, as the
solver tests check them (`tests/inference/test_solve.ml`; the corpus is
`TestPrograms.corpus`). The standard library of each grade is loaded untimed.
Each file is typechecked in 3 fresh child processes, so that the tables the
grades keep start empty; a row shows the median of the first (cold) time.
Files over 2 s are marked.

The total is the sum of these typechecking times. It excludes compilation,
process start-up and the loading of the standard library, and so it is much
shorter than a run of `make test` (about a minute), which also runs the other
test suites.

Run from the root of the repository:

    dune exec --profile release bench/typecheck/bench_typecheck.exe

## Measured

- 2026-11-11, at 050a3898 on `main`
- macOS 15.8.2 (Darwin 24.6.0, arm64), Apple M3 Pro
- OCaml 5.5.0, dune 3.24.2, `--profile release`
- 385 files, total 1.1 s of typechecking, none over 2 s

The slowest 20 files:

| file                                                   | grades                        | time (s) |
| ------------------------------------------------------ | ----------------------------- | -------: |
| examples/arduino/bala2-radio-robot/robot.tpe           | timed-regex-interval-rational |     0.28 |
| examples/arduino/starter/starter.tpe                   | timed-regex-interval-rational |     0.22 |
| examples/arduino/steps/steps.tpe                       | inter-arrival                 |     0.06 |
| examples/arduino/bala2-radio-controller/controller.tpe | timed-regex-interval-rational |     0.06 |
| examples/arduino/bala2-regex/balance_regex.tpe         | timed-regex-interval-rational |     0.05 |
| examples/arduino/fall/fall.tpe                         | timed-regex-interval-rational |     0.05 |
| examples/arduino/bala2/balance.tpe                     | time-interval-rational        |     0.03 |
| examples/arduino/level/level.tpe                       | timed-regex-interval-rational |     0.03 |
| examples/arduino/wheels/wheels.tpe                     | timed-regex-interval-rational |     0.02 |
| examples/lattice/staged_release.tpe                    | time-lower-bound-lattice      |     0.02 |
| examples/opentrons/contamination.tpe                   | time-upper-bound-lattice      |     0.01 |
| examples/arduino/calibrated/calibrated.tpe             | time-interval-rational        |     0.01 |
| examples/opentrons/purification_reject.tpe             | timed-regex-interval-rational |     0.01 |
| examples/opentrons/purification.tpe                    | timed-regex-interval-rational |     0.01 |
| examples/arduino/peak/peak.tpe                         | at-most-counts                |     0.01 |
| examples/arduino/tilt/tilt.tpe                         | time-interval-rational        |     0.00 |
| examples/opentrons/washes.tpe                          | timed-regex-interval-rational |     0.00 |
| examples/banked_traces/lower_bounds.tpe                | banked-traces-lower-bound     |     0.00 |
| examples/banked_traces/intervals.tpe                   | banked-traces-interval        |     0.00 |
| tests/termination.tpe                                  | time-lower-bound              |     0.00 |
