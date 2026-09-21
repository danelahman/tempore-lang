  $ for f in *.tpe
  > do
  >   echo "======================================================================"
  >   echo $f
  >   echo "======================================================================"
  >   case $f in
  >     time_intervals.tpe) ../tempore --resources time-interval $f;;
  >     time_upper.tpe) ../tempore --resources time-upper-bound $f;;
  >     comp_type_annotation_upper*.tpe) ../tempore --resources time-upper-bound $f;;
  >     eternal_lower.tpe) ../tempore $f;;
  >     eternal_*.tpe) ../tempore --resources time-upper-bound $f;;
  >     noneternal_lower.tpe) ../tempore $f;;
  >     noneternal*.tpe) ../tempore --resources time-upper-bound $f;;
  >     continuation_discard_reject_lower.tpe) ../tempore $f;;
  >     continuation_nested_discard_reject_lower.tpe) ../tempore $f;;
  >     continuation_twice_lower.tpe) ../tempore $f;;
  >     continuation_*.tpe) ../tempore --resources time-upper-bound $f;;
  >     error_use_after_delay.tpe) ../tempore --resources time-upper-bound $f;;
  >     traces_lower.tpe) ../tempore --resources traces-lower-bound $f;;
  >     3dprint_traces.tpe) ../tempore --resources traces-interval $f;;
  >     traces_intervals.tpe) ../tempore --resources traces-interval $f;;
  >     traces_intervals_bounds.tpe) ../tempore --resources traces-interval $f;;
  >     traces_intervals_default_bounds.tpe) ../tempore --resources traces-interval $f;;
  >     traces_*.tpe) ../tempore --resources traces-upper-bound $f;;
  >     *) ../tempore $f;;
  >   esac
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  3dprint_traces.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    ({1},{1}),
    { resource_0 ↦ Epoxy # ({8},{11}),
      resource_2 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            unbox resource_0 as g in
            perform Mount (p, g) (op_var. return op_var)
          with printer
        # ({Heat; Extrude; Cool},{Heat; Extrude; Cool})
    },
    ({1},{1}),
    ({3},{3}),
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # ({2},{2}) },
    ({2},{2}),
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # ({2},{8})
    },
    ({2},{2}),
    ({1},{1})
  ]
  
  === Run 2 ===
  return ("Sword #1", Printed (Cooled (Extruded (Heated (Model "Sword")))))
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            return ("Sword #1", p)
          with printer
        # ({Heat; Extrude; Cool},{Heat; Extrude; Cool})
    },
    ({1},{1}),
    ({3},{3}),
    { resource_2 ↦ Extruded (Heated (Model "Sword")) # ({2},{2}) },
    ({2},{2}),
    { resource_3 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # ({2},{8})
    },
    ({2},{2})
  ]
  
  === Run 3 ===
  return (Model "Sword")
  State: [
    ({1},{1})
  ]
  
  === Run 4 ===
  return Epoxy
  State: []
  
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
  3 | let f () : int # 5 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the resource inequality `3 >= 5` does not hold
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
  File "comp_type_annotation_upper_reject.tpe", line 3, characters 9-31:
  3 | let f () : int # 2 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `2`
    Note: the resource inequality `3 <= 2` does not hold
  ======================================================================
  continuation_discard_reject_lower.tpe
  ======================================================================
  File "continuation_discard_reject_lower.tpe", line 10, characters 27-38:
  10 | let h = handler | x -> x | Op p k -> 5
                                  ^^^^^^^^^^^
  Typing error: For every grade `ρ₀` the continuation `k` may have, the case for `Op` must have a grade matching `1 + ρ₀`, but its grade `0` does not
    File "continuation_discard_reject_lower.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_discard_reject_lower.tpe", line 10, characters 32-33:
    10 | let h = handler | x -> x | Op p k -> 5
                                         ^
    `k` may have any grade `ρ₀`
    Note: the resource inequality `∀ρ₀. 0 >= ρ₀ + 1` does not hold: for `ρ₀ = 0` it becomes `0 >= 1`
  ======================================================================
  continuation_discard_upper.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: [
    { resource_1 ↦
        fun op_var ↦ handle
                       return op_var;
                       delay 5 (return ());
                       return 3
                     with h
        # 1
    }
  ]
  
  ======================================================================
  continuation_escape_reject.tpe
  ======================================================================
  File "continuation_escape_reject.tpe", line 11, characters 39-40:
  11 | let h g = handler | x -> x | Op p k -> g k; delay 1; continue k with ()
                                              ^
  Typing error: Variable `g` has type `[1](unit → α # ρ₀) → β`, which is not eternal, so it cannot be used in the case for `Op`: the case runs at a time the handler does not fix
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
    the case for `Op` begins here
  ======================================================================
  continuation_fixed_reject.tpe
  ======================================================================
  File "continuation_fixed_reject.tpe", line 10, characters 39-95:
  10 | let h = handler | x -> (fun () -> x) | Op p k -> (fun () -> let f = continue k with () in f ())
                                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The continuation `k` in the case for `Op` may have any grade `ρ₀`, but here `ρ₀` is required to equal `0`
    File "continuation_fixed_reject.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_fixed_reject.tpe", line 10, characters 44-45:
    10 | let h = handler | x -> (fun () -> x) | Op p k -> (fun () -> let f = continue k with () in f ())
                                                     ^
    `k` may have any grade `ρ₀`
    Note: while matching `unit → β # ρ₁ + ρ₂` against `unit → α`
  ======================================================================
  continuation_nested_discard_reject_lower.tpe
  ======================================================================
  File "continuation_nested_discard_reject_lower.tpe", line 21, characters 13-43:
  21 |            | Op2 q k' -> delay 3; return ())
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ρ₀` the continuation `k'` may have, the case for `Op2` must have a grade matching `3 + ρ₀`, but its grade `3` does not
    File "continuation_nested_discard_reject_lower.tpe", line 6, characters 0-32:
    6 | operation Op2 : unit ~> unit # 3
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "continuation_nested_discard_reject_lower.tpe", line 21, characters 19-21:
    21 |            | Op2 q k' -> delay 3; return ())
                            ^^
    `k'` may have any grade `ρ₀`
    Note: the resource inequality `∀ρ₀. 0 >= ρ₀` does not hold: for `ρ₀ = 1` it becomes `0 >= 1`
  ======================================================================
  continuation_nested_escape_reject.tpe
  ======================================================================
  File "continuation_nested_escape_reject.tpe", line 23, characters 23-24:
  23 |          | Op2 q k' -> g k'; delay 1; continue k' with ())
                              ^
  Typing error: Variable `g` has type `[1](unit → α # ρ₀) → β`, which is not eternal, so it cannot be used in the case for `Op1`: the case runs at a time the handler does not fix
    File "continuation_nested_escape_reject.tpe", line 5, characters 0-32:
    5 | operation Op1 : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op1` is declared here
    File "continuation_nested_escape_reject.tpe", line 13, characters 6-7:
    13 | let h g =
               ^
    `g` is bound here
    File "continuation_nested_escape_reject.tpe", lines 16-23, characters 4-58:
    16 |   | Op1 p k ->
             ^^^^^^^^^^
    the case for `Op1` begins here
  ======================================================================
  continuation_nested_fixed_reject.tpe
  ======================================================================
  File "continuation_nested_fixed_reject.tpe", line 21, characters 11-70:
  21 |          | Op2 q k' -> (fun () -> let f = continue k' with () in f ()))
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The continuation `k'` in the case for `Op2` may have any grade `ρ₀`, but here `ρ₀` is required to equal `0`
    File "continuation_nested_fixed_reject.tpe", line 6, characters 0-32:
    6 | operation Op2 : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "continuation_nested_fixed_reject.tpe", line 21, characters 17-19:
    21 |          | Op2 q k' -> (fun () -> let f = continue k' with () in f ()))
                          ^^
    `k'` may have any grade `ρ₀`
    Note: while matching `unit → β # ρ₁ + ρ₂` against `unit → α`
  ======================================================================
  continuation_nested_twice_reject_upper.tpe
  ======================================================================
  File "continuation_nested_twice_reject_upper.tpe", lines 22-24, characters 13-34:
  22 |            | Op2 q k' ->
                    ^^^^^^^^^^^
  Typing error: For every grade `ρ₀` the continuation `k'` may have, the case for `Op2` must have a grade matching `1 + ρ₀`, but its grade `ρ₀ + ρ₀` does not
    File "continuation_nested_twice_reject_upper.tpe", line 6, characters 0-32:
    6 | operation Op2 : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "continuation_nested_twice_reject_upper.tpe", line 22, characters 19-21:
    22 |            | Op2 q k' ->
                            ^^
    `k'` may have any grade `ρ₀`
    Note: the resource inequality `∀ρ₀. ρ₀ <= 1` does not hold: for `ρ₀ = 2` it becomes `2 <= 1`
  ======================================================================
  continuation_twice_lower.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_1 ↦ fun op_var ↦ handle
                                  return op_var;
                                  return 3
                                with h # 0 }
  ]
  
  ======================================================================
  continuation_twice_reject_upper.tpe
  ======================================================================
  File "continuation_twice_reject_upper.tpe", line 10, characters 27-85:
  10 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ρ₀` the continuation `k` may have, the case for `Op` must have a grade matching `1 + ρ₀`, but its grade `ρ₀ + ρ₀` does not
    File "continuation_twice_reject_upper.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "continuation_twice_reject_upper.tpe", line 10, characters 32-33:
    10 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                         ^
    `k` may have any grade `ρ₀`
    Note: the resource inequality `∀ρ₀. ρ₀ <= 1` does not hold: for `ρ₀ = 2` it becomes `2 <= 1`
  ======================================================================
  default_ops.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            let v = return op_var in
            (let b = (let b = (+) v in
                      b 1) in
             perform Set b (op_var. return op_var));
            return v
          with h
        # 3
    },
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
    Note: the resource inequality `2 >= 3` does not hold
  ======================================================================
  default_reject_duplicate.tpe
  ======================================================================
  File "default_reject_duplicate.tpe", line 8, characters 0-25:
  8 | default Log msg = delay 2
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: operation `Log` already has a default implementation
  ======================================================================
  default_reject_type.tpe
  ======================================================================
  File "default_reject_type.tpe", line 7, characters 0-32:
  7 | default Get () = delay 3; "zero"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Get` returns `string` but `Get` returns `int`
    File "default_reject_type.tpe", line 5, characters 0-31:
    5 | operation Get : unit ~> int # 3
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Get` is declared here
  ======================================================================
  default_reject_unknown.tpe
  ======================================================================
  File "default_reject_unknown.tpe", line 5, characters 0-25:
  5 | default Log msg = delay 1
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: Unknown name `Log`
  ======================================================================
  duplicate_variant_tydef_sum.tpe
  ======================================================================
  File "duplicate_variant_tydef_sum.tpe", line 3, characters 0-39:
  3 | type cow = Horn of int | Horn of string
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: Label `Horn` defined multiple times
  ======================================================================
  error_apply_arg.tpe
  ======================================================================
  File "error_apply_arg.tpe", line 11, characters 8-9:
  11 |   f "one"
               ^
  Typing error: This argument has type `string` but the function expects `int`
    File "error_apply_arg.tpe", line 11, characters 2-3:
    11 |   f "one"
           ^
    the function has type `int → int # ρ₀ + ρ₁`
    File "error_apply_arg.tpe", line 9, characters 10-29:
    9 |   let f = id (fun n -> n + 1) in
                  ^^^^^^^^^^^^^^^^^^^
    `int` was inferred here
    Note: while matching `int → int # ρ₀ + ρ₁` against `string → α # ρ₂`
  ======================================================================
  error_handler_case.tpe
  ======================================================================
  File "error_handler_case.tpe", line 9, characters 4-20:
  9 |   | Op p k -> "done"
          ^^^^^^^^^^^^^^^^
  Typing error: The case for `Op` returns `string` but the return clause returns `int`
    File "error_handler_case.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
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
  Typing error: Variable `t` is used after grade `3` has elapsed, but its type `token` is not eternal
    File "error_use_after_delay.tpe", line 16, characters 6-7:
    16 |   let t = Token in
               ^
    `t` is bound here
    File "error_use_after_delay.tpe", line 17, characters 2-9:
    17 |   delay 2;
           ^^^^^^^
    `delay 2` elapses here
    File "error_use_after_delay.tpe", line 19, characters 2-17:
    19 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    `Ping` is performed here (grade `1`)
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
  Typing error: This argument has type `string` but the function expects `int`
    File "errors_multiple.tpe", line 12, characters 27-28:
    12 | let first (n : string) = n + 1
                                    ^
    the function has type `int → int → int`
    Note: while matching `int → int → int` against `string → int → α # ρ₀ # ρ₁`
  
  File "errors_multiple.tpe", line 15, characters 14-36:
  15 |   let slow () : int # 5 = delay 3; 1 in
                     ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the resource inequality `3 >= 5` does not hold
  
  File "errors_multiple.tpe", line 18, characters 15-24:
  18 | let second n = first n + "two"
                      ^^^^^^^^^
  Typing error: The application has type `int` but `string` is expected here
    Note: while matching `int → int → int` against `int → string → α # ρ₀ # ρ₁`
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
  eternal_types.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: [
    1
  ]
  
  === Run 2 ===
  return (Stamp 1)
  State: [
    1
  ]
  
  === Run 3 ===
  return Tag
  State: [
    1
  ]
  
  === Run 4 ===
  return 5
  State: [
    2
  ]
  
  === Run 5 ===
  return (fun () ↦ return ())
  State: []
  
  === Run 6 ===
  return 2
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var;
            return 1
          with handler
               | return y ↦ return y
               | Tick (p, k) ↦
                        let r = (unbox k as unbox_var in
                                 unbox_var ()) in
                        return 2
        # 1
    }
  ]
  
  === Run 7 ===
  return (Stamp 42)
  State: [
    3
  ]
  
  === Run 8 ===
  return (Ticket Token)
  State: []
  
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var;
            return 5
          with handler
               | return y ↦ return y
               | Op (p, k) ↦
                      let r = (unbox k as unbox_var in
                               unbox_var ()) in
                      return 6
        # 1
    }
  ]
  
  ======================================================================
  eternal_tyvars_reject_function.tpe
  ======================================================================
  File "eternal_tyvars_reject_function.tpe", line 9, characters 4-8:
  9 | run keep (fun () -> ())
          ^^^^
  Typing error: `unit → unit` is not eternal, but `keep` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_function.tpe", line 5, characters 0-23:
    5 | let keep x = delay 1; x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `keep` is defined here
    File "eternal_tyvars_reject_function.tpe", line 5, characters 9-10:
    5 | let keep x = delay 1; x
                 ^
    `x` is bound here
    File "eternal_tyvars_reject_function.tpe", line 5, characters 13-20:
    5 | let keep x = delay 1; x
                     ^^^^^^^
    `delay 1` elapses here
    File "eternal_tyvars_reject_function.tpe", line 5, characters 22-23:
    5 | let keep x = delay 1; x
                              ^
    `x` is used here after grade `1` has elapsed, which only an eternal type allows
  ======================================================================
  eternal_tyvars_reject_handler.tpe
  ======================================================================
  File "eternal_tyvars_reject_handler.tpe", line 12, characters 48-49:
  12 | run handle (perform Op (); (fun () -> ())) with h (fun () -> ())
                                                       ^
  Typing error: `unit → unit` is not eternal, but `h` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 0-70:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `h` is defined here
    File "eternal_tyvars_reject_handler.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 6-7:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
              ^
    `x` is bound here
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 29-70:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` begins here
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 47-65:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                       ^^^^^^^^^^^^^^^^^^
    this computation runs here (grade `ρ₀`)
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 69-70:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                                             ^
    `x` is used here, in the case for `Op`
  ======================================================================
  eternal_tyvars_reject_higher_order.tpe
  ======================================================================
  File "eternal_tyvars_reject_higher_order.tpe", line 9, characters 4-9:
  9 | run after (fun () -> delay 2) (fun () -> ())
          ^^^^^
  Typing error: `unit → unit` is not eternal, but `after` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_higher_order.tpe", line 5, characters 0-23:
    5 | let after g x = g (); x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `after` is defined here
    File "eternal_tyvars_reject_higher_order.tpe", line 5, characters 12-13:
    5 | let after g x = g (); x
                    ^
    `x` is bound here
    File "eternal_tyvars_reject_higher_order.tpe", line 5, characters 16-20:
    5 | let after g x = g (); x
                        ^^^^
    this computation runs here (grade `2`)
    File "eternal_tyvars_reject_higher_order.tpe", line 5, characters 22-23:
    5 | let after g x = g (); x
                              ^
    `x` is used here after grade `2` has elapsed, which only an eternal type allows
    Note: the resource inequality `2 <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_noneternal.tpe
  ======================================================================
  File "eternal_tyvars_reject_noneternal.tpe", line 11, characters 4-8:
  11 | run keep Token
           ^^^^
  Typing error: `token` is not eternal, but `keep` needs the type of `x` to be eternal
    File "eternal_tyvars_reject_noneternal.tpe", line 7, characters 0-23:
    7 | let keep x = delay 1; x
        ^^^^^^^^^^^^^^^^^^^^^^^
    `keep` is defined here
    File "eternal_tyvars_reject_noneternal.tpe", line 7, characters 9-10:
    7 | let keep x = delay 1; x
                 ^
    `x` is bound here
    File "eternal_tyvars_reject_noneternal.tpe", line 7, characters 13-20:
    7 | let keep x = delay 1; x
                     ^^^^^^^
    `delay 1` elapses here
    File "eternal_tyvars_reject_noneternal.tpe", line 7, characters 22-23:
    7 | let keep x = delay 1; x
                              ^
    `x` is used here after grade `1` has elapsed, which only an eternal type allows
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
    File "invalid_match_type.tpe", line 4, characters 8-9:
    4 | run let a = [A] in
                ^
    `a list` was inferred here
  ======================================================================
  iterative_unbox.tpe
  ======================================================================
  File "iterative_unbox.tpe", line 7, characters 30-57:
  7 |   fold_left (fun acc value -> unbox value as v in acc + v) 0 boxed
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `value` is unboxed before any grade has elapsed, but its box grade is `3`
    File "iterative_unbox.tpe", line 7, characters 21-26:
    7 |   fold_left (fun acc value -> unbox value as v in acc + v) 0 boxed
                             ^^^^^
    `value` is bound here
    Note: the resource inequality `0 >= 3` does not hold
  ======================================================================
  less_than_function.tpe
  ======================================================================
  Runtime error: Incomparable expression (fun x ↦ return x)
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
  return -1000000000
  State: []
  
  === Run 6 ===
  return 42
  State: []
  
  === Run 7 ===
  return -42
  State: []
  
  === Run 8 ===
  return 42
  State: []
  
  === Run 9 ===
  return 42
  State: []
  
  === Run 10 ===
  return 11259375
  State: []
  
  === Run 11 ===
  return 11259375
  State: []
  
  === Run 12 ===
  return 32072
  State: []
  
  === Run 13 ===
  return 32072
  State: []
  
  === Run 14 ===
  return 3.141592
  State: []
  
  === Run 15 ===
  return 4.141592
  State: []
  
  === Run 16 ===
  return -5.1592
  State: []
  
  === Run 17 ===
  return 6.1592
  State: []
  
  === Run 18 ===
  return -3.14
  State: []
  
  ======================================================================
  malformed_type_application.tpe
  ======================================================================
  File "malformed_type_application.tpe", line 4, characters 0-25:
  4 | type bar = (int, int) foo
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Type `foo` expects 1 argument but is given 2
  ======================================================================
  nat.tpe
  ======================================================================
  === Run 1 ===
  return 42
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
  File "noneternal_reject_after_delay.tpe", line 13, characters 2-3:
  13 |   t
         ^
  Typing error: Variable `t` is used after grade `1` has elapsed, but its type `token` is not eternal
    File "noneternal_reject_after_delay.tpe", line 11, characters 6-7:
    11 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_after_delay.tpe", line 12, characters 2-9:
    12 |   delay 1;
           ^^^^^^^
    `delay 1` elapses here
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  noneternal_reject_alias.tpe
  ======================================================================
  File "noneternal_reject_alias.tpe", line 5, characters 0-29:
  5 | noneternal type seconds = int
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: type `seconds` is an alias and cannot be declared noneternal; wrap it in a constructor, as in `noneternal type seconds = Seconds of ...`
  ======================================================================
  noneternal_reject_unknown_grade.tpe
  ======================================================================
  File "noneternal_reject_unknown_grade.tpe", line 21, characters 2-3:
  21 |   t
         ^
  Typing error: Variable `t` is used after grade `ρ₀ + 1` has elapsed, but its type `token` is not eternal and grade `ρ₀ + 1` cannot be compared with `0`
    File "noneternal_reject_unknown_grade.tpe", line 18, characters 6-7:
    18 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_unknown_grade.tpe", line 19, characters 10-14:
    19 |   let r = g () in
                   ^^^^
    this computation runs here (grade `ρ₀`)
    File "noneternal_reject_unknown_grade.tpe", line 20, characters 2-9:
    20 |   delay 1;
           ^^^^^^^
    `delay 1` elapses here
  
  File "noneternal_reject_unknown_grade.tpe", line 34, characters 19-23:
  34 | let hold_token g = hold g Token
                          ^^^^
  Typing error: `token` is not eternal, but `hold` needs the type of `y` to be eternal
    File "noneternal_reject_unknown_grade.tpe", lines 26-30, characters 0-3:
    26 | let hold g x =
         ^^^^^^^^^^^^^^
    `hold` is defined here
    File "noneternal_reject_unknown_grade.tpe", line 27, characters 6-7:
    27 |   let y = x in
               ^
    `y` is bound here
    File "noneternal_reject_unknown_grade.tpe", line 28, characters 10-14:
    28 |   let r = g () in
                   ^^^^
    this computation runs here (grade `ρ₀`)
    File "noneternal_reject_unknown_grade.tpe", line 29, characters 2-9:
    29 |   delay 1;
           ^^^^^^^
    `delay 1` elapses here
    File "noneternal_reject_unknown_grade.tpe", line 30, characters 2-3:
    30 |   y
           ^
    `y` is used here after grade `ρ₀ + 1` has elapsed, which only an eternal type allows
    Note: grade `ρ₀ + 1` cannot be compared with `0`
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
  op_case_context.tpe
  ======================================================================
  === Run 1 ===
  return 12
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            let v = return op_var in
            return v
          with handler
               | return x ↦ return x
               | Op (p, k) ↦
                      let Stamp i = return (Stamp 3) in
                      let b =
                        (let b =
                           (let b = (let b = (let b = (+) p in
                                              b 2) in
                                     (+) b) in
                            b i) in
                         double b) in
                      unbox k as unbox_var in
                      unbox_var b
        # 0
    }
  ]
  
  ======================================================================
  op_case_context_reject_continuation.tpe
  ======================================================================
  File "op_case_context_reject_continuation.tpe", line 23, characters 13-31:
  23 |              continue k with ())
                    ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` has type `[0](unit → α # ρ₀)`, which is not eternal, so it cannot be used in the case for `Op2`: the case runs at a time the handler does not fix
    File "op_case_context_reject_continuation.tpe", line 6, characters 0-32:
    6 | operation Op2 : unit ~> unit # 0
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "op_case_context_reject_continuation.tpe", line 14, characters 10-11:
    14 |   | Op1 p k ->
                   ^
    `k` is bound here
    File "op_case_context_reject_continuation.tpe", lines 21-23, characters 11-31:
    21 |          | Op2 q k' ->
                    ^^^^^^^^^^^
    the case for `Op2` begins here
    File "op_case_context_reject_continuation.tpe", line 22, characters 21-40:
    22 |              let a = continue k' with () in
                              ^^^^^^^^^^^^^^^^^^^
    this computation runs here (grade `ρ₁`)
    Note: a box type is never eternal
  ======================================================================
  op_case_context_reject_function.tpe
  ======================================================================
  File "op_case_context_reject_function.tpe", line 13, characters 14-15:
  13 |       let v = f () in
                     ^
  Typing error: Variable `f` has type `unit → int # ρ₀`, which is not eternal, so it cannot be used in the case for `Op`: the case runs at a time the handler does not fix
    File "op_case_context_reject_function.tpe", line 5, characters 0-30:
    5 | operation Op : unit ~> int # 0
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "op_case_context_reject_function.tpe", line 9, characters 6-7:
    9 | let h f =
              ^
    `f` is bound here
    File "op_case_context_reject_function.tpe", lines 12-14, characters 4-23:
    12 |   | Op p k ->
             ^^^^^^^^^
    the case for `Op` begins here
  ======================================================================
  op_case_context_reject_noneternal.tpe
  ======================================================================
  File "op_case_context_reject_noneternal.tpe", line 15, characters 30-31:
  15 |   | Op p k -> continue k with t
                                     ^
  Typing error: Variable `t` has type `token`, which is not eternal, so it cannot be used in the case for `Op`: the case runs at a time the handler does not fix
    File "op_case_context_reject_noneternal.tpe", line 8, characters 0-32:
    8 | operation Op : unit ~> token # 0
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "op_case_context_reject_noneternal.tpe", line 12, characters 6-7:
    12 | let h t =
               ^
    `t` is bound here
    File "op_case_context_reject_noneternal.tpe", line 15, characters 4-31:
    15 |   | Op p k -> continue k with t
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` begins here
  ======================================================================
  op_case_context_reject_unbox.tpe
  ======================================================================
  File "op_case_context_reject_unbox.tpe", lines 14-15, characters 6-23:
  14 |       unbox b as v in
             ^^^^^^^^^^^^^^^
  Typing error: Variable `b` has type `[ρ₀]int`, which is not eternal, so it cannot be used in the case for `Op`: the case runs at a time the handler does not fix
    File "op_case_context_reject_unbox.tpe", line 5, characters 0-30:
    5 | operation Op : unit ~> int # 0
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "op_case_context_reject_unbox.tpe", line 10, characters 6-7:
    10 | let h b =
               ^
    `b` is bound here
    File "op_case_context_reject_unbox.tpe", lines 13-15, characters 4-23:
    13 |   | Op p k ->
             ^^^^^^^^^
    the case for `Op` begins here
    Note: a box type is never eternal
  ======================================================================
  orelse_andalso.tpe
  ======================================================================
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
  return (1::u, "foo"::u)
  State: []
  
  === Run 4 ===
  return ([]::v, (2::[])::v)
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
  Typing error: This argument has type `string` but the function expects `int`
    File "polymorphism_id_id.tpe", line 3, characters 11-12:
    3 |     (v 42, v "foo")
                   ^
    the function has type `int → int`
    File "polymorphism_id_id.tpe", line 2, characters 12-15:
    2 | run let v = u u in
                    ^^^
    `int` was inferred here
    Note: while matching `int → int` against `string → α # ρ₀`
  ======================================================================
  recursion.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: []
  
  ======================================================================
  shadow_label.tpe
  ======================================================================
  File "shadow_label.tpe", line 2, characters 0-41:
  2 | type bull = Tail of string | Horn of bull
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: Label `Horn` defined multiple times
  ======================================================================
  shadow_type.tpe
  ======================================================================
  File "shadow_type.tpe", line 3, characters 0-23:
  3 | type cow = Hoof of bool
      ^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: Type `cow` defined multiple times
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
  test_op_handling.tpe
  ======================================================================
  === Run 1 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            let freshSword = return op_var in
            let freshHammer =
              perform PrintResinModel (Model "Hammer") (op_var. return op_var) in
            unbox freshSword as cooledSword in
            let curedSword =
              perform UvCure (Cooled cooledSword) (op_var. return op_var) in
            unbox freshHammer as cooledHammer in
            let curedHammer =
              perform UvCure (Cooled cooledHammer) (op_var. return op_var) in
            return (Complete curedSword, Complete curedHammer)
          with h
        # 7
    },
    7,
    { resource_2 ↦ Fresh (Model "Sword") # 5,
      resource_4 ↦
        fun op_var ↦
          handle
            let freshHammer = return op_var in
            unbox resource_2 as cooledSword in
            let curedSword =
              perform UvCure (Cooled cooledSword) (op_var. return op_var) in
            unbox freshHammer as cooledHammer in
            let curedHammer =
              perform UvCure (Cooled cooledHammer) (op_var. return op_var) in
            return (Complete curedSword, Complete curedHammer)
          with h
        # 7
    },
    7,
    { resource_5 ↦ Fresh (Model "Hammer") # 5,
      resource_7 ↦
        fun op_var ↦
          handle
            let curedSword = return op_var in
            unbox resource_5 as cooledHammer in
            let curedHammer =
              perform UvCure (Cooled cooledHammer) (op_var. return op_var) in
            return (Complete curedSword, Complete curedHammer)
          with h
        # 5
    },
    5,
    { resource_9 ↦
        fun op_var ↦
          handle
            let curedHammer = return op_var in
            return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
                    Complete curedHammer)
          with h
        # 5
    },
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
  return -1
  State: []
  
  === Run 10 ===
  return -3.14159
  State: []
  
  === Run 11 ===
  return -1.
  State: []
  
  === Run 12 ===
  return "test integer operations"
  State: []
  
  === Run 13 ===
  return 4
  State: []
  
  === Run 14 ===
  return 4
  State: []
  
  === Run 15 ===
  return 19
  State: []
  
  === Run 16 ===
  return 65
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
  return 1
  State: []
  
  === Run 74 ===
  return (2::3::4::[])
  State: []
  
  === Run 75 ===
  return "test abs, min and max"
  State: []
  
  === Run 76 ===
  return (5, 5, 5)
  State: []
  
  === Run 77 ===
  return 1
  State: []
  
  === Run 78 ===
  return 2
  State: []
  
  === Run 79 ===
  return "test gcd and lcm"
  State: []
  
  === Run 80 ===
  return 4
  State: []
  
  === Run 81 ===
  return 24
  State: []
  
  === Run 82 ===
  return "test odd and even"
  State: []
  
  === Run 83 ===
  return false
  State: []
  
  === Run 84 ===
  return true
  State: []
  
  === Run 85 ===
  return "test id"
  State: []
  
  === Run 86 ===
  return 5
  State: []
  
  === Run 87 ===
  return id
  State: []
  
  === Run 88 ===
  return "test compose and reverse apply"
  State: []
  
  === Run 89 ===
  return 196
  State: []
  
  === Run 90 ===
  return 7
  State: []
  
  === Run 91 ===
  return "test fst and snd"
  State: []
  
  === Run 92 ===
  return "foo"
  State: []
  
  === Run 93 ===
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
    3
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
    { resource_0 ↦ 42 # 7,
      resource_2 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_0 as x in
            return x
          with h
        # 7
    },
    3,
    4
  ]
  
  ======================================================================
  time_intervals.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # (1,4) },
    (1,1),
    (2,2)
  ]
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # (1,4) },
    (1,1),
    (2,2)
  ]
  
  === Run 3 ===
  return 4
  State: [
    { resource_0 ↦ 1 # (1,4) },
    (1,1),
    (2,2)
  ]
  
  === Run 4 ===
  return 8
  State: [
    { resource_0 ↦ 1 # (1,4) },
    (1,1),
    (2,2)
  ]
  
  === Run 5 ===
  return 15
  State: [
    { resource_0 ↦ 7 # (2,5), resource_1 ↦ 1 # (1,4) },
    (1,1),
    (2,2)
  ]
  
  ======================================================================
  time_reject_within.tpe
  ======================================================================
  File "time_reject_within.tpe", line 6, characters 0-47:
  6 | operation Heat : unit ~> unit # 2 within (1, 2)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: runtime bounds are only used by the timed-trace grading monoids; under `time-lower-bound` the operation grade already carries them
  ======================================================================
  time_upper.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # 3 },
    1,
    2
  ]
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # 3 },
    2
  ]
  
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
    { resource_1 ↦
        fun op_var ↦ handle
                       return op_var
                     with printer
        # {Heat; Extrude; Cool}
    },
    {1},
    {3},
    {2}
  ]
  
  ======================================================================
  traces_intervals.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    ({1},{1}),
    { resource_0 ↦ Epoxy # ({8},{11}),
      resource_2 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            unbox resource_0 as g in
            perform Mount (p, g) (op_var. return op_var)
          with printer
        # ({Heat; Extrude; Cool},{Heat; Extrude; Cool})
    },
    ({1},{1}),
    ({3},{3}),
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # ({2},{2}) },
    ({2},{2}),
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # ({2},{8})
    },
    ({2},{2}),
    ({1},{1})
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
  File "traces_intervals_default_bounds.tpe", line 9, characters 0-28:
  9 | default Extrude () = delay 1
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Extrude` has grade `({1},{1})`, which does not match the declared grade `({3},{5})` of `Extrude`
    File "traces_intervals_default_bounds.tpe", line 7, characters 0-71:
    7 | operation Extrude : unit ~> unit # ({Extrude}, {Extrude}) within (3, 5)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the resource inequality `({1},{1}) <= ({3},{5})` does not hold
  ======================================================================
  traces_lower.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    {1},
    { resource_0 ↦ Epoxy # {8},
      resource_2 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            unbox resource_0 as g in
            perform Mount (p, g) (op_var. return op_var)
          with printer
        # {Heat; Extrude; Cool}
    },
    {1},
    {3},
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # {2} },
    {2},
    { resource_4 ↦ Printed (Cooled (Extruded (Heated (Model "Sword")))) # {2} },
    {2},
    {1}
  ]
  
  ======================================================================
  traces_normalise.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_0 ↦ 42 # {Heat; 4 | 4; Heat} }
  ]
  
  ======================================================================
  traces_reject_allowance.tpe
  ======================================================================
  File "traces_reject_allowance.tpe", lines 10-11, characters 2-3:
  10 |   unbox r as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed after grade `{Heat}` has elapsed, which does not match its box grade `{1}`
    File "traces_reject_allowance.tpe", line 8, characters 14-15:
    8 |   box 1 42 as r in
                      ^
    `r` is bound here
    File "traces_reject_allowance.tpe", line 9, characters 2-17:
    9 |   perform Heat ();
          ^^^^^^^^^^^^^^^
    `Heat` is performed here (grade `{Heat}`)
    Note: the resource inequality `{Heat} <= {1}` does not hold
  ======================================================================
  traces_reject_bounds.tpe
  ======================================================================
  File "traces_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Heat : unit ~> unit # {Heat} within (3, 0)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: the runtime bounds of operation `Heat` must satisfy `lo <= hi`
  ======================================================================
  traces_reject_bounds_declared.tpe
  ======================================================================
  File "traces_reject_bounds_declared.tpe", line 6, characters 0-61:
  6 | operation Send : string ~> unit # {Tx | Tx; Tx} within (2, 6)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: operation `Send` is compound, so its runtime bounds follow from its grade `{Tx | Tx; Tx}` and must not be declared
  ======================================================================
  traces_reject_default_bounds.tpe
  ======================================================================
  File "traces_reject_default_bounds.tpe", line 8, characters 0-28:
  8 | default Extrude () = delay 6
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Extrude` has grade `{6}`, which does not match the declared grade `{5}` of `Extrude`
    File "traces_reject_default_bounds.tpe", line 6, characters 0-58:
    6 | operation Extrude : unit ~> unit # {Extrude} within (3, 5)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the resource inequality `{6} <= {5}` does not hold
  ======================================================================
  traces_reject_default_nonatomic.tpe
  ======================================================================
  File "traces_reject_default_nonatomic.tpe", line 14, characters 0-39:
  14 | default PrintModel m = delay 6; Fresh m
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: a default implementation may only be given for an atomic operation, but the grade of `PrintModel` is `{Heat; Extrude; Cool}`; handle it with a handler in terms of the operations it names
  ======================================================================
  traces_reject_missing_within.tpe
  ======================================================================
  File "traces_reject_missing_within.tpe", line 5, characters 0-38:
  5 | operation Heat : unit ~> unit # {Heat}
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: atomic operation `Heat` needs runtime bounds `within (lo, hi)` under the `traces-upper-bound` grading monoid
  ======================================================================
  traces_reject_order.tpe
  ======================================================================
  File "traces_reject_order.tpe", lines 16-20, characters 4-31:
  16 |   | PrintModel m k ->
           ^^^^^^^^^^^^^^^^^
  Typing error: The case for `PrintModel` has grade `{Cool; Extrude; Heat}`, which does not match the grade `{Heat; Extrude; Cool}` of `PrintModel` followed by its continuation
    File "traces_reject_order.tpe", line 11, characters 0-61:
    11 | operation PrintModel : model ~> fresh # {Heat; Extrude; Cool}
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `PrintModel` is declared here
    Note: the resource inequality `{Cool; Extrude; Heat} <= {Heat; Extrude; Cool}` does not hold
  ======================================================================
  traces_reject_self_retry.tpe
  ======================================================================
  File "traces_reject_self_retry.tpe", line 6, characters 0-53:
  6 | operation Send : string ~> unit # {Send | Send; Send}
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: compound operation `Send` may not name itself in its grade `{Send | Send; Send}`
  ======================================================================
  traces_reject_unknown_event.tpe
  ======================================================================
  File "traces_reject_unknown_event.tpe", line 6, characters 0-53:
  6 | operation PrintModel : unit ~> unit # {Heat; Extrude}
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: unknown event `Extrude` in the grade of operation `PrintModel`
  ======================================================================
  traces_upper.tpe
  ======================================================================
  === Run 1 ===
  return (Receipt "telemetry")
  State: [
    { resource_0 ↦ Receipt "telemetry" # {6},
      resource_2 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_0 as r in
            return r
          with send_retry
        # {Tx | Tx; Tx}
    },
    {2},
    {2}
  ]
  
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
  return h
  State: []
  
  ======================================================================
  use_undefined_type.tpe
  ======================================================================
  File "use_undefined_type.tpe", line 1, characters 18-21:
  1 | type foo = One of bar | Two of int
                        ^^^
  Syntax error: Unknown name `bar`

The options: typechecking only reports errors and runs nothing, and the
single-dash form of the help option is not accepted.

  $ ../tempore --typecheck-only nat.tpe
  $ ../tempore --typecheck-only comp_type_annotation_reject.tpe
  File "comp_type_annotation_reject.tpe", line 3, characters 9-31:
  3 | let f () : int # 5 = delay 3; 1
               ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `3`, which does not match its annotated grade `5`
    Note: the resource inequality `3 >= 5` does not hold
  [1]
  $ ../tempore -help
  ../tempore: unknown option '-help'.
  Run Tempore as '../tempore [filename.tpe] ...'
    --debug           Show final internal state and top level typing results after execution
    --help            Display this list of options
    --no-stdlib       Do not load the standard library
    --resources       Type of resource grades to use (default: time-lower-bound). Accepted: 'time-lower-bound', 'time-upper-bound', 'time-interval', 'traces-lower-bound', 'traces-upper-bound', 'traces-interval'
    --typecheck-only  Typecheck the files without running them
  [2]
