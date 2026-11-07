# Regular grades benchmark

Times the grade operations and the typechecking of the regular trace
languages, the regex grades with banked delays and the timed regex grades,
comparing the implementations of each grade where there are several. Run from
the root of the repository:

    dune exec --profile release bench/regular/bench_regular.exe

A full run takes about 14 minutes. With `--quick` each family is timed at its
least size only, in about 3 minutes.

## Grades and implementations

The implementations other than `-symbolic`, `-rational-symbolic` and the timed
regex grades are hidden: `--grades` accepts them for benchmarking, and
`./tempore --help` lists only the others.

| column   | `--grades` names                                                                    | representation                                             | inclusion                                                  |
| -------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------- |
| automata | `regular-trace-languages-letter-automata`                                           | minimal automata over single letters                       | product with the complement, breadth-first                 |
| plain    | `regular-trace-languages-letter-derivatives`                                        | expressions over single letters                            | derivatives by single letters, depth-first                 |
| letters  | `regular-trace-languages-symbolic-by-letters`                                       | symbolic expressions over letter sets                      | derivatives by single letters, depth-first                 |
| symbolic | `regular-trace-languages-symbolic`                                                  | symbolic expressions over letter sets                      | gap derivatives by minterms, depth-first                   |
| automata | `banked-regex-{lower-bound,upper-bound,interval}-letter-automata`                   | minimal automata over single letters                       | product with the closure, breadth-first                    |
| plain    | `banked-regex-{lower-bound,upper-bound,interval}-letter-derivatives`                | expressions over single letters                            | derivatives by single letters with closures, depth-first   |
| letters  | `banked-regex-{lower-bound,upper-bound,interval}-symbolic-by-letters`               | symbolic expressions over letter sets                      | derivatives by single letters with closures, depth-first   |
| symbolic | `banked-regex-{lower-bound,upper-bound,interval}-symbolic`                          | symbolic expressions over letter sets                      | gap derivatives with a closure reader, breadth-first       |
| automata | `regular-trace-languages-rational-automata`                                         | minimal symbolic automata over letter and delay sets       | product with the complement, breadth-first                 |
| symbolic | `regular-trace-languages-rational-symbolic`                                         | symbolic expressions over letter and delay sets            | gap derivatives by minterms, depth-first                   |
| automata | `banked-regex-{lower-bound,upper-bound,interval}-rational-automata`                 | minimal symbolic automata over letter and delay sets       | product with a closure reader, breadth-first               |
| symbolic | `banked-regex-{lower-bound,upper-bound,interval}-rational-symbolic`                 | symbolic expressions over letter and delay sets            | gap derivatives with a closure reader, breadth-first       |
| time     | `timed-regex-{lower-bound,upper-bound,interval}[-rational]`, `timed-regex-finite-…` | expressions over time spans, idle waits and operation sets | partial derivatives with a time span reader, breadth-first |

The results tables show each implementation under its label in the first
column. Each ratio of consecutive columns mixes several choices:

- automata / plain: automata built with the grade against expressions decided
  on the fly, a breadth-first product against a depth-first search, and
  canonical against derived equality and printing;
- plain / letters: single letters, with the alphabets of two grades aligned,
  against letter sets; the decision procedures are the same;
- letters / symbolic: derivatives by single letters, a run of ticks taken in
  one step, against gap derivatives by minterms, a delay of any length in one
  step; breadth-first against Dijkstra counterexamples, and equality by the
  derivatives against a bisimulation of the gap derivatives; for the regex
  grades with banked delays also a depth-first search with the closure stepped
  alongside against a breadth-first search with a closure reader;
- rational automata / symbolic: minimal symbolic automata and a product
  against expressions and gap derivatives.

The timed regex grades have one implementation, timed alone.

## Workloads

Each family is timed at increasing sizes; each row names its workload.

Whole time steps, four columns:

- Typechecking: the standard library alone, then with each example and test
  whose header names the `-symbolic` grade, under every implementation.
- Corpus of the regular trace languages: 41 literals of those files; elaborate,
  `mul`, `join`, `leq`, `equal`, `counterexample` over all pairs, `show` of
  each.
- Protocol `P^k` (k = 8, 32) and nested protocol `N_d` (d = 3, 6): products,
  joins and inclusions of repeated sessions.
- n-th letter from the end (n = 4, 8, 12, 16): complement and intersection,
  where automata determinise; `show` of `E2` at n = 8, 12.
- Alphabet of k names (k = 8, 32, 128): one letter set of many names, few
  minterms; k names told apart (k = 32, 128): every name on its own, the
  minterms being the letters.
- Gaps (`(100 | 101)*`, `(1000 | 1001)*`, `(97 | 89)*`): long sums of whole
  delays, `(a | b)*` against `a*; b*` and against `(a | b + 1)*`.
- Corpus of each regex grade with banked delays: 24 one-sided literals of the
  examples and tests of these grades, 34 with the interval literals, under the
  running times those files declare; elaborate, `leq`, `equal`,
  `counterexample` over all pairs, `inhabited` and `show` of each.
- Delays (n = 8, 128, 1024), k declared names of three running times (k = 8,
  128, 512) and n-th letter from the end (n = 4, 8): the runs of ticks, the
  classes of names of equal running time, and complements, over running times
  with open ends.
- Interval consistency (n = 10, 100), interval grade only: an interval of n
  reads with a common run, one whose upper end permits no run of its lower
  end, and one whose ends last apart.

Rational delays, two columns:

- Typechecking as above, for the `-rational-symbolic` grades.
- Corpora of the rational files: 17 literals of the regular trace languages,
  23 one-sided and 31 with intervals of the regex grades with banked delays.
- Delay sets: nine grades whose sets of delays have long finite parts, or of
  the same shape and small; elaborate, `leq` of a delay below, `equal` with
  the join of that delay, `counterexample`.
- Delays, declared names and interval consistency as above, for the upper
  bound and the interval, over fractional running times with open ends.

Timed regex grades, one column:

- Case-study corpus: 34 literals of the Arduino and Opentrons case studies and
  of `examples/timed_regex`, under the running times their files and packages
  declare on their boards; all pairs as above, `duration_bounds`, `inhabited`
  and `show` of each, under `timed-regex-interval-rational`.
- Calibration window of the balancing robot,
  `[{≥1000 & ~Move}, {≤600000 & ~Move}]`, against two grades of unbounded
  durations; kept out of the corpus, whose all-pairs rows it would dominate.
- Interval consistency (n = 10, 40, 160, 640): a common run found by zones,
  none, and ends whose durations are apart.
- Bounded repetitions (n = 20, 80, 320, 1280): `{(A; idle 25/2)^n}` against
  time spans of 27/2 and of 12 after each `A`, and against a star; the counts
  are not unrolled.
- Time spans absorbing items (k = 10, 100, 1000): `{(Reading; idle 10)^k}`
  against one time span of its greatest length, on the upper side, and against
  `{≥1000 & ~Move}` on the lower side.
- n-th operation from the end (n = 4, 8, 12, 16), whole time steps: the
  nondeterminism of the reader.
- k declared names of three running times (k = 32, 512), whole time steps:
  the classes of names of a world.
- Finite timed regex grades: the 22 literals of the case-study corpus that
  `timed-regex-finite-interval-rational` reads, as a parity check.

The typechecking of the timed regex grades, which needs the packages of the
Arduino backend, is timed by `bench/typecheck`.

## Method

Each measurement runs in a fresh child process, so that the tables the grades
keep start empty. It prepares its inputs untimed and times the operation once
(cold); a typechecking is then repeated for 0.1 s (warm, the mean). The tables
show the medians over 5 processes, fewer once 10 s have been spent; a process
is stopped after 10 s, and the cell then reads `> 10 s`. The ratios are of the
cold times; a ratio is left empty when its denominator is below the
resolution of the clock. The running times of the corpora are read from their
files in a separate child process.

## Measured

- 2026-11-07, at 8b8ebe9a
- Apple M3 Pro, macOS 15.8.2 (Darwin 24.6.0, arm64)
- OCaml 5.5.0, dune 3.24.2, `--profile release`
- Total run time: 13 min 38 s

## Summary

Geometric means of the ratios of the cold times, over the rows in which every
implementation takes at least 5 us and none times out: the mean of the
logarithms of the ratios, exponentiated.

| rows                                     | count | automata / plain | plain / letters | letters / symbolic | automata / symbolic |
| ---------------------------------------- | ----: | ---------------: | --------------: | -----------------: | ------------------: |
| whole time steps, typechecking           |    34 |             1.07 |            1.04 |               1.00 |                1.11 |
| whole time steps, operations             |   204 |             3.92 |            1.19 |               0.93 |                4.34 |
| of which regular trace languages         |    68 |             4.03 |            1.16 |               0.47 |                2.22 |
| of which `banked-regex-lower-bound`      |    44 |             5.28 |            1.57 |               0.66 |                5.46 |
| of which `banked-regex-upper-bound`      |    43 |             3.29 |            0.98 |               1.94 |                6.26 |
| of which `banked-regex-interval`         |    49 |             3.35 |            1.14 |               1.71 |                6.53 |
| rational delays, typechecking            |    22 |                  |                 |                    |                1.03 |
| rational delays, operations              |   113 |                  |                 |                    |                0.60 |
| of which regular trace languages         |    29 |                  |                 |                    |                0.49 |
| of which regex grades with banked delays |    84 |                  |                 |                    |                0.63 |

Typechecking differs little between the implementations: the standard
library dominates it, 13 to 29 ms. The slow cases, not investigated:

- Automata unroll delays into ticks: `(1000 | 1001)*` takes over 10 s in every
  row, the delays of 1024 ticks 0.15 to 7.5 s against at most 11 ms for the
  derivatives, and the n-th letter from the end at n = 16 over 10 s for `E2`.
- Derivatives by single letters, plain and letters, take over 10 s on
  `a*; b* <= (1000 | 1001)*` and the equality, where gap derivatives take 39
  and 13 ms; on the false inclusion of the same family the gap derivatives
  take 38 ms against 25 us.
- Gap derivatives are the slowest on complements of the regex grades with
  banked delays: at n = 8 of the n-th letter from the end, the upper bound and
  the interval take 3.4 s on `leq (B | C)* <= E`, 7.0 to 7.2 s on its
  counterexample and over 10 s on `leq C* <= E2`, where letters take 7 ms and
  305 ms and automata 2.3 to 2.5 ms; the lower bound takes 1.2 s on `leq C* <= E2`.
  Under the regular trace languages, deciding `E = E'` at n = 16 takes over 10
  s, against 2.3 to 3.0 s for the others.
