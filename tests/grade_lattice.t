Declarations of the grade lattice: the checks of a declaration, an undeclared
element, a declaration under a grading monoid not built on a grade lattice, and
the declarations of the files of one run.

An element occurs twice in a chain:

  $ printf 'grade lattice A < B < A\n\nlet x = 1\n' > repeat.tpe
  $ ../tempore --grades lattice repeat.tpe
  File "repeat.tpe", line 1, characters 22-23:
  1 | grade lattice A < B < A
                            ^
  Syntax error: The element `A` occurs twice in the chain `A < B < A`
  [1]

The order has a cycle:

  $ printf 'grade lattice A < B, B < C, C < A\n\nlet x = 1\n' > cycle.tpe
  $ ../tempore --grades lattice cycle.tpe
  File "cycle.tpe", line 1, characters 0-33:
  1 | grade lattice A < B, B < C, C < A
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The declared grade lattice has a cycle through `A`, `B` and `C`
  [1]

There is no least element:

  $ printf 'grade lattice A < C, B < C\n\nlet x = 1\n' > least.tpe
  $ ../tempore --grades lattice least.tpe
  File "least.tpe", line 1, characters 0-26:
  1 | grade lattice A < C, B < C
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The declared grade lattice has no least element; the minimal elements are `A` and `B`
  [1]

Two elements have no upper bound, or no least one:

  $ printf 'grade lattice A < B, A < C\n\nlet x = 1\n' > upper.tpe
  $ ../tempore --grades lattice upper.tpe
  File "upper.tpe", line 1, characters 0-26:
  1 | grade lattice A < B, A < C
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The elements `B` and `C` have no upper bound
  [1]
  $ printf 'grade lattice A < B < D, A < C < D, B < E, C < E\n\nlet x = 1\n' > join.tpe
  $ ../tempore --grades lattice join.tpe
  File "join.tpe", line 1, characters 0-48:
  1 | grade lattice A < B < D, A < C < D, B < E, C < E
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The elements `B` and `C` have no least upper bound; their minimal upper bounds are `D` and `E`
  [1]

Elements are ordered by `<` only:

  $ printf 'grade lattice A <= B\n\nlet x = 1\n' > order.tpe
  $ ../tempore --grades lattice order.tpe
  File "order.tpe", line 1, characters 16-18:
  1 | grade lattice A <= B
                      ^^
  Syntax error: Elements are ordered by `<` in a declaration of the grade lattice, not `<=`
  [1]

An element that is not declared, among few elements and among many:

  $ printf 'grade lattice Quiet < Noisy\n\nlet f () = box High 1 as x in unbox x as y in y\n' > unknown.tpe
  $ ../tempore --grades lattice unknown.tpe
  File "unknown.tpe", line 3, characters 15-19:
  3 | let f () = box High 1 as x in unbox x as y in y
                     ^^^^
  Syntax error: In the `lattice` grading monoid, unknown element `High` of the grade lattice; its elements are `Quiet` and `Noisy`
  [1]
  $ printf 'grade lattice P < Q < R < S < T\n\nlet f () = box (3, X) 1 as x in unbox x as y in y\n' > unknown_many.tpe
  $ ../tempore --grades time-upper-bound-lattice unknown_many.tpe
  File "unknown_many.tpe", line 3, characters 15-21:
  3 | let f () = box (3, X) 1 as x in unbox x as y in y
                     ^^^^^^
  Syntax error: In the `time-upper-bound-lattice` grading monoid, in the second component (`lattice`), unknown element `X` of the grade lattice; its 5 elements range from `P` to `T`
  [1]

A declaration under a grading monoid not built on a grade lattice:

  $ printf 'grade lattice Quiet < Noisy\n\nlet x = 1\n' > monoid.tpe
  $ ../tempore --grades time-upper-bound monoid.tpe
  File "monoid.tpe", line 1, characters 0-27:
  1 | grade lattice Quiet < Noisy
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The `time-upper-bound` grading monoid is not built on a grade lattice, so none can be declared
  [1]

The files of one run share a declaration: repeated identically, in another
chain order, or declared once and used by another file, it is accepted; a
differing one is an error.

  $ printf 'grade lattice Public < Team < Secret, Public < Partner < Secret\n\nlet x = 1\n' > first.tpe
  $ printf 'grade lattice Public < Partner < Secret, Public < Team < Secret\n\nlet y = 2\n' > same.tpe
  $ printf 'let f () = box Team 1 as b in unbox b as z in z\n\nrun f ()\n' > user.tpe
  $ ../tempore --grades lattice first.tpe same.tpe user.tpe
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 ! Team }
  ]
  
  $ printf 'grade lattice Public < Secret\n\nlet y = 2\n' > other.tpe
  $ ../tempore --grades lattice first.tpe other.tpe
  File "other.tpe", line 1, characters 0-29:
  1 | grade lattice Public < Secret
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: The grade lattice `Public < Secret` differs from the grade lattice `Public < Team < Secret, Public < Partner < Secret` of the program
    File "first.tpe", line 1, characters 0-63:
    1 | grade lattice Public < Team < Secret, Public < Partner < Secret
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the grade lattice of the program is declared here
  [1]

Elsewhere `grade` and `lattice` are identifiers:

  $ printf 'let grade = 3\n\nlet lattice = 4\n\nrun grade + lattice\n' > identifier.tpe
  $ ../tempore --grades lattice identifier.tpe
  === Run 1 ===
  return 7
  State: []
  
