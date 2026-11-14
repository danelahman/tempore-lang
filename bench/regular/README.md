# Regular grades benchmark

Times the grade operations and the typechecking of the regular trace
languages, the regex grades with banked delays and the timed regex grades,
comparing the implementations of each grade where there are several. Run from
the root of the repository:

    dune exec --profile release bench/regular/bench_regular.exe

A full run takes about 14 minutes. With `--quick` each family is timed at its
first size only, in about 3 minutes.

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
| plain    | `banked-regex-{lower-bound,upper-bound,interval}-letter-derivatives`                | expressions over single letters                            | derivatives by single letters with closures, breadth-first |
| letters  | `banked-regex-{lower-bound,upper-bound,interval}-symbolic-by-letters`               | symbolic expressions over letter sets                      | derivatives by single letters with closures, breadth-first |
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

Each measurement runs in a fresh child process, so that no measurement inherits
the tables the grades filled in another. It prepares its inputs untimed and
times the operation once (cold); a typechecking is then repeated for 0.1 s
(warm, the mean). The tables show the medians over 5 processes, fewer once the
cold times exceed 10 s; a process is stopped after 10 s, and the cell then reads
`> 10 s`. The ratios are of the cold times; a ratio is left empty when its
denominator is below the resolution of the clock. The running times of the
corpora are read from their files in a separate child process.

## Measured

- 2026-11-11, at 050a3898 with the benchmark's updated literals of the Opentrons
  case studies
- Apple M3 Pro, macOS 15.8.2 (Darwin 24.6.0, arm64)
- OCaml 5.5.0, dune 3.24.2, `--profile release`
- Total run time: 13 min 44 s
- `tests/recursion_closure_reject_regular.tpe`, added after 050a3898, is not in
  the tables

## Summary

Geometric means of the ratios of the cold times, over the rows in which every
implementation takes at least 5 us and none times out: the mean of the
logarithms of the ratios, exponentiated.

| rows                                     | count | automata / plain | plain / letters | letters / symbolic | automata / symbolic |
| ---------------------------------------- | ----: | ---------------: | --------------: | -----------------: | ------------------: |
| whole time steps, typechecking           |    34 |             1.07 |            1.04 |               1.00 |                1.12 |
| whole time steps, operations             |   204 |             3.62 |            1.28 |               0.91 |                4.20 |
| of which regular trace languages         |    68 |             3.42 |            1.39 |               0.49 |                2.34 |
| of which `banked-regex-lower-bound`      |    44 |             5.23 |            1.49 |               0.59 |                4.59 |
| of which `banked-regex-upper-bound`      |    43 |             3.03 |            1.04 |               2.11 |                6.67 |
| of which `banked-regex-interval`         |    49 |             3.28 |            1.19 |               1.48 |                5.80 |
| rational delays, typechecking            |    22 |                  |                 |                    |                1.03 |
| rational delays, operations              |   111 |                  |                 |                    |                0.74 |
| of which regular trace languages         |    27 |                  |                 |                    |                0.67 |
| of which regex grades with banked delays |    84 |                  |                 |                    |                0.76 |

Typechecking differs little between the implementations: the standard
library dominates it, 13 to 29 ms. The slow cases, not investigated:

- Automata unroll delays into ticks: `(1000 | 1001)*` takes over 10 s in every
  row, the delays of 1024 ticks 0.14 to 7.5 s against at most 11 ms for the
  derivatives, and the n-th letter from the end at n = 16 over 10 s for `E2`.
- Derivatives by single letters, plain and letters, take over 10 s on
  `a*; b* <= (1000 | 1001)*` and the equality, where gap derivatives take 47
  and 18 ms; on the false inclusion of the same family the gap derivatives
  take 45 ms against 24 us.
- Gap derivatives are the slowest on complements of the regex grades with
  banked delays: at n = 8 of the n-th letter from the end, the upper bound and
  the interval take 3.4 s on `leq (B | C)* <= E`, 7.2 s on its
  counterexample and over 10 s on `leq C* <= E2`, where letters take 7 ms and
  310 to 318 ms and automata 2.4 to 2.7 ms; the lower bound takes 1.2 s on `leq C* <= E2`.
  Under the regular trace languages, deciding `E = E'` at n = 16 takes over 10
  s, against 2.3 to 3.0 s for the others.
- Rational delays: no cell reaches 1 s. On the delay sets the automata decide
  inclusion and equality in 3 to 70 us, the symbolic expressions in 1 us to
  8.4 ms, which elaborate them 1.0 to 2.8 times faster.
- Timed regex grades: the case-study corpus takes 41 ms for `leq` over all
  1156 pairs, 185 ms for `counterexample`. The calibration window takes over
  10 s on `(ReadEncoders | Setpoints)*` and 204 ms on `(Reading; idle 10)*`.
  Interval consistency by zones grows fast: 0.46 s and 2.3 s at n = 160 and
  over 10 s at n = 640, where the durations decide the third interval in
  5.3 ms. The n-th operation from the end takes 0.10 ms, 2.5 ms, 42 ms and
  1.46 s at n = 4, 8, 12, 16. The true inclusion of the bounded repetitions
  grows superlinearly, 0.14 ms to 210 ms from n = 20 to 1280.

## Results

Median over 5 processes (fewer past 10 s), each stopped after 10 s; cold: first run in a fresh process; warm: mean of repeated runs, for the typechecking; ratios of the cold times of consecutive columns.

### Whole time steps

#### Typechecking