- Rational delays: no cell reaches 1 s. On the delay sets the automata decide
  inclusion and equality in 3 to 106 us, the symbolic expressions in 1 us to
  7.7 ms, which elaborate them 1.0 to 8.4 times faster.
- Timed regex grades: the case-study corpus takes 32 ms for `leq` over all
  1156 pairs, 133 ms for `counterexample`. The calibration window takes over
  10 s on `(ReadEncoders | Setpoints)*` and 206 ms on `(Reading; idle 10)*`.
  Interval consistency by zones grows fast: 0.46 s and 2.3 s at n = 160 and
  over 10 s at n = 640, where the durations decide the third interval in
  5.5 ms. The n-th operation from the end takes 0.09 ms, 3.1 ms, 42 ms and
  1.42 s at n = 4, 8, 12, 16. The true inclusion of the bounded repetitions
  grows superlinearly, 0.66 ms to 208 ms from n = 20 to 1280.

## Results

Median over 5 processes (fewer past 10 s), each stopped after 10 s; cold: first run in a fresh process; warm: mean of repeated runs, for the typechecking; ratios of the cold times of consecutive columns.

### Whole time steps

#### Typechecking

| workload                                              | automata |    plain |  letters | symbolic | aut/plain | plain/let | let/symb | aut. warm | pl. warm | let. warm | sym. warm |
| ----------------------------------------------------- | -------- | -------- | -------- | -------- | --------- | --------- | -------- | --------- | -------- | --------- | --------- |
| **typechecking, regular-trace-languages**             |          |          |          |          |           |           |          |           |          |           |           |
| standard library alone                                | 21.25 ms | 20.09 ms | 19.81 ms | 20.10 ms |      1.06 |      1.01 |     0.99 |  17.39 ms | 16.43 ms |  16.22 ms |  16.23 ms |
| examples/regular_trace_languages/upper_bounds.tpe     | 24.35 ms | 23.01 ms | 22.04 ms | 21.92 ms |      1.06 |      1.04 |     1.01 |  20.40 ms | 19.15 ms |  17.95 ms |  18.02 ms |
| tests/literals_regular.tpe                            | 21.75 ms | 20.59 ms | 20.00 ms | 20.50 ms |      1.06 |      1.03 |     0.98 |  17.80 ms | 16.68 ms |  16.47 ms |  16.57 ms |
| tests/literals_reject_empty.tpe                       | 353.1 us | 340.9 us | 345.0 us | 325.0 us |      1.04 |      0.99 |     1.06 |  133.2 us | 125.0 us |  124.8 us |  125.7 us |
| tests/recursion_effect_regular.tpe                    | 20.86 ms | 20.22 ms | 19.39 ms | 19.48 ms |      1.03 |      1.04 |     1.00 |  18.20 ms | 17.33 ms |  16.94 ms |  16.92 ms |
| tests/recursion_effect_reject_unannotated_regular.tpe | 20.49 ms | 19.62 ms | 19.01 ms | 19.03 ms |      1.04 |      1.03 |     1.00 |  17.96 ms | 16.94 ms |  16.58 ms |  16.58 ms |
| tests/regular_auth.tpe                                | 20.94 ms | 20.18 ms | 19.65 ms | 19.71 ms |      1.04 |      1.03 |     1.00 |  18.69 ms | 17.65 ms |  16.95 ms |  16.94 ms |
| tests/regular_protocol.tpe                            | 22.26 ms | 21.34 ms | 20.01 ms | 20.05 ms |      1.04 |      1.07 |     1.00 |  19.49 ms | 18.42 ms |  17.52 ms |  17.49 ms |
| tests/regular_reject_auth.tpe                         | 20.97 ms | 20.28 ms | 19.61 ms | 19.71 ms |      1.03 |      1.03 |     1.00 |  18.67 ms | 17.53 ms |  16.87 ms |  16.86 ms |
| tests/regular_reject_bounds.tpe                       | 20.39 ms | 19.05 ms | 18.68 ms | 18.53 ms |      1.07 |      1.02 |     1.01 |  17.44 ms | 16.44 ms |  16.21 ms |  16.19 ms |
| tests/regular_reject_counterexample.tpe               | 21.54 ms | 21.10 ms | 19.72 ms | 20.13 ms |      1.02 |      1.07 |     0.98 |  19.30 ms | 17.88 ms |  17.20 ms |  17.21 ms |
| tests/regular_reject_protocol.tpe                     | 21.45 ms | 20.20 ms | 19.33 ms | 19.51 ms |      1.06 |      1.05 |     0.99 |  18.92 ms | 17.57 ms |  16.92 ms |  16.91 ms |
| **typechecking, banked-regex-lower-bound**            |          |          |          |          |           |           |          |           |          |           |           |
| standard library alone                                | 17.55 ms | 17.24 ms | 16.97 ms | 16.80 ms |      1.02 |      1.02 |     1.01 |  13.48 ms | 12.85 ms |  12.63 ms |  12.61 ms |
| examples/banked_regex/lower_bounds.tpe                | 20.03 ms | 18.90 ms | 17.79 ms | 17.82 ms |      1.06 |      1.06 |     1.00 |  15.84 ms | 14.57 ms |  13.54 ms |  13.51 ms |
| tests/banked_regex_lower.tpe                          | 19.32 ms | 19.13 ms | 17.83 ms | 18.20 ms |      1.01 |      1.07 |     0.98 |  15.19 ms | 14.20 ms |  13.38 ms |  13.38 ms |
| tests/banked_regex_lower_reject.tpe                   | 19.80 ms | 18.57 ms | 17.74 ms | 17.67 ms |      1.07 |      1.05 |     1.00 |  15.58 ms | 14.22 ms |  13.52 ms |  13.52 ms |
| tests/banked_regex_lower_ticks_reject.tpe             | 17.73 ms | 17.26 ms | 16.82 ms | 17.03 ms |      1.03 |      1.03 |     0.99 |  13.65 ms | 12.97 ms |  12.68 ms |  12.72 ms |
| **typechecking, banked-regex-upper-bound**            |          |          |          |          |           |           |          |           |          |           |           |
| standard library alone                                | 21.88 ms | 20.62 ms | 19.95 ms | 19.95 ms |      1.06 |      1.03 |     1.00 |  17.02 ms | 15.41 ms |  15.05 ms |  15.08 ms |
| examples/banked_regex/mail_session.tpe                | 28.78 ms | 27.27 ms | 24.86 ms | 24.54 ms |      1.06 |      1.10 |     1.01 |  23.68 ms | 21.48 ms |  18.70 ms |  18.68 ms |
| examples/banked_regex/upper_bounds.tpe                | 25.46 ms | 23.55 ms | 22.23 ms | 22.19 ms |      1.08 |      1.06 |     1.00 |  20.68 ms | 18.07 ms |  16.85 ms |  16.88 ms |
| tests/banked_regex_upper.tpe                          | 24.36 ms | 22.54 ms | 21.47 ms | 21.51 ms |      1.08 |      1.05 |     1.00 |  19.33 ms | 17.19 ms |  16.07 ms |  16.13 ms |
| tests/banked_regex_upper_open.tpe                     | 22.47 ms | 20.78 ms | 20.25 ms | 20.35 ms |      1.08 |      1.03 |     0.99 |  17.63 ms | 15.82 ms |  15.30 ms |  15.29 ms |
| tests/banked_regex_upper_open_reject.tpe              | 23.15 ms | 21.11 ms | 20.71 ms | 20.28 ms |      1.10 |      1.02 |     1.02 |  17.70 ms | 15.90 ms |  15.38 ms |  15.33 ms |
| tests/banked_regex_upper_reject.tpe                   | 24.63 ms | 22.57 ms | 21.34 ms | 21.55 ms |      1.09 |      1.06 |     0.99 |  19.44 ms | 17.36 ms |  16.11 ms |  16.16 ms |
| tests/banked_regex_upper_ticks.tpe                    | 23.02 ms | 21.39 ms | 20.46 ms | 20.41 ms |      1.08 |      1.05 |     1.00 |  17.79 ms | 16.00 ms |  15.41 ms |  15.40 ms |
| tests/banked_regex_upper_ticks_reject.tpe             | 22.19 ms | 20.46 ms | 19.98 ms | 20.23 ms |      1.08 |      1.02 |     0.99 |  17.20 ms | 15.56 ms |  15.12 ms |  15.18 ms |
| **typechecking, banked-regex-interval**               |          |          |          |          |           |           |          |           |          |           |           |
| standard library alone                                | 25.15 ms | 22.20 ms | 20.78 ms | 20.70 ms |      1.13 |      1.07 |     1.00 |  19.86 ms | 17.60 ms |  16.63 ms |  16.64 ms |
| examples/banked_regex/intervals.tpe                   | 28.32 ms | 24.89 ms | 23.57 ms | 23.52 ms |      1.14 |      1.06 |     1.00 |  23.12 ms | 19.82 ms |  18.08 ms |  18.12 ms |
| tests/banked_regex_compound_named_later_reject.tpe    | 25.07 ms | 22.17 ms | 20.81 ms | 20.87 ms |      1.13 |      1.07 |     1.00 |  20.03 ms | 17.62 ms |  16.76 ms |  16.82 ms |
| tests/banked_regex_compound_wildcard.tpe              | 24.80 ms | 21.92 ms | 21.29 ms | 21.76 ms |      1.13 |      1.03 |     0.98 |  20.28 ms | 17.72 ms |  16.95 ms |  17.06 ms |
| tests/banked_regex_interval.tpe                       | 26.14 ms | 22.77 ms | 21.78 ms | 21.77 ms |      1.15 |      1.05 |     1.00 |  21.25 ms | 18.36 ms |  17.27 ms |  17.27 ms |
| tests/banked_regex_interval_no_common_run_reject.tpe  | 24.52 ms | 21.85 ms | 21.55 ms | 21.67 ms |      1.12 |      1.01 |     0.99 |  20.16 ms | 17.68 ms |  16.95 ms |  16.91 ms |
| tests/banked_regex_interval_reject.tpe                | 25.58 ms | 22.42 ms | 21.74 ms | 21.77 ms |      1.14 |      1.03 |     1.00 |  20.88 ms | 18.26 ms |  17.19 ms |  17.17 ms |
| tests/banked_regex_interval_ticks_reject.tpe          | 24.36 ms | 21.82 ms | 21.62 ms | 21.71 ms |      1.12 |      1.01 |     1.00 |  20.03 ms | 17.49 ms |  16.81 ms |  16.85 ms |

#### Grade operations

