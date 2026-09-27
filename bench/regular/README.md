# Regular trace grades benchmark

Compares the two implementations of the regular trace grade — automata
(`traces-regex`) and symbolic derivatives (`traces-regex-symbolic`) — and of
the three cost-model regular trace grades built over them (`traces-regex-upper`,
`traces-regex-lower`, `traces-regex-interval`, each also with a `-symbolic`
suffix): typechecking of the examples and tests that use each grade, and the
grade operations (elaboration, `mul`, `join`, `leq`, `equal`, `counterexample`,
`inhabited`) on families of grades of increasing size. Run from the root of
the repository:

    dune exec --profile release bench/regular/bench_regular.exe

Each measurement runs in a fresh child process, so that the tables the
derivatives keep start empty: it prepares its inputs untimed, then times the
operation once (cold) and then repeatedly (warm, the mean of the repeated
runs). The table shows the medians over 5 processes (fewer past 10 s of total
measurement); a cell reads `> 20 s` when a single run was killed at that
alarm. The ratio is automata over derivatives, cold.

## Measured

- 2026-09-27
- macOS 15.7.7 (Darwin 24.6.0, arm64)
- OCaml 5.5.0, dune 3.24.2
- `--profile release`
- Total run time: 7 min 55 s (the plain regular-trace grade's "n-th letter
  from the end, n = 16" family alone accounts for most of it: several of its
  rows hit the 20 s alarm under `traces-regex`)

## Results

Median over 5 processes (fewer past 10 s); cold: first run in a fresh
process, warm: mean of repeated runs; ratio: automata / derivatives, cold.