| workload                                              |   automata |      plain |    letters |   symbolic |  aut/plain |  plain/let |   let/symb |  aut. warm |   pl. warm |  let. warm |  sym. warm |
| ----------------------------------------------------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| **typechecking, regular-trace-languages**             |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                                |   22.07 ms |   21.14 ms |   20.61 ms |   20.76 ms |       1.04 |       1.03 |       0.99 |   17.79 ms |   16.86 ms |   16.75 ms |   16.76 ms |
| examples/regular_trace_languages/upper_bounds.tpe     |   25.38 ms |   24.10 ms |   22.62 ms |   22.88 ms |       1.05 |       1.07 |       0.99 |   20.89 ms |   19.55 ms |   18.24 ms |   18.40 ms |
| tests/literals_regular.tpe                            |   22.23 ms |   21.09 ms |   21.42 ms |   21.39 ms |       1.05 |       0.98 |       1.00 |   18.29 ms |   17.22 ms |   16.88 ms |   16.94 ms |
| tests/literals_reject_empty.tpe                       |    1.27 ms |    1.28 ms |    1.21 ms |    1.24 ms |       0.99 |       1.06 |       0.98 |   142.3 us |   133.2 us |   131.6 us |   131.5 us |
| tests/recursion_effect_regular.tpe                    |   22.97 ms |   22.37 ms |   21.59 ms |   21.99 ms |       1.03 |       1.04 |       0.98 |   18.65 ms |   17.79 ms |   17.58 ms |   17.33 ms |
| tests/recursion_effect_reject_unannotated_regular.tpe |   22.68 ms |   22.33 ms |   21.34 ms |   21.52 ms |       1.02 |       1.05 |       0.99 |   18.36 ms |   17.62 ms |   17.15 ms |   17.17 ms |
| tests/regular_auth.tpe                                |   23.36 ms |   21.89 ms |   21.46 ms |   21.81 ms |       1.07 |       1.02 |       0.98 |   19.01 ms |   18.01 ms |   17.58 ms |   17.57 ms |
| tests/regular_protocol.tpe                            |   24.51 ms |   22.98 ms |   21.87 ms |   22.38 ms |       1.07 |       1.05 |       0.98 |   20.31 ms |   18.99 ms |   17.90 ms |   18.00 ms |
| tests/regular_reject_auth.tpe                         |   23.01 ms |   21.81 ms |   21.66 ms |   21.72 ms |       1.06 |       1.01 |       1.00 |   18.88 ms |   17.93 ms |   17.57 ms |   17.61 ms |
| tests/regular_reject_bounds.tpe                       |   22.35 ms |   20.66 ms |   20.66 ms |   20.74 ms |       1.08 |       1.00 |       1.00 |   17.92 ms |   17.03 ms |   16.82 ms |   16.86 ms |
| tests/regular_reject_counterexample.tpe               |   23.55 ms |   22.45 ms |   22.01 ms |   22.31 ms |       1.05 |       1.02 |       0.99 |   19.64 ms |   18.48 ms |   17.69 ms |   17.73 ms |
| tests/regular_reject_protocol.tpe                     |   23.53 ms |   22.08 ms |   21.42 ms |   21.61 ms |       1.07 |       1.03 |       0.99 |   19.44 ms |   18.19 ms |   17.45 ms |   17.43 ms |
| **typechecking, banked-regex-lower-bound**            |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                                |   17.48 ms |   16.84 ms |   16.53 ms |   16.98 ms |       1.04 |       1.02 |       0.97 |   13.80 ms |   13.14 ms |   12.91 ms |   12.91 ms |
| examples/banked_regex/lower_bounds.tpe                |   19.97 ms |   18.78 ms |   17.61 ms |   17.66 ms |       1.06 |       1.07 |       1.00 |   16.09 ms |   14.76 ms |   13.88 ms |   13.83 ms |
| tests/banked_regex_lower.tpe                          |   19.41 ms |   18.50 ms |   17.79 ms |   17.67 ms |       1.05 |       1.04 |       1.01 |   15.42 ms |   14.50 ms |   13.77 ms |   13.74 ms |
| tests/banked_regex_lower_reject.tpe                   |   20.34 ms |   19.09 ms |   17.95 ms |   17.88 ms |       1.07 |       1.06 |       1.00 |   15.82 ms |   14.53 ms |   13.85 ms |   13.77 ms |
| tests/banked_regex_lower_ticks_reject.tpe             |   18.12 ms |   17.19 ms |   16.90 ms |   16.66 ms |       1.05 |       1.02 |       1.01 |   13.92 ms |   13.31 ms |   12.93 ms |   12.95 ms |
| **typechecking, banked-regex-upper-bound**            |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                                |   21.57 ms |   19.72 ms |   19.86 ms |   19.45 ms |       1.09 |       0.99 |       1.02 |   17.67 ms |   16.14 ms |   15.66 ms |   15.65 ms |
| examples/banked_regex/mail_session.tpe                |   28.21 ms |   26.76 ms |   24.34 ms |   23.97 ms |       1.05 |       1.10 |       1.02 |   24.36 ms |   22.26 ms |   19.34 ms |   19.23 ms |
| examples/banked_regex/upper_bounds.tpe                |   25.04 ms |   23.23 ms |   21.78 ms |   21.47 ms |       1.08 |       1.07 |       1.01 |   21.50 ms |   18.85 ms |   17.61 ms |   17.49 ms |
| tests/banked_regex_upper.tpe                          |   23.63 ms |   21.75 ms |   20.49 ms |   20.47 ms |       1.09 |       1.06 |       1.00 |   19.95 ms |   17.66 ms |   16.72 ms |   16.81 ms |
| tests/banked_regex_upper_open.tpe                     |   22.27 ms |   20.46 ms |   20.04 ms |   19.37 ms |       1.09 |       1.02 |       1.03 |   18.37 ms |   16.48 ms |   15.95 ms |   15.89 ms |
| tests/banked_regex_upper_open_reject.tpe              |   22.10 ms |   20.46 ms |   19.74 ms |   19.89 ms |       1.08 |       1.04 |       0.99 |   18.37 ms |   16.38 ms |   15.86 ms |   16.14 ms |
| tests/banked_regex_upper_reject.tpe                   |   24.07 ms |   22.48 ms |   20.95 ms |   20.70 ms |       1.07 |       1.07 |       1.01 |   20.42 ms |   18.24 ms |   16.78 ms |   16.88 ms |
| tests/banked_regex_upper_ticks.tpe                    |   22.07 ms |   20.35 ms |   19.80 ms |   19.94 ms |       1.08 |       1.03 |       0.99 |   18.42 ms |   16.69 ms |   15.98 ms |   16.18 ms |
| tests/banked_regex_upper_ticks_reject.tpe             |   21.78 ms |   20.19 ms |   19.27 ms |   19.33 ms |       1.08 |       1.05 |       1.00 |   17.97 ms |   16.34 ms |   15.74 ms |   15.72 ms |
| **typechecking, banked-regex-interval**               |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                                |   24.39 ms |   21.88 ms |   21.04 ms |   21.26 ms |       1.11 |       1.04 |       0.99 |   20.53 ms |   18.07 ms |   17.38 ms |   17.32 ms |
| examples/banked_regex/intervals.tpe                   |   29.04 ms |   25.18 ms |   22.86 ms |   23.08 ms |       1.15 |       1.10 |       0.99 |   23.94 ms |   20.61 ms |   18.56 ms |   18.62 ms |
| tests/banked_regex_compound_named_later_reject.tpe    |   24.59 ms |   22.24 ms |   21.47 ms |   21.32 ms |       1.11 |       1.04 |       1.01 |   20.54 ms |   18.01 ms |   17.35 ms |   17.28 ms |
| tests/banked_regex_compound_wildcard.tpe              |   25.24 ms |   22.45 ms |   21.15 ms |   21.18 ms |       1.12 |       1.06 |       1.00 |   21.02 ms |   18.11 ms |   17.46 ms |   17.52 ms |
| tests/banked_regex_interval.tpe                       |   25.89 ms |   23.18 ms |   21.91 ms |   21.72 ms |       1.12 |       1.06 |       1.01 |   21.70 ms |   18.87 ms |   17.89 ms |   17.84 ms |
| tests/banked_regex_interval_no_common_run_reject.tpe  |   24.73 ms |   22.36 ms |   21.03 ms |   21.02 ms |       1.11 |       1.06 |       1.00 |   20.77 ms |   18.21 ms |   17.38 ms |   17.35 ms |
| tests/banked_regex_interval_reject.tpe                |   25.62 ms |   23.17 ms |   21.48 ms |   21.66 ms |       1.11 |       1.08 |       0.99 |   21.26 ms |   18.83 ms |   17.88 ms |   17.85 ms |
| tests/banked_regex_interval_ticks_reject.tpe          |   24.58 ms |   22.25 ms |   20.97 ms |   20.97 ms |       1.10 |       1.06 |       1.00 |   20.54 ms |   17.99 ms |   17.29 ms |   17.36 ms |

#### Grade operations

