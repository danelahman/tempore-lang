# Typechecking benchmark

Times the typechecking of every file of the examples and the tests under the
grades its header names, with the packages and board of the examples, as the
solver tests check them (`tests/inference/test_solve.ml`; the corpus is
`TestPrograms.corpus`). The standard library of each grade is loaded untimed.
Each file is typechecked in 3 fresh child processes, so that the tables the
grades keep start empty; a row shows the median of the first (cold) time.
Files over 2 s are marked. Run from the root of the repository:

    dune exec --profile release bench/typecheck/bench_typecheck.exe

## Measured

- 2026-10-15, at 4ba6950 on `box-examples`
- macOS 15.7.7 (Darwin 24.6.0, arm64), Apple M3 Pro
- OCaml 5.5.0, `--profile release`
- 326 files, total 1.4 s of typechecking, none over 2 s (the whole run takes
  about 30 s, mostly loading the standard library in each process)

The slowest 20 files:

| file | grades | time (s) |
|---|---|---:|
| examples/arduino/bala2-regex/balance_regex.tpe | regex-timed-interval-rational-symbolic | 0.36 |
| examples/arduino/fall/fall.tpe | regex-timed-interval-rational-symbolic | 0.31 |
| examples/arduino/level/level.tpe | regex-timed-interval-rational-symbolic | 0.14 |
| examples/arduino/wheels/wheels.tpe | regex-timed-interval-rational-symbolic | 0.12 |
| examples/arduino/steps/steps.tpe | operation-spacing | 0.08 |
| examples/arduino/bala2/balance.tpe | time-interval-rational | 0.05 |
| examples/opentrons/washes.tpe | regex-timed-interval-symbolic | 0.03 |
| examples/levels/staged_release.tpe | time-lower-bound-levels | 0.03 |
| examples/opentrons/purification.tpe | regex-timed-interval-rational-symbolic | 0.02 |
| examples/opentrons/purification_reject.tpe | regex-timed-interval-rational-symbolic | 0.01 |
| examples/opentrons/contamination.tpe | time-upper-bound-levels | 0.01 |
| examples/regular_timed_ops/upper_bounds_rational.tpe | regex-timed-upper-bound-rational-symbolic | 0.01 |
| examples/opentrons/cleanup.tpe | regex-timed-interval-symbolic | 0.01 |
| examples/traces_timed_ops/upper_bounds.tpe | traces-timed-upper-bound | 0.01 |
| examples/arduino/calibrated/calibrated.tpe | time-interval-rational | 0.01 |
| examples/arduino/peak/peak.tpe | counts-upper-bound | 0.01 |
| examples/regular_timed_ops/mail_session.tpe | regex-timed-upper-bound-symbolic | 0.01 |
| tests/regex_timed_rational_upper.tpe | regex-timed-upper-bound-rational-symbolic | 0.01 |
| examples/arduino/tilt/tilt.tpe | time-interval-rational | 0.01 |
| examples/regular_timed_ops/upper_bounds.tpe | regex-timed-upper-bound-symbolic | 0.01 |