| workload                                 |   automata | derivative |  aut. warm |  der. warm |    ratio |
|-------------------------------------------|------------|------------|------------|------------|----------|
| **typechecking, traces-regex** | | | | | |
| standard library alone                   |   42.85 ms |   38.02 ms |   38.25 ms |   33.49 ms |     1.13 |
| examples/regular/regular_traces.tpe      |   52.53 ms |   41.12 ms |   48.54 ms |   36.63 ms |     1.28 |
| tests/literals_regular.tpe               |   43.28 ms |   38.09 ms |   38.84 ms |   33.55 ms |     1.14 |
| tests/regular_auth.tpe                   |   46.34 ms |   39.21 ms |   41.77 ms |   34.73 ms |     1.18 |
| tests/regular_protocol.tpe               |   50.49 ms |   40.91 ms |   46.61 ms |   36.40 ms |     1.23 |
| tests/regular_reject_auth.tpe            |   44.79 ms |   38.86 ms |   40.05 ms |   34.43 ms |     1.15 |
| tests/regular_reject_bounds.tpe          |   43.07 ms |   38.54 ms |   38.63 ms |   33.84 ms |     1.12 |
| tests/regular_reject_counterexample.tpe  |   45.59 ms |   40.38 ms |   41.43 ms |   36.42 ms |     1.13 |
| tests/regular_reject_protocol.tpe        |   45.26 ms |   38.76 ms |   41.39 ms |   34.20 ms |     1.17 |
| **corpus (29 literals)** | | | | | |
| elaborate                                |    3.26 ms |   260.1 us |   495.7 us |    32.5 us |    12.55 |
| mul, all pairs                           |   12.87 ms |   106.1 us |   11.60 ms |    50.9 us |   121.27 |
| join, all pairs                          |   10.45 ms |    3.13 ms |    9.10 ms |   196.0 us |     3.34 |
| leq, all pairs                           |    5.24 ms |    7.50 ms |    3.92 ms |   182.7 us |     0.70 |
| equal, all pairs                         |    37.2 us |    3.36 ms |    20.7 us |    26.7 us |     0.01 |
| counterexample, all pairs                |    8.90 ms |    6.50 ms |    7.65 ms |    1.49 ms |     1.37 |
| **protocol P^k, k = 2** | | | | | |
| mul P^k                                  |    19.1 us |     1.9 us |    10.6 us |     0.1 us |    10.00 |
| join J = P \| ... \| P^k                 |    34.8 us |     2.9 us |    19.0 us |     0.2 us |    12.17 |
| leq P^k <= P*                            |     4.1 us |    15.0 us |     1.4 us |     0.1 us |     0.27 |
| leq P; P* <= J (false)                   |     5.0 us |    22.9 us |     1.7 us |     0.1 us |     0.22 |
| counterexample P; P*, J                  |    37.0 us |    22.9 us |    26.4 us |     4.5 us |     1.61 |
| equal J \| P; P* = P; P*                 |    11.0 us |    16.9 us |     8.5 us |     0.2 us |     0.65 |
| **protocol P^k, k = 8** | | | | | |
| mul P^k                                  |    2.47 ms |     4.1 us |   264.3 us |     2.2 us |   610.41 |
| join J = P \| ... \| P^k                 |    4.59 ms |    19.1 us |   984.0 us |     9.0 us |   240.65 |
| leq P^k <= P*                            |     7.9 us |    41.0 us |     4.9 us |     0.1 us |     0.19 |
| leq P; P* <= J (false)                   |     9.1 us |    78.2 us |     5.4 us |     0.1 us |     0.12 |
| counterexample P; P*, J                  |   168.1 us |    88.0 us |   159.0 us |    13.4 us |     1.91 |
| equal J \| P; P* = P; P*                 |    23.8 us |    64.8 us |    20.8 us |     0.6 us |     0.37 |
| **protocol P^k, k = 32** | | | | | |
| mul P^k                                  |   15.22 ms |    67.0 us |   11.27 ms |    45.8 us |   227.19 |
| join J = P \| ... \| P^k                 |  114.02 ms |    3.08 ms |  110.63 ms |   539.4 us |    36.99 |
| leq P^k <= P*                            |    24.8 us |   134.9 us |    20.6 us |     0.1 us |     0.18 |
| leq P; P* <= J (false)                   |    26.9 us |   652.1 us |    23.1 us |     0.2 us |     0.04 |
| counterexample P; P*, J                  |    2.11 ms |   726.9 us |    2.04 ms |    98.6 us |     2.90 |
| equal J \| P; P* = P; P*                 |    85.1 us |   574.8 us |    82.9 us |     4.3 us |     0.15 |
| **nested protocol N_d, d = 1** | | | | | |
| elaborate N_d                            |    2.39 ms |   104.0 us |    74.6 us |     3.2 us |    22.99 |
| leq N_d <= N_d+1                         |     3.1 us |    16.2 us |     1.2 us |     0.1 us |     0.19 |
| counterexample N_d+1, N_d                |    38.9 us |    18.1 us |    27.8 us |     4.5 us |     2.14 |
| equal N_d = N_d \| P                     |     1.9 us |    10.0 us |     0.2 us |     0.0 us |     0.19 |
| **nested protocol N_d, d = 3** | | | | | |
| elaborate N_d                            |    2.58 ms |   134.0 us |   193.2 us |     6.2 us |    19.28 |
| leq N_d <= N_d+1                         |     5.0 us |    30.0 us |     1.8 us |     0.1 us |     0.17 |
| counterexample N_d+1, N_d                |   132.1 us |    35.0 us |    59.6 us |     6.9 us |     3.77 |
| equal N_d = N_d \| P                     |     1.0 us |    11.9 us |     0.2 us |     0.0 us |     0.08 |
| **nested protocol N_d, d = 6** | | | | | |
| elaborate N_d                            |    3.32 ms |   146.9 us |   486.2 us |    10.9 us |    22.58 |
| leq N_d <= N_d+1                         |     6.0 us |    2.27 ms |     2.6 us |     0.1 us |     0.00 |
| counterexample N_d+1, N_d                |   141.9 us |    2.42 ms |   130.4 us |    11.6 us |     0.06 |
| equal N_d = N_d \| P                     |     1.0 us |    14.1 us |     0.3 us |     0.0 us |     0.07 |
| **n-th letter from the end, n = 4** | | | | | |
| elaborate E                              |    2.87 ms |   109.0 us |   192.9 us |     1.8 us |    26.37 |
| elaborate E2                             |    3.82 ms |   114.0 us |   844.5 us |     3.3 us |    33.53 |
| leq (B \| C)* <= E                       |    87.0 us |    21.0 us |    53.5 us |     0.1 us |     4.15 |
| counterexample (B \| C)*; A; (B \| C)^n, E |   247.0 us |    21.9 us |    73.3 us |     3.6 us |    11.26 |
| leq C* <= E2                             |    58.9 us |    22.9 us |    53.1 us |     0.2 us |     2.57 |
| elaborate E', decide E = E'              |   643.0 us |    2.54 ms |   326.5 us |     4.4 us |     0.25 |
| **n-th letter from the end, n = 8** | | | | | |
| elaborate E                              |    9.83 ms |   109.2 us |    5.92 ms |     3.1 us |    90.03 |
| elaborate E2                             |   89.40 ms |   122.1 us |   85.74 ms |     6.0 us |   732.36 |
| leq (B \| C)* <= E                       |    1.72 ms |    20.0 us |    1.80 ms |     0.1 us |    85.99 |
| counterexample (B \| C)*; A; (B \| C)^n, E |    1.78 ms |    2.45 ms |    1.82 ms |     5.7 us |     0.73 |
| leq C* <= E2                             |    1.75 ms |    2.39 ms |    1.76 ms |     0.1 us |     0.73 |
| elaborate E', decide E = E'              |    9.12 ms |    6.81 ms |    8.97 ms |     8.6 us |     1.34 |
| **n-th letter from the end, n = 12** | | | | | |
| elaborate E                              |  169.04 ms |   109.2 us |  164.68 ms |     4.8 us |  1548.06 |
| elaborate E2                             |    10.12 s |    2.80 ms |          - |     9.1 us |  3616.71 |
| leq (B \| C)* <= E                       |   48.88 ms |    11.0 us |   49.45 ms |     0.1 us |  4456.80 |
| counterexample (B \| C)*; A; (B \| C)^n, E |   48.51 ms |    46.0 us |   49.10 ms |     8.5 us |  1054.18 |
| leq C* <= E2                             |   50.27 ms |    33.1 us |   50.28 ms |     0.2 us |  1516.89 |
| elaborate E', decide E = E'              |  250.70 ms |   80.65 ms |  254.19 ms |    16.0 us |     3.11 |
| **n-th letter from the end, n = 16** | | | | | |
| elaborate E                              |     4.03 s |   121.8 us |          - |     6.9 us | 33103.26 |
| elaborate E2                             |     > 20 s |   186.0 us |            |    13.7 us | > 107546 |
| leq (B \| C)* <= E                       |     1.21 s |    26.0 us |          - |     0.1 us | 46429.64 |
| counterexample (B \| C)*; A; (B \| C)^n, E |     1.20 s |    70.1 us |          - |    11.7 us | 17094.79 |
| leq C* <= E2                             |     > 20 s |    31.0 us |            |     0.2 us | > 645278 |
| elaborate E', decide E = E'              |     6.28 s |     2.83 s |          - |          - |     2.22 |
| **alphabet of k = 8 names** | | | | | |
| elaborate W, X                           |   446.8 us |   140.2 us |   160.9 us |     8.3 us |     3.19 |
| mul X W                                  |    21.9 us |     0.0 us |    11.0 us |     0.1 us |      inf |
| join X W                                 |    12.9 us |     0.0 us |     6.4 us |     0.1 us |      inf |
| leq X <= W                               |     5.0 us |    12.9 us |     2.0 us |     0.2 us |     0.39 |
| leq W <= X (false)                       |     6.0 us |     6.9 us |     0.7 us |     0.2 us |     0.86 |
| counterexample W, X                      |    11.0 us |     1.9 us |     3.9 us |     0.1 us |     5.75 |
| equal W = W \| X                         |     1.9 us |    16.0 us |     0.1 us |     0.0 us |     0.12 |
| **alphabet of k = 32 names** | | | | | |
| elaborate W, X                           |    5.70 ms |   218.2 us |    1.43 ms |    56.2 us |    26.15 |
| mul X W                                  |    35.0 us |     0.0 us |    33.1 us |     0.1 us |      inf |
| join X W                                 |    23.8 us |     0.0 us |    21.8 us |     0.1 us |      inf |
| leq X <= W                               |    16.0 us |    11.0 us |    10.7 us |     0.1 us |     1.46 |
| leq W <= X (false)                       |     7.2 us |     5.0 us |     3.2 us |     0.2 us |     1.43 |
| counterexample W, X                      |    16.0 us |     3.1 us |    12.5 us |     0.1 us |     5.15 |
| equal W = W \| X                         |     2.1 us |    17.2 us |     0.4 us |     0.0 us |     0.12 |
| **alphabet of k = 128 names** | | | | | |
| elaborate W, X                           |   23.69 ms |   949.1 us |   19.18 ms |   622.5 us |    24.96 |
| mul X W                                  |   179.8 us |     0.0 us |   167.4 us |     0.1 us |      inf |
| join X W                                 |   127.1 us |     0.0 us |   127.3 us |     0.1 us |      inf |
| leq X <= W                               |    97.0 us |    23.1 us |   120.4 us |     0.2 us |     4.20 |
| leq W <= X (false)                       |    21.9 us |    16.9 us |    15.3 us |     0.1 us |     1.30 |
| counterexample W, X                      |    92.0 us |     1.9 us |    89.0 us |     0.1 us |    48.25 |
| equal W = W \| X                         |     4.1 us |    27.9 us |     1.4 us |     0.0 us |     0.15 |
| **typechecking, traces-regex-upper** | | | | | |
| standard library alone                   |   41.00 ms |   45.47 ms |   36.33 ms |   40.88 ms |     0.90 |
| examples/regular_costs/regular_costs_upper.tpe |   56.30 ms |   60.40 ms |   54.20 ms |   63.32 ms |     0.93 |
| tests/regex_costs_upper.tpe              |   51.12 ms |   58.14 ms |   47.73 ms |   55.73 ms |     0.88 |
| tests/regex_costs_upper_reject.tpe       |   50.41 ms |   56.36 ms |   46.23 ms |   56.38 ms |     0.89 |
| tests/regex_costs_upper_runs.tpe         |   45.46 ms |   49.61 ms |   48.97 ms |   48.08 ms |     0.92 |
| tests/regex_costs_upper_runs_reject.tpe  |   42.64 ms |   47.41 ms |   38.29 ms |   43.26 ms |     0.90 |
| **typechecking, traces-regex-lower** | | | | | |
| standard library alone                   |   27.18 ms |   25.50 ms |   22.95 ms |   21.17 ms |     1.07 |
| examples/regular_costs/regular_costs_lower.tpe |   31.43 ms |   29.09 ms |   27.20 ms |   24.43 ms |     1.08 |
| tests/regex_costs_lower.tpe              |   30.37 ms |   28.22 ms |   26.02 ms |   23.43 ms |     1.08 |
| tests/regex_costs_lower_reject.tpe       |   31.30 ms |   27.50 ms |   26.52 ms |   23.01 ms |     1.14 |
| tests/regex_costs_lower_runs_reject.tpe  |   27.52 ms |   25.78 ms |   22.83 ms |   21.54 ms |     1.07 |
| **typechecking, traces-regex-interval** | | | | | |
| standard library alone                   |   50.89 ms |   48.75 ms |   46.11 ms |   44.82 ms |     1.04 |
| examples/regular_costs/regular_costs_intervals.tpe |   67.87 ms |   65.55 ms |   63.88 ms |   61.42 ms |     1.04 |
| tests/regex_costs_interval.tpe           |   57.03 ms |   54.83 ms |   52.59 ms |   53.07 ms |     1.04 |
| tests/regex_costs_interval_reject.tpe    |   55.88 ms |   53.38 ms |   52.00 ms |   54.42 ms |     1.05 |
| tests/regex_costs_interval_runs_reject.tpe |   52.34 ms |   49.93 ms |   47.90 ms |   46.65 ms |     1.05 |
| **traces-regex-upper: cost corpus (15 literals)** | | | | | |
| elaborate                                |    2.37 ms |   207.2 us |   225.5 us |    14.6 us |    11.42 |
| leq, all pairs                           |   11.07 ms |   15.51 ms |   206.4 us |   308.4 us |     0.71 |
| equal, all pairs                         |   11.17 ms |   15.73 ms |   293.1 us |   432.2 us |     0.71 |
| counterexample, all pairs                |   14.61 ms |   15.30 ms |    3.69 ms |   359.8 us |     0.95 |
| **traces-regex-upper: delays, n = 8** | | | | | |
| leq T <= S                               |    63.9 us |   106.1 us |     0.6 us |     1.3 us |     0.60 |
| leq S <= T (false)                       |   120.9 us |   202.9 us |     0.6 us |     1.3 us |     0.60 |
| counterexample S, T                      |   229.1 us |   217.2 us |    55.0 us |     2.1 us |     1.05 |
| leq R <= T                               |   133.0 us |   229.8 us |     0.6 us |     1.6 us |     0.58 |
| equal T = T \| R                         |   774.1 us |    2.41 ms |    66.4 us |     3.9 us |     0.32 |
| **traces-regex-upper: delays, n = 32** | | | | | |
| leq T <= S                               |   276.1 us |    2.06 ms |     0.6 us |     2.6 us |     0.13 |
| leq S <= T (false)                       |    1.17 ms |    5.28 ms |     0.6 us |     2.6 us |     0.22 |
| counterexample S, T                      |    1.79 ms |    5.75 ms |   586.4 us |     7.5 us |     0.31 |
| leq R <= T                               |   850.0 us |    4.62 ms |     0.6 us |     4.6 us |     0.18 |
| equal T = T \| R                         |    3.17 ms |    7.35 ms |   709.1 us |    13.2 us |     0.43 |
| **traces-regex-upper: delays, n = 128** | | | | | |
| leq T <= S                               |    4.17 ms |    6.27 ms |     0.6 us |    10.6 us |     0.67 |
| leq S <= T (false)                       |   27.82 ms |   36.34 ms |     0.6 us |    10.6 us |     0.77 |
| counterexample S, T                      |   50.15 ms |   36.18 ms |   21.45 ms |    86.7 us |     1.39 |
| leq R <= T                               |   12.08 ms |   19.02 ms |     0.6 us |    22.3 us |     0.63 |
| equal T = T \| R                         |   50.87 ms |   49.23 ms |   11.79 ms |    75.4 us |     1.03 |
| **traces-regex-upper: 8 declared names** | | | | | |
| leq X <= W                               |    42.0 us |    86.1 us |     1.2 us |     1.9 us |     0.49 |
| leq W <= X (false)                       |    69.1 us |   142.1 us |     1.2 us |     1.9 us |     0.49 |
| counterexample W, X                      |   107.0 us |   131.1 us |    19.7 us |     2.4 us |     0.82 |
| leq Y <= {8}                             |   587.0 us |    2.19 ms |     0.5 us |     1.0 us |     0.27 |
| inhabited X                              |    15.0 us |    27.9 us |     5.9 us |     3.7 us |     0.54 |
| **traces-regex-upper: 32 declared names** | | | | | |
| leq X <= W                               |   121.8 us |    1.98 ms |     5.4 us |     7.8 us |     0.06 |
| leq W <= X (false)                       |   273.9 us |    2.45 ms |     5.4 us |     7.7 us |     0.11 |
| counterexample W, X                      |   293.0 us |    2.42 ms |    23.7 us |     8.3 us |     0.12 |
| leq Y <= {8}                             |    1.81 ms |    6.18 ms |     2.1 us |     2.6 us |     0.29 |
| inhabited X                              |    26.9 us |    61.0 us |    20.3 us |    14.5 us |     0.44 |
| **traces-regex-upper: 128 declared names** | | | | | |
| leq X <= W                               |    1.22 ms |    4.03 ms |    24.0 us |    35.7 us |     0.30 |
| leq W <= X (false)                       |    3.21 ms |    5.84 ms |    24.1 us |    35.6 us |     0.55 |
| counterexample W, X                      |    3.22 ms |    5.78 ms |    42.2 us |    36.0 us |     0.56 |
| leq Y <= {8}                             |   28.89 ms |   31.12 ms |     9.4 us |     9.9 us |     0.93 |
| inhabited X                              |   134.0 us |   236.0 us |   134.1 us |    62.0 us |     0.57 |
| **traces-regex-upper: n-th letter from the end, n = 4** | | | | | |
| elaborate E, E2                          |    5.44 ms |   134.9 us |    1.03 ms |     5.1 us |    40.34 |
| leq (B \| C)* <= E                       |   161.2 us |    2.19 ms |     0.4 us |     0.9 us |     0.07 |
| counterexample (B \| C)*; A; (B \| C)^n, E |   618.9 us |    2.20 ms |     0.4 us |     1.2 us |     0.28 |
| leq C* <= E2                             |    81.1 us |    3.55 ms |     0.4 us |     1.1 us |     0.02 |
| **traces-regex-upper: n-th letter from the end, n = 8** | | | | | |
| elaborate E, E2                          |   95.13 ms |   127.1 us |   90.44 ms |     9.1 us |   748.64 |
| leq (B \| C)* <= E                       |    2.78 ms |    9.58 ms |     0.4 us |     1.0 us |     0.29 |
| counterexample (B \| C)*; A; (B \| C)^n, E |    3.20 ms |   10.58 ms |     0.4 us |     1.5 us |     0.30 |
| leq C* <= E2                             |    2.32 ms |  123.73 ms |     0.4 us |     1.2 us |     0.02 |
| **traces-regex-lower: cost corpus (15 literals)** | | | | | |
| elaborate                                |    2.46 ms |    2.17 ms |   225.8 us |    14.3 us |     1.13 |
| leq, all pairs                           |    6.23 ms |    4.18 ms |   206.6 us |   291.9 us |     1.49 |
| equal, all pairs                         |    6.28 ms |    4.41 ms |   305.7 us |   425.8 us |     1.42 |
| counterexample, all pairs                |    7.50 ms |    4.11 ms |    1.62 ms |   314.7 us |     1.83 |
| **traces-regex-lower: delays, n = 8** | | | | | |
| leq T <= S                               |    67.0 us |    48.2 us |     0.6 us |     1.3 us |     1.39 |
| leq S <= T (false)                       |    60.1 us |    21.9 us |     0.6 us |     1.3 us |     2.74 |
| counterexample S, T                      |    66.0 us |    26.9 us |     1.4 us |     1.3 us |     2.45 |
| leq R <= T                               |   116.1 us |   118.0 us |     0.6 us |     1.6 us |     0.98 |
| equal T = T \| R                         |   834.9 us |   191.9 us |    66.8 us |     3.9 us |     4.35 |
| **traces-regex-lower: delays, n = 32** | | | | | |
| leq T <= S                               |   297.1 us |   256.1 us |     0.6 us |     2.7 us |     1.16 |
| leq S <= T (false)                       |   283.0 us |    25.0 us |     0.6 us |     2.7 us |    11.30 |
| counterexample S, T                      |   287.1 us |    22.9 us |     1.4 us |     2.7 us |    12.54 |
| leq R <= T                               |   711.9 us |    1.10 ms |     0.6 us |     4.6 us |     0.65 |
| equal T = T \| R                         |    2.77 ms |    4.06 ms |   714.2 us |    13.0 us |     0.68 |
| **traces-regex-lower: delays, n = 128** | | | | | |
| leq T <= S                               |    4.12 ms |    5.36 ms |     0.6 us |    10.5 us |     0.77 |
| leq S <= T (false)                       |    4.07 ms |    37.9 us |     0.6 us |    10.9 us |   107.36 |
| counterexample S, T                      |    4.10 ms |    40.1 us |     1.4 us |    10.9 us |   102.48 |
| leq R <= T                               |   10.29 ms |    9.99 ms |     0.6 us |    22.1 us |     1.03 |
| equal T = T \| R                         |   46.06 ms |   19.62 ms |   12.04 ms |    76.0 us |     2.35 |
| **traces-regex-lower: 8 declared names** | | | | | |
| leq X <= W                               |   464.9 us |    47.9 us |     1.2 us |     1.9 us |     9.70 |
| leq W <= X (false)                       |   453.9 us |    27.2 us |     1.2 us |     1.9 us |    16.70 |
| counterexample W, X                      |    33.1 us |    27.2 us |     2.1 us |     1.9 us |     1.22 |
| leq Y <= {8}                             |    79.9 us |    76.1 us |     0.5 us |     1.0 us |     1.05 |
| inhabited X                              |    16.0 us |    24.8 us |     5.8 us |     3.6 us |     0.64 |
| **traces-regex-lower: 32 declared names** | | | | | |
| leq X <= W                               |    46.0 us |    84.9 us |     5.4 us |     7.8 us |     0.54 |
| leq W <= X (false)                       |    31.0 us |    42.9 us |     5.3 us |     7.8 us |     0.72 |
| counterexample W, X                      |    34.1 us |    39.8 us |     6.2 us |     7.8 us |     0.86 |
| leq Y <= {8}                             |   143.1 us |   299.2 us |     2.1 us |     2.6 us |     0.48 |
| inhabited X                              |    25.0 us |    56.0 us |    21.0 us |    14.5 us |     0.45 |
| **traces-regex-lower: 128 declared names** | | | | | |
| leq X <= W                               |   257.0 us |   970.8 us |    24.0 us |    36.2 us |     0.26 |
| leq W <= X (false)                       |   165.0 us |   751.0 us |    23.9 us |    35.9 us |     0.22 |
| counterexample W, X                      |   169.0 us |   748.2 us |    24.8 us |    36.0 us |     0.23 |
| leq Y <= {8}                             |   796.1 us |    4.69 ms |     9.4 us |     9.9 us |     0.17 |
| inhabited X                              |   136.1 us |   972.0 us |   136.2 us |    61.7 us |     0.14 |
| **traces-regex-lower: n-th letter from the end, n = 4** | | | | | |
| elaborate E, E2                          |    4.30 ms |   141.9 us |    1.03 ms |     5.1 us |    30.31 |
| leq (B \| C)* <= E                       |    96.1 us |    47.9 us |     0.4 us |     0.9 us |     2.00 |
| counterexample (B \| C)*; A; (B \| C)^n, E |   121.1 us |    51.0 us |     0.4 us |     1.2 us |     2.37 |
| leq C* <= E2                             |    58.9 us |    62.9 us |     0.4 us |     1.1 us |     0.94 |
| **traces-regex-lower: n-th letter from the end, n = 8** | | | | | |
| elaborate E, E2                          |   95.13 ms |   127.1 us |   90.41 ms |     9.0 us |   748.63 |
| leq (B \| C)* <= E                       |    1.64 ms |    80.8 us |     0.4 us |     1.0 us |    20.30 |
| counterexample (B \| C)*; A; (B \| C)^n, E |    1.73 ms |    67.0 us |     0.4 us |     1.5 us |    25.85 |
| leq C* <= E2                             |    1.59 ms |    57.0 us |     0.4 us |     1.2 us |    27.83 |
| **traces-regex-interval: cost corpus (20 literals)** | | | | | |
| elaborate                                |    3.18 ms |   201.0 us |   414.0 us |    22.6 us |    15.80 |
| leq, all pairs                           |   11.01 ms |   10.22 ms |   518.6 us |   737.2 us |     1.08 |
| equal, all pairs                         |   11.09 ms |   10.58 ms |   629.4 us |   868.0 us |     1.05 |
| counterexample, all pairs                |   17.69 ms |   10.55 ms |    7.12 ms |   849.1 us |     1.68 |
| **traces-regex-interval: delays, n = 8** | | | | | |
| leq T <= S                               |   597.0 us |   131.8 us |     1.2 us |     2.6 us |     4.53 |
| leq S <= T (false)                       |   598.9 us |    23.8 us |     0.6 us |     1.3 us |    25.12 |
| counterexample S, T                      |   544.1 us |    28.1 us |     1.4 us |     1.3 us |    19.34 |
| leq R <= T                               |   253.0 us |   263.9 us |     1.2 us |     3.2 us |     0.96 |
| equal T = T \| R                         |    2.65 ms |    1.20 ms |   132.2 us |     7.9 us |     2.20 |
| **traces-regex-interval: delays, n = 32** | | | | | |
| leq T <= S                               |   661.1 us |    1.06 ms |     1.2 us |     5.4 us |     0.62 |
| leq S <= T (false)                       |   354.1 us |    31.0 us |     0.6 us |     2.7 us |    11.42 |
| counterexample S, T                      |   342.1 us |    34.1 us |     1.4 us |     2.8 us |    10.03 |
| leq R <= T                               |    1.61 ms |    4.38 ms |     1.2 us |     9.2 us |     0.37 |
| equal T = T \| R                         |    6.07 ms |    6.70 ms |    1.46 ms |    26.4 us |     0.91 |
| **traces-regex-interval: delays, n = 128** | | | | | |
| leq T <= S                               |    8.28 ms |    6.25 ms |     1.2 us |    21.3 us |     1.32 |
| leq S <= T (false)                       |    4.05 ms |    46.0 us |     0.6 us |    10.8 us |    87.97 |
| counterexample S, T                      |    4.06 ms |    40.1 us |     1.4 us |    11.0 us |   101.34 |
| leq R <= T                               |   22.55 ms |   22.22 ms |     1.2 us |    44.9 us |     1.01 |
| equal T = T \| R                         |   95.98 ms |   58.56 ms |   23.55 ms |   151.1 us |     1.64 |
| **traces-regex-interval: 8 declared names** | | | | | |
| leq X <= W                               |    68.2 us |   123.0 us |     2.5 us |     3.8 us |     0.55 |
| leq W <= X (false)                       |    34.1 us |    38.1 us |     1.2 us |     1.9 us |     0.89 |
| counterexample W, X                      |    31.9 us |    26.9 us |     2.1 us |     1.9 us |     1.19 |
| leq Y <= {8}                             |    78.0 us |    82.0 us |     0.5 us |     1.0 us |     0.95 |
| inhabited X                              |    26.0 us |    38.1 us |    11.7 us |     7.5 us |     0.68 |
| **traces-regex-interval: 32 declared names** | | | | | |
| leq X <= W                               |   160.9 us |    1.10 ms |    10.9 us |    15.7 us |     0.15 |
| leq W <= X (false)                       |    38.1 us |    40.1 us |     5.4 us |     7.9 us |     0.95 |
| counterexample W, X                      |    40.1 us |    47.0 us |     6.2 us |     8.0 us |     0.85 |
| leq Y <= {8}                             |   150.0 us |    1.32 ms |     2.1 us |     2.6 us |     0.11 |
| inhabited X                              |    52.0 us |    87.0 us |    40.9 us |    28.7 us |     0.60 |
| **traces-regex-interval: 128 declared names** | | | | | |
| leq X <= W                               |    1.45 ms |    4.24 ms |    47.6 us |    70.5 us |     0.34 |
| leq W <= X (false)                       |   154.0 us |    89.9 us |    23.9 us |    37.2 us |     1.71 |
| counterexample W, X                      |   158.1 us |    83.0 us |    25.1 us |    36.2 us |     1.91 |
| leq Y <= {8}                             |   769.9 us |    4.20 ms |     9.5 us |     9.9 us |     0.18 |
| inhabited X                              |   258.9 us |   330.0 us |   269.4 us |   124.4 us |     0.78 |
| **traces-regex-interval: n-th letter from the end, n = 4** | | | | | |
| elaborate E, E2                          |    4.62 ms |   169.0 us |    1.04 ms |     5.1 us |    27.33 |
| leq (B \| C)* <= E                       |   251.1 us |   994.9 us |     0.8 us |     1.8 us |     0.25 |
| counterexample (B \| C)*; A; (B \| C)^n, E |    2.46 ms |    1.04 ms |     0.9 us |     2.3 us |     2.36 |
| leq C* <= E2                             |   210.0 us |    3.69 ms |     0.8 us |     2.1 us |     0.06 |
| **traces-regex-interval: n-th letter from the end, n = 8** | | | | | |
| elaborate E, E2                          |   95.32 ms |   133.0 us |   90.93 ms |     9.0 us |   716.47 |
| leq (B \| C)* <= E                       |    4.34 ms |    9.50 ms |     0.7 us |     2.0 us |     0.46 |
| counterexample (B \| C)*; A; (B \| C)^n, E |    4.84 ms |    9.46 ms |     0.8 us |     3.0 us |     0.51 |
| leq C* <= E2                             |    3.87 ms |  121.82 ms |     0.8 us |     2.4 us |     0.03 |

Every cost-model row added by this benchmark completes within 130 ms cold, in
either implementation; the "n-th letter from the end" family for the
cost-model grades stops at `n = 8` for this reason, one step short of where
its plain-grade counterpart starts costing seconds. The four `> 20 s` cells
above are all in the plain regular-trace grade's pre-existing "n-th letter
from the end, n = 16" family, unrelated to the cost-model additions.