| workload                                                         |   automata |      plain |    letters |   symbolic |  aut/plain |  plain/let |   let/symb |
| ---------------------------------------------------------------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| **regular-trace-languages: corpus (41 literals)**                |            |            |            |            |            |            |            |
| elaborate                                                        |    1.52 ms |   203.1 us |   181.0 us |   255.8 us |       7.46 |       1.12 |       0.71 |
| mul, all pairs                                                   |   15.95 ms |    3.74 ms |   597.0 us |   547.9 us |       4.27 |       6.26 |       1.09 |
| join, all pairs                                                  |   12.73 ms |    3.81 ms |    1.67 ms |    1.65 ms |       3.34 |       2.28 |       1.02 |
| leq, all pairs                                                   |    5.37 ms |    7.19 ms |    4.51 ms |    6.26 ms |       0.75 |       1.59 |       0.72 |
| equal, all pairs                                                 |    21.9 us |    3.89 ms |    1.61 ms |    1.93 ms |       0.01 |       2.42 |       0.83 |
| counterexample, all pairs                                        |   10.59 ms |    7.29 ms |    4.57 ms |    7.77 ms |       1.45 |       1.59 |       0.59 |
| show, each                                                       |   598.9 us |    1.70 ms |    1.61 ms |    1.62 ms |       0.35 |       1.05 |       0.99 |
| **regular-trace-languages: protocol P^k, k = 8**                 |            |            |            |            |            |            |            |
| mul P^k                                                          |   559.1 us |     7.9 us |     5.0 us |     6.0 us |      71.06 |       1.57 |       0.84 |
| join J = P \| ... \| P^k                                         |    1.68 ms |    35.0 us |    29.1 us |    26.9 us |      47.88 |       1.20 |       1.08 |
| leq P^k <= P*                                                    |     6.0 us |    45.1 us |    45.1 us |    78.9 us |       0.13 |       1.00 |       0.57 |
| leq P; P* <= J (false)                                           |     6.0 us |   519.0 us |   490.0 us |   528.1 us |       0.01 |       1.06 |       0.93 |
| counterexample P; P*, J                                          |   109.2 us |   510.0 us |   537.2 us |   567.0 us |       0.21 |       0.95 |       0.95 |
| equal J \| P; P* = P; P*                                         |    14.1 us |   506.2 us |   474.9 us |   556.0 us |       0.03 |       1.07 |       0.85 |
| **regular-trace-languages: protocol P^k, k = 32**                |            |            |            |            |            |            |            |
| mul P^k                                                          |    7.54 ms |    93.0 us |    88.0 us |    88.0 us |      81.14 |       1.06 |       1.00 |
| join J = P \| ... \| P^k                                         |   64.61 ms |    2.08 ms |    2.01 ms |    1.97 ms |      30.99 |       1.04 |       1.02 |
| leq P^k <= P*                                                    |    18.8 us |   164.0 us |   157.1 us |   191.9 us |       0.11 |       1.04 |       0.82 |
| leq P; P* <= J (false)                                           |    21.0 us |    2.01 ms |    2.22 ms |    1.89 ms |       0.01 |       0.91 |       1.17 |
| counterexample P; P*, J                                          |    1.25 ms |    2.22 ms |    2.50 ms |    1.97 ms |       0.56 |       0.89 |       1.27 |
| equal J \| P; P* = P; P*                                         |    54.8 us |    2.13 ms |    2.43 ms |    2.41 ms |       0.03 |       0.88 |       1.00 |
| **regular-trace-languages: nested protocol N_d, d = 3**          |            |            |            |            |            |            |            |
| elaborate N_d                                                    |   598.9 us |    66.0 us |    68.2 us |   107.0 us |       9.07 |       0.97 |       0.64 |
| leq N_d <= N_d+1                                                 |     3.1 us |    32.2 us |    28.1 us |    47.0 us |       0.10 |       1.14 |       0.60 |
| counterexample N_d+1, N_d                                        |    43.9 us |    38.9 us |    36.0 us |   453.0 us |       1.13 |       1.08 |       0.08 |
| equal N_d = N_d \| P                                             |     1.0 us |    10.0 us |    10.0 us |    11.9 us |       0.10 |       1.00 |       0.84 |
| **regular-trace-languages: nested protocol N_d, d = 6**          |            |            |            |            |            |            |            |
| elaborate N_d                                                    |    1.37 ms |    75.8 us |    76.1 us |   128.0 us |      18.06 |       1.00 |       0.59 |
| leq N_d <= N_d+1                                                 |     4.1 us |   459.0 us |   451.8 us |   433.0 us |       0.01 |       1.02 |       1.04 |
| counterexample N_d+1, N_d                                        |    84.2 us |   456.1 us |   444.2 us |   449.2 us |       0.18 |       1.03 |       0.99 |
| equal N_d = N_d \| P                                             |     1.0 us |    11.0 us |    10.0 us |    11.9 us |       0.09 |       1.10 |       0.84 |
| **regular-trace-languages: n-th letter from the end, n = 4**     |            |            |            |            |            |            |            |
| elaborate E                                                      |   610.1 us |    53.9 us |    54.8 us |    52.0 us |      11.32 |       0.98 |       1.06 |
| elaborate E2                                                     |    1.59 ms |    61.0 us |    56.0 us |    54.8 us |      26.00 |       1.09 |       1.02 |
| leq (B \| C)* <= E                                               |    39.1 us |    21.0 us |    14.1 us |    85.1 us |       1.86 |       1.49 |       0.17 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   645.9 us |    44.1 us |    33.9 us |   504.0 us |      14.64 |       1.30 |       0.07 |
| leq C* <= E2                                                     |    32.9 us |    26.0 us |    22.2 us |   505.0 us |       1.27 |       1.17 |       0.04 |
| elaborate E', decide E = E'                                      |   834.0 us |    1.29 ms |    1.23 ms |    3.18 ms |       0.64 |       1.05 |       0.39 |
| **regular-trace-languages: n-th letter from the end, n = 8**     |            |            |            |            |            |            |            |
| elaborate E                                                      |    4.83 ms |    59.8 us |    55.1 us |    52.0 us |      80.78 |       1.09 |       1.06 |
| elaborate E2                                                     |   48.64 ms |    71.0 us |    58.9 us |    57.0 us |     684.54 |       1.21 |       1.03 |
| leq (B \| C)* <= E                                               |    1.12 ms |    24.1 us |    16.0 us |   605.1 us |      46.35 |       1.51 |       0.03 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |    1.18 ms |   456.1 us |   453.0 us |    1.33 ms |       2.59 |       1.01 |       0.34 |
| leq C* <= E2                                                     |   942.9 us |   448.2 us |    22.2 us |    1.25 ms |       2.10 |      20.22 |       0.02 |
| elaborate E', decide E = E'                                      |    5.10 ms |    6.92 ms |    6.50 ms |   97.31 ms |       0.74 |       1.06 |       0.07 |
| show E2                                                          |     6.9 us |   512.8 us |   464.0 us |   457.0 us |       0.01 |       1.11 |       1.02 |
| **regular-trace-languages: n-th letter from the end, n = 12**    |            |            |            |            |            |            |            |
| elaborate E                                                      |   91.19 ms |    62.0 us |    54.1 us |    54.1 us |    1471.01 |       1.15 |       1.00 |
| elaborate E2                                                     |     4.78 s |   506.2 us |    67.0 us |    62.0 us |    9442.04 |       7.56 |       1.08 |
| leq (B \| C)* <= E                                               |   27.47 ms |   445.1 us |    16.0 us |    1.54 ms |      61.71 |      27.87 |       0.01 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   27.18 ms |    72.0 us |    62.0 us |    1.57 ms |     377.50 |       1.16 |       0.04 |
| leq C* <= E2                                                     |   28.91 ms |    21.0 us |    21.0 us |    1.34 ms |    1377.74 |       1.00 |       0.02 |
| elaborate E', decide E = E'                                      |  126.27 ms |  111.13 ms |  104.80 ms |     3.26 s |       1.14 |       1.06 |       0.03 |
| show E2                                                          |    10.0 us |    50.1 us |    36.0 us |    36.0 us |       0.20 |       1.39 |       1.00 |
| **regular-trace-languages: n-th letter from the end, n = 16**    |            |            |            |            |            |            |            |
| elaborate E                                                      |     2.00 s |    70.1 us |    58.2 us |    55.1 us |   28574.18 |       1.20 |       1.06 |
| elaborate E2                                                     |     > 10 s |   103.0 us |    68.9 us |    65.1 us |    > 97090 |       1.49 |       1.06 |
| leq (B \| C)* <= E                                               |  630.07 ms |    26.9 us |    16.0 us |    1.94 ms |   23386.69 |       1.69 |       0.01 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |  623.20 ms |   125.9 us |   115.2 us |    2.52 ms |    4950.52 |       1.09 |       0.05 |
| leq C* <= E2                                                     |     > 10 s |    28.1 us |    21.9 us |    2.25 ms |   > 355449 |       1.28 |       0.01 |
| elaborate E', decide E = E'                                      |     2.98 s |     2.43 s |     2.33 s |     > 10 s |       1.23 |       1.04 |     < 0.23 |
| **regular-trace-languages: alphabet of k = 8 names**             |            |            |            |            |            |            |            |
| elaborate W, X                                                   |   232.0 us |    85.8 us |    77.0 us |    94.2 us |       2.70 |       1.11 |       0.82 |
| mul X W                                                          |    12.2 us |     1.2 us |     0.0 us |     2.1 us |      10.20 |            |       0.00 |
| join X W                                                         |     6.9 us |     1.9 us |     1.0 us |     1.9 us |       3.62 |       2.00 |       0.50 |
| leq X <= W                                                       |     4.1 us |    13.8 us |     9.1 us |    13.8 us |       0.29 |       1.53 |       0.66 |
| leq W <= X (false)                                               |     1.2 us |     5.0 us |     3.8 us |     2.1 us |       0.24 |       1.31 |       1.78 |
| counterexample W, X                                              |     7.2 us |     2.1 us |     1.0 us |     1.0 us |       3.33 |       2.25 |       1.00 |
| equal W = W \| X                                                 |     1.0 us |    26.0 us |    19.1 us |    16.9 us |       0.04 |       1.36 |       1.13 |
| **regular-trace-languages: alphabet of k = 32 names**            |            |            |            |            |            |            |            |
| elaborate W, X                                                   |    1.86 ms |   850.0 us |   140.9 us |   131.1 us |       2.19 |       6.03 |       1.07 |
| mul X W                                                          |    18.1 us |     4.1 us |     0.0 us |     0.0 us |       4.47 |            |            |
| join X W                                                         |    12.2 us |     4.1 us |     0.0 us |     0.0 us |       3.00 |            |            |
| leq X <= W                                                       |     6.0 us |    64.8 us |    26.0 us |    14.1 us |       0.09 |       2.50 |       1.85 |
| leq W <= X (false)                                               |     3.1 us |    12.2 us |     9.1 us |     3.8 us |       0.25 |       1.34 |       2.38 |
| counterexample W, X                                              |    10.0 us |     5.0 us |     1.2 us |     1.2 us |       2.00 |       4.20 |       1.00 |
| equal W = W \| X                                                 |     1.0 us |    93.9 us |    62.9 us |    19.1 us |       0.01 |       1.49 |       3.30 |
| **regular-trace-languages: alphabet of k = 128 names**           |            |            |            |            |            |            |            |
| elaborate W, X                                                   |   14.13 ms |    5.96 ms |    1.19 ms |    1.07 ms |       2.37 |       5.02 |       1.11 |
| mul X W                                                          |    96.8 us |    11.0 us |     1.0 us |     0.0 us |       8.83 |      11.50 |            |
| join X W                                                         |    73.9 us |    11.0 us |     1.9 us |     0.0 us |       6.74 |       5.75 |            |
| leq X <= W                                                       |    22.2 us |   449.9 us |   437.0 us |    17.9 us |       0.05 |       1.03 |      24.44 |
| leq W <= X (false)                                               |    11.9 us |    43.9 us |    29.8 us |     6.9 us |       0.27 |       1.47 |       4.31 |
| counterexample W, X                                              |    62.0 us |    11.9 us |     1.0 us |     2.1 us |       5.20 |      12.50 |       0.44 |
| equal W = W \| X                                                 |     2.1 us |   504.0 us |   490.0 us |    21.0 us |       0.00 |       1.03 |      23.35 |
| **regular-trace-languages: k = 32 names told apart**             |            |            |            |            |            |            |            |
| elaborate U, V                                                   |   14.21 ms |   806.1 us |   804.2 us |    1.26 ms |      17.62 |       1.00 |       0.64 |
| leq U <= V                                                       |    26.9 us |   517.1 us |   248.0 us |    1.13 ms |       0.05 |       2.09 |       0.22 |
| leq V <= U (false)                                               |     4.1 us |    13.1 us |    10.0 us |    28.1 us |       0.31 |       1.31 |       0.36 |
| counterexample V, U                                              |    11.0 us |     5.0 us |     2.1 us |     1.0 us |       2.19 |       2.33 |       2.25 |
| equal V = skip \| U; V                                           |    1.48 ms |    53.9 us |    36.0 us |   401.0 us |      27.39 |       1.50 |       0.09 |
| **regular-trace-languages: k = 128 names told apart**            |            |            |            |            |            |            |            |
| elaborate U, V                                                   |     2.48 s |    8.24 ms |    9.35 ms |   11.37 ms |     301.68 |       0.88 |       0.82 |
| leq U <= V                                                       |   420.1 us |   12.81 ms |   11.37 ms |   15.70 ms |       0.03 |       1.13 |       0.72 |
| leq V <= U (false)                                               |    16.0 us |    54.8 us |    42.9 us |   427.0 us |       0.29 |       1.28 |       0.10 |
| counterexample V, U                                              |    81.1 us |    14.1 us |     2.1 us |     1.0 us |       5.76 |       6.56 |       2.25 |
| equal V = skip \| U; V                                           |   74.87 ms |   155.9 us |   104.0 us |    2.78 ms |     480.17 |       1.50 |       0.04 |
| **regular-trace-languages: gaps, (a \| b)*, a = 100, b = 101**   |            |            |            |            |            |            |            |
| elaborate G                                                      |  267.83 ms |    56.0 us |    56.0 us |    50.1 us |    4780.18 |       1.00 |       1.12 |
| leq a*; b* <= G                                                  |    3.23 ms |  136.45 ms |  138.66 ms |    1.53 ms |       0.02 |       0.98 |      90.50 |
| equal G = a*; b*                                                 |   131.8 us |  125.39 ms |  128.82 ms |   156.9 us |       0.00 |       0.97 |     821.11 |
| leq (a \| b + 1)* <= G (false)                                   |    64.1 us |    24.1 us |    25.0 us |    1.94 ms |       2.66 |       0.96 |       0.01 |
| counterexample (a \| b + 1)*, G                                  |    1.13 ms |    33.1 us |    35.0 us |    1.87 ms |      34.16 |       0.95 |       0.02 |
| **regular-trace-languages: gaps, (a \| b)*, a = 1000, b = 1001** |            |            |            |            |            |            |            |
| elaborate G                                                      |     > 10 s |    68.9 us |    53.2 us |    50.1 us |   > 145132 |       1.30 |       1.06 |
| leq a*; b* <= G                                                  |     > 10 s |     > 10 s |     > 10 s |   46.71 ms |            |            |      > 214 |
| equal G = a*; b*                                                 |     > 10 s |     > 10 s |     > 10 s |   17.76 ms |            |            |      > 563 |
| leq (a \| b + 1)* <= G (false)                                   |     > 10 s |    23.8 us |    23.8 us |   45.09 ms |   > 419430 |       1.00 |       0.00 |
| counterexample (a \| b + 1)*, G                                  |     > 10 s |   664.0 us |   661.8 us |   44.92 ms |    > 15060 |       1.00 |       0.01 |
| **regular-trace-languages: gaps, (a \| b)*, a = 97, b = 89**     |            |            |            |            |            |            |            |
| elaborate G                                                      |  218.74 ms |    54.1 us |    54.8 us |    50.1 us |    4041.65 |       0.99 |       1.10 |
| leq a*; b* <= G                                                  |    2.51 ms |  126.15 ms |  127.27 ms |    1.42 ms |       0.02 |       0.99 |      89.75 |
| equal G = a*; b*                                                 |    98.2 us |  116.70 ms |  118.47 ms |   164.0 us |       0.00 |       0.99 |     722.27 |
| leq (a \| b + 1)* <= G (false)                                   |    47.0 us |    18.1 us |    25.0 us |    2.03 ms |       2.59 |       0.72 |       0.01 |
| counterexample (a \| b + 1)*, G                                  |   998.0 us |    25.0 us |    28.1 us |    2.01 ms |      39.87 |       0.89 |       0.01 |
| **banked-regex-lower-bound: corpus (24 literals)**               |            |            |            |            |            |            |            |
| elaborate                                                        |    1.12 ms |   686.9 us |   664.0 us |   691.2 us |       1.63 |       1.03 |       0.96 |
| leq, all pairs                                                   |    4.71 ms |    4.55 ms |    3.16 ms |    2.89 ms |       1.04 |       1.44 |       1.10 |
| equal, all pairs                                                 |    4.88 ms |    4.84 ms |    3.25 ms |    2.96 ms |       1.01 |       1.49 |       1.10 |
| counterexample, all pairs                                        |    5.48 ms |    4.52 ms |    3.20 ms |    2.99 ms |       1.21 |       1.41 |       1.07 |
| inhabited, each                                                  |   347.9 us |   133.0 us |   127.1 us |   105.9 us |       2.61 |       1.05 |       1.20 |
| show, each                                                       |   309.0 us |   573.2 us |   508.1 us |   505.9 us |       0.54 |       1.13 |       1.00 |
| **banked-regex-lower-bound: delays, n = 8**                      |            |            |            |            |            |            |            |
| leq T <= S                                                       |    44.1 us |   600.1 us |    28.8 us |   582.2 us |       0.07 |      20.80 |       0.05 |
| leq S <= T (false)                                               |    40.1 us |   582.9 us |   571.0 us |    38.1 us |       0.07 |       1.02 |      14.97 |
| counterexample S, T                                              |    41.0 us |    36.0 us |    23.8 us |    37.0 us |       1.14 |       1.51 |       0.65 |
| leq R <= T                                                       |    88.0 us |    48.2 us |    36.0 us |    31.9 us |       1.83 |       1.34 |       1.13 |
| equal T = T \| R                                                 |   376.0 us |    61.0 us |    48.9 us |    36.0 us |       6.16 |       1.25 |       1.36 |
| **banked-regex-lower-bound: delays, n = 128**                    |            |            |            |            |            |            |            |
| leq T <= S                                                       |    1.77 ms |    42.0 us |    27.9 us |    34.1 us |      42.16 |       1.50 |       0.82 |
| leq S <= T (false)                                               |    1.74 ms |    37.9 us |    22.9 us |    35.0 us |      45.82 |       1.66 |       0.65 |
| counterexample S, T                                              |    1.72 ms |    38.1 us |    23.8 us |    37.0 us |      45.19 |       1.60 |       0.65 |
| leq R <= T                                                       |    9.12 ms |    52.0 us |    37.0 us |    31.0 us |     175.51 |       1.41 |       1.19 |
| equal T = T \| R                                                 |   28.22 ms |    64.1 us |    52.9 us |    38.9 us |     440.06 |       1.21 |       1.36 |
| **banked-regex-lower-bound: delays, n = 1024**                   |            |            |            |            |            |            |            |
| leq T <= S                                                       |  146.65 ms |    49.8 us |    36.0 us |    36.0 us |    2943.08 |       1.38 |       1.00 |
| leq S <= T (false)                                               |  145.70 ms |    39.1 us |    25.0 us |    37.9 us |    3726.36 |       1.56 |       0.66 |
| counterexample S, T                                              |  145.74 ms |    41.0 us |    24.8 us |    43.2 us |    3553.94 |       1.65 |       0.57 |
| leq R <= T                                                       |  702.04 ms |    62.9 us |    46.0 us |    34.8 us |   11153.59 |       1.37 |       1.32 |
| equal T = T \| R                                                 |     2.25 s |    89.2 us |    69.9 us |    42.0 us |   25234.54 |       1.28 |       1.66 |
| **banked-regex-lower-bound: k = 8 declared names**               |            |            |            |            |            |            |            |
| leq X <= W                                                       |    37.0 us |    55.8 us |    40.1 us |    35.0 us |       0.66 |       1.39 |       1.14 |
| leq W <= X (false)                                               |    31.9 us |    42.2 us |    26.9 us |    35.0 us |       0.76 |       1.57 |       0.77 |
| counterexample W, X                                              |    32.9 us |    45.1 us |    26.9 us |    36.0 us |       0.73 |       1.67 |       0.75 |
| leq Y <= {8}                                                     |    73.2 us |    66.0 us |    57.0 us |    40.1 us |       1.11 |       1.16 |       1.42 |
| inhabited X                                                      |    24.1 us |    42.0 us |    31.9 us |    21.9 us |       0.57 |       1.31 |       1.46 |
| **banked-regex-lower-bound: k = 128 declared names**             |            |            |            |            |            |            |            |
| leq X <= W                                                       |   184.1 us |   453.9 us |   474.9 us |    83.2 us |       0.41 |       0.96 |       5.71 |
| leq W <= X (false)                                               |   151.9 us |   364.1 us |    74.1 us |    82.0 us |       0.42 |       4.91 |       0.90 |
| counterexample W, X                                              |   154.0 us |   320.0 us |    75.1 us |    82.0 us |       0.48 |       4.26 |       0.92 |
| leq Y <= {8}                                                     |   424.1 us |   339.0 us |   649.9 us |    54.1 us |       1.25 |       0.52 |      12.01 |
| inhabited X                                                      |    91.1 us |   222.9 us |   417.0 us |    47.0 us |       0.41 |       0.53 |       8.88 |
| **banked-regex-lower-bound: k = 512 declared names**             |            |            |            |            |            |            |            |
| leq X <= W                                                       |    1.25 ms |    4.36 ms |    1.51 ms |    2.30 ms |       0.29 |       2.89 |       0.66 |
| leq W <= X (false)                                               |    1.05 ms |    3.63 ms |   845.9 us |    2.29 ms |       0.29 |       4.29 |       0.37 |
| counterexample W, X                                              |    1.04 ms |    3.64 ms |   859.0 us |    2.27 ms |       0.29 |       4.23 |       0.38 |
| leq Y <= {8}                                                     |    2.16 ms |    1.29 ms |    6.51 ms |    78.9 us |       1.68 |       0.20 |      82.52 |
| inhabited X                                                      |   560.0 us |    2.07 ms |    1.37 ms |    86.1 us |       0.27 |       1.51 |      15.93 |
| **banked-regex-lower-bound: n-th letter from the end, n = 4**    |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   984.2 us |    70.8 us |    59.1 us |    57.9 us |      13.90 |       1.20 |       1.02 |
| leq (B \| C)* <= E                                               |    74.1 us |    67.0 us |    45.1 us |    1.03 ms |       1.11 |       1.49 |       0.04 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |    81.1 us |    57.2 us |    41.0 us |   975.1 us |       1.42 |       1.40 |       0.04 |
| leq C* <= E2                                                     |    51.0 us |    67.9 us |    56.0 us |    6.84 ms |       0.75 |       1.21 |       0.01 |
| **banked-regex-lower-bound: n-th letter from the end, n = 8**    |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   51.64 ms |    89.9 us |    65.1 us |    63.2 us |     574.47 |       1.38 |       1.03 |
| leq (B \| C)* <= E                                               |    1.04 ms |    66.0 us |    50.1 us |   32.04 ms |      15.79 |       1.32 |       0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |    1.13 ms |    67.0 us |    51.0 us |   32.12 ms |      16.85 |       1.31 |       0.00 |
| leq C* <= E2                                                     |   878.1 us |    75.8 us |    56.0 us |     1.20 s |      11.58 |       1.35 |       0.00 |
| **banked-regex-upper-bound: corpus (24 literals)**               |            |            |            |            |            |            |            |
| elaborate                                                        |   726.0 us |   140.0 us |   125.9 us |   160.0 us |       5.19 |       1.11 |       0.79 |
| leq, all pairs                                                   |   42.32 ms |   29.77 ms |   30.06 ms |    4.48 ms |       1.42 |       0.99 |       6.71 |
| equal, all pairs                                                 |   42.39 ms |   29.98 ms |   30.17 ms |    4.63 ms |       1.41 |       0.99 |       6.52 |
| counterexample, all pairs                                        |   45.83 ms |   30.17 ms |   30.19 ms |    5.62 ms |       1.52 |       1.00 |       5.37 |
| inhabited, each                                                  |   332.1 us |   365.0 us |   343.1 us |   309.9 us |       0.91 |       1.06 |       1.11 |
| show, each                                                       |   304.9 us |   674.0 us |   604.9 us |   622.0 us |       0.45 |       1.11 |       0.97 |
| **banked-regex-upper-bound: delays, n = 8**                      |            |            |            |            |            |            |            |
| leq T <= S                                                       |    52.9 us |    51.0 us |    41.0 us |    42.0 us |       1.04 |       1.24 |       0.98 |
| leq S <= T (false)                                               |    87.0 us |    62.0 us |    52.0 us |    47.0 us |       1.40 |       1.19 |       1.11 |
| counterexample S, T                                              |   119.0 us |    63.9 us |    55.8 us |    52.0 us |       1.86 |       1.15 |       1.07 |
| leq R <= T                                                       |    98.0 us |    53.2 us |    43.9 us |    34.1 us |       1.84 |       1.21 |       1.29 |
| equal T = T \| R                                                 |   281.8 us |    73.9 us |    63.2 us |    44.8 us |       3.81 |       1.17 |       1.41 |
| **banked-regex-upper-bound: delays, n = 128**                    |            |            |            |            |            |            |            |
| leq T <= S                                                       |    1.80 ms |    50.8 us |    42.0 us |    40.1 us |      35.38 |       1.21 |       1.05 |
| leq S <= T (false)                                               |   10.70 ms |   974.2 us |   985.1 us |   664.0 us |      10.98 |       0.99 |       1.48 |
| counterexample S, T                                              |   22.80 ms |    1.06 ms |    1.04 ms |   772.0 us |      21.51 |       1.02 |       1.35 |
| leq R <= T                                                       |   12.08 ms |    58.9 us |    47.0 us |    35.0 us |     205.20 |       1.25 |       1.34 |
| equal T = T \| R                                                 |   41.52 ms |   309.0 us |   295.9 us |    45.1 us |     134.38 |       1.04 |       6.57 |
| **banked-regex-upper-bound: delays, n = 1024**                   |            |            |            |            |            |            |            |
| leq T <= S                                                       |  145.30 ms |    66.0 us |    52.9 us |    46.0 us |    2200.13 |       1.25 |       1.15 |
| leq S <= T (false)                                               |  800.83 ms |    6.63 ms |    6.74 ms |    4.44 ms |     120.81 |       0.98 |       1.52 |
| counterexample S, T                                              |     7.47 s |   10.41 ms |   10.44 ms |    8.14 ms |     717.65 |       1.00 |       1.28 |
| leq R <= T                                                       |  939.12 ms |   315.0 us |   288.0 us |    36.0 us |    2981.80 |       1.09 |       8.00 |
| equal T = T \| R                                                 |     3.30 s |   357.2 us |   325.2 us |   254.9 us |    9243.31 |       1.10 |       1.28 |
| **banked-regex-upper-bound: k = 8 declared names**               |            |            |            |            |            |            |            |
| leq X <= W                                                       |    44.8 us |    70.8 us |    51.0 us |    47.9 us |       0.63 |       1.39 |       1.06 |
| leq W <= X (false)                                               |    52.0 us |    99.9 us |    83.0 us |    60.1 us |       0.52 |       1.20 |       1.38 |
| counterexample W, X                                              |    68.9 us |   102.0 us |    84.9 us |    67.0 us |       0.68 |       1.20 |       1.27 |
| leq Y <= {8}                                                     |   232.0 us |   166.9 us |   161.9 us |    57.0 us |       1.39 |       1.03 |       2.84 |
| inhabited X                                                      |    25.0 us |    43.9 us |    32.2 us |    25.0 us |       0.57 |       1.36 |       1.29 |
| **banked-regex-upper-bound: k = 128 declared names**             |            |            |            |            |            |            |            |
| leq X <= W                                                       |   378.1 us |    1.88 ms |    2.16 ms |    94.9 us |       0.20 |       0.87 |      22.74 |
| leq W <= X (false)                                               |   834.9 us |    4.88 ms |    5.10 ms |   104.2 us |       0.17 |       0.96 |      48.92 |
| counterexample W, X                                              |   833.0 us |    4.87 ms |    5.08 ms |   110.9 us |       0.17 |       0.96 |      45.85 |
| leq Y <= {8}                                                     |    8.48 ms |    6.10 ms |    9.82 ms |    74.9 us |       1.39 |       0.62 |     131.12 |
| inhabited X                                                      |    91.1 us |   263.0 us |   131.1 us |    52.0 us |       0.35 |       2.01 |       2.52 |
| **banked-regex-upper-bound: k = 512 declared names**             |            |            |            |            |            |            |            |
| leq X <= W                                                       |    4.06 ms |   27.19 ms |   26.38 ms |   172.9 us |       0.15 |       1.03 |     152.59 |
| leq W <= X (false)                                               |    9.44 ms |   82.67 ms |   84.87 ms |   629.9 us |       0.11 |       0.97 |     134.74 |
| counterexample W, X                                              |    9.37 ms |   82.13 ms |   85.19 ms |   660.9 us |       0.11 |       0.96 |     128.89 |
| leq Y <= {8}                                                     |  111.36 ms |   82.69 ms |  163.23 ms |    81.1 us |       1.35 |       0.51 |    2013.59 |
| inhabited X                                                      |   576.0 us |    2.00 ms |    4.20 ms |    83.9 us |       0.29 |       0.48 |      50.02 |
| **banked-regex-upper-bound: n-th letter from the end, n = 4**    |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   881.0 us |    73.9 us |    60.8 us |    59.1 us |      11.92 |       1.22 |       1.03 |
| leq (B \| C)* <= E                                               |   145.0 us |   389.1 us |   437.0 us |    7.55 ms |       0.37 |       0.89 |       0.06 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   153.1 us |   410.1 us |   410.1 us |   17.69 ms |       0.37 |       1.00 |       0.02 |
| leq C* <= E2                                                     |   134.0 us |    2.71 ms |    2.58 ms |  422.51 ms |       0.05 |       1.05 |       0.01 |
| **banked-regex-upper-bound: n-th letter from the end, n = 8**    |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   50.98 ms |    87.0 us |    66.0 us |    61.0 us |     585.78 |       1.32 |       1.08 |
| leq (B \| C)* <= E                                               |    2.56 ms |    6.03 ms |    6.80 ms |     3.44 s |       0.42 |       0.89 |       0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |    2.71 ms |    6.12 ms |    6.78 ms |     7.20 s |       0.44 |       0.90 |       0.00 |
| leq C* <= E2                                                     |    2.47 ms |  305.07 ms |  318.20 ms |     > 10 s |       0.01 |       0.96 |    < 0.032 |
| **banked-regex-interval: corpus (34 literals)**                  |            |            |            |            |            |            |            |
| elaborate                                                        |   738.9 us |   170.9 us |   145.9 us |   206.0 us |       4.32 |       1.17 |       0.71 |
| leq, all pairs                                                   |   80.40 ms |   57.12 ms |   55.80 ms |    8.31 ms |       1.41 |       1.02 |       6.71 |
| equal, all pairs                                                 |   76.91 ms |   56.17 ms |   53.93 ms |    7.17 ms |       1.37 |       1.04 |       7.53 |
| counterexample, all pairs                                        |   23.56 ms |   25.42 ms |   22.16 ms |    9.85 ms |       0.93 |       1.15 |       2.25 |
| inhabited, each                                                  |    1.45 ms |    1.60 ms |    1.62 ms |   551.9 us |       0.90 |       0.99 |       2.93 |
| show, each                                                       |   520.0 us |   579.8 us |   535.0 us |   523.1 us |       0.90 |       1.08 |       1.02 |
| **banked-regex-interval: delays, n = 8**                         |            |            |            |            |            |            |            |
| leq T <= S                                                       |    60.1 us |    55.8 us |    43.9 us |    44.1 us |       1.08 |       1.27 |       0.99 |
| leq S <= T (false)                                               |    82.0 us |    61.0 us |    50.1 us |    43.9 us |       1.34 |       1.22 |       1.14 |
| counterexample S, T                                              |    42.9 us |    36.0 us |    24.1 us |    35.0 us |       1.19 |       1.50 |       0.69 |
| leq R <= T                                                       |    97.0 us |    51.0 us |    42.0 us |    33.1 us |       1.90 |       1.22 |       1.27 |
| equal T = T \| R                                                 |   442.0 us |    73.9 us |    60.8 us |    42.9 us |       5.98 |       1.22 |       1.42 |
| **banked-regex-interval: delays, n = 128**                       |            |            |            |            |            |            |            |
| leq T <= S                                                       |    1.87 ms |    57.0 us |    44.1 us |    41.0 us |      32.83 |       1.29 |       1.08 |
| leq S <= T (false)                                               |   10.74 ms |   823.0 us |   804.9 us |   555.0 us |      13.04 |       1.02 |       1.45 |
| counterexample S, T                                              |    1.71 ms |    36.0 us |    24.1 us |    33.9 us |      47.50 |       1.50 |       0.71 |
| leq R <= T                                                       |   12.07 ms |    57.9 us |    46.0 us |    31.9 us |     208.33 |       1.26 |       1.44 |
| equal T = T \| R                                                 |   47.50 ms |    83.9 us |    67.9 us |    44.1 us |     565.98 |       1.24 |       1.54 |
| **banked-regex-interval: delays, n = 1024**                      |            |            |            |            |            |            |            |
| leq T <= S                                                       |  145.96 ms |    76.8 us |    61.0 us |    45.1 us |    1901.23 |       1.26 |       1.35 |
| leq S <= T (false)                                               |  796.03 ms |    6.46 ms |    6.62 ms |    4.34 ms |     123.28 |       0.98 |       1.53 |
| counterexample S, T                                              |  143.60 ms |    37.2 us |    26.0 us |    42.0 us |    3860.83 |       1.43 |       0.62 |
| leq R <= T                                                       |  936.03 ms |    72.0 us |    57.9 us |    36.0 us |   13000.04 |       1.24 |       1.61 |
| equal T = T \| R                                                 |     3.77 s |   123.0 us |   100.1 us |    49.1 us |   30657.38 |       1.23 |       2.04 |
| **banked-regex-interval: k = 8 declared names**                  |            |            |            |            |            |            |            |
| leq X <= W                                                       |    48.9 us |    81.1 us |    62.9 us |    55.1 us |       0.60 |       1.29 |       1.14 |
| leq W <= X (false)                                               |    47.0 us |    99.9 us |    78.0 us |    55.1 us |       0.47 |       1.28 |       1.42 |
| counterexample W, X                                              |    36.0 us |    45.1 us |    26.2 us |    33.9 us |       0.80 |       1.72 |       0.77 |
| leq Y <= {8}                                                     |   397.9 us |   189.1 us |   188.1 us |    66.0 us |       2.10 |       1.01 |       2.85 |
| inhabited X                                                      |    26.9 us |    45.1 us |    35.0 us |    23.1 us |       0.60 |       1.29 |       1.52 |
| **banked-regex-interval: k = 128 declared names**                |            |            |            |            |            |            |            |
| leq X <= W                                                       |   457.0 us |    1.96 ms |    1.98 ms |   412.0 us |       0.23 |       0.99 |       4.80 |
| leq W <= X (false)                                               |   814.0 us |    4.97 ms |    4.88 ms |   104.2 us |       0.16 |       1.02 |      46.82 |
| counterexample W, X                                              |   157.8 us |   315.0 us |    76.1 us |    90.1 us |       0.50 |       4.14 |       0.84 |
| leq Y <= {8}                                                     |    8.87 ms |    6.43 ms |    9.92 ms |    95.1 us |       1.38 |       0.65 |     104.24 |
| inhabited X                                                      |   121.1 us |   315.9 us |   176.0 us |    62.0 us |       0.38 |       1.80 |       2.84 |
| **banked-regex-interval: k = 512 declared names**                |            |            |            |            |            |            |            |
| leq X <= W                                                       |    4.17 ms |   27.59 ms |   27.58 ms |    2.74 ms |       0.15 |       1.00 |      10.07 |
| leq W <= X (false)                                               |    8.78 ms |   81.60 ms |   85.76 ms |   973.9 us |       0.11 |       0.95 |      88.05 |
| counterexample W, X                                              |    1.10 ms |    3.32 ms |   168.1 us |   940.1 us |       0.33 |      19.78 |       0.18 |
| leq Y <= {8}                                                     |  112.69 ms |   82.44 ms |  165.99 ms |   934.8 us |       1.37 |       0.50 |     177.56 |
| inhabited X                                                      |   671.1 us |    2.17 ms |    5.21 ms |   906.9 us |       0.31 |       0.42 |       5.74 |
| **banked-regex-interval: n-th letter from the end, n = 4**       |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   917.9 us |    75.8 us |    61.0 us |    59.1 us |      12.11 |       1.24 |       1.03 |
| leq (B \| C)* <= E                                               |   294.9 us |   555.0 us |   567.0 us |    7.23 ms |       0.53 |       0.98 |       0.08 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |   155.9 us |   541.9 us |   559.1 us |   16.96 ms |       0.29 |       0.97 |       0.03 |
| leq C* <= E2                                                     |   126.1 us |    2.67 ms |    2.54 ms |  418.97 ms |       0.05 |       1.05 |       0.01 |
| **banked-regex-interval: n-th letter from the end, n = 8**       |            |            |            |            |            |            |            |
| elaborate E, E2                                                  |   50.91 ms |    98.9 us |    67.9 us |    65.1 us |     514.57 |       1.46 |       1.04 |
| leq (B \| C)* <= E                                               |    2.73 ms |    6.11 ms |    6.70 ms |     3.44 s |       0.45 |       0.91 |       0.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E                       |    2.64 ms |    6.33 ms |    6.81 ms |     7.22 s |       0.42 |       0.93 |       0.00 |
| leq C* <= E2                                                     |    2.35 ms |  311.70 ms |  310.24 ms |     > 10 s |       0.01 |       1.00 |    < 0.031 |
| **banked-regex-interval: interval consistency, n = 10**          |            |            |            |            |            |            |            |
| inhabited C                                                      |   217.0 us |   484.9 us |   458.0 us |   159.0 us |       0.45 |       1.06 |       2.88 |
| vacuous I (no common run)                                        |   114.0 us |   145.0 us |   131.8 us |    88.9 us |       0.79 |       1.10 |       1.48 |
| vacuous T (durations apart)                                      |   381.9 us |   157.1 us |   151.9 us |    54.1 us |       2.43 |       1.03 |       2.81 |
| **banked-regex-interval: interval consistency, n = 100**         |            |            |            |            |            |            |            |
| inhabited C                                                      |   19.04 ms |   23.24 ms |   22.41 ms |    1.11 ms |       0.82 |       1.04 |      20.19 |
| vacuous I (no common run)                                        |    4.67 ms |    6.36 ms |    6.11 ms |   592.0 us |       0.73 |       1.04 |      10.32 |
| vacuous T (durations apart)                                      |   43.59 ms |    6.56 ms |    6.61 ms |   401.0 us |       6.64 |       0.99 |      16.47 |