| workload                                                         |  automata |     plain |   letters |  symbolic | aut/plain | plain/let | let/symb |
| ---------------------------------------------------------------- | --------- | --------- | --------- | --------- | --------- | --------- | -------- |
| **regular-trace-languages: corpus (41 literals)**                |           |           |           |           |           |           |          |
| elaborate                                                        |   3.56 ms |   2.65 ms |  185.0 us |   2.76 ms |      1.35 |     14.31 |     0.07 |
| mul, all pairs                                                   |  15.65 ms |   3.66 ms |  167.1 us |  329.0 us |      4.27 |     21.92 |     0.51 |
| join, all pairs                                                  |  12.56 ms |   3.85 ms |   1.44 ms |   1.40 ms |      3.26 |      2.67 |     1.03 |
| leq, all pairs                                                   |   6.10 ms |   6.66 ms |   4.36 ms |   5.70 ms |      0.92 |      1.53 |     0.77 |
| equal, all pairs                                                 |   21.0 us |   3.92 ms |   1.21 ms |   1.58 ms |      0.01 |      3.23 |     0.77 |
| counterexample, all pairs                                        |  10.89 ms |   6.55 ms |   4.37 ms |   6.99 ms |      1.66 |      1.50 |     0.62 |
| show, each                                                       |   1.24 ms |   1.18 ms |   1.09 ms |   1.08 ms |      1.05 |      1.08 |     1.01 |
| **regular-trace-languages: protocol P^k, k = 8**                 |           |           |           |           |           |           |          |
| mul P^k                                                          |   2.56 ms |    7.9 us |    6.9 us |    5.0 us |    324.88 |      1.14 |     1.38 |
| join J = P \| ... \| P^k                                         |   3.52 ms |   33.9 us |   30.0 us |   28.8 us |    103.85 |      1.13 |     1.04 |
| leq P^k <= P*                                                    |    6.0 us |   2.16 ms |   2.23 ms |   2.24 ms |      0.00 |      0.97 |     1.00 |
| leq P; P* <= J (false)                                           |    6.9 us |   2.32 ms |   2.29 ms |   2.32 ms |      0.00 |      1.01 |     0.99 |
| counterexample P; P*, J                                          |  101.1 us |   92.0 us |   2.45 ms |   2.38 ms |      1.10 |      0.04 |     1.03 |
| equal J \| P; P* = P; P*                                         |   13.1 us |   73.9 us |   2.28 ms |   2.32 ms |      0.18 |      0.03 |     0.98 |
| **regular-trace-languages: protocol P^k, k = 32**                |           |           |           |           |           |           |          |
| mul P^k                                                          |   9.55 ms |   2.35 ms |   2.32 ms |   2.30 ms |      4.06 |      1.01 |     1.01 |
| join J = P \| ... \| P^k                                         |  64.32 ms |   4.18 ms |   4.05 ms |   4.28 ms |     15.41 |      1.03 |     0.95 |
| leq P^k <= P*                                                    |   18.8 us |  256.1 us |  318.1 us |  352.9 us |      0.07 |      0.81 |     0.90 |
| leq P; P* <= J (false)                                           |   21.0 us |   1.54 ms |   1.91 ms |   1.59 ms |      0.01 |      0.81 |     1.20 |
| counterexample P; P*, J                                          |   1.23 ms |   1.52 ms |   1.81 ms |   1.64 ms |      0.81 |      0.84 |     1.11 |
| equal J \| P; P* = P; P*                                         |   56.0 us |   1.49 ms |   1.64 ms |   1.95 ms |      0.04 |      0.90 |     0.84 |
| **regular-trace-languages: nested protocol N_d, d = 3**          |           |           |           |           |           |           |          |
| elaborate N_d                                                    |   2.60 ms |   69.1 us |   75.1 us |   2.41 ms |     37.59 |      0.92 |     0.03 |
| leq N_d <= N_d+1                                                 |    3.1 us |   31.9 us |   31.0 us |   37.0 us |      0.10 |      1.03 |     0.84 |
| counterexample N_d+1, N_d                                        |   40.8 us |   33.9 us |   34.1 us |   43.9 us |      1.20 |      0.99 |     0.78 |
| equal N_d = N_d \| P                                             |    0.0 us |    8.1 us |    8.1 us |   10.0 us |      0.00 |      1.00 |     0.81 |
| **regular-trace-languages: nested protocol N_d, d = 6**          |           |           |           |           |           |           |          |
| elaborate N_d                                                    |   2.96 ms |   2.41 ms |   2.42 ms |   2.48 ms |      1.23 |      1.00 |     0.98 |
| leq N_d <= N_d+1                                                 |    4.1 us |   39.1 us |   36.0 us |   66.0 us |      0.10 |      1.09 |     0.55 |
| counterexample N_d+1, N_d                                        |  104.0 us |   46.0 us |   39.1 us |   86.1 us |      2.26 |      1.18 |     0.45 |
| equal N_d = N_d \| P                                             |    1.0 us |   10.0 us |   10.0 us |   12.2 us |      0.10 |      1.00 |     0.82 |
| **regular-trace-languages: n-th letter from the end, n = 4**     |           |           |           |           |           |           |          |
| elaborate E                                                      |  241.0 us |   56.0 us |   50.1 us |   55.1 us |      4.30 |      1.12 |     0.91 |
| elaborate E2                                                     |   2.82 ms |   60.1 us |   54.1 us |   56.0 us |     46.97 |      1.11 |     0.97 |
| leq (B \| C)* <= E                                               |   2.01 ms |   21.9 us |   14.1 us |  100.1 us |     91.54 |      1.56 |     0.14 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   76.8 us |   51.0 us |   37.0 us |  121.1 us |      1.50 |      1.38 |     0.31 |
| leq C* <= E2                                                     |  288.0 us |   29.1 us |   22.9 us |  122.1 us |      9.90 |      1.27 |     0.19 |
| elaborate E', decide E = E'                                      |   2.32 ms |   2.31 ms |   2.14 ms |   5.18 ms |      1.01 |      1.08 |     0.41 |
| **regular-trace-languages: n-th letter from the end, n = 8**     |           |           |           |           |           |           |          |
| elaborate E                                                      |   6.31 ms |   67.9 us |   52.9 us |   52.9 us |     92.85 |      1.28 |     1.00 |
| elaborate E2                                                     |  43.97 ms |   83.0 us |   62.0 us |   62.0 us |    529.94 |      1.34 |     1.00 |
| leq (B \| C)* <= E                                               |  899.1 us |   23.8 us |   17.2 us |   2.06 ms |     37.71 |      1.39 |     0.01 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   1.05 ms |   86.1 us |   62.0 us |   2.32 ms |     12.15 |      1.39 |     0.03 |
| leq C* <= E2                                                     |   1.02 ms |   30.0 us |   22.9 us |   2.24 ms |     33.95 |      1.31 |     0.01 |
| elaborate E', decide E = E'                                      |   4.50 ms |   8.57 ms |   7.97 ms |  93.88 ms |      0.53 |      1.08 |     0.08 |
| show E2                                                          |    7.2 us |   58.9 us |   42.0 us |   43.9 us |      0.12 |      1.40 |     0.96 |
| **regular-trace-languages: n-th letter from the end, n = 12**    |           |           |           |           |           |           |          |
| elaborate E                                                      |  85.32 ms |   63.9 us |   58.2 us |   57.9 us |   1335.32 |      1.10 |     1.00 |
| elaborate E2                                                     |    4.81 s |   90.1 us |   63.2 us |   64.8 us |  53317.16 |      1.43 |     0.97 |
| leq (B \| C)* <= E                                               |  26.55 ms |   25.0 us |   16.9 us |   2.65 ms |   1060.44 |      1.48 |     0.01 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |  26.82 ms |  104.9 us |   86.1 us |   3.45 ms |    255.65 |      1.22 |     0.02 |
| leq C* <= E2                                                     |  27.07 ms |   30.0 us |   23.8 us |   3.13 ms |    901.17 |      1.26 |     0.01 |
| elaborate E', decide E = E'                                      | 125.08 ms | 109.09 ms | 103.14 ms |    3.31 s |      1.15 |      1.06 |     0.03 |
| show E2                                                          |   11.0 us |   65.1 us |   46.0 us |   47.0 us |      0.17 |      1.41 |     0.98 |
| **regular-trace-languages: n-th letter from the end, n = 16**    |           |           |           |           |           |           |          |
| elaborate E                                                      |    2.00 s |   67.0 us |   59.1 us |   56.0 us |  29830.68 |      1.13 |     1.06 |
| elaborate E2                                                     |    > 10 s |  111.1 us |   72.0 us |   72.0 us |   > 90007 |      1.54 |     1.00 |
| leq (B \| C)* <= E                                               | 632.15 ms |   25.0 us |   16.0 us |   4.09 ms |  25251.54 |      1.57 |     0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       | 629.64 ms |   1.87 ms |   1.97 ms |   4.82 ms |    336.38 |      0.95 |     0.41 |
| leq C* <= E2                                                     |    > 10 s |   28.1 us |   21.9 us |   4.57 ms |  > 355449 |      1.28 |     0.00 |
| elaborate E', decide E = E'                                      |    2.99 s |    2.43 s |    2.28 s |    > 10 s |      1.23 |      1.07 |   < 0.23 |
| **regular-trace-languages: alphabet of k = 8 names**             |           |           |           |           |           |           |          |
| elaborate W, X                                                   |   2.12 ms |   92.0 us |   73.2 us |  107.0 us |     23.02 |      1.26 |     0.68 |
| mul X W                                                          |   11.2 us |    1.0 us |    0.0 us |    1.0 us |     11.75 |           |     0.00 |
| join X W                                                         |    7.9 us |    1.0 us |    0.0 us |    0.0 us |      8.25 |           |          |
| leq X <= W                                                       |    4.1 us |   14.1 us |    8.1 us |   14.8 us |      0.29 |      1.74 |     0.55 |
| leq W <= X (false)                                               |    1.0 us |    4.1 us |    4.1 us |    2.1 us |      0.24 |      1.00 |     1.89 |
| counterexample W, X                                              |    6.9 us |    1.9 us |    2.1 us |    1.9 us |      3.62 |      0.89 |     1.12 |
| equal W = W \| X                                                 |    1.0 us |   24.1 us |   18.8 us |   17.9 us |      0.04 |      1.28 |     1.05 |
| **regular-trace-languages: alphabet of k = 32 names**            |           |           |           |           |           |           |          |
| elaborate W, X                                                   |   3.90 ms |   2.03 ms |  140.9 us |  140.9 us |      1.92 |     14.41 |     1.00 |
| mul X W                                                          |   19.1 us |    4.1 us |    1.0 us |    0.0 us |      4.71 |      4.25 |          |
| join X W                                                         |   12.9 us |    5.0 us |    0.0 us |    1.0 us |      2.57 |           |     0.00 |
| leq X <= W                                                       |    6.2 us |   63.9 us |   1.71 ms |   15.0 us |      0.10 |      0.04 |   113.92 |
| leq W <= X (false)                                               |    3.1 us |   11.2 us |    7.9 us |    3.1 us |      0.28 |      1.42 |     2.54 |
| counterexample W, X                                              |   10.0 us |    4.1 us |    1.0 us |    2.1 us |      2.47 |      4.25 |     0.44 |
| equal W = W \| X                                                 |    0.0 us |  299.9 us |   1.77 ms |   19.1 us |      0.00 |      0.17 |    92.59 |
| **regular-trace-languages: alphabet of k = 128 names**           |           |           |           |           |           |           |          |
| elaborate W, X                                                   |  15.05 ms |   6.97 ms |   2.70 ms |   2.24 ms |      2.16 |      2.58 |     1.21 |
| mul X W                                                          |  104.0 us |   11.0 us |    0.0 us |    0.0 us |      9.48 |           |          |
| join X W                                                         |   73.2 us |   11.0 us |    2.1 us |    0.0 us |      6.67 |      5.11 |          |
| leq X <= W                                                       |   21.9 us |  426.1 us |  126.1 us |   18.1 us |      0.05 |      3.38 |     6.96 |
| leq W <= X (false)                                               |   11.2 us |   42.0 us |   30.0 us |    6.2 us |      0.27 |      1.40 |     4.85 |
| counterexample W, X                                              |   62.0 us |   11.0 us |    1.9 us |    1.0 us |      5.65 |      5.75 |     2.00 |
| equal W = W \| X                                                 |    1.9 us |  469.2 us |  579.8 us |   21.0 us |      0.00 |      0.81 |    27.64 |
| **regular-trace-languages: k = 32 names told apart**             |           |           |           |           |           |           |          |
| elaborate U, V                                                   |  16.20 ms |   2.08 ms |   1.99 ms |   2.56 ms |      7.79 |      1.05 |     0.78 |
| leq U <= V                                                       |   26.9 us |  576.0 us |  579.1 us |   1.61 ms |      0.05 |      0.99 |     0.36 |
| leq V <= U (false)                                               |    4.1 us |   11.9 us |    9.1 us |  321.9 us |      0.34 |      1.32 |     0.03 |
| counterexample V, U                                              |   11.9 us |    5.0 us |    1.0 us |    1.9 us |      2.38 |      5.25 |     0.50 |
| equal V = skip \| U; V                                           |   1.40 ms |   51.0 us |   34.1 us |  887.2 us |     27.46 |      1.50 |     0.04 |
| **regular-trace-languages: k = 128 names told apart**            |           |           |           |           |           |           |          |
| elaborate U, V                                                   |    2.47 s |   9.36 ms |   9.27 ms |  11.22 ms |    264.37 |      1.01 |     0.83 |
| leq U <= V                                                       |  405.1 us |   6.93 ms |   6.92 ms |  12.07 ms |      0.06 |      1.00 |     0.57 |
| leq V <= U (false)                                               |   16.0 us |   52.9 us |   38.9 us |  412.9 us |      0.30 |      1.36 |     0.09 |
| counterexample V, U                                              |   69.1 us |   13.8 us |    1.9 us |    3.8 us |      5.00 |      7.25 |     0.50 |
| equal V = skip \| U; V                                           |  74.69 ms |  146.9 us |   93.0 us |   2.84 ms |    508.57 |      1.58 |     0.03 |
| **regular-trace-languages: gaps, (a \| b)*, a = 100, b = 101**   |           |           |           |           |           |           |          |
| elaborate G                                                      | 260.29 ms |   52.9 us |   51.0 us |   51.0 us |   4917.65 |      1.04 |     1.00 |
| leq a*; b* <= G                                                  |   2.91 ms | 131.75 ms | 135.85 ms |   1.26 ms |      0.02 |      0.97 |   108.24 |
| equal G = a*; b*                                                 |  185.0 us | 121.91 ms | 125.47 ms |  169.0 us |      0.00 |      0.97 |   742.27 |
| leq (a \| b + 1)* <= G (false)                                   |   75.1 us |   24.1 us |   26.9 us |   2.47 ms |      3.12 |      0.89 |     0.01 |
| counterexample (a \| b + 1)*, G                                  |   1.33 ms |   35.0 us |   35.0 us |   2.64 ms |     37.89 |      1.00 |     0.01 |
| **regular-trace-languages: gaps, (a \| b)*, a = 1000, b = 1001** |           |           |           |           |           |           |          |
| elaborate G                                                      |    > 10 s |   68.9 us |   51.0 us |   51.0 us |  > 145132 |      1.35 |     1.00 |
| leq a*; b* <= G                                                  |    > 10 s |    > 10 s |    > 10 s |  39.17 ms |           |           |    > 255 |
| equal G = a*; b*                                                 |    > 10 s |    > 10 s |    > 10 s |  13.06 ms |           |           |    > 766 |
| leq (a \| b + 1)* <= G (false)                                   |    > 10 s |   25.0 us |   25.0 us |  38.31 ms |  > 399458 |      1.00 |     0.00 |
| counterexample (a \| b + 1)*, G                                  |    > 10 s |  114.0 us |  114.9 us |  38.47 ms |   > 87747 |      0.99 |     0.00 |
| **regular-trace-languages: gaps, (a \| b)*, a = 97, b = 89**     |           |           |           |           |           |           |          |
| elaborate G                                                      | 211.23 ms |   57.0 us |   52.0 us |   49.8 us |   3706.97 |      1.10 |     1.04 |
| leq a*; b* <= G                                                  |   2.52 ms | 122.78 ms | 127.00 ms |  283.0 us |      0.02 |      0.97 |   448.75 |
| equal G = a*; b*                                                 |  253.2 us | 112.53 ms | 115.75 ms |  173.1 us |      0.00 |      0.97 |   668.74 |
| leq (a \| b + 1)* <= G (false)                                   |  137.1 us |   21.0 us |   20.0 us |   2.46 ms |      6.53 |      1.05 |     0.01 |
| counterexample (a \| b + 1)*, G                                  |  892.9 us |   30.0 us |   29.8 us |   2.66 ms |     29.72 |      1.01 |     0.01 |
| **banked-regex-lower-bound: corpus (24 literals)**               |           |           |           |           |           |           |          |
| elaborate                                                        |   1.11 ms |  158.1 us |  121.1 us |  165.2 us |      7.02 |      1.31 |     0.73 |
| leq, all pairs                                                   |   6.89 ms |   7.07 ms |   5.77 ms |   5.41 ms |      0.97 |      1.22 |     1.07 |
| equal, all pairs                                                 |   7.02 ms |   7.48 ms |   5.87 ms |   5.40 ms |      0.94 |      1.27 |     1.09 |
| counterexample, all pairs                                        |   7.53 ms |   7.00 ms |   5.87 ms |   5.26 ms |      1.08 |      1.19 |     1.12 |
| inhabited, each                                                  |   1.85 ms |  140.9 us |  139.0 us |  120.9 us |     13.11 |      1.01 |     1.15 |
| show, each                                                       |   1.93 ms |   2.65 ms |   2.38 ms |   2.36 ms |      0.73 |      1.11 |     1.01 |
| **banked-regex-lower-bound: delays, n = 8**                      |           |           |           |           |           |           |          |
| leq T <= S                                                       |   51.0 us |   44.8 us |   31.0 us |   36.0 us |      1.14 |      1.45 |     0.86 |
| leq S <= T (false)                                               |   43.2 us |   41.0 us |   28.1 us |   36.0 us |      1.05 |      1.46 |     0.78 |
| counterexample S, T                                              |   43.2 us |   40.1 us |   28.1 us |   36.0 us |      1.08 |      1.42 |     0.78 |
| leq R <= T                                                       |  769.9 us |   57.0 us |   41.0 us |   30.0 us |     13.51 |      1.39 |     1.37 |
| equal T = T \| R                                                 |  807.0 us |   67.2 us |   53.2 us |   36.0 us |     12.00 |      1.26 |     1.48 |
| **banked-regex-lower-bound: delays, n = 128**                    |           |           |           |           |           |           |          |
| leq T <= S                                                       |   1.62 ms |   49.1 us |   32.9 us |   37.0 us |     33.06 |      1.49 |     0.89 |
| leq S <= T (false)                                               |   1.58 ms |   41.0 us |   28.1 us |   39.1 us |     38.51 |      1.46 |     0.72 |
| counterexample S, T                                              |   1.59 ms |   42.0 us |   30.0 us |   43.9 us |     37.82 |      1.40 |     0.68 |
| leq R <= T                                                       |   8.32 ms |   57.0 us |   45.1 us |   31.2 us |    145.94 |      1.26 |     1.44 |
| equal T = T \| R                                                 |  26.03 ms |   73.0 us |   58.9 us |   38.9 us |    356.80 |      1.24 |     1.52 |
| **banked-regex-lower-bound: delays, n = 1024**                   |           |           |           |           |           |           |          |
| leq T <= S                                                       | 145.04 ms |   54.1 us |   39.8 us |   37.9 us |   2679.86 |      1.36 |     1.05 |
| leq S <= T (false)                                               | 145.15 ms |   45.1 us |   28.8 us |   42.9 us |   3221.20 |      1.56 |     0.67 |
| counterexample S, T                                              | 144.86 ms |   43.2 us |   29.1 us |   42.0 us |   3356.75 |      1.48 |     0.69 |
| leq R <= T                                                       | 706.66 ms |   62.0 us |   47.0 us |   31.0 us |  11399.81 |      1.32 |     1.52 |
| equal T = T \| R                                                 |    2.27 s |   98.9 us |   78.2 us |   40.1 us |  22908.52 |      1.27 |     1.95 |
| **banked-regex-lower-bound: k = 8 declared names**               |           |           |           |           |           |           |          |
| leq X <= W                                                       |   24.1 us |   62.9 us |   52.0 us |   38.1 us |      0.38 |      1.21 |     1.36 |
| leq W <= X (false)                                               |   25.0 us |   51.0 us |   32.2 us |   40.1 us |      0.49 |      1.59 |     0.80 |
| counterexample W, X                                              |   21.0 us |   48.9 us |   30.0 us |   37.0 us |      0.43 |      1.63 |     0.81 |
| leq Y <= {8}                                                     |   57.9 us |   67.9 us |   63.2 us |   41.0 us |      0.85 |      1.08 |     1.54 |
| inhabited X                                                      |   16.9 us |   48.2 us |   35.0 us |   23.1 us |      0.35 |      1.37 |     1.52 |
| **banked-regex-lower-bound: k = 128 declared names**             |           |           |           |           |           |           |          |
| leq X <= W                                                       |  165.9 us |  379.1 us |  172.9 us |   62.0 us |      0.44 |      2.19 |     2.79 |
| leq W <= X (false)                                               |  133.0 us |  286.1 us |   57.9 us |   59.8 us |      0.47 |      4.94 |     0.97 |
| counterexample W, X                                              |  133.0 us |  284.2 us |   57.0 us |   59.8 us |      0.47 |      4.99 |     0.95 |
| leq Y <= {8}                                                     |  401.0 us |  211.0 us |  521.9 us |   38.9 us |      1.90 |      0.40 |    13.43 |
| inhabited X                                                      |   74.9 us |  191.9 us |  119.9 us |   33.1 us |      0.39 |      1.60 |     3.62 |
| **banked-regex-lower-bound: k = 512 declared names**             |           |           |           |           |           |           |          |
| leq X <= W                                                       |   1.22 ms |   4.24 ms |   2.47 ms |  365.0 us |      0.29 |      1.71 |     6.77 |
| leq W <= X (false)                                               |   1.04 ms |   3.36 ms |   1.82 ms |  370.0 us |      0.31 |      1.85 |     4.91 |
| counterexample W, X                                              |   1.05 ms |   3.36 ms |   1.78 ms |  361.0 us |      0.31 |      1.89 |     4.93 |
| leq Y <= {8}                                                     |   1.75 ms |   1.09 ms |   3.22 ms |  282.0 us |      1.61 |      0.34 |    11.42 |
| inhabited X                                                      |  565.1 us |   2.07 ms |   2.23 ms |  294.9 us |      0.27 |      0.93 |     7.55 |
| **banked-regex-lower-bound: n-th letter from the end, n = 4**    |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |   3.32 ms |   72.0 us |   57.9 us |   61.0 us |     46.17 |      1.24 |     0.95 |
| leq (B \| C)* <= E                                               |   59.1 us |   71.0 us |   44.8 us |   3.22 ms |      0.83 |      1.59 |     0.01 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   72.0 us |  772.0 us |   45.1 us |   3.08 ms |      0.09 |     17.13 |     0.01 |
| leq C* <= E2                                                     |   39.8 us |  727.9 us |   59.1 us |   8.45 ms |      0.05 |     12.31 |     0.01 |
| **banked-regex-lower-bound: n-th letter from the end, n = 8**    |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |  46.70 ms |  927.9 us |   64.8 us |   63.2 us |     50.32 |     14.31 |     1.03 |
| leq (B \| C)* <= E                                               |  938.9 us |  762.0 us |   53.9 us |  28.55 ms |      1.23 |     14.14 |     0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |  962.0 us |   32.2 us |   26.9 us |  27.92 ms |     29.89 |      1.19 |     0.00 |
| leq C* <= E2                                                     |   1.00 ms |   31.9 us |  755.1 us |    1.21 s |     31.31 |      0.04 |     0.00 |
| **banked-regex-upper-bound: corpus (24 literals)**               |           |           |           |           |           |           |          |
| elaborate                                                        |   2.57 ms |   2.01 ms |   1.97 ms |   2.04 ms |      1.28 |      1.02 |     0.97 |
| leq, all pairs                                                   |  41.48 ms |  29.21 ms |  29.69 ms |   5.46 ms |      1.42 |      0.98 |     5.44 |
| equal, all pairs                                                 |  42.10 ms |  29.73 ms |  30.00 ms |   5.38 ms |      1.42 |      0.99 |     5.58 |
| counterexample, all pairs                                        |  45.00 ms |  29.76 ms |  30.02 ms |   6.54 ms |      1.51 |      0.99 |     4.59 |
| inhabited, each                                                  |  926.0 us |  142.1 us |  132.1 us |  109.9 us |      6.52 |      1.08 |     1.20 |
| show, each                                                       |  874.0 us |  778.9 us |  726.9 us |  720.0 us |      1.12 |      1.07 |     1.01 |
| **banked-regex-upper-bound: delays, n = 8**                      |           |           |           |           |           |           |          |
| leq T <= S                                                       |   53.9 us |   52.9 us |   48.9 us |   37.9 us |      1.02 |      1.08 |     1.29 |
| leq S <= T (false)                                               |   83.9 us |   64.1 us |   57.0 us |   42.9 us |      1.31 |      1.13 |     1.33 |
| counterexample S, T                                              |  119.9 us |   64.1 us |   57.0 us |   48.2 us |      1.87 |      1.13 |     1.18 |
| leq R <= T                                                       |   96.1 us |   53.9 us |   46.0 us |   31.0 us |      1.78 |      1.17 |     1.48 |
| equal T = T \| R                                                 |  622.0 us |   75.1 us |   62.9 us |   41.0 us |      8.28 |      1.19 |     1.53 |
| **banked-regex-upper-bound: delays, n = 128**                    |           |           |           |           |           |           |          |
| leq T <= S                                                       |   1.63 ms |   52.0 us |   43.9 us |   37.9 us |     31.40 |      1.18 |     1.16 |
| leq S <= T (false)                                               |   9.82 ms |   1.43 ms |   1.41 ms |   1.17 ms |      6.88 |      1.01 |     1.21 |
| counterexample S, T                                              |  21.79 ms |   1.73 ms |   1.68 ms |   1.47 ms |     12.58 |      1.03 |     1.14 |
| leq R <= T                                                       |  11.17 ms |   58.2 us |   48.9 us |   32.9 us |    192.08 |      1.19 |     1.49 |
| equal T = T \| R                                                 |  35.64 ms |   81.1 us |   78.0 us |   50.1 us |    439.71 |      1.04 |     1.56 |
| **banked-regex-upper-bound: delays, n = 1024**                   |           |           |           |           |           |           |          |
| leq T <= S                                                       | 145.03 ms |   68.2 us |   51.0 us |   41.0 us |   2126.86 |      1.34 |     1.24 |
| leq S <= T (false)                                               | 797.41 ms |   6.85 ms |   6.78 ms |   4.67 ms |    116.39 |      1.01 |     1.45 |
| counterexample S, T                                              |    7.51 s |  10.65 ms |  10.55 ms |   8.37 ms |    704.76 |      1.01 |     1.26 |
| leq R <= T                                                       | 939.34 ms |   77.0 us |   65.1 us |   39.8 us |  12197.71 |      1.18 |     1.63 |
| equal T = T \| R                                                 |    3.27 s |  119.0 us |  103.0 us |   44.8 us |  27482.05 |      1.16 |     2.30 |
| **banked-regex-upper-bound: k = 8 declared names**               |           |           |           |           |           |           |          |
| leq X <= W                                                       |   34.1 us |   67.9 us |   51.0 us |   42.9 us |      0.50 |      1.33 |     1.19 |
| leq W <= X (false)                                               |   37.0 us |   93.2 us |   80.1 us |   52.0 us |      0.40 |      1.16 |     1.54 |
| counterexample W, X                                              |   47.9 us |   98.0 us |   86.8 us |   60.1 us |      0.49 |      1.13 |     1.44 |
| leq Y <= {8}                                                     |  172.1 us |  160.0 us |  164.0 us |   54.1 us |      1.08 |      0.98 |     3.03 |
| inhabited X                                                      |   21.9 us |   42.9 us |   32.9 us |   21.0 us |      0.51 |      1.30 |     1.57 |
| **banked-regex-upper-bound: k = 128 declared names**             |           |           |           |           |           |           |          |
| leq X <= W                                                       |  360.0 us |   1.78 ms |   2.44 ms |   66.0 us |      0.20 |      0.73 |    36.97 |
| leq W <= X (false)                                               |  781.1 us |   4.70 ms |   5.53 ms |   74.1 us |      0.17 |      0.85 |    74.55 |
| counterexample W, X                                              |  793.9 us |   4.72 ms |   5.56 ms |   88.0 us |      0.17 |      0.85 |    63.21 |
| leq Y <= {8}                                                     |   8.53 ms |   5.96 ms |   9.92 ms |   52.9 us |      1.43 |      0.60 |   187.38 |
| inhabited X                                                      |   75.8 us |  191.9 us |  660.9 us |   37.0 us |      0.40 |      0.29 |    17.88 |
| **banked-regex-upper-bound: k = 512 declared names**             |           |           |           |           |           |           |          |
| leq X <= W                                                       |   4.09 ms |  26.71 ms |  23.37 ms |   1.77 ms |      0.15 |      1.14 |    13.21 |
| leq W <= X (false)                                               |   8.92 ms |  82.07 ms |  82.02 ms |   1.79 ms |      0.11 |      1.00 |    45.92 |
| counterexample W, X                                              |   9.01 ms |  82.57 ms |  81.48 ms |   1.79 ms |      0.11 |      1.01 |    45.62 |
| leq Y <= {8}                                                     | 113.65 ms |  81.26 ms | 160.38 ms |   79.2 us |      1.40 |      0.51 |  2026.11 |
| inhabited X                                                      |  722.9 us |   1.98 ms |   2.26 ms |   1.68 ms |      0.36 |      0.88 |     1.35 |
| **banked-regex-upper-bound: n-th letter from the end, n = 4**    |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |   1.57 ms |   67.0 us |   56.0 us |   57.0 us |     23.39 |      1.20 |     0.98 |
| leq (B \| C)* <= E                                               |  133.0 us |  648.0 us |  944.9 us |   6.94 ms |      0.21 |      0.69 |     0.14 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |  448.0 us |  675.0 us |  975.8 us |  12.42 ms |      0.66 |      0.69 |     0.08 |
| leq C* <= E2                                                     |  114.0 us |   3.48 ms |   3.29 ms | 417.06 ms |      0.03 |      1.06 |     0.01 |
| **banked-regex-upper-bound: n-th letter from the end, n = 8**    |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |  45.74 ms |   79.9 us |   60.1 us |   62.9 us |    572.67 |      1.33 |     0.95 |
| leq (B \| C)* <= E                                               |   2.35 ms |   6.71 ms |   7.03 ms |    3.36 s |      0.35 |      0.95 |     0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   2.45 ms |   6.62 ms |   7.09 ms |    7.04 s |      0.37 |      0.93 |     0.00 |
| leq C* <= E2                                                     |   2.33 ms | 303.23 ms | 304.67 ms |    > 10 s |      0.01 |      1.00 |   < 0.03 |
| **banked-regex-interval: corpus (34 literals)**                  |           |           |           |           |           |           |          |
| elaborate                                                        |   1.47 ms |  808.0 us |  742.9 us |  769.9 us |      1.82 |      1.09 |     0.97 |
| leq, all pairs                                                   |  74.09 ms |  55.31 ms |  54.41 ms |   8.33 ms |      1.34 |      1.02 |     6.53 |
| equal, all pairs                                                 |  71.54 ms |  54.85 ms |  53.59 ms |   7.25 ms |      1.30 |      1.02 |     7.39 |
| counterexample, all pairs                                        |  23.23 ms |  25.08 ms |  21.94 ms |   9.88 ms |      0.93 |      1.14 |     2.22 |
| inhabited, each                                                  |   1.87 ms |   1.92 ms |   1.85 ms |  626.8 us |      0.97 |      1.04 |     2.95 |
| show, each                                                       |  792.0 us |  735.0 us |  685.9 us |  683.1 us |      1.08 |      1.07 |     1.00 |
| **banked-regex-interval: delays, n = 8**                         |           |           |           |           |           |           |          |
| leq T <= S                                                       |   31.0 us |   53.9 us |   44.1 us |   42.9 us |      0.58 |      1.22 |     1.03 |
| leq S <= T (false)                                               |   51.0 us |  623.0 us |  606.1 us |  616.1 us |      0.08 |      1.03 |     0.98 |
| counterexample S, T                                              |   21.0 us |   34.1 us |   21.9 us |   33.9 us |      0.62 |      1.55 |     0.65 |
| leq R <= T                                                       |   57.0 us |   47.9 us |   42.2 us |   29.1 us |      1.19 |      1.14 |     1.45 |
| equal T = T \| R                                                 |  543.8 us |  625.1 us |  600.1 us |  586.0 us |      0.87 |      1.04 |     1.02 |
| **banked-regex-interval: delays, n = 128**                       |           |           |           |           |           |           |          |
| leq T <= S                                                       |   1.66 ms |  618.0 us |  595.8 us |  609.9 us |      2.69 |      1.04 |     0.98 |
| leq S <= T (false)                                               |   9.91 ms |   1.55 ms |   1.53 ms |  693.1 us |      6.39 |      1.01 |     2.21 |
| counterexample S, T                                              |   1.59 ms |   10.0 us |    6.0 us |   19.1 us |    158.29 |      1.68 |     0.31 |
| leq R <= T                                                       |  11.15 ms |   23.8 us |   45.1 us |   31.9 us |    467.50 |      0.53 |     1.41 |
| equal T = T \| R                                                 |  41.32 ms |   82.0 us |   66.0 us |   42.9 us |    503.77 |      1.24 |     1.54 |
| **banked-regex-interval: delays, n = 1024**                      |           |           |           |           |           |           |          |
| leq T <= S                                                       | 146.01 ms |   73.0 us |   61.0 us |   47.0 us |   2001.34 |      1.20 |     1.30 |
| leq S <= T (false)                                               | 794.23 ms |   6.77 ms |   6.79 ms |   4.63 ms |    117.23 |      1.00 |     1.47 |
| counterexample S, T                                              | 145.23 ms |   39.1 us |   26.0 us |   39.8 us |   3714.13 |      1.50 |     0.65 |
| leq R <= T                                                       | 935.95 ms |   74.1 us |   65.1 us |   34.1 us |  12622.72 |      1.14 |     1.91 |
| equal T = T \| R                                                 |    3.75 s |  118.0 us |   94.2 us |   44.1 us |  31795.24 |      1.25 |     2.14 |
| **banked-regex-interval: k = 8 declared names**                  |           |           |           |           |           |           |          |
| leq X <= W                                                       |  732.2 us |   74.1 us |   59.8 us |   53.9 us |      9.87 |      1.24 |     1.11 |
| leq W <= X (false)                                               |  699.0 us |   91.1 us |   78.0 us |   52.0 us |      7.68 |      1.17 |     1.50 |
| counterexample W, X                                              |  683.1 us |   41.0 us |   27.2 us |   35.0 us |     16.66 |      1.51 |     0.78 |
| leq Y <= {8}                                                     |  919.1 us |  176.0 us |  179.1 us |   63.2 us |      5.22 |      0.98 |     2.83 |
| inhabited X                                                      |  690.0 us |   42.9 us |   34.1 us |   23.1 us |     16.08 |      1.26 |     1.47 |
| **banked-regex-interval: k = 128 declared names**                |           |           |           |           |           |           |          |
| leq X <= W                                                       |  424.9 us |   1.82 ms |   2.47 ms |  114.9 us |      0.23 |      0.74 |    21.51 |
| leq W <= X (false)                                               |  747.9 us |   4.71 ms |   5.26 ms |   88.0 us |      0.16 |      0.90 |    59.76 |
| counterexample W, X                                              |  134.0 us |  284.9 us |   58.2 us |   69.9 us |      0.47 |      4.90 |     0.83 |
| leq Y <= {8}                                                     |   8.46 ms |   6.39 ms |   9.87 ms |   79.2 us |      1.32 |      0.65 |   124.70 |
| inhabited X                                                      |   95.8 us |  222.9 us |  420.1 us |   51.0 us |      0.43 |      0.53 |     8.23 |
| **banked-regex-interval: k = 512 declared names**                |           |           |           |           |           |           |          |
| leq X <= W                                                       |   3.98 ms |  27.11 ms |  22.48 ms |  830.9 us |      0.15 |      1.21 |    27.06 |
| leq W <= X (false)                                               |   8.69 ms |  80.63 ms |  80.54 ms |  757.9 us |      0.11 |      1.00 |   106.26 |
| counterexample W, X                                              |   1.08 ms |   3.36 ms |  403.9 us |  759.1 us |      0.32 |      8.32 |     0.53 |
| leq Y <= {8}                                                     | 114.73 ms |  80.36 ms | 158.20 ms |  122.1 us |      1.43 |      0.51 |  1296.00 |
| inhabited X                                                      |  666.9 us |   2.16 ms |  818.0 us |  736.0 us |      0.31 |      2.64 |     1.11 |
| **banked-regex-interval: n-th letter from the end, n = 4**       |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |   1.79 ms |   71.0 us |   58.2 us |   59.1 us |     25.25 |      1.22 |     0.98 |
| leq (B \| C)* <= E                                               |  135.9 us |  985.9 us |   1.02 ms |   7.40 ms |      0.14 |      0.96 |     0.14 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |  266.1 us |  962.0 us |   1.15 ms |  12.68 ms |      0.28 |      0.84 |     0.09 |
| leq C* <= E2                                                     |   94.2 us |   3.56 ms |   3.42 ms | 408.91 ms |      0.03 |      1.04 |     0.01 |
| **banked-regex-interval: n-th letter from the end, n = 8**       |           |           |           |           |           |           |          |
| elaborate E, E2                                                  |  45.61 ms |   82.0 us |   63.9 us |   62.9 us |    556.11 |      1.28 |     1.02 |
| leq (B \| C)* <= E                                               |   2.38 ms |   6.80 ms |   7.19 ms |    3.37 s |      0.35 |      0.95 |     0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   2.43 ms |   6.78 ms |   7.25 ms |    7.22 s |      0.36 |      0.94 |     0.00 |
| leq C* <= E2                                                     |   2.50 ms | 301.15 ms | 304.97 ms |    > 10 s |      0.01 |      0.99 |   < 0.03 |
| **banked-regex-interval: interval consistency, n = 10**          |           |           |           |           |           |           |          |
| inhabited C                                                      |  469.0 us |  917.9 us |  905.0 us |  761.0 us |      0.51 |      1.01 |     1.19 |
| vacuous I (no common run)                                        |  103.0 us |  140.0 us |  132.1 us |   99.9 us |      0.74 |      1.06 |     1.32 |
| vacuous T (durations apart)                                      |  352.9 us |  742.0 us |  766.0 us |   57.0 us |      0.48 |      0.97 |    13.44 |
| **banked-regex-interval: interval consistency, n = 100**         |           |           |           |           |           |           |          |
| inhabited C                                                      |  19.18 ms |  23.21 ms |  22.30 ms |   1.26 ms |      0.83 |      1.04 |    17.66 |
| vacuous I (no common run)                                        |   4.46 ms |   6.69 ms |   6.54 ms |  783.9 us |      0.67 |      1.02 |     8.35 |
| vacuous T (durations apart)                                      |  43.27 ms |   6.62 ms |   6.49 ms |  448.0 us |      6.54 |      1.02 |    14.49 |

