# Regular trace grades benchmark

Compares the four implementations of the regular trace grade, and of the three
cost-model regular trace grades built over each (`traces-regex-upper`,
`traces-regex-lower`, `traces-regex-interval`, with the same suffixes). They
differ one design choice at a time:

| implementation | grade suffix    | construction     | letters of the expressions | letters derived by |
|----------------|-----------------|------------------|----------------------------|--------------------|
| automata       | (none)          | minimal automata | —                          | —                  |
| plain          | `-plain`        | derivatives      | single letters             | letters            |
| letters        | `-derivatives`  | derivatives      | letter sets                | letters            |
| symbolic       | `-symbolic`     | derivatives      | letter sets                | minterms           |

The automata implementation (`RegularTraceGrade`) builds canonical minimal
automata; the other three share the normal form, interning, memoisation,
decision procedures (depth-first emptiness, breadth-first shortest
counterexamples, Hopcroft–Karp equality) and printing of `SymbolicRegex` and
`RegularTraceGradeDerivative`. The symbolic implementation derives by the
minterms of the letter sets, as RE#. The letters implementation derives by
the concrete letters of the expressions compared instead: `tick`, each name
mentioned and one catch-all letter for the others. The plain implementation
(`RegularTraceGradePlain`) moreover has no letter sets: its expressions are
over single letters, `_` is the union of the letters of the grade's alphabet,
and grades over different names are re-expressed over the union of their
names before they are combined or compared, as the automata implementation
aligns its alphabets. The three ratios thus read off the three effects:
automata / plain the construction, plain / letters the representation of
letters, and letters / symbolic the minterms; their product is automata /
symbolic.

The workloads are the typechecking of the examples and tests that use each
grade, the standard library included, and the grade operations (elaboration,
`mul`, `join`, `leq`, `equal`, `counterexample`, `inhabited`) on families of
grades of increasing size. The families "alphabet of k names" and "k declared
names" mention many names within one letter set, where the minterms are few
and the letters many; "k names told apart" mentions each name on its own,
where the minterms are the letters. The delays of up to 1024 ticks exercise the
runs of ticks as counters (45cd85f), and the 512 declared names, of three costs,
the stepping of the symbolic cost-model grades by classes of names of equal
cost (bcce0dc). Run from the root of the repository:

    dune exec --profile release bench/regular/bench_regular.exe

Each measurement runs in a fresh child process, so that the tables the
derivatives keep start empty: it prepares its inputs untimed, then times the
operation once (cold) and then repeatedly (warm, the mean of the repeated
runs). The table shows the medians over 5 processes (fewer past 10 s of total
measurement); a cell reads `> 10 s` when a single run was killed at that
alarm. The ratios are of the cold times; a ratio is left empty when its
denominator is below the resolution of the clock.

## Measured

- 2026-09-28, at bcce0dc on `v2`, with the workloads extended as below
- macOS 15.7.7 (Darwin 24.6.0, arm64)
- OCaml 5.5.0, dune 3.24.2
- `--profile release`
- Total run time: 18 min 9 s
- Changes to the benchmark since 2026-09-27: the cost-model families "delays"
  gain n = 1024 and "declared names" gain k = 512, and the alarm is lowered
  from 20 s to 10 s. All five `> 10 s` cells are of the automata.

## Summary

Geometric means of the ratios of the cold times over the rows in which all
four implementations take at least 5 us (the cost-model rows include the new
families):

| rows                                | count | automata / plain | plain / letters | letters / symbolic | automata / symbolic |
|-------------------------------------|------:|-----------------:|----------------:|-------------------:|--------------------:|
| typechecking                        |    25 |             1.08 |            1.05 |               0.99 |                1.12 |
| operations of the plain grade       |    53 |             2.86 |            1.54 |               1.21 |                5.34 |
| operations of the cost-model grades |   131 |             3.45 |            1.41 |               1.55 |                7.54 |

Change since the run of 2026-09-27 (at baa89f1): geometric means of new / old
cold times over the rows of both runs in which both take at least 5 us. Below
1 is faster. The typechecking rows also gain from the inference work between
the runs (incremental elimination, per-grade comparison and hashing), equally
for all four implementations.

| rows                                | automata | plain | letters | symbolic |
|-------------------------------------|---------:|------:|--------:|---------:|
| typechecking (25 rows)              |     0.77 |  0.71 |    0.71 |     0.72 |
| operations of the plain grade       |     0.80 |  0.91 |    0.76 |     0.81 |
| operations of the cost-model grades |     1.03 |  0.55 |    0.52 |     0.38 |

How the derivatives fare:

- Runs of ticks as counters. At n = 1024 ticks every derivative implementation
  decides the delay workloads in 22 us to 0.8 ms, mostly as fast as at n = 8
  (the interval grade's `leq R <= T` and `equal T = T | R` grow from 0.1 ms to
  0.55 and 0.81 ms), where the automata take 0.26 to 8.9 s or exceed 10 s (up
  to 54,000 times slower). The exception is `leq S <= T (false)` and its
  counterexample under the upper bound, which still grow linearly in n: 2.2 ms
  at n = 128 (35 ms on 2026-09-27) and 18 to 29 ms at n = 1024.
- Classes of names of equal cost, upper bound. The symbolic grade stays at 0.1
  to 1.2 ms from 128 to 512 declared names, where the letters and plain
  implementations take 33 to 230 ms on the comparisons: up to 2,090 times on
  `leq Y <= {8}` and 100 times on `leq W <= X (false)`. On 2026-09-27 the
  symbolic grade took 31 ms on `leq Y <= {8}` at 128 names; it now takes 0.13
  ms.
- Classes of names of equal cost, lower bound and interval: the gain is
  smaller, and some rows are slower. At 512 names the lower symbolic grade
  takes 4.6 to 4.9 ms on every row, 21 times slower than the letters
  implementation on `leq W <= X (false)` and its counterexample (0.22 ms). The
  interval symbolic grade at 32 names takes 0.44 ms on the same rows, against
  0.04 ms for the letters implementation and 0.04 ms for itself on 2026-09-27.
  The warm times are unchanged, so the added cost is paid once per comparison.
  This regression needs investigating.
- Minterms in the plain grade: unchanged in kind. They pay off where one
  letter set names many operations (11 and 26 times on `leq X <= W` and `equal
  W = W | X` over 128 names). Where every name is told apart they cost (0.09
  on `leq V <= U (false)` over 128 names).
- Construction: the automata still lose by up to four orders of magnitude on
  complements and intersections ("n-th letter from the end", up to 32,700
  times at n = 16, and two `> 10 s` cells), but win on small inclusions and
  equalities of canonical automata.
- Regression in the cold path of all three derivative implementations: `leq C*
  <= E2` at n = 8 under the upper and interval cost-model grades takes 445 to
  460 ms, 3.4 to 3.9 times slower than on 2026-09-27, while the automata take
  3.7 ms. The warm times are unchanged. Several first operations also show a
  cold-start overhead of about 1 to 5 ms with unchanged warm times (e.g.
  elaborating the corpus by plain derivatives, 5.26 ms against 0.27 ms, and
  "n-th letter from the end, n = 12, elaborate E", 1.4 ms against 0.12 to 0.16
  ms). The cause is not yet identified.

## Results

Median over 5 processes (fewer past 10 s); cold: first run in a fresh process,
warm: mean of repeated runs; ratios of the cold times: automata / plain
(construction), plain / letters (representation), letters / symbolic
(minterms).