### Rational delays

#### Typechecking

| workload                                                      |   automata |   symbolic |   aut/symb |  aut. warm |  sym. warm |
| ------------------------------------------------------------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| **typechecking, regular-trace-languages-rational**            |            |            |            |            |            |
| standard library alone                                        |   19.14 ms |   18.90 ms |       1.01 |   16.24 ms |   16.53 ms |
| examples/introduction/stale_calibration.tpe                   |   19.72 ms |   19.85 ms |       0.99 |   16.96 ms |   17.13 ms |
| examples/regular_trace_languages/upper_bounds_rational.tpe    |   20.43 ms |   20.50 ms |       1.00 |   17.81 ms |   17.76 ms |
| tests/regex_rational.tpe                                      |   19.94 ms |   20.44 ms |       0.98 |   17.46 ms |   17.55 ms |
| tests/regex_rational_reject.tpe                               |   20.70 ms |   20.40 ms |       1.01 |   17.74 ms |   17.75 ms |
| **typechecking, banked-regex-lower-bound-rational**           |            |            |            |            |            |
| standard library alone                                        |   15.29 ms |   15.30 ms |       1.00 |   12.73 ms |   12.82 ms |
| tests/banked_regex_rational_lower.tpe                         |   17.13 ms |   16.57 ms |       1.03 |   14.77 ms |   13.85 ms |
| tests/banked_regex_rational_lower_reject.tpe                  |   17.21 ms |   16.70 ms |       1.03 |   14.36 ms |   13.88 ms |
| **typechecking, banked-regex-upper-bound-rational**           |            |            |            |            |            |
| standard library alone                                        |   18.06 ms |   18.00 ms |       1.00 |   15.44 ms |   15.38 ms |
| examples/banked_regex/upper_bounds_rational.tpe               |   22.26 ms |   20.42 ms |       1.09 |   19.69 ms |   17.37 ms |
| tests/banked_regex_rational_upper.tpe                         |   21.71 ms |   20.20 ms |       1.07 |   18.70 ms |   17.32 ms |
| tests/banked_regex_rational_upper_open.tpe                    |   19.06 ms |   18.66 ms |       1.02 |   16.21 ms |   15.86 ms |
| tests/banked_regex_rational_upper_open_reject.tpe             |   18.82 ms |   18.40 ms |       1.02 |   16.16 ms |   15.76 ms |
| tests/banked_regex_rational_upper_reject.tpe                  |   21.97 ms |   20.50 ms |       1.07 |   19.24 ms |   17.50 ms |
| tests/literals_reject_idle_grade.tpe                          |   379.1 us |   344.0 us |       1.10 |   155.3 us |   137.9 us |
| **typechecking, banked-regex-interval-rational**              |            |            |            |            |            |
| standard library alone                                        |   19.96 ms |   20.30 ms |       0.98 |   16.83 ms |   16.89 ms |
| examples/banked_regex/intervals_rational.tpe                  |   24.78 ms |   22.34 ms |       1.11 |   21.50 ms |   18.88 ms |
| tests/banked_regex_rational_interval.tpe                      |   21.19 ms |   20.37 ms |       1.04 |   18.27 ms |   17.47 ms |
| tests/banked_regex_rational_interval_default_open_reject.tpe  |   20.50 ms |   20.07 ms |       1.02 |   17.49 ms |   17.23 ms |
| tests/banked_regex_rational_interval_no_common_run_reject.tpe |   20.06 ms |   20.15 ms |       1.00 |   17.28 ms |   17.07 ms |
| tests/banked_regex_rational_interval_open_reject.tpe          |   20.17 ms |   19.81 ms |       1.02 |   17.17 ms |   16.97 ms |
| tests/banked_regex_rational_interval_reject.tpe               |   21.00 ms |   20.38 ms |       1.03 |   18.13 ms |   17.61 ms |

