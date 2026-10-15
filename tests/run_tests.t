Every test file, run under the grades its header names, the default grades if
it names none:

  $ for f in *.tpe
  > do
  >   echo "======================================================================"
  >   echo $f
  >   echo "======================================================================"
  >   ../tempore $(support/header_options.exe $f) $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  alias_cyclic_reject.tpe
  ======================================================================
  File "alias_cyclic_reject.tpe", line 3, characters 0-16:
  3 | type t = t * nat
      ^^^^^^^^^^^^^^^^
  Typing error: The type alias `t` is cyclic
  ======================================================================
  alias_cyclic_reject_argument.tpe
  ======================================================================
  File "alias_cyclic_reject_argument.tpe", line 3, characters 0-21:
  3 | type 'a t = 'a t list
      ^^^^^^^^^^^^^^^^^^^^^
  Typing error: The type alias `t` is cyclic
  ======================================================================
  alias_cyclic_reject_mutual.tpe
  ======================================================================
  File "alias_cyclic_reject_mutual.tpe", lines 3-4, characters 0-9:
  3 | type t = u * nat
      ^^^^^^^^^^^^^^^^
  Typing error: The type alias `t` is cyclic
  ======================================================================
  alias_cyclic_reject_parameter.tpe
  ======================================================================
  File "alias_cyclic_reject_parameter.tpe", line 3, characters 0-23:
  3 | type 'a t = ('a * 'a) t
      ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The type alias `t` is cyclic
  ======================================================================
  alias_cyclic_reject_through_alias.tpe
  ======================================================================
  File "alias_cyclic_reject_through_alias.tpe", lines 3-4, characters 0-12:
  3 | type 'a id = 'a
      ^^^^^^^^^^^^^^^
  Typing error: The type alias `u` is cyclic
  ======================================================================
  alias_recursive.tpe
  ======================================================================
  === Run 1 ===
  return (Node (Leaf, Node (Leaf, Leaf)))
  State: []
  
  === Run 2 ===
  return (1, 2)
  State: []
  
  === Run 3 ===
  return 3
  State: []
  
  ======================================================================
  andalso_reject_tuple.tpe
  ======================================================================
  File "andalso_reject_tuple.tpe", line 4, characters 9-22:
  4 | run (&&) (true, false)
               ^^^^^^^^^^^^^
  Typing error: This argument has type `α × β` but the function expects `bool`
    File "andalso_reject_tuple.tpe", line 4, characters 4-8:
    4 | run (&&) (true, false)
            ^^^^
    the function has type `bool → bool → bool`
    Note: while matching `bool → bool → bool` against `bool × bool → γ # ε₀`
  ======================================================================
  annotation_grade_variables.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    1,
    2
  ]
  
  === Run 2 ===
  return 5
  State: [
    { resource_0 ↦ <fun> # 2 },
    2
  ]
  
  === Run 3 ===
  return 2
  State: []
  
  ======================================================================
  annotation_grade_variables_cyclic.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    1,
    1,
    1
  ]
  
  === Run 2 ===
  return ()
  State: [
    1,
    1
  ]
  
  === Run 3 ===
  return 5
  State: []
  
  === Run 4 ===
  return ()
  State: [
    10
  ]
  
  ======================================================================
  annotation_grade_variables_cyclic_reject.tpe
  ======================================================================
  File "annotation_grade_variables_cyclic_reject.tpe", line 15, characters 22-23:
  15 | let h () : unit # 5 = f (fun () -> ())
                             ^
  Typing error: The effect inequality `10 <= 5` does not hold
    File "annotation_grade_variables_cyclic_reject.tpe", line 11, characters 0-58:
    11 | let f (g : unit -> unit # 'e) : unit # 'e = g (); delay 10
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `f` is defined here
    File "annotation_grade_variables_cyclic_reject.tpe", line 15, characters 9-38:
    15 | let h () : unit # 5 = f (fun () -> ())
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  
  File "annotation_grade_variables_cyclic_reject.tpe", line 28, characters 4-7:
  28 | run bad ()
           ^^^
  Typing error: The conditions of this run could not be established: `1 · ε₀ <= 3` and `1 · ε₀ <= ε₀`
    File "annotation_grade_variables_cyclic_reject.tpe", line 24, characters 0-31:
    24 | let bad () : unit # 3 = loop 20
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `bad` is defined here
    File "annotation_grade_variables_cyclic_reject.tpe", lines 19-20, characters 0-51:
    19 | let rec loop (n : nat) : unit # 'e =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `loop` is defined here
    Note: this run requires grades for its unknowns at which every one of these holds; none of the grades tried does, although the definitions they come from were accepted
  ======================================================================
  annotation_grade_variables_interval_reject.tpe
  ======================================================================
  File "annotation_grade_variables_interval_reject.tpe", line 25, characters 27-28:
  25 | let h () : unit # [0, 5] = f (fun () -> ())
                                  ^
  Typing error: The effect inequality `[10, 10] <= [0, 5]` does not hold
    File "annotation_grade_variables_interval_reject.tpe", line 14, characters 0-58:
    14 | let f (g : unit -> unit # 'e) : unit # 'e = g (); delay 10
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `f` is defined here
    File "annotation_grade_variables_interval_reject.tpe", line 25, characters 9-43:
    25 | let h () : unit # [0, 5] = f (fun () -> ())
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  ======================================================================
  annotation_grade_variables_reject.tpe
  ======================================================================
  File "annotation_grade_variables_reject.tpe", line 12, characters 37-69:
  12 |   ((slow : (unit -> nat # 'e) list), (fast : (unit -> nat # 'e) list))
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This expression has type `(unit → nat # 1) list` but is annotated with `(unit → nat # 2) list`
    File "annotation_grade_variables_reject.tpe", line 12, characters 3-35:
    12 |   ((slow : (unit -> nat # 'e) list), (fast : (unit -> nat # 'e) list))
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
    Note: the effect inequality `2 <= 1` does not hold
  
  File "annotation_grade_variables_reject.tpe", line 18, characters 27-70:
  18 | let violated () = run_fast ((fun () -> delay 2; 0) : unit -> nat # 'e)
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `2`, which does not match its annotated grade `1`
    File "annotation_grade_variables_reject.tpe", line 18, characters 18-26:
    18 | let violated () = run_fast ((fun () -> delay 2; 0) : unit -> nat # 'e)
                           ^^^^^^^^
    the inequality goes through the type of `run_fast` here
    Note: the effect inequality `2 <= 1` does not hold
  ======================================================================
  annotation_recursion.tpe
  ======================================================================
  === Run 1 ===
  return 120
  State: []
  
  === Run 2 ===
  return 120
  State: []
  
  === Run 3 ===
  return 4
  State: []
  
  === Run 4 ===
  return false
  State: []
  
  === Run 5 ===
  return 7
  State: []
  
  === Run 6 ===
  return 4
  State: []
  
  === Run 7 ===
  return 24
  State: []
  
  === Run 8 ===
  return (true, "4")
  State: []
  
  ======================================================================
  annotation_recursion_reject.tpe
  ======================================================================
  File "annotation_recursion_reject.tpe", line 4, characters 14-71:
  4 | let rec count (n : nat) : bool = if n = 0 then 0 else 1 + count (n - 1)
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The body of the recursive function `count` has type `bool` but `count` is used as returning `nat`
    File "annotation_recursion_reject.tpe", line 4, characters 54-57:
    4 | let rec count (n : nat) : bool = if n = 0 then 0 else 1 + count (n - 1)
                                                              ^^^
    `nat` was inferred here
  
  File "annotation_recursion_reject.tpe", line 8, characters 22-73:
  8 | let rec pick (x : 'b) (y : 'b) : nat = if y then x else pick (x + 1) true
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `nat` is not compatible with type `bool`
    File "annotation_recursion_reject.tpe", line 8, characters 39-73:
    8 | let rec pick (x : 'b) (y : 'b) : nat = if y then x else pick (x + 1) true
                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `bool` was inferred here
  ======================================================================
  annotation_type_variables_reject.tpe
  ======================================================================
  File "annotation_type_variables_reject.tpe", line 6, characters 24-26:
  6 | type opaque = Opaque of 'b
                              ^^
  Syntax error: Unknown name `b`
  ======================================================================
  annotation_type_variables_reject_operation.tpe
  ======================================================================
  File "annotation_type_variables_reject_operation.tpe", line 6, characters 17-19:
  6 | operation Send : 'b ~> unit # 1
                       ^^
  Syntax error: Unknown name `b`
  ======================================================================
  comp_type_annotation.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    3
  ]
  
  === Run 2 ===
  return 4
  State: [
    2
  ]
  
  === Run 3 ===
  return 42
  State: [
    1
  ]
  
  === Run 4 ===
  return 1
  State: [
    3
  ]
  
  ======================================================================
  comp_type_annotation_reject.tpe
  ======================================================================
  File "comp_type_annotation_reject.tpe", line 3, characters 9-31:
  3 | let f () : nat # 5 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the effect inequality `3 >= 5` does not hold
  ======================================================================
  comp_type_annotation_upper.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    3
  ]
  
  ======================================================================
  comp_type_annotation_upper_reject.tpe
  ======================================================================
  File "comp_type_annotation_upper_reject.tpe", line 8, characters 9-31:
  8 | let f () : nat # 2 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `2`
    Note: the effect inequality `3 <= 2` does not hold
  ======================================================================
  comparison_reject_box.tpe
  ======================================================================
  File "comparison_reject_box.tpe", line 3, characters 23-24:
  3 | run (box 1 3 as b in b = b)
                             ^
  Typing error: Type `[ρ₀]nat` is not eternal, as required by the type of `(=)`
    File "stdlib.tpe", line 1, characters 0-37:
    1 | let ( = ) x y = __compare_eq__ (x, y)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `(=)` is defined here
    Note: a box type is never eternal
  ======================================================================
  comparison_reject_function.tpe
  ======================================================================
  File "comparison_reject_function.tpe", line 5, characters 7-8:
  5 | run (f = f)
             ^
  Typing error: Type `α → β # ε₀` is not eternal, as required by the type of `(=)`
    File "stdlib.tpe", line 1, characters 0-37:
    1 | let ( = ) x y = __compare_eq__ (x, y)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `(=)` is defined here
  ======================================================================
  comparison_reject_recursive_argument.tpe
  ======================================================================
  File "comparison_reject_recursive_argument.tpe", line 5, characters 26-27:
  5 | run (N (W (fun () -> 1))) = (N (W (fun () -> 2)))
                                ^
  Typing error: Type `α wrap` is not eternal, as required by the type of `(=)`
    File "stdlib.tpe", line 1, characters 0-37:
    1 | let ( = ) x y = __compare_eq__ (x, y)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `(=)` is defined here
  ======================================================================
  continuation_discard_abort_reject_lower.tpe
  ======================================================================
  File "continuation_discard_abort_reject_lower.tpe", line 13, characters 52-57:
  13 | let g () = handle (perform Op (); delay 10; 3) with abort (fun () -> delay 5; 0)
                                                           ^^^^^
  Typing error: The effect inequality `∀ε_Op. 5 >= 1 · ε_Op` does not hold
    File "continuation_discard_abort_reject_lower.tpe", line 9, characters 0-48:
    9 | let abort f = handler | x -> x | Op () k -> f ()
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `abort` is defined here
    File "continuation_discard_abort_reject_lower.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_discard_abort_reject_lower.tpe", line 9, characters 39-40:
    9 | let abort f = handler | x -> x | Op () k -> f ()
                                               ^
    `k` may have any grade `ε_Op`
    Note: the effect inequality `∀ε_Op. 5 >= 1 · ε_Op` does not hold: for `ε_Op = 5` it becomes `5 >= 6`
  ======================================================================
  continuation_discard_delay_reject_lower.tpe
  ======================================================================
  File "continuation_discard_delay_reject_lower.tpe", line 11, characters 27-48:
  11 | let h = handler | x -> x | Op () k -> delay 5; 0
                                  ^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ε_Op` the continuation `k` may have, the case for `Op` must have a grade matching `1 · ε_Op`, but its grade `5` does not
    File "continuation_discard_delay_reject_lower.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_discard_delay_reject_lower.tpe", line 11, characters 33-34:
    11 | let h = handler | x -> x | Op () k -> delay 5; 0
                                          ^
    `k` may have any grade `ε_Op`
    Note: the effect inequality `∀ε_Op. 5 >= 1 · ε_Op` does not hold: for `ε_Op = 5` it becomes `5 >= 6`
  ======================================================================
  continuation_discard_reject_lower.tpe
  ======================================================================
  File "continuation_discard_reject_lower.tpe", line 10, characters 27-38:
  10 | let h = handler | x -> x | Op p k -> 5
                                  ^^^^^^^^^^^
  Typing error: For every grade `ε_Op` the continuation `k` may have, the case for `Op` must have a grade matching `1 · ε_Op`, but its grade `0` does not
    File "continuation_discard_reject_lower.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_discard_reject_lower.tpe", line 10, characters 32-33:
    10 | let h = handler | x -> x | Op p k -> 5
                                         ^
    `k` may have any grade `ε_Op`
    Note: the effect inequality `∀ε_Op. 0 >= 1 · ε_Op` does not hold: for `ε_Op = 0` it becomes `0 >= 1`
  ======================================================================
  continuation_discard_upper.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: [
    { resource_1 ↦ <fun> # 1 }
  ]
  
  ======================================================================
  continuation_escape_reject.tpe
  ======================================================================
  File "continuation_escape_reject.tpe", line 11, characters 39-40:
  11 | let h g = handler | x -> x | Op p k -> g k; delay 1; continue k with ()
                                              ^
  Typing error: Variable `g` has type `[1](unit → α # ε₀) → β`, which is not eternal, so it cannot be used in the case for `Op`: the case runs with a grade the handler does not fix
    File "continuation_escape_reject.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_escape_reject.tpe", line 11, characters 6-7:
    11 | let h g = handler | x -> x | Op p k -> g k; delay 1; continue k with ()
               ^
    `g` is bound here
    File "continuation_escape_reject.tpe", line 11, characters 29-71:
    11 | let h g = handler | x -> x | Op p k -> g k; delay 1; continue k with ()
                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` is checked with the top grade `∞` accumulated
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  continuation_fixed.tpe
  ======================================================================
  === Run 1 ===
  return (fun () ↦ let f = (unbox resource_1 as cont_var in
                            cont_var ()) in
                   f ())
  State: [
    { resource_1 ↦ <fun> # 1 }
  ]
  
  ======================================================================
  continuation_nested_discard_reject_lower.tpe
  ======================================================================
  File "continuation_nested_discard_reject_lower.tpe", line 21, characters 13-43:
  21 |            | Op2 q k' -> delay 3; return ())
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ε_Op2` the continuation `k'` may have, the case for `Op2` must have a grade matching `3 · ε_Op2`, but its grade `3` does not
    File "continuation_nested_discard_reject_lower.tpe", line 6, characters 0-32:
    6 | operation Op2 : unit ~> unit # 3
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "continuation_nested_discard_reject_lower.tpe", line 21, characters 19-21:
    21 |            | Op2 q k' -> delay 3; return ())
                            ^^
    `k'` may have any grade `ε_Op2`
    Note: the effect inequality `∀ε_Op2. 3 >= 3 · ε_Op2` does not hold: for `ε_Op2 = 1` it becomes `3 >= 4`
  ======================================================================
  continuation_nested_escape_reject.tpe
  ======================================================================
  File "continuation_nested_escape_reject.tpe", line 24, characters 23-24:
  24 |          | Op2 q k' -> g k'; delay 1; continue k' with ())
                              ^
  Typing error: Variable `g` has type `[1](unit → α # ε₀) → β`, which is not eternal, so it cannot be used in the case for `Op1`: the case runs with a grade the handler does not fix
    File "continuation_nested_escape_reject.tpe", line 6, characters 0-32:
    6 | operation Op1 : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op1` is declared here
    File "continuation_nested_escape_reject.tpe", line 14, characters 6-7:
    14 | let h g =
               ^
    `g` is bound here
    File "continuation_nested_escape_reject.tpe", lines 17-24, characters 4-58:
    17 |   | Op1 p k ->
             ^^^^^^^^^^
    the case for `Op1` is checked with the top grade `∞` accumulated
    File "continuation_nested_escape_reject.tpe", line 24, characters 11-57:
    24 |          | Op2 q k' -> g k'; delay 1; continue k' with ())
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op2` is checked with the top grade `∞` accumulated
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  continuation_nested_fixed.tpe
  ======================================================================
  === Run 1 ===
  return (fun () ↦ let f = (unbox resource_3 as cont_var in
                            cont_var ()) in
                   f ())
  State: [
    { resource_1 ↦ <fun> # 1, resource_3 ↦ <fun> # 1 }
  ]
  
  ======================================================================
  continuation_nested_twice_reject_upper.tpe
  ======================================================================
  File "continuation_nested_twice_reject_upper.tpe", line 25, characters 15-34:
  25 |                continue k' with ())
                      ^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k'` is unboxed with grade `∣ε_Op2∣` accumulated since it was bound, which is not below its box grade `1`
    File "continuation_nested_twice_reject_upper.tpe", line 24, characters 23-42:
    24 |                let b = continue k' with () in
                                ^^^^^^^^^^^^^^^^^^^
    grade `ε_Op2` accumulates here (this computation)
    File "continuation_nested_twice_reject_upper.tpe", line 23, characters 19-21:
    23 |            | Op2 q k' ->
                            ^^
    `k'` may have any grade `ε_Op2`
    Note: the resource inequality `∀ε_Op2. ∣ε_Op2∣ <= 1` does not hold: for `ε_Op2 = ∞` it becomes `∞ <= 1`
  ======================================================================
  continuation_obligation_lower.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # 1 },
    1
  ]
  
  ======================================================================
  continuation_twice_lower.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  ======================================================================
  continuation_twice_reject_upper.tpe
  ======================================================================
  File "continuation_twice_reject_upper.tpe", line 11, characters 67-85:
  11 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                                                          ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `∣ε_Op∣` accumulated since it was bound, which is not below its box grade `1`
    File "continuation_twice_reject_upper.tpe", line 11, characters 45-63:
    11 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                                      ^^^^^^^^^^^^^^^^^^
    grade `ε_Op` accumulates here (this computation)
    File "continuation_twice_reject_upper.tpe", line 11, characters 32-33:
    11 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                         ^
    `k` may have any grade `ε_Op`
    Note: the resource inequality `∀ε_Op. ∣ε_Op∣ <= 1` does not hold: for `ε_Op = ∞` it becomes `∞ <= 1`
  ======================================================================
  counts_upper.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: []
  
  === Run 2 ===
  return ()
  State: [
    { resource_1 ↦ <fun> # (Send, 1),
      resource_3 ↦ <fun> # (Send, 1),
      resource_5 ↦ <fun> # (Send, 1)
    }
  ]
  
  === Run 3 ===
  return 7
  State: [
    { resource_0 ↦ 7 # (Send, 2) }
  ]
  
  ======================================================================
  counts_upper_reject.tpe
  ======================================================================
  File "counts_upper_reject.tpe", lines 11-15, characters 12-16:
  11 | let four () : unit # (Send, 3) =
                   ^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Send, 4)`, which does not match its annotated grade `(Send, 3)`
    Note: the effect inequality `(Send, 4) <= (Send, 3)` does not hold
  
  File "counts_upper_reject.tpe", lines 18-20, characters 16-16:
  18 | let unlisted () : unit # (Send, 3) =
                       ^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `((Auth, 1), (Send, 1))`, which does not match its annotated grade `(Send, 3)`
    Note: the effect inequality `((Auth, 1), (Send, 1)) <= (Send, 3)` does not hold
  
  File "counts_upper_reject.tpe", lines 27-28, characters 2-3:
  27 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(Send, 2)` accumulated since it was bound, which is not below its box grade `(Send, 1)`
    File "counts_upper_reject.tpe", line 24, characters 21-22:
    24 |   box (Send, 1) 7 as x in
                              ^
    `x` is bound here
    File "counts_upper_reject.tpe", line 25, characters 2-16:
    25 |   perform Send 1;
           ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "counts_upper_reject.tpe", line 26, characters 2-16:
    26 |   perform Send 2;
           ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    Note: the resource inequality `(Send, 2) <= (Send, 1)` does not hold
  
  File "counts_upper_reject.tpe", line 35, characters 48-66:
  35 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                                                       ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(Send, 2)` accumulated since it was bound, which is not below its box grade `(Send, 1)`
    File "counts_upper_reject.tpe", line 35, characters 11-12:
    35 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                    ^
    `k` is bound here
    File "counts_upper_reject.tpe", line 35, characters 16-30:
    35 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                         ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "counts_upper_reject.tpe", line 35, characters 32-46:
    35 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                                         ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    Note: the resource inequality `(Send, 2) <= (Send, 1)` does not hold
  ======================================================================
  default_chain.tpe
  ======================================================================
  === Run 1 ===
  return 2
  State: [
    1,
    1,
    1
  ]
  
  === Run 2 ===
  return ()
  State: [
    { resource_1 ↦ <fun> # 1 },
    1
  ]
  
  ======================================================================
  default_file_order.tpe
  ======================================================================
  === Run 1 (unhandled operation) ===
  perform Heat () (op_var. return op_var)
  
  === Run 2 (unhandled operation) ===
  perform Cool () (op_var. (let op_var = return op_var in
                            return op_var))
  
  === Run 3 ===
  return ()
  State: [
    1,
    1
  ]
  
  ======================================================================
  default_ops.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ <fun> # 3 },
    3,
    1,
    1
  ]
  
  === Run 2 ===
  return 0
  State: [
    3,
    1
  ]
  
  ======================================================================
  default_reject_bounds.tpe
  ======================================================================
  File "default_reject_bounds.tpe", line 7, characters 0-24:
  7 | default Get () = delay 2
      ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Get` has grade `2`, which does not match the declared grade `3` of `Get`
    File "default_reject_bounds.tpe", line 5, characters 0-32:
    5 | operation Get : unit ~> unit # 3
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Get` is declared here
    Note: the effect inequality `2 >= 3` does not hold
  ======================================================================
  default_reject_cycle.tpe
  ======================================================================
  File "default_reject_cycle.tpe", line 9, characters 0-31:
  9 | default Pong x = perform Ping x
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default of `Pong` may perform `Pong` again, through the default of `Ping`
    File "default_reject_cycle.tpe", line 9, characters 17-31:
    9 | default Pong x = perform Ping x
                         ^^^^^^^^^^^^^^
    `Ping` is performed here
    File "default_reject_cycle.tpe", line 8, characters 0-31:
    8 | default Ping x = perform Pong x
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the default of `Ping`, which may perform `Pong`, is defined here
    Note: a default runs in place of an unhandled operation, so a cycle through defaults does not terminate
  ======================================================================
  default_reject_duplicate.tpe
  ======================================================================
  File "default_reject_duplicate.tpe", line 8, characters 0-25:
  8 | default Log msg = delay 2
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Operation `Log` already has a default implementation
  ======================================================================
  default_reject_global.tpe
  ======================================================================
  File "default_reject_global.tpe", line 11, characters 0-27:
  11 | default Retry n = refetch n
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default of `Retry` may perform `Retry` again, through the default of `Fetch`
    File "default_reject_global.tpe", line 11, characters 18-25:
    11 | default Retry n = refetch n
                           ^^^^^^^
    `refetch`, which may perform `Fetch`, is used here
    File "default_reject_global.tpe", line 10, characters 0-33:
    10 | default Fetch n = perform Retry n
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the default of `Fetch`, which may perform `Retry`, is defined here
    Note: a default runs in place of an unhandled operation, so a cycle through defaults does not terminate
  ======================================================================
  default_reject_loop.tpe
  ======================================================================
  File "default_reject_loop.tpe", line 6, characters 0-31:
  6 | default Loop x = perform Loop x
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default of `Loop` may perform `Loop` again
    File "default_reject_loop.tpe", line 6, characters 17-31:
    6 | default Loop x = perform Loop x
                         ^^^^^^^^^^^^^^
    `Loop` is performed here
    Note: a default runs in place of an unhandled operation, so a cycle through defaults does not terminate
  ======================================================================
  default_reject_type.tpe
  ======================================================================
  File "default_reject_type.tpe", line 7, characters 0-32:
  7 | default Get () = delay 3; "zero"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Get` returns `string` but `Get` returns `nat`
    File "default_reject_type.tpe", line 5, characters 0-31:
    5 | operation Get : unit ~> nat # 3
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Get` is declared here
  ======================================================================
  default_reject_unestablished.tpe
  ======================================================================
  File "default_reject_unestablished.tpe", line 18, characters 0-23:
  18 | default Op () = loop 20
       ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The conditions of this default implementation could not be established: `ε₀ <= 3` and `1 · ε₀ <= ε₀`
    File "default_reject_unestablished.tpe", line 13, characters 0-31:
    13 | operation Op : unit ~> unit # 3
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "default_reject_unestablished.tpe", lines 10-11, characters 0-51:
    10 | let rec loop (n : nat) : unit # 'e =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `loop` is defined here
    File "default_reject_unestablished.tpe", line 18, characters 16-20:
    18 | default Op () = loop 20
                         ^^^^
    the inequality goes through the type of `loop` here
    Note: this default implementation requires grades for its unknowns at which every one of these holds; none of the grades tried does, although the definitions they come from were accepted
  ======================================================================
  default_reject_unknown.tpe
  ======================================================================
  File "default_reject_unknown.tpe", line 5, characters 8-11:
  5 | default Log msg = delay 1
              ^^^
  Syntax error: Unknown name `Log`
  ======================================================================
  delay_reject_expression.tpe
  ======================================================================
  File "delay_reject_expression.tpe", line 4, characters 20-21:
  4 | let wait () = delay (1 + 1)
                          ^
  Syntax error: The argument of `delay` is a duration literal, such as `2`, `1/2` or `0.25`
  ======================================================================
  delay_reject_fraction.tpe
  ======================================================================
  File "delay_reject_fraction.tpe", line 8, characters 20-23:
  8 | let wait () = delay 0.5
                          ^^^
  Syntax error: In the `time-upper-bound` grading monoid, delays are whole numbers of time steps; did you mean to use one of the `time-lower-bound-rational`, `time-upper-bound-rational`, `time-interval-rational`, `traces-upper-bound-rational`, `traces-timed-lower-bound-rational`, `traces-timed-upper-bound-rational`, `traces-timed-interval-rational`, `regex-upper-bound-rational-symbolic`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `security-levels`, `flow-levels`, `mode-times` or `event-separation` grading monoids?
  ======================================================================
  delay_reject_negative.tpe
  ======================================================================
  File "delay_reject_negative.tpe", line 3, characters 10-14:
  3 | run delay -0.5
                ^^^^
  Syntax error: Durations must be non-negative
  ======================================================================
  delay_reject_overflow.tpe
  ======================================================================
  File "delay_reject_overflow.tpe", line 8, characters 0-49:
  8 | let f () = delay 4611686018427387903; delay 1; ()
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The duration exceeds the supported range
  ======================================================================
  delay_reject_variable.tpe
  ======================================================================
  File "delay_reject_variable.tpe", line 6, characters 8-9:
  6 |   delay n
              ^
  Syntax error: The argument of `delay` is a duration literal, such as `2`, `1/2` or `0.25`
  ======================================================================
  diagnostic_reject_utf8_columns.tpe
  ======================================================================
  File "diagnostic_reject_utf8_columns.tpe", line 3, characters 18-20:
  3 | run ("∞∞∞", qq)
                  ^^
  Syntax error: Unknown name `qq`
  ======================================================================
  duplicate_variant_tydef_sum.tpe
  ======================================================================
  File "duplicate_variant_tydef_sum.tpe", line 3, characters 25-29:
  3 | type cow = Horn of nat | Horn of string
                               ^^^^
  Syntax error: Label `Horn` defined multiple times
  ======================================================================
  error_apply_arg.tpe
  ======================================================================
  File "error_apply_arg.tpe", line 11, characters 8-9:
  11 |   f "one"
               ^
  Typing error: This argument has type `string` but the function expects `nat`
    File "error_apply_arg.tpe", line 11, characters 2-3:
    11 |   f "one"
           ^
    the function has type `nat → nat`
    File "error_apply_arg.tpe", line 9, characters 10-29:
    9 |   let f = id (fun n -> n + 1) in
                  ^^^^^^^^^^^^^^^^^^^
    `nat` was inferred here
    Note: while matching `nat → nat` against `string → α # ε₀`
  ======================================================================
  error_earliest_failure.tpe
  ======================================================================
  File "error_earliest_failure.tpe", lines 14-16, characters 2-25:
  14 |   unbox b as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with the unit grade `0` accumulated since it was bound, which is not below its box grade `3`
    File "error_earliest_failure.tpe", line 13, characters 13-14:
    13 |   box 3 1 as b in
                      ^
    `b` is bound here
    Note: the resource inequality `0 >= 3` does not hold
  ======================================================================
  error_handler_case.tpe
  ======================================================================
  File "error_handler_case.tpe", line 9, characters 4-20:
  9 |   | Op p k -> "done"
          ^^^^^^^^^^^^^^^^
  Typing error: The case for `Op` returns `string` but the return clause returns `nat`
    File "error_handler_case.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "error_handler_case.tpe", line 8, characters 9-10:
    8 |   | x -> 0
                 ^
    `nat` was inferred here
  ======================================================================
  error_unbox_nonvariable.tpe
  ======================================================================
  File "error_unbox_nonvariable.tpe", line 7, characters 10-12:
  7 | run unbox 42 as v in v
                ^^
  Typing error: Only a variable can be unboxed
  ======================================================================
  error_use_after_delay.tpe
  ======================================================================
  File "error_use_after_delay.tpe", line 21, characters 2-3:
  21 |   t
         ^
  Typing error: Variable `t` is used with grade `3` accumulated since it was bound, but its type `token` is not eternal
    File "error_use_after_delay.tpe", line 16, characters 6-7:
    16 |   let t = Token in
               ^
    `t` is bound here
    File "error_use_after_delay.tpe", line 17, characters 2-9:
    17 |   delay 2;
           ^^^^^^^
    grade `2` accumulates here (delay)
    File "error_use_after_delay.tpe", line 19, characters 2-17:
    19 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `1` accumulates here (operation `Ping`)
    Note: the resource inequality `3 <= 0` does not hold
  ======================================================================
  error_variant_arity.tpe
  ======================================================================
  File "error_variant_arity.tpe", line 12, characters 4-9:
  12 | run Red 1
           ^^^^^
  Typing error: Constructor `Red` takes no argument but is given one
  
  File "error_variant_arity.tpe", line 14, characters 4-8:
  14 | run Wrap
           ^^^^
  Typing error: Constructor `Wrap` takes an argument but is given none
  
  File "error_variant_arity.tpe", line 17, characters 6-11:
  17 |     | Red x -> 0
             ^^^^^
  Typing error: Constructor `Red` takes no argument but is given one
  
  File "error_variant_arity.tpe", line 21, characters 6-10:
  21 |     | Wrap -> 0
             ^^^^
  Typing error: Constructor `Wrap` takes an argument but is given none
  ======================================================================
  errors_multiple.tpe
  ======================================================================
  File "errors_multiple.tpe", line 12, characters 25-26:
  12 | let first (n : string) = n + 1
                                ^
  Typing error: This argument has type `string` but the function expects `nat`
    File "errors_multiple.tpe", line 12, characters 27-28:
    12 | let first (n : string) = n + 1
                                    ^
    the function has type `nat → nat → nat`
    Note: while matching `nat → nat → nat` against `string → α # ε₀`
  
  File "errors_multiple.tpe", line 15, characters 14-36:
  15 |   let slow () : nat # 5 = delay 3; 1 in
                     ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the effect inequality `3 >= 5` does not hold
  
  File "errors_multiple.tpe", line 18, characters 29-30:
  18 | let second n = first n + "two"
                                    ^
  Typing error: This argument has type `string` but the function expects `nat`
    File "errors_multiple.tpe", line 18, characters 15-24:
    18 | let second n = first n + "two"
                        ^^^^^^^^^
    the function has type `nat → nat`
    Note: while matching `nat → nat` against `string → α # ε₀`
  ======================================================================
  eternal_lower.tpe
  ======================================================================
  === Run 1 ===
  return (fun () ↦ return ())
  State: [
    1
  ]
  
  === Run 2 ===
  return (fun () ↦ return ())
  State: [
    2
  ]
  
  ======================================================================
  eternal_recursive.tpe
  ======================================================================
  === Run 1 ===
  return 2
  State: [
    5
  ]
  
  === Run 2 ===
  return true
  State: []
  
  ======================================================================
  eternal_recursive_reject_argument.tpe
  ======================================================================
  File "eternal_recursive_reject_argument.tpe", line 14, characters 8-9:
  14 |   match w with
               ^
  Typing error: Variable `w` is used with grade `5` accumulated since it was bound, but its type `α wrap` is not eternal
    File "eternal_recursive_reject_argument.tpe", line 12, characters 6-7:
    12 |   let w = N (W (fun () -> unbox b as x in x)) in
               ^
    `w` is bound here
    File "eternal_recursive_reject_argument.tpe", line 13, characters 2-9:
    13 |   delay 5;
           ^^^^^^^
    grade `5` accumulates here (delay)
    Note: the resource inequality `5 <= 0` does not hold
  ======================================================================
  eternal_tyvars.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: [
    1
  ]
  
  === Run 2 ===
  return Tag
  State: [
    1
  ]
  
  === Run 3 ===
  return 5
  State: [
    2
  ]
  
  === Run 4 ===
  return (fun () ↦ return ())
  State: []
  
  === Run 5 ===
  return (1, "two")
  State: [
    1
  ]
  
  === Run 6 ===
  return true
  State: [
    1,
    1
  ]
  
  === Run 7 ===
  return 6
  State: [
    { resource_1 ↦ <fun> # 1 }
  ]
  
  ======================================================================
  eternal_tyvars_reject_function.tpe
  ======================================================================
  File "eternal_tyvars_reject_function.tpe", line 10, characters 4-8:
  10 | run keep (fun () -> ())
           ^^^^
  Typing error: `unit → unit # ε₀` is not eternal, but `keep` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_function.tpe", line 6, characters 0-23:
    6 | let keep x = delay 1; x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `keep` is defined here
    File "eternal_tyvars_reject_function.tpe", line 6, characters 9-10:
    6 | let keep x = delay 1; x
                 ^
    `x` is bound here
    File "eternal_tyvars_reject_function.tpe", line 6, characters 13-20:
    6 | let keep x = delay 1; x
                     ^^^^^^^
    grade `1` accumulates here (delay)
    File "eternal_tyvars_reject_function.tpe", line 6, characters 22-23:
    6 | let keep x = delay 1; x
                              ^
    `x` is used here with grade `1` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_handler.tpe
  ======================================================================
  File "eternal_tyvars_reject_handler.tpe", line 13, characters 48-49:
  13 | run handle (perform Op (); (fun () -> ())) with h (fun () -> ())
                                                       ^
  Typing error: `unit → unit # ε₀` is not eternal, but `h` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_handler.tpe", line 10, characters 0-70:
    10 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `h` is defined here
    File "eternal_tyvars_reject_handler.tpe", line 6, characters 0-31:
    6 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "eternal_tyvars_reject_handler.tpe", line 10, characters 6-7:
    10 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
               ^
    `x` is bound here
    File "eternal_tyvars_reject_handler.tpe", line 10, characters 29-70:
    10 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` is checked with the top grade `∞` accumulated
    File "eternal_tyvars_reject_handler.tpe", line 10, characters 47-65:
    10 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                        ^^^^^^^^^^^^^^^^^^
    grade `ε₁` accumulates here (this computation)
    File "eternal_tyvars_reject_handler.tpe", line 10, characters 69-70:
    10 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                                              ^
    `x` is used here, in the case for `Op`
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_higher_order.tpe
  ======================================================================
  File "eternal_tyvars_reject_higher_order.tpe", line 10, characters 4-9:
  10 | run after (fun () -> delay 2) (fun () -> ())
           ^^^^^
  Typing error: `unit → unit # ε₀` is not eternal, but `after` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_higher_order.tpe", line 6, characters 0-23:
    6 | let after g x = g (); x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `after` is defined here
    File "eternal_tyvars_reject_higher_order.tpe", line 6, characters 12-13:
    6 | let after g x = g (); x
                    ^
    `x` is bound here
    File "eternal_tyvars_reject_higher_order.tpe", line 6, characters 16-20:
    6 | let after g x = g (); x
                        ^^^^
    grade `2` accumulates here (this computation)
    File "eternal_tyvars_reject_higher_order.tpe", line 6, characters 22-23:
    6 | let after g x = g (); x
                              ^
    `x` is used here with grade `2` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `2 <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_noneternal.tpe
  ======================================================================
  File "eternal_tyvars_reject_noneternal.tpe", line 12, characters 4-8:
  12 | run keep Token
           ^^^^
  Typing error: `token` is not eternal, but `keep` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_noneternal.tpe", line 8, characters 0-23:
    8 | let keep x = delay 1; x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `keep` is defined here
    File "eternal_tyvars_reject_noneternal.tpe", line 8, characters 9-10:
    8 | let keep x = delay 1; x
                 ^
    `x` is bound here
    File "eternal_tyvars_reject_noneternal.tpe", line 8, characters 13-20:
    8 | let keep x = delay 1; x
                     ^^^^^^^
    grade `1` accumulates here (delay)
    File "eternal_tyvars_reject_noneternal.tpe", line 8, characters 22-23:
    8 | let keep x = delay 1; x
                              ^
    `x` is used here with grade `1` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  event_separation.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    0.2,
    2,
    0.2,
    2,
    0.2,
    2
  ]
  
  === Run 2 ===
  return ()
  State: [
    0.1,
    2,
    0.1,
    2
  ]
  
  === Run 3 ===
  return ()
  State: [
    0.2,
    2,
    0.2
  ]
  
  === Run 4 ===
  return 7
  State: [
    { resource_0 ↦ 7 # [1, 3] },
    2
  ]
  
  === Run 5 ===
  return 7
  State: [
    { resource_0 ↦ 7 # (2, Beat, [0, 1]) },
    0.2,
    0.2
  ]
  
  ======================================================================
  event_separation_reject.tpe
  ======================================================================
  File "event_separation_reject.tpe", lines 18-25, characters 15-12:
  18 | let rec slow n : unit # (Beat, [0, 0], [0, 5], [0, 5]) =
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `0 ⊔ {Beat; Work; Work} · (Beat, [0, 0], [0, 5], [0, 5])`, which does not match its annotated grade `(Beat, [0, 0], [0, 5], [0, 5])`
    Note: the effect inequality `0 ⊔ {Beat; Work; Work} · (Beat, [0, 0], [0, 5], [0, 5]) <= (Beat, [0, 0], [0, 5], [0, 5])` does not hold
    Note: the grade `⟨Beat: active ([0, 0], [0, 6.5], [0, 6.5]); Work: silent [0, 0], active ([2, ∞), [0.1, 0.5], [0, ∞), [0, ∞)); _: silent [0, ∞), active ([2.1, ∞), [0, ∞), [0, ∞))⟩` is below `0 ⊔ {Beat; Work; Work} · (Beat, [0, 0], [0, 5], [0, 5])` but not below `(Beat, [0, 0], [0, 5], [0, 5])`
  
  File "event_separation_reject.tpe", lines 29-35, characters 16-13:
  29 | let rec beeps n : unit # (Beep, [2, ∞)) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `0 ⊔ {Beep; 1} · (Beep, [2, ∞))`, which does not match its annotated grade `(Beep, [2, ∞))`
    Note: the effect inequality `0 ⊔ {Beep; 1} · (Beep, [2, ∞)) <= (Beep, [2, ∞))` does not hold
    Note: the grade `⟨Beep: active ([0, 0], [1.1, ∞), [0, ∞)); _: silent [0, ∞), active ([1.1, ∞), [0, ∞), [0, ∞))⟩` is below `0 ⊔ {Beep; 1} · (Beep, [2, ∞))` but not below `(Beep, [2, ∞))`
  
  File "event_separation_reject.tpe", lines 40-46, characters 16-13:
  40 | let rec short n : unit # (Beat, [0, 5]) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `0 ⊔ {Beat; Work} · (Beat, [0, 5])`, which does not match its annotated grade `(Beat, [0, 5])`
    Note: the effect inequality `0 ⊔ {Beat; Work} · (Beat, [0, 5]) <= (Beat, [0, 5])` does not hold
    Note: the grade `⟨Beat: active ([0, 0], [0, 8.5], [0, 8.5]); Work: silent [0, 0], active ([0.1, 0.5], [0, ∞), [0, ∞)); _: silent [0, ∞), active ([1.1, ∞), [0, ∞), [0, ∞))⟩` is below `0 ⊔ {Beat; Work} · (Beat, [0, 5])` but not below `(Beat, [0, 5])`
  
  File "event_separation_reject.tpe", lines 54-55, characters 2-3:
  54 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Beat; Beat; Beat}` accumulated since it was bound, which is not below its box grade `(2, Beat, [0, 1])`
    File "event_separation_reject.tpe", line 50, characters 29-30:
    50 |   box (2, Beat, [0, 1]) 7 as x in
                                      ^
    `x` is bound here
    File "event_separation_reject.tpe", line 51, characters 2-17:
    51 |   perform Beat ();
           ^^^^^^^^^^^^^^^
    grade `{Beat}` accumulates here (operation `Beat`)
    File "event_separation_reject.tpe", line 52, characters 2-17:
    52 |   perform Beat ();
           ^^^^^^^^^^^^^^^
    grade `{Beat}` accumulates here (operation `Beat`)
    File "event_separation_reject.tpe", line 53, characters 2-17:
    53 |   perform Beat ();
           ^^^^^^^^^^^^^^^
    grade `{Beat}` accumulates here (operation `Beat`)
    Note: the resource inequality `{Beat; Beat; Beat} <= (2, Beat, [0, 1])` does not hold
  
  File "event_separation_reject.tpe", lines 61-62, characters 2-3:
  61 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Beat}` accumulated since it was bound, which is not below its box grade `(2, Beat, [0, 1])`
    File "event_separation_reject.tpe", line 59, characters 29-30:
    59 |   box (2, Beat, [0, 1]) 7 as x in
                                      ^
    `x` is bound here
    File "event_separation_reject.tpe", line 60, characters 2-17:
    60 |   perform Beat ();
           ^^^^^^^^^^^^^^^
    grade `{Beat}` accumulates here (operation `Beat`)
    Note: the resource inequality `{Beat} <= (2, Beat, [0, 1])` does not hold
  ======================================================================
  event_separation_reject_unknown.tpe
  ======================================================================
  File "event_separation_reject_unknown.tpe", line 11, characters 21-36:
  11 | let beat () : unit # (Bleat, [0, 5]) = perform Beat ()
                            ^^^^^^^^^^^^^^^
  Typing error: Unknown event `Bleat`; the events of a grade must be declared operations
  ======================================================================
  exhaustiveness.tpe
  ======================================================================
  === Run 1 ===
  return (4, 0, "many", 0)
  State: []
  
  === Run 2 ===
  return (true, 2, 4, (2, 1), 3)
  State: []
  
  === Run 3 ===
  return (Some 2, None, Some 1, Some [], (1, "a")::[])
  State: []
  
  === Run 4 ===
  return 0
  State: [
    { resource_1 ↦ <fun> # 1 },
    1
  ]
  
  === Run 5 ===
  return ()
  State: [
    1
  ]
  
  ======================================================================
  exhaustiveness_reject_bool.tpe
  ======================================================================
  File "exhaustiveness_reject_bool.tpe", lines 4-6, characters 2-18:
  4 |   match p with
        ^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `(false, false)` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  exhaustiveness_reject_constructor.tpe
  ======================================================================
  File "exhaustiveness_reject_constructor.tpe", lines 6-8, characters 2-14:
  6 |   match c with
        ^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `Blue _` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  exhaustiveness_reject_int.tpe
  ======================================================================
  File "exhaustiveness_reject_int.tpe", line 3, characters 18-56:
  3 | let f (n : int) = match n with 0i -> true | -1i -> false
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `1i` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  exhaustiveness_reject_let.tpe
  ======================================================================
  File "exhaustiveness_reject_let.tpe", line 3, characters 8-16:
  3 | run let (Some x) = Some 3 in x
              ^^^^^^^^
  Typing error: This pattern is not exhaustive: `None` is not matched
    Note: a value that the pattern does not match would stop the run
  ======================================================================
  exhaustiveness_reject_nat.tpe
  ======================================================================
  File "exhaustiveness_reject_nat.tpe", lines 4-6, characters 2-23:
  4 |   match n with
        ^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `1` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  exhaustiveness_reject_nil.tpe
  ======================================================================
  File "exhaustiveness_reject_nil.tpe", lines 4-5, characters 2-15:
  4 |   match xs with
        ^^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `[]` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  exhaustiveness_reject_parameter.tpe
  ======================================================================
  File "exhaustiveness_reject_parameter.tpe", line 3, characters 15-23:
  3 | let head = fun (x :: _) -> x
                     ^^^^^^^^
  Typing error: This pattern is not exhaustive: `[]` is not matched
    Note: a value that the pattern does not match would stop the run
  ======================================================================
  exhaustiveness_reject_string.tpe
  ======================================================================
  File "exhaustiveness_reject_string.tpe", lines 4-6, characters 2-12:
  4 |   match s with
        ^^^^^^^^^^^^
  Typing error: This match is not exhaustive: `""` is not matched
    Note: a value that no case matches would stop the run
  ======================================================================
  float_functions.tpe
  ======================================================================
  === Run 1 ===
  return (0., 3., 1e+20)
  State: []
  
  === Run 2 ===
  return 9007199254740992
  State: []
  
  === Run 3 ===
  return (1e+308, infinity)
  State: []
  
  === Run 4 ===
  return (2, 3, 0, 100000000000000000000)
  State: []
  
  === Run 5 ===
  return (0, 0, 0)
  State: []
  
  === Run 6 ===
  return 0
  State: []
  
  === Run 7 ===
  return 4294967295
  State: []
  
  === Run 8 ===
  return (2., 1.41421356237, 0., -0., nan)
  State: []
  
  === Run 9 ===
  return (infinity, nan)
  State: []
  
  === Run 10 ===
  return (0.785398163397, -0.785398163397, 1.57079632679, nan)
  State: []
  
  === Run 11 ===
  return (0.785398163397, 2.35619449019, -2.35619449019)
  State: []
  
  === Run 12 ===
  return (0., 3.14159265359, -3.14159265359)
  State: []
  
  === Run 13 ===
  return (1.57079632679, 0.785398163397, nan)
  State: []
  
  ======================================================================
  float_literals.tpe
  ======================================================================
  === Run 1 ===
  return 1.
  State: []
  
  === Run 2 ===
  return 1.
  State: []
  
  === Run 3 ===
  return -1.5
  State: []
  
  === Run 4 ===
  return -2.5
  State: []
  
  === Run 5 ===
  return 3.
  State: []
  
  === Run 6 ===
  return 0.001
  State: []
  
  === Run 7 ===
  return -2.
  State: []
  
  === Run 8 ===
  return 1
  State: []
  
  ======================================================================
  float_literals_reject_subtraction.tpe
  ======================================================================
  File "float_literals_reject_subtraction.tpe", line 4, characters 4-5:
  4 | run x-1.0
          ^
  Typing error: This argument has type `float` but the function expects `nat`
  ======================================================================
  flow_levels.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: []
  
  === Run 2 ===
  return ()
  State: []
  
  === Run 3 ===
  return ()
  State: [
    { resource_1 ↦ <fun> # (Low, (Board, Low)) }
  ]
  
  === Run 4 ===
  return 7
  State: [
    { resource_0 ↦ 7 # (High, (Board, Low)) }
  ]
  
  ======================================================================
  flow_levels_reject.tpe
  ======================================================================
  File "flow_levels_reject.tpe", lines 12-14, characters 18-16:
  12 | let post_after () : unit # (High, (Board, Low)) =
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(High, (Board, High))`, which does not match its annotated grade `(High, (Board, Low))`
    Note: the effect inequality `(High, (Board, High)) <= (High, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", lines 17-19, characters 16-15:
  17 | let unlisted () : unit # (Low, (Board, Low)) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Low, (Audit, Low), (Board, Low))`, which does not match its annotated grade `(Low, (Board, Low))`
    Note: the effect inequality `(Low, (Audit, Low), (Board, Low)) <= (Low, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", lines 26-27, characters 2-3:
  26 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(High, (Board, High))` accumulated since it was bound, which is not below its box grade `(High, (Board, Low))`
    File "flow_levels_reject.tpe", line 23, characters 32-33:
    23 |   box (High, (Board, Low)) 7 as x in
                                         ^
    `x` is bound here
    File "flow_levels_reject.tpe", line 24, characters 10-31:
    24 |   let s = perform ReadSecret () in
                   ^^^^^^^^^^^^^^^^^^^^^
    grade `High` accumulates here (operation `ReadSecret`)
    File "flow_levels_reject.tpe", line 25, characters 2-16:
    25 |   perform Post s;
           ^^^^^^^^^^^^^^
    grade `(Low, (Board, Low))` accumulates here (operation `Post`)
    Note: the resource inequality `(High, (Board, High)) <= (High, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", line 34, characters 31-49:
  34 |   | Log n k -> perform Post n; continue k with ()
                                      ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(Low, (Board, Low))` accumulated since it was bound, which is not below its box grade `(Low, (Audit, Low))`
    File "flow_levels_reject.tpe", line 34, characters 10-11:
    34 |   | Log n k -> perform Post n; continue k with ()
                   ^
    `k` is bound here
    File "flow_levels_reject.tpe", line 34, characters 15-29:
    34 |   | Log n k -> perform Post n; continue k with ()
                        ^^^^^^^^^^^^^^
    grade `(Low, (Board, Low))` accumulates here (operation `Post`)
    Note: the resource inequality `(Low, (Board, Low)) <= (Low, (Audit, Low))` does not hold
  ======================================================================
  int_division_by_zero.tpe
  ======================================================================
  Run-time error: Division by zero
  ======================================================================
  int_modulo_by_zero.tpe
  ======================================================================
  Run-time error: Modulo by zero
  ======================================================================
  int_of_float_infinity.tpe
  ======================================================================
  === Run 1 ===
  return -1i
  State: []
  
  Run-time error: Conversion of infinity to an integer
  ======================================================================
  integers.tpe
  ======================================================================
  === Run 1 ===
  return (3i, -3i, -3i, 0i, 0i, 31i, 1000i)
  State: []
  
  === Run 2 ===
  return (4i, -3i, -24i, 5i, 0i)
  State: []
  
  === Run 3 ===
  return (3i, -3i, -3i, 3i)
  State: []
  
  === Run 4 ===
  return (1i, -1i, 1i, -1i)
  State: []
  
  === Run 5 ===
  return (7i, 3i, 6i)
  State: []
  
  === Run 6 ===
  return (true, true, false, -1i, 0i, -1i)
  State: []
  
  === Run 7 ===
  return (Some -3i, -1i::0i::1i::[], "-12i")
  State: []
  
  === Run 8 ===
  return (0i, 5i, 5, 0, 0)
  State: []
  
  === Run 9 ===
  return (-3., 0., 1e+23)
  State: []
  
  === Run 10 ===
  return (2i, -2i, 0i)
  State: []
  
  === Run 11 ===
  return (100000000000000000000i, -100000000000000000000i, 0i)
  State: []
  
  === Run 12 ===
  return (18446744073709551616i, 2147483648i, 0i)
  State: []
  
  ======================================================================
  invalid_match_type.tpe
  ======================================================================
  File "invalid_match_type.tpe", line 6, characters 6-7:
  6 |     | B -> ()
            ^
  Typing error: This pattern matches values of type `b` but the matched value has type `a list`
    File "invalid_match_type.tpe", line 5, characters 8-9:
    5 |   match a with
                ^
    the matched value has type `a list`
    File "invalid_match_type.tpe", line 4, characters 12-15:
    4 | run let a = [A] in
                    ^^^
    `a list` was inferred here
  ======================================================================
  iterative_unbox.tpe
  ======================================================================
  File "iterative_unbox.tpe", line 7, characters 30-57:
  7 |   fold_left (fun acc value -> unbox value as v in acc + v) 0 boxed
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `value` is unboxed with the unit grade `0` accumulated since it was bound, which is not below its box grade `3`
    File "iterative_unbox.tpe", line 7, characters 21-26:
    7 |   fold_left (fun acc value -> unbox value as v in acc + v) 0 boxed
                             ^^^^^
    `value` is bound here
    File "iterative_unbox.tpe", line 7, characters 2-11:
    7 |   fold_left (fun acc value -> unbox value as v in acc + v) 0 boxed
          ^^^^^^^^^
    the inequality goes through the type of `fold_left` here
    File "iterative_unbox.tpe", line 5, characters 14-26:
    5 |   let boxed = box_n_values 5 [] in 
                      ^^^^^^^^^^^^
    the inequality goes through the type of `box_n_values` here
    Note: the resource inequality `0 >= 3` does not hold
  ======================================================================
  less_than_function.tpe
  ======================================================================
  File "less_than_function.tpe", line 1, characters 17-18:
  1 | run (fun x -> x) < (fun x -> 2 * x)
                       ^
  Typing error: Type `α → β # ε₀` is not eternal, as required by the type of `(<)`
    File "stdlib.tpe", line 2, characters 0-37:
    2 | let ( < ) x y = __compare_lt__ (x, y)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `(<)` is defined here
  ======================================================================
  levels.tpe
  ======================================================================
  === Run 1 ===
  return ("public", "report")
  State: [
    { resource_0 ↦ "public" # Low }
  ]
  
  === Run 2 ===
  return "secret"
  State: [
    { resource_0 ↦ "secret" # High }
  ]
  
  === Run 3 ===
  return "public"
  State: [
    { resource_0 ↦ "public" # Low }
  ]
  
  ======================================================================
  levels_reject.tpe
  ======================================================================
  File "levels_reject.tpe", lines 15-16, characters 2-3:
  15 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `High` accumulated since it was bound, which is not below its box grade `Low`
    File "levels_reject.tpe", line 13, characters 22-23:
    13 |   box Low "public" as r in
                               ^
    `r` is bound here
    File "levels_reject.tpe", line 14, characters 2-23:
    14 |   perform Send "secret";
           ^^^^^^^^^^^^^^^^^^^^^
    grade `High` accumulates here (operation `Send`)
    Note: the resource inequality `High <= Low` does not hold
  ======================================================================
  levels_reject_literal.tpe
  ======================================================================
  File "levels_reject_literal.tpe", line 7, characters 19-20:
  7 | let claim () = box 3 1
                         ^
  Syntax error: In the `security-levels` grading monoid, grades are the levels `Low` and `High`, not plain integers; did you mean to use one of the `time-lower-bound`, `time-upper-bound`, `time-lower-bound-rational`, `time-upper-bound-rational`, `traces-upper-bound`, `traces-upper-bound-rational`, `traces-timed-lower-bound`, `traces-timed-upper-bound`, `traces-timed-interval`, `traces-timed-lower-bound-rational`, `traces-timed-upper-bound-rational`, `traces-timed-interval-rational`, `regex-upper-bound-symbolic`, `regex-upper-bound-rational-symbolic`, `regex-timed-lower-bound-symbolic`, `regex-timed-upper-bound-symbolic`, `regex-timed-interval-symbolic`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `windowed-schedules`, `mode-switch-costs`, `mode-times`, `counts-upper-bound` or `event-separation` grading monoids?
  ======================================================================
  levels_time_lower.tpe
  ======================================================================
  === Run 1 ===
  return "report"
  State: [
    { resource_0 ↦ "report" # (3, Low) },
    (3, Low)
  ]
  
  === Run 2 ===
  return ("report", "figures")
  State: [
    { resource_0 ↦ "report" # (3, Low) },
    (2, Low),
    (1, Low)
  ]
  
  === Run 3 ===
  return "report"
  State: [
    { resource_0 ↦ "report" # (3, High) },
    (1, Low),
    (2, Low)
  ]
  
  === Run 4 ===
  return "report"
  State: [
    { resource_0 ↦ "report" # (0, High) },
    (1, Low)
  ]
  
  ======================================================================
  levels_time_lower_reject.tpe
  ======================================================================
  File "levels_time_lower_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `(2, Low)` accumulated since it was bound, which is not below its box grade `(3, Low)`
    File "levels_time_lower_reject.tpe", line 15, characters 27-28:
    15 |   box (3, Low) "report" as r in
                                    ^
    `r` is bound here
    File "levels_time_lower_reject.tpe", line 16, characters 2-9:
    16 |   delay 2;
           ^^^^^^^
    grade `(2, Low)` accumulates here (delay)
    Note: the resource inequality `(2, Low) ≾ (3, Low)` does not hold
  
  File "levels_time_lower_reject.tpe", lines 25-26, characters 2-3:
  25 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `(3, High)` accumulated since it was bound, which is not below its box grade `(3, Low)`
    File "levels_time_lower_reject.tpe", line 22, characters 27-28:
    22 |   box (3, Low) "report" as r in
                                    ^
    `r` is bound here
    File "levels_time_lower_reject.tpe", line 23, characters 2-24:
    23 |   perform Publish "news";
           ^^^^^^^^^^^^^^^^^^^^^^
    grade `(1, High)` accumulates here (operation `Publish`)
    File "levels_time_lower_reject.tpe", line 24, characters 2-9:
    24 |   delay 2;
           ^^^^^^^
    grade `(2, Low)` accumulates here (delay)
    Note: the resource inequality `(3, High) ≾ (3, Low)` does not hold
  ======================================================================
  levels_time_upper.tpe
  ======================================================================
  === Run 1 ===
  return "token"
  State: [
    { resource_0 ↦ "token" # (5, Low) },
    (1, Low),
    (1, Low),
    (2, Low)
  ]
  
  === Run 2 ===
  return "token"
  State: [
    { resource_0 ↦ "token" # (5, High) },
    (1, Low)
  ]
  
  === Run 3 ===
  return "token"
  State: [
    { resource_0 ↦ "token" # (∞, Low) },
    (100, Low)
  ]
  
  ======================================================================
  levels_time_upper_reject.tpe
  ======================================================================
  File "levels_time_upper_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox c as t in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `(6, Low)` accumulated since it was bound, which is not below its box grade `(5, Low)`
    File "levels_time_upper_reject.tpe", line 15, characters 26-27:
    15 |   box (5, Low) "token" as c in
                                   ^
    `c` is bound here
    File "levels_time_upper_reject.tpe", line 16, characters 2-9:
    16 |   delay 6;
           ^^^^^^^
    grade `(6, Low)` accumulates here (delay)
    Note: the resource inequality `(6, Low) <= (5, Low)` does not hold
  
  File "levels_time_upper_reject.tpe", lines 24-25, characters 2-3:
  24 |   unbox c as t in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `(1, High)` accumulated since it was bound, which is not below its box grade `(5, Low)`
    File "levels_time_upper_reject.tpe", line 22, characters 26-27:
    22 |   box (5, Low) "token" as c in
                                   ^
    `c` is bound here
    File "levels_time_upper_reject.tpe", line 23, characters 2-23:
    23 |   perform Leak "secret";
           ^^^^^^^^^^^^^^^^^^^^^
    grade `(1, High)` accumulates here (operation `Leak`)
    Note: the resource inequality `(1, High) <= (5, Low)` does not hold
  ======================================================================
  lexer.tpe
  ======================================================================
  === Run 1 ===
  return 10
  State: []
  
  === Run 2 ===
  return 20
  State: []
  
  === Run 3 ===
  return 30
  State: []
  
  === Run 4 ===
  return 40
  State: []
  
  === Run 5 ===
  return 42
  State: []
  
  === Run 6 ===
  return 42
  State: []
  
  === Run 7 ===
  return 42
  State: []
  
  === Run 8 ===
  return 11259375
  State: []
  
  === Run 9 ===
  return 11259375
  State: []
  
  === Run 10 ===
  return 32072
  State: []
  
  === Run 11 ===
  return 32072
  State: []
  
  === Run 12 ===
  return 3.141592
  State: []
  
  === Run 13 ===
  return 4.141592
  State: []
  
  === Run 14 ===
  return -5.1592
  State: []
  
  === Run 15 ===
  return 6.1592
  State: []
  
  === Run 16 ===
  return -3.14
  State: []
  
  ======================================================================
  lexer_reject_unknown_character.tpe
  ======================================================================
  File "lexer_reject_unknown_character.tpe", line 3, characters 7-9:
  3 | let café = 1
             ^
  Syntax error: Unexpected character `é`
  ======================================================================
  list_constructor_reject.tpe
  ======================================================================
  File "list_constructor_reject.tpe", line 3, characters 23-33:
  3 | let f l = match l with x :: n + 1 -> x | _ -> 0
                             ^^^^^^^^^^
  Typing error: Constructor `::` expects an argument of type `nat` but is given `α list`
  ======================================================================
  literals_rational_interval.tpe
  ======================================================================
  === Run 1 ===
  return "o"
  State: [
    { resource_0 ↦ "o" # [1/3, ∞) },
    [1/3, 1/3]
  ]
  
  === Run 2 ===
  return "c"
  State: [
    { resource_0 ↦ "c" # [0.25, 2] },
    [1.75, 1.75]
  ]
  
  === Run 3 ===
  return "q"
  State: [
    { resource_0 ↦ "q" # [0.5, 4/3] },
    [2/3, 2/3]
  ]
  
  === Run 4 ===
  return "p"
  State: [
    { resource_0 ↦ "p" # (0, 1) },
    [0.999, 0.999]
  ]
  
  === Run 5 ===
  return "b"
  State: [
    { resource_0 ↦ "b" # (0.5, 1.5] },
    [1.5, 1.5]
  ]
  
  === Run 6 ===
  return "a"
  State: [
    { resource_0 ↦ "a" # [0, 0.5) },
    [0.25, 0.25]
  ]
  
  === Run 7 ===
  return "l"
  State: [
    { resource_0 ↦ "l" # (1/3, ∞) },
    [1/3, 1/3],
    [0.01, 0.01]
  ]
  
  === Run 8 ===
  return ()
  State: [
    [0.5, 0.5]
  ]
  
  ======================================================================
  literals_rational_upper.tpe
  ======================================================================
  === Run 1 ===
  return "q"
  State: [
    { resource_0 ↦ "q" # 1.5 },
    1.5
  ]
  
  === Run 2 ===
  return "d"
  State: [
    { resource_0 ↦ "d" # 1.5 },
    1.5
  ]
  
  === Run 3 ===
  return "e"
  State: [
    { resource_0 ↦ "e" # 0.125 },
    0.125
  ]
  
  === Run 4 ===
  return "w"
  State: [
    { resource_0 ↦ "w" # 2 },
    2
  ]
  
  === Run 5 ===
  return ()
  State: [
    0.25,
    0.125
  ]
  
  ======================================================================
  literals_regular.tpe
  ======================================================================
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Send | Read*} }
  ]
  
  === Run 2 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 3 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 4 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {_} }
  ]
  
  === Run 5 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 3; (Send | Write)*} }
  ]
  
  === Run 6 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(Send; 2)*} }
  ]
  
  === Run 7 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(_ & ~Revoke)*} }
  ]
  
  === Run 8 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Open; (Read | Write)*; Close} }
  ]
  
  === Run 9 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3 | 2*} }
  ]
  
  === Run 10 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3} }
  ]
  
  === Run 11 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {0} }
  ]
  
  === Run 12 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 1; (0 | 1; (0 | 1)); Send} }
  ]
  
  === Run 13 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; (0 | 1); Send} }
  ]
  
  === Run 14 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; 1*} }
  ]
  
  === Run 15 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {2; (0 | 1; (0 | 1))} }
  ]
  
  === Run 16 ===
  return 0
  State: [
    { resource_0 ↦ 1 # ⊤ }
  ]
  
  ======================================================================
  literals_reject_complement.tpe
  ======================================================================
  File "literals_reject_complement.tpe", line 9, characters 19-32:
  9 | let claim () = box {Send; ~Read} 1
                         ^^^^^^^^^^^^^
  Syntax error: In the `traces-timed-upper-bound` grading monoid, sets of traces are built from operation names and delays with `;` and `|` only, without complement `~`; did you mean to use one of the `regex-upper-bound-symbolic`, `regex-upper-bound-rational-symbolic`, `regex-timed-lower-bound-symbolic`, `regex-timed-upper-bound-symbolic`, `regex-timed-interval-symbolic`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic` or `regex-timed-interval-rational-symbolic` grading monoids?
  ======================================================================
  literals_reject_component.tpe
  ======================================================================
  File "literals_reject_component.tpe", line 8, characters 19-30:
  8 | let claim () = box (3, Medium) 1
                         ^^^^^^^^^^^
  Syntax error: In the `time-lower-bound-levels` grading monoid, in the second component (`security-levels`), unknown level `Medium`; the levels are `Low` and `High`
  ======================================================================
  literals_reject_counts.tpe
  ======================================================================
  File "literals_reject_counts.tpe", line 7, characters 19-29:
  7 | let claim () = box (Send, -1) 1
                         ^^^^^^^^^^
  Syntax error: In the `counts-upper-bound` grading monoid, in the entry of `Send`, grades must be non-negative
  ======================================================================
  literals_reject_empty.tpe
  ======================================================================
  File "literals_reject_empty.tpe", line 9, characters 19-33:
  9 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: In the `regex-upper-bound-symbolic` grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_reject_event_separation.tpe
  ======================================================================
  File "literals_reject_event_separation.tpe", line 11, characters 21-43:
  11 | let beat () : unit # (Beat, [0, 1], [0, 5]) = perform Beat ()
                            ^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: In the `event-separation` grading monoid, an entry `(X, ...)` lists one interval, the gaps, or three, the lead, the gaps and the tail
  ======================================================================
  literals_reject_flow.tpe
  ======================================================================
  File "literals_reject_flow.tpe", line 7, characters 19-54:
  7 | let claim () = box (High, (Board, Low), (Board, High)) 1
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: In the `flow-levels` grading monoid, the output `Board` is listed twice
  ======================================================================
  literals_reject_fraction.tpe
  ======================================================================
  File "literals_reject_fraction.tpe", line 8, characters 19-22:
  8 | let claim () = box 3/2 1
                         ^^^
  Syntax error: In the `time-upper-bound` grading monoid, grades are plain integers or `∞`, not fractions such as `3/2`; did you mean to use one of the `time-lower-bound-rational`, `time-upper-bound-rational`, `traces-upper-bound-rational`, `traces-timed-lower-bound-rational`, `traces-timed-upper-bound-rational`, `traces-timed-interval-rational`, `regex-upper-bound-rational-symbolic`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `mode-times` or `event-separation` grading monoids?
  ======================================================================
  literals_reject_fraction_operator.tpe
  ======================================================================
  File "literals_reject_fraction_operator.tpe", line 3, characters 20-21:
  3 | let claim () = box 3%2 1
                          ^
  Syntax error: Unknown operator `%` in a fraction
  ======================================================================
  literals_reject_fraction_zero.tpe
  ======================================================================
  File "literals_reject_fraction_zero.tpe", line 3, characters 21-22:
  3 | let claim () = box 1/0 1
                           ^
  Syntax error: Fractions have positive denominators
  ======================================================================
  literals_reject_inf.tpe
  ======================================================================
  File "literals_reject_inf.tpe", line 3, characters 19-22:
  3 | let claim () = box ∞ 1
                         ^
  Syntax error: In the `time-lower-bound` grading monoid, grades are plain integers, not `∞`; did you mean to use one of the `time-upper-bound`, `time-upper-bound-rational`, `mode-switch-costs` or `counts-upper-bound` grading monoids?
  ======================================================================
  literals_reject_interval_closed_infinity.tpe
  ======================================================================
  File "literals_reject_interval_closed_infinity.tpe", line 9, characters 19-27:
  9 | let claim () = box [2, ∞] 1
                         ^^^^^^
  Syntax error: An infinite endpoint of an interval is written with a parenthesis, as in `[n, ∞)`
  ======================================================================
  literals_reject_interval_empty.tpe
  ======================================================================
  File "literals_reject_interval_empty.tpe", line 8, characters 19-25:
  8 | let claim () = box [2, 2) 1
                         ^^^^^^
  Syntax error: In the `time-interval` grading monoid, interval endpoints must satisfy n < m at an open endpoint
  ======================================================================
  literals_reject_interval_no_step.tpe
  ======================================================================
  File "literals_reject_interval_no_step.tpe", line 8, characters 19-25:
  8 | let claim () = box (1, 2) 1
                         ^^^^^^
  Syntax error: In the `time-interval` grading monoid, the interval contains no integer; did you mean to use one of the `time-interval-rational`, `regex-timed-interval-rational-symbolic`, `resource-levels` or `event-separation` grading monoids?
  ======================================================================
  literals_reject_interval_reversed.tpe
  ======================================================================
  File "literals_reject_interval_reversed.tpe", line 8, characters 19-25:
  8 | let claim () = box [5, 2] 1
                         ^^^^^^
  Syntax error: In the `time-interval` grading monoid, interval endpoints must satisfy n <= m
  ======================================================================
  literals_reject_large.tpe
  ======================================================================
  File "literals_reject_large.tpe", line 3, characters 19-39:
  3 | let claim () = box 99999999999999999999 1
                         ^^^^^^^^^^^^^^^^^^^^
  Syntax error: Grade literal 99999999999999999999 is too large
  ======================================================================
  literals_reject_mode_times.tpe
  ======================================================================
  File "literals_reject_mode_times.tpe", line 7, characters 19-31:
  7 | let claim () = box (On, Off, 0) 1
                         ^^^^^^^^^^^^
  Syntax error: In the `mode-times` grading monoid, in the entry from `On` to `Off`, a change of mode takes a positive time
  ======================================================================
  literals_reject_mode_times_bound.tpe
  ======================================================================
  File "literals_reject_mode_times_bound.tpe", line 7, characters 19-57:
  7 | let claim () = box (Cold, Cold, (Out, [40, 50]), [0, 30]) 1
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: In the `mode-times` grading monoid, in the entry from `Cold` to `Cold`, the time in `Out` exceeds the total time
  ======================================================================
  literals_reject_mode_times_operation.tpe
  ======================================================================
  File "literals_reject_mode_times_operation.tpe", line 7, characters 33-61:
  7 | operation Round : unit ~> unit # ({Take; Return}, Cold, Cold) within [2, 3]
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: In the `mode-times` grading monoid, an operation is written `{X}` of a single operation `X`, not `{Take; Return}`
  ======================================================================
  literals_reject_modes.tpe
  ======================================================================
  File "literals_reject_modes.tpe", line 7, characters 19-31:
  7 | let claim () = box (On, Off, 0) 1
                         ^^^^^^^^^^^^
  Syntax error: In the `mode-switch-costs` grading monoid, in the cost from `On` to `Off`, a change of mode costs at least 1
  ======================================================================
  literals_reject_name.tpe
  ======================================================================
  File "literals_reject_name.tpe", line 3, characters 19-22:
  3 | let claim () = box Low 1
                         ^^^
  Syntax error: In the `time-lower-bound` grading monoid, grades are plain integers, not names such as `Low`; did you mean to use one of the `security-levels` or `flow-levels` grading monoids?
  ======================================================================
  literals_reject_negative.tpe
  ======================================================================
  File "literals_reject_negative.tpe", line 3, characters 19-21:
  3 | let claim () = box -1 1
                         ^^
  Syntax error: In the `time-lower-bound` grading monoid, grades must be non-negative
  ======================================================================
  literals_reject_peak.tpe
  ======================================================================
  File "literals_reject_peak.tpe", line 7, characters 19-25:
  7 | let claim () = box (2, 1) 1
                         ^^^^^^
  Syntax error: In the `resource-levels` grading monoid, the peak must be at least 0 and at least the net change
  ======================================================================
  literals_reject_rational_negative.tpe
  ======================================================================
  File "literals_reject_rational_negative.tpe", line 8, characters 19-23:
  8 | let claim () = box -0.5 1
                         ^^^^
  Syntax error: In the `time-upper-bound-rational` grading monoid, grades must be non-negative
  ======================================================================
  literals_reject_resource_levels_range_empty.tpe
  ======================================================================
  File "literals_reject_resource_levels_range_empty.tpe", line 8, characters 19-30:
  8 | let claim () = box ((0, 1), 1) 1
                         ^^^^^^^^^^^
  Syntax error: In the `resource-levels` grading monoid, in the net change, the interval contains no integer
  ======================================================================
  literals_reject_star.tpe
  ======================================================================
  File "literals_reject_star.tpe", line 7, characters 19-31:
  7 | let claim () = box {(Send; 2)*} 1
                         ^^^^^^^^^^^^
  Syntax error: In the `traces-timed-upper-bound` grading monoid, sets of traces are built from operation names and delays with `;` and `|` only, without repetition `*`; did you mean to use one of the `regex-upper-bound-symbolic`, `regex-upper-bound-rational-symbolic`, `regex-timed-lower-bound-symbolic`, `regex-timed-upper-bound-symbolic`, `regex-timed-interval-symbolic`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic` or `regex-timed-interval-rational-symbolic` grading monoids?
  ======================================================================
  literals_reject_unknown.tpe
  ======================================================================
  File "literals_reject_unknown.tpe", line 3, characters 19-26:
  3 | let claim () = box forever 1
                         ^^^^^^^
  Syntax error: `forever` is no grade literal; grades are written as integers, fractions such as `3/2` or `1.5`, names such as `High`, `⊤` (ASCII `top`), `∞` (ASCII `inf`), tuples `(...)`, intervals `[...]` and brace literals `{...}`
  ======================================================================
  literals_reject_windowed_schedules.tpe
  ======================================================================
  File "literals_reject_windowed_schedules.tpe", line 8, characters 19-27:
  8 | let claim () = box (1, {0}) 1
                         ^^^^^^^^
  Syntax error: In the `windowed-schedules` grading monoid, times are given by operation, e.g. `(1, (Send, {0}))` for `Send` at the start, or `(1, (_, {0}))` for any operation
  ======================================================================
  literals_reject_windowed_schedules_empty.tpe
  ======================================================================
  File "literals_reject_windowed_schedules_empty.tpe", line 9, characters 19-25:
  9 | let claim () = box (2, 3) 1
                         ^^^^^^
  Syntax error: In the `windowed-schedules` grading monoid, the interval contains no integer; did you mean to use one of the `time-interval-rational`, `regex-timed-interval-rational-symbolic`, `resource-levels` or `event-separation` grading monoids?
  ======================================================================
  literals_reject_within_empty.tpe
  ======================================================================
  File "literals_reject_within_empty.tpe", line 9, characters 46-52:
  9 | operation Send : unit ~> unit # {Send} within [2, 2)
                                                    ^^^^^^
  Syntax error: Interval endpoints must satisfy n < m at an open endpoint
  ======================================================================
  literals_reject_within_no_step.tpe
  ======================================================================
  File "literals_reject_within_no_step.tpe", line 9, characters 46-52:
  9 | operation Send : unit ~> unit # {Send} within (1, 2)
                                                    ^^^^^^
  Syntax error: In the `traces-timed-upper-bound` grading monoid, the interval `(1, 2)` contains no whole number of time steps
  ======================================================================
  literals_time_interval.tpe
  ======================================================================
  === Run 1 ===
  return "open-ended"
  State: [
    { resource_0 ↦ "open-ended" # [3, ∞) },
    [100, 100]
  ]
  
  === Run 2 ===
  return "open-ended"
  State: [
    { resource_0 ↦ "open-ended" # [3, ∞) },
    [3, 3]
  ]
  
  === Run 3 ===
  return "any time"
  State: [
    { resource_0 ↦ "any time" # [0, ∞) },
    [5, 5]
  ]
  
  === Run 4 ===
  return ()
  State: [
    [7, 7]
  ]
  
  === Run 5 ===
  return (3::[])
  State: [
    { resource_0 ↦ 3::4::[] # [1, 2] },
    [1, 1]
  ]
  
  === Run 6 ===
  return 5
  State: [
    { resource_0 ↦ 5 # [1, ∞) },
    [2, 2]
  ]
  
  === Run 7 ===
  return "open"
  State: [
    { resource_0 ↦ "open" # [2, 4] },
    [4, 4]
  ]
  
  === Run 8 ===
  return "half"
  State: [
    { resource_0 ↦ "half" # [2, 4] },
    [2, 2]
  ]
  
  === Run 9 ===
  return "below"
  State: [
    { resource_0 ↦ "below" # [3, 5] },
    [5, 5]
  ]
  
  === Run 10 ===
  return "late"
  State: [
    { resource_0 ↦ "late" # [3, ∞) },
    [3, 3]
  ]
  
  === Run 11 ===
  return 6
  State: [
    { resource_0 ↦ 6 # [1, 2] },
    [1, 1]
  ]
  
  ======================================================================
  literals_time_lower.tpe
  ======================================================================
  === Run 1 ===
  return "now"
  State: [
    { resource_0 ↦ "now" # 0 }
  ]
  
  === Run 2 ===
  return "now"
  State: [
    { resource_0 ↦ "now" # 0 }
  ]
  
  === Run 3 ===
  return "boxed"
  State: [
    { resource_0 ↦ "boxed" # 0 }
  ]
  
  ======================================================================
  literals_time_upper.tpe
  ======================================================================
  === Run 1 ===
  return "forever"
  State: [
    { resource_0 ↦ "forever" # ∞ },
    100
  ]
  
  === Run 2 ===
  return "forever"
  State: [
    { resource_0 ↦ "forever" # ∞ },
    100
  ]
  
  === Run 3 ===
  return "forever"
  State: [
    { resource_0 ↦ "forever" # ∞ },
    100
  ]
  
  === Run 4 ===
  return ()
  State: [
    7
  ]
  
  ======================================================================
  literals_traces.tpe
  ======================================================================
  === Run 1 ===
  return "any run"
  State: [
    { resource_0 ↦ "any run" # [{0}, ∞) },
    [{1}, {1}],
    [{3}, {3}]
  ]
  
  === Run 2 ===
  return "after a send"
  State: [
    { resource_0 ↦ "after a send" # [{Send}, ∞) },
    [{1}, {1}],
    [{1}, {1}]
  ]
  
  === Run 3 ===
  return "a send or a wait"
  State: [
    { resource_0 ↦ "a send or a wait" # [{1}, {Send; 1 | 3}] },
    [{1}, {1}],
    [{1}, {1}]
  ]
  
  ======================================================================
  malformed_type_application.tpe
  ======================================================================
  File "malformed_type_application.tpe", line 4, characters 0-25:
  4 | type bar = (nat, nat) foo
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `foo` expects 1 argument but is given 2
  ======================================================================
  mode_switch_costs.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: []
  
  ======================================================================
  mode_switch_costs_reject.tpe
  ======================================================================
  File "mode_switch_costs_reject.tpe", line 13, characters 14-52:
  13 | let tx_off () : unit # (Off, Off, 2) = perform Tx ()
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(On, On, 2)`, which does not match its annotated grade `(Off, Off, 2)`
    Note: the effect inequality `(On, On, 2) <= (Off, Off, 2)` does not hold
  
  File "mode_switch_costs_reject.tpe", lines 16-20, characters 11-16:
  16 | let two () : unit # (Off, Off, 4) =
                  ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Off, Off, 6)`, which does not match its annotated grade `(Off, Off, 4)`
    Note: the effect inequality `(Off, Off, 6) <= (Off, Off, 4)` does not hold
  
  File "mode_switch_costs_reject.tpe", lines 23-24, characters 17-46:
  23 | let idle_or_tx b : unit # ((On, On, 2), (Off, Off, 1)) =
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `((On, On, 2), (_, _, 1), (_, Stuck, 0))`, which does not match its annotated grade `((Off, Off, 1), (On, On, 2))`
    Note: the effect inequality `((On, On, 2), (_, _, 1), (_, Stuck, 0)) <= ((Off, Off, 1), (On, On, 2))` does not hold
  
  File "mode_switch_costs_reject.tpe", line 32, characters 15-33:
  32 |   | Tx () k -> continue k with ()
                      ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `0` accumulated since it was bound, which is not below its box grade `(On, On, 2)`
    File "mode_switch_costs_reject.tpe", line 32, characters 10-11:
    32 |   | Tx () k -> continue k with ()
                   ^
    `k` is bound here
    Note: the resource inequality `0 <= (On, On, 2)` does not hold
  
  File "mode_switch_costs_reject.tpe", line 35, characters 0-18:
  35 | default On () = ()
       ^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `On` has grade `0`, which does not match the declared grade `(Off, On, 1)` of `On`
    File "mode_switch_costs_reject.tpe", line 7, characters 0-42:
    7 | operation On : unit ~> unit # (Off, On, 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `On` is declared here
    Note: the effect inequality `0 <= (Off, On, 1)` does not hold
  ======================================================================
  mode_times.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    1,
    4,
    4,
    1,
    1,
    4,
    4,
    1,
    1,
    4,
    4,
    1
  ]
  
  ======================================================================
  mode_times_reject.tpe
  ======================================================================
  File "mode_times_reject.tpe", line 19, characters 2-7:
  19 |   round ();
         ^^^^^
  Typing error: The effect inequality `(Cold, Cold, (Cold, [1, 2]), (Out, [8, 10])) · (Cold, Cold, (Cold, [1, 2]), (Out, [8, 10])) · (Cold, Cold, (Cold, [1, 2]), (Out, [8, 10])) · (Cold, Cold, (Cold, [1, 2]), (Out, [8, 10])) <= (Cold, Cold, (Out, [0, 30]))` does not hold
    File "mode_times_reject.tpe", lines 11-15, characters 0-19:
    11 | let round () : unit # (Cold, Cold, (Cold, [1, 2]), (Out, [8, 10])) =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `round` is defined here
    File "mode_times_reject.tpe", lines 18-22, characters 14-10:
    18 | let rounds () : unit # (Cold, Cold, (Out, [0, 30])) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  
  File "mode_times_reject.tpe", line 25, characters 20-62:
  25 | let cold_pipette () : unit # (Cold, Cold) = perform Pipette ()
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `({Pipette}, Out, Out)`, which does not match its annotated grade `(Cold, Cold)`
    Note: the effect inequality `({Pipette}, Out, Out) <= (Cold, Cold)` does not hold
  
  File "mode_times_reject.tpe", line 29, characters 12-61:
  29 | let take () : unit # (Cold, Out, (Cold, 0)) = perform Take ()
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `({Take}, Cold, Out)`, which does not match its annotated grade `(Cold, Out, (Cold, 0))`
    Note: the effect inequality `({Take}, Cold, Out) <= (Cold, Out, (Cold, 0))` does not hold
  
  File "mode_times_reject.tpe", lines 32-34, characters 12-19:
  32 | let late () : unit # (Out, Cold, (Out, [0, 1])) =
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `5 · ({Return}, Out, Cold)`, which does not match its annotated grade `(Out, Cold, (Out, [0, 1]))`
    Note: the effect inequality `5 · ({Return}, Out, Cold) <= (Out, Cold, (Out, [0, 1]))` does not hold
  ======================================================================
  nat_division_by_zero.tpe
  ======================================================================
  Run-time error: Division by zero
  ======================================================================
  nat_large_literals.tpe
  ======================================================================
  === Run 1 ===
  return 99999999999999999999
  State: []
  
  === Run 2 ===
  return 18446744073709551615
  State: []
  
  === Run 3 ===
  return 99999999999999999998
  State: []
  
  === Run 4 ===
  return 18446744073709551616
  State: []
  
  ======================================================================
  nat_of_float_infinity.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: []
  
  Run-time error: Conversion of infinity to a natural number
  ======================================================================
  nat_reject_negative.tpe
  ======================================================================
  File "nat_reject_negative.tpe", line 3, characters 4-18:
  3 | run -1_000_000_000
          ^^^^^^^^^^^^^^
  Syntax error: Natural numbers have no negation; floats are negated with `-.` and integers with `~-!`
  ======================================================================
  nat_reject_successor_pattern.tpe
  ======================================================================
  File "nat_reject_successor_pattern.tpe", line 3, characters 21-26:
  3 | run match "one" with m + 1 -> m | _ -> 0
                           ^^^^^
  Typing error: This pattern matches values of type `nat` but the matched value has type `string`
    File "nat_reject_successor_pattern.tpe", line 3, characters 14-15:
    3 | run match "one" with m + 1 -> m | _ -> 0
                      ^
    the matched value has type `string`
  
  File "nat_reject_successor_pattern.tpe", line 5, characters 17-23:
  5 | run match 3 with (a, b) + 1 -> a | _ -> 0
                       ^^^^^^
  Typing error: This pattern matches values of type `α × β` but, as the argument of a successor pattern, is given values of type `nat`
  ======================================================================
  nat_reject_successor_zero.tpe
  ======================================================================
  File "nat_reject_successor_zero.tpe", line 3, characters 21-22:
  3 | run match 3 with m + 0 -> m
                           ^
  Syntax error: The number added in a successor pattern must be positive
  ======================================================================
  nat_successor_patterns.tpe
  ======================================================================
  === Run 1 ===
  return 3628800
  State: []
  
  === Run 2 ===
  return 610
  State: []
  
  === Run 3 ===
  return (true, false)
  State: []
  
  === Run 4 ===
  return (1::2::3::[])
  State: []
  
  === Run 5 ===
  return (3, 0::[])
  State: []
  
  === Run 6 ===
  return 3
  State: []
  
  === Run 7 ===
  return 2
  State: []
  
  === Run 8 ===
  return 7
  State: []
  
  === Run 9 ===
  return (2, 1)
  State: []
  
  === Run 10 ===
  return 99999999999999999998
  State: []
  
  === Run 11 ===
  return 1
  State: []
  
  ======================================================================
  non_linear_pattern.tpe
  ======================================================================
  File "non_linear_pattern.tpe", line 3, characters 8-13:
  3 | run let (a,a) = (10, 20) in a
              ^^^^^
  Syntax error: Variable `a` defined multiple times
  ======================================================================
  noneternal_lower.tpe
  ======================================================================
  === Run 1 ===
  return Token
  State: [
    1
  ]
  
  ======================================================================
  noneternal_reject_after_delay.tpe
  ======================================================================
  File "noneternal_reject_after_delay.tpe", line 14, characters 2-3:
  14 |   t
         ^
  Typing error: Variable `t` is used with grade `1` accumulated since it was bound, but its type `token` is not eternal
    File "noneternal_reject_after_delay.tpe", line 12, characters 6-7:
    12 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_after_delay.tpe", line 13, characters 2-9:
    13 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  noneternal_reject_alias.tpe
  ======================================================================
  File "noneternal_reject_alias.tpe", line 9, characters 0-29:
  9 | noneternal type seconds = nat
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `seconds` is an alias and cannot be declared noneternal; wrap it in a constructor, as in `noneternal type seconds = Seconds of ...`
  ======================================================================
  noneternal_reject_unknown_grade.tpe
  ======================================================================
  File "noneternal_reject_unknown_grade.tpe", line 22, characters 2-3:
  22 |   t
         ^
  Typing error: Variable `t` is used with grade `1` accumulated since it was bound, but its type `token` is not eternal
    File "noneternal_reject_unknown_grade.tpe", line 19, characters 6-7:
    19 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_unknown_grade.tpe", line 21, characters 2-9:
    21 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `1 <= 0` does not hold
  
  File "noneternal_reject_unknown_grade.tpe", line 35, characters 19-23:
  35 | let hold_token g = hold g Token
                          ^^^^
  Typing error: `token` is not eternal, but `hold` needs the type of `y` to be eternal
    File "noneternal_reject_unknown_grade.tpe", lines 27-31, characters 0-3:
    27 | let hold g x =
         ^^^^^^^^^^^^^^
    `hold` is defined here
    File "noneternal_reject_unknown_grade.tpe", line 28, characters 6-7:
    28 |   let y = x in
               ^
    `y` is bound here
    File "noneternal_reject_unknown_grade.tpe", line 30, characters 2-9:
    30 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    File "noneternal_reject_unknown_grade.tpe", line 31, characters 2-3:
    31 |   y
           ^
    `y` is used here with grade `1` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  noneternal_type.tpe
  ======================================================================
  === Run 1 ===
  return (Ticket Token)
  State: []
  
  === Run 2 ===
  return (Stamp 42)
  State: [
    3
  ]
  
  ======================================================================
  occurs_check.tpe
  ======================================================================
  File "occurs_check.tpe", line 1, characters 14-19:
  1 | run let rec f x = f in f
                    ^^^^^
  Typing error: Cannot construct the infinite type `α = β → α`
  ======================================================================
  occurs_check_related_annotation.tpe
  ======================================================================
  File "occurs_check_related_annotation.tpe", line 9, characters 6-31:
  9 |   let p : 'a * 'a list = (x, y) in
            ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Cannot construct the infinite type `α = α list`
    File "occurs_check_related_annotation.tpe", line 7, characters 10-13:
    7 |   let u = f x in
                  ^^^
    the argument `x` is given the parameter type of `f` here
    File "occurs_check_related_annotation.tpe", line 8, characters 10-13:
    8 |   let v = f y in
                  ^^^
    the argument `y` is given the parameter type of `f` here
  ======================================================================
  occurs_check_related_application.tpe
  ======================================================================
  File "occurs_check_related_application.tpe", line 10, characters 9-11:
  10 |   k (f, [x])
                ^^
  Typing error: Cannot construct the infinite type `α = α list`
    File "occurs_check_related_application.tpe", line 10, characters 2-12:
    10 |   k (f, [x])
           ^^^^^^^^^^
    `α list` was inferred here
    File "occurs_check_related_application.tpe", line 8, characters 10-13:
    8 |   let u = f x in
                  ^^^
    the argument `x` is given the parameter type of `f` here
    File "occurs_check_related_application.tpe", line 9, characters 10-50:
    9 |   let k = fun p -> match p with (g, b) -> (g b, b) in
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the value of this computation is bound to `k` here
  ======================================================================
  occurs_check_related_pattern.tpe
  ======================================================================
  File "occurs_check_related_pattern.tpe", line 10, characters 2-10:
  10 |   k (x, f)
         ^^^^^^^^
  Typing error: Cannot construct the infinite type `α = α list`
    File "occurs_check_related_pattern.tpe", line 10, characters 2-3:
    10 |   k (x, f)
           ^
    the function has type `β × (γ list → δ # ε₀) → ζ # ε₀`
    File "occurs_check_related_pattern.tpe", line 9, characters 32-38:
    9 |   let k = fun p -> match p with (b, g) -> g [b] in
                                        ^^^^^^
    `α list` was inferred here
    File "occurs_check_related_pattern.tpe", line 8, characters 10-13:
    8 |   let u = f x in
                  ^^^
    `α` was inferred here
    Note: while matching `β × (γ list → δ # ε₀) → ζ # ε₀` against `(η → θ # ε₁) → ι # ε₂`
  ======================================================================
  op_case_context.tpe
  ======================================================================
  === Run 1 ===
  return 12
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  ======================================================================
  op_case_context_continuation.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ <fun> # 0, resource_3 ↦ <fun> # 0 }
  ]
  
  ======================================================================
  op_case_context_function.tpe
  ======================================================================
  ======================================================================
  op_case_context_noneternal.tpe
  ======================================================================
  ======================================================================
  op_case_context_unbox.tpe
  ======================================================================
  ======================================================================
  operation_ground.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: []
  
  ======================================================================
  operation_reject_datatype.tpe
  ======================================================================
  File "operation_reject_datatype.tpe", line 5, characters 0-40:
  5 | operation Op : callback list ~> unit # 1
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The operation `Op` has a parameter type containing a function type through the definition of `callback`; operation parameter and result types must be ground
    Note: a function or handler in an operation's parameter or result lets a handler build non-terminating programs without recursion
  ======================================================================
  operation_reject_higher_order.tpe
  ======================================================================
  File "operation_reject_higher_order.tpe", line 8, characters 0-45:
  8 | operation Op : unit ~> (unit -> unit # 0) # 0
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The operation `Op` has a result type containing a function type; operation parameter and result types must be ground
    Note: a function or handler in an operation's parameter or result lets a handler build non-terminating programs without recursion
  ======================================================================
  orelse_andalso.tpe
  ======================================================================
  === Run 1 ===
  return false
  State: []
  
  === Run 2 ===
  return false
  State: []
  
  === Run 3 ===
  return false
  State: []
  
  === Run 4 ===
  return true
  State: []
  
  === Run 5 ===
  return false
  State: []
  
  === Run 6 ===
  return true
  State: []
  
  === Run 7 ===
  return true
  State: []
  
  === Run 8 ===
  return true
  State: []
  
  === Run 9 ===
  return true
  State: []
  
  ======================================================================
  parse_precedence.tpe
  ======================================================================
  === Run 1 ===
  return 6
  State: [
    { resource_0 ↦ 5 # 1 }
  ]
  
  === Run 2 ===
  return 8
  State: [
    { resource_0 ↦ 7 # 0 }
  ]
  
  === Run 3 ===
  return 9
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  === Run 4 ===
  return 4
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  === Run 5 ===
  return 1
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  === Run 6 ===
  return 2
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  === Run 7 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # 0 }
  ]
  
  === Run 8 ===
  return 2
  State: []
  
  === Run 9 ===
  return 2
  State: []
  
  === Run 10 ===
  return 3
  State: []
  
  === Run 11 ===
  return (fun y ↦ let b = ( * ) y in
                  b 2)
  State: []
  
  === Run 12 ===
  return 6
  State: []
  
  ======================================================================
  patterns.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: []
  
  === Run 2 ===
  return (1, 2)
  State: []
  
  === Run 3 ===
  return (1, 2::3::4::[])
  State: []
  
  === Run 4 ===
  return (2::3::4::[])
  State: []
  
  === Run 5 ===
  return 10
  State: []
  
  === Run 6 ===
  return (10, Moo 10)
  State: []
  
  === Run 7 ===
  return (42, 42, 42)
  State: []
  
  === Run 8 ===
  return (1, 2, 3, (1, 2, 3))
  State: []
  
  === Run 9 ===
  return ("foo", "foo", "bar")
  State: []
  
  === Run 10 ===
  return (fun (Moo x) ↦ return x)
  State: []
  
  === Run 11 ===
  return (fun o ↦
            match o with
            | Some (x::xs) ↦ return xs
            | Some [] ↦ return []
            | None ↦ return [])
  State: []
  
  === Run 12 ===
  return (fun l ↦
            match l with
            | (x as y)::_ as z ↦ return (x, y, z)
            | [] ↦ return (0, 0, []))
  State: []
  
  === Run 13 ===
  return (fun l ↦ match l with
                  | x + 1::_ ↦ return x
                  | _ ↦ return 0)
  State: []
  
  ======================================================================
  plain_rational_traces_upper.tpe
  ======================================================================
  ======================================================================
  plain_traces_upper.tpe
  ======================================================================
  ======================================================================
  plain_traces_upper_reject.tpe
  ======================================================================
  File "plain_traces_upper_reject.tpe", lines 19-20, characters 2-3:
  19 |   unbox r as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `{Heat}` accumulated since it was bound, which is not below its box grade `{1}`
    File "plain_traces_upper_reject.tpe", line 17, characters 14-15:
    17 |   box 1 42 as r in
                       ^
    `r` is bound here
    File "plain_traces_upper_reject.tpe", line 18, characters 2-17:
    18 |   perform Heat ();
           ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Heat} <= {1}` does not hold
  
  File "plain_traces_upper_reject.tpe", lines 22-23, characters 32-67:
  22 | let read_or_send (fresh : bool) : unit # {Read} =
                                       ^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Read | Send}`, which does not match its annotated grade `{Read}`
    Note: the effect inequality `{Read | Send} <= {Read}` does not hold
    Note: the grade `{Send}` is below `{Read | Send}` but not below `{Read}`
  ======================================================================
  polymorphism.tpe
  ======================================================================
  === Run 1 ===
  return (5, "foo")
  State: []
  
  === Run 2 ===
  return (4, "foo")
  State: []
  
  === Run 3 ===
  return (1::[], "foo"::[])
  State: []
  
  === Run 4 ===
  return ([]::[]::[], (2::[])::[]::[])
  State: []
  
  === Run 5 ===
  return (fun x ↦
            let h = return (fun t ↦ return (fun u ↦ return u)) in
            let b = h x in
            b x)
  State: []
  
  === Run 6 ===
  return (fun x ↦
            let h = return (fun t ↦ return (fun u ↦ return t)) in
            let b = h x in
            b x)
  State: []
  
  ======================================================================
  polymorphism_id_id.tpe
  ======================================================================
  File "polymorphism_id_id.tpe", line 3, characters 17-18:
  3 |     (v 42, v "foo")
                       ^
  Typing error: This argument has type `string` but the function expects `nat`
    File "polymorphism_id_id.tpe", line 3, characters 11-12:
    3 |     (v 42, v "foo")
                   ^
    the function has type `nat → nat`
    File "polymorphism_id_id.tpe", line 3, characters 5-9:
    3 |     (v 42, v "foo")
             ^^^^
    `nat` was inferred here
    Note: while matching `nat → nat` against `string → α # ε₀`
  ======================================================================
  positivity.tpe
  ======================================================================
  === Run 1 ===
  return (Node ((Node [])::(Node ((Node [])::[]))::[]))
  State: []
  
  === Run 2 ===
  return (Even (Odd Zero))
  State: []
  
  ======================================================================
  positivity_reject_list.tpe
  ======================================================================
  File "positivity_reject_list.tpe", line 3, characters 0-29:
  3 | type t = T of (t list -> nat)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `t` is not strictly positive: it occurs in the domain of a function type in the argument of constructor `T`
    Note: a type occurring other than strictly positively in its own definition admits non-terminating programs without recursion
  ======================================================================
  positivity_reject_mutual.tpe
  ======================================================================
  File "positivity_reject_mutual.tpe", lines 3-4, characters 0-14:
  3 | type a = A of (b -> nat)
      ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `b` is not strictly positive: it occurs in the domain of a function type in the argument of constructor `A`
    Note: a type occurring other than strictly positively in its own definition admits non-terminating programs without recursion
  ======================================================================
  positivity_reject_nested.tpe
  ======================================================================
  File "positivity_reject_nested.tpe", line 3, characters 0-33:
  3 | type 'a t = Leaf | Node of 'a t t
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `t` is not strictly positive: it occurs in an argument of `t`, a type being defined, in the argument of constructor `Node`
    Note: a type occurring other than strictly positively in its own definition admits non-terminating programs without recursion
  ======================================================================
  positivity_reject_omega.tpe
  ======================================================================
  File "positivity_reject_omega.tpe", line 7, characters 0-27:
  7 | type t = Fold of (t -> nat)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `t` is not strictly positive: it occurs in the domain of a function type in the argument of constructor `Fold`
    Note: a type occurring other than strictly positively in its own definition admits non-terminating programs without recursion
  ======================================================================
  positivity_reject_parameter.tpe
  ======================================================================
  File "positivity_reject_parameter.tpe", line 5, characters 0-20:
  5 | type t = T of t pred
      ^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `t` is not strictly positive: it occurs in an argument of `pred`, at a parameter that is not strictly positive, in the argument of constructor `T`
    Note: a type occurring other than strictly positively in its own definition admits non-terminating programs without recursion
  ======================================================================
  rational_time_intervals.tpe
  ======================================================================
  === Run 1 ===
  return "tea"
  State: [
    { resource_0 ↦ "tea" # [0.5, 1.5] },
    [0.25, 0.25],
    { resource_2 ↦ <fun> # [0.5, 0.75] },
    [0.625, 0.625]
  ]
  
  ======================================================================
  rational_time_intervals_reject.tpe
  ======================================================================
  File "rational_time_intervals_reject.tpe", lines 14-15, characters 2-3:
  14 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `[1, 1.5]` accumulated since it was bound, which is not below its box grade `[0.5, 1.25]`
    File "rational_time_intervals_reject.tpe", line 11, characters 27-28:
    11 |   box [0.5, 1.25] "tea" as r in
                                    ^
    `r` is bound here
    File "rational_time_intervals_reject.tpe", line 12, characters 2-17:
    12 |   perform Pour ();
           ^^^^^^^^^^^^^^^
    grade `[0.5, 0.75]` accumulates here (operation `Pour`)
    File "rational_time_intervals_reject.tpe", line 13, characters 2-17:
    13 |   perform Pour ();
           ^^^^^^^^^^^^^^^
    grade `[0.5, 0.75]` accumulates here (operation `Pour`)
    Note: the resource inequality `[1, 1.5] <= [0.5, 1.25]` does not hold
  ======================================================================
  rational_time_intervals_reject_within.tpe
  ======================================================================
  File "rational_time_intervals_reject_within.tpe", line 10, characters 0-60:
  10 | operation Dose : unit ~> unit # [0.5, 1.5] within [1/2, 3/2]
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `time-interval-rational` grading monoid, which does not use them
  ======================================================================
  rational_time_lower.tpe
  ======================================================================
  === Run 1 ===
  return "ripe"
  State: [
    { resource_0 ↦ "ripe" # 2.25 },
    0.5,
    1.25,
    { resource_2 ↦ <fun> # 0.5 },
    0.5
  ]
  
  ======================================================================
  rational_time_lower_reject.tpe
  ======================================================================
  File "rational_time_lower_reject.tpe", line 11, characters 27-48:
  11 | let h = handler | x -> x | Op () k -> delay 5; 0
                                  ^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ε_Op` the continuation `k` may have, the case for `Op` must have a grade matching `1 · ε_Op`, but its grade `5` does not
    File "rational_time_lower_reject.tpe", line 6, characters 0-31:
    6 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "rational_time_lower_reject.tpe", line 11, characters 33-34:
    11 | let h = handler | x -> x | Op () k -> delay 5; 0
                                          ^
    `k` may have any grade `ε_Op`
    Note: the effect inequality `∀ε_Op. 5 >= 1 · ε_Op` does not hold: for `ε_Op = 4.5` it becomes `5 >= 5.5`
  
  File "rational_time_lower_reject.tpe", lines 20-21, characters 2-3:
  20 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `1` accumulated since it was bound, which is not below its box grade `1.5`
    File "rational_time_lower_reject.tpe", line 16, characters 22-23:
    16 |   box 1.5 "unripe" as r in
                               ^
    `r` is bound here
    File "rational_time_lower_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_lower_reject.tpe", line 18, characters 2-11:
    18 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_lower_reject.tpe", line 19, characters 2-11:
    19 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    Note: the resource inequality `1 >= 1.5` does not hold
  ======================================================================
  rational_time_upper.tpe
  ======================================================================
  === Run 1 ===
  return "fresh"
  State: [
    { resource_0 ↦ "fresh" # 1 },
    1/3,
    1/3,
    1/3
  ]
  
  === Run 2 ===
  return "fresh"
  State: [
    { resource_0 ↦ "fresh" # 0.5 },
    0.375,
    0.125
  ]
  
  === Run 3 ===
  return "fresh"
  State: [
    { resource_0 ↦ "fresh" # 0.5 },
    0.375,
    { resource_2 ↦ <fun> # 0.125 },
    0.0625
  ]
  
  ======================================================================
  rational_time_upper_reject.tpe
  ======================================================================
  File "rational_time_upper_reject.tpe", lines 14-15, characters 2-3:
  14 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `4/3` accumulated since it was bound, which is not below its box grade `1`
    File "rational_time_upper_reject.tpe", line 9, characters 19-20:
    9 |   box 1 "fresh" as r in
                           ^
    `r` is bound here
    File "rational_time_upper_reject.tpe", line 10, characters 2-11:
    10 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_upper_reject.tpe", line 11, characters 2-11:
    11 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_upper_reject.tpe", line 12, characters 2-11:
    12 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_upper_reject.tpe", line 13, characters 2-11:
    13 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    Note: the resource inequality `4/3 <= 1` does not hold
  ======================================================================
  rational_traces_intervals.tpe
  ======================================================================
  === Run 1 ===
  return 6
  State: [
    [{0.75}, {0.75}],
    [{0.25}, {0.25}],
    [{0.75}, {0.75}]
  ]
  
  ======================================================================
  rational_traces_intervals_default_open.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1.5}, {1.5}],
    [{2}, {2}]
  ]
  
  ======================================================================
  rational_traces_intervals_default_open_reject.tpe
  ======================================================================
  File "rational_traces_intervals_default_open_reject.tpe", line 15, characters 0-25:
  15 | default Send () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` takes a duration in `[2, 2]`, which is not within the running-time bounds `[1, 2)` of `Send`
    File "rational_traces_intervals_default_open_reject.tpe", line 12, characters 0-62:
    12 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 2)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
  
  File "rational_traces_intervals_default_open_reject.tpe", line 16, characters 0-25:
  16 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` takes a duration in `[1, 1]`, which is not within the running-time bounds `(1, 2]` of `Beep`
    File "rational_traces_intervals_default_open_reject.tpe", line 13, characters 0-62:
    13 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
  ======================================================================
  rational_traces_intervals_reject.tpe
  ======================================================================
  File "rational_traces_intervals_reject.tpe", lines 18-19, characters 2-3:
  18 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `[{Sample; 0.125}, {Sample; 0.125}]` accumulated since it was bound, which is not below its box grade `[{0.75}, {2}]`
    File "rational_traces_intervals_reject.tpe", line 15, characters 21-24:
    15 |   box [3/4, 2] () as due in
                              ^^^
    `due` is bound here
    File "rational_traces_intervals_reject.tpe", line 16, characters 10-27:
    16 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    File "rational_traces_intervals_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/8;
           ^^^^^^^^^
    grade `[{0.125}, {0.125}]` accumulates here (delay)
    Note: the resource inequality `[{Sample; 0.125}, {Sample; 0.125}] <= [{0.75}, {2}]` does not hold
  ======================================================================
  rational_traces_intervals_reject_open.tpe
  ======================================================================
  File "rational_traces_intervals_reject_open.tpe", line 10, characters 19-27:
  10 | let claim () = box (1/2, 2] 1
                          ^^^^^^^^
  Syntax error: In the `traces-timed-interval-rational` grading monoid, an open endpoint denotes an infinite set of traces, which these grades do not express; did you mean to use one of the `time-interval-rational`, `regex-timed-interval-rational-symbolic` or `event-separation` grading monoids?
  ======================================================================
  rational_traces_upper.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_0 ↦ () # {2.75} },
    {0.5},
    {0.25},
    {0.25}
  ]
  
  ======================================================================
  rational_traces_upper_open.tpe
  ======================================================================
  ======================================================================
  rational_traces_upper_open_reject.tpe
  ======================================================================
  File "rational_traces_upper_open_reject.tpe", lines 16-17, characters 2-3:
  16 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Sample}` accumulated since it was bound, which is not below its box grade `{1.4}`
    File "rational_traces_upper_open_reject.tpe", line 14, characters 17-21:
    14 |   box {1.4} 1 as slot in
                          ^^^^
    `slot` is bound here
    File "rational_traces_upper_open_reject.tpe", line 15, characters 2-19:
    15 |   perform Sample ();
           ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    Note: the resource inequality `{Sample} <= {1.4}` does not hold
  ======================================================================
  rational_traces_upper_reject.tpe
  ======================================================================
  File "rational_traces_upper_reject.tpe", lines 18-19, characters 2-3:
  18 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `{Sample; 0.5}` accumulated since it was bound, which is not below its box grade `{1.75}`
    File "rational_traces_upper_reject.tpe", line 15, characters 18-21:
    15 |   box {7/4} () as due in
                           ^^^
    `due` is bound here
    File "rational_traces_upper_reject.tpe", line 16, characters 10-27:
    16 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "rational_traces_upper_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    Note: the resource inequality `{Sample; 0.5} <= {1.75}` does not hold
  ======================================================================
  rational_traces_upper_short.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.25},
    {0.25}
  ]
  
  ======================================================================
  recursion_effect_levels.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_0 ↦ 3 # High }
  ]
  
  ======================================================================
  recursion_effect_regular.tpe
  ======================================================================
  === Run 1 ===
  return 0
  State: []
  
  === Run 2 (unhandled operation) ===
  perform Read () (op_var.
    (let x =
       (let x = return op_var in
        let y = (rec read_all ...) 0 in
        let b = (+) x in
        b y) in
     let y = read_all 1 in
     let b = (+) x in
     b y))
  
  ======================================================================
  recursion_effect_reject_invariant.tpe
  ======================================================================
  File "recursion_effect_reject_invariant.tpe", lines 8-13, characters 15-12:
  8 | let rec wait n : unit # 5 =
                     ^^^^^^^^^^^^
  Typing error: This function's body has grade `6`, which does not match its annotated grade `5`
    Note: the effect inequality `6 <= 5` does not hold
  ======================================================================
  recursion_effect_reject_lower.tpe
  ======================================================================
  File "recursion_effect_reject_lower.tpe", lines 7-12, characters 15-12:
  7 | let rec wait n : unit # 3 =
                     ^^^^^^^^^^^^
  Typing error: This function's body has grade `0`, which does not match its annotated grade `3`
    Note: the effect inequality `0 >= 3` does not hold
  ======================================================================
  recursion_effect_reject_unannotated.tpe
  ======================================================================
  File "recursion_effect_reject_unannotated.tpe", lines 8-13, characters 13-12:
  8 | let rec wait n =
                   ^^^
  Typing error: The effect inequality `1 <= 0` does not hold
  ======================================================================
  recursion_effect_reject_unannotated_regular.tpe
  ======================================================================
  File "recursion_effect_reject_unannotated_regular.tpe", lines 16-21, characters 20-19:
  16 | let rec unannotated (n : nat) =
                           ^^^^^^^^^^^
  Typing error: The effect inequality `{Read} <= {0}` does not hold
  ======================================================================
  recursion_effect_upper.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    1,
    1,
    1
  ]
  
  === Run 2 ===
  return 3
  State: []
  
  === Run 3 ===
  return 4
  State: [
    2,
    2,
    2,
    2
  ]
  
  === Run 4 ===
  return 2
  State: [
    { resource_1 ↦ <fun> # ∞ },
    1,
    { resource_3 ↦ <fun> # ∞ },
    1
  ]
  
  ======================================================================
  recursion_lock.tpe
  ======================================================================
  === Run 1 ===
  return (12, 2, 3)
  State: [
    { resource_1 ↦ <fun> # 0,
      resource_3 ↦ <fun> # 0,
      resource_5 ↦ <fun> # 0,
      resource_7 ↦ <fun> # 0,
      resource_9 ↦ <fun> # 0
    }
  ]
  
  ======================================================================
  recursion_lock_lower.tpe
  ======================================================================
  === Run 1 ===
  return 6
  State: []
  
  ======================================================================
  recursion_lock_reject.tpe
  ======================================================================
  File "recursion_lock_reject.tpe", line 12, characters 15-16:
  12 |     | j + 1 -> g (go j)
                      ^
  Typing error: Variable `g` has type `nat → nat`, which is not eternal, so it cannot be used in the body of the recursive function `go`, which may run at any later time
    File "recursion_lock_reject.tpe", line 8, characters 16-17:
    8 | let apply_times g n =
                        ^
    `g` is bound here
    File "recursion_lock_reject.tpe", lines 9-12, characters 13-23:
    9 |   let rec go m =
                     ^^^
    `go` is defined here, its body checked with the top grade `∞` accumulated
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  regex_rational.tpe
  ======================================================================
  ======================================================================
  regex_rational_reject.tpe
  ======================================================================
  File "regex_rational_reject.tpe", lines 19-20, characters 2-3:
  19 |   unbox t as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{1}` accumulated since it was bound, which is not below its box grade `{~1}`
    File "regex_rational_reject.tpe", line 16, characters 16-17:
    16 |   box {~1} 7 as t in
                         ^
    `t` is bound here
    File "regex_rational_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 18, characters 2-11:
    18 |   delay 0.5;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    Note: the resource inequality `{1} <= {~1}` does not hold
  
  File "regex_rational_reject.tpe", lines 28-29, characters 2-3:
  28 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `{Sample; 1; Send}` accumulated since it was bound, which is not below its box grade `{Sample; [0, 1); Send}`
    File "regex_rational_reject.tpe", line 23, characters 35-38:
    23 |   box {Sample; [0, 1); Send} () as due in
                                            ^^^
    `due` is bound here
    File "regex_rational_reject.tpe", line 24, characters 10-27:
    24 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_rational_reject.tpe", line 25, characters 2-11:
    25 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 26, characters 2-11:
    26 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 27, characters 2-16:
    27 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; 1; Send} <= {Sample; [0, 1); Send}` does not hold
  
  File "regex_rational_reject.tpe", line 31, characters 14-43:
  31 | let thirds () : unit # {(1/2)*} = delay 1/3
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{1/3}`, which does not match its annotated grade `{(0.5)*}`
    Note: the effect inequality `{1/3} <= {(0.5)*}` does not hold
  
  File "regex_rational_reject.tpe", lines 36-37, characters 2-3:
  36 |   unbox w as u in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `w` is unboxed with grade `{2 | 0.5}` accumulated since it was bound, which is not below its box grade `{[1, ∞)}`
    File "regex_rational_reject.tpe", line 34, characters 23-24:
    34 |   box {[1, ∞)} () as w in
                              ^
    `w` is bound here
    File "regex_rational_reject.tpe", line 35, characters 2-34:
    35 |   if b then delay 1/2 else delay 2;
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{2 | 0.5}` accumulates here (this computation)
    Note: the resource inequality `{2 | 0.5} <= {[1, ∞)}` does not hold
    Note: the grade `{0.5}` is below `{2 | 0.5}` but not below `{[1, ∞)}`
  ======================================================================
  regex_timed_compound_named_later_reject.tpe
  ======================================================================
  File "regex_timed_compound_named_later_reject.tpe", line 10, characters 0-45:
  10 | operation Two : unit ~> unit # {Fetch; Later}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Unknown event `Later` in the grade of operation `Two`
  ======================================================================
  regex_timed_compound_wildcard.tpe
  ======================================================================
  ======================================================================
  regex_timed_interval.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_timed_interval_reject.tpe
  ======================================================================
  File "regex_timed_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_timed_interval_reject.tpe", line 16, characters 28-29:
    16 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 17, characters 2-18:
    17 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_timed_interval_reject.tpe", lines 25-26, characters 2-5:
  25 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_timed_interval_reject.tpe", line 23, characters 28-29:
    23 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 24, characters 2-18:
    24 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_timed_interval_ticks_reject.tpe
  ======================================================================
  File "regex_timed_interval_ticks_reject.tpe", line 17, characters 6-34:
  17 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_timed_interval_ticks_reject.tpe", line 24, characters 33-61:
  24 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_timed_lower.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {Ping; 3} },
    {1},
    {3},
    {1}
  ]
  
  ======================================================================
  regex_timed_lower_reject.tpe
  ======================================================================
  File "regex_timed_lower_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_timed_lower_reject.tpe", line 17, characters 31-32:
    17 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_lower_reject.tpe", line 18, characters 2-17:
    18 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_timed_lower_reject.tpe", line 19, characters 2-9:
    19 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_timed_lower_reject.tpe", line 25, characters 29-30:
    25 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_timed_lower_reject.tpe", line 26, characters 2-10:
    26 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 34-35, characters 2-5:
  34 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_lower_reject.tpe", line 32, characters 25-26:
    32 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_timed_lower_reject.tpe", line 33, characters 2-58:
    33 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_timed_lower_ticks_reject.tpe
  ======================================================================
  File "regex_timed_lower_ticks_reject.tpe", line 16, characters 6-30:
  16 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_timed_rational_interval.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{0.5}, {1.5}] },
    [{0.5}, {0.5}]
  ]
  
  ======================================================================
  regex_timed_rational_interval_default_open_reject.tpe
  ======================================================================
  File "regex_timed_rational_interval_default_open_reject.tpe", line 14, characters 0-25:
  14 | default Send () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` has grade `[{2}, {2}]`, which does not match the declared grade `[{1}, {[0, 2)}]` of `Send`
    File "regex_timed_rational_interval_default_open_reject.tpe", line 11, characters 0-62:
    11 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 2)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
    Note: the effect inequality `[{2}, {2}] <= [{1}, {[0, 2)}]` does not hold
  
  File "regex_timed_rational_interval_default_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_timed_rational_interval_default_open_reject.tpe", line 12, characters 0-62:
    12 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_timed_rational_interval_open_reject.tpe
  ======================================================================
  File "regex_timed_rational_interval_open_reject.tpe", line 12, characters 0-25:
  12 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_timed_rational_interval_open_reject.tpe", line 10, characters 0-62:
    10 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_timed_rational_interval_reject.tpe
  ======================================================================
  File "regex_timed_rational_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Sample}, {Sample}]` accumulated since it was bound, which is not below its box grade `[{0.75}, {2}]`
    File "regex_timed_rational_interval_reject.tpe", line 16, characters 30-31:
    16 |   box [3/4, 2] (Token "t") as t in
                                       ^
    `t` is bound here
    File "regex_timed_rational_interval_reject.tpe", line 17, characters 10-27:
    17 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{Sample}, {Sample}] <= [{0.75}, {2}]` does not hold
  
  File "regex_timed_rational_interval_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{0.5; Sample}, {0.5; Sample}]` accumulated since it was bound, which is not below its box grade `[{0.5}, {[0, 1)}]`
    File "regex_timed_rational_interval_reject.tpe", line 24, characters 39-40:
    24 |   box [{1/2}, {[0, 1)}] (Token "t") as t in
                                                ^
    `t` is bound here
    File "regex_timed_rational_interval_reject.tpe", line 25, characters 2-11:
    25 |   delay 1/2;
           ^^^^^^^^^
    grade `[{0.5}, {0.5}]` accumulates here (delay)
    File "regex_timed_rational_interval_reject.tpe", line 26, characters 10-27:
    26 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{0.5; Sample}, {0.5; Sample}] <= [{0.5}, {[0, 1)}]` does not hold
  ======================================================================
  regex_timed_rational_lower.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25}
  ]
  
  ======================================================================
  regex_timed_rational_lower_reject.tpe
  ======================================================================
  File "regex_timed_rational_lower_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{0.25}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_timed_rational_lower_reject.tpe", line 17, characters 27-28:
    17 |   box {1/2} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 18, characters 2-11:
    18 |   delay 1/4;
           ^^^^^^^^^
    grade `{0.25}` accumulates here (delay)
    Note: the resource inequality `{0.25} <= {0.5}` does not hold
  
  File "regex_timed_rational_lower_reject.tpe", lines 26-27, characters 2-5:
  26 |   unbox s as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `s` is unboxed with grade `{3}` accumulated since it was bound, which is not below its box grade `{Send}`
    File "regex_timed_rational_lower_reject.tpe", line 24, characters 28-29:
    24 |   box {Send} (Token "s") as s in
                                     ^
    `s` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 25, characters 2-9:
    25 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{3} <= {Send}` does not hold
  
  File "regex_timed_rational_lower_reject.tpe", lines 36-37, characters 2-5:
  36 |   unbox p as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `p` is unboxed with grade `{(0, 1)}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_timed_rational_lower_reject.tpe", line 34, characters 27-28:
    34 |   box {1/2} (Token "p") as p in
                                    ^
    `p` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 35, characters 2-15:
    35 |   some_delay ();
           ^^^^^^^^^^^^^
    grade `{(0, 1)}` accumulates here (this computation)
    Note: the resource inequality `{(0, 1)} <= {0.5}` does not hold
    Note: the grade `{1/3}` is below `{(0, 1)}` but not below `{0.5}`
  
  File "regex_timed_rational_lower_reject.tpe", line 40, characters 13-44:
  40 | let quick () : nat # {1} = perform Sample ()
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample}`, which does not match its annotated grade `{1}`
    Note: the effect inequality `{Sample} <= {1}` does not hold
  ======================================================================
  regex_timed_rational_upper.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25},
    {0.25}
  ]
  
  ======================================================================
  regex_timed_rational_upper_open.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # {[0, 2)} },
    {1.9}
  ]
  
  ======================================================================
  regex_timed_rational_upper_open_reject.tpe
  ======================================================================
  File "regex_timed_rational_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Sample}` accumulated since it was bound, which is not below its box grade `{[0, 2)}`
    File "regex_timed_rational_upper_open_reject.tpe", line 15, characters 20-24:
    15 |   box {[0, 2)} 1 as slot in
                             ^^^^
    `slot` is bound here
    File "regex_timed_rational_upper_open_reject.tpe", line 16, characters 2-19:
    16 |   perform Sample ();
           ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    Note: the resource inequality `{Sample} <= {[0, 2)}` does not hold
  
  File "regex_timed_rational_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{2}`, which does not match the declared grade `{[0, 2)}` of `Beep`
    File "regex_timed_rational_upper_open_reject.tpe", line 12, characters 0-54:
    12 | operation Beep : unit ~> unit # {Beep} within [1/2, 2)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{2} <= {[0, 2)}` does not hold
  ======================================================================
  regex_timed_rational_upper_reject.tpe
  ======================================================================
  File "regex_timed_rational_upper_reject.tpe", lines 21-22, characters 2-5:
  21 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; 1/3}` accumulated since it was bound, which is not below its box grade `{1.75}`
    File "regex_timed_rational_upper_reject.tpe", line 18, characters 27-28:
    18 |   box {7/4} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 19, characters 10-27:
    19 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_timed_rational_upper_reject.tpe", line 20, characters 2-11:
    20 |   delay 1/3;
           ^^^^^^^^^
    grade `{1/3}` accumulates here (delay)
    Note: the resource inequality `{Sample; 1/3} <= {1.75}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; Send}` accumulated since it was bound, which is not below its box grade `{Send; 2}`
    File "regex_timed_rational_upper_reject.tpe", line 27, characters 31-32:
    27 |   box {Send; 2} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 28, characters 10-27:
    28 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_timed_rational_upper_reject.tpe", line 29, characters 2-16:
    29 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; Send} <= {Send; 2}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 42-43, characters 2-5:
  42 |   unbox b as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `{[0, 0.5); Send; [0, 0.5)}` accumulated since it was bound, which is not below its box grade `{1.99}`
    File "regex_timed_rational_upper_reject.tpe", line 38, characters 28-29:
    38 |   box {1.99} (Token "b") as b in
                                     ^
    `b` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 39, characters 2-16:
    39 |   short_delay ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    File "regex_timed_rational_upper_reject.tpe", line 40, characters 2-16:
    40 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_timed_rational_upper_reject.tpe", line 41, characters 2-16:
    41 |   short_delay ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    Note: the resource inequality `{[0, 0.5); Send; [0, 0.5)} <= {1.99}` does not hold
    Note: the grade `{64/129; Send; 64/129}` is below `{[0, 0.5); Send; [0, 0.5)}` but not below `{1.99}`
  
  File "regex_timed_rational_upper_reject.tpe", lines 51-52, characters 2-5:
  51 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Send; 1}` accumulated since it was bound, which is not below its box grade `{Send; ([0, 1] & ~1)}`
    File "regex_timed_rational_upper_reject.tpe", line 48, characters 43-44:
    48 |   box {Send; ([0, 1] & ~1)} (Token "l") as l in
                                                    ^
    `l` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 49, characters 2-16:
    49 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_timed_rational_upper_reject.tpe", line 50, characters 2-9:
    50 |   delay 1;
           ^^^^^^^
    grade `{1}` accumulates here (delay)
    Note: the resource inequality `{Send; 1} <= {Send; ([0, 1] & ~1)}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 56-58, characters 19-19:
  56 | let two_samples () : nat # {5/2} =
                          ^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample; Sample}`, which does not match its annotated grade `{2.5}`
    Note: the effect inequality `{Sample; Sample} <= {2.5}` does not hold
  ======================================================================
  regex_timed_upper.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_timed_upper_open.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_timed_upper_open_reject.tpe
  ======================================================================
  File "regex_timed_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_timed_upper_open_reject.tpe", line 15, characters 15-19:
    15 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_timed_upper_open_reject.tpe", line 16, characters 2-15:
    16 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_timed_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_timed_upper_open_reject.tpe", line 12, characters 0-52:
    12 | operation Beep : unit ~> unit # {Beep} within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_timed_upper_reject.tpe
  ======================================================================
  File "regex_timed_upper_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_upper_reject.tpe", line 17, characters 25-26:
    17 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_timed_upper_reject.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 28-29, characters 2-5:
  28 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_timed_upper_reject.tpe", line 25, characters 30-31:
    25 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_timed_upper_reject.tpe", line 26, characters 2-18:
    26 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_timed_upper_reject.tpe", line 27, characters 2-16:
    27 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 35-36, characters 2-5:
  35 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_timed_upper_reject.tpe", line 33, characters 37-38:
    33 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_timed_upper_reject.tpe", line 34, characters 2-49:
    34 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_timed_upper_reject.tpe", lines 39-41, characters 17-17:
  39 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_timed_upper_ticks.tpe
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_timed_upper_ticks_reject.tpe
  ======================================================================
  File "regex_timed_upper_ticks_reject.tpe", line 17, characters 6-23:
  17 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 22, characters 26-43:
  22 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 25, characters 27-44:
  25 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  ======================================================================
  regular_auth.tpe
  ======================================================================
  === Run 1 ===
  return 42
  State: [
    { resource_0 ↦ 42 # {3; _*} },
    {4}
  ]
  
  ======================================================================
  regular_protocol.tpe
  ======================================================================
  ======================================================================
  regular_reject_auth.tpe
  ======================================================================
  File "regular_reject_auth.tpe", lines 19-21, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 17, characters 36-37:
    17 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 26-27, characters 2-5:
  26 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 24, characters 41-42:
    24 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 25, characters 2-19:
    25 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 33-34, characters 2-3:
  33 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 30, characters 20-21:
    30 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 31, characters 2-18:
    31 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 32, characters 2-9:
    32 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe
  ======================================================================
  File "regular_reject_bounds.tpe", line 9, characters 0-52:
  9 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `regex-upper-bound-symbolic` grading monoid, which does not use them
  ======================================================================
  regular_reject_counterexample.tpe
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 18-23, characters 23-3:
  18 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 29-30, characters 2-5:
  29 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 27, characters 23-24:
    27 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 28, characters 2-49:
    28 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe
  ======================================================================
  File "regular_reject_protocol.tpe", line 21, characters 6-23:
  21 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 17, characters 15-16:
    17 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 18, characters 6-21:
    18 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 19, characters 6-22:
    19 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 20, characters 14-29:
    20 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 23-24, characters 16-34:
  23 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold
  ======================================================================
  resource_levels.tpe
  ======================================================================
  === Run 1 ===
  return (File "a", File "b")
  State: []
  
  === Run 2 ===
  return (File "a", File "b")
  State: [
    { resource_1 ↦ <fun> # ([0, 1], 1), resource_3 ↦ <fun> # ([0, 1], 1) }
  ]
  
  === Run 3 ===
  return ()
  State: []
  
  ======================================================================
  resource_levels_by_resource.tpe
  ======================================================================
  === Run 1 (unhandled operation) ===
  perform Lock () (op_var.
    (return op_var;
     let a = perform Open "a" (op_var. return op_var) in
     let b = perform Open "b" (op_var. return op_var) in
     return (a, b)))
  
  ======================================================================
  resource_levels_by_resource_reject.tpe
  ======================================================================
  File "resource_levels_by_resource_reject.tpe", lines 16-20, characters 14-19:
  16 | let relock () : unit # ((Files, 0, 2), (Locks, 0, 1)) =
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Locks, 0, 2)`, which does not match its annotated grade `((Files, 0, 2), (Locks, 0, 1))`
    Note: the effect inequality `(Locks, 0, 2) <= ((Files, 0, 2), (Locks, 0, 1))` does not hold
  
  File "resource_levels_by_resource_reject.tpe", lines 23-29, characters 19-17:
  23 | let three_files () : unit # (0, 2) =
                          ^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Files, 0, 3)`, which does not match its annotated grade `(0, 2)`
    Note: the effect inequality `(Files, 0, 3) <= (0, 2)` does not hold
  
  File "resource_levels_by_resource_reject.tpe", lines 36-37, characters 2-3:
  36 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(Locks, 1, 1)` accumulated since it was bound, which is not below its box grade `(Files, 0, 1)`
    File "resource_levels_by_resource_reject.tpe", line 34, characters 25-26:
    34 |   box (Files, 0, 1) 7 as x in
                                  ^
    `x` is bound here
    File "resource_levels_by_resource_reject.tpe", line 35, characters 2-17:
    35 |   perform Lock ();
           ^^^^^^^^^^^^^^^
    grade `(Locks, 1, 1)` accumulates here (operation `Lock`)
    Note: the resource inequality `(Locks, 1, 1) <= (Files, 0, 1)` does not hold
  ======================================================================
  resource_levels_ranges.tpe
  ======================================================================
  === Run 1 ===
  return (File "a")
  State: []
  
  ======================================================================
  resource_levels_reject.tpe
  ======================================================================
  File "resource_levels_reject.tpe", lines 13-19, characters 13-17:
  13 | let three () : unit # (0, 2) =
                    ^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(0, 3)`, which does not match its annotated grade `(0, 2)`
    Note: the effect inequality `(0, 3) <= (0, 2)` does not hold
  
  File "resource_levels_reject.tpe", lines 26-27, characters 2-3:
  26 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(0, 1)` accumulated since it was bound, which is not below its box grade `(0, 0)`
    File "resource_levels_reject.tpe", line 23, characters 18-19:
    23 |   box (0, 0) 7 as x in
                           ^
    `x` is bound here
    File "resource_levels_reject.tpe", line 24, characters 10-26:
    24 |   let f = perform Open "f" in
                   ^^^^^^^^^^^^^^^^
    grade `(1, 1)` accumulates here (operation `Open`)
    File "resource_levels_reject.tpe", line 25, characters 2-17:
    25 |   perform Close f;
           ^^^^^^^^^^^^^^^
    grade `(-1, 0)` accumulates here (operation `Close`)
    Note: the resource inequality `(0, 1) <= (0, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 31, characters 0-20:
  31 | default Close f = ()
       ^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Close` has grade `(0, 0)`, which does not match the declared grade `(-1, 0)` of `Close`
    File "resource_levels_reject.tpe", line 10, characters 0-40:
    10 | operation Close : file ~> unit # (-1, 0)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Close` is declared here
    Note: the effect inequality `(0, 0) <= (-1, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 38, characters 17-35:
  38 |   | Close f k -> continue k with ()
                        ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `(0, 0)` accumulated since it was bound, which is not below its box grade `(-1, 0)`
    File "resource_levels_reject.tpe", line 38, characters 12-13:
    38 |   | Close f k -> continue k with ()
                     ^
    `k` is bound here
    Note: the resource inequality `(0, 0) <= (-1, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 42, characters 0-29:
  42 | default Open name = File name
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Open` has grade `(0, 0)`, which does not match the declared grade `(1, 1)` of `Open`
    File "resource_levels_reject.tpe", line 9, characters 0-40:
    9 | operation Open : string ~> file # (1, 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Open` is declared here
    Note: the effect inequality `(0, 0) <= (1, 1)` does not hold
  
  File "resource_levels_reject.tpe", line 49, characters 19-44:
  49 |   | Open name k -> continue k with File name
                          ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `(0, 0)` accumulated since it was bound, which is not below its box grade `(1, 1)`
    File "resource_levels_reject.tpe", line 49, characters 14-15:
    49 |   | Open name k -> continue k with File name
                       ^
    `k` is bound here
    Note: the resource inequality `(0, 0) <= (1, 1)` does not hold
  
  File "resource_levels_reject.tpe", lines 53-56, characters 18-3:
  53 | let rotate_late f : file # (-1, 0, 0) =
                         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(0, 1)`, which does not match its annotated grade `(-1, 0, 0)`
    Note: the effect inequality `(0, 1) <= (-1, 0, 0)` does not hold
  ======================================================================
  shadow_label.tpe
  ======================================================================
  File "shadow_label.tpe", line 2, characters 29-33:
  2 | type bull = Tail of string | Horn of bull
                                   ^^^^
  Syntax error: Label `Horn` defined multiple times
  ======================================================================
  shadow_type.tpe
  ======================================================================
  File "shadow_type.tpe", line 3, characters 5-8:
  3 | type cow = Hoof of bool
           ^^^
  Syntax error: Type `cow` defined multiple times
  ======================================================================
  string_reject_newline_location.tpe
  ======================================================================
  File "string_reject_newline_location.tpe", line 6, characters 8-17:
  6 | run (s, undefined)
              ^^^^^^^^^
  Syntax error: Unknown name `undefined`
  ======================================================================
  termination.tpe
  ======================================================================
  === Run 1 ===
  return (6, 3, 3::2::1::[])
  State: []
  
  === Run 2 ===
  return (8, 3)
  State: []
  
  === Run 3 ===
  return ((1, "a")::(2, "b")::[], 3)
  State: []
  
  === Run 4 ===
  return (1::3::2::4::[])
  State: []
  
  === Run 5 ===
  return (6, 3)
  State: []
  
  === Run 6 ===
  return (1::2::3::[], 89)
  State: []
  
  ======================================================================
  termination_reject_ackermann.tpe
  ======================================================================
  File "termination_reject_ackermann.tpe", line 8, characters 28-43:
  8 |   | (m + 1, n + 1) -> ack m (ack (m + 1) n)
                                  ^^^^^^^^^^^^^^^
  Typing error: The recursive function `ack` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_ackermann.tpe", lines 4-8, characters 12-43:
    4 | let rec ack m n =
                    ^^^^^
    `ack` is defined here
    File "termination_reject_ackermann.tpe", line 8, characters 33-40:
    8 |   | (m + 1, n + 1) -> ack m (ack (m + 1) n)
                                         ^^^^^^^
    argument 1 here is not a structural part of parameter 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  termination_reject_countdown.tpe
  ======================================================================
  File "termination_reject_countdown.tpe", line 4, characters 49-66:
  4 | let rec countdown n = if n = 0 then [] else n :: countdown (n - 1)
                                                       ^^^^^^^^^^^^^^^^^
  Typing error: The recursive function `countdown` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_countdown.tpe", line 4, characters 18-66:
    4 | let rec countdown n = if n = 0 then [] else n :: countdown (n - 1)
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `countdown` is defined here
    File "termination_reject_countdown.tpe", line 4, characters 59-66:
    4 | let rec countdown n = if n = 0 then [] else n :: countdown (n - 1)
                                                                   ^^^^^^^
    argument 1 here is not a structural part of parameter 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  termination_reject_escape.tpe
  ======================================================================
  File "termination_reject_escape.tpe", line 4, characters 22-26:
  4 | let rec loop n = n |> loop
                            ^^^^
  Typing error: The recursive function `loop` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_escape.tpe", line 4, characters 13-26:
    4 | let rec loop n = n |> loop
                     ^^^^^^^^^^^^^
    `loop` is defined here
    File "termination_reject_escape.tpe", line 4, characters 22-26:
    4 | let rec loop n = n |> loop
                              ^^^^
    `loop` is used here without its argument 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  termination_reject_increasing.tpe
  ======================================================================
  File "termination_reject_increasing.tpe", line 3, characters 36-46:
  3 | let rec up n = if n = 0 then 0 else up (n + 1)
                                          ^^^^^^^^^^
  Typing error: The recursive function `up` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_increasing.tpe", line 3, characters 11-46:
    3 | let rec up n = if n = 0 then 0 else up (n + 1)
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `up` is defined here
    File "termination_reject_increasing.tpe", line 3, characters 39-46:
    3 | let rec up n = if n = 0 then 0 else up (n + 1)
                                               ^^^^^^^
    argument 1 here is not a structural part of parameter 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  termination_reject_loop.tpe
  ======================================================================
  File "termination_reject_loop.tpe", line 3, characters 14-17:
  3 | let rec u x = u x
                    ^^^
  Typing error: The recursive function `u` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_loop.tpe", line 3, characters 10-17:
    3 | let rec u x = u x
                  ^^^^^^^
    `u` is defined here
    File "termination_reject_loop.tpe", line 3, characters 16-17:
    3 | let rec u x = u x
                        ^
    argument 1 here is not a structural part of parameter 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  termination_reject_spin.tpe
  ======================================================================
  File "termination_reject_spin.tpe", line 3, characters 17-23:
  3 | let rec spin n = spin n
                       ^^^^^^
  Typing error: The recursive function `spin` might not terminate: no argument decreases structurally in every recursive call
    File "termination_reject_spin.tpe", line 3, characters 13-23:
    3 | let rec spin n = spin n
                     ^^^^^^^^^^
    `spin` is defined here
    File "termination_reject_spin.tpe", line 3, characters 22-23:
    3 | let rec spin n = spin n
                              ^
    argument 1 here is not a structural part of parameter 1
    Note: match the parameter against a constructor, a list `x :: xs` or a successor `m + 1`, and pass the part in the recursive call
  ======================================================================
  test_equality.tpe
  ======================================================================
  === Run 1 ===
  return true
  State: []
  
  === Run 2 ===
  return false
  State: []
  
  === Run 3 ===
  return true
  State: []
  
  === Run 4 ===
  return false
  State: []
  
  === Run 5 ===
  return false
  State: []
  
  === Run 6 ===
  return true
  State: []
  
  ======================================================================
  test_less_then.tpe
  ======================================================================
  === Run 1 ===
  return false
  State: []
  
  === Run 2 ===
  return true
  State: []
  
  === Run 3 ===
  return false
  State: []
  
  === Run 4 ===
  return false
  State: []
  
  === Run 5 ===
  return true
  State: []
  
  === Run 6 ===
  return false
  State: []
  
  === Run 7 ===
  return false
  State: []
  
  === Run 8 ===
  return "composite values"
  State: []
  
  === Run 9 ===
  return true
  State: []
  
  === Run 10 ===
  return false
  State: []
  
  ======================================================================
  test_mocked_ops.tpe
  ======================================================================
  === Run 1 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    7,
    { resource_0 ↦ Fresh (Model "Sword") # 5 },
    7,
    { resource_1 ↦ Fresh (Model "Hammer") # 5 },
    5,
    5
  ]
  
  ======================================================================
  test_precedence_and_associativity.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: []
  
  === Run 2 ===
  return 2
  State: []
  
  === Run 3 ===
  return 5
  State: []
  
  === Run 4 ===
  return 1
  State: []
  
  === Run 5 ===
  return 5
  State: []
  
  === Run 6 ===
  return 3
  State: []
  
  === Run 7 ===
  return 27.
  State: []
  
  === Run 8 ===
  return true
  State: []
  
  === Run 9 ===
  return 22
  State: []
  
  ======================================================================
  test_stdlib.tpe
  ======================================================================
  === Run 1 ===
  return "test less"
  State: []
  
  === Run 2 ===
  return true
  State: []
  
  === Run 3 ===
  return false
  State: []
  
  === Run 4 ===
  return false
  State: []
  
  === Run 5 ===
  return "test equal"
  State: []
  
  === Run 6 ===
  return true
  State: []
  
  === Run 7 ===
  return true
  State: []
  
  === Run 8 ===
  return "test tilda_minus"
  State: []
  
  === Run 9 ===
  return -3.14159
  State: []
  
  === Run 10 ===
  return -1.
  State: []
  
  === Run 11 ===
  return "test natural number operations"
  State: []
  
  === Run 12 ===
  return 4
  State: []
  
  === Run 13 ===
  return 4
  State: []
  
  === Run 14 ===
  return 19
  State: []
  
  === Run 15 ===
  return 0
  State: []
  
  === Run 16 ===
  return 2
  State: []
  
  === Run 17 ===
  return 33
  State: []
  
  === Run 18 ===
  return 0
  State: []
  
  === Run 19 ===
  return 2
  State: []
  
  === Run 20 ===
  return 0
  State: []
  
  === Run 21 ===
  return "test float operations"
  State: []
  
  === Run 22 ===
  return 8.
  State: []
  
  === Run 23 ===
  return 5.84
  State: []
  
  === Run 24 ===
  return 8.478
  State: []
  
  === Run 25 ===
  return 0.44
  State: []
  
  === Run 26 ===
  return 1.16296296296
  State: []
  
  === Run 27 ===
  return infinity
  State: []
  
  === Run 28 ===
  return "13"
  State: []
  
  === Run 29 ===
  return "(1, 2, 3)::[]"
  State: []
  
  === Run 30 ===
  return "(1, 2, 3)"
  State: []
  
  === Run 31 ===
  return "fun x \226\134\166 return x"
  State: []
  
  === Run 32 ===
  return "test some and none"
  State: []
  
  === Run 33 ===
  return None
  State: []
  
  === Run 34 ===
  return (Some 3)
  State: []
  
  === Run 35 ===
  return "test ignore"
  State: []
  
  === Run 36 ===
  return ()
  State: []
  
  === Run 37 ===
  return "test not"
  State: []
  
  === Run 38 ===
  return false
  State: []
  
  === Run 39 ===
  return "test compare"
  State: []
  
  === Run 40 ===
  return true
  State: []
  
  === Run 41 ===
  return true
  State: []
  
  === Run 42 ===
  return true
  State: []
  
  === Run 43 ===
  return true
  State: []
  
  === Run 44 ===
  return true
  State: []
  
  === Run 45 ===
  return "test range"
  State: []
  
  === Run 46 ===
  return (4::5::6::7::8::9::[])
  State: []
  
  === Run 47 ===
  return "test map"
  State: []
  
  === Run 48 ===
  return (1::4::9::16::25::[])
  State: []
  
  === Run 49 ===
  return "test take"
  State: []
  
  === Run 50 ===
  return 5
  State: []
  
  === Run 51 ===
  return (2::5::8::11::14::17::20::23::26::29::32::35::38::41::44::47::50::53::56::59::62::[])
  State: []
  
  === Run 52 ===
  return "test fold_left and fold_right"
  State: []
  
  === Run 53 ===
  return 89
  State: []
  
  === Run 54 ===
  return 161
  State: []
  
  === Run 55 ===
  return "test forall, exists and mem"
  State: []
  
  === Run 56 ===
  return false
  State: []
  
  === Run 57 ===
  return true
  State: []
  
  === Run 58 ===
  return false
  State: []
  
  === Run 59 ===
  return "test filter"
  State: []
  
  === Run 60 ===
  return (4::5::[])
  State: []
  
  === Run 61 ===
  return "test complement and intersection"
  State: []
  
  === Run 62 ===
  return (1::3::5::6::[])
  State: []
  
  === Run 63 ===
  return (2::4::[])
  State: []
  
  === Run 64 ===
  return "test zip and unzip"
  State: []
  
  === Run 65 ===
  return ((1, "a")::(2, "b")::(3, "c")::[])
  State: []
  
  === Run 66 ===
  return (1::2::3::[], "a"::"b"::"c"::[])
  State: []
  
  === Run 67 ===
  return "test reverse"
  State: []
  
  === Run 68 ===
  return (5::4::3::2::1::[])
  State: []
  
  === Run 69 ===
  return "test concatenate lists"
  State: []
  
  === Run 70 ===
  return (1::2::3::4::5::6::[])
  State: []
  
  === Run 71 ===
  return "test length, hd and tl"
  State: []
  
  === Run 72 ===
  return 5
  State: []
  
  === Run 73 ===
  return (Some 1)
  State: []
  
  === Run 74 ===
  return (Some (2::3::4::[]))
  State: []
  
  === Run 75 ===
  return "test min and max"
  State: []
  
  === Run 76 ===
  return 1
  State: []
  
  === Run 77 ===
  return 2
  State: []
  
  === Run 78 ===
  return "test odd and even"
  State: []
  
  === Run 79 ===
  return false
  State: []
  
  === Run 80 ===
  return true
  State: []
  
  === Run 81 ===
  return "test id"
  State: []
  
  === Run 82 ===
  return 5
  State: []
  
  === Run 83 ===
  return (fun x ↦ return x)
  State: []
  
  === Run 84 ===
  return "test compose and reverse apply"
  State: []
  
  === Run 85 ===
  return 196
  State: []
  
  === Run 86 ===
  return 7
  State: []
  
  === Run 87 ===
  return "test fst and snd"
  State: []
  
  === Run 88 ===
  return "foo"
  State: []
  
  === Run 89 ===
  return 4
  State: []
  
  ======================================================================
  test_temporal.tpe
  ======================================================================
  === Run 1 ===
  return 0
  State: []
  
  === Run 2 ===
  return 0
  State: [
    3
  ]
  
  === Run 3 ===
  return 1
  State: [
    9,
    2,
    3
  ]
  
  === Run 4 ===
  return 11
  State: [
    5
  ]
  
  === Run 5 ===
  return 11
  State: [
    10,
    5
  ]
  
  === Run 6 ===
  return ()
  State: [
    24,
    24,
    24,
    23,
    23,
    42
  ]
  
  === Run 7 ===
  return resource_0
  State: [
    5,
    { resource_0 ↦ 11 # 3 },
    3
  ]
  
  === Run 8 ===
  return 42
  State: [
    { resource_0 ↦ 42 # 3 },
    5
  ]
  
  === Run 9 ===
  return (43, "test")
  State: [
    2,
    10,
    { resource_0 ↦ (43, 99, "test") # 3 },
    3
  ]
  
  ======================================================================
  time_fold_delays.tpe
  ======================================================================
  === Run 1 ===
  return 42
  State: [
    { resource_0 ↦ 42 # 7, resource_2 ↦ <fun> # 7 },
    3,
    4
  ]
  
  ======================================================================
  time_reject_within.tpe
  ======================================================================
  File "time_reject_within.tpe", line 6, characters 0-47:
  6 | operation Heat : unit ~> unit # 2 within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `time-lower-bound` grading monoid, which does not use them
  ======================================================================
  toplevel_let_scope.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: []
  
  === Run 2 ===
  return 3
  State: []
  
  ======================================================================
  toplevel_value_print.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: []
  
  === Run 2 ===
  return (1, Some 1)
  State: []
  
  === Run 3 ===
  return ((1, Some 1), fun z ↦ return z)
  State: []
  
  === Run 4 ===
  return (Some (1, Some 1))
  State: []
  
  ======================================================================
  traces_annotation.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  traces_default.tpe
  ======================================================================
  === Run 1 ===
  return (Fresh (Model "Sword"))
  State: [
    { resource_1 ↦ <fun> # {Heat; Extrude; Cool} },
    {1},
    {3},
    {2}
  ]
  
  ======================================================================
  traces_intervals_bounds.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: []
  
  ======================================================================
  traces_intervals_default_bounds.tpe
  ======================================================================
  File "traces_intervals_default_bounds.tpe", line 14, characters 0-28:
  14 | default Extrude () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Extrude` has grade `[{1}, {1}]`, which does not match the declared grade `[{3}, {5}]` of `Extrude`
    File "traces_intervals_default_bounds.tpe", line 12, characters 0-71:
    12 | operation Extrude : unit ~> unit # [{Extrude}, {Extrude}] within [3, 5]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{3}, {5}]` does not hold
  ======================================================================
  traces_intervals_default_open_reject.tpe
  ======================================================================
  File "traces_intervals_default_open_reject.tpe", line 14, characters 0-25:
  14 | default Send () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` has grade `[{3}, {3}]`, which does not match the declared grade `[{1}, {2}]` of `Send`
    File "traces_intervals_default_open_reject.tpe", line 11, characters 0-62:
    11 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
    Note: the effect inequality `[{3}, {3}] <= [{1}, {2}]` does not hold
  
  File "traces_intervals_default_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{2}, {3}]` of `Beep`
    File "traces_intervals_default_open_reject.tpe", line 12, characters 0-62:
    12 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 3]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{2}, {3}]` does not hold
  ======================================================================
  traces_normalise.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_0 ↦ 42 # {Heat; 4 | 4; Heat} }
  ]
  
  ======================================================================
  traces_open_bounds.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  traces_open_bounds_reject.tpe
  ======================================================================
  File "traces_open_bounds_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "traces_open_bounds_reject.tpe", line 15, characters 15-19:
    15 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "traces_open_bounds_reject.tpe", line 16, characters 2-15:
    16 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "traces_open_bounds_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "traces_open_bounds_reject.tpe", line 12, characters 0-52:
    12 | operation Beep : unit ~> unit # {Beep} within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  traces_reject_allowance.tpe
  ======================================================================
  File "traces_reject_allowance.tpe", lines 15-16, characters 2-3:
  15 |   unbox r as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `{Heat}` accumulated since it was bound, which is not below its box grade `{1}`
    File "traces_reject_allowance.tpe", line 13, characters 14-15:
    13 |   box 1 42 as r in
                       ^
    `r` is bound here
    File "traces_reject_allowance.tpe", line 14, characters 2-17:
    14 |   perform Heat ();
           ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Heat} <= {1}` does not hold
  ======================================================================
  traces_reject_bounds.tpe
  ======================================================================
  File "traces_reject_bounds.tpe", line 8, characters 0-52:
  8 | operation Heat : unit ~> unit # {Heat} within [3, 0]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The running-time bounds of operation `Heat` must satisfy `lo <= hi`
  ======================================================================
  traces_reject_bounds_declared.tpe
  ======================================================================
  File "traces_reject_bounds_declared.tpe", line 11, characters 0-61:
  11 | operation Send : string ~> unit # {Tx | Tx; Tx} within [2, 6]
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Operation `Send` is compound, so its running-time bounds follow from its grade `{Tx | Tx; Tx}` and must not be declared
  ======================================================================
  traces_reject_bounds_zero.tpe
  ======================================================================
  File "traces_reject_bounds_zero.tpe", line 9, characters 0-52:
  9 | operation Heat : unit ~> unit # {Heat} within [0, 0]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The upper running-time bound of operation `Heat` must be positive
  ======================================================================
  traces_reject_default_bounds.tpe
  ======================================================================
  File "traces_reject_default_bounds.tpe", line 13, characters 0-28:
  13 | default Extrude () = delay 6
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Extrude` has grade `{6}`, which does not match the declared grade `{5}` of `Extrude`
    File "traces_reject_default_bounds.tpe", line 11, characters 0-58:
    11 | operation Extrude : unit ~> unit # {Extrude} within [3, 5]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the effect inequality `{6} <= {5}` does not hold
  ======================================================================
  traces_reject_default_nonatomic.tpe
  ======================================================================
  File "traces_reject_default_nonatomic.tpe", line 19, characters 0-39:
  19 | default PrintModel m = delay 6; Fresh m
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: A default implementation may only be given for an atomic operation, but the grade of `PrintModel` is `{Heat; Extrude; Cool}`; handle it with a handler in terms of the operations it names
  ======================================================================
  traces_reject_fractional_bound.tpe
  ======================================================================
  File "traces_reject_fractional_bound.tpe", line 10, characters 47-50:
  10 | operation Heat : unit ~> unit # {Heat} within [1/2, 1]
                                                      ^^^
  Syntax error: In the `traces-timed-upper-bound` grading monoid, running-time bounds are delays, and delays are whole numbers of time steps; did you mean to use one of the `traces-timed-lower-bound-rational`, `traces-timed-upper-bound-rational`, `traces-timed-interval-rational`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `mode-times` or `event-separation` grading monoids?
  ======================================================================
  traces_reject_missing_within.tpe
  ======================================================================
  File "traces_reject_missing_within.tpe", line 10, characters 0-38:
  10 | operation Heat : unit ~> unit # {Heat}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Atomic operation `Heat` needs running-time bounds `within [lo, hi]` under the `traces-timed-upper-bound` grading monoid
  ======================================================================
  traces_reject_order.tpe
  ======================================================================
  File "traces_reject_order.tpe", line 24, characters 6-31:
  24 |       continue k with (Fresh m)
             ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Cool; Extrude; Heat}` accumulated since it was bound, which is not below its box grade `{Heat; Extrude; Cool}`
    File "traces_reject_order.tpe", line 20, characters 17-18:
    20 |   | PrintModel m k ->
                          ^
    `k` is bound here
    File "traces_reject_order.tpe", line 21, characters 6-21:
    21 |       perform Cool ();
               ^^^^^^^^^^^^^^^
    grade `{Cool}` accumulates here (operation `Cool`)
    File "traces_reject_order.tpe", line 22, characters 6-24:
    22 |       perform Extrude ();
               ^^^^^^^^^^^^^^^^^^
    grade `{Extrude}` accumulates here (operation `Extrude`)
    File "traces_reject_order.tpe", line 23, characters 6-21:
    23 |       perform Heat ();
               ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Cool; Extrude; Heat} <= {Heat; Extrude; Cool}` does not hold
  ======================================================================
  traces_reject_self_retry.tpe
  ======================================================================
  File "traces_reject_self_retry.tpe", line 11, characters 0-53:
  11 | operation Send : string ~> unit # {Send | Send; Send}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Compound operation `Send` may not name itself in its grade `{Send | Send; Send}`
  ======================================================================
  traces_reject_undecided_condition.tpe
  ======================================================================
  File "traces_reject_undecided_condition.tpe", line 20, characters 49-50:
  20 | run handle (perform Op (); perform Tick ()) with h
                                                        ^
  Typing error: The condition `∀ε_Op. ε_Op · {1} <= {1} · ε_Op` of the case for `Op` cannot be established
    File "traces_reject_undecided_condition.tpe", line 18, characters 0-78:
    18 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `h` is defined here
    File "traces_reject_undecided_condition.tpe", line 16, characters 0-31:
    16 | operation Op : unit ~> unit # 1
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "traces_reject_undecided_condition.tpe", line 18, characters 33-34:
    18 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
                                          ^
    `k` may have any grade `ε_Op`
    File "traces_reject_undecided_condition.tpe", line 18, characters 27-78:
    18 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` begins here
    Note: a run requires the effect inequality to hold for every grade the continuation `k` may have, and it is neither derived nor refuted
  ======================================================================
  traces_reject_unknown_event.tpe
  ======================================================================
  File "traces_reject_unknown_event.tpe", line 11, characters 0-53:
  11 | operation PrintModel : unit ~> unit # {Heat; Extrude}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Unknown event `Extrude` in the grade of operation `PrintModel`
  ======================================================================
  tydef.tpe
  ======================================================================
  === Run 1 ===
  return Tail
  State: []
  
  === Run 2 ===
  return (Node (10, Empty, Node (20, Empty, Empty)))
  State: []
  
  ======================================================================
  type_annotations.tpe
  ======================================================================
  === Run 1 ===
  return (fun y ↦ return (fun z ↦ let b = (let b = z y in
                                           b true) in
                                  return b))
  State: []
  
  ======================================================================
  typing.tpe
  ======================================================================
  === Run 1 ===
  return (fun y ↦ return y)
  State: []
  
  === Run 2 ===
  return (rec h ...)
  State: []
  
  ======================================================================
  unbox_annotation.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_0 ↦ (1, 2) # 5 },
    5
  ]
  
  ======================================================================
  unbox_annotation_reject.tpe
  ======================================================================
  File "unbox_annotation_reject.tpe", line 8, characters 8-21:
  8 |   unbox (boxed : nat) as (l, r) in l + r
              ^^^^^^^^^^^^^
  Typing error: This expression has type `[_](nat × nat)` but is annotated with `nat`
  ======================================================================
  unbox_nested.tpe
  ======================================================================
  ======================================================================
  unbox_nested_reject_lower.tpe
  ======================================================================
  File "unbox_nested_reject_lower.tpe", lines 14-15, characters 2-3:
  14 |   unbox y as v in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `y` is unboxed with grade `[0.5, 0.5]` accumulated since it was bound, which is not below its box grade `[1, 3]`
    File "unbox_nested_reject_lower.tpe", line 12, characters 13-14:
    12 |   unbox x as y in
                      ^
    `y` is bound here
    File "unbox_nested_reject_lower.tpe", line 13, characters 2-11:
    13 |   delay 1/2;
           ^^^^^^^^^
    grade `[0.5, 0.5]` accumulates here (delay)
    Note: the resource inequality `[0.5, 0.5] <= [1, 3]` does not hold
  
  File "unbox_nested_reject_lower.tpe", lines 24-25, characters 2-3:
  24 |   unbox y as v in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `y` is unboxed with grade `[0.5, 0.5]` accumulated since it was bound, which is not below its box grade `[1, 3]`
    File "unbox_nested_reject_lower.tpe", line 22, characters 13-14:
    22 |   unbox x as y in
                      ^
    `y` is bound here
    File "unbox_nested_reject_lower.tpe", line 23, characters 2-11:
    23 |   delay 1/2;
           ^^^^^^^^^
    grade `[0.5, 0.5]` accumulates here (delay)
    File "unbox_nested_reject_lower.tpe", lines 22-25, characters 2-3:
    22 |   unbox x as y in
           ^^^^^^^^^^^^^^^
    the inequality goes through the unboxing of `x` here
    Note: the resource inequality `[0.5, 0.5] <= [1, 3]` does not hold
  ======================================================================
  unbox_nested_reject_upper.tpe
  ======================================================================
  File "unbox_nested_reject_upper.tpe", lines 14-15, characters 2-3:
  14 |   unbox y as v in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `y` is unboxed with grade `[4, 4]` accumulated since it was bound, which is not below its box grade `[1, 3]`
    File "unbox_nested_reject_upper.tpe", line 12, characters 13-14:
    12 |   unbox x as y in
                      ^
    `y` is bound here
    File "unbox_nested_reject_upper.tpe", line 13, characters 2-9:
    13 |   delay 4;
           ^^^^^^^
    grade `[4, 4]` accumulates here (delay)
    Note: the resource inequality `[4, 4] <= [1, 3]` does not hold
  
  File "unbox_nested_reject_upper.tpe", lines 24-25, characters 2-3:
  24 |   unbox y as v in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `y` is unboxed with grade `[4, 4]` accumulated since it was bound, which is not below its box grade `[1, 3]`
    File "unbox_nested_reject_upper.tpe", line 22, characters 13-14:
    22 |   unbox x as y in
                      ^
    `y` is bound here
    File "unbox_nested_reject_upper.tpe", line 23, characters 2-9:
    23 |   delay 4;
           ^^^^^^^
    grade `[4, 4]` accumulates here (delay)
    File "unbox_nested_reject_upper.tpe", lines 22-25, characters 2-3:
    22 |   unbox x as y in
           ^^^^^^^^^^^^^^^
    the inequality goes through the unboxing of `x` here
    Note: the resource inequality `[4, 4] <= [1, 3]` does not hold
  ======================================================================
  unhandled_continue.tpe
  ======================================================================
  === Run 1 (unhandled operation) ===
  perform Get () (op_var. (let x = return op_var in
                           let b = (+) x in
                           b 1))
  
  === Run 2 ===
  return 2
  State: []
  
  === Run 3 (unhandled operation) ===
  perform Get () (op_var. handle
                            return op_var
                          with h)
  
  === Run 4 ===
  return 42
  State: [
    { resource_1 ↦ <fun> # 1 },
    1
  ]
  
  ======================================================================
  use_undefined_type.tpe
  ======================================================================
  File "use_undefined_type.tpe", line 1, characters 18-21:
  1 | type foo = One of bar | Two of nat
                        ^^^
  Syntax error: Unknown name `bar`
  ======================================================================
  windowed_schedules.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    2,
    1
  ]
  
  === Run 2 ===
  return ()
  State: [
    2,
    { resource_1 ↦ <fun> # (1, (Send, {0})) },
    1
  ]
  
  === Run 3 ===
  return 7
  State: [
    { resource_0 ↦ 7 # [2, 4] },
    2,
    1
  ]
  
  ======================================================================
  windowed_schedules_reject.tpe
  ======================================================================
  File "windowed_schedules_reject.tpe", lines 11-13, characters 17-17:
  11 | let late_send () : unit # (4, (Send, {2})) =
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(4, (Send, {3}))`, which does not match its annotated grade `(4, (Send, {2}))`
    Note: the effect inequality `(4, (Send, {3})) <= (4, (Send, {2}))` does not hold
  
  File "windowed_schedules_reject.tpe", lines 16-18, characters 12-17:
  16 | let slow () : unit # ([2, 3], (Send, {1 | 2})) =
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `([2, 4], (Send, {1; (0 | 1 | 2)}))`, which does not match its annotated grade `([2, 3], (Send, {1 | 2}))`
    Note: the effect inequality `([2, 4], (Send, {1; (0 | 1 | 2)})) <= ([2, 3], (Send, {1 | 2}))` does not hold
  
  File "windowed_schedules_reject.tpe", lines 25-26, characters 2-3:
  25 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(2, (Send, {0}))` accumulated since it was bound, which is not below its box grade `[2, 4]`
    File "windowed_schedules_reject.tpe", line 22, characters 18-19:
    22 |   box [2, 4] 7 as x in
                           ^
    `x` is bound here
    File "windowed_schedules_reject.tpe", line 23, characters 2-17:
    23 |   perform Send ();
           ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    File "windowed_schedules_reject.tpe", line 24, characters 2-9:
    24 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `(2, (Send, {0})) <= [2, 4]` does not hold
  
  File "windowed_schedules_reject.tpe", line 33, characters 51-69:
  33 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                                                          ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(2, (Send, {0 | 1}))` accumulated since it was bound, which is not below its box grade `(1, (Send, {0}))`
    File "windowed_schedules_reject.tpe", line 33, characters 12-13:
    33 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                     ^
    `k` is bound here
    File "windowed_schedules_reject.tpe", line 33, characters 17-32:
    33 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                          ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    File "windowed_schedules_reject.tpe", line 33, characters 34-49:
    33 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                                           ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    Note: the resource inequality `(2, (Send, {0 | 1})) <= (1, (Send, {0}))` does not hold
  
  File "windowed_schedules_reject.tpe", line 36, characters 15-58:
  36 | let renamed () : unit # (1, (Recv, {0})) = perform Send ()
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(1, (Send, {0}))`, which does not match its annotated grade `(1, (Recv, {0}))`
    Note: the effect inequality `(1, (Send, {0})) <= (1, (Recv, {0}))` does not hold

The programs of the regular trace grade, run above under its implementation
by symbolic derivatives, 'regex-upper-bound-symbolic', under its implementation by
automata, 'regex-upper-bound-letter-automata':

  $ for f in literals_reject_empty.tpe literals_regular.tpe regular_*.tpe
  > do
  >   echo "======================================================================"
  >   echo "$f (regex-upper-bound-letter-automata)"
  >   echo "======================================================================"
  >   g=$(support/header_options.exe -grades $f)
  >   ../tempore --grades ${g%-symbolic}-letter-automata $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "literals_reject_empty.tpe", line 9, characters 19-33:
  9 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: In the `regex-upper-bound-letter-automata` grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_regular.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Send | Read*} }
  ]
  
  === Run 2 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 3 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 4 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {_} }
  ]
  
  === Run 5 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 3; (Send | Write)*} }
  ]
  
  === Run 6 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(Send; 2)*} }
  ]
  
  === Run 7 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(_ & ~Revoke)*} }
  ]
  
  === Run 8 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Open; (Read | Write)*; Close} }
  ]
  
  === Run 9 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3 | 2*} }
  ]
  
  === Run 10 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3} }
  ]
  
  === Run 11 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {0} }
  ]
  
  === Run 12 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 1; (0 | 1; (0 | 1)); Send} }
  ]
  
  === Run 13 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; (0 | 1); Send} }
  ]
  
  === Run 14 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; 1*} }
  ]
  
  === Run 15 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {2; (0 | 1; (0 | 1))} }
  ]
  
  === Run 16 ===
  return 0
  State: [
    { resource_0 ↦ 1 # ⊤ }
  ]
  
  ======================================================================
  regular_auth.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return 42
  State: [
    { resource_0 ↦ 42 # {3; _*} },
    {4}
  ]
  
  ======================================================================
  regular_protocol.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  ======================================================================
  regular_reject_auth.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_auth.tpe", lines 19-21, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 17, characters 36-37:
    17 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 26-27, characters 2-5:
  26 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 24, characters 41-42:
    24 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 25, characters 2-19:
    25 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 33-34, characters 2-3:
  33 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 30, characters 20-21:
    30 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 31, characters 2-18:
    31 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 32, characters 2-9:
    32 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_bounds.tpe", line 9, characters 0-52:
  9 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `regex-upper-bound-letter-automata` grading monoid, which does not use them
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 18-23, characters 23-3:
  18 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 29-30, characters 2-5:
  29 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 27, characters 23-24:
    27 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 28, characters 2-49:
    28 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_protocol.tpe", line 21, characters 6-23:
  21 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 17, characters 15-16:
    17 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 18, characters 6-21:
    18 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 19, characters 6-22:
    19 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 20, characters 14-29:
    20 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 23-24, characters 16-34:
  23 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold

The programs of the regular trace grades of timed operations, run above under
their implementations by symbolic derivatives, under their implementations by
automata, the programs over rational delays excepted:

  $ for f in regex_timed_*.tpe
  > do
  >   g=$(support/header_options.exe -grades $f)
  >   case $g in *-rational-symbolic) continue;; esac
  >   grades=${g%-symbolic}-letter-automata
  >   echo "======================================================================"
  >   echo "$f ($grades)"
  >   echo "======================================================================"
  >   ../tempore --grades $grades $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  regex_timed_compound_named_later_reject.tpe (regex-timed-interval-letter-automata)
  ======================================================================
  File "regex_timed_compound_named_later_reject.tpe", line 10, characters 0-45:
  10 | operation Two : unit ~> unit # {Fetch; Later}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Unknown event `Later` in the grade of operation `Two`
  ======================================================================
  regex_timed_compound_wildcard.tpe (regex-timed-interval-letter-automata)
  ======================================================================
  ======================================================================
  regex_timed_interval.tpe (regex-timed-interval-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_timed_interval_reject.tpe (regex-timed-interval-letter-automata)
  ======================================================================
  File "regex_timed_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_timed_interval_reject.tpe", line 16, characters 28-29:
    16 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 17, characters 2-18:
    17 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_timed_interval_reject.tpe", lines 25-26, characters 2-5:
  25 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_timed_interval_reject.tpe", line 23, characters 28-29:
    23 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 24, characters 2-18:
    24 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_timed_interval_ticks_reject.tpe (regex-timed-interval-letter-automata)
  ======================================================================
  File "regex_timed_interval_ticks_reject.tpe", line 17, characters 6-34:
  17 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_timed_interval_ticks_reject.tpe", line 24, characters 33-61:
  24 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_timed_lower.tpe (regex-timed-lower-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {Ping; 3} },
    {1},
    {3},
    {1}
  ]
  
  ======================================================================
  regex_timed_lower_reject.tpe (regex-timed-lower-bound-letter-automata)
  ======================================================================
  File "regex_timed_lower_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_timed_lower_reject.tpe", line 17, characters 31-32:
    17 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_lower_reject.tpe", line 18, characters 2-17:
    18 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_timed_lower_reject.tpe", line 19, characters 2-9:
    19 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_timed_lower_reject.tpe", line 25, characters 29-30:
    25 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_timed_lower_reject.tpe", line 26, characters 2-10:
    26 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 34-35, characters 2-5:
  34 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_lower_reject.tpe", line 32, characters 25-26:
    32 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_timed_lower_reject.tpe", line 33, characters 2-58:
    33 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_timed_lower_ticks_reject.tpe (regex-timed-lower-bound-letter-automata)
  ======================================================================
  File "regex_timed_lower_ticks_reject.tpe", line 16, characters 6-30:
  16 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_timed_upper.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_timed_upper_open.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_timed_upper_open_reject.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  File "regex_timed_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_timed_upper_open_reject.tpe", line 15, characters 15-19:
    15 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_timed_upper_open_reject.tpe", line 16, characters 2-15:
    16 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_timed_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_timed_upper_open_reject.tpe", line 12, characters 0-52:
    12 | operation Beep : unit ~> unit # {Beep} within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_timed_upper_reject.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  File "regex_timed_upper_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_upper_reject.tpe", line 17, characters 25-26:
    17 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_timed_upper_reject.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 28-29, characters 2-5:
  28 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_timed_upper_reject.tpe", line 25, characters 30-31:
    25 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_timed_upper_reject.tpe", line 26, characters 2-18:
    26 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_timed_upper_reject.tpe", line 27, characters 2-16:
    27 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 35-36, characters 2-5:
  35 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_timed_upper_reject.tpe", line 33, characters 37-38:
    33 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_timed_upper_reject.tpe", line 34, characters 2-49:
    34 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_timed_upper_reject.tpe", lines 39-41, characters 17-17:
  39 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_timed_upper_ticks.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_timed_upper_ticks_reject.tpe (regex-timed-upper-bound-letter-automata)
  ======================================================================
  File "regex_timed_upper_ticks_reject.tpe", line 17, characters 6-23:
  17 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 22, characters 26-43:
  22 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 25, characters 27-44:
  25 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations

The programs of the regular trace grades over rational delays, run above under
their visible implementations, under their implementations by automata
('-rational-automata'):

  $ for f in regex_rational*.tpe regex_timed_rational_*.tpe
  > do
  >   g=$(support/header_options.exe -grades $f)
  >   grades=${g%-symbolic}-automata
  >   echo "======================================================================"
  >   echo "$f ($grades)"
  >   echo "======================================================================"
  >   ../tempore --grades $grades $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  regex_rational.tpe (regex-upper-bound-rational-automata)
  ======================================================================
  ======================================================================
  regex_rational_reject.tpe (regex-upper-bound-rational-automata)
  ======================================================================
  File "regex_rational_reject.tpe", lines 19-20, characters 2-3:
  19 |   unbox t as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{1}` accumulated since it was bound, which is not below its box grade `{~1}`
    File "regex_rational_reject.tpe", line 16, characters 16-17:
    16 |   box {~1} 7 as t in
                         ^
    `t` is bound here
    File "regex_rational_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 18, characters 2-11:
    18 |   delay 0.5;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    Note: the resource inequality `{1} <= {~1}` does not hold
  
  File "regex_rational_reject.tpe", lines 28-29, characters 2-3:
  28 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `{Sample; 1; Send}` accumulated since it was bound, which is not below its box grade `{Sample; [0, 1); Send}`
    File "regex_rational_reject.tpe", line 23, characters 35-38:
    23 |   box {Sample; [0, 1); Send} () as due in
                                            ^^^
    `due` is bound here
    File "regex_rational_reject.tpe", line 24, characters 10-27:
    24 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_rational_reject.tpe", line 25, characters 2-11:
    25 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 26, characters 2-11:
    26 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 27, characters 2-16:
    27 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; 1; Send} <= {Sample; [0, 1); Send}` does not hold
  
  File "regex_rational_reject.tpe", line 31, characters 14-43:
  31 | let thirds () : unit # {(1/2)*} = delay 1/3
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{1/3}`, which does not match its annotated grade `{(0.5)*}`
    Note: the effect inequality `{1/3} <= {(0.5)*}` does not hold
  
  File "regex_rational_reject.tpe", lines 36-37, characters 2-3:
  36 |   unbox w as u in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `w` is unboxed with grade `{2 | 0.5}` accumulated since it was bound, which is not below its box grade `{[1, ∞)}`
    File "regex_rational_reject.tpe", line 34, characters 23-24:
    34 |   box {[1, ∞)} () as w in
                              ^
    `w` is bound here
    File "regex_rational_reject.tpe", line 35, characters 2-34:
    35 |   if b then delay 1/2 else delay 2;
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{2 | 0.5}` accumulates here (this computation)
    Note: the resource inequality `{2 | 0.5} <= {[1, ∞)}` does not hold
    Note: the grade `{0.5}` is below `{2 | 0.5}` but not below `{[1, ∞)}`
  ======================================================================
  regex_timed_rational_interval.tpe (regex-timed-interval-rational-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{0.5}, {1.5}] },
    [{0.5}, {0.5}]
  ]
  
  ======================================================================
  regex_timed_rational_interval_default_open_reject.tpe (regex-timed-interval-rational-automata)
  ======================================================================
  File "regex_timed_rational_interval_default_open_reject.tpe", line 14, characters 0-25:
  14 | default Send () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` has grade `[{2}, {2}]`, which does not match the declared grade `[{1}, {[0, 2)}]` of `Send`
    File "regex_timed_rational_interval_default_open_reject.tpe", line 11, characters 0-62:
    11 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 2)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
    Note: the effect inequality `[{2}, {2}] <= [{1}, {[0, 2)}]` does not hold
  
  File "regex_timed_rational_interval_default_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_timed_rational_interval_default_open_reject.tpe", line 12, characters 0-62:
    12 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_timed_rational_interval_open_reject.tpe (regex-timed-interval-rational-automata)
  ======================================================================
  File "regex_timed_rational_interval_open_reject.tpe", line 12, characters 0-25:
  12 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_timed_rational_interval_open_reject.tpe", line 10, characters 0-62:
    10 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_timed_rational_interval_reject.tpe (regex-timed-interval-rational-automata)
  ======================================================================
  File "regex_timed_rational_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Sample}, {Sample}]` accumulated since it was bound, which is not below its box grade `[{0.75}, {2}]`
    File "regex_timed_rational_interval_reject.tpe", line 16, characters 30-31:
    16 |   box [3/4, 2] (Token "t") as t in
                                       ^
    `t` is bound here
    File "regex_timed_rational_interval_reject.tpe", line 17, characters 10-27:
    17 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{Sample}, {Sample}] <= [{0.75}, {2}]` does not hold
  
  File "regex_timed_rational_interval_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{0.5; Sample}, {0.5; Sample}]` accumulated since it was bound, which is not below its box grade `[{0.5}, {[0, 1)}]`
    File "regex_timed_rational_interval_reject.tpe", line 24, characters 39-40:
    24 |   box [{1/2}, {[0, 1)}] (Token "t") as t in
                                                ^
    `t` is bound here
    File "regex_timed_rational_interval_reject.tpe", line 25, characters 2-11:
    25 |   delay 1/2;
           ^^^^^^^^^
    grade `[{0.5}, {0.5}]` accumulates here (delay)
    File "regex_timed_rational_interval_reject.tpe", line 26, characters 10-27:
    26 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{0.5; Sample}, {0.5; Sample}] <= [{0.5}, {[0, 1)}]` does not hold
  ======================================================================
  regex_timed_rational_lower.tpe (regex-timed-lower-bound-rational-automata)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25}
  ]
  
  ======================================================================
  regex_timed_rational_lower_reject.tpe (regex-timed-lower-bound-rational-automata)
  ======================================================================
  File "regex_timed_rational_lower_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{0.25}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_timed_rational_lower_reject.tpe", line 17, characters 27-28:
    17 |   box {1/2} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 18, characters 2-11:
    18 |   delay 1/4;
           ^^^^^^^^^
    grade `{0.25}` accumulates here (delay)
    Note: the resource inequality `{0.25} <= {0.5}` does not hold
  
  File "regex_timed_rational_lower_reject.tpe", lines 26-27, characters 2-5:
  26 |   unbox s as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `s` is unboxed with grade `{3}` accumulated since it was bound, which is not below its box grade `{Send}`
    File "regex_timed_rational_lower_reject.tpe", line 24, characters 28-29:
    24 |   box {Send} (Token "s") as s in
                                     ^
    `s` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 25, characters 2-9:
    25 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{3} <= {Send}` does not hold
  
  File "regex_timed_rational_lower_reject.tpe", lines 36-37, characters 2-5:
  36 |   unbox p as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `p` is unboxed with grade `{(0, 1)}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_timed_rational_lower_reject.tpe", line 34, characters 27-28:
    34 |   box {1/2} (Token "p") as p in
                                    ^
    `p` is bound here
    File "regex_timed_rational_lower_reject.tpe", line 35, characters 2-15:
    35 |   some_delay ();
           ^^^^^^^^^^^^^
    grade `{(0, 1)}` accumulates here (this computation)
    Note: the resource inequality `{(0, 1)} <= {0.5}` does not hold
    Note: the grade `{1/3}` is below `{(0, 1)}` but not below `{0.5}`
  
  File "regex_timed_rational_lower_reject.tpe", line 40, characters 13-44:
  40 | let quick () : nat # {1} = perform Sample ()
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample}`, which does not match its annotated grade `{1}`
    Note: the effect inequality `{Sample} <= {1}` does not hold
  ======================================================================
  regex_timed_rational_upper.tpe (regex-timed-upper-bound-rational-automata)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25},
    {0.25}
  ]
  
  ======================================================================
  regex_timed_rational_upper_open.tpe (regex-timed-upper-bound-rational-automata)
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # {[0, 2)} },
    {1.9}
  ]
  
  ======================================================================
  regex_timed_rational_upper_open_reject.tpe (regex-timed-upper-bound-rational-automata)
  ======================================================================
  File "regex_timed_rational_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Sample}` accumulated since it was bound, which is not below its box grade `{[0, 2)}`
    File "regex_timed_rational_upper_open_reject.tpe", line 15, characters 20-24:
    15 |   box {[0, 2)} 1 as slot in
                             ^^^^
    `slot` is bound here
    File "regex_timed_rational_upper_open_reject.tpe", line 16, characters 2-19:
    16 |   perform Sample ();
           ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    Note: the resource inequality `{Sample} <= {[0, 2)}` does not hold
  
  File "regex_timed_rational_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{2}`, which does not match the declared grade `{[0, 2)}` of `Beep`
    File "regex_timed_rational_upper_open_reject.tpe", line 12, characters 0-54:
    12 | operation Beep : unit ~> unit # {Beep} within [1/2, 2)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{2} <= {[0, 2)}` does not hold
  ======================================================================
  regex_timed_rational_upper_reject.tpe (regex-timed-upper-bound-rational-automata)
  ======================================================================
  File "regex_timed_rational_upper_reject.tpe", lines 21-22, characters 2-5:
  21 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; 1/3}` accumulated since it was bound, which is not below its box grade `{1.75}`
    File "regex_timed_rational_upper_reject.tpe", line 18, characters 27-28:
    18 |   box {7/4} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 19, characters 10-27:
    19 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_timed_rational_upper_reject.tpe", line 20, characters 2-11:
    20 |   delay 1/3;
           ^^^^^^^^^
    grade `{1/3}` accumulates here (delay)
    Note: the resource inequality `{Sample; 1/3} <= {1.75}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; Send}` accumulated since it was bound, which is not below its box grade `{Send; 2}`
    File "regex_timed_rational_upper_reject.tpe", line 27, characters 31-32:
    27 |   box {Send; 2} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 28, characters 10-27:
    28 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_timed_rational_upper_reject.tpe", line 29, characters 2-16:
    29 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; Send} <= {Send; 2}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 42-43, characters 2-5:
  42 |   unbox b as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `{[0, 0.5); Send; [0, 0.5)}` accumulated since it was bound, which is not below its box grade `{1.99}`
    File "regex_timed_rational_upper_reject.tpe", line 38, characters 28-29:
    38 |   box {1.99} (Token "b") as b in
                                     ^
    `b` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 39, characters 2-16:
    39 |   short_delay ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    File "regex_timed_rational_upper_reject.tpe", line 40, characters 2-16:
    40 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_timed_rational_upper_reject.tpe", line 41, characters 2-16:
    41 |   short_delay ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    Note: the resource inequality `{[0, 0.5); Send; [0, 0.5)} <= {1.99}` does not hold
    Note: the grade `{64/129; Send; 64/129}` is below `{[0, 0.5); Send; [0, 0.5)}` but not below `{1.99}`
  
  File "regex_timed_rational_upper_reject.tpe", lines 51-52, characters 2-5:
  51 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Send; 1}` accumulated since it was bound, which is not below its box grade `{Send; ([0, 1] & ~1)}`
    File "regex_timed_rational_upper_reject.tpe", line 48, characters 43-44:
    48 |   box {Send; ([0, 1] & ~1)} (Token "l") as l in
                                                    ^
    `l` is bound here
    File "regex_timed_rational_upper_reject.tpe", line 49, characters 2-16:
    49 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_timed_rational_upper_reject.tpe", line 50, characters 2-9:
    50 |   delay 1;
           ^^^^^^^
    grade `{1}` accumulates here (delay)
    Note: the resource inequality `{Send; 1} <= {Send; ([0, 1] & ~1)}` does not hold
  
  File "regex_timed_rational_upper_reject.tpe", lines 56-58, characters 19-19:
  56 | let two_samples () : nat # {5/2} =
                          ^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample; Sample}`, which does not match its annotated grade `{2.5}`
    Note: the effect inequality `{Sample; Sample} <= {2.5}` does not hold

The examples and programs of the regular trace grades under two further
implementations, by derivatives by letters instead of minterms
('-symbolic-by-letters') and by derivatives of expressions over single letters
instead of letter sets ('-letter-derivatives'), whose outputs are those of the
implementations above, the examples over rational delays excepted:

  $ for f in ../examples/regular/*.tpe ../examples/regular_timed_ops/*.tpe \
  >   literals_reject_empty.tpe literals_regular.tpe regular_*.tpe regex_timed_*.tpe
  > do
  >   g=$(support/header_options.exe -grades $f)
  >   case $g in *-rational-symbolic) continue;; esac
  >   grades=${g%-symbolic}
  >   for variant in symbolic-by-letters letter-derivatives
  >   do
  >     echo "======================================================================"
  >     echo "$f ($grades-$variant)"
  >     echo "======================================================================"
  >     ../tempore --grades $grades-$variant $f
  >     :  # this command is here to suppress potential non-zero exit codes in the output
  >   done
  > done
  ======================================================================
  ../examples/regular/upper_bounds.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return "settled"
  State: [
    { resource_0 ↦ "settled" # {3; _*} },
    {4}
  ]
  
  ======================================================================
  ../examples/regular/upper_bounds.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return "settled"
  State: [
    { resource_0 ↦ "settled" # {3; _*} },
    {4}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/intervals.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1}, {1}],
    [{4}, {4}],
    [{1}, {1}],
    [{2}, {2}]
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/intervals.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1}, {1}],
    [{4}, {4}],
    [{1}, {1}],
    [{2}, {2}]
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/lower_bounds.tpe (regex-timed-lower-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Part "gear")
  State: [
    { resource_0 ↦ Part "gear" # {Coat; 4} },
    {1},
    {4},
    {2}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/lower_bounds.tpe (regex-timed-lower-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Part "gear")
  State: [
    { resource_0 ↦ Part "gear" # {Coat; 4} },
    {1},
    {4},
    {2}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/mail_session.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Checkpoint 5, 2)
  State: [
    { resource_0 ↦ Checkpoint 5 # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 2 ===
  return (Message (1, "Agenda", false))
  State: [
    {3},
    {1},
    {1}
  ]
  
  === Run 3 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 4 ===
  return 1
  State: [
    {1},
    {1},
    {1},
    {1}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/mail_session.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Checkpoint 5, 2)
  State: [
    { resource_0 ↦ Checkpoint 5 # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 2 ===
  return (Message (1, "Agenda", false))
  State: [
    {3},
    {1},
    {1}
  ]
  
  === Run 3 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 4 ===
  return 1
  State: [
    {1},
    {1},
    {1},
    {1}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/upper_bounds.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {2; Send; 6} },
    {2},
    {2},
    {5}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/upper_bounds.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {2; Send; 6} },
    {2},
    {2},
    {5}
  ]
  
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "literals_reject_empty.tpe", line 9, characters 19-33:
  9 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: In the `regex-upper-bound-symbolic-by-letters` grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "literals_reject_empty.tpe", line 9, characters 19-33:
  9 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: In the `regex-upper-bound-letter-derivatives` grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_regular.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Send | Read*} }
  ]
  
  === Run 2 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 3 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 4 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {_} }
  ]
  
  === Run 5 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 3; (Send | Write)*} }
  ]
  
  === Run 6 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(Send; 2)*} }
  ]
  
  === Run 7 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(_ & ~Revoke)*} }
  ]
  
  === Run 8 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Open; (Read | Write)*; Close} }
  ]
  
  === Run 9 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3 | 2*} }
  ]
  
  === Run 10 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3} }
  ]
  
  === Run 11 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {0} }
  ]
  
  === Run 12 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 1; (0 | 1; (0 | 1)); Send} }
  ]
  
  === Run 13 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; (0 | 1); Send} }
  ]
  
  === Run 14 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; 1*} }
  ]
  
  === Run 15 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {2; (0 | 1; (0 | 1))} }
  ]
  
  === Run 16 ===
  return 0
  State: [
    { resource_0 ↦ 1 # ⊤ }
  ]
  
  ======================================================================
  literals_regular.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Send | Read*} }
  ]
  
  === Run 2 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 3 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read*} }
  ]
  
  === Run 4 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {_} }
  ]
  
  === Run 5 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 3; (Send | Write)*} }
  ]
  
  === Run 6 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(Send; 2)*} }
  ]
  
  === Run 7 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {(_ & ~Revoke)*} }
  ]
  
  === Run 8 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Open; (Read | Write)*; Close} }
  ]
  
  === Run 9 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3 | 2*} }
  ]
  
  === Run 10 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {3} }
  ]
  
  === Run 11 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {0} }
  ]
  
  === Run 12 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 1; (0 | 1; (0 | 1)); Send} }
  ]
  
  === Run 13 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; (0 | 1); Send} }
  ]
  
  === Run 14 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {Read; 2; 1*} }
  ]
  
  === Run 15 ===
  return 0
  State: [
    { resource_0 ↦ 1 # {2; (0 | 1; (0 | 1))} }
  ]
  
  === Run 16 ===
  return 0
  State: [
    { resource_0 ↦ 1 # ⊤ }
  ]
  
  ======================================================================
  regular_auth.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return 42
  State: [
    { resource_0 ↦ 42 # {3; _*} },
    {4}
  ]
  
  ======================================================================
  regular_auth.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return 42
  State: [
    { resource_0 ↦ 42 # {3; _*} },
    {4}
  ]
  
  ======================================================================
  regular_protocol.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  ======================================================================
  regular_protocol.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  ======================================================================
  regular_reject_auth.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_auth.tpe", lines 19-21, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 17, characters 36-37:
    17 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 26-27, characters 2-5:
  26 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 24, characters 41-42:
    24 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 25, characters 2-19:
    25 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 33-34, characters 2-3:
  33 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 30, characters 20-21:
    30 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 31, characters 2-18:
    31 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 32, characters 2-9:
    32 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_auth.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_auth.tpe", lines 19-21, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 17, characters 36-37:
    17 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 26-27, characters 2-5:
  26 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 24, characters 41-42:
    24 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 25, characters 2-19:
    25 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 33-34, characters 2-3:
  33 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 30, characters 20-21:
    30 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 31, characters 2-18:
    31 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 32, characters 2-9:
    32 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_bounds.tpe", line 9, characters 0-52:
  9 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `regex-upper-bound-symbolic-by-letters` grading monoid, which does not use them
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_bounds.tpe", line 9, characters 0-52:
  9 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Running-time bounds must not be declared under the `regex-upper-bound-letter-derivatives` grading monoid, which does not use them
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 18-23, characters 23-3:
  18 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 29-30, characters 2-5:
  29 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 27, characters 23-24:
    27 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 28, characters 2-49:
    28 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 18-23, characters 23-3:
  18 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 29-30, characters 2-5:
  29 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 27, characters 23-24:
    27 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 28, characters 2-49:
    28 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_protocol.tpe", line 21, characters 6-23:
  21 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 17, characters 15-16:
    17 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 18, characters 6-21:
    18 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 19, characters 6-22:
    19 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 20, characters 14-29:
    20 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 23-24, characters 16-34:
  23 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_protocol.tpe", line 21, characters 6-23:
  21 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 17, characters 15-16:
    17 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 18, characters 6-21:
    18 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 19, characters 6-22:
    19 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 20, characters 14-29:
    20 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 23-24, characters 16-34:
  23 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold
  ======================================================================
  regex_timed_compound_named_later_reject.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  File "regex_timed_compound_named_later_reject.tpe", line 10, characters 0-45:
  10 | operation Two : unit ~> unit # {Fetch; Later}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Unknown event `Later` in the grade of operation `Two`
  ======================================================================
  regex_timed_compound_named_later_reject.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  File "regex_timed_compound_named_later_reject.tpe", line 10, characters 0-45:
  10 | operation Two : unit ~> unit # {Fetch; Later}
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Unknown event `Later` in the grade of operation `Two`
  ======================================================================
  regex_timed_compound_wildcard.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  ======================================================================
  regex_timed_compound_wildcard.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  ======================================================================
  regex_timed_interval.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_timed_interval.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_timed_interval_reject.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  File "regex_timed_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_timed_interval_reject.tpe", line 16, characters 28-29:
    16 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 17, characters 2-18:
    17 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_timed_interval_reject.tpe", lines 25-26, characters 2-5:
  25 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_timed_interval_reject.tpe", line 23, characters 28-29:
    23 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 24, characters 2-18:
    24 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_timed_interval_reject.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  File "regex_timed_interval_reject.tpe", lines 18-19, characters 2-5:
  18 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_timed_interval_reject.tpe", line 16, characters 28-29:
    16 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 17, characters 2-18:
    17 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_timed_interval_reject.tpe", lines 25-26, characters 2-5:
  25 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_timed_interval_reject.tpe", line 23, characters 28-29:
    23 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_timed_interval_reject.tpe", line 24, characters 2-18:
    24 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_timed_interval_ticks_reject.tpe (regex-timed-interval-symbolic-by-letters)
  ======================================================================
  File "regex_timed_interval_ticks_reject.tpe", line 17, characters 6-34:
  17 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_timed_interval_ticks_reject.tpe", line 24, characters 33-61:
  24 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_timed_interval_ticks_reject.tpe (regex-timed-interval-letter-derivatives)
  ======================================================================
  File "regex_timed_interval_ticks_reject.tpe", line 17, characters 6-34:
  17 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_timed_interval_ticks_reject.tpe", line 24, characters 33-61:
  24 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_timed_lower.tpe (regex-timed-lower-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {Ping; 3} },
    {1},
    {3},
    {1}
  ]
  
  ======================================================================
  regex_timed_lower.tpe (regex-timed-lower-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {Ping; 3} },
    {1},
    {3},
    {1}
  ]
  
  ======================================================================
  regex_timed_lower_reject.tpe (regex-timed-lower-bound-symbolic-by-letters)
  ======================================================================
  File "regex_timed_lower_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_timed_lower_reject.tpe", line 17, characters 31-32:
    17 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_lower_reject.tpe", line 18, characters 2-17:
    18 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_timed_lower_reject.tpe", line 19, characters 2-9:
    19 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_timed_lower_reject.tpe", line 25, characters 29-30:
    25 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_timed_lower_reject.tpe", line 26, characters 2-10:
    26 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 34-35, characters 2-5:
  34 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_lower_reject.tpe", line 32, characters 25-26:
    32 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_timed_lower_reject.tpe", line 33, characters 2-58:
    33 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_timed_lower_reject.tpe (regex-timed-lower-bound-letter-derivatives)
  ======================================================================
  File "regex_timed_lower_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_timed_lower_reject.tpe", line 17, characters 31-32:
    17 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_timed_lower_reject.tpe", line 18, characters 2-17:
    18 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_timed_lower_reject.tpe", line 19, characters 2-9:
    19 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 27-28, characters 2-5:
  27 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_timed_lower_reject.tpe", line 25, characters 29-30:
    25 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_timed_lower_reject.tpe", line 26, characters 2-10:
    26 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_timed_lower_reject.tpe", lines 34-35, characters 2-5:
  34 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_lower_reject.tpe", line 32, characters 25-26:
    32 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_timed_lower_reject.tpe", line 33, characters 2-58:
    33 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_timed_lower_ticks_reject.tpe (regex-timed-lower-bound-symbolic-by-letters)
  ======================================================================
  File "regex_timed_lower_ticks_reject.tpe", line 16, characters 6-30:
  16 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_timed_lower_ticks_reject.tpe (regex-timed-lower-bound-letter-derivatives)
  ======================================================================
  File "regex_timed_lower_ticks_reject.tpe", line 16, characters 6-30:
  16 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_timed_upper.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_timed_upper.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_timed_upper_open.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_timed_upper_open.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_timed_upper_open_reject.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_timed_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_timed_upper_open_reject.tpe", line 15, characters 15-19:
    15 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_timed_upper_open_reject.tpe", line 16, characters 2-15:
    16 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_timed_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_timed_upper_open_reject.tpe", line 12, characters 0-52:
    12 | operation Beep : unit ~> unit # {Beep} within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_timed_upper_open_reject.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_timed_upper_open_reject.tpe", lines 17-18, characters 2-3:
  17 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_timed_upper_open_reject.tpe", line 15, characters 15-19:
    15 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_timed_upper_open_reject.tpe", line 16, characters 2-15:
    16 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_timed_upper_open_reject.tpe", line 20, characters 0-25:
  20 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_timed_upper_open_reject.tpe", line 12, characters 0-52:
    12 | operation Beep : unit ~> unit # {Beep} within [1, 3)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_timed_upper_reject.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_timed_upper_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_upper_reject.tpe", line 17, characters 25-26:
    17 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_timed_upper_reject.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 28-29, characters 2-5:
  28 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_timed_upper_reject.tpe", line 25, characters 30-31:
    25 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_timed_upper_reject.tpe", line 26, characters 2-18:
    26 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_timed_upper_reject.tpe", line 27, characters 2-16:
    27 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 35-36, characters 2-5:
  35 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_timed_upper_reject.tpe", line 33, characters 37-38:
    33 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_timed_upper_reject.tpe", line 34, characters 2-49:
    34 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_timed_upper_reject.tpe", lines 39-41, characters 17-17:
  39 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_timed_upper_reject.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_timed_upper_reject.tpe", lines 19-20, characters 2-5:
  19 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_timed_upper_reject.tpe", line 17, characters 25-26:
    17 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_timed_upper_reject.tpe", line 18, characters 2-18:
    18 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 28-29, characters 2-5:
  28 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_timed_upper_reject.tpe", line 25, characters 30-31:
    25 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_timed_upper_reject.tpe", line 26, characters 2-18:
    26 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_timed_upper_reject.tpe", line 27, characters 2-16:
    27 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_timed_upper_reject.tpe", lines 35-36, characters 2-5:
  35 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_timed_upper_reject.tpe", line 33, characters 37-38:
    33 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_timed_upper_reject.tpe", line 34, characters 2-49:
    34 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_timed_upper_reject.tpe", lines 39-41, characters 17-17:
  39 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_timed_upper_ticks.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_timed_upper_ticks.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_timed_upper_ticks_reject.tpe (regex-timed-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_timed_upper_ticks_reject.tpe", line 17, characters 6-23:
  17 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 22, characters 26-43:
  22 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 25, characters 27-44:
  25 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  ======================================================================
  regex_timed_upper_ticks_reject.tpe (regex-timed-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_timed_upper_ticks_reject.tpe", line 17, characters 6-23:
  17 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 22, characters 26-43:
  22 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_timed_upper_ticks_reject.tpe", line 25, characters 27-44:
  25 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations

The options: typechecking only reports errors and runs nothing, and the
single-dash form of the help option is not accepted.

  $ ../tempore --typecheck-only ../examples/basics/nat.tpe
  $ ../tempore --typecheck-only comp_type_annotation_reject.tpe
  File "comp_type_annotation_reject.tpe", line 3, characters 9-31:
  3 | let f () : nat # 5 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the effect inequality `3 >= 5` does not hold
  [1]
  $ ../tempore -help
  ../tempore: unknown option '-help'.
  Run Tempore as '../tempore [filename.tpe] ...'
    --api-level       Set the apiLevel of the protocol written with --bind (default: 2.30)
    --bind            With --emit-opentrons, write an Opentrons protocol whose operations are performed by the functions of the given Python binding file
    --board           With --package, type the program under the running-time bounds of the operations of the packages on the given board of the Arduino backend, where they give them (default: the bounds of their declarations); a device written with --device has the board of its manifest
    --build           Build the project written with --device with PlatformIO, passing its output through and exiting with its exit code
    --capture         After --upload, or without an upload with --device, read the serial port of --port at the baud rate of the board for the given number of seconds, printing its lines, and then the last complete profile among them, if any
    --debug           Print the inferred type schemes of the top-level definitions before running
    --device          With --emit-arduino, write a PlatformIO project of the device described by the given manifest, of the definitions reached from its tasks
    --emit-arduino    Typecheck the files and write them, compiled to C++, to the given directory, without running them; a name without a directory component names a directory in _arduino/projects
    --emit-opentrons  Typecheck the files and write them, compiled to Python, to the given file, without running them; a file name without a directory names a file in _opentrons/protocols
    --grades          Selects the grades (default: time-lower-bound); accepted:
        Time:
          time-lower-bound                          Lower bounds
          time-upper-bound                          Upper bounds
          time-interval                             Intervals
          time-lower-bound-rational                 Lower bounds (rational)
          time-upper-bound-rational                 Upper bounds (rational)
          time-interval-rational                    Intervals (rational)
        Traces:
          traces-upper-bound                        Upper bounds
          traces-upper-bound-rational               Upper bounds (rational)
        Traces of timed operations:
          traces-timed-lower-bound                  Lower bounds
          traces-timed-upper-bound                  Upper bounds
          traces-timed-interval                     Intervals
          traces-timed-lower-bound-rational         Lower bounds (rational)
          traces-timed-upper-bound-rational         Upper bounds (rational)
          traces-timed-interval-rational            Intervals (rational)
        Regular expressions:
          regex-upper-bound-symbolic                Upper bounds (symbolic)
              symbolic expressions over letter sets; inclusion by gap derivatives by minterms, depth-first
          regex-upper-bound-rational-symbolic       Upper bounds (rational, symbolic)
              symbolic expressions over letter and delay sets; inclusion by gap derivatives by minterms, depth-first
        Regular expressions of timed operations:
          regex-timed-lower-bound-symbolic          Lower bounds (symbolic)
              symbolic expressions over letter sets; inclusion by gap derivatives with a closure reader, breadth-first
          regex-timed-upper-bound-symbolic          Upper bounds (symbolic)
              symbolic expressions over letter sets; inclusion by gap derivatives with a closure reader, breadth-first
          regex-timed-interval-symbolic             Intervals (symbolic)
              symbolic expressions over letter sets; inclusion by gap derivatives with a closure reader, breadth-first
          regex-timed-lower-bound-rational-symbolic Lower bounds (rational, symbolic)
              symbolic expressions over letter and delay sets; inclusion by gap derivatives with a closure reader, breadth-first
          regex-timed-upper-bound-rational-symbolic Upper bounds (rational, symbolic)
              symbolic expressions over letter and delay sets; inclusion by gap derivatives with a closure reader, breadth-first
          regex-timed-interval-rational-symbolic    Intervals (rational, symbolic)
              symbolic expressions over letter and delay sets; inclusion by gap derivatives with a closure reader, breadth-first
        Security levels:
          security-levels                           Levels
          time-lower-bound-levels                   Embargoes
          time-upper-bound-levels                   Expiring capabilities
          flow-levels                               Flow-sensitive outputs
        Semidirect products:
          resource-levels                           Resource levels
          windowed-schedules                        Windowed schedules
          mode-switch-costs                         Mode-switch costs
          mode-times                                Mode times
        Operation counts:
          counts-upper-bound                        Upper bounds
        Separation of timed operations:
          event-separation                          Event separation
        Further implementations of the regular grades, kept for benchmarking, are accepted by --grades with the suffixes -letter-automata, -symbolic-by-letters and -letter-derivatives in place of -symbolic, and -rational-automata in place of -rational-symbolic.
    --help            Display this list of options
    --host-runs       With --emit-arduino, also compile the run commands, and write a main program for the host that executes them and prints their results as the interpreter does
    --host-simulate   With --device, build the project for the host with c++ and run its tasks for the given number of seconds of simulated time, printing the log of the device with the events of its tasks
    --monitor         Set what a protocol written with --bind or a device written with --device does when an operation's running time is outside its bounds, or a step of a periodic task takes its period or longer: abort, warn or off (default: abort)
    --no-stdlib       Do not load the standard library
    --package         Load the declarations of the operations of the given peripheral package of the Arduino backend before the files, so that the program may perform them, run by their default implementations; repeatable; the packages of a device written with --device are those of its manifest
    --pio             Use the given executable as the PlatformIO of --build and --upload (default: pio on the PATH, or else in _arduino/venv)
    --port            Upload through the given serial port under --upload (default: the port PlatformIO detects), and read it under --capture
    --profile         Build the project written with --device with the profile of the running times of its operations and periodic tasks, logged every 5 seconds in place of the trace under --host-simulate
    --robot           Set the robot of the protocol written with --bind: flex (default: flex)
    --simulate        Run the Opentrons simulator on the protocol written with --bind, passing its run log through and exiting with its exit code
    --simulator       Use the given executable as the Opentrons simulator of --simulate (default: opentrons_simulate on the PATH, or else in _opentrons)
    --time-unit       Set the length of a unit of duration of the protocol written with --bind: seconds, minutes, hours or a positive number of seconds (default: seconds)
    --timeline        Print the timeline of each run after its result: its delays and calls of operations performed by their default implementations, with the events of these indented below them, each with its grade, and the resources boxed, with their grades, and unboxed, each row with the grade accumulated before it; long grades are shortened
    --timeline-full   Print the timelines of --timeline with their grades in full; implies --timeline
    --typecheck-only  Typecheck the files without running them
    --upload          Build the project written with --device with PlatformIO and upload it to the board, passing its output through and exiting with its exit code
  [2]
