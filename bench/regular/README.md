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
where the minterms are the letters. Run from the root of the repository:

    dune exec --profile release bench/regular/bench_regular.exe

Each measurement runs in a fresh child process, so that the tables the
derivatives keep start empty: it prepares its inputs untimed, then times the
operation once (cold) and then repeatedly (warm, the mean of the repeated
runs). The table shows the medians over 5 processes (fewer past 10 s of total
measurement); a cell reads `> 20 s` when a single run was killed at that
alarm. The ratios are of the cold times; a ratio is left empty when its
denominator is below the resolution of the clock.

## Measured

- 2026-09-27
- macOS 15.7.7 (Darwin 24.6.0, arm64)
- OCaml 5.5.0, dune 3.24.2
- `--profile release`
- Total run time: 14 min 32 s (the two `> 20 s` cells, both of the automata
  in the plain grade's "n-th letter from the end, n = 16" family, account for
  a large part of it)

## Summary

Geometric means of the ratios of the cold times over the rows in which all
four implementations take at least 5 us:

| rows                                | count | automata / plain | plain / letters | letters / symbolic | automata / symbolic |
|-------------------------------------|------:|-----------------:|----------------:|-------------------:|--------------------:|
| typechecking                        |    25 |             1.00 |            1.06 |               1.00 |                1.06 |
| operations of the plain grade       |    53 |             2.87 |            1.27 |               1.26 |                4.56 |
| operations of the cost-model grades |   105 |             1.17 |            1.30 |               1.04 |                1.58 |

On the operations of the plain grade, of the factor 4.56 between automata and
symbolic derivatives, about 70% on a logarithmic scale is due to the
construction, about 15% to the letter sets and about 15% to the minterms. The
extremes are in the construction: the automata elaborate complements and
intersections by the subset and product constructions, up to four orders of
magnitude slower on the "n-th letter from the end" family, but decide
inclusion and equality of their canonical automata faster on small grades.
The minterms matter where one letter set names many operations: up to 155
times on "alphabet of k = 128 names", where the letters implementation
derives by 130 letters and the symbolic one by 3 minterms. Where every name is
told apart they cost instead, up to 33 times on "k names told apart", the
partition into minterms taking time quadratic in the number of letter sets. Without letter sets, the plain implementation pays for the alignment of
alphabets: up to 38 times on `mul` of the corpus, and 18 to 20 times on `mul`
and `join` over 128 names. The cost-model grades search automata over the concrete
letters in all four implementations; there the minterms hardly matter, and
the letter sets account for most of the difference.

## Results

Median over 5 processes (fewer past 10 s); cold: first run in a fresh process, warm: mean of repeated runs; ratios of the cold times: automata / plain (construction), plain / letters (representation), letters / symbolic (minterms).