#### Grade operations

| workload                                                               |   automata |   symbolic |   aut/symb |
| ---------------------------------------------------------------------- | ---------- | ---------- | ---------- |
| **regular-trace-languages-rational: corpus (17 literals)**             |            |            |            |
| elaborate                                                              |    3.24 ms |   143.1 us |      22.64 |
| leq, all pairs                                                         |   363.1 us |    3.04 ms |       0.12 |
| equal, all pairs                                                       |     6.0 us |   554.1 us |       0.01 |
| counterexample, all pairs                                              |    2.27 ms |    3.49 ms |       0.65 |
| show, each                                                             |    15.0 us |    40.1 us |       0.38 |
| **regular-trace-languages-rational: delay set {(100 \| 101)*}**        |            |            |            |
| elaborate G                                                            |    3.79 ms |    2.99 ms |       1.26 |
| leq 201 <= G                                                           |     2.9 us |    56.0 us |       0.05 |
| equal G = G \| 201                                                     |     3.1 us |    55.1 us |       0.06 |
| counterexample G, 201                                                  |    44.1 us |   105.1 us |       0.42 |
| **regular-trace-languages-rational: delay set {(300 \| 301)*}**        |            |            |            |
| elaborate G                                                            |    9.90 ms |    5.04 ms |       1.96 |
| leq 601 <= G                                                           |     3.1 us |    1.63 ms |       0.00 |
| equal G = G \| 601                                                     |     3.1 us |    1.65 ms |       0.00 |
| counterexample G, 601                                                  |   315.9 us |    2.16 ms |       0.15 |
| **regular-trace-languages-rational: delay set {(1000 \| 1001)*}**      |            |            |            |
| elaborate G                                                            |   60.17 ms |   21.48 ms |       2.80 |
| leq 2001 <= G                                                          |     4.1 us |    8.23 ms |       0.00 |
| equal G = G \| 2001                                                    |     4.1 us |    8.35 ms |       0.00 |
| counterexample G, 2001                                                 |    3.77 ms |   13.47 ms |       0.28 |
| **regular-trace-languages-rational: delay set {97*; 89*}**             |            |            |            |
| elaborate G                                                            |    4.03 ms |    3.16 ms |       1.27 |
| leq 186 <= G                                                           |     3.1 us |    47.0 us |       0.07 |
| equal G = G \| 186                                                     |     3.1 us |    47.0 us |       0.07 |
| counterexample G, 186                                                  |    39.1 us |    93.0 us |       0.42 |
| **regular-trace-languages-rational: delay set {997*; 991*}**           |            |            |            |
| elaborate G                                                            |   59.26 ms |   21.91 ms |       2.71 |
| leq 1988 <= G                                                          |     3.8 us |    8.06 ms |       0.00 |
| equal G = G \| 1988                                                    |     4.1 us |    8.05 ms |       0.00 |
| counterexample G, 1988                                                 |    3.71 ms |   13.33 ms |       0.28 |
| **regular-trace-languages-rational: delay set {(1 \| (10, 10.001))*}** |            |            |            |
| elaborate G                                                            |   49.45 ms |   47.40 ms |       1.04 |
| leq 1 <= G                                                             |     3.8 us |   115.2 us |       0.03 |
| equal G = G \| 1                                                       |     3.1 us |   118.0 us |       0.03 |
| counterexample G, 1                                                    |   525.0 us |   559.1 us |       0.94 |
| **regular-trace-languages-rational: delay set {(1/97 \| 1/89)*}**      |            |            |            |
| elaborate G                                                            |    4.57 ms |    3.40 ms |       1.35 |
| leq 1 <= G                                                             |    70.1 us |    83.0 us |       0.84 |
| equal G = G \| 1                                                       |    70.1 us |    80.1 us |       0.88 |
| counterexample G, 1                                                    |   131.8 us |   325.9 us |       0.40 |
| **regular-trace-languages-rational: delay set {~((300 \| 301)*)}**     |            |            |            |
| elaborate G                                                            |   10.25 ms |    7.06 ms |       1.45 |
| leq 1/2 <= G                                                           |     4.1 us |     1.0 us |       4.25 |
| equal G = G \| 1/2                                                     |     4.1 us |     1.0 us |       4.25 |
| counterexample G, 1/2                                                  |    1.45 ms |    1.84 ms |       0.79 |
| **regular-trace-languages-rational: delay set {[1, 1.001]*}**          |            |            |            |
| elaborate G                                                            |    3.75 ms |    3.45 ms |       1.09 |
| leq 500 <= G                                                           |    11.0 us |    19.1 us |       0.57 |
| equal G = G \| 500                                                     |    10.0 us |    19.1 us |       0.53 |
| counterexample G, 500                                                  |    31.9 us |    67.0 us |       0.48 |
| **banked-regex-lower-bound-rational: corpus (23 literals)**            |            |            |            |
| elaborate                                                              |    3.37 ms |   697.1 us |       4.84 |
| leq, all pairs                                                         |    1.20 ms |    3.19 ms |       0.37 |
| equal, all pairs                                                       |    1.24 ms |    3.09 ms |       0.40 |
| counterexample, all pairs                                              |    2.58 ms |    3.24 ms |       0.80 |
| inhabited, each                                                        |    27.9 us |    48.9 us |       0.57 |
| show, each                                                             |    20.0 us |    42.0 us |       0.48 |
| **banked-regex-upper-bound-rational: corpus (23 literals)**            |            |            |            |
| elaborate                                                              |    3.52 ms |   628.0 us |       5.60 |
| leq, all pairs                                                         |    2.00 ms |    3.64 ms |       0.55 |
| equal, all pairs                                                       |    2.08 ms |    3.79 ms |       0.55 |
| counterexample, all pairs                                              |    5.85 ms |    4.29 ms |       1.36 |
| inhabited, each                                                        |    26.9 us |    45.1 us |       0.60 |
| show, each                                                             |    23.1 us |    47.0 us |       0.49 |
| **banked-regex-upper-bound-rational: delays, n = 8**                   |            |            |            |
| leq T <= S                                                             |    30.0 us |    44.1 us |       0.68 |
| leq S <= T (false)                                                     |    41.0 us |    59.1 us |       0.69 |
| counterexample S, T                                                    |    2.60 ms |    67.9 us |      38.29 |
| leq R <= T                                                             |    28.8 us |    34.1 us |       0.85 |
| equal T = T \| R                                                       |    2.52 ms |    46.0 us |      54.81 |
| **banked-regex-upper-bound-rational: delays, n = 128**                 |            |            |            |
| leq T <= S                                                             |    27.9 us |    42.9 us |       0.65 |
| leq S <= T (false)                                                     |    3.14 ms |    3.75 ms |       0.84 |
| counterexample S, T                                                    |    6.11 ms |    3.88 ms |       1.57 |
| leq R <= T                                                             |    29.1 us |    32.2 us |       0.90 |
| equal T = T \| R                                                       |    2.54 ms |    44.8 us |      56.67 |
| **banked-regex-upper-bound-rational: delays, n = 1024**                |            |            |            |
| leq T <= S                                                             |    2.46 ms |    44.1 us |      55.84 |
| leq S <= T (false)                                                     |    8.45 ms |   13.75 ms |       0.61 |
| counterexample S, T                                                    |  250.65 ms |   21.37 ms |      11.73 |
| leq R <= T                                                             |    30.0 us |    34.1 us |       0.88 |
| equal T = T \| R                                                       |    62.0 us |    47.0 us |       1.32 |
| **banked-regex-upper-bound-rational: k = 8 declared names**            |            |            |            |
| leq X <= W                                                             |    31.0 us |    60.1 us |       0.52 |
| leq W <= X (false)                                                     |    39.1 us |    83.0 us |       0.47 |
| counterexample W, X                                                    |    73.9 us |    92.0 us |       0.80 |
| leq Y <= {8}                                                           |    21.9 us |    46.0 us |       0.48 |
| inhabited X                                                            |    17.9 us |    35.0 us |       0.51 |
| **banked-regex-upper-bound-rational: k = 128 declared names**          |            |            |            |
| leq X <= W                                                             |   537.9 us |    1.86 ms |       0.29 |
| leq W <= X (false)                                                     |    1.10 ms |    3.18 ms |       0.35 |
| counterexample W, X                                                    |    1.12 ms |    3.25 ms |       0.34 |
| leq Y <= {8}                                                           |    35.0 us |    55.1 us |       0.64 |
| inhabited X                                                            |   188.1 us |   612.0 us |       0.31 |
| **banked-regex-upper-bound-rational: k = 512 declared names**          |            |            |            |
| leq X <= W                                                             |    6.88 ms |   14.48 ms |       0.47 |
| leq W <= X (false)                                                     |   14.81 ms |   34.22 ms |       0.43 |
| counterexample W, X                                                    |   14.51 ms |   33.40 ms |       0.43 |
| leq Y <= {8}                                                           |    73.9 us |    78.9 us |       0.94 |
| inhabited X                                                            |    2.13 ms |    4.87 ms |       0.44 |
| **banked-regex-interval-rational: corpus (31 literals)**               |            |            |            |
| elaborate                                                              |    3.34 ms |   167.1 us |      19.99 |
| leq, all pairs                                                         |    4.06 ms |    4.71 ms |       0.86 |
| equal, all pairs                                                       |    3.57 ms |    4.51 ms |       0.79 |
| counterexample, all pairs                                              |   12.30 ms |    6.10 ms |       2.02 |
| inhabited, each                                                        |   128.0 us |    2.58 ms |       0.05 |
| show, each                                                             |    32.2 us |    77.0 us |       0.42 |
| **banked-regex-interval-rational: delays, n = 8**                      |            |            |            |
| leq T <= S                                                             |    27.9 us |    43.9 us |       0.64 |
| leq S <= T (false)                                                     |    33.9 us |    56.0 us |       0.60 |
| counterexample S, T                                                    |    24.1 us |    38.9 us |       0.62 |
| leq R <= T                                                             |    22.2 us |    31.0 us |       0.72 |
| equal T = T \| R                                                       |    57.0 us |    46.0 us |       1.24 |
| **banked-regex-interval-rational: delays, n = 128**                    |            |            |            |
| leq T <= S                                                             |    25.0 us |    42.0 us |       0.60 |
| leq S <= T (false)                                                     |   750.1 us |    3.68 ms |       0.20 |
| counterexample S, T                                                    |    24.1 us |    38.9 us |       0.62 |
| leq R <= T                                                             |    23.1 us |    31.0 us |       0.75 |
| equal T = T \| R                                                       |    52.9 us |    42.9 us |       1.23 |
| **banked-regex-interval-rational: delays, n = 1024**                   |            |            |            |
| leq T <= S                                                             |    23.8 us |    43.9 us |       0.54 |
| leq S <= T (false)                                                     |    6.09 ms |   14.01 ms |       0.43 |
| counterexample S, T                                                    |    25.0 us |    37.9 us |       0.66 |
| leq R <= T                                                             |    21.9 us |    30.0 us |       0.73 |
| equal T = T \| R                                                       |    56.0 us |    45.1 us |       1.24 |
| **banked-regex-interval-rational: k = 8 declared names**               |            |            |            |
| leq X <= W                                                             |    38.9 us |    70.1 us |       0.55 |
| leq W <= X (false)                                                     |    36.0 us |    80.1 us |       0.45 |
| counterexample W, X                                                    |    23.1 us |    47.9 us |       0.48 |
| leq Y <= {8}                                                           |    20.0 us |    41.0 us |       0.49 |
| inhabited X                                                            |    20.0 us |    31.9 us |       0.63 |
| **banked-regex-interval-rational: k = 128 declared names**             |            |            |            |
| leq X <= W                                                             |   961.1 us |    2.27 ms |       0.42 |
| leq W <= X (false)                                                     |    1.05 ms |    3.18 ms |       0.33 |
| counterexample W, X                                                    |   279.9 us |    1.26 ms |       0.22 |
| leq Y <= {8}                                                           |    37.0 us |    55.1 us |       0.67 |
| inhabited X                                                            |   279.2 us |   639.0 us |       0.44 |
| **banked-regex-interval-rational: k = 512 declared names**             |            |            |            |
| leq X <= W                                                             |   11.53 ms |   19.80 ms |       0.58 |
| leq W <= X (false)                                                     |   13.98 ms |   32.83 ms |       0.43 |
| counterexample W, X                                                    |    2.87 ms |    7.61 ms |       0.38 |
| leq Y <= {8}                                                           |    73.0 us |    1.27 ms |       0.06 |
| inhabited X                                                            |    3.12 ms |    5.26 ms |       0.59 |
| **banked-regex-interval-rational: interval consistency, n = 10**       |            |            |            |
| inhabited C                                                            |    96.8 us |    2.65 ms |       0.04 |
| vacuous I (no common run)                                              |    52.9 us |    99.9 us |       0.53 |
| vacuous T (durations apart)                                            |    49.1 us |    56.0 us |       0.88 |
| **banked-regex-interval-rational: interval consistency, n = 100**      |            |            |            |
| inhabited C                                                            |   711.0 us |    1.12 ms |       0.63 |
| vacuous I (no common run)                                              |   306.1 us |   778.0 us |       0.39 |
| vacuous T (durations apart)                                            |   184.1 us |   340.9 us |       0.54 |