| workload                                 |   automata |      plain |    letters |   symbolic |  aut/plain |  plain/let |   let/symb |  aut. warm |   pl. warm |  let. warm |  sym. warm |
|------------------------------------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|
| **typechecking, traces-regex**           |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   34.98 ms |   29.44 ms |   28.47 ms |   28.52 ms |       1.19 |       1.03 |       1.00 |   28.67 ms |   25.04 ms |   24.35 ms |   24.37 ms |
| examples/regular/regular_traces.tpe      |   39.58 ms |   34.09 ms |   31.82 ms |   32.24 ms |       1.16 |       1.07 |       0.99 |   34.89 ms |   29.09 ms |   26.93 ms |   26.91 ms |
| tests/literals_regular.tpe               |   33.79 ms |   29.67 ms |   29.04 ms |   29.26 ms |       1.14 |       1.02 |       0.99 |   28.74 ms |   25.17 ms |   24.40 ms |   24.63 ms |
| tests/regular_auth.tpe                   |   36.92 ms |   32.11 ms |   30.78 ms |   31.72 ms |       1.15 |       1.04 |       0.97 |   31.56 ms |   26.97 ms |   26.50 ms |   26.27 ms |
| tests/regular_protocol.tpe               |   39.42 ms |   34.77 ms |   32.51 ms |   32.42 ms |       1.13 |       1.07 |       1.00 |   32.89 ms |   28.56 ms |   26.71 ms |   26.79 ms |
| tests/regular_reject_auth.tpe            |   37.32 ms |   32.53 ms |   31.41 ms |   31.69 ms |       1.15 |       1.04 |       0.99 |   30.68 ms |   26.69 ms |   25.71 ms |   25.77 ms |
| tests/regular_reject_bounds.tpe          |   35.07 ms |   30.22 ms |   29.42 ms |   29.21 ms |       1.16 |       1.03 |       1.01 |   28.77 ms |   25.35 ms |   24.42 ms |   24.39 ms |
| tests/regular_reject_counterexample.tpe  |   37.12 ms |   31.90 ms |   31.35 ms |   30.47 ms |       1.16 |       1.02 |       1.03 |   30.93 ms |   26.42 ms |   25.67 ms |   25.57 ms |
| tests/regular_reject_protocol.tpe        |   37.00 ms |   32.45 ms |   31.48 ms |   30.19 ms |       1.14 |       1.03 |       1.04 |   30.55 ms |   26.41 ms |   25.42 ms |   25.34 ms |
| **corpus (29 literals)**                 |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    6.07 ms |    5.26 ms |   244.1 us |   315.0 us |       1.15 |      21.56 |       0.78 |   422.7 us |    33.0 us |    29.7 us |    30.1 us |
| mul, all pairs                           |    9.86 ms |    1.67 ms |    94.2 us |    95.8 us |       5.92 |      17.70 |       0.98 |    9.84 ms |    1.15 ms |    53.7 us |    53.6 us |
| join, all pairs                          |    7.88 ms |    1.68 ms |   255.1 us |   257.0 us |       4.69 |       6.58 |       0.99 |    7.88 ms |    1.19 ms |   173.7 us |   175.7 us |
| leq, all pairs                           |    3.78 ms |    3.39 ms |    2.14 ms |    2.38 ms |       1.11 |       1.58 |       0.90 |    3.71 ms |    1.14 ms |   172.2 us |   173.7 us |
| equal, all pairs                         |    21.9 us |    1.89 ms |   608.0 us |   732.9 us |       0.01 |       3.12 |       0.83 |    20.7 us |   967.4 us |    18.0 us |    18.0 us |
| counterexample, all pairs                |    7.08 ms |    3.43 ms |    2.13 ms |    2.20 ms |       2.07 |       1.61 |       0.97 |    7.13 ms |    2.01 ms |   934.1 us |    1.08 ms |
| **protocol P^k, k = 2**                  |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |    16.0 us |     3.1 us |     1.9 us |     1.9 us |       5.15 |       1.62 |       1.00 |     8.1 us |     0.3 us |     0.1 us |     0.1 us |
| join J = P | ... | P^k                   |    29.1 us |     6.0 us |     5.0 us |     4.1 us |       4.88 |       1.19 |       1.24 |    14.6 us |     0.6 us |     0.2 us |     0.2 us |
| leq P^k <= P*                            |     7.9 us |    10.0 us |    14.1 us |    11.0 us |       0.79 |       0.71 |       1.28 |     1.7 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |     6.9 us |    23.1 us |    23.1 us |    19.1 us |       0.30 |       1.00 |       1.21 |     2.1 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample P; P*, J                  |    44.8 us |    21.0 us |    26.0 us |    19.1 us |       2.14 |       0.81 |       1.36 |    24.2 us |     3.7 us |     3.5 us |     3.2 us |
| equal J | P; P* = P; P*                  |    14.1 us |    20.0 us |    19.1 us |    16.0 us |       0.70 |       1.05 |       1.19 |     6.7 us |     0.5 us |     0.2 us |     0.2 us |
| **protocol P^k, k = 8**                  |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |    1.78 ms |     8.1 us |     6.0 us |     6.0 us |     219.47 |       1.36 |       1.00 |   210.3 us |     4.1 us |     2.9 us |     2.9 us |
| join J = P | ... | P^k                   |    2.71 ms |    30.0 us |    20.0 us |    21.9 us |      90.34 |       1.50 |       0.91 |   801.3 us |    16.9 us |    11.1 us |    11.1 us |
| leq P^k <= P*                            |    10.0 us |    45.1 us |    42.9 us |    35.0 us |       0.22 |       1.05 |       1.22 |     5.7 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |    11.0 us |    88.0 us |    89.9 us |    65.1 us |       0.12 |       0.98 |       1.38 |     6.6 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample P; P*, J                  |   181.2 us |   105.1 us |    93.9 us |    66.0 us |       1.72 |       1.12 |       1.42 |   138.2 us |     9.6 us |     9.4 us |     7.9 us |
| equal J | P; P* = P; P*                  |    17.9 us |    64.8 us |    70.1 us |    54.1 us |       0.28 |       0.93 |       1.30 |    15.7 us |     0.9 us |     0.6 us |     0.6 us |
| **protocol P^k, k = 32**                 |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |   11.29 ms |   107.8 us |    88.9 us |    89.9 us |     104.80 |       1.21 |       0.99 |    9.22 ms |    65.5 us |    58.3 us |    58.2 us |
| join J = P | ... | P^k                   |   92.13 ms |    2.97 ms |    2.92 ms |    2.37 ms |      31.03 |       1.02 |       1.23 |   89.21 ms |   777.3 us |   667.6 us |   670.1 us |
| leq P^k <= P*                            |    30.0 us |   155.9 us |   111.8 us |    77.0 us |       0.19 |       1.39 |       1.45 |    24.8 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |    32.9 us |   634.9 us |   654.9 us |   384.1 us |       0.05 |       0.97 |       1.71 |    27.4 us |     0.3 us |     0.2 us |     0.2 us |
| counterexample P; P*, J                  |    2.12 ms |   659.9 us |   668.0 us |   387.0 us |       3.20 |       0.99 |       1.73 |    1.75 ms |    39.3 us |    36.4 us |    29.9 us |
| equal J | P; P* = P; P*                  |    57.9 us |   533.1 us |   556.0 us |   340.2 us |       0.11 |       0.96 |       1.63 |    56.4 us |     4.4 us |     4.2 us |     4.2 us |
| **nested protocol N_d, d = 1**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |   217.0 us |   110.1 us |   123.0 us |   100.1 us |       1.97 |       0.90 |       1.23 |    65.0 us |     3.0 us |     2.8 us |     2.8 us |
| leq N_d <= N_d+1                         |     8.1 us |    19.1 us |    13.8 us |    11.9 us |       0.42 |       1.38 |       1.16 |     1.4 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |    47.0 us |    21.0 us |    24.1 us |    16.9 us |       2.24 |       0.87 |       1.42 |    24.8 us |     3.9 us |     3.5 us |     3.2 us |
| equal N_d = N_d | P                      |     1.2 us |    13.8 us |    11.9 us |    10.0 us |       0.09 |       1.16 |       1.19 |     0.2 us |     0.2 us |     0.0 us |     0.0 us |
| **nested protocol N_d, d = 3**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |    1.85 ms |   100.1 us |   101.1 us |   117.1 us |      18.45 |       0.99 |       0.86 |   163.4 us |     5.6 us |     5.3 us |     5.3 us |
| leq N_d <= N_d+1                         |     6.9 us |    36.0 us |    31.2 us |    20.0 us |       0.19 |       1.15 |       1.56 |     2.2 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |    59.8 us |    33.1 us |    33.1 us |    26.0 us |       1.81 |       1.00 |       1.28 |    51.7 us |     5.8 us |     5.4 us |     4.7 us |
| equal N_d = N_d | P                      |     1.0 us |    15.0 us |    15.0 us |    13.8 us |       0.06 |       1.00 |       1.09 |     0.3 us |     0.2 us |     0.0 us |     0.0 us |
| **nested protocol N_d, d = 6**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |    2.64 ms |   100.9 us |   108.0 us |   114.9 us |      26.13 |       0.93 |       0.94 |   404.8 us |    10.0 us |     9.4 us |     9.5 us |
| leq N_d <= N_d+1                         |     6.9 us |    57.0 us |    57.0 us |    46.0 us |       0.12 |       1.00 |       1.24 |     3.3 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |   124.0 us |    74.9 us |    68.9 us |    46.0 us |       1.66 |       1.09 |       1.50 |   113.4 us |     9.2 us |     8.6 us |     7.3 us |
| equal N_d = N_d | P                      |     0.0 us |    13.1 us |    13.8 us |    11.9 us |       0.00 |       0.95 |       1.16 |     0.3 us |     0.2 us |     0.0 us |     0.0 us |
| **n-th letter from the end, n = 4**      |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |    2.02 ms |    99.9 us |   100.9 us |    83.0 us |      20.18 |       0.99 |       1.22 |   142.0 us |     3.0 us |     1.8 us |     1.8 us |
| elaborate E2                             |    3.26 ms |   124.9 us |    91.1 us |    89.9 us |      26.10 |       1.37 |       1.01 |   607.2 us |     7.3 us |     3.3 us |     3.3 us |
| leq (B | C)* <= E                        |    95.1 us |    23.1 us |    13.1 us |    11.2 us |       4.11 |       1.76 |       1.17 |    45.4 us |     2.2 us |     0.1 us |     0.1 us |
| counterexample (B | C)*; A; (B | C)^n, E |   379.1 us |    39.1 us |    31.9 us |    21.9 us |       9.70 |       1.22 |       1.46 |    62.5 us |     4.5 us |     2.8 us |     2.5 us |
| leq C* <= E2                             |    52.0 us |    38.1 us |    22.9 us |    22.2 us |       1.36 |       1.67 |       1.03 |    45.1 us |     2.4 us |     0.2 us |     0.2 us |
| elaborate E', decide E = E'              |   783.9 us |    1.76 ms |    1.79 ms |    1.94 ms |       0.44 |       0.98 |       0.93 |   240.6 us |     6.9 us |     4.2 us |     4.2 us |
| **n-th letter from the end, n = 8**      |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |    7.53 ms |    83.0 us |    83.9 us |    94.2 us |      90.71 |       0.99 |       0.89 |    4.55 ms |     5.3 us |     3.3 us |     3.3 us |
| elaborate E2                             |   70.03 ms |   129.9 us |    83.0 us |    90.1 us |     538.93 |       1.57 |       0.92 |   64.08 ms |    13.0 us |     6.4 us |     6.3 us |
| leq (B | C)* <= E                        |    1.74 ms |    24.1 us |    16.0 us |    16.0 us |      72.30 |       1.51 |       1.00 |    1.46 ms |     2.4 us |     0.1 us |     0.1 us |
| counterexample (B | C)*; A; (B | C)^n, E |    1.92 ms |    1.85 ms |    1.87 ms |    1.64 ms |       1.04 |       0.99 |       1.14 |    1.55 ms |     6.4 us |     4.3 us |     3.7 us |
| leq C* <= E2                             |    1.48 ms |    1.73 ms |    19.8 us |    21.9 us |       0.85 |      87.57 |       0.90 |    1.43 ms |     2.6 us |     0.2 us |     0.2 us |
| elaborate E', decide E = E'              |    7.64 ms |    7.54 ms |    7.19 ms |    6.20 ms |       1.01 |       1.05 |       1.16 |    6.85 ms |    13.3 us |     8.6 us |     8.5 us |
| **n-th letter from the end, n = 12**     |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |  131.17 ms |    1.54 ms |    1.82 ms |    1.41 ms |      85.01 |       0.85 |       1.29 |  129.18 ms |     8.0 us |     5.4 us |     5.3 us |
| elaborate E2                             |     7.32 s |    1.43 ms |    1.41 ms |   107.0 us |    5103.38 |       1.02 |      13.18 |          - |    19.6 us |    10.5 us |    10.4 us |
| leq (B | C)* <= E                        |   42.24 ms |    23.8 us |    15.0 us |    15.0 us |    1771.76 |       1.59 |       1.00 |   40.33 ms |     2.9 us |     0.1 us |     0.1 us |
| counterexample (B | C)*; A; (B | C)^n, E |   42.62 ms |    79.2 us |    62.0 us |    41.0 us |     538.41 |       1.28 |       1.51 |   40.45 ms |     8.5 us |     6.1 us |     5.2 us |
| leq C* <= E2                             |   33.52 ms |    33.1 us |    23.1 us |    25.0 us |    1011.35 |       1.43 |       0.92 |   51.31 ms |     3.1 us |     0.2 us |     0.2 us |
| elaborate E', decide E = E'              |  191.64 ms |   87.75 ms |   83.35 ms |   66.97 ms |       2.18 |       1.05 |       1.24 |  194.33 ms |    23.2 us |    15.5 us |    16.8 us |
| **n-th letter from the end, n = 16**     |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |     3.06 s |    98.0 us |    82.0 us |    83.2 us |   31190.43 |       1.19 |       0.99 |          - |    11.3 us |     8.0 us |     7.9 us |
| elaborate E2                             |     > 10 s |   167.8 us |   126.8 us |   136.1 us |    > 59578 |       1.32 |       0.93 |            |    27.3 us |    15.9 us |    15.7 us |
| leq (B | C)* <= E                        |  952.19 ms |    29.1 us |    17.9 us |    19.1 us |   32735.96 |       1.63 |       0.94 |  958.31 ms |     3.2 us |     0.1 us |     0.1 us |
| counterexample (B | C)*; A; (B | C)^n, E |  977.81 ms |    93.2 us |    74.1 us |    48.9 us |   10489.13 |       1.26 |       1.52 |  981.89 ms |    10.7 us |     7.7 us |     6.4 us |
| leq C* <= E2                             |     > 10 s |    38.1 us |    21.9 us |    21.2 us |   > 262144 |       1.74 |       1.03 |            |     3.4 us |     0.2 us |     0.2 us |
| elaborate E', decide E = E'              |     4.56 s |     2.59 s |     2.55 s |     1.90 s |       1.76 |       1.02 |       1.34 |          - |          - |          - |          - |
| **alphabet of k = 8 names**              |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |   387.0 us |   120.2 us |   114.9 us |   113.0 us |       3.22 |       1.05 |       1.02 |   139.4 us |     8.9 us |     6.6 us |     6.6 us |
| mul X W                                  |    20.0 us |     4.1 us |     0.0 us |     0.0 us |       4.94 |            |            |     8.4 us |     0.6 us |     0.1 us |     0.1 us |
| join X W                                 |    11.0 us |     1.9 us |     1.2 us |     1.0 us |       5.75 |       1.60 |       1.25 |     4.7 us |     0.6 us |     0.1 us |     0.1 us |
| leq X <= W                               |     8.1 us |    22.2 us |    13.1 us |     5.0 us |       0.37 |       1.69 |       2.62 |     1.9 us |     0.7 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |     4.1 us |     6.9 us |     3.1 us |     5.0 us |       0.59 |       2.23 |       0.62 |     0.6 us |     0.7 us |     0.1 us |     0.1 us |
| counterexample W, X                      |     7.9 us |     2.1 us |     3.1 us |     2.1 us |       3.67 |       0.69 |       1.44 |     3.6 us |     0.7 us |     0.1 us |     0.1 us |
| equal W = W | X                          |     1.0 us |    30.0 us |    23.1 us |    11.9 us |       0.03 |       1.30 |       1.94 |     0.1 us |     0.5 us |     0.0 us |     0.0 us |
| **alphabet of k = 32 names**             |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |    2.19 ms |   384.1 us |   180.0 us |   153.1 us |       5.69 |       2.13 |       1.18 |    1.31 ms |   125.2 us |    39.1 us |    39.2 us |
| mul X W                                  |    27.9 us |     6.0 us |     1.0 us |     0.0 us |       4.68 |       6.25 |            |    26.4 us |     2.7 us |     0.1 us |     0.1 us |
| join X W                                 |    18.8 us |     4.1 us |     1.9 us |     1.0 us |       4.65 |       2.12 |       2.00 |    16.6 us |     2.7 us |     0.1 us |     0.1 us |
| leq X <= W                               |    10.0 us |    82.0 us |    41.0 us |    10.0 us |       0.12 |       2.00 |       4.10 |     6.6 us |     2.8 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |     5.0 us |    18.8 us |    11.0 us |     4.1 us |       0.27 |       1.72 |       2.71 |     2.9 us |     2.8 us |     0.1 us |     0.1 us |
| counterexample W, X                      |    13.1 us |     6.9 us |     2.9 us |     3.1 us |       1.90 |       2.42 |       0.92 |    12.0 us |     2.8 us |     0.1 us |     0.1 us |
| equal W = W | X                          |     1.0 us |   103.0 us |    71.0 us |    15.0 us |       0.01 |       1.45 |       4.73 |     0.4 us |     2.4 us |     0.0 us |     0.0 us |
| **alphabet of k = 128 names**            |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |   19.95 ms |   10.09 ms |    1.35 ms |    1.13 ms |       1.98 |       7.49 |       1.19 |   17.32 ms |    4.34 ms |   408.8 us |   410.2 us |
| mul X W                                  |   139.0 us |    15.0 us |     0.0 us |     0.0 us |       9.25 |            |            |   142.5 us |    13.4 us |     0.1 us |     0.1 us |
| join X W                                 |   105.1 us |    16.0 us |     1.0 us |     1.2 us |       6.58 |      16.75 |       0.80 |   107.5 us |    13.4 us |     0.1 us |     0.1 us |
| leq X <= W                               |    33.1 us |    1.43 ms |   191.9 us |    17.2 us |       0.02 |       7.47 |      11.18 |    31.5 us |    13.5 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |    16.9 us |    57.9 us |    36.0 us |     9.1 us |       0.29 |       1.61 |       3.97 |    13.9 us |    13.4 us |     0.1 us |     0.1 us |
| counterexample W, X                      |    88.9 us |    14.1 us |     3.1 us |     1.9 us |       6.32 |       4.54 |       1.62 |    87.8 us |    13.4 us |     0.1 us |     0.1 us |
| equal W = W | X                          |     3.1 us |    1.79 ms |   562.0 us |    21.9 us |       0.00 |       3.19 |      25.62 |     1.3 us |    12.5 us |     0.0 us |     0.0 us |
| **k = 8 names told apart**               |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |    1.13 ms |   107.0 us |   113.0 us |   109.0 us |      10.53 |       0.95 |       1.04 |   327.9 us |     6.0 us |     5.4 us |     5.4 us |
| leq U <= V                               |    11.9 us |    32.9 us |    28.1 us |    35.0 us |       0.36 |       1.17 |       0.80 |     4.2 us |     0.7 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |     2.1 us |     5.0 us |     3.1 us |     8.1 us |       0.43 |       1.62 |       0.38 |     0.7 us |     0.7 us |     0.1 us |     0.1 us |
| counterexample V, U                      |    10.0 us |     4.1 us |     2.9 us |     2.1 us |       2.47 |       1.42 |       1.33 |     3.6 us |     0.7 us |     0.1 us |     0.1 us |
| equal V = 0 | U; V                       |   138.0 us |    26.0 us |    17.2 us |    18.1 us |       5.31 |       1.51 |       0.95 |    74.2 us |     3.0 us |     0.4 us |     0.4 us |
| **k = 32 names told apart**              |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |   19.99 ms |   801.1 us |   747.9 us |   845.2 us |      24.96 |       1.07 |       0.88 |   18.81 ms |    51.7 us |    46.4 us |    46.4 us |
| leq U <= V                               |    45.1 us |   441.1 us |   402.0 us |   458.0 us |       0.10 |       1.10 |       0.88 |    41.8 us |     2.8 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |     5.0 us |    19.1 us |    15.0 us |    64.1 us |       0.26 |       1.27 |       0.23 |     3.0 us |     2.8 us |     0.1 us |     0.1 us |
| counterexample V, U                      |    14.1 us |     5.0 us |     2.9 us |     1.9 us |       2.81 |       1.75 |       1.50 |    12.2 us |     2.8 us |     0.1 us |     0.1 us |
| equal V = 0 | U; V                       |    2.16 ms |    73.0 us |    44.1 us |    90.1 us |      29.59 |       1.65 |       0.49 |    2.11 ms |    14.6 us |     1.2 us |     1.2 us |
| **k = 128 names told apart**             |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |     3.59 s |   12.79 ms |   13.31 ms |   15.17 ms |     280.68 |       0.96 |       0.88 |          - |   793.4 us |   744.0 us |   743.0 us |
| leq U <= V                               |   720.0 us |    9.14 ms |    9.82 ms |   10.21 ms |       0.08 |       0.93 |       0.96 |   667.8 us |    13.5 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |    24.8 us |    69.1 us |    58.2 us |   669.0 us |       0.36 |       1.19 |       0.09 |    14.6 us |    13.3 us |     0.1 us |     0.1 us |
| counterexample V, U                      |   101.1 us |    21.0 us |     6.0 us |     4.1 us |       4.82 |       3.52 |       1.47 |    88.5 us |    13.3 us |     0.1 us |     0.1 us |
| equal V = 0 | U; V                       |  109.12 ms |   216.0 us |   121.1 us |   676.9 us |     505.17 |       1.78 |       0.18 |  109.51 ms |    96.1 us |     5.4 us |     5.4 us |
| **typechecking, traces-regex-upper**     |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   28.27 ms |   28.78 ms |   27.12 ms |   27.97 ms |       0.98 |       1.06 |       0.97 |   26.22 ms |   26.38 ms |   25.39 ms |   25.98 ms |
| examples/regular_costs/regular_costs_upper.tpe |   39.03 ms |   38.77 ms |   35.91 ms |   36.49 ms |       1.01 |       1.08 |       0.98 |   38.82 ms |   35.05 ms |   33.40 ms |   34.58 ms |
| tests/regex_costs_upper.tpe              |   34.88 ms |   35.25 ms |   34.28 ms |   35.98 ms |       0.99 |       1.03 |       0.95 |   33.78 ms |   32.15 ms |   31.62 ms |   32.75 ms |
| tests/regex_costs_upper_reject.tpe       |   34.81 ms |   33.96 ms |   32.40 ms |   33.04 ms |       1.02 |       1.05 |       0.98 |   32.90 ms |   30.72 ms |   29.56 ms |   30.32 ms |
| tests/regex_costs_upper_runs.tpe         |   31.97 ms |   32.96 ms |   31.31 ms |   32.21 ms |       0.97 |       1.05 |       0.97 |   29.59 ms |   29.25 ms |   28.00 ms |   29.08 ms |
| tests/regex_costs_upper_runs_reject.tpe  |   31.01 ms |   30.94 ms |   29.53 ms |   30.18 ms |       1.00 |       1.05 |       0.98 |   27.79 ms |   27.38 ms |   26.30 ms |   26.86 ms |
| **typechecking, traces-regex-lower**     |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   23.42 ms |   21.78 ms |   21.69 ms |   21.67 ms |       1.08 |       1.00 |       1.00 |   21.33 ms |   20.13 ms |   19.39 ms |   19.39 ms |
| examples/regular_costs/regular_costs_lower.tpe |   26.40 ms |   25.56 ms |   23.87 ms |   23.85 ms |       1.03 |       1.07 |       1.00 |   24.33 ms |   22.82 ms |   21.69 ms |   21.40 ms |
| tests/regex_costs_lower.tpe              |   25.83 ms |   24.14 ms |   23.12 ms |   23.29 ms |       1.07 |       1.04 |       0.99 |   23.52 ms |   22.04 ms |   20.85 ms |   20.96 ms |
| tests/regex_costs_lower_reject.tpe       |   27.83 ms |   24.56 ms |   23.59 ms |   22.69 ms |       1.13 |       1.04 |       1.04 |   24.57 ms |   21.87 ms |   20.70 ms |   20.66 ms |
| tests/regex_costs_lower_runs_reject.tpe  |   22.81 ms |   21.59 ms |   21.12 ms |   22.52 ms |       1.06 |       1.02 |       0.94 |   21.15 ms |   19.64 ms |   19.17 ms |   20.73 ms |
| **typechecking, traces-regex-interval**  |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   34.24 ms |   32.28 ms |   30.07 ms |   30.76 ms |       1.06 |       1.07 |       0.98 |   31.94 ms |   29.61 ms |   27.54 ms |   28.43 ms |
| examples/regular_costs/regular_costs_intervals.tpe |   45.14 ms |   41.20 ms |   37.50 ms |   38.65 ms |       1.10 |       1.10 |       0.97 |   41.96 ms |   38.69 ms |   34.56 ms |   35.39 ms |
| tests/regex_costs_interval.tpe           |   38.19 ms |   35.79 ms |   32.80 ms |   33.95 ms |       1.07 |       1.09 |       0.97 |   35.94 ms |   32.46 ms |   30.37 ms |   31.11 ms |
| tests/regex_costs_interval_reject.tpe    |   37.79 ms |   34.98 ms |   32.15 ms |   33.31 ms |       1.08 |       1.09 |       0.97 |   35.01 ms |   31.69 ms |   29.53 ms |   30.19 ms |
| tests/regex_costs_interval_runs_reject.tpe |   35.31 ms |   33.03 ms |   30.69 ms |   31.11 ms |       1.07 |       1.08 |       0.99 |   32.87 ms |   30.39 ms |   28.35 ms |   28.89 ms |
| **traces-regex-upper: cost corpus (15 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |   464.2 us |   149.0 us |   136.9 us |   129.9 us |       3.12 |       1.09 |       1.05 |   186.9 us |    13.3 us |    12.4 us |    12.4 us |
| leq, all pairs                           |    9.77 ms |   10.44 ms |   10.04 ms |    5.49 ms |       0.94 |       1.04 |       1.83 |   274.7 us |   525.3 us |   241.2 us |   255.8 us |
| equal, all pairs                         |    9.81 ms |   10.72 ms |   10.04 ms |    5.68 ms |       0.91 |       1.07 |       1.77 |   391.2 us |   729.5 us |   343.0 us |   361.1 us |
| counterexample, all pairs                |   12.78 ms |   10.56 ms |   10.21 ms |    5.66 ms |       1.21 |       1.03 |       1.81 |    3.20 ms |   599.0 us |   290.3 us |   304.0 us |
| **traces-regex-upper: delays, n = 8**    |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    93.0 us |    76.1 us |    64.8 us |    57.9 us |       1.22 |       1.17 |       1.12 |     1.1 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |   233.9 us |   113.0 us |   105.9 us |    81.1 us |       2.07 |       1.07 |       1.31 |     1.1 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |   531.0 us |   110.1 us |   112.1 us |    92.0 us |       4.82 |       0.98 |       1.22 |    45.0 us |     2.3 us |     1.7 us |     1.8 us |
| leq R <= T                               |   276.1 us |    79.9 us |    66.0 us |    62.9 us |       3.46 |       1.21 |       1.05 |     1.5 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |    1.13 ms |   124.0 us |   117.1 us |   104.2 us |       9.09 |       1.06 |       1.12 |    50.8 us |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-upper: delays, n = 32**   |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   256.1 us |    72.0 us |    60.8 us |    57.9 us |       3.56 |       1.18 |       1.05 |     1.8 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |    3.30 ms |   528.1 us |   537.9 us |   367.9 us |       6.25 |       0.98 |       1.46 |     1.8 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |    3.91 ms |   544.1 us |   565.1 us |   386.0 us |       7.18 |       0.96 |       1.46 |   459.6 us |     6.7 us |     5.8 us |     5.9 us |
| leq R <= T                               |    3.63 ms |    73.9 us |    69.1 us |    66.0 us |      49.07 |       1.07 |       1.05 |     3.1 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |   12.49 ms |   137.1 us |   118.0 us |   111.1 us |      91.07 |       1.16 |       1.06 |   510.0 us |     3.4 us |     2.0 us |     2.2 us |
| **traces-regex-upper: delays, n = 128**  |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    3.35 ms |    74.1 us |    67.0 us |    59.8 us |      45.14 |       1.11 |       1.12 |     4.5 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |   64.61 ms |    3.05 ms |    3.17 ms |    2.21 ms |      21.15 |       0.96 |       1.43 |     4.5 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |   80.90 ms |    3.09 ms |    3.29 ms |    2.31 ms |      26.21 |       0.94 |       1.42 |   15.48 ms |    62.0 us |    59.1 us |    59.2 us |
| leq R <= T                               |   67.75 ms |    88.0 us |    81.1 us |    80.8 us |     770.06 |       1.09 |       1.00 |     9.5 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |  210.48 ms |   148.1 us |   132.1 us |   114.9 us |    1421.59 |       1.12 |       1.15 |    8.43 ms |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-upper: delays, n = 1024** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |  260.18 ms |    93.9 us |    79.2 us |    75.1 us |    2769.76 |       1.19 |       1.05 |    29.2 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |     5.37 s |   24.62 ms |   25.94 ms |   17.96 ms |     218.21 |       0.95 |       1.44 |          - |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |     > 10 s |   29.22 ms |   30.22 ms |   22.44 ms |      > 342 |       0.97 |       1.35 |            |    3.77 ms |    3.70 ms |    3.67 ms |
| leq R <= T                               |     5.62 s |   134.0 us |   129.0 us |   123.0 us |   41956.83 |       1.04 |       1.05 |          - |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |     > 10 s |   240.1 us |   221.0 us |   208.1 us |    > 41651 |       1.09 |       1.06 |            |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-upper: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   295.9 us |    79.2 us |    57.9 us |    49.1 us |       3.74 |       1.37 |       1.18 |     1.9 us |     2.6 us |     1.9 us |     1.9 us |
| leq W <= X (false)                       |   316.9 us |   121.1 us |    96.8 us |    57.2 us |       2.62 |       1.25 |       1.69 |     1.9 us |     2.6 us |     1.9 us |     1.9 us |
| counterexample W, X                      |    86.8 us |   124.9 us |   103.0 us |    72.0 us |       0.69 |       1.21 |       1.43 |    17.3 us |     3.0 us |     2.2 us |     2.2 us |
| leq Y <= {8}                             |   250.8 us |   151.9 us |   147.1 us |    72.0 us |       1.65 |       1.03 |       2.04 |     1.0 us |     0.8 us |     0.7 us |     0.6 us |
| inhabited X                              |    25.0 us |    46.0 us |    29.1 us |    37.9 us |       0.54 |       1.58 |       0.77 |     1.5 us |     2.8 us |     2.7 us |     1.7 us |
| **traces-regex-upper: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    87.0 us |   687.1 us |   219.1 us |    67.0 us |       0.13 |       3.14 |       3.27 |     7.9 us |    11.7 us |     8.1 us |     7.7 us |
| leq W <= X (false)                       |   178.8 us |    1.41 ms |   966.1 us |    80.1 us |       0.13 |       1.46 |      12.06 |     7.9 us |    11.7 us |     8.1 us |     7.8 us |
| counterexample W, X                      |   198.1 us |    1.36 ms |   976.8 us |    78.0 us |       0.15 |       1.40 |      12.53 |    23.4 us |    12.1 us |     8.4 us |     8.1 us |
| leq Y <= {8}                             |    1.32 ms |    1.52 ms |    1.53 ms |    99.9 us |       0.87 |       0.99 |      15.35 |     2.9 us |     2.7 us |     2.7 us |     2.0 us |
| inhabited X                              |    34.1 us |    80.1 us |    45.1 us |    41.0 us |       0.43 |       1.78 |       1.10 |     6.2 us |    11.4 us |    10.8 us |     5.4 us |
| **traces-regex-upper: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   518.1 us |    3.14 ms |    3.01 ms |   664.0 us |       0.17 |       1.04 |       4.53 |    34.6 us |    55.5 us |    38.6 us |    36.2 us |
| leq W <= X (false)                       |    1.11 ms |    7.44 ms |    7.31 ms |   136.9 us |       0.15 |       1.02 |      53.45 |    34.7 us |    55.6 us |    38.6 us |    36.2 us |
| counterexample W, X                      |    1.12 ms |    7.44 ms |    7.32 ms |   141.9 us |       0.15 |       1.02 |      51.61 |    50.6 us |    56.1 us |    39.0 us |    36.6 us |
| leq Y <= {8}                             |   13.30 ms |    9.30 ms |   14.02 ms |   134.9 us |       1.43 |       0.66 |     103.86 |    12.8 us |    12.6 us |    12.6 us |     8.9 us |
| inhabited X                              |   113.0 us |   286.1 us |   134.0 us |    73.0 us |       0.40 |       2.14 |       1.84 |    27.3 us |    52.4 us |    48.7 us |    22.8 us |
| **traces-regex-upper: 512 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    5.72 ms |   37.88 ms |   33.03 ms |    1.13 ms |       0.15 |       1.15 |      29.28 |   156.9 us |   273.9 us |   190.8 us |   180.4 us |
| leq W <= X (false)                       |   13.18 ms |  116.79 ms |  116.49 ms |    1.16 ms |       0.11 |       1.00 |     100.34 |   156.3 us |   268.2 us |   189.8 us |   180.6 us |
| counterexample W, X                      |   13.58 ms |  116.72 ms |  116.37 ms |    1.18 ms |       0.12 |       1.00 |      98.53 |   172.2 us |   271.0 us |   190.6 us |   180.6 us |
| leq Y <= {8}                             |  188.98 ms |  113.35 ms |  229.74 ms |   109.9 us |       1.67 |       0.49 |    2090.19 |    54.3 us |    53.7 us |    53.1 us |    37.7 us |
| inhabited X                              |   838.0 us |    2.90 ms |    2.59 ms |    1.09 ms |       0.29 |       1.12 |       2.38 |   118.5 us |   262.2 us |   249.3 us |   108.6 us |
| **traces-regex-upper: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    1.60 ms |    99.2 us |    87.0 us |    93.9 us |      16.16 |       1.14 |       0.93 |   751.6 us |    10.2 us |     5.0 us |     5.0 us |
| leq (B | C)* <= E                        |   203.8 us |   791.1 us |   760.1 us |   634.2 us |       0.26 |       1.04 |       1.20 |     1.5 us |     2.9 us |     0.8 us |     0.8 us |
| counterexample (B | C)*; A; (B | C)^n, E |   208.9 us |   835.9 us |   762.9 us |   659.0 us |       0.25 |       1.10 |       1.16 |     1.8 us |     2.6 us |     1.1 us |     1.1 us |
| leq C* <= E2                             |   139.0 us |    4.22 ms |    3.80 ms |    3.88 ms |       0.03 |       1.11 |       0.98 |     1.7 us |     3.3 us |     1.0 us |     1.0 us |
| **traces-regex-upper: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   70.57 ms |   124.0 us |    90.1 us |    91.1 us |     569.26 |       1.38 |       0.99 |   66.84 ms |    18.4 us |     9.5 us |     9.5 us |
| leq (B | C)* <= E                        |    3.74 ms |    8.64 ms |    8.71 ms |    6.30 ms |       0.43 |       0.99 |       1.38 |    17.3 us |     3.4 us |     0.9 us |     1.0 us |
| counterexample (B | C)*; A; (B | C)^n, E |    3.95 ms |    8.39 ms |    8.82 ms |    6.71 ms |       0.47 |       0.95 |       1.31 |    17.7 us |     3.2 us |     1.4 us |     1.4 us |
| leq C* <= E2                             |    3.68 ms |  444.42 ms |  460.08 ms |  457.69 ms |       0.01 |       0.97 |       1.01 |    20.3 us |     3.9 us |     1.1 us |     1.2 us |
| **traces-regex-lower: cost corpus (15 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |   875.9 us |   145.9 us |   134.0 us |   137.1 us |       6.00 |       1.09 |       0.98 |   187.0 us |    13.4 us |    12.4 us |    12.4 us |
| leq, all pairs                           |    2.21 ms |    2.85 ms |    2.17 ms |    2.11 ms |       0.78 |       1.31 |       1.03 |   274.0 us |   525.3 us |   243.5 us |   255.5 us |
| equal, all pairs                         |    2.24 ms |    3.07 ms |    2.37 ms |    2.30 ms |       0.73 |       1.30 |       1.03 |   406.1 us |   767.0 us |   357.7 us |   377.1 us |
| counterexample, all pairs                |    3.44 ms |    2.85 ms |    2.19 ms |    2.30 ms |       1.21 |       1.30 |       0.95 |    1.49 ms |   563.6 us |   265.2 us |   279.0 us |
| **traces-regex-lower: delays, n = 8**    |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    74.9 us |    42.9 us |    29.8 us |    34.1 us |       1.74 |       1.44 |       0.87 |     1.1 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |    64.1 us |    36.0 us |    23.8 us |    26.0 us |       1.78 |       1.51 |       0.92 |     1.1 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |    64.1 us |    34.1 us |    23.8 us |    27.2 us |       1.88 |       1.43 |       0.88 |     1.9 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |   260.1 us |   390.1 us |   412.9 us |    48.9 us |       0.67 |       0.94 |       8.45 |     1.4 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |   693.8 us |    83.9 us |    66.0 us |    66.0 us |       8.27 |       1.27 |       1.00 |    50.6 us |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-lower: delays, n = 32**   |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   279.9 us |    41.0 us |    29.8 us |    36.0 us |       6.83 |       1.38 |       0.83 |     1.8 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |   237.9 us |    36.0 us |    22.2 us |    26.9 us |       6.61 |       1.62 |       0.82 |     1.8 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |   236.0 us |    36.0 us |    22.2 us |    29.1 us |       6.56 |       1.62 |       0.76 |     2.6 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |    2.43 ms |    65.1 us |    52.0 us |    48.9 us |      37.27 |       1.25 |       1.06 |     3.1 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |    7.27 ms |    84.2 us |    72.0 us |    72.0 us |      86.41 |       1.17 |       1.00 |   509.0 us |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-lower: delays, n = 128**  |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    3.28 ms |    43.9 us |    31.9 us |    37.0 us |      74.72 |       1.37 |       0.86 |     4.5 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |    3.21 ms |    35.0 us |    21.9 us |    26.9 us |      91.56 |       1.60 |       0.81 |     4.5 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |    3.18 ms |    33.9 us |    22.9 us |    26.0 us |      93.85 |       1.48 |       0.88 |     5.3 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |   38.46 ms |    67.9 us |    52.9 us |    57.0 us |     566.05 |       1.28 |       0.93 |     9.4 us |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |  111.40 ms |    97.0 us |    77.0 us |    73.9 us |    1148.02 |       1.26 |       1.04 |    8.35 ms |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-lower: delays, n = 1024** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |  260.20 ms |    59.1 us |    43.9 us |    48.2 us |    4400.69 |       1.35 |       0.91 |    29.2 us |     1.5 us |     0.9 us |     1.0 us |
| leq S <= T (false)                       |  258.57 ms |    36.0 us |    23.8 us |    26.0 us |    7182.28 |       1.51 |       0.92 |    29.4 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |  258.13 ms |    37.9 us |    21.9 us |    29.1 us |    6809.18 |       1.73 |       0.75 |    30.5 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |     2.90 s |   104.9 us |    96.1 us |    96.1 us |   27664.42 |       1.09 |       1.00 |          - |     1.4 us |     0.9 us |     1.0 us |
| equal T = T | R                          |     8.85 s |   165.0 us |   141.1 us |   141.1 us |   53651.60 |       1.17 |       1.00 |          - |     3.4 us |     2.0 us |     2.1 us |
| **traces-regex-lower: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    43.9 us |    62.0 us |    52.9 us |    52.9 us |       0.71 |       1.17 |       1.00 |     1.9 us |     2.6 us |     1.9 us |     1.9 us |
| leq W <= X (false)                       |    37.0 us |    43.2 us |    29.1 us |    33.9 us |       0.86 |       1.48 |       0.86 |     1.9 us |     2.6 us |     1.9 us |     1.9 us |
| counterexample W, X                      |    37.9 us |    47.9 us |    27.2 us |    34.1 us |       0.79 |       1.76 |       0.80 |     2.7 us |     2.7 us |     1.9 us |     1.9 us |
| leq Y <= {8}                             |    87.0 us |    68.9 us |    58.2 us |    55.1 us |       1.26 |       1.18 |       1.06 |     1.0 us |     0.8 us |     0.7 us |     0.6 us |
| inhabited X                              |    24.8 us |    42.2 us |    26.0 us |    32.9 us |       0.59 |       1.62 |       0.79 |     1.5 us |     2.8 us |     2.7 us |     1.7 us |
| **traces-regex-lower: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    64.1 us |   134.9 us |    77.0 us |    58.9 us |       0.48 |       1.75 |       1.31 |     7.8 us |    11.7 us |     8.1 us |     7.7 us |
| leq W <= X (false)                       |    49.1 us |    92.0 us |    37.0 us |    41.0 us |       0.53 |       2.49 |       0.90 |     7.8 us |    11.6 us |     8.0 us |     7.7 us |
| counterexample W, X                      |    48.9 us |    88.9 us |    40.1 us |    42.0 us |       0.55 |       2.22 |       0.95 |     8.6 us |    11.7 us |     8.1 us |     7.7 us |
| leq Y <= {8}                             |   201.9 us |   147.1 us |   150.9 us |    60.1 us |       1.37 |       0.97 |       2.51 |     2.9 us |     2.7 us |     2.7 us |     2.0 us |
| inhabited X                              |    73.9 us |    73.9 us |    41.0 us |    37.9 us |       1.00 |       1.80 |       1.08 |     6.2 us |    11.4 us |    10.7 us |     5.4 us |
| **traces-regex-lower: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   227.0 us |    1.10 ms |   709.1 us |   110.1 us |       0.21 |       1.56 |       6.44 |    34.7 us |    55.1 us |    38.7 us |    36.1 us |
| leq W <= X (false)                       |   177.1 us |   400.1 us |    96.1 us |    93.9 us |       0.44 |       4.16 |       1.02 |    34.5 us |    55.5 us |    38.9 us |    36.2 us |
| counterexample W, X                      |   182.2 us |   413.9 us |    98.9 us |    97.0 us |       0.44 |       4.18 |       1.02 |    35.5 us |    55.6 us |    39.1 us |    36.2 us |
| leq Y <= {8}                             |   902.2 us |   976.1 us |    1.16 ms |    85.1 us |       0.92 |       0.84 |      13.61 |    12.8 us |    12.6 us |    12.6 us |     8.8 us |
| inhabited X                              |   108.0 us |   284.9 us |   130.9 us |    76.1 us |       0.38 |       2.18 |       1.72 |    27.2 us |    52.0 us |    48.8 us |    22.9 us |
| **traces-regex-lower: 512 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    1.81 ms |    6.02 ms |    3.03 ms |    4.93 ms |       0.30 |       1.99 |       0.61 |   155.1 us |   273.1 us |   191.2 us |   179.4 us |
| leq W <= X (false)                       |    1.55 ms |    4.68 ms |   221.0 us |    4.77 ms |       0.33 |      21.17 |       0.05 |   154.9 us |   274.1 us |   193.1 us |   179.2 us |
| counterexample W, X                      |    1.59 ms |    4.93 ms |   223.9 us |    4.74 ms |       0.32 |      22.03 |       0.05 |   155.3 us |   274.2 us |   192.7 us |   179.3 us |
| leq Y <= {8}                             |    4.43 ms |    2.46 ms |    3.96 ms |    4.58 ms |       1.80 |       0.62 |       0.86 |    52.2 us |    54.3 us |    53.4 us |    37.3 us |
| inhabited X                              |   788.9 us |    2.82 ms |    1.55 ms |    4.64 ms |       0.28 |       1.81 |       0.34 |   117.8 us |   258.7 us |   246.0 us |   107.0 us |
| **traces-regex-lower: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    1.50 ms |   106.1 us |    84.9 us |    88.0 us |      14.15 |       1.25 |       0.96 |   746.0 us |    10.2 us |     5.0 us |     5.0 us |
| leq (B | C)* <= E                        |    95.8 us |    66.0 us |    42.0 us |    47.9 us |       1.45 |       1.57 |       0.88 |     1.5 us |     2.9 us |     0.8 us |     0.8 us |
| counterexample (B | C)*; A; (B | C)^n, E |   111.8 us |    64.8 us |    50.8 us |    52.9 us |       1.72 |       1.28 |       0.96 |     1.8 us |     2.6 us |     1.1 us |     1.1 us |
| leq C* <= E2                             |    60.1 us |    74.9 us |    57.0 us |    62.9 us |       0.80 |       1.31 |       0.91 |     1.7 us |     3.3 us |     1.0 us |     1.0 us |
| **traces-regex-lower: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   70.69 ms |   126.8 us |   102.0 us |    99.2 us |     557.30 |       1.24 |       1.03 |   67.04 ms |    18.3 us |     9.6 us |     9.5 us |
| leq (B | C)* <= E                        |    1.66 ms |    70.1 us |    47.0 us |    53.2 us |      23.72 |       1.49 |       0.88 |    17.2 us |     3.3 us |     0.9 us |     1.0 us |
| counterexample (B | C)*; A; (B | C)^n, E |    1.62 ms |    80.1 us |    62.0 us |    62.0 us |      20.22 |       1.29 |       1.00 |    17.6 us |     3.1 us |     1.4 us |     1.4 us |
| leq C* <= E2                             |    1.36 ms |    78.2 us |    52.0 us |    58.9 us |      17.44 |       1.50 |       0.88 |    19.9 us |     3.7 us |     1.1 us |     1.2 us |
| **traces-regex-interval: cost corpus (20 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    1.01 ms |   175.0 us |   158.1 us |   158.1 us |       5.78 |       1.11 |       1.00 |   351.2 us |    20.7 us |    19.1 us |    19.1 us |
| leq, all pairs                           |    7.13 ms |    7.98 ms |    6.92 ms |    5.39 ms |       0.89 |       1.15 |       1.28 |   695.8 us |    1.27 ms |   606.5 us |   645.6 us |
| equal, all pairs                         |    7.48 ms |    8.20 ms |    7.10 ms |    5.68 ms |       0.91 |       1.15 |       1.25 |   824.9 us |    1.50 ms |   720.0 us |   764.6 us |
| counterexample, all pairs                |   12.96 ms |    8.33 ms |    7.15 ms |    5.59 ms |       1.55 |       1.16 |       1.28 |    6.14 ms |    1.41 ms |   698.2 us |   739.7 us |
| **traces-regex-interval: delays, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   444.9 us |    85.8 us |    66.0 us |    62.9 us |       5.18 |       1.30 |       1.05 |     2.3 us |     2.9 us |     1.9 us |     2.1 us |
| leq S <= T (false)                       |    62.9 us |    35.0 us |    21.9 us |    30.0 us |       1.80 |       1.60 |       0.73 |     1.1 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |    64.1 us |    34.1 us |    24.1 us |    29.1 us |       1.88 |       1.42 |       0.83 |     1.9 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |   747.0 us |    93.0 us |    80.8 us |    75.8 us |       8.03 |       1.15 |       1.07 |     2.9 us |     2.8 us |     1.8 us |     2.0 us |
| equal T = T | R                          |    1.55 ms |   158.1 us |   140.9 us |   118.0 us |       9.84 |       1.12 |       1.19 |   101.6 us |     6.9 us |     4.0 us |     4.3 us |
| **traces-regex-interval: delays, n = 32** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   313.0 us |    81.1 us |    67.9 us |    61.0 us |       3.86 |       1.19 |       1.11 |     3.6 us |     2.9 us |     1.9 us |     2.0 us |
| leq S <= T (false)                       |   242.9 us |    32.9 us |    21.0 us |    29.1 us |       7.38 |       1.57 |       0.72 |     1.8 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |   242.0 us |    35.0 us |    26.0 us |    30.0 us |       6.90 |       1.35 |       0.87 |     2.6 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |    5.69 ms |    91.1 us |    83.9 us |    74.9 us |      62.46 |       1.09 |       1.12 |     6.1 us |     2.8 us |     1.8 us |     2.0 us |
| equal T = T | R                          |   18.67 ms |   162.1 us |   145.0 us |   127.1 us |     115.13 |       1.12 |       1.14 |    1.02 ms |     6.9 us |     4.0 us |     4.3 us |
| **traces-regex-interval: delays, n = 128** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    3.43 ms |    88.0 us |    74.1 us |    65.1 us |      39.01 |       1.19 |       1.14 |     9.0 us |     2.9 us |     1.9 us |     2.1 us |
| leq S <= T (false)                       |    3.23 ms |    34.1 us |    21.9 us |    28.1 us |      94.77 |       1.55 |       0.78 |     4.5 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |    3.20 ms |    36.0 us |    22.9 us |    30.0 us |      88.85 |       1.57 |       0.76 |     5.3 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |   96.68 ms |   108.0 us |    88.9 us |    85.1 us |     895.18 |       1.21 |       1.04 |    19.1 us |     2.8 us |     1.8 us |     2.0 us |
| equal T = T | R                          |  307.69 ms |   180.0 us |   154.0 us |   142.1 us |    1709.34 |       1.17 |       1.08 |   16.72 ms |     6.9 us |     4.0 us |     4.3 us |
| **traces-regex-interval: delays, n = 1024** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |  259.43 ms |   121.1 us |   100.9 us |    98.9 us |    2141.94 |       1.20 |       1.02 |    58.5 us |     2.9 us |     1.9 us |     2.0 us |
| leq S <= T (false)                       |  258.31 ms |    35.0 us |    22.9 us |    30.0 us |    7370.28 |       1.53 |       0.76 |    29.4 us |     1.5 us |     0.9 us |     1.0 us |
| counterexample S, T                      |  258.29 ms |    35.0 us |    25.0 us |    29.1 us |    7369.76 |       1.40 |       0.86 |    30.3 us |     1.5 us |     1.0 us |     1.0 us |
| leq R <= T                               |     7.97 s |   564.1 us |   568.2 us |   546.0 us |   14127.19 |       0.99 |       1.04 |          - |     2.8 us |     1.8 us |     2.0 us |
| equal T = T | R                          |     > 10 s |   813.0 us |   771.0 us |   745.1 us |    > 12300 |       1.05 |       1.03 |            |     6.9 us |     4.0 us |     4.4 us |
| **traces-regex-interval: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    58.2 us |   103.0 us |    78.9 us |    72.0 us |       0.56 |       1.31 |       1.10 |     3.8 us |     5.3 us |     3.8 us |     3.8 us |
| leq W <= X (false)                       |    37.2 us |    52.0 us |    34.1 us |    44.1 us |       0.72 |       1.52 |       0.77 |     1.9 us |     2.7 us |     1.9 us |     1.9 us |
| counterexample W, X                      |    40.1 us |    61.0 us |    33.9 us |    42.9 us |       0.66 |       1.80 |       0.79 |     2.7 us |     2.7 us |     1.9 us |     1.9 us |
| leq Y <= {8}                             |    92.0 us |    86.1 us |    70.1 us |    60.1 us |       1.07 |       1.23 |       1.17 |     1.0 us |     0.8 us |     0.7 us |     0.6 us |
| inhabited X                              |    28.1 us |    55.1 us |    40.1 us |    47.0 us |       0.51 |       1.38 |       0.85 |     3.1 us |     5.7 us |     5.5 us |     3.4 us |
| **traces-regex-interval: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   110.9 us |   395.1 us |   660.9 us |   467.1 us |       0.28 |       0.60 |       1.42 |    15.8 us |    23.4 us |    16.2 us |    15.5 us |
| leq W <= X (false)                       |    52.0 us |    90.1 us |    38.9 us |   438.0 us |       0.58 |       2.32 |       0.09 |     7.8 us |    11.7 us |     8.1 us |     7.7 us |
| counterexample W, X                      |    51.0 us |    89.9 us |    39.1 us |   417.0 us |       0.57 |       2.30 |       0.09 |     8.7 us |    11.7 us |     8.1 us |     7.7 us |
| leq Y <= {8}                             |   170.0 us |   144.0 us |   141.9 us |    62.0 us |       1.18 |       1.02 |       2.29 |     2.9 us |     2.7 us |     2.6 us |     2.0 us |
| inhabited X                              |    37.9 us |    95.8 us |    57.2 us |    47.0 us |       0.40 |       1.68 |       1.22 |    12.4 us |    22.9 us |    21.5 us |    10.8 us |
| **traces-regex-interval: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   615.1 us |    3.58 ms |    3.28 ms |   192.9 us |       0.17 |       1.09 |      17.02 |    69.4 us |   110.3 us |    77.0 us |    72.8 us |
| leq W <= X (false)                       |   200.0 us |   629.2 us |    99.9 us |    93.0 us |       0.32 |       6.30 |       1.07 |    34.8 us |    55.9 us |    39.3 us |    36.2 us |
| counterexample W, X                      |   198.8 us |   653.0 us |   105.9 us |    96.1 us |       0.30 |       6.17 |       1.10 |    35.7 us |    56.5 us |    39.3 us |    36.4 us |
| leq Y <= {8}                             |   891.0 us |   669.0 us |    1.14 ms |   101.1 us |       1.33 |       0.58 |      11.33 |    12.9 us |    12.9 us |    12.8 us |     8.9 us |
| inhabited X                              |   155.0 us |   572.9 us |   226.0 us |   114.9 us |       0.27 |       2.53 |       1.97 |    55.1 us |   105.1 us |    97.9 us |    45.6 us |
| **traces-regex-interval: 512 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    6.09 ms |   39.10 ms |   32.41 ms |    5.66 ms |       0.16 |       1.21 |       5.73 |   314.7 us |   545.8 us |   381.2 us |   355.4 us |
| leq W <= X (false)                       |    1.63 ms |    4.71 ms |   850.9 us |   201.0 us |       0.35 |       5.53 |       4.23 |   155.4 us |   276.0 us |   191.9 us |   188.5 us |
| counterexample W, X                      |    1.69 ms |    4.93 ms |   881.2 us |   207.9 us |       0.34 |       5.60 |       4.24 |   156.9 us |   275.0 us |   191.9 us |   189.3 us |
| leq Y <= {8}                             |    4.52 ms |    2.27 ms |    3.94 ms |    83.2 us |       1.99 |       0.58 |      47.36 |    52.7 us |    54.9 us |    53.6 us |    39.0 us |
| inhabited X                              |    1.00 ms |    3.44 ms |    1.63 ms |    5.78 ms |       0.29 |       2.11 |       0.28 |   238.7 us |   523.3 us |   498.6 us |   215.7 us |
| **traces-regex-interval: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    1.51 ms |   154.0 us |   126.8 us |   119.0 us |       9.80 |       1.21 |       1.07 |   755.5 us |    10.2 us |     5.0 us |     5.1 us |
| leq (B | C)* <= E                        |   220.8 us |   458.0 us |   449.9 us |   351.0 us |       0.48 |       1.02 |       1.28 |     3.1 us |     5.9 us |     1.6 us |     1.7 us |
| counterexample (B | C)*; A; (B | C)^n, E |   242.0 us |   472.1 us |   464.0 us |   353.1 us |       0.51 |       1.02 |       1.31 |     3.7 us |     5.3 us |     2.1 us |     2.2 us |
| leq C* <= E2                             |   160.0 us |    3.97 ms |    3.67 ms |    3.84 ms |       0.04 |       1.08 |       0.96 |     3.5 us |     6.6 us |     1.9 us |     2.1 us |
| **traces-regex-interval: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   71.97 ms |   167.8 us |   133.0 us |   132.1 us |     428.76 |       1.26 |       1.01 |   68.27 ms |    18.5 us |     9.6 us |     9.6 us |
| leq (B | C)* <= E                        |    3.99 ms |    8.34 ms |    8.66 ms |    6.58 ms |       0.48 |       0.96 |       1.32 |    34.7 us |     6.7 us |     1.9 us |     2.0 us |
| counterexample (B | C)*; A; (B | C)^n, E |    4.17 ms |    8.36 ms |    8.83 ms |    6.33 ms |       0.50 |       0.95 |       1.40 |    35.3 us |     6.3 us |     2.8 us |     2.9 us |
| leq C* <= E2                             |    3.80 ms |  453.38 ms |  454.84 ms |  458.89 ms |       0.01 |       1.00 |       0.99 |    40.0 us |     8.0 us |     2.2 us |     2.4 us |