### Rational delays

#### Typechecking

| workload                                                      | automata | symbolic | aut/symb | aut. warm | sym. warm |
| ------------------------------------------------------------- | -------- | -------- | -------- | --------- | --------- |
| **typechecking, regular-trace-languages-rational**            |          |          |          |           |           |
| standard library alone                                        | 18.36 ms | 18.78 ms |     0.98 |  15.64 ms |  16.13 ms |
| examples/introduction/stale_calibration.tpe                   | 19.19 ms | 19.41 ms |     0.99 |  16.51 ms |  16.73 ms |
| examples/regular_trace_languages/upper_bounds_rational.tpe    | 20.05 ms | 19.91 ms |     1.01 |  17.39 ms |  17.22 ms |
| tests/regex_rational.tpe                                      | 19.70 ms | 19.60 ms |     1.01 |  16.94 ms |  17.01 ms |
| tests/regex_rational_reject.tpe                               | 20.01 ms | 19.85 ms |     1.01 |  17.22 ms |  17.22 ms |
| **typechecking, banked-regex-lower-bound-rational**           |          |          |          |           |           |
| standard library alone                                        | 15.52 ms | 15.61 ms |     0.99 |  12.43 ms |  12.46 ms |
| tests/banked_regex_rational_lower.tpe                         | 17.42 ms | 16.67 ms |     1.05 |  14.45 ms |  13.67 ms |
| tests/banked_regex_rational_lower_reject.tpe                  | 16.81 ms | 16.52 ms |     1.02 |  14.02 ms |  13.50 ms |
| **typechecking, banked-regex-upper-bound-rational**           |          |          |          |           |           |
| standard library alone                                        | 18.05 ms | 17.90 ms |     1.01 |  15.13 ms |  15.16 ms |
| examples/banked_regex/upper_bounds_rational.tpe               | 22.66 ms | 20.48 ms |     1.11 |  19.25 ms |  16.98 ms |
| tests/banked_regex_rational_upper.tpe                         | 21.93 ms | 20.01 ms |     1.10 |  18.40 ms |  16.81 ms |
| tests/banked_regex_rational_upper_open.tpe                    | 18.70 ms | 18.54 ms |     1.01 |  15.76 ms |  15.45 ms |
| tests/banked_regex_rational_upper_open_reject.tpe             | 18.82 ms | 18.61 ms |     1.01 |  15.90 ms |  15.49 ms |
| tests/banked_regex_rational_upper_reject.tpe                  | 22.02 ms | 20.48 ms |     1.08 |  18.88 ms |  17.09 ms |
| tests/literals_reject_idle_grade.tpe                          | 372.2 us | 316.1 us |     1.18 |  152.3 us |  132.7 us |
| **typechecking, banked-regex-interval-rational**              |          |          |          |           |           |
| standard library alone                                        | 20.25 ms | 20.47 ms |     0.99 |  16.43 ms |  16.52 ms |
| examples/banked_regex/intervals_rational.tpe                  | 25.08 ms | 23.04 ms |     1.09 |  21.23 ms |  18.45 ms |
| tests/banked_regex_rational_interval.tpe                      | 22.17 ms | 21.45 ms |     1.03 |  17.90 ms |  17.20 ms |
| tests/banked_regex_rational_interval_default_open_reject.tpe  | 21.16 ms | 20.72 ms |     1.02 |  17.10 ms |  16.71 ms |
| tests/banked_regex_rational_interval_no_common_run_reject.tpe | 20.84 ms | 20.57 ms |     1.01 |  16.87 ms |  16.72 ms |
| tests/banked_regex_rational_interval_open_reject.tpe          | 21.06 ms | 20.71 ms |     1.02 |  16.90 ms |  16.69 ms |
| tests/banked_regex_rational_interval_reject.tpe               | 21.69 ms | 21.26 ms |     1.02 |  17.83 ms |  17.19 ms |