### Timed regex grades

#### Grade operations

| workload                                                                                       |       time |
| ---------------------------------------------------------------------------------------------- | ---------- |
| **timed-regex-interval-rational: case-study corpus (34 literals)**                             |            |
| elaborate                                                                                      |    3.03 ms |
| leq, all pairs                                                                                 |   41.30 ms |
| equal, all pairs                                                                               |   36.67 ms |
| counterexample, all pairs                                                                      |  185.43 ms |
| duration_bounds, each                                                                          |    8.62 ms |
| inhabited, each                                                                                |   10.93 ms |
| show, each                                                                                     |    40.1 us |
| **timed-regex-interval-rational: calibration window W = [{≥1000 & ~Move}, {≤600000 & ~Move}]** |            |
| duration_bounds W                                                                              |    47.2 us |
| inhabited W                                                                                    |    36.0 us |
| leq S <= W (false)                                                                             |  204.11 ms |
| leq E <= W (false)                                                                             |     > 10 s |
| **timed-regex-interval-rational: interval consistency, n = 10**                                |            |
| inhabited C                                                                                    |    4.29 ms |
| vacuous I (no common run)                                                                      |   11.73 ms |
| vacuous T (durations apart)                                                                    |    2.65 ms |
| **timed-regex-interval-rational: interval consistency, n = 40**                                |            |
| inhabited C                                                                                    |   23.68 ms |
| vacuous I (no common run)                                                                      |  140.31 ms |
| vacuous T (durations apart)                                                                    |    2.87 ms |
| **timed-regex-interval-rational: interval consistency, n = 160**                               |            |
| inhabited C                                                                                    |  464.24 ms |
| vacuous I (no common run)                                                                      |     2.34 s |
| vacuous T (durations apart)                                                                    |    4.06 ms |
| **timed-regex-interval-rational: interval consistency, n = 640**                               |            |
| inhabited C                                                                                    |     > 10 s |
| vacuous I (no common run)                                                                      |     > 10 s |
| vacuous T (durations apart)                                                                    |    5.35 ms |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 20**                              |            |
| leq W <= (A; ≤27/2)^n                                                                          |   141.9 us |
| leq W <= (A; ≤12)^n (false)                                                                    |    63.9 us |
| counterexample W, (A; ≤12)^n                                                                   |    72.0 us |
| leq W <= (A \| B \| ≤14)*                                                                      |    44.8 us |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 80**                              |            |
| leq W <= (A; ≤27/2)^n                                                                          |    1.53 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |   185.0 us |
| counterexample W, (A; ≤12)^n                                                                   |   212.9 us |
| leq W <= (A \| B \| ≤14)*                                                                      |   102.0 us |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 320**                             |            |
| leq W <= (A; ≤27/2)^n                                                                          |   17.31 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |    1.78 ms |
| counterexample W, (A; ≤12)^n                                                                   |    1.87 ms |
| leq W <= (A \| B \| ≤14)*                                                                      |   813.0 us |
| **timed-regex-upper-bound-rational: bounded repetitions, n = 1280**                            |            |
| leq W <= (A; ≤27/2)^n                                                                          |  210.36 ms |
| leq W <= (A; ≤12)^n (false)                                                                    |    9.08 ms |
| counterexample W, (A; ≤12)^n                                                                   |    9.99 ms |
| leq W <= (A \| B \| ≤14)*                                                                      |    3.50 ms |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 10**                       |            |
| duration_bounds A                                                                              |    41.0 us |
| leq A <= ≤L & ~Move                                                                            |    41.0 us |
| leq A <= <L & ~Move (false)                                                                    |    44.1 us |
| counterexample A, <L & ~Move                                                                   |    47.2 us |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 100**                      |            |
| duration_bounds A                                                                              |   203.8 us |
| leq A <= ≤L & ~Move                                                                            |   201.0 us |
| leq A <= <L & ~Move (false)                                                                    |   206.9 us |
| counterexample A, <L & ~Move                                                                   |   248.0 us |
| **timed-regex-upper-bound-rational: time spans absorbing items, k = 1000**                     |            |
| duration_bounds A                                                                              |    4.40 ms |
| leq A <= ≤L & ~Move                                                                            |    4.56 ms |
| leq A <= <L & ~Move (false)                                                                    |    4.77 ms |
| counterexample A, <L & ~Move                                                                   |    5.29 ms |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 10**                       |            |
| duration_bounds A                                                                              |    39.8 us |
| leq A <= ≥1000 & ~Move                                                                         |    39.8 us |
| counterexample A, ≥1000 & ~Move                                                                |    43.9 us |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 100**                      |            |
| duration_bounds A                                                                              |   211.0 us |
| leq A <= ≥1000 & ~Move                                                                         |   177.9 us |
| counterexample A, ≥1000 & ~Move                                                                |   180.0 us |
| **timed-regex-lower-bound-rational: time spans absorbing items, k = 1000**                     |            |
| duration_bounds A                                                                              |    4.03 ms |
| leq A <= ≥1000 & ~Move                                                                         |    2.67 ms |
| counterexample A, ≥1000 & ~Move                                                                |    2.67 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 4**                                |            |
| leq L <= R                                                                                     |   102.0 us |
| leq L <= R' (false)                                                                            |   101.1 us |
| counterexample L, R'                                                                           |    89.9 us |
| **timed-regex-upper-bound: n-th operation from the end, n = 8**                                |            |
| leq L <= R                                                                                     |    2.51 ms |
| leq L <= R' (false)                                                                            |    2.50 ms |
| counterexample L, R'                                                                           |    2.44 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 12**                               |            |
| leq L <= R                                                                                     |   42.49 ms |
| leq L <= R' (false)                                                                            |   42.47 ms |
| counterexample L, R'                                                                           |   42.40 ms |
| **timed-regex-upper-bound: n-th operation from the end, n = 16**                               |            |
| leq L <= R                                                                                     |     1.46 s |
| leq L <= R' (false)                                                                            |     1.41 s |
| counterexample L, R'                                                                           |     1.46 s |
| **timed-regex-upper-bound: k = 32 declared names**                                             |            |
| leq X <= S                                                                                     |    91.1 us |
| leq X <= Op1; (Op2 \| ... \| ≤3)*; Op1                                                         |    78.9 us |
| leq S <= X (false)                                                                             |    51.0 us |
| counterexample S, X                                                                            |    52.9 us |
| **timed-regex-upper-bound: k = 512 declared names**                                            |            |
| leq X <= S                                                                                     |    3.90 ms |
| leq X <= Op1; (Op2 \| ... \| ≤3)*; Op1                                                         |    3.74 ms |
| leq S <= X (false)                                                                             |    2.40 ms |
| counterexample S, X                                                                            |    2.41 ms |
| **timed-regex-finite-interval-rational: star-free case-study corpus (22 literals)**            |            |
| elaborate                                                                                      |   108.0 us |
| leq, all pairs                                                                                 |   26.14 ms |
| equal, all pairs                                                                               |   23.25 ms |
| counterexample, all pairs                                                                      |   71.75 ms |
| duration_bounds, each                                                                          |    9.47 ms |
| inhabited, each                                                                                |   10.13 ms |
| show, each                                                                                     |    24.1 us |
