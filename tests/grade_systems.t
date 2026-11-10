Grade systems other than the identity ones, selected by --resource-grades: the
pairs of grade algebras without a registered grade system, the literals of
boxes and box types read by the resource grade algebra and those of effects by
the effect grade algebra, and the resource grades of a lock printed as images.

A pair of grade algebras without a registered grade system is refused, naming
the resource grade algebras of the effect grade algebra:

  $ ../tempore --grades time-interval-rational --resource-grades time-interval ../examples/introduction/sensor_reading.tpe
  The grade algebra `time-interval-rational` has no grade system with the resource grade algebra `time-interval`; its resource grade algebras are `time-interval-rational`, `time-lower-bound-rational` and `time-upper-bound-rational`
  [1]

  $ ../tempore --grades lattice --resource-grades time-interval ../examples/lattice/security.tpe
  The grade algebra `lattice` has no grade system with the resource grade algebra `time-interval`; its only resource grade algebra is `lattice` itself
  [1]

The resource grade algebra of the effect grade algebra itself is the identity
system:

  $ ../tempore --grades time-interval-rational --resource-grades time-interval-rational --typecheck-only ../examples/introduction/sensor_reading.tpe

A box type whose grade is not a literal of the resource grade algebra is a
syntax error naming the resource grade algebras that read it:

  $ ../tempore --grades time-interval-rational --resource-grades time-lower-bound-rational ../examples/introduction/sensor_reading.tpe
  File "../examples/introduction/sensor_reading.tpe", line 51, characters 33-40:
  51 | operation Scan     :    unit ~> [[5, 10)]reading ! (0, 1/2]
                                        ^^^^^^^
  Syntax error: In the `time-lower-bound-rational` resource grade algebra, lower bounds are unbounded above, written `n`, `[n, ∞)` or `(n, ∞)`; did you mean to use the `time-interval-rational` resource grade algebra?
  [1]

  $ ../tempore --grades time-interval-rational --resource-grades time-upper-bound-rational ../examples/introduction/sensor_reading.tpe
  File "../examples/introduction/sensor_reading.tpe", line 51, characters 33-40:
  51 | operation Scan     :    unit ~> [[5, 10)]reading ! (0, 1/2]
                                        ^^^^^^^
  Syntax error: In the `time-upper-bound-rational` resource grade algebra, upper bounds start at a closed 0, written `n`, `[0, n]`, `[0, n)` or `∞`; did you mean to use the `time-interval-rational` resource grade algebra?
  [1]

An effect grade that is not a literal of the effect grade algebra is a syntax
error naming the effect grade algebra:

  $ printf 'operation Wait : unit ~> unit ! 5\n' > effect.tpe
  $ ../tempore --grades time-interval --resource-grades time-lower-bound effect.tpe
  File "effect.tpe", line 1, characters 32-33:
  1 | operation Wait : unit ~> unit ! 5
                                      ^
  Syntax error: In the `time-interval` effect grade algebra, grades are intervals `[n, m]`, `(n, m)`, `[n, m)`, `(n, m]`, `[n, ∞)` or `(n, ∞)`, not plain integers; did you mean to use one of the `time-lower-bound`, `timed-regex-lower-bound`, `timed-regex-finite-lower-bound` or `banked-traces-lower-bound` effect grade algebras?
  [1]

A box grade of a timed regex literal under the time intervals:

  $ printf 'operation Ping : unit ~> unit ! {Ping} within [1, 2]\n\nlet f x = box {Ping; [0, 3]} x\n' > regex.tpe
  $ ../tempore --grades timed-regex-interval --resource-grades time-interval regex.tpe
  File "regex.tpe", line 3, characters 14-28:
  3 | let f x = box {Ping; [0, 3]} x
                    ^^^^^^^^^^^^^^
  Syntax error: In the `time-interval` resource grade algebra, grades are intervals `[n, m]`, `(n, m)`, `[n, m)`, `(n, m]`, `[n, ∞)` or `(n, ∞)`, not brace literals `{...}`; did you mean to use the `timed-regex-interval` resource grade algebra?
  [1]