#### Grade operations

| workload                                                               |  automata | symbolic | aut/symb |
| ---------------------------------------------------------------------- | --------- | -------- | -------- |
| **regular-trace-languages-rational: corpus (17 literals)**             |           |          |          |
| elaborate                                                              |   2.46 ms | 150.2 us |    16.38 |
| leq, all pairs                                                         |  515.0 us |  1.98 ms |     0.26 |
| equal, all pairs                                                       |    6.0 us |  1.46 ms |     0.00 |
| counterexample, all pairs                                              |   2.47 ms |  2.60 ms |     0.95 |
| show, each                                                             |   15.0 us |  37.9 us |     0.40 |
| **regular-trace-languages-rational: delay set {(100 \| 101)*}**        |           |          |          |
| elaborate G                                                            |   2.00 ms | 239.8 us |     8.36 |
| leq 201 <= G                                                           |    3.8 us |  57.9 us |     0.07 |
| equal G = G \| 201                                                     |    5.0 us |  57.9 us |     0.09 |
| counterexample G, 201                                                  |  546.0 us | 104.2 us |     5.24 |
| **regular-trace-languages-rational: delay set {(300 \| 301)*}**        |           |          |          |
| elaborate G                                                            |   7.32 ms |  3.46 ms |     2.11 |
| leq 601 <= G                                                           |    3.1 us | 749.8 us |     0.00 |
| equal G = G \| 601                                                     |    3.1 us | 735.0 us |     0.00 |
| counterexample G, 601                                                  |  306.1 us |  1.18 ms |     0.26 |
| **regular-trace-languages-rational: delay set {(1000 \| 1001)*}**      |           |          |          |
| elaborate G                                                            |  53.33 ms | 17.83 ms |     2.99 |
| leq 2001 <= G                                                          |    5.0 us |  7.67 ms |     0.00 |
| equal G = G \| 2001                                                    |    5.0 us |  7.69 ms |     0.00 |
| counterexample G, 2001                                                 |   4.50 ms | 12.55 ms |     0.36 |
| **regular-trace-languages-rational: delay set {97*; 89*}**             |           |          |          |
| elaborate G                                                            |   1.96 ms | 242.0 us |     8.09 |
| leq 186 <= G                                                           |    5.0 us |  48.9 us |     0.10 |
| equal G = G \| 186                                                     |    3.1 us |  52.0 us |     0.06 |
| counterexample G, 186                                                  |  519.0 us |  92.0 us |     5.64 |
| **regular-trace-languages-rational: delay set {997*; 991*}**           |           |          |          |
| elaborate G                                                            |  53.46 ms | 18.43 ms |     2.90 |
| leq 1988 <= G                                                          |    6.0 us |  7.68 ms |     0.00 |
| equal G = G \| 1988                                                    |    6.2 us |  7.58 ms |     0.00 |
| counterexample G, 1988                                                 |   4.47 ms | 12.45 ms |     0.36 |
| **regular-trace-languages-rational: delay set {(1 \| (10, 10.001))*}** |           |          |          |
| elaborate G                                                            |  47.11 ms | 45.23 ms |     1.04 |
| leq 1 <= G                                                             |    4.1 us | 113.0 us |     0.04 |
| equal G = G \| 1                                                       |    3.1 us | 115.9 us |     0.03 |
| counterexample G, 1                                                    |  325.9 us | 839.0 us |     0.39 |
| **regular-trace-languages-rational: delay set {(1/97 \| 1/89)*}**      |           |          |          |
| elaborate G                                                            |   2.73 ms | 436.1 us |     6.25 |
| leq 1 <= G                                                             |  105.9 us |  1.49 ms |     0.07 |
| equal G = G \| 1                                                       |  104.9 us |  1.47 ms |     0.07 |
| counterexample G, 1                                                    |  147.1 us |  1.70 ms |     0.09 |
| **regular-trace-languages-rational: delay set {~((300 \| 301)*)}**     |           |          |          |
| elaborate G                                                            |   7.21 ms |  4.41 ms |     1.63 |
| leq 1/2 <= G                                                           |    3.8 us |   1.0 us |     4.00 |
| equal G = G \| 1/2                                                     |    3.1 us |   1.0 us |     3.25 |
| counterexample G, 1/2                                                  |   1.28 ms |  1.69 ms |     0.76 |
| **regular-trace-languages-rational: delay set {[1, 1.001]*}**          |           |          |          |
| elaborate G                                                            |   2.54 ms |  2.15 ms |     1.18 |
| leq 500 <= G                                                           |   11.0 us |  17.2 us |     0.64 |
| equal G = G \| 500                                                     |   10.0 us |  17.2 us |     0.58 |
| counterexample G, 500                                                  |   29.1 us |  67.0 us |     0.43 |
| **banked-regex-lower-bound-rational: corpus (23 literals)**            |           |          |          |
| elaborate                                                              |   2.54 ms |  1.53 ms |     1.67 |
| leq, all pairs                                                         |   1.24 ms |  1.24 ms |     1.00 |
| equal, all pairs                                                       |   1.33 ms |  1.83 ms |     0.73 |
| counterexample, all pairs                                              |   2.61 ms |  2.11 ms |     1.24 |
| inhabited, each                                                        |   21.0 us |  63.9 us |     0.33 |
| show, each                                                             |   20.0 us |  42.9 us |     0.47 |
| **banked-regex-upper-bound-rational: corpus (23 literals)**            |           |          |          |
| elaborate                                                              |   1.83 ms | 124.0 us |    14.75 |
| leq, all pairs                                                         |   2.16 ms |  2.67 ms |     0.81 |
| equal, all pairs                                                       |   2.23 ms |  2.67 ms |     0.83 |
| counterexample, all pairs                                              |   5.94 ms |  3.40 ms |     1.75 |
| inhabited, each                                                        |   20.0 us |  62.2 us |     0.32 |
| show, each                                                             |   16.9 us |  42.9 us |     0.39 |
| **banked-regex-upper-bound-rational: delays, n = 8**                   |           |          |          |
| leq T <= S                                                             |   21.2 us |  36.0 us |     0.59 |
| leq S <= T (false)                                                     |   32.9 us |  50.8 us |     0.65 |
| counterexample S, T                                                    |  445.1 us |  60.1 us |     7.41 |
| leq R <= T                                                             |   21.0 us |  29.8 us |     0.70 |
| equal T = T \| R                                                       |   54.1 us |  42.0 us |     1.29 |
| **banked-regex-upper-bound-rational: delays, n = 128**                 |           |          |          |
| leq T <= S                                                             |   21.0 us |  33.9 us |     0.62 |
| leq S <= T (false)                                                     |   1.51 ms |  2.57 ms |     0.59 |
| counterexample S, T                                                    |   4.70 ms |  2.75 ms |     1.71 |
| leq R <= T                                                             |   21.9 us |  27.9 us |     0.79 |
| equal T = T \| R                                                       |   55.1 us |  42.0 us |     1.31 |
| **banked-regex-upper-bound-rational: delays, n = 1024**                |           |          |          |
| leq T <= S                                                             |   20.0 us |  36.0 us |     0.56 |
| leq S <= T (false)                                                     |   6.63 ms | 11.94 ms |     0.56 |
| counterexample S, T                                                    | 242.75 ms | 18.81 ms |    12.91 |
| leq R <= T                                                             |   23.1 us |  30.0 us |     0.77 |
| equal T = T \| R                                                       |   57.0 us |  42.9 us |     1.33 |
| **banked-regex-upper-bound-rational: k = 8 declared names**            |           |          |          |
| leq X <= W                                                             |  658.0 us |  56.0 us |    11.74 |
| leq W <= X (false)                                                     |   32.2 us | 430.1 us |     0.07 |
| counterexample W, X                                                    |   77.0 us | 432.0 us |     0.18 |
| leq Y <= {8}                                                           |   15.0 us |  42.2 us |     0.36 |
| inhabited X                                                            |   11.0 us |  27.9 us |     0.39 |
| **banked-regex-upper-bound-rational: k = 128 declared names**          |           |          |          |
| leq X <= W                                                             |  501.9 us |  2.49 ms |     0.20 |
| leq W <= X (false)                                                     |   1.04 ms |  3.78 ms |     0.28 |
| counterexample W, X                                                    |   1.07 ms |  3.93 ms |     0.27 |
| leq Y <= {8}                                                           |   25.0 us |  52.9 us |     0.47 |
| inhabited X                                                            |  181.2 us | 742.0 us |     0.24 |
| **banked-regex-upper-bound-rational: k = 512 declared names**          |           |          |          |
| leq X <= W                                                             |   6.54 ms | 12.98 ms |     0.50 |
| leq W <= X (false)                                                     |  14.02 ms | 32.21 ms |     0.44 |
| counterexample W, X                                                    |  13.62 ms | 32.42 ms |     0.42 |
| leq Y <= {8}                                                           |   72.0 us |  73.0 us |     0.99 |
| inhabited X                                                            |   2.06 ms |  2.82 ms |     0.73 |
| **banked-regex-interval-rational: corpus (31 literals)**               |           |          |          |
| elaborate                                                              |   2.24 ms | 175.0 us |    12.78 |
| leq, all pairs                                                         |   4.06 ms |  3.57 ms |     1.14 |
| equal, all pairs                                                       |   3.57 ms |  3.38 ms |     1.05 |
| counterexample, all pairs                                              |  11.99 ms |  4.98 ms |     2.41 |
| inhabited, each                                                        |  119.0 us | 711.0 us |     0.17 |
| show, each                                                             |   31.9 us |  75.8 us |     0.42 |
| **banked-regex-interval-rational: delays, n = 8**                      |           |          |          |
| leq T <= S                                                             |   19.1 us |  38.1 us |     0.50 |
| leq S <= T (false)                                                     |   24.1 us |  52.0 us |     0.46 |
| counterexample S, T                                                    |   14.1 us |  31.9 us |     0.44 |
| leq R <= T                                                             |   14.1 us |  27.9 us |     0.50 |
| equal T = T \| R                                                       |   42.0 us |  41.0 us |     1.02 |
| **banked-regex-interval-rational: delays, n = 128**                    |           |          |          |
| leq T <= S                                                             |   16.0 us |  37.2 us |     0.43 |
| leq S <= T (false)                                                     |   1.50 ms |  2.45 ms |     0.61 |
| counterexample S, T                                                    |   16.9 us |  32.9 us |     0.51 |
| leq R <= T                                                             |   16.0 us |  26.0 us |     0.61 |
| equal T = T \| R                                                       |   44.8 us |  40.1 us |     1.12 |
| **banked-regex-interval-rational: delays, n = 1024**                   |           |          |          |
| leq T <= S                                                             |   18.8 us |  37.0 us |     0.51 |
| leq S <= T (false)                                                     |   6.42 ms | 11.72 ms |     0.55 |
| counterexample S, T                                                    |   19.1 us |  34.1 us |     0.56 |
| leq R <= T                                                             |   16.0 us |  27.9 us |     0.57 |
| equal T = T \| R                                                       |   47.0 us |  42.9 us |     1.09 |
| **banked-regex-interval-rational: k = 8 declared names**               |           |          |          |
| leq X <= W                                                             |   45.1 us |  66.0 us |     0.68 |
| leq W <= X (false)                                                     |   43.2 us |  78.2 us |     0.55 |
| counterexample W, X                                                    |   26.0 us |  44.1 us |     0.59 |
| leq Y <= {8}                                                           |   16.0 us |  40.1 us |     0.40 |
| inhabited X                                                            |   16.0 us |  28.8 us |     0.55 |
| **banked-regex-interval-rational: k = 128 declared names**             |           |          |          |
| leq X <= W                                                             |  915.1 us |  2.66 ms |     0.34 |
| leq W <= X (false)                                                     |   1.03 ms |  3.68 ms |     0.28 |
| counterexample W, X                                                    |  285.1 us |  1.37 ms |     0.21 |
| leq Y <= {8}                                                           |   29.1 us |  34.8 us |     0.84 |
| inhabited X                                                            |  273.0 us | 998.0 us |     0.27 |
| **banked-regex-interval-rational: k = 512 declared names**             |           |          |          |
| leq X <= W                                                             |  10.95 ms | 19.38 ms |     0.56 |
| leq W <= X (false)                                                     |  13.58 ms | 32.46 ms |     0.42 |
| counterexample W, X                                                    |   2.71 ms |  6.86 ms |     0.40 |
| leq Y <= {8}                                                           |   69.9 us | 262.0 us |     0.27 |
| inhabited X                                                            |   2.76 ms |  4.22 ms |     0.65 |
| **banked-regex-interval-rational: interval consistency, n = 10**       |           |          |          |
| inhabited C                                                            |   86.1 us | 600.1 us |     0.14 |
| vacuous I (no common run)                                              |   42.9 us | 508.1 us |     0.08 |
| vacuous T (durations apart)                                            |   35.0 us |  49.8 us |     0.70 |
| **banked-regex-interval-rational: interval consistency, n = 100**      |           |          |          |
| inhabited C                                                            |  690.9 us |  1.19 ms |     0.58 |
| vacuous I (no common run)                                              |  292.8 us |  1.39 ms |     0.21 |
| vacuous T (durations apart)                                            |  199.1 us | 324.0 us |     0.61 |