| workload                                 |   automata |      plain |    letters |   symbolic |  aut/plain |  plain/let |   let/symb |  aut. warm |   pl. warm |  let. warm |  sym. warm |
|------------------------------------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|
| **typechecking, traces-regex**           |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   44.30 ms |   40.57 ms |   39.59 ms |   39.43 ms |       1.09 |       1.02 |       1.00 |   38.00 ms |   34.22 ms |   33.42 ms |   33.23 ms |
| examples/regular/regular_traces.tpe      |   54.10 ms |   49.43 ms |   42.86 ms |   42.74 ms |       1.09 |       1.15 |       1.00 |   48.44 ms |   42.90 ms |   36.39 ms |   36.14 ms |
| tests/literals_regular.tpe               |   44.72 ms |   40.79 ms |   39.75 ms |   39.87 ms |       1.10 |       1.03 |       1.00 |   38.83 ms |   34.28 ms |   33.64 ms |   33.49 ms |
| tests/regular_auth.tpe                   |   47.05 ms |   42.82 ms |   40.82 ms |   40.04 ms |       1.10 |       1.05 |       1.02 |   41.44 ms |   36.14 ms |   33.93 ms |   34.01 ms |
| tests/regular_protocol.tpe               |   52.11 ms |   47.51 ms |   42.17 ms |   41.87 ms |       1.10 |       1.13 |       1.01 |   46.38 ms |   41.46 ms |   35.37 ms |   35.57 ms |
| tests/regular_reject_auth.tpe            |   46.19 ms |   41.40 ms |   40.12 ms |   40.48 ms |       1.12 |       1.03 |       0.99 |   39.87 ms |   35.30 ms |   33.74 ms |   33.79 ms |
| tests/regular_reject_bounds.tpe          |   42.22 ms |   38.39 ms |   37.20 ms |   37.15 ms |       1.10 |       1.03 |       1.00 |   38.29 ms |   34.24 ms |   33.32 ms |   33.29 ms |
| tests/regular_reject_counterexample.tpe  |   44.44 ms |   39.95 ms |   38.44 ms |   38.33 ms |       1.11 |       1.04 |       1.00 |   40.89 ms |   35.44 ms |   33.85 ms |   33.76 ms |
| tests/regular_reject_protocol.tpe        |   43.69 ms |   39.82 ms |   38.29 ms |   38.05 ms |       1.10 |       1.04 |       1.01 |   40.26 ms |   35.35 ms |   33.45 ms |   33.48 ms |
| **corpus (29 literals)**                 |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    1.87 ms |   268.0 us |   253.9 us |   268.9 us |       6.99 |       1.06 |       0.94 |   500.6 us |    36.3 us |    31.7 us |    31.7 us |
| mul, all pairs                           |   13.09 ms |    3.97 ms |   104.9 us |   104.9 us |       3.30 |      37.83 |       1.00 |   11.54 ms |    1.53 ms |    50.6 us |    49.9 us |
| join, all pairs                          |   10.48 ms |    3.76 ms |    1.16 ms |    1.15 ms |       2.79 |       3.25 |       1.01 |    9.19 ms |    1.57 ms |   197.7 us |   197.0 us |
| leq, all pairs                           |    4.67 ms |    7.48 ms |    4.90 ms |    5.17 ms |       0.62 |       1.53 |       0.95 |    3.97 ms |    1.56 ms |   177.9 us |   178.8 us |
| equal, all pairs                         |    23.1 us |    4.87 ms |    1.52 ms |    1.65 ms |       0.00 |       3.19 |       0.92 |    20.3 us |    1.38 ms |    26.5 us |    26.9 us |
| counterexample, all pairs                |    8.78 ms |    6.89 ms |    4.35 ms |    4.75 ms |       1.28 |       1.58 |       0.92 |    7.69 ms |    2.73 ms |    1.23 ms |    1.50 ms |
| **protocol P^k, k = 2**                  |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |    17.9 us |     2.1 us |     2.1 us |     1.9 us |       8.33 |       1.00 |       1.12 |    10.4 us |     0.3 us |     0.1 us |     0.1 us |
| join J = P \| ... \| P^k                 |    37.0 us |     5.0 us |     6.0 us |     4.1 us |       7.38 |       0.84 |       1.47 |    18.7 us |     0.5 us |     0.2 us |     0.2 us |
| leq P^k <= P*                            |     6.9 us |    22.9 us |    21.0 us |    15.0 us |       0.30 |       1.09 |       1.40 |     1.5 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |     5.0 us |    27.9 us |    27.2 us |    22.2 us |       0.18 |       1.03 |       1.23 |     1.7 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample P; P*, J                  |    49.1 us |    29.1 us |    29.1 us |    25.0 us |       1.69 |       1.00 |       1.16 |    26.8 us |     4.9 us |     4.6 us |     4.5 us |
| equal J \| P; P* = P; P*                 |    15.0 us |    22.9 us |    22.9 us |    21.0 us |       0.66 |       1.00 |       1.09 |     8.5 us |     0.5 us |     0.2 us |     0.2 us |
| **protocol P^k, k = 8**                  |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |    1.10 ms |     9.1 us |     7.2 us |     5.0 us |     121.63 |       1.27 |       1.43 |   265.9 us |     3.4 us |     2.2 us |     2.2 us |
| join J = P \| ... \| P^k                 |    2.39 ms |    29.1 us |    20.0 us |    18.8 us |      82.03 |       1.45 |       1.06 |    1.02 ms |    14.5 us |     8.8 us |     8.8 us |
| leq P^k <= P*                            |     8.8 us |    53.9 us |    57.0 us |    38.9 us |       0.16 |       0.95 |       1.47 |     4.9 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |    10.0 us |   104.9 us |   109.2 us |    82.0 us |       0.10 |       0.96 |       1.33 |     5.5 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample P; P*, J                  |   170.9 us |   116.1 us |   122.8 us |    93.9 us |       1.47 |       0.95 |       1.31 |   162.8 us |    14.8 us |    14.7 us |    13.3 us |
| equal J \| P; P* = P; P*                 |    24.1 us |    79.2 us |    85.8 us |    65.1 us |       0.30 |       0.92 |       1.32 |    21.0 us |     0.9 us |     0.6 us |     0.6 us |
| **protocol P^k, k = 32**                 |            |            |            |            |            |            |            |            |            |            |            |
| mul P^k                                  |   13.44 ms |    79.9 us |    67.0 us |    64.8 us |     168.28 |       1.19 |       1.03 |   11.59 ms |    50.5 us |    45.2 us |    44.9 us |
| join J = P \| ... \| P^k                 |  115.38 ms |    1.97 ms |    2.10 ms |    2.05 ms |      58.51 |       0.94 |       1.03 |  112.01 ms |   643.6 us |   537.0 us |   542.9 us |
| leq P^k <= P*                            |    26.0 us |   341.2 us |   187.9 us |   141.9 us |       0.08 |       1.82 |       1.32 |    20.6 us |     0.3 us |     0.1 us |     0.1 us |
| leq P; P* <= J (false)                   |    30.0 us |    1.42 ms |   902.9 us |   684.0 us |       0.02 |       1.57 |       1.32 |    23.2 us |     0.3 us |     0.2 us |     0.2 us |
| counterexample P; P*, J                  |    2.20 ms |    1.52 ms |    1.68 ms |   786.1 us |       1.45 |       0.90 |       2.13 |    2.08 ms |   109.1 us |   106.0 us |    98.5 us |
| equal J \| P; P* = P; P*                 |    85.1 us |    1.35 ms |   773.9 us |   612.0 us |       0.06 |       1.74 |       1.26 |    81.5 us |     4.4 us |     4.2 us |     4.2 us |
| **nested protocol N_d, d = 1**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |    1.02 ms |   133.0 us |   112.1 us |   140.0 us |       7.65 |       1.19 |       0.80 |    75.0 us |     3.1 us |     3.2 us |     3.2 us |
| leq N_d <= N_d+1                         |     7.9 us |    26.9 us |    21.0 us |    19.1 us |       0.29 |       1.28 |       1.10 |     1.2 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |    42.0 us |    26.9 us |    23.1 us |    21.0 us |       1.56 |       1.16 |       1.10 |    28.1 us |     5.0 us |     4.7 us |     4.5 us |
| equal N_d = N_d \| P                     |     1.0 us |    12.2 us |    11.9 us |    10.0 us |       0.08 |       1.02 |       1.19 |     0.2 us |     0.2 us |     0.0 us |     0.0 us |
| **nested protocol N_d, d = 3**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |    1.11 ms |   133.0 us |   137.1 us |   137.1 us |       8.31 |       0.97 |       1.00 |   194.6 us |     6.0 us |     6.1 us |     6.1 us |
| leq N_d <= N_d+1                         |     6.0 us |    41.0 us |    39.1 us |    31.0 us |       0.15 |       1.05 |       1.26 |     1.8 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |   196.0 us |    49.1 us |    48.9 us |    36.0 us |       3.99 |       1.00 |       1.36 |    59.9 us |     7.9 us |     7.5 us |     6.9 us |
| equal N_d = N_d \| P                     |     1.0 us |    13.1 us |    12.9 us |    11.9 us |       0.07 |       1.02 |       1.08 |     0.2 us |     0.2 us |     0.0 us |     0.0 us |
| **nested protocol N_d, d = 6**           |            |            |            |            |            |            |            |            |            |            |            |
| elaborate N_d                            |    1.94 ms |   144.0 us |   126.8 us |   125.2 us |      13.50 |       1.14 |       1.01 |   490.9 us |    10.4 us |    10.8 us |    10.7 us |
| leq N_d <= N_d+1                         |     6.2 us |    57.0 us |    47.2 us |    37.9 us |       0.11 |       1.21 |       1.25 |     2.6 us |     0.3 us |     0.1 us |     0.1 us |
| counterexample N_d+1, N_d                |   144.0 us |    66.0 us |    57.0 us |    47.0 us |       2.18 |       1.16 |       1.21 |   132.0 us |    13.2 us |    12.8 us |    11.8 us |
| equal N_d = N_d \| P                     |     1.0 us |    18.1 us |    11.9 us |    11.9 us |       0.05 |       1.52 |       1.00 |     0.3 us |     0.3 us |     0.0 us |     0.0 us |
| **n-th letter from the end, n = 4**      |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |    1.23 ms |   108.0 us |   121.1 us |   104.9 us |      11.39 |       0.89 |       1.15 |   193.4 us |     3.2 us |     1.8 us |     1.8 us |
| elaborate E2                             |    2.55 ms |   120.9 us |    92.0 us |   107.0 us |      21.13 |       1.31 |       0.86 |   857.9 us |     7.9 us |     3.2 us |     3.3 us |
| leq (B \| C)* <= E                       |    90.1 us |    39.1 us |    23.8 us |    21.9 us |       2.30 |       1.64 |       1.09 |    54.6 us |     2.6 us |     0.1 us |     0.1 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |   120.9 us |    37.0 us |    31.9 us |    25.0 us |       3.27 |       1.16 |       1.28 |    74.9 us |     5.8 us |     3.7 us |     3.5 us |
| leq C* <= E2                             |    62.0 us |    40.1 us |    27.2 us |    26.0 us |       1.55 |       1.47 |       1.05 |    53.9 us |     2.8 us |     0.1 us |     0.1 us |
| elaborate E', decide E = E'              |   865.2 us |   252.0 us |   231.0 us |   159.0 us |       3.43 |       1.09 |       1.45 |   332.5 us |     7.5 us |     4.4 us |     4.4 us |
| **n-th letter from the end, n = 8**      |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |    8.99 ms |   124.0 us |   114.0 us |   112.1 us |      72.53 |       1.09 |       1.02 |    6.06 ms |     5.6 us |     3.1 us |     3.1 us |
| elaborate E2                             |   91.87 ms |   178.1 us |   150.2 us |   118.0 us |     515.85 |       1.19 |       1.27 |   86.61 ms |    14.3 us |     5.9 us |     5.9 us |
| leq (B \| C)* <= E                       |    2.27 ms |    41.0 us |    26.0 us |    21.2 us |      55.38 |       1.58 |       1.22 |    1.79 ms |     2.8 us |     0.1 us |     0.1 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |    2.30 ms |    53.9 us |    48.9 us |    37.9 us |      42.71 |       1.10 |       1.29 |    1.83 ms |     8.7 us |     6.3 us |     5.6 us |
| leq C* <= E2                             |    2.03 ms |    47.0 us |    30.0 us |    29.1 us |      43.14 |       1.56 |       1.03 |    1.75 ms |     3.0 us |     0.1 us |     0.1 us |
| elaborate E', decide E = E'              |   10.26 ms |    7.44 ms |    7.09 ms |    5.47 ms |       1.38 |       1.05 |       1.30 |    9.14 ms |    14.4 us |     8.6 us |     8.7 us |
| **n-th letter from the end, n = 12**     |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |  173.60 ms |   124.9 us |   119.0 us |   156.2 us |    1389.55 |       1.05 |       0.76 |  168.38 ms |     8.4 us |     4.7 us |     4.7 us |
| elaborate E2                             |    10.23 s |   180.0 us |   129.9 us |   127.8 us |   56836.51 |       1.39 |       1.02 |          - |    21.4 us |     9.2 us |     9.2 us |
| leq (B \| C)* <= E                       |   51.04 ms |    37.9 us |    21.2 us |    19.1 us |    1346.48 |       1.79 |       1.11 |   50.29 ms |     3.3 us |     0.1 us |     0.1 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |   51.23 ms |    72.0 us |    61.0 us |    45.1 us |     711.45 |       1.18 |       1.35 |   49.36 ms |    12.2 us |     9.3 us |     8.3 us |
| leq C* <= E2                             |   51.05 ms |    47.0 us |    27.2 us |    26.9 us |    1086.92 |       1.73 |       1.01 |   52.50 ms |     3.5 us |     0.1 us |     0.1 us |
| elaborate E', decide E = E'              |  251.43 ms |  115.94 ms |  113.28 ms |   78.14 ms |       2.17 |       1.02 |       1.45 |  250.90 ms |    24.6 us |    14.8 us |    16.0 us |
| **n-th letter from the end, n = 16**     |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E                              |     4.08 s |   111.1 us |    93.9 us |    88.0 us |   36743.62 |       1.18 |       1.07 |          - |    11.6 us |     6.7 us |     6.7 us |
| elaborate E2                             |     > 20 s |   167.8 us |   114.9 us |   117.1 us |   > 119156 |       1.46 |       0.98 |            |    29.3 us |    13.2 us |    13.2 us |
| leq (B \| C)* <= E                       |     1.19 s |    36.0 us |    22.9 us |    19.1 us |   33077.23 |       1.57 |       1.20 |          - |     3.5 us |     0.1 us |     0.1 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |     1.18 s |    93.0 us |    84.2 us |    60.1 us |   12640.81 |       1.10 |       1.40 |          - |    15.7 us |    12.9 us |    11.6 us |
| leq C* <= E2                             |     > 20 s |    45.1 us |    26.2 us |    21.9 us |   > 443842 |       1.72 |       1.20 |            |     3.8 us |     0.1 us |     0.1 us |
| elaborate E', decide E = E'              |     6.13 s |     3.73 s |     3.63 s |     2.50 s |       1.64 |       1.03 |       1.45 |          - |          - |          - |          - |
| **alphabet of k = 8 names**              |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |   734.1 us |   134.9 us |   152.1 us |   116.1 us |       5.44 |       0.89 |       1.31 |   157.4 us |     8.9 us |     8.3 us |     8.2 us |
| mul X W                                  |    19.1 us |     1.9 us |     1.0 us |     0.0 us |      10.00 |       2.00 |            |    10.8 us |     0.6 us |     0.1 us |     0.1 us |
| join X W                                 |    13.8 us |     4.1 us |     1.9 us |     1.0 us |       3.41 |       2.12 |       2.00 |     6.4 us |     0.6 us |     0.1 us |     0.1 us |
| leq X <= W                               |     4.1 us |    28.8 us |    26.0 us |    14.1 us |       0.14 |       1.11 |       1.85 |     1.9 us |     0.7 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |     2.9 us |     9.1 us |    10.0 us |     7.2 us |       0.32 |       0.90 |       1.40 |     0.7 us |     0.7 us |     0.1 us |     0.1 us |
| counterexample W, X                      |    10.0 us |     3.8 us |     2.9 us |     3.1 us |       2.62 |       1.33 |       0.92 |     3.8 us |     0.7 us |     0.1 us |     0.1 us |
| equal W = W \| X                         |     1.0 us |    29.1 us |    24.1 us |    14.1 us |       0.03 |       1.21 |       1.71 |     0.1 us |     0.5 us |     0.0 us |     0.0 us |
| **alphabet of k = 32 names**             |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |    3.00 ms |   703.1 us |   246.0 us |   196.9 us |       4.26 |       2.86 |       1.25 |    1.43 ms |   121.0 us |    55.2 us |    54.9 us |
| mul X W                                  |    78.9 us |     7.9 us |     0.0 us |     0.0 us |      10.03 |            |            |    33.7 us |     2.7 us |     0.1 us |     0.1 us |
| join X W                                 |    23.8 us |     5.0 us |     2.1 us |     1.2 us |       4.76 |       2.33 |       1.80 |    22.3 us |     2.8 us |     0.1 us |     0.1 us |
| leq X <= W                               |    16.0 us |   189.1 us |   385.0 us |    11.0 us |       0.08 |       0.49 |      35.11 |    11.0 us |     2.8 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |     6.9 us |    24.1 us |   309.9 us |     9.1 us |       0.29 |       0.08 |      34.21 |     3.2 us |     2.8 us |     0.1 us |     0.1 us |
| counterexample W, X                      |    89.2 us |    10.0 us |     2.9 us |     2.9 us |       8.90 |       3.50 |       1.00 |    13.0 us |     2.8 us |     0.1 us |     0.1 us |
| equal W = W \| X                         |     1.2 us |   136.9 us |    67.0 us |    15.0 us |       0.01 |       2.04 |       4.46 |     0.4 us |     2.5 us |     0.0 us |     0.0 us |
| **alphabet of k = 128 names**            |            |            |            |            |            |            |            |            |            |            |            |
| elaborate W, X                           |   22.70 ms |   13.52 ms |    1.36 ms |    1.17 ms |       1.68 |       9.97 |       1.15 |   18.67 ms |    4.15 ms |   607.1 us |   609.1 us |
| mul X W                                  |   176.9 us |    19.1 us |     1.0 us |     0.0 us |       9.28 |      20.00 |            |   176.2 us |    13.0 us |     0.1 us |     0.1 us |
| join X W                                 |   138.0 us |    16.9 us |     1.0 us |     1.0 us |       8.15 |      17.75 |       1.00 |   135.9 us |    13.0 us |     0.1 us |     0.1 us |
| leq X <= W                               |    95.8 us |    2.49 ms |    3.12 ms |    20.0 us |       0.04 |       0.80 |     155.64 |    98.4 us |    13.2 us |     0.1 us |     0.1 us |
| leq W <= X (false)                       |    18.1 us |    76.1 us |    46.0 us |    16.0 us |       0.24 |       1.65 |       2.88 |    15.1 us |    13.2 us |     0.1 us |     0.1 us |
| counterexample W, X                      |   104.9 us |    18.1 us |     3.8 us |     3.1 us |       5.79 |       4.75 |       1.23 |   100.2 us |    13.2 us |     0.1 us |     0.1 us |
| equal W = W \| X                         |     2.9 us |    1.38 ms |   993.0 us |    24.8 us |       0.00 |       1.39 |      40.05 |     1.4 us |    12.2 us |     0.0 us |     0.0 us |
| **k = 8 names told apart**               |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |    1.13 ms |   125.2 us |   129.9 us |   150.9 us |       9.03 |       0.96 |       0.86 |   379.2 us |     6.0 us |     5.6 us |     5.6 us |
| leq U <= V                               |    11.2 us |    49.1 us |    42.9 us |    47.9 us |       0.23 |       1.14 |       0.90 |     4.4 us |     0.7 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |     5.0 us |    11.0 us |    11.0 us |    15.0 us |       0.46 |       1.00 |       0.73 |     0.7 us |     0.7 us |     0.1 us |     0.1 us |
| counterexample V, U                      |    10.0 us |     5.0 us |     4.1 us |     4.1 us |       2.00 |       1.24 |       1.00 |     3.8 us |     0.7 us |     0.1 us |     0.1 us |
| equal V = 0 \| U; V                      |   133.0 us |    25.0 us |    16.9 us |    21.0 us |       5.31 |       1.48 |       0.81 |    86.2 us |     3.3 us |     0.4 us |     0.4 us |
| **k = 32 names told apart**              |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |   22.66 ms |   410.1 us |   416.0 us |   542.2 us |      55.26 |       0.99 |       0.77 |   20.79 ms |    45.3 us |    40.7 us |    40.7 us |
| leq U <= V                               |   165.9 us |    1.35 ms |    1.37 ms |    1.27 ms |       0.12 |       0.99 |       1.08 |   142.3 us |     2.9 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |     8.1 us |    26.0 us |    17.9 us |   595.8 us |       0.31 |       1.45 |       0.03 |     3.2 us |     2.8 us |     0.1 us |     0.1 us |
| counterexample V, U                      |    18.8 us |    10.0 us |     5.0 us |     4.1 us |       1.88 |       2.00 |       1.24 |    13.0 us |     2.8 us |     0.1 us |     0.1 us |
| equal V = 0 \| U; V                      |    2.34 ms |    75.1 us |    54.1 us |   619.2 us |      31.18 |       1.39 |       0.09 |    2.31 ms |    16.1 us |     1.0 us |     1.0 us |
| **k = 128 names told apart**             |            |            |            |            |            |            |            |            |            |            |            |
| elaborate U, V                           |     3.85 s |   15.72 ms |   14.93 ms |   16.24 ms |     244.62 |       1.05 |       0.92 |          - |   662.9 us |   595.7 us |   596.7 us |
| leq U <= V                               |    6.90 ms |   19.63 ms |   19.66 ms |   20.20 ms |       0.35 |       1.00 |       0.97 |    6.69 ms |    13.1 us |     0.1 us |     0.1 us |
| leq V <= U (false)                       |    26.0 us |    91.1 us |    72.0 us |    1.03 ms |       0.29 |       1.26 |       0.07 |    15.0 us |    13.4 us |     0.1 us |     0.1 us |
| counterexample V, U                      |   118.0 us |    21.0 us |     3.1 us |     3.1 us |       5.62 |       6.77 |       1.00 |   100.4 us |    13.3 us |     0.1 us |     0.1 us |
| equal V = 0 \| U; V                      |  116.20 ms |   273.9 us |   169.0 us |    1.15 ms |     424.18 |       1.62 |       0.15 |  116.33 ms |   100.8 us |     4.0 us |     4.0 us |
| **typechecking, traces-regex-upper**     |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   40.15 ms |   46.93 ms |   44.45 ms |   44.50 ms |       0.86 |       1.06 |       1.00 |   35.88 ms |   43.31 ms |   41.07 ms |   41.01 ms |
| examples/regular_costs/regular_costs_upper.tpe |   55.37 ms |   63.15 ms |   59.87 ms |   59.28 ms |       0.88 |       1.05 |       1.01 |   54.25 ms |   60.32 ms |   63.05 ms |   62.52 ms |
| tests/regex_costs_upper.tpe              |   49.37 ms |   57.63 ms |   57.20 ms |   57.60 ms |       0.86 |       1.01 |       0.99 |   46.20 ms |   58.29 ms |   55.49 ms |   55.69 ms |
| tests/regex_costs_upper_reject.tpe       |   49.20 ms |   56.18 ms |   55.84 ms |   55.59 ms |       0.88 |       1.01 |       1.00 |   45.67 ms |   65.88 ms |   53.65 ms |   56.20 ms |
| tests/regex_costs_upper_runs.tpe         |   44.44 ms |   51.63 ms |   48.88 ms |   49.09 ms |       0.86 |       1.06 |       1.00 |   48.08 ms |   55.72 ms |   45.88 ms |   48.48 ms |
| tests/regex_costs_upper_runs_reject.tpe  |   41.90 ms |   49.90 ms |   46.04 ms |   46.00 ms |       0.84 |       1.08 |       1.00 |   37.72 ms |   46.97 ms |   42.50 ms |   42.68 ms |
| **typechecking, traces-regex-lower**     |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   26.53 ms |   25.01 ms |   24.71 ms |   24.92 ms |       1.06 |       1.01 |       0.99 |   22.49 ms |   21.18 ms |   20.95 ms |   20.85 ms |
| examples/regular_costs/regular_costs_lower.tpe |   30.61 ms |   30.37 ms |   28.28 ms |   28.18 ms |       1.01 |       1.07 |       1.00 |   26.62 ms |   26.12 ms |   23.96 ms |   23.81 ms |
| tests/regex_costs_lower.tpe              |   29.60 ms |   28.63 ms |   27.10 ms |   27.17 ms |       1.03 |       1.06 |       1.00 |   25.42 ms |   24.81 ms |   22.92 ms |   23.03 ms |
| tests/regex_costs_lower_reject.tpe       |   30.63 ms |   27.94 ms |   26.83 ms |   26.80 ms |       1.10 |       1.04 |       1.00 |   26.20 ms |   23.78 ms |   22.62 ms |   22.64 ms |
| tests/regex_costs_lower_runs_reject.tpe  |   26.49 ms |   25.00 ms |   24.74 ms |   24.83 ms |       1.06 |       1.01 |       1.00 |   22.64 ms |   21.34 ms |   20.80 ms |   20.72 ms |
| **typechecking, traces-regex-interval**  |            |            |            |            |            |            |            |            |            |            |            |
| standard library alone                   |   49.86 ms |   51.88 ms |   48.02 ms |   47.89 ms |       0.96 |       1.08 |       1.00 |   45.77 ms |   48.42 ms |   44.71 ms |   44.46 ms |
| examples/regular_costs/regular_costs_intervals.tpe |   66.22 ms |   69.70 ms |   63.67 ms |   64.04 ms |       0.95 |       1.09 |       0.99 |   63.58 ms |   72.33 ms |   61.21 ms |   61.01 ms |
| tests/regex_costs_interval.tpe           |   55.47 ms |   58.08 ms |   53.50 ms |   53.19 ms |       0.96 |       1.09 |       1.01 |   52.15 ms |   55.35 ms |   52.07 ms |   51.85 ms |
| tests/regex_costs_interval_reject.tpe    |   55.01 ms |   56.83 ms |   52.34 ms |   52.35 ms |       0.97 |       1.09 |       1.00 |   52.10 ms |   54.53 ms |   53.30 ms |   53.26 ms |
| tests/regex_costs_interval_runs_reject.tpe |   50.97 ms |   55.07 ms |   49.58 ms |   49.37 ms |       0.93 |       1.11 |       1.00 |   47.38 ms |   52.25 ms |   46.40 ms |   46.27 ms |
| **traces-regex-upper: cost corpus (15 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    1.03 ms |   170.0 us |   170.0 us |   175.0 us |       6.08 |       1.00 |       0.97 |   226.5 us |    14.9 us |    14.3 us |    14.2 us |
| leq, all pairs                           |   10.13 ms |   12.53 ms |   13.32 ms |   13.16 ms |       0.81 |       0.94 |       1.01 |   209.5 us |   688.6 us |   310.6 us |   312.8 us |
| equal, all pairs                         |   10.04 ms |   12.84 ms |   13.09 ms |   13.29 ms |       0.78 |       0.98 |       0.98 |   295.6 us |   957.4 us |   435.5 us |   438.7 us |
| counterexample, all pairs                |   13.74 ms |   12.09 ms |   13.44 ms |   12.44 ms |       1.14 |       0.90 |       1.08 |    3.74 ms |   757.2 us |   363.3 us |   363.8 us |
| **traces-regex-upper: delays, n = 8**    |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    73.0 us |   605.1 us |   673.1 us |   607.0 us |       0.12 |       0.90 |       1.11 |     0.6 us |     2.4 us |     1.3 us |     1.3 us |
| leq S <= T (false)                       |   124.9 us |   692.1 us |   783.9 us |   759.1 us |       0.18 |       0.88 |       1.03 |     0.6 us |     2.5 us |     1.3 us |     1.3 us |
| counterexample S, T                      |   223.2 us |   743.9 us |   199.1 us |   189.1 us |       0.30 |       3.74 |       1.05 |    54.9 us |     3.2 us |     2.1 us |     2.0 us |
| leq R <= T                               |   134.9 us |   172.1 us |   199.1 us |   189.1 us |       0.78 |       0.86 |       1.05 |     0.6 us |     2.7 us |     1.6 us |     1.6 us |
| equal T = T \| R                         |    1.12 ms |   400.1 us |   492.1 us |   475.9 us |       2.80 |       0.81 |       1.03 |    66.0 us |     7.1 us |     3.9 us |     3.8 us |
| **traces-regex-upper: delays, n = 32**   |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   299.0 us |   269.2 us |   286.1 us |   293.0 us |       1.11 |       0.94 |       0.98 |     0.6 us |     5.4 us |     2.7 us |     2.7 us |
| leq S <= T (false)                       |    1.23 ms |    2.49 ms |    2.65 ms |    2.58 ms |       0.49 |       0.94 |       1.03 |     0.6 us |     5.4 us |     2.6 us |     2.6 us |
| counterexample S, T                      |    1.90 ms |    2.51 ms |    2.58 ms |    2.60 ms |       0.76 |       0.97 |       0.99 |   603.6 us |    10.6 us |     7.5 us |     7.5 us |
| leq R <= T                               |   803.9 us |    1.76 ms |    2.13 ms |    2.06 ms |       0.46 |       0.83 |       1.03 |     0.6 us |     7.3 us |     4.6 us |     4.6 us |
| equal T = T \| R                         |    3.28 ms |    3.41 ms |    4.13 ms |    4.03 ms |       0.96 |       0.83 |       1.03 |   724.2 us |    21.5 us |    13.3 us |    13.3 us |
| **traces-regex-upper: delays, n = 128**  |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    4.36 ms |    3.55 ms |    3.60 ms |    3.81 ms |       1.23 |       0.99 |       0.94 |     0.6 us |    20.3 us |    10.7 us |    10.6 us |
| leq S <= T (false)                       |   29.70 ms |   31.72 ms |   35.09 ms |   34.70 ms |       0.94 |       0.90 |       1.01 |     0.6 us |    21.3 us |    10.7 us |    10.6 us |
| counterexample S, T                      |   51.98 ms |   31.36 ms |   34.89 ms |   34.56 ms |       1.66 |       0.90 |       1.01 |   21.36 ms |    98.1 us |    85.4 us |    85.1 us |
| leq R <= T                               |   12.69 ms |   13.55 ms |   16.96 ms |   17.03 ms |       0.94 |       0.80 |       1.00 |     0.6 us |    33.4 us |    22.2 us |    22.3 us |
| equal T = T \| R                         |   52.54 ms |   35.47 ms |   47.72 ms |   48.01 ms |       1.48 |       0.74 |       0.99 |   11.78 ms |   103.4 us |    74.1 us |    74.6 us |
| **traces-regex-upper: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    37.0 us |    86.1 us |    85.8 us |    83.0 us |       0.43 |       1.00 |       1.03 |     1.2 us |     2.4 us |     1.9 us |     1.9 us |
| leq W <= X (false)                       |    65.1 us |   119.9 us |   143.1 us |   122.1 us |       0.54 |       0.84 |       1.17 |     1.2 us |     2.4 us |     1.9 us |     1.9 us |
| counterexample W, X                      |   105.9 us |   114.2 us |   139.0 us |   112.1 us |       0.93 |       0.82 |       1.24 |    19.5 us |     2.9 us |     2.3 us |     2.3 us |
| leq Y <= {8}                             |   237.0 us |   280.9 us |   300.2 us |   299.9 us |       0.84 |       0.94 |       1.00 |     0.5 us |     1.1 us |     1.0 us |     1.0 us |
| inhabited X                              |    15.0 us |    40.1 us |    17.2 us |    24.1 us |       0.38 |       2.33 |       0.71 |     5.8 us |     4.2 us |     3.6 us |     3.5 us |
| **traces-regex-upper: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   132.1 us |    1.02 ms |    1.13 ms |   232.0 us |       0.13 |       0.90 |       4.86 |     5.5 us |    10.7 us |     7.8 us |     7.9 us |
| leq W <= X (false)                       |   293.0 us |    1.61 ms |    1.68 ms |    1.27 ms |       0.18 |       0.96 |       1.32 |     5.5 us |    10.7 us |     7.8 us |     7.8 us |
| counterexample W, X                      |   313.0 us |   803.0 us |    1.70 ms |    1.16 ms |       0.39 |       0.47 |       1.46 |    23.9 us |    11.2 us |     8.3 us |     8.3 us |
| leq Y <= {8}                             |    1.93 ms |    2.59 ms |    3.14 ms |    3.11 ms |       0.75 |       0.82 |       1.01 |     2.1 us |     2.6 us |     2.6 us |     2.6 us |
| inhabited X                              |    26.9 us |    77.0 us |    42.0 us |    52.0 us |       0.35 |       1.84 |       0.81 |    21.2 us |    22.2 us |    14.0 us |    13.9 us |
| **traces-regex-upper: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    1.25 ms |    2.71 ms |    4.97 ms |    2.79 ms |       0.46 |       0.54 |       1.78 |    23.7 us |    48.2 us |    35.7 us |    35.6 us |
| leq W <= X (false)                       |    3.31 ms |    4.80 ms |    8.35 ms |    5.04 ms |       0.69 |       0.58 |       1.66 |    23.8 us |    48.4 us |    35.6 us |    35.8 us |
| counterexample W, X                      |    3.38 ms |    4.79 ms |    8.37 ms |    4.94 ms |       0.71 |       0.57 |       1.69 |    42.3 us |    48.8 us |    35.9 us |    36.2 us |
| leq Y <= {8}                             |   28.86 ms |   29.18 ms |   31.27 ms |   31.00 ms |       0.99 |       0.93 |       1.01 |     9.4 us |     9.8 us |     9.9 us |     9.9 us |
| inhabited X                              |   140.0 us |   304.0 us |   124.0 us |   222.0 us |       0.46 |       2.45 |       0.56 |   134.4 us |   173.7 us |    61.4 us |    61.4 us |
| **traces-regex-upper: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    2.43 ms |   114.0 us |   124.0 us |    96.1 us |      21.37 |       0.92 |       1.29 |    1.05 ms |    11.3 us |     5.0 us |     5.0 us |
| leq (B \| C)* <= E                       |   140.2 us |    1.01 ms |    1.07 ms |    1.02 ms |       0.14 |       0.94 |       1.05 |     0.4 us |     3.4 us |     0.8 us |     0.9 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |   371.0 us |   998.0 us |    1.02 ms |   970.8 us |       0.37 |       0.97 |       1.05 |     0.4 us |     2.9 us |     1.1 us |     1.1 us |
| leq C* <= E2                             |    87.0 us |    2.10 ms |    2.68 ms |    2.00 ms |       0.04 |       0.79 |       1.34 |     0.4 us |     3.8 us |     1.1 us |     1.1 us |
| **traces-regex-upper: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   95.63 ms |   130.9 us |   119.9 us |   121.1 us |     730.62 |       1.09 |       0.99 |   92.62 ms |    20.1 us |     8.9 us |     8.9 us |
| leq (B \| C)* <= E                       |    3.09 ms |    7.05 ms |    9.26 ms |    8.48 ms |       0.44 |       0.76 |       1.09 |     0.4 us |     3.8 us |     1.0 us |     1.0 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |    3.69 ms |    7.81 ms |    9.73 ms |    8.83 ms |       0.47 |       0.80 |       1.10 |     0.4 us |     3.5 us |     1.5 us |     1.5 us |
| leq C* <= E2                             |    2.57 ms |  130.32 ms |  137.76 ms |  117.48 ms |       0.02 |       0.95 |       1.17 |     0.4 us |     4.4 us |     1.2 us |     1.2 us |
| **traces-regex-lower: cost corpus (15 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    1.24 ms |   173.8 us |   176.2 us |   164.0 us |       7.14 |       0.99 |       1.07 |   225.3 us |    15.0 us |    14.3 us |    14.3 us |
| leq, all pairs                           |    4.87 ms |    3.91 ms |    3.37 ms |    2.70 ms |       1.24 |       1.16 |       1.25 |   212.4 us |   692.5 us |   304.0 us |   299.9 us |
| equal, all pairs                         |    4.90 ms |    3.50 ms |    2.89 ms |    2.73 ms |       1.40 |       1.21 |       1.06 |   311.7 us |    1.01 ms |   440.6 us |   432.4 us |
| counterexample, all pairs                |    6.23 ms |    3.17 ms |    2.54 ms |    2.57 ms |       1.97 |       1.25 |       0.99 |    1.65 ms |   719.7 us |   324.2 us |   320.7 us |
| **traces-regex-lower: delays, n = 8**    |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    58.9 us |   764.1 us |   716.0 us |    47.0 us |       0.08 |       1.07 |      15.24 |     0.6 us |     2.4 us |     1.3 us |     1.3 us |
| leq S <= T (false)                       |    52.0 us |    30.0 us |     9.1 us |    12.2 us |       1.73 |       3.32 |       0.75 |     0.6 us |     2.5 us |     1.3 us |     1.3 us |
| counterexample S, T                      |    65.8 us |    37.0 us |    17.2 us |    31.9 us |       1.78 |       2.15 |       0.54 |     1.4 us |     2.5 us |     1.3 us |     1.9 us |
| leq R <= T                               |   112.1 us |   118.0 us |    98.0 us |   108.0 us |       0.95 |       1.20 |       0.91 |     0.6 us |     2.6 us |     1.6 us |     1.6 us |
| equal T = T \| R                         |   660.9 us |   192.9 us |   176.9 us |   181.0 us |       3.43 |       1.09 |       0.98 |    66.2 us |     7.2 us |     3.8 us |     3.8 us |
| **traces-regex-lower: delays, n = 32**   |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   318.1 us |   237.0 us |   235.1 us |   242.9 us |       1.34 |       1.01 |       0.97 |     0.6 us |     5.4 us |     2.6 us |     2.7 us |
| leq S <= T (false)                       |   289.0 us |    42.9 us |    21.0 us |    23.1 us |       6.73 |       2.05 |       0.91 |     0.6 us |     5.5 us |     2.7 us |     2.7 us |
| counterexample S, T                      |   290.9 us |    47.0 us |    21.9 us |    24.8 us |       6.19 |       2.14 |       0.88 |     1.5 us |     5.5 us |     2.7 us |     2.7 us |
| leq R <= T                               |   718.8 us |    1.00 ms |   971.1 us |   989.9 us |       0.72 |       1.03 |       0.98 |     0.6 us |     7.4 us |     4.6 us |     4.6 us |
| equal T = T \| R                         |    2.87 ms |    1.91 ms |    1.93 ms |    1.91 ms |       1.50 |       0.99 |       1.01 |   725.5 us |    21.6 us |    13.3 us |    13.1 us |
| **traces-regex-lower: delays, n = 128**  |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    4.28 ms |    3.25 ms |    3.44 ms |    3.53 ms |       1.32 |       0.94 |       0.97 |     0.6 us |    20.4 us |    10.7 us |    10.6 us |
| leq S <= T (false)                       |    4.33 ms |    77.0 us |    30.0 us |    33.1 us |      56.23 |       2.56 |       0.91 |     0.6 us |    21.4 us |    10.7 us |    10.7 us |
| counterexample S, T                      |    4.33 ms |    72.0 us |    29.1 us |    30.0 us |      60.09 |       2.48 |       0.97 |     1.5 us |    21.5 us |    10.7 us |    10.6 us |
| leq R <= T                               |   11.03 ms |    8.70 ms |    8.94 ms |    9.01 ms |       1.27 |       0.97 |       0.99 |     0.6 us |    33.3 us |    22.3 us |    22.3 us |
| equal T = T \| R                         |   47.37 ms |   18.33 ms |   19.37 ms |   19.40 ms |       2.58 |       0.95 |       1.00 |   11.99 ms |   104.4 us |    75.4 us |    75.3 us |
| **traces-regex-lower: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    33.1 us |    61.0 us |    34.1 us |    39.1 us |       0.54 |       1.79 |       0.87 |     1.2 us |     2.4 us |     1.9 us |     1.9 us |
| leq W <= X (false)                       |    31.9 us |    42.0 us |    24.1 us |    26.0 us |       0.76 |       1.74 |       0.93 |     1.2 us |     2.4 us |     1.9 us |     1.9 us |
| counterexample W, X                      |    36.0 us |    43.9 us |    25.0 us |    28.8 us |       0.82 |       1.75 |       0.87 |     2.0 us |     2.5 us |     1.9 us |     1.9 us |
| leq Y <= {8}                             |    83.2 us |    83.0 us |    72.0 us |    75.1 us |       1.00 |       1.15 |       0.96 |     0.5 us |     1.1 us |     1.1 us |     1.0 us |
| inhabited X                              |    16.0 us |    44.1 us |    18.1 us |    25.0 us |       0.36 |       2.43 |       0.72 |     5.8 us |     4.2 us |     3.6 us |     3.6 us |
| **traces-regex-lower: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    62.0 us |   134.9 us |    73.2 us |    83.0 us |       0.46 |       1.84 |       0.88 |     5.5 us |    10.7 us |     7.8 us |     7.9 us |
| leq W <= X (false)                       |    43.9 us |    89.2 us |    35.0 us |    34.8 us |       0.49 |       2.54 |       1.01 |     5.5 us |    10.8 us |     7.9 us |     8.0 us |
| counterexample W, X                      |    47.0 us |    93.0 us |    36.0 us |    33.9 us |       0.51 |       2.58 |       1.06 |     6.4 us |    10.8 us |     7.9 us |     7.9 us |
| leq Y <= {8}                             |   172.1 us |   273.0 us |   725.0 us |   704.1 us |       0.63 |       0.38 |       1.03 |     2.1 us |     2.7 us |     2.6 us |     2.6 us |
| inhabited X                              |    27.2 us |    83.9 us |    40.1 us |    49.8 us |       0.32 |       2.10 |       0.80 |    21.1 us |    22.2 us |    14.2 us |    14.1 us |
| **traces-regex-lower: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   298.0 us |   912.9 us |   218.9 us |   309.9 us |       0.33 |       4.17 |       0.71 |    23.8 us |    48.4 us |    36.3 us |    36.4 us |
| leq W <= X (false)                       |   176.0 us |   757.9 us |    78.9 us |    81.1 us |       0.23 |       9.60 |       0.97 |    23.8 us |    48.4 us |    36.5 us |    36.6 us |
| counterexample W, X                      |   178.1 us |   401.0 us |    78.0 us |    76.1 us |       0.44 |       5.14 |       1.03 |    24.6 us |    48.3 us |    36.2 us |    36.3 us |
| leq Y <= {8}                             |   750.1 us |    1.33 ms |    3.35 ms |    2.48 ms |       0.56 |       0.40 |       1.35 |     9.4 us |     9.8 us |     9.9 us |    10.0 us |
| inhabited X                              |   154.0 us |   309.0 us |   128.0 us |   224.1 us |       0.50 |       2.41 |       0.57 |   150.4 us |   180.8 us |    61.7 us |    61.8 us |
| **traces-regex-lower: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    1.97 ms |   119.9 us |   103.0 us |   102.0 us |      16.46 |       1.16 |       1.01 |    1.05 ms |    11.3 us |     5.0 us |     5.0 us |
| leq (B \| C)* <= E                       |    95.8 us |    72.0 us |    46.0 us |    46.0 us |       1.33 |       1.56 |       1.00 |     0.4 us |     3.4 us |     0.9 us |     0.9 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |   229.8 us |    61.0 us |    38.9 us |    42.2 us |       3.77 |       1.57 |       0.92 |     0.4 us |     2.9 us |     1.1 us |     1.1 us |
| leq C* <= E2                             |    66.0 us |    68.9 us |    44.8 us |    44.8 us |       0.96 |       1.54 |       1.00 |     0.4 us |     3.8 us |     1.1 us |     1.1 us |
| **traces-regex-lower: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   97.36 ms |   137.1 us |   122.1 us |   123.0 us |     710.18 |       1.12 |       0.99 |   91.10 ms |    20.0 us |     8.9 us |     8.9 us |
| leq (B \| C)* <= E                       |    2.08 ms |    70.8 us |    52.0 us |    45.1 us |      29.40 |       1.36 |       1.15 |     0.4 us |     3.8 us |     1.0 us |     1.0 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |    1.94 ms |   486.1 us |    57.9 us |    58.9 us |       3.98 |       8.39 |       0.98 |     0.4 us |     3.5 us |     1.5 us |     1.5 us |
| leq C* <= E2                             |    1.90 ms |    74.9 us |    47.2 us |    50.1 us |      25.39 |       1.59 |       0.94 |     0.4 us |     4.1 us |     1.2 us |     1.2 us |
| **traces-regex-interval: cost corpus (20 literals)** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate                                |    1.27 ms |   585.1 us |   627.0 us |   570.1 us |       2.17 |       0.93 |       1.10 |   423.4 us |    23.6 us |    22.3 us |    22.4 us |
| leq, all pairs                           |   12.32 ms |    9.90 ms |    9.31 ms |    9.14 ms |       1.25 |       1.06 |       1.02 |   521.7 us |    1.65 ms |   743.7 us |   737.2 us |
| equal, all pairs                         |   12.59 ms |   10.08 ms |    9.23 ms |    9.22 ms |       1.25 |       1.09 |       1.00 |   633.0 us |    1.94 ms |   874.2 us |   870.4 us |
| counterexample, all pairs                |   19.18 ms |    9.94 ms |    9.36 ms |    9.29 ms |       1.93 |       1.06 |       1.01 |    7.19 ms |    1.77 ms |   852.7 us |   854.2 us |
| **traces-regex-interval: delays, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   128.0 us |   109.0 us |   112.1 us |   109.0 us |       1.18 |       0.97 |       1.03 |     1.2 us |     4.8 us |     2.6 us |     2.6 us |
| leq S <= T (false)                       |    62.0 us |    36.0 us |    18.8 us |    23.8 us |       1.72 |       1.91 |       0.79 |     0.6 us |     2.4 us |     1.3 us |     1.3 us |
| counterexample S, T                      |    67.0 us |    34.8 us |    18.1 us |    16.0 us |       1.92 |       1.92 |       1.13 |     1.4 us |     2.5 us |     1.3 us |     1.3 us |
| leq R <= T                               |   245.1 us |   216.0 us |   235.1 us |   231.0 us |       1.13 |       0.92 |       1.02 |     1.2 us |     5.3 us |     3.2 us |     3.2 us |
| equal T = T \| R                         |   875.0 us |   490.0 us |   592.9 us |   586.0 us |       1.79 |       0.83 |       1.01 |   132.4 us |    14.4 us |     7.7 us |     7.7 us |
| **traces-regex-interval: delays, n = 32** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |   708.8 us |   325.0 us |   368.8 us |   360.0 us |       2.18 |       0.88 |       1.02 |     1.2 us |    10.8 us |     5.3 us |     5.3 us |
| leq S <= T (false)                       |   414.1 us |    52.0 us |    26.0 us |    23.8 us |       7.97 |       2.00 |       1.09 |     0.6 us |     5.5 us |     2.7 us |     2.7 us |
| counterexample S, T                      |   401.0 us |    46.0 us |    20.0 us |    24.8 us |       8.72 |       2.30 |       0.81 |     1.4 us |     5.5 us |     2.7 us |     2.7 us |
| leq R <= T                               |    1.75 ms |    1.51 ms |    1.93 ms |    1.91 ms |       1.16 |       0.78 |       1.01 |     1.2 us |    14.6 us |     9.1 us |     9.0 us |
| equal T = T \| R                         |    6.70 ms |    3.82 ms |    4.64 ms |    4.65 ms |       1.76 |       0.82 |       1.00 |    1.46 ms |    43.5 us |    26.8 us |    26.7 us |
| **traces-regex-interval: delays, n = 128** |            |            |            |            |            |            |            |            |            |            |            |
| leq T <= S                               |    8.60 ms |    3.39 ms |    3.67 ms |    3.57 ms |       2.54 |       0.92 |       1.03 |     1.2 us |    41.4 us |    21.4 us |    21.4 us |
| leq S <= T (false)                       |    4.46 ms |    83.9 us |    32.9 us |    37.0 us |      53.20 |       2.55 |       0.89 |     0.6 us |    21.6 us |    10.8 us |    10.8 us |
| counterexample S, T                      |    4.44 ms |    74.9 us |    31.0 us |    34.1 us |      59.29 |       2.42 |       0.91 |     1.4 us |    21.4 us |    10.8 us |    10.8 us |
| leq R <= T                               |   24.47 ms |   18.10 ms |   21.56 ms |   21.20 ms |       1.35 |       0.84 |       1.02 |     1.2 us |    66.6 us |    44.8 us |    44.9 us |
| equal T = T \| R                         |   98.21 ms |   46.35 ms |   59.80 ms |   59.46 ms |       2.12 |       0.78 |       1.01 |   23.59 ms |   207.1 us |   150.0 us |   149.7 us |
| **traces-regex-interval: 8 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    71.0 us |   104.9 us |   104.0 us |    91.1 us |       0.68 |       1.01 |       1.14 |     2.5 us |     4.9 us |     3.8 us |     3.7 us |
| leq W <= X (false)                       |    37.0 us |    48.2 us |    22.9 us |    21.9 us |       0.77 |       2.10 |       1.04 |     1.2 us |     2.4 us |     1.9 us |     1.9 us |
| counterexample W, X                      |    35.0 us |    44.8 us |    17.2 us |    24.1 us |       0.78 |       2.61 |       0.71 |     2.1 us |     2.5 us |     1.9 us |     1.9 us |
| leq Y <= {8}                             |    81.1 us |    74.1 us |    62.0 us |    66.0 us |       1.09 |       1.20 |       0.94 |     0.5 us |     1.1 us |     1.0 us |     1.0 us |
| inhabited X                              |    26.9 us |    46.0 us |    20.0 us |    23.8 us |       0.59 |       2.30 |       0.84 |    11.6 us |     8.4 us |     7.2 us |     7.1 us |
| **traces-regex-interval: 32 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |   195.0 us |   402.9 us |   465.9 us |   274.9 us |       0.48 |       0.86 |       1.69 |    11.0 us |    21.3 us |    15.6 us |    15.7 us |
| leq W <= X (false)                       |    48.9 us |    93.9 us |    33.9 us |    41.0 us |       0.52 |       2.77 |       0.83 |     5.5 us |    10.7 us |     7.8 us |     7.8 us |
| counterexample W, X                      |    51.0 us |    92.0 us |    32.2 us |    35.0 us |       0.55 |       2.86 |       0.92 |     6.3 us |    10.7 us |     7.9 us |     7.8 us |
| leq Y <= {8}                             |   181.0 us |   285.9 us |   301.8 us |   311.9 us |       0.63 |       0.95 |       0.97 |     2.1 us |     2.7 us |     2.6 us |     2.6 us |
| inhabited X                              |    78.0 us |   113.0 us |    64.8 us |    77.0 us |       0.69 |       1.74 |       0.84 |    42.2 us |    44.7 us |    28.3 us |    28.2 us |
| **traces-regex-interval: 128 declared names** |            |            |            |            |            |            |            |            |            |            |            |
| leq X <= W                               |    1.60 ms |    3.09 ms |    5.71 ms |    3.57 ms |       0.52 |       0.54 |       1.60 |    47.9 us |    96.7 us |    71.0 us |    71.6 us |
| leq W <= X (false)                       |   179.1 us |   395.1 us |    88.9 us |   105.1 us |       0.45 |       4.44 |       0.85 |    23.9 us |    48.5 us |    37.4 us |    37.0 us |
| counterexample W, X                      |   179.1 us |   408.9 us |    84.2 us |    91.1 us |       0.44 |       4.86 |       0.92 |    24.6 us |    48.4 us |    36.5 us |    36.5 us |
| leq Y <= {8}                             |   757.0 us |    1.32 ms |    3.67 ms |    3.50 ms |       0.57 |       0.36 |       1.05 |     9.3 us |     9.8 us |     9.9 us |     9.9 us |
| inhabited X                              |   304.0 us |   486.9 us |   232.9 us |   305.2 us |       0.62 |       2.09 |       0.76 |   302.5 us |   350.4 us |   123.1 us |   124.0 us |
| **traces-regex-interval: n-th letter from the end, n = 4** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |    1.88 ms |   119.0 us |   114.0 us |   102.0 us |      15.80 |       1.04 |       1.12 |    1.06 ms |    11.3 us |     5.0 us |     5.0 us |
| leq (B \| C)* <= E                       |   236.0 us |   308.0 us |   392.0 us |   344.0 us |       0.77 |       0.79 |       1.14 |     0.7 us |     6.9 us |     1.7 us |     1.8 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |   518.8 us |   335.0 us |   406.0 us |   345.9 us |       1.55 |       0.83 |       1.17 |     0.8 us |     5.8 us |     2.3 us |     2.3 us |
| leq C* <= E2                             |   139.0 us |    2.12 ms |    2.41 ms |    1.42 ms |       0.07 |       0.88 |       1.70 |     0.8 us |     7.5 us |     2.1 us |     2.2 us |
| **traces-regex-interval: n-th letter from the end, n = 8** |            |            |            |            |            |            |            |            |            |            |            |
| elaborate E, E2                          |   96.53 ms |   141.9 us |   125.9 us |   111.1 us |     680.47 |       1.13 |       1.13 |   91.75 ms |    19.9 us |     8.9 us |     8.9 us |
| leq (B \| C)* <= E                       |    5.07 ms |    7.00 ms |    9.42 ms |    8.37 ms |       0.72 |       0.74 |       1.12 |     0.8 us |     7.7 us |     2.0 us |     2.0 us |
| counterexample (B \| C)*; A; (B \| C)^n, E |    5.74 ms |    8.88 ms |   10.20 ms |    9.17 ms |       0.65 |       0.87 |       1.11 |     0.8 us |     7.0 us |     3.0 us |     3.0 us |
| leq C* <= E2                             |    4.37 ms |  132.80 ms |  138.93 ms |  117.92 ms |       0.03 |       0.96 |       1.18 |     0.8 us |     8.8 us |     2.4 us |     2.4 us |
