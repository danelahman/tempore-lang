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
  Syntax error: In the `time-interval` effect grade algebra, grades are intervals `[n, m]`, `(n, m)`, `[n, m)`, `(n, m]`, `[n, ∞)` or `(n, ∞)`, not plain integers; did you mean to use the `time-lower-bound` effect grade algebra?
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