### Timed regex grades

#### Grade operations

| workload                                                                                       |      time |
| ---------------------------------------------------------------------------------------------- | --------- |
| **timed-regex-interval-rational: case-study corpus (34 literals)**                             |           |
| elaborate                                                                                      |  698.1 us |
| leq, all pairs                                                                                 |  32.32 ms |
| equal, all pairs                                                                               |  29.10 ms |
| counterexample, all pairs                                                                      | 133.46 ms |
| duration_bounds, each                                                                          |   7.36 ms |
| inhabited, each                                                                                |   9.66 ms |
| show, each                                                                                     |   32.9 us |
| **timed-regex-interval-rational: calibration window W = [{≥1000 & ~Move}, {≤600000 & ~Move}]** |           |
| duration_bounds W                                                                              |   42.9 us |
| inhabited W                                                                                    |   35.0 us |
| leq S <= W (false)                                                                             | 205.68 ms |
| leq E <= W (false)                                                                             |    > 10 s |
| **timed-regex-interval-rational: interval consistency, n = 10**                                |           |
| inhabited C                                                                                    |   2.52 ms |
| vacuous I (no common run)                                                                      |   9.51 ms |
| vacuous T (durations apart)                                                                    |   60.1 us |
| **timed-regex-interval-rational: interval consistency, n = 40**                                |           |
| inhabited C                                                                                    |  20.60 ms |
| vacuous I (no common run)                                                                      | 135.78 ms |
| vacuous T (durations apart)                                                                    |  747.9 us |
| **timed-regex-interval-rational: interval consistency, n = 160**                               |           |
| inhabited C                                                                                    | 460.73 ms |
| vacuous I (no common run)                                                                      |    2.31 s |
| vacuous T (durations apart)                                                                    |   2.41 ms |
| **timed-regex-interval-rational: interval consistency, n = 640**                               |           |
| inhabited C                                                                                    |    > 10 s |
| vacuous I (no common run)                                                                      |    > 10 s |
| vacuous T (durations apart)                                                                    |   5.49 ms |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 20**                              |           |
| leq W <= (A; ≤27/2)^n                                                                          |  664.2 us |
| leq W <= (A; ≤12)^n (false)                                                                    |  557.9 us |
| counterexample W, (A; ≤12)^n                                                                   |  556.9 us |
| leq W <= (A \| B \| ≤14)*                                                                      |   42.9 us |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 80**                              |           |
| leq W <= (A; ≤27/2)^n                                                                          |   2.39 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |  672.1 us |
| counterexample W, (A; ≤12)^n                                                                   |  679.0 us |
| leq W <= (A \| B \| ≤14)*                                                                      |  564.1 us |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 320**                             |           |
| leq W <= (A; ≤27/2)^n                                                                          |  14.85 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |   2.37 ms |
| counterexample W, (A; ≤12)^n                                                                   |   2.54 ms |
| leq W <= (A \| B \| ≤14)*                                                                      |   1.59 ms |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 1280**                            |           |
| leq W <= (A; ≤27/2)^n                                                                          | 208.00 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |   7.44 ms |
| counterexample W, (A; ≤12)^n                                                                   |   7.87 ms |
| leq W <= (A \| B \| ≤14)*                                                                      |   3.96 ms |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 10**                       |           |
| duration_bounds A                                                                              |  545.0 us |
| leq A <= ≤L & ~Move                                                                            |  521.9 us |
| leq A <= <L & ~Move (false)                                                                    |  513.1 us |
| counterexample A, <L & ~Move                                                                   |  505.0 us |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 100**                      |           |
| duration_bounds A                                                                              |  675.2 us |
| leq A <= ≤L & ~Move                                                                            |  674.0 us |
| leq A <= <L & ~Move (false)                                                                    |  666.9 us |
| counterexample A, <L & ~Move                                                                   |  701.0 us |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 1000**                     |           |
| duration_bounds A                                                                              |   4.43 ms |
| leq A <= ≤L & ~Move                                                                            |   4.95 ms |
| leq A <= <L & ~Move (false)                                                                    |   5.00 ms |
| counterexample A, <L & ~Move                                                                   |   5.43 ms |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 10**                       |           |
| duration_bounds A                                                                              |  548.1 us |
| leq A <= ≥1000 & ~Move                                                                         |  515.0 us |
| counterexample A, ≥1000 & ~Move                                                                |   23.8 us |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 100**                      |           |
| duration_bounds A                                                                              |  172.9 us |
| leq A <= ≥1000 & ~Move                                                                         |  178.1 us |
| counterexample A, ≥1000 & ~Move                                                                |  173.1 us |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 1000**                     |           |
| duration_bounds A                                                                              |   4.12 ms |
| leq A <= ≥1000 & ~Move                                                                         |   3.09 ms |
| counterexample A, ≥1000 & ~Move                                                                |   3.06 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 4**                                |           |
| leq L <= R                                                                                     |   91.1 us |
| leq L <= R' (false)                                                                            |   88.0 us |
| counterexample L, R'                                                                           |   85.8 us |
| **timed-regex-upper-bound: n-th operation from the end, n = 8**                                |           |
| leq L <= R                                                                                     |   3.14 ms |
| leq L <= R' (false)                                                                            |   3.08 ms |
| counterexample L, R'                                                                           |   3.06 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 12**                               |           |
| leq L <= R                                                                                     |  41.79 ms |
| leq L <= R' (false)                                                                            |  42.02 ms |
| counterexample L, R'                                                                           |  42.21 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 16**                               |           |
| leq L <= R                                                                                     |    1.42 s |
| leq L <= R' (false)                                                                            |    1.42 s |
| counterexample L, R'                                                                           |    1.43 s |
| **timed-regex-upper-bound: k = 32 declared names**                                             |           |
| leq X <= S                                                                                     |   87.0 us |
| leq X <= Op1; (Op2 \| ... \| ≤3)*; Op1                                                         |   76.1 us |
| leq S <= X (false)                                                                             |   48.9 us |
| counterexample S, X                                                                            |   52.0 us |
| **timed-regex-upper-bound: k = 512 declared names**                                            |           |
| leq X <= S                                                                                     |   3.88 ms |
| leq X <= Op1; (Op2 \| ... \| ≤3)*; Op1                                                         |   3.62 ms |
| leq S <= X (false)                                                                             |   2.29 ms |
| counterexample S, X                                                                            |   2.30 ms |
| **timed-regex-finite-interval-rational: star-free case-study corpus (22 literals)**            |           |
| elaborate                                                                                      |  110.9 us |
| leq, all pairs                                                                                 |  22.32 ms |
| equal, all pairs                                                                               |  18.81 ms |
| counterexample, all pairs                                                                      |  69.39 ms |
| duration_bounds, each                                                                          |   7.46 ms |
| inhabited, each                                                                                |   8.01 ms |
| show, each                                                                                     |   21.0 us |