The scheme of a function whose box is unboxed after a computation of an
effect variable is qualified by the image of the variable:

  $ cat > rest.tpe <<'TPE'
  > operation Clean : unit ~> unit ! [20, 30]
  > default Clean () = delay 25
  > 
  > let rest f d =
  >   box 45 d as b in
  >   f ();
  >   unbox b as v in v
  > 
  > let chores () = perform Clean (); perform Clean (); perform Clean ()
  > 
  > run rest chores 3
  > TPE
  $ ../tempore --grades time-interval --resource-grades time-lower-bound --debug --no-stdlib rest.tpe
  === Top-level definitions ===
  rest :
    ∀ α β ε₀. ∣ε₀∣ ≾ 45 ⇒ (unit → α ! ε₀) → (β → β ! ε₀)
  chores :
    unit → unit ! [60, 90]
  
  === Run 1 ===
  return 3
  State: [
    { resource_0 ↦ 3 ! 45 },
    25,
    25,
    25
  ]
  

An argument whose effect has a resource grade not below the box grade is
refused at the application, the lock of the computation shown by its resource
grade:

  $ printf 'run rest (fun () -> perform Clean ()) 3\n' >> rest.tpe
  $ ../tempore --grades time-interval --resource-grades time-lower-bound --no-stdlib rest.tpe
  File "rest.tpe", line 12, characters 4-8:
  12 | run rest (fun () -> perform Clean ()) 3
           ^^^^
  Typing error: The resource inequality `20 >= 45` does not hold
    File "rest.tpe", lines 4-7, characters 0-19:
    4 | let rest f d =
        ^^^^^^^^^^^^^^
    `rest` is defined here
    File "rest.tpe", line 5, characters 14-15:
    5 |   box 45 d as b in
                      ^
    `b` is bound here
    File "rest.tpe", line 6, characters 2-6:
    6 |   f ();
          ^^^^
    grade `20` accumulates here (this computation)
  [1]

A box graded by a time upper bound under the upper trace bounds, the image of
a set of traces being the greatest duration of its traces, each operation at
the upper end of its running time:

  $ cat > ping.tpe <<'TPE'
  > operation Ping : unit ~> unit ! {Ping} within [1, 2]
  > default Ping () = delay 1
  > 
  > let twice x =
  >   box 5 x as b in
  >   perform Ping (); perform Ping ();
  >   unbox b as v in v
  > 
  > run twice 3
  > TPE
  $ ../tempore --grades banked-traces-upper-bound --resource-grades time-upper-bound --no-stdlib ping.tpe
  === Run 1 ===
  return 3
  State: [
    { resource_0 ↦ 3 ! 5 },
    1,
    1
  ]
  

  $ printf 'let thrice x =\n  box 5 x as b in\n  perform Ping (); perform Ping (); perform Ping ();\n  unbox b as v in v\n' >> ping.tpe
  $ ../tempore --grades banked-traces-upper-bound --resource-grades time-upper-bound --no-stdlib ping.tpe
  File "ping.tpe", line 13, characters 2-19:
  13 |   unbox b as v in v
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `6` accumulated since it was bound, which is not below its box grade `5`
    File "ping.tpe", line 11, characters 13-14:
    11 |   box 5 x as b in
                      ^
    `b` is bound here
    File "ping.tpe", line 12, characters 2-17:
    12 |   perform Ping (); perform Ping (); perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `2` accumulates here (operation `Ping`)
    File "ping.tpe", line 12, characters 19-34:
    12 |   perform Ping (); perform Ping (); perform Ping ();
                            ^^^^^^^^^^^^^^^
    grade `2` accumulates here (operation `Ping`)
    File "ping.tpe", line 12, characters 36-51:
    12 |   perform Ping (); perform Ping (); perform Ping ();
                                             ^^^^^^^^^^^^^^^
    grade `2` accumulates here (operation `Ping`)
    Note: the resource inequality `6 <= 5` does not hold
  [1]

A box graded by the numbers of calls under the finite run sets, the image of a
set of runs giving each operation the greatest number of its calls in one run:

  $ cat > send.tpe <<'TPE'
  > operation Send : unit ~> unit ! {Send}
  > 
  > let two x =
  >   box (Send, 2) x as b in
  >   perform Send (); delay 3; perform Send ();
  >   unbox b as v in v
  > TPE
  $ ../tempore --grades finite-run-sets --resource-grades at-most-counts --typecheck-only --no-stdlib send.tpe

  $ printf 'let three x =\n  box (Send, 2) x as b in\n  perform Send (); perform Send (); perform Send ();\n  unbox b as v in v\n' >> send.tpe
  $ ../tempore --grades finite-run-sets --resource-grades at-most-counts --typecheck-only --no-stdlib send.tpe
  File "send.tpe", line 10, characters 2-19:
  10 |   unbox b as v in v
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `(Send, 3)` accumulated since it was bound, which is not below its box grade `(Send, 2)`
    File "send.tpe", line 8, characters 21-22:
    8 |   box (Send, 2) x as b in
                             ^
    `b` is bound here
    File "send.tpe", line 9, characters 2-17:
    9 |   perform Send (); perform Send (); perform Send ();
          ^^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "send.tpe", line 9, characters 19-34:
    9 |   perform Send (); perform Send (); perform Send ();
                           ^^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "send.tpe", line 9, characters 36-51:
    9 |   perform Send (); perform Send (); perform Send ();
                                            ^^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    Note: the resource inequality `(Send, 3) <= (Send, 2)` does not hold
  [1]

