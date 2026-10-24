Declarations of levels: the checks of a declaration, an undeclared level, a
declaration under a grading monoid not built on levels, and the declarations
of the files of one run.

A level occurs twice in a chain:

  $ printf 'levels A < B < A\n\nlet x = 1\n' > repeat.tpe
  $ ../tempore --grades security-levels repeat.tpe
  File "repeat.tpe", line 1, characters 15-16:
  1 | levels A < B < A
                     ^
  Syntax error: The level `A` occurs twice in the chain `A < B < A`
  [1]

The order has a cycle:

  $ printf 'levels A < B, B < C, C < A\n\nlet x = 1\n' > cycle.tpe
  $ ../tempore --grades security-levels cycle.tpe
  File "cycle.tpe", line 1, characters 0-26:
  1 | levels A < B, B < C, C < A
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The declared levels have a cycle through `A`, `B` and `C`
  [1]

There is no least level:

  $ printf 'levels A < C, B < C\n\nlet x = 1\n' > least.tpe
  $ ../tempore --grades security-levels least.tpe
  File "least.tpe", line 1, characters 0-19:
  1 | levels A < C, B < C
      ^^^^^^^^^^^^^^^^^^^
  Syntax error: The declared levels have no least level; the minimal levels are `A` and `B`
  [1]

Two levels have no upper bound, or no least one:

  $ printf 'levels A < B, A < C\n\nlet x = 1\n' > upper.tpe
  $ ../tempore --grades security-levels upper.tpe
  File "upper.tpe", line 1, characters 0-19:
  1 | levels A < B, A < C
      ^^^^^^^^^^^^^^^^^^^
  Syntax error: The levels `B` and `C` have no upper bound
  [1]
  $ printf 'levels A < B < D, A < C < D, B < E, C < E\n\nlet x = 1\n' > join.tpe
  $ ../tempore --grades security-levels join.tpe
  File "join.tpe", line 1, characters 0-41:
  1 | levels A < B < D, A < C < D, B < E, C < E
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The levels `B` and `C` have no least upper bound; their minimal upper bounds are `D` and `E`
  [1]

Levels are ordered by `<` only:

  $ printf 'levels A <= B\n\nlet x = 1\n' > order.tpe
  $ ../tempore --grades security-levels order.tpe
  File "order.tpe", line 1, characters 9-11:
  1 | levels A <= B
               ^^
  Syntax error: Levels are ordered by `<` in a declaration of levels, not `<=`
  [1]

A level that is not declared, among few levels and among many:

  $ printf 'levels Quiet < Noisy\n\nlet f () = box High 1 as x in unbox x as y in y\n' > unknown.tpe
  $ ../tempore --grades security-levels unknown.tpe
  File "unknown.tpe", line 3, characters 15-19:
  3 | let f () = box High 1 as x in unbox x as y in y
                     ^^^^
  Syntax error: In the `security-levels` grading monoid, unknown level `High`; the levels are `Quiet` and `Noisy`
  [1]
  $ printf 'levels P < Q < R < S < T\n\nlet f () = box (3, X) 1 as x in unbox x as y in y\n' > unknown_many.tpe
  $ ../tempore --grades time-upper-bound-levels unknown_many.tpe
  File "unknown_many.tpe", line 3, characters 15-21:
  3 | let f () = box (3, X) 1 as x in unbox x as y in y
                     ^^^^^^
  Syntax error: In the `time-upper-bound-levels` grading monoid, in the second component (`security-levels`), unknown level `X`; the 5 levels range from `P` to `T`
  [1]

A declaration under a grading monoid not built on levels:

  $ printf 'levels Quiet < Noisy\n\nlet x = 1\n' > monoid.tpe
  $ ../tempore --grades time-upper-bound monoid.tpe
  File "monoid.tpe", line 1, characters 0-20:
  1 | levels Quiet < Noisy
      ^^^^^^^^^^^^^^^^^^^^
  Syntax error: The `time-upper-bound` grading monoid is not built on levels, which therefore cannot be declared
  [1]

The files of one run share a declaration: repeated identically, in another
chain order, or declared once and used by another file, it is accepted; a
differing one is an error.

  $ printf 'levels Public < Team < Secret, Public < Partner < Secret\n\nlet x = 1\n' > first.tpe
  $ printf 'levels Public < Partner < Secret, Public < Team < Secret\n\nlet y = 2\n' > same.tpe
  $ printf 'let f () = box Team 1 as b in unbox b as z in z\n\nrun f ()\n' > user.tpe
  $ ../tempore --grades security-levels first.tpe same.tpe user.tpe
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 ! Team }
  ]
  
  $ printf 'levels Public < Secret\n\nlet y = 2\n' > other.tpe
  $ ../tempore --grades security-levels first.tpe other.tpe
  File "other.tpe", line 1, characters 0-22:
  1 | levels Public < Secret
      ^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The levels `Public < Secret` differ from the levels `Public < Team < Secret, Public < Partner < Secret` of the program
    File "first.tpe", line 1, characters 0-56:
    1 | levels Public < Team < Secret, Public < Partner < Secret
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the levels of the program are declared here
  [1]

Elsewhere `levels` is an identifier:

  $ printf 'let levels = 3\n\nrun levels + 1\n' > identifier.tpe
  $ ../tempore --grades security-levels identifier.tpe
  === Run 1 ===
  return 4
  State: []
  