Under the at-least counts with a top, the image of a set of runs gives each
operation the least number of its calls in one run, and a box graded by
`(Send, 1)` is unboxed only once a message is certain to have been sent:

  $ cat > sent.tpe <<'TPE'
  > operation Send : unit ~> unit ! {Send}
  > 
  > let after_send x =
  >   box (Send, 1) x as b in
  >   perform Send ();
  >   unbox b as v in v
  > 
  > let at_once x =
  >   box (Send, 1) x as b in
  >   unbox b as v in v
  > TPE
  $ ../tempore --grades finite-run-sets --resource-grades at-least-counts-with-top --typecheck-only --no-stdlib sent.tpe
  File "sent.tpe", line 10, characters 2-19:
  10 |   unbox b as v in v
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with the unit grade `0` accumulated since it was bound, which is not below its box grade `(Send, 1)`
    File "sent.tpe", line 9, characters 21-22:
    9 |   box (Send, 1) x as b in
                             ^
    `b` is bound here
    Note: the resource inequality `0 >= (Send, 1)` does not hold
  [1]

A box graded by an element of the declared grade lattice under the time lower
bounds paired with it, the image of a pair being its element:

  $ cat > calm.tpe <<'TPE'
  > grade lattice Quiet < Noisy
  > 
  > operation Hum : unit ~> unit ! (1, Quiet)
  > operation Shout : unit ~> unit ! (1, Noisy)
  > default Hum () = delay 1
  > default Shout () = delay 1
  > 
  > let calm x =
  >   box Quiet x as b in
  >   perform Hum ();
  >   unbox b as v in v
  > 
  > run calm 4
  > TPE
  $ ../tempore --grades time-lower-bound-lattice --resource-grades lattice --no-stdlib calm.tpe
  === Run 1 ===
  return 4
  State: [
    { resource_0 ↦ 4 ! Quiet }
  ]
  

  $ printf 'let loud x =\n  box Quiet x as b in\n  perform Shout ();\n  unbox b as v in v\n' >> calm.tpe
  $ ../tempore --grades time-lower-bound-lattice --resource-grades lattice --no-stdlib calm.tpe
  File "calm.tpe", line 17, characters 2-19:
  17 |   unbox b as v in v
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `Noisy` accumulated since it was bound, which is not below its box grade `Quiet`
    File "calm.tpe", line 15, characters 17-18:
    15 |   box Quiet x as b in
                          ^
    `b` is bound here
    File "calm.tpe", line 16, characters 2-18:
    16 |   perform Shout ();
           ^^^^^^^^^^^^^^^^
    grade `Noisy` accumulates here (operation `Shout`)
    Note: the resource inequality `Noisy <= Quiet` does not hold
  [1]

The declared grade lattice is that of the effect grades where the resource
grades are the time lower bounds, the image of a pair being its time:

  $ cat > hum.tpe <<'TPE'
  > grade lattice Quiet < Noisy
  > 
  > operation Hum : unit ~> unit ! (1, Quiet)
  > 
  > let settled x =
  >   box 2 x as b in
  >   perform Hum (); perform Hum ();
  >   unbox b as v in v
  > 
  > let early x =
  >   box 2 x as b in
  >   perform Hum ();
  >   unbox b as v in v
  > TPE
  $ ../tempore --grades time-lower-bound-lattice --resource-grades time-lower-bound --typecheck-only --no-stdlib hum.tpe
  File "hum.tpe", line 13, characters 2-19:
  13 |   unbox b as v in v
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `1` accumulated since it was bound, which is not below its box grade `2`
    File "hum.tpe", line 11, characters 13-14:
    11 |   box 2 x as b in
                      ^
    `b` is bound here
    File "hum.tpe", line 12, characters 2-16:
    12 |   perform Hum ();
           ^^^^^^^^^^^^^^
    grade `1` accumulates here (operation `Hum`)
    Note: the resource inequality `1 >= 2` does not hold
  [1]
