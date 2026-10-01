  $ for f in *.tpe
  > do
  >   echo "======================================================================"
  >   echo $f
  >   echo "======================================================================"
  >   case $f in
  >     time_intervals.tpe) ../tempore --grades time-interval $f;;
  >     rational_time_lower*.tpe) ../tempore --grades time-lower-bound-rational $f;;
  >     rational_time_upper*.tpe) ../tempore --grades time-upper-bound-rational $f;;
  >     rational_time_intervals*.tpe) ../tempore --grades time-interval-rational $f;;
  >     rational_traces_upper*.tpe) ../tempore --grades traces-cost-upper-bound-rational $f;;
  >     rational_traces_intervals*.tpe) ../tempore --grades traces-cost-interval-rational $f;;
  >     plain_traces_upper*.tpe) ../tempore --grades traces-upper-bound $f;;
  >     plain_rational_traces_upper*.tpe) ../tempore --grades traces-upper-bound-rational $f;;
  >     literals_rational_upper.tpe) ../tempore --grades time-upper-bound-rational $f;;
  >     literals_rational_interval.tpe) ../tempore --grades time-interval-rational $f;;
  >     literals_reject_rational_negative.tpe) ../tempore --grades time-upper-bound-rational $f;;
  >     literals_reject_fraction.tpe) ../tempore --grades time-upper-bound $f;;
  >     delay_reject_fraction.tpe) ../tempore --grades time-upper-bound $f;;
  >     default_reject_unestablished.tpe) ../tempore --grades time-upper-bound $f;;
  >     time_upper.tpe) ../tempore --grades time-upper-bound $f;;
  >     comp_type_annotation_upper*.tpe) ../tempore --grades time-upper-bound $f;;
  >     annotation_grade_variables_interval_reject.tpe) ../tempore --grades time-interval $f;;
  >     annotation_grade_variables*.tpe) ../tempore --grades time-upper-bound $f;;
  >     eternal_lower.tpe) ../tempore $f;;
  >     eternal_*.tpe) ../tempore --grades time-upper-bound $f;;
  >     noneternal_lower.tpe) ../tempore $f;;
  >     noneternal*.tpe) ../tempore --grades time-upper-bound $f;;
  >     continuation_discard_reject_lower.tpe) ../tempore $f;;
  >     continuation_discard_abort_reject_lower.tpe) ../tempore $f;;
  >     continuation_discard_delay_reject_lower.tpe) ../tempore $f;;
  >     continuation_obligation_lower.tpe) ../tempore $f;;
  >     continuation_nested_discard_reject_lower.tpe) ../tempore $f;;
  >     continuation_twice_lower.tpe) ../tempore $f;;
  >     continuation_*.tpe) ../tempore --grades time-upper-bound $f;;
  >     error_use_after_delay.tpe) ../tempore --grades time-upper-bound $f;;
  >     traces_lower.tpe) ../tempore --grades traces-cost-lower-bound $f;;
  >     3dprint_traces.tpe) ../tempore --grades traces-cost-interval $f;;
  >     traces_intervals.tpe) ../tempore --grades traces-cost-interval $f;;
  >     traces_intervals_bounds.tpe) ../tempore --grades traces-cost-interval $f;;
  >     traces_intervals_default_bounds.tpe) ../tempore --grades traces-cost-interval $f;;
  >     traces_intervals_default_open_reject.tpe) ../tempore --grades traces-cost-interval $f;;
  >     traces_*.tpe) ../tempore --grades traces-cost-upper-bound $f;;
  >     levels_time_lower*.tpe) ../tempore --grades time-lower-bound-levels $f;;
  >     levels_time_upper*.tpe) ../tempore --grades time-upper-bound-levels $f;;
  >     levels*.tpe) ../tempore --grades security-levels $f;;
  >     literals_time_upper.tpe) ../tempore --grades time-upper-bound $f;;
  >     literals_time_interval.tpe) ../tempore --grades time-interval $f;;
  >     literals_reject_interval_*.tpe) ../tempore --grades time-interval $f;;
  >     literals_reject_within_*.tpe) ../tempore --grades traces-cost-upper-bound $f;;
  >     literals_traces.tpe) ../tempore --grades traces-cost-interval $f;;
  >     literals_reject_star.tpe) ../tempore --grades traces-cost-upper-bound $f;;
  >     literals_reject_component.tpe) ../tempore --grades time-lower-bound-levels $f;;
  >     literals_reject_complement.tpe) ../tempore --grades traces-cost-upper-bound $f;;
  >     literals_reject_empty.tpe) ../tempore --grades regex-upper-bound-symbolic $f;;
  >     literals_regular.tpe) ../tempore --grades regex-upper-bound-symbolic $f;;
  >     regular_*.tpe) ../tempore --grades regex-upper-bound-symbolic $f;;
  >     regex_rational*.tpe) ../tempore --grades regex-upper-bound-rational-symbolic $f;;
  >     regex_costs_rational_lower*.tpe) ../tempore --grades regex-cost-lower-bound-rational-symbolic $f;;
  >     regex_costs_rational_upper*.tpe) ../tempore --grades regex-cost-upper-bound-rational-symbolic $f;;
  >     regex_costs_rational_interval*.tpe) ../tempore --grades regex-cost-interval-rational-symbolic $f;;
  >     regex_costs_lower*.tpe) ../tempore --grades regex-cost-lower-bound-symbolic $f;;
  >     regex_costs_upper*.tpe) ../tempore --grades regex-cost-upper-bound-symbolic $f;;
  >     regex_costs_interval*.tpe) ../tempore --grades regex-cost-interval-symbolic $f;;
  >     resource_levels*.tpe) ../tempore --grades resource-levels $f;;
  >     literals_reject_peak.tpe) ../tempore --grades resource-levels $f;;
  >     literals_reject_resource_levels_range_empty.tpe) ../tempore --grades resource-levels $f;;
  >     windowed_schedules*.tpe) ../tempore --grades windowed-schedules $f;;
  >     literals_reject_windowed_schedules.tpe) ../tempore --grades windowed-schedules $f;;
  >     literals_reject_windowed_schedules_empty.tpe) ../tempore --grades windowed-schedules $f;;
  >     flow_levels*.tpe) ../tempore --grades flow-levels $f;;
  >     literals_reject_flow.tpe) ../tempore --grades flow-levels $f;;
  >     counts*.tpe) ../tempore --grades counts-upper-bound $f;;
  >     literals_reject_counts.tpe) ../tempore --grades counts-upper-bound $f;;
  >     mode_switch_costs*.tpe) ../tempore --grades mode-switch-costs $f;;
  >     literals_reject_modes.tpe) ../tempore --grades mode-switch-costs $f;;
  >     recursion_lock_lower.tpe) ../tempore $f;;
  >     recursion_lock*.tpe) ../tempore --grades time-upper-bound $f;;
  >     recursion_effect_regular.tpe) ../tempore --grades regex-upper-bound-symbolic $f;;
  >     recursion_effect_reject_unannotated_regular.tpe) ../tempore --grades regex-upper-bound-symbolic $f;;
  >     recursion_effect_levels.tpe) ../tempore --grades security-levels $f;;
  >     recursion_effect_reject_lower.tpe) ../tempore $f;;
  >     recursion_effect_*.tpe) ../tempore --grades time-upper-bound $f;;
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
    [{1}, {1}],
    { resource_0 ↦ Epoxy # [{8}, {11}],
      resource_2 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            unbox resource_0 as g in
            perform Mount (p, g) (op_var. return op_var)
          with printer
        # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]
    },
    [{1}, {1}],
    [{3}, {3}],
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{2}, {2}],
    [{1}, {1}]
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
        # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]
    },
    [{1}, {1}],
    [{3}, {3}],
    { resource_2 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_3 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{2}, {2}]
  ]
  
  === Run 3 ===
  return (Model "Sword")
  State: [
    [{1}, {1}]
  ]
  
  === Run 4 ===
  return Epoxy
  State: []
  
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
    { resource_0 ↦ fun () ↦ delay 2 (return ());
                            return 5 # 2 },
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
  File "annotation_grade_variables_cyclic_reject.tpe", line 14, characters 22-23:
  14 | let h () : unit # 5 = f (fun () -> ())
                             ^
  Typing error: The effect inequality `10 <= 5` does not hold
    File "annotation_grade_variables_cyclic_reject.tpe", line 10, characters 0-58:
    10 | let f (g : unit -> unit # 'e) : unit # 'e = g (); delay 10
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `f` is defined here
    File "annotation_grade_variables_cyclic_reject.tpe", line 14, characters 9-38:
    14 | let h () : unit # 5 = f (fun () -> ())
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  
  File "annotation_grade_variables_cyclic_reject.tpe", line 27, characters 4-7:
  27 | run bad ()
           ^^^
  Typing error: The conditions of this run could not be established: `1 · ε₀ <= 3` and `1 · ε₀ <= ε₀`
    File "annotation_grade_variables_cyclic_reject.tpe", line 23, characters 0-31:
    23 | let bad () : unit # 3 = loop 20
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `bad` is defined here
    File "annotation_grade_variables_cyclic_reject.tpe", lines 18-19, characters 0-51:
    18 | let rec loop (n : nat) : unit # 'e =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `loop` is defined here
    Note: this run requires grades for its unknowns at which every one of these holds; none of the grades tried does, although the definitions they come from were accepted
  ======================================================================
  annotation_grade_variables_interval_reject.tpe
  ======================================================================
  File "annotation_grade_variables_interval_reject.tpe", line 24, characters 27-28:
  24 | let h () : unit # [0, 5] = f (fun () -> ())
                                  ^
  Typing error: The effect inequality `[10, 10] <= [0, 5]` does not hold
    File "annotation_grade_variables_interval_reject.tpe", line 13, characters 0-58:
    13 | let f (g : unit -> unit # 'e) : unit # 'e = g (); delay 10
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `f` is defined here
    File "annotation_grade_variables_interval_reject.tpe", line 24, characters 9-43:
    24 | let h () : unit # [0, 5] = f (fun () -> ())
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  ======================================================================
  annotation_grade_variables_reject.tpe
  ======================================================================
  File "annotation_grade_variables_reject.tpe", line 11, characters 37-69:
  11 |   ((slow : (unit -> nat # 'e) list), (fast : (unit -> nat # 'e) list))
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This expression has type `(unit → nat # 1) list` but is annotated with `(unit → nat # 2) list`
    File "annotation_grade_variables_reject.tpe", line 11, characters 3-35:
    11 |   ((slow : (unit -> nat # 'e) list), (fast : (unit -> nat # 'e) list))
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
    Note: the effect inequality `2 <= 1` does not hold
  
  File "annotation_grade_variables_reject.tpe", line 17, characters 27-70:
  17 | let violated () = run_fast ((fun () -> delay 2; 0) : unit -> nat # 'e)
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `2`, which does not match its annotated grade `1`
    File "annotation_grade_variables_reject.tpe", line 17, characters 18-26:
    17 | let violated () = run_fast ((fun () -> delay 2; 0) : unit -> nat # 'e)
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
  File "comp_type_annotation_upper_reject.tpe", line 3, characters 9-31:
  3 | let f () : nat # 2 = delay 3; 1
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
  return (fun () ↦
            let f = (unbox resource_1 as unbox_var in
                     unbox_var ()) in
            f ())
  State: [
    { resource_1 ↦ fun op_var ↦ handle
                                  return op_var;
                                  return 3
                                with h # 1 }
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
  File "continuation_nested_escape_reject.tpe", line 23, characters 23-24:
  23 |          | Op2 q k' -> g k'; delay 1; continue k' with ())
                              ^
  Typing error: Variable `g` has type `[1](unit → α # ε₀) → β`, which is not eternal, so it cannot be used in the case for `Op1`: the case runs with a grade the handler does not fix
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
    the case for `Op1` is checked with the top grade `∞` accumulated
    File "continuation_nested_escape_reject.tpe", line 23, characters 11-57:
    23 |          | Op2 q k' -> g k'; delay 1; continue k' with ())
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op2` is checked with the top grade `∞` accumulated
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  continuation_nested_fixed.tpe
  ======================================================================
  === Run 1 ===
  return (fun () ↦
            let f = (unbox resource_3 as unbox_var in
                     unbox_var ()) in
            f ())
  State: [
    { resource_1 ↦ fun op_var ↦ handle
                                  return op_var;
                                  return 7
                                with h # 1,
      resource_3 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_1 as unbox_var in
            unbox_var ()
          with handler
               | return y ↦ return y
               | Op2 (q, k') ↦
                       return (fun () ↦
                                 let f = (unbox k' as unbox_var in
                                          unbox_var ()) in
                                 f ())
        # 1
    }
  ]
  
  ======================================================================
  continuation_nested_twice_reject_upper.tpe
  ======================================================================
  File "continuation_nested_twice_reject_upper.tpe", line 24, characters 15-34:
  24 |                continue k' with ())
                      ^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k'` is unboxed with grade `∣ε_Op2∣` accumulated since it was bound, which is not below its box grade `1`
    File "continuation_nested_twice_reject_upper.tpe", line 23, characters 23-42:
    23 |                let b = continue k' with () in
                                ^^^^^^^^^^^^^^^^^^^
    grade `ε_Op2` accumulates here (this computation)
    File "continuation_nested_twice_reject_upper.tpe", line 22, characters 19-21:
    22 |            | Op2 q k' ->
                            ^^
    `k'` may have any grade `ε_Op2`
    Note: the resource inequality `∀ε_Op2. ∣ε_Op2∣ <= 1` does not hold: for `ε_Op2 = ∞` it becomes `∞ <= 1`
  ======================================================================
  continuation_obligation_lower.tpe
  ======================================================================
  === Run 1 ===
  return 3
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var;
            return 3
          with handler
               | return x ↦ return x
               | Op ((), k) ↦
                      (fun () ↦ delay 1 (return ())) ();
                      unbox k as unbox_var in
                      unbox_var ()
        # 1
    },
    1
  ]
  
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
  File "continuation_twice_reject_upper.tpe", line 10, characters 67-85:
  10 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                                                          ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `∣ε_Op∣` accumulated since it was bound, which is not below its box grade `1`
    File "continuation_twice_reject_upper.tpe", line 10, characters 45-63:
    10 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
                                                      ^^^^^^^^^^^^^^^^^^
    grade `ε_Op` accumulates here (this computation)
    File "continuation_twice_reject_upper.tpe", line 10, characters 32-33:
    10 | let h = handler | x -> x | Op p k -> let a = continue k with () in continue k with ()
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var;
            perform Send 2 (op_var. return op_var);
            perform Send 3 (op_var. return op_var)
          with handler
               | return x ↦ return x
               | Send (n, k) ↦ unbox k as unbox_var in
                               unbox_var ()
        # (Send, 1),
      resource_3 ↦
        fun op_var ↦
          handle
            return op_var;
            perform Send 3 (op_var. return op_var)
          with handler
               | return x ↦ return x
               | Send (n, k) ↦ unbox k as unbox_var in
                               unbox_var ()
        # (Send, 1),
      resource_5 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Send (n, k) ↦ unbox k as unbox_var in
                               unbox_var ()
        # (Send, 1)
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
  File "counts_upper_reject.tpe", lines 7-11, characters 12-16:
  7 | let four () : unit # (Send, 3) =
                  ^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Send, 4)`, which does not match its annotated grade `(Send, 3)`
    Note: the effect inequality `(Send, 4) <= (Send, 3)` does not hold
  
  File "counts_upper_reject.tpe", lines 14-16, characters 16-16:
  14 | let unlisted () : unit # (Send, 3) =
                       ^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `((Auth, 1), (Send, 1))`, which does not match its annotated grade `(Send, 3)`
    Note: the effect inequality `((Auth, 1), (Send, 1)) <= (Send, 3)` does not hold
  
  File "counts_upper_reject.tpe", lines 23-24, characters 2-3:
  23 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(Send, 2)` accumulated since it was bound, which is not below its box grade `(Send, 1)`
    File "counts_upper_reject.tpe", line 20, characters 21-22:
    20 |   box (Send, 1) 7 as x in
                              ^
    `x` is bound here
    File "counts_upper_reject.tpe", line 21, characters 2-16:
    21 |   perform Send 1;
           ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "counts_upper_reject.tpe", line 22, characters 2-16:
    22 |   perform Send 2;
           ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    Note: the resource inequality `(Send, 2) <= (Send, 1)` does not hold
  
  File "counts_upper_reject.tpe", line 31, characters 48-66:
  31 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                                                       ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(Send, 2)` accumulated since it was bound, which is not below its box grade `(Send, 1)`
    File "counts_upper_reject.tpe", line 31, characters 11-12:
    31 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                    ^
    `k` is bound here
    File "counts_upper_reject.tpe", line 31, characters 16-30:
    31 |   | Send n k -> perform Send n; perform Send n; continue k with ()
                         ^^^^^^^^^^^^^^
    grade `(Send, 1)` accumulates here (operation `Send`)
    File "counts_upper_reject.tpe", line 31, characters 32-46:
    31 |   | Send n k -> perform Send n; perform Send n; continue k with ()
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Report (msg, k) ↦
                          delay 1 (return ());
                          unbox k as unbox_var in
                          unbox_var ()
        # 1
    },
    1
  ]
  
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
  Typing error: operation `Log` already has a default implementation
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
  File "default_reject_unknown.tpe", line 5, characters 0-25:
  5 | default Log msg = delay 1
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: Unknown name `Log`
  ======================================================================
  delay_reject_expression.tpe
  ======================================================================
  File "delay_reject_expression.tpe", line 4, characters 20-21:
  4 | let wait () = delay (1 + 1)
                          ^
  Syntax error: the argument of 'delay' is a duration literal, such as '2', '1/2' or '0.25'
  ======================================================================
  delay_reject_fraction.tpe
  ======================================================================
  File "delay_reject_fraction.tpe", line 4, characters 20-23:
  4 | let wait () = delay 0.5
                          ^^^
  Syntax error: in the 'time-upper-bound' grading monoid, delays are whole numbers of time steps; did you mean to use one of the 'time-lower-bound-rational', 'time-upper-bound-rational', 'time-interval-rational', 'traces-upper-bound-rational', 'traces-cost-lower-bound-rational', 'traces-cost-upper-bound-rational', 'traces-cost-interval-rational', 'regex-upper-bound-rational-symbolic', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic', 'regex-cost-interval-rational-symbolic', 'security-levels' or 'flow-levels' grading monoids?
  ======================================================================
  delay_reject_variable.tpe
  ======================================================================
  File "delay_reject_variable.tpe", line 6, characters 8-9:
  6 |   delay n
              ^
  Syntax error: the argument of 'delay' is a duration literal, such as '2', '1/2' or '0.25'
  ======================================================================
  duplicate_variant_tydef_sum.tpe
  ======================================================================
  File "duplicate_variant_tydef_sum.tpe", line 3, characters 0-39:
  3 | type cow = Horn of nat | Horn of string
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
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
  Typing error: `unit → unit # ε₀` is not eternal, but `keep` needs the type of `x` to be eternal
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
    grade `1` accumulates here (delay)
    File "eternal_tyvars_reject_function.tpe", line 5, characters 22-23:
    5 | let keep x = delay 1; x
                              ^
    `x` is used here with grade `1` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_handler.tpe
  ======================================================================
  File "eternal_tyvars_reject_handler.tpe", line 12, characters 48-49:
  12 | run handle (perform Op (); (fun () -> ())) with h (fun () -> ())
                                                       ^
  Typing error: `unit → unit # ε₀` is not eternal, but `h` needs the type of `x` to be eternal
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
    the case for `Op` is checked with the top grade `∞` accumulated
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 47-65:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                       ^^^^^^^^^^^^^^^^^^
    grade `ε₁` accumulates here (this computation)
    File "eternal_tyvars_reject_handler.tpe", line 9, characters 69-70:
    9 | let h x = handler | y -> y | Op p k -> let r = continue k with () in x
                                                                             ^
    `x` is used here, in the case for `Op`
    Note: the resource inequality `∞ <= 0` does not hold
  ======================================================================
  eternal_tyvars_reject_higher_order.tpe
  ======================================================================
  File "eternal_tyvars_reject_higher_order.tpe", line 9, characters 4-9:
  9 | run after (fun () -> delay 2) (fun () -> ())
          ^^^^^
  Typing error: `unit → unit # ε₀` is not eternal, but `after` needs the type of `x` to be eternal
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
    grade `2` accumulates here (this computation)
    File "eternal_tyvars_reject_higher_order.tpe", line 5, characters 22-23:
    5 | let after g x = g (); x
                              ^
    `x` is used here with grade `2` accumulated since it was bound, which only an eternal type allows
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
    grade `1` accumulates here (delay)
    File "eternal_tyvars_reject_noneternal.tpe", line 7, characters 22-23:
    7 | let keep x = delay 1; x
                              ^
    `x` is used here with grade `1` accumulated since it was bound, which only an eternal type allows
    Note: the resource inequality `1 <= 0` does not hold
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return () ↦ return 0
               | Put ((n, _), k) ↦
                       delay 1 (return ());
                       unbox k as unbox_var in
                       unbox_var ()
        # 1
    },
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var;
            perform ReadSecret () (op_var. return op_var);
            return ()
          with handler
               | return x ↦ return x
               | Post (n, k) ↦ unbox k as unbox_var in
                               unbox_var ()
        # (Low, (Board, Low))
    }
  ]
  
  === Run 4 ===
  return 7
  State: [
    { resource_0 ↦ 7 # (High, (Board, Low)) }
  ]
  
  ======================================================================
  flow_levels_reject.tpe
  ======================================================================
  File "flow_levels_reject.tpe", lines 8-10, characters 18-16:
  8 | let post_after () : unit # (High, (Board, Low)) =
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(High, (Board, High))`, which does not match its annotated grade `(High, (Board, Low))`
    Note: the effect inequality `(High, (Board, High)) <= (High, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", lines 13-15, characters 16-15:
  13 | let unlisted () : unit # (Low, (Board, Low)) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Low, (Audit, Low), (Board, Low))`, which does not match its annotated grade `(Low, (Board, Low))`
    Note: the effect inequality `(Low, (Audit, Low), (Board, Low)) <= (Low, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", lines 22-23, characters 2-3:
  22 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(High, (Board, High))` accumulated since it was bound, which is not below its box grade `(High, (Board, Low))`
    File "flow_levels_reject.tpe", line 19, characters 32-33:
    19 |   box (High, (Board, Low)) 7 as x in
                                         ^
    `x` is bound here
    File "flow_levels_reject.tpe", line 20, characters 10-31:
    20 |   let s = perform ReadSecret () in
                   ^^^^^^^^^^^^^^^^^^^^^
    grade `High` accumulates here (operation `ReadSecret`)
    File "flow_levels_reject.tpe", line 21, characters 2-16:
    21 |   perform Post s;
           ^^^^^^^^^^^^^^
    grade `(Low, (Board, Low))` accumulates here (operation `Post`)
    Note: the resource inequality `(High, (Board, High)) <= (High, (Board, Low))` does not hold
  
  File "flow_levels_reject.tpe", line 30, characters 31-49:
  30 |   | Log n k -> perform Post n; continue k with ()
                                      ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(Low, (Board, Low))` accumulated since it was bound, which is not below its box grade `(Low, (Audit, Low))`
    File "flow_levels_reject.tpe", line 30, characters 10-11:
    30 |   | Log n k -> perform Post n; continue k with ()
                   ^
    `k` is bound here
    File "flow_levels_reject.tpe", line 30, characters 15-29:
    30 |   | Log n k -> perform Post n; continue k with ()
                        ^^^^^^^^^^^^^^
    grade `(Low, (Board, Low))` accumulates here (operation `Post`)
    Note: the resource inequality `(Low, (Board, Low)) <= (Low, (Audit, Low))` does not hold
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
  File "levels_reject.tpe", lines 11-12, characters 2-3:
  11 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `High` accumulated since it was bound, which is not below its box grade `Low`
    File "levels_reject.tpe", line 9, characters 22-23:
    9 |   box Low "public" as r in
                              ^
    `r` is bound here
    File "levels_reject.tpe", line 10, characters 2-23:
    10 |   perform Send "secret";
           ^^^^^^^^^^^^^^^^^^^^^
    grade `High` accumulates here (operation `Send`)
    Note: the resource inequality `High <= Low` does not hold
  ======================================================================
  levels_reject_literal.tpe
  ======================================================================
  File "levels_reject_literal.tpe", line 3, characters 19-20:
  3 | let claim () = box 3 1
                         ^
  Syntax error: in the 'security-levels' grading monoid, grades are the levels 'Low' and 'High', not plain integers; did you mean to use one of the 'time-lower-bound', 'time-upper-bound', 'time-lower-bound-rational', 'time-upper-bound-rational', 'traces-upper-bound', 'traces-upper-bound-rational', 'traces-cost-lower-bound', 'traces-cost-upper-bound', 'traces-cost-interval', 'traces-cost-lower-bound-rational', 'traces-cost-upper-bound-rational', 'traces-cost-interval-rational', 'regex-upper-bound-symbolic', 'regex-upper-bound-rational-symbolic', 'regex-cost-lower-bound-symbolic', 'regex-cost-upper-bound-symbolic', 'regex-cost-interval-symbolic', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic', 'regex-cost-interval-rational-symbolic', 'windowed-schedules', 'mode-switch-costs' or 'counts-upper-bound' grading monoids?
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
  File "levels_time_lower_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `(2, Low)` accumulated since it was bound, which is not below its box grade `(3, Low)`
    File "levels_time_lower_reject.tpe", line 10, characters 27-28:
    10 |   box (3, Low) "report" as r in
                                    ^
    `r` is bound here
    File "levels_time_lower_reject.tpe", line 11, characters 2-9:
    11 |   delay 2;
           ^^^^^^^
    grade `(2, Low)` accumulates here (delay)
    Note: the resource inequality `(2, Low) ≾ (3, Low)` does not hold
  
  File "levels_time_lower_reject.tpe", lines 20-21, characters 2-3:
  20 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `(3, High)` accumulated since it was bound, which is not below its box grade `(3, Low)`
    File "levels_time_lower_reject.tpe", line 17, characters 27-28:
    17 |   box (3, Low) "report" as r in
                                    ^
    `r` is bound here
    File "levels_time_lower_reject.tpe", line 18, characters 2-24:
    18 |   perform Publish "news";
           ^^^^^^^^^^^^^^^^^^^^^^
    grade `(1, High)` accumulates here (operation `Publish`)
    File "levels_time_lower_reject.tpe", line 19, characters 2-9:
    19 |   delay 2;
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
  File "levels_time_upper_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox c as t in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `(6, Low)` accumulated since it was bound, which is not below its box grade `(5, Low)`
    File "levels_time_upper_reject.tpe", line 10, characters 26-27:
    10 |   box (5, Low) "token" as c in
                                   ^
    `c` is bound here
    File "levels_time_upper_reject.tpe", line 11, characters 2-9:
    11 |   delay 6;
           ^^^^^^^
    grade `(6, Low)` accumulates here (delay)
    Note: the resource inequality `(6, Low) <= (5, Low)` does not hold
  
  File "levels_time_upper_reject.tpe", lines 19-20, characters 2-3:
  19 |   unbox c as t in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `(1, High)` accumulated since it was bound, which is not below its box grade `(5, Low)`
    File "levels_time_upper_reject.tpe", line 17, characters 26-27:
    17 |   box (5, Low) "token" as c in
                                   ^
    `c` is bound here
    File "levels_time_upper_reject.tpe", line 18, characters 2-23:
    18 |   perform Leak "secret";
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
  File "literals_reject_complement.tpe", line 4, characters 19-32:
  4 | let claim () = box {Send; ~Read} 1
                         ^^^^^^^^^^^^^
  Syntax error: in the 'traces-cost-upper-bound' grading monoid, sets of traces are built from operation names and delays with ';' and '|' only, without complement '~'; did you mean to use one of the 'regex-upper-bound-symbolic', 'regex-upper-bound-rational-symbolic', 'regex-cost-lower-bound-symbolic', 'regex-cost-upper-bound-symbolic', 'regex-cost-interval-symbolic', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic' or 'regex-cost-interval-rational-symbolic' grading monoids?
  ======================================================================
  literals_reject_component.tpe
  ======================================================================
  File "literals_reject_component.tpe", line 3, characters 19-30:
  3 | let claim () = box (3, Medium) 1
                         ^^^^^^^^^^^
  Syntax error: in the 'time-lower-bound-levels' grading monoid, in the second component ('security-levels'), unknown level 'Medium'; the levels are 'Low' and 'High'
  ======================================================================
  literals_reject_counts.tpe
  ======================================================================
  File "literals_reject_counts.tpe", line 3, characters 19-29:
  3 | let claim () = box (Send, -1) 1
                         ^^^^^^^^^^
  Syntax error: in the 'counts-upper-bound' grading monoid, in the entry of 'Send', grades must be non-negative
  ======================================================================
  literals_reject_empty.tpe
  ======================================================================
  File "literals_reject_empty.tpe", line 4, characters 19-33:
  4 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: in the 'regex-upper-bound-symbolic' grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_reject_flow.tpe
  ======================================================================
  File "literals_reject_flow.tpe", line 3, characters 19-54:
  3 | let claim () = box (High, (Board, Low), (Board, High)) 1
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Syntax error: in the 'flow-levels' grading monoid, the output 'Board' is listed twice
  ======================================================================
  literals_reject_fraction.tpe
  ======================================================================
  File "literals_reject_fraction.tpe", line 4, characters 19-22:
  4 | let claim () = box 3/2 1
                         ^^^
  Syntax error: in the 'time-upper-bound' grading monoid, grades are plain integers or '∞', not fractions such as '3/2'; did you mean to use one of the 'time-lower-bound-rational', 'time-upper-bound-rational', 'traces-upper-bound-rational', 'traces-cost-lower-bound-rational', 'traces-cost-upper-bound-rational', 'traces-cost-interval-rational', 'regex-upper-bound-rational-symbolic', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic' or 'regex-cost-interval-rational-symbolic' grading monoids?
  ======================================================================
  literals_reject_fraction_operator.tpe
  ======================================================================
  File "literals_reject_fraction_operator.tpe", line 3, characters 20-21:
  3 | let claim () = box 3%2 1
                          ^
  Syntax error: unknown operator '%' in a fraction
  ======================================================================
  literals_reject_fraction_zero.tpe
  ======================================================================
  File "literals_reject_fraction_zero.tpe", line 3, characters 21-22:
  3 | let claim () = box 1/0 1
                           ^
  Syntax error: fractions have positive denominators
  ======================================================================
  literals_reject_inf.tpe
  ======================================================================
  File "literals_reject_inf.tpe", line 3, characters 19-22:
  3 | let claim () = box ∞ 1
                         ^^^
  Syntax error: in the 'time-lower-bound' grading monoid, grades are plain integers, not '∞'; did you mean to use one of the 'time-upper-bound', 'time-upper-bound-rational', 'mode-switch-costs' or 'counts-upper-bound' grading monoids?
  ======================================================================
  literals_reject_interval_closed_infinity.tpe
  ======================================================================
  File "literals_reject_interval_closed_infinity.tpe", line 4, characters 19-27:
  4 | let claim () = box [2, ∞] 1
                         ^^^^^^^^
  Syntax error: an infinite endpoint of an interval is written with a parenthesis, as in '[n, ∞)'
  ======================================================================
  literals_reject_interval_empty.tpe
  ======================================================================
  File "literals_reject_interval_empty.tpe", line 4, characters 19-25:
  4 | let claim () = box [2, 2) 1
                         ^^^^^^
  Syntax error: in the 'time-interval' grading monoid, interval endpoints must satisfy n < m at an open endpoint
  ======================================================================
  literals_reject_interval_no_step.tpe
  ======================================================================
  File "literals_reject_interval_no_step.tpe", line 4, characters 19-25:
  4 | let claim () = box (1, 2) 1
                         ^^^^^^
  Syntax error: in the 'time-interval' grading monoid, the interval contains no integer; did you mean to use one of the 'time-interval-rational', 'regex-cost-interval-rational-symbolic' or 'resource-levels' grading monoids?
  ======================================================================
  literals_reject_interval_reversed.tpe
  ======================================================================
  File "literals_reject_interval_reversed.tpe", line 3, characters 19-25:
  3 | let claim () = box [5, 2] 1
                         ^^^^^^
  Syntax error: in the 'time-interval' grading monoid, interval endpoints must satisfy n <= m
  ======================================================================
  literals_reject_large.tpe
  ======================================================================
  File "literals_reject_large.tpe", line 3, characters 19-39:
  3 | let claim () = box 99999999999999999999 1
                         ^^^^^^^^^^^^^^^^^^^^
  Syntax error: Grade literal 99999999999999999999 is too large
  ======================================================================
  literals_reject_modes.tpe
  ======================================================================
  File "literals_reject_modes.tpe", line 3, characters 19-31:
  3 | let claim () = box (On, Off, 0) 1
                         ^^^^^^^^^^^^
  Syntax error: in the 'mode-switch-costs' grading monoid, in the cost from 'On' to 'Off', a change of mode costs at least 1
  ======================================================================
  literals_reject_name.tpe
  ======================================================================
  File "literals_reject_name.tpe", line 3, characters 19-22:
  3 | let claim () = box Low 1
                         ^^^
  Syntax error: in the 'time-lower-bound' grading monoid, grades are plain integers, not names such as 'Low'; did you mean to use one of the 'security-levels' or 'flow-levels' grading monoids?
  ======================================================================
  literals_reject_negative.tpe
  ======================================================================
  File "literals_reject_negative.tpe", line 3, characters 19-21:
  3 | let claim () = box -1 1
                         ^^
  Syntax error: in the 'time-lower-bound' grading monoid, grades must be non-negative
  ======================================================================
  literals_reject_peak.tpe
  ======================================================================
  File "literals_reject_peak.tpe", line 3, characters 19-25:
  3 | let claim () = box (2, 1) 1
                         ^^^^^^
  Syntax error: in the 'resource-levels' grading monoid, the peak must be at least 0 and at least the net change
  ======================================================================
  literals_reject_rational_negative.tpe
  ======================================================================
  File "literals_reject_rational_negative.tpe", line 3, characters 19-23:
  3 | let claim () = box -0.5 1
                         ^^^^
  Syntax error: in the 'time-upper-bound-rational' grading monoid, grades must be non-negative
  ======================================================================
  literals_reject_resource_levels_range_empty.tpe
  ======================================================================
  File "literals_reject_resource_levels_range_empty.tpe", line 3, characters 19-30:
  3 | let claim () = box ((0, 1), 1) 1
                         ^^^^^^^^^^^
  Syntax error: in the 'resource-levels' grading monoid, in the net change, the interval contains no integer
  ======================================================================
  literals_reject_star.tpe
  ======================================================================
  File "literals_reject_star.tpe", line 3, characters 19-31:
  3 | let claim () = box {(Send; 2)*} 1
                         ^^^^^^^^^^^^
  Syntax error: in the 'traces-cost-upper-bound' grading monoid, sets of traces are built from operation names and delays with ';' and '|' only, without repetition '*'; did you mean to use one of the 'regex-upper-bound-symbolic', 'regex-upper-bound-rational-symbolic', 'regex-cost-lower-bound-symbolic', 'regex-cost-upper-bound-symbolic', 'regex-cost-interval-symbolic', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic' or 'regex-cost-interval-rational-symbolic' grading monoids?
  ======================================================================
  literals_reject_unknown.tpe
  ======================================================================
  File "literals_reject_unknown.tpe", line 3, characters 19-26:
  3 | let claim () = box forever 1
                         ^^^^^^^
  Syntax error: 'forever' is no grade literal; grades are written as integers, fractions such as '3/2' or '1.5', names such as 'High', '⊤' (ASCII 'top'), '∞' (ASCII 'inf'), tuples '(...)', intervals '[...]' and brace literals '{...}'
  ======================================================================
  literals_reject_windowed_schedules.tpe
  ======================================================================
  File "literals_reject_windowed_schedules.tpe", line 3, characters 19-27:
  3 | let claim () = box (1, {0}) 1
                         ^^^^^^^^
  Syntax error: in the 'windowed-schedules' grading monoid, times are given by operation, e.g. '(1, (Send, {0}))' for 'Send' at the start, or '(1, (_, {0}))' for any operation
  ======================================================================
  literals_reject_windowed_schedules_empty.tpe
  ======================================================================
  File "literals_reject_windowed_schedules_empty.tpe", line 4, characters 19-25:
  4 | let claim () = box (2, 3) 1
                         ^^^^^^
  Syntax error: in the 'windowed-schedules' grading monoid, the interval contains no integer; did you mean to use one of the 'time-interval-rational', 'regex-cost-interval-rational-symbolic' or 'resource-levels' grading monoids?
  ======================================================================
  literals_reject_within_empty.tpe
  ======================================================================
  File "literals_reject_within_empty.tpe", line 4, characters 46-52:
  4 | operation Send : unit ~> unit # {Send} within [2, 2)
                                                    ^^^^^^
  Syntax error: interval endpoints must satisfy n < m at an open endpoint
  ======================================================================
  literals_reject_within_no_step.tpe
  ======================================================================
  File "literals_reject_within_no_step.tpe", line 4, characters 46-52:
  4 | operation Send : unit ~> unit # {Send} within (1, 2)
                                                    ^^^^^^
  Syntax error: in the 'traces-cost-upper-bound' grading monoid, the interval '(1, 2)' contains no whole number of time steps
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
  File "mode_switch_costs_reject.tpe", line 9, characters 14-52:
  9 | let tx_off () : unit # (Off, Off, 2) = perform Tx ()
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(On, On, 2)`, which does not match its annotated grade `(Off, Off, 2)`
    Note: the effect inequality `(On, On, 2) <= (Off, Off, 2)` does not hold
  
  File "mode_switch_costs_reject.tpe", lines 12-16, characters 11-16:
  12 | let two () : unit # (Off, Off, 4) =
                  ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Off, Off, 6)`, which does not match its annotated grade `(Off, Off, 4)`
    Note: the effect inequality `(Off, Off, 6) <= (Off, Off, 4)` does not hold
  
  File "mode_switch_costs_reject.tpe", lines 19-20, characters 17-46:
  19 | let idle_or_tx b : unit # ((On, On, 2), (Off, Off, 1)) =
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `((On, On, 2), (_, _, 1), (_, Stuck, 0))`, which does not match its annotated grade `((Off, Off, 1), (On, On, 2))`
    Note: the effect inequality `((On, On, 2), (_, _, 1), (_, Stuck, 0)) <= ((Off, Off, 1), (On, On, 2))` does not hold
  
  File "mode_switch_costs_reject.tpe", line 28, characters 15-33:
  28 |   | Tx () k -> continue k with ()
                      ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `0` accumulated since it was bound, which is not below its box grade `(On, On, 2)`
    File "mode_switch_costs_reject.tpe", line 28, characters 10-11:
    28 |   | Tx () k -> continue k with ()
                   ^
    `k` is bound here
    Note: the resource inequality `0 <= (On, On, 2)` does not hold
  
  File "mode_switch_costs_reject.tpe", line 31, characters 0-18:
  31 | default On () = ()
       ^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `On` has grade `0`, which does not match the declared grade `(Off, On, 1)` of `On`
    File "mode_switch_costs_reject.tpe", line 3, characters 0-42:
    3 | operation On : unit ~> unit # (Off, On, 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `On` is declared here
    Note: the effect inequality `0 <= (Off, On, 1)` does not hold
  ======================================================================
  nat.tpe
  ======================================================================
  === Run 1 ===
  return 42
  State: []
  
  ======================================================================
  nat_division_by_zero.tpe
  ======================================================================
  Runtime error: Division by zero
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
  nat_reject_negative.tpe
  ======================================================================
  File "nat_reject_negative.tpe", line 3, characters 4-18:
  3 | run -1_000_000_000
          ^^^^^^^^^^^^^^
  Syntax error: Natural numbers have no negation
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
  File "noneternal_reject_after_delay.tpe", line 13, characters 2-3:
  13 |   t
         ^
  Typing error: Variable `t` is used with grade `1` accumulated since it was bound, but its type `token` is not eternal
    File "noneternal_reject_after_delay.tpe", line 11, characters 6-7:
    11 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_after_delay.tpe", line 12, characters 2-9:
    12 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `1 <= 0` does not hold
  ======================================================================
  noneternal_reject_alias.tpe
  ======================================================================
  File "noneternal_reject_alias.tpe", line 5, characters 0-29:
  5 | noneternal type seconds = nat
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: type `seconds` is an alias and cannot be declared noneternal; wrap it in a constructor, as in `noneternal type seconds = Seconds of ...`
  ======================================================================
  noneternal_reject_unknown_grade.tpe
  ======================================================================
  File "noneternal_reject_unknown_grade.tpe", line 21, characters 2-3:
  21 |   t
         ^
  Typing error: Variable `t` is used with grade `1` accumulated since it was bound, but its type `token` is not eternal
    File "noneternal_reject_unknown_grade.tpe", line 18, characters 6-7:
    18 |   let t = Token in
               ^
    `t` is bound here
    File "noneternal_reject_unknown_grade.tpe", line 20, characters 2-9:
    20 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `1 <= 0` does not hold
  
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
    File "noneternal_reject_unknown_grade.tpe", line 29, characters 2-9:
    29 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    File "noneternal_reject_unknown_grade.tpe", line 30, characters 2-3:
    30 |   y
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
  op_case_context_continuation.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ fun op_var ↦ handle
                                  return op_var;
                                  return 7
                                with h # 0,
      resource_3 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_1 as unbox_var in
            unbox_var ()
          with handler
               | return y ↦ return y
               | Op2 (q, k') ↦
                       let a = (unbox k' as unbox_var in
                                unbox_var ()) in
                       unbox resource_1 as unbox_var in
                       unbox_var ()
        # 0
    }
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
  plain_rational_traces_upper.tpe
  ======================================================================
  ======================================================================
  plain_traces_upper.tpe
  ======================================================================
  ======================================================================
  plain_traces_upper_reject.tpe
  ======================================================================
  File "plain_traces_upper_reject.tpe", lines 15-16, characters 2-3:
  15 |   unbox r as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `{Heat}` accumulated since it was bound, which is not below its box grade `{1}`
    File "plain_traces_upper_reject.tpe", line 13, characters 14-15:
    13 |   box 1 42 as r in
                       ^
    `r` is bound here
    File "plain_traces_upper_reject.tpe", line 14, characters 2-17:
    14 |   perform Heat ();
           ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Heat} <= {1}` does not hold
  
  File "plain_traces_upper_reject.tpe", lines 18-19, characters 32-67:
  18 | let read_or_send (fresh : bool) : unit # {Read} =
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
    { resource_2 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_0 as y in
            return y
          with h
        # [0.5, 0.75]
    },
    [0.625, 0.625]
  ]
  
  ======================================================================
  rational_time_intervals_reject.tpe
  ======================================================================
  File "rational_time_intervals_reject.tpe", lines 13-14, characters 2-3:
  13 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `[1, 1.5]` accumulated since it was bound, which is not below its box grade `[0.5, 1.25]`
    File "rational_time_intervals_reject.tpe", line 10, characters 27-28:
    10 |   box [0.5, 1.25] "tea" as r in
                                    ^
    `r` is bound here
    File "rational_time_intervals_reject.tpe", line 11, characters 2-17:
    11 |   perform Pour ();
           ^^^^^^^^^^^^^^^
    grade `[0.5, 0.75]` accumulates here (operation `Pour`)
    File "rational_time_intervals_reject.tpe", line 12, characters 2-17:
    12 |   perform Pour ();
           ^^^^^^^^^^^^^^^
    grade `[0.5, 0.75]` accumulates here (operation `Pour`)
    Note: the resource inequality `[1, 1.5] <= [0.5, 1.25]` does not hold
  ======================================================================
  rational_time_intervals_reject_within.tpe
  ======================================================================
  File "rational_time_intervals_reject_within.tpe", line 5, characters 0-60:
  5 | operation Dose : unit ~> unit # [0.5, 1.5] within [1/2, 3/2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `time-interval-rational` grading monoid
  ======================================================================
  rational_time_lower.tpe
  ======================================================================
  === Run 1 ===
  return "ripe"
  State: [
    { resource_0 ↦ "ripe" # 2.25 },
    0.5,
    1.25,
    { resource_2 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_0 as y in
            return y
          with h
        # 0.5
    },
    0.5
  ]
  
  ======================================================================
  rational_time_lower_reject.tpe
  ======================================================================
  File "rational_time_lower_reject.tpe", line 10, characters 27-48:
  10 | let h = handler | x -> x | Op () k -> delay 5; 0
                                  ^^^^^^^^^^^^^^^^^^^^^
  Typing error: For every grade `ε_Op` the continuation `k` may have, the case for `Op` must have a grade matching `1 · ε_Op`, but its grade `5` does not
    File "rational_time_lower_reject.tpe", line 5, characters 0-31:
    5 | operation Op : unit ~> unit # 1
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "rational_time_lower_reject.tpe", line 10, characters 33-34:
    10 | let h = handler | x -> x | Op () k -> delay 5; 0
                                          ^
    `k` may have any grade `ε_Op`
    Note: the effect inequality `∀ε_Op. 5 >= 1 · ε_Op` does not hold: for `ε_Op = 4.5` it becomes `5 >= 5.5`
  
  File "rational_time_lower_reject.tpe", lines 19-20, characters 2-3:
  19 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `1` accumulated since it was bound, which is not below its box grade `1.5`
    File "rational_time_lower_reject.tpe", line 15, characters 22-23:
    15 |   box 1.5 "unripe" as r in
                               ^
    `r` is bound here
    File "rational_time_lower_reject.tpe", line 16, characters 2-11:
    16 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_lower_reject.tpe", line 17, characters 2-11:
    17 |   delay 1/3;
           ^^^^^^^^^
    grade `1/3` accumulates here (delay)
    File "rational_time_lower_reject.tpe", line 18, characters 2-11:
    18 |   delay 1/3;
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
    { resource_2 ↦
        fun op_var ↦
          handle
            return op_var;
            unbox resource_0 as y in
            return y
          with h
        # 0.125
    },
    0.0625
  ]
  
  ======================================================================
  rational_time_upper_reject.tpe
  ======================================================================
  File "rational_time_upper_reject.tpe", lines 13-14, characters 2-3:
  13 |   unbox r as y in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `4/3` accumulated since it was bound, which is not below its box grade `1`
    File "rational_time_upper_reject.tpe", line 8, characters 19-20:
    8 |   box 1 "fresh" as r in
                           ^
    `r` is bound here
    File "rational_time_upper_reject.tpe", line 9, characters 2-11:
    9 |   delay 1/3;
          ^^^^^^^^^
    grade `1/3` accumulates here (delay)
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
  File "rational_traces_intervals_default_open_reject.tpe", line 10, characters 0-25:
  10 | default Send () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` takes a duration in `[2, 2]`, which is not within the running-time bounds `[1, 2)` of `Send`
    File "rational_traces_intervals_default_open_reject.tpe", line 7, characters 0-62:
    7 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 2)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
  
  File "rational_traces_intervals_default_open_reject.tpe", line 11, characters 0-25:
  11 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` takes a duration in `[1, 1]`, which is not within the running-time bounds `(1, 2]` of `Beep`
    File "rational_traces_intervals_default_open_reject.tpe", line 8, characters 0-62:
    8 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
  ======================================================================
  rational_traces_intervals_reject.tpe
  ======================================================================
  File "rational_traces_intervals_reject.tpe", lines 13-14, characters 2-3:
  13 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `[{Sample; 0.125}, {Sample; 0.125}]` accumulated since it was bound, which is not below its box grade `[{0.75}, {2}]`
    File "rational_traces_intervals_reject.tpe", line 10, characters 21-24:
    10 |   box [3/4, 2] () as due in
                              ^^^
    `due` is bound here
    File "rational_traces_intervals_reject.tpe", line 11, characters 10-27:
    11 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    File "rational_traces_intervals_reject.tpe", line 12, characters 2-11:
    12 |   delay 1/8;
           ^^^^^^^^^
    grade `[{0.125}, {0.125}]` accumulates here (delay)
    Note: the resource inequality `[{Sample; 0.125}, {Sample; 0.125}] <= [{0.75}, {2}]` does not hold
  ======================================================================
  rational_traces_intervals_reject_open.tpe
  ======================================================================
  File "rational_traces_intervals_reject_open.tpe", line 5, characters 19-27:
  5 | let claim () = box (1/2, 2] 1
                         ^^^^^^^^
  Syntax error: in the 'traces-cost-interval-rational' grading monoid, an open endpoint denotes an infinite set of traces, which these grades do not express; did you mean to use one of the 'time-interval-rational' or 'regex-cost-interval-rational-symbolic' grading monoids?
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
  File "rational_traces_upper_open_reject.tpe", lines 11-12, characters 2-3:
  11 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Sample}` accumulated since it was bound, which is not below its box grade `{1.4}`
    File "rational_traces_upper_open_reject.tpe", line 9, characters 17-21:
    9 |   box {1.4} 1 as slot in
                         ^^^^
    `slot` is bound here
    File "rational_traces_upper_open_reject.tpe", line 10, characters 2-19:
    10 |   perform Sample ();
           ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    Note: the resource inequality `{Sample} <= {1.4}` does not hold
  ======================================================================
  rational_traces_upper_reject.tpe
  ======================================================================
  File "rational_traces_upper_reject.tpe", lines 13-14, characters 2-3:
  13 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `{Sample; 0.5}` accumulated since it was bound, which is not below its box grade `{1.75}`
    File "rational_traces_upper_reject.tpe", line 10, characters 18-21:
    10 |   box {7/4} () as due in
                           ^^^
    `due` is bound here
    File "rational_traces_upper_reject.tpe", line 11, characters 10-27:
    11 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "rational_traces_upper_reject.tpe", line 12, characters 2-11:
    12 |   delay 1/2;
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
  recursion.tpe
  ======================================================================
  === Run 1 ===
  return (3628800, 55, 120)
  State: []
  
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
  File "recursion_effect_reject_invariant.tpe", lines 7-12, characters 15-12:
  7 | let rec wait n : unit # 5 =
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
  File "recursion_effect_reject_unannotated.tpe", lines 7-12, characters 13-12:
  7 | let rec wait n =
                   ^^^
  Typing error: The effect inequality `1 <= 0` does not hold
  ======================================================================
  recursion_effect_reject_unannotated_regular.tpe
  ======================================================================
  File "recursion_effect_reject_unannotated_regular.tpe", lines 15-20, characters 20-19:
  15 | let rec unannotated (n : nat) =
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Pause (_, k) ↦
                         delay 1 (return ());
                         let y = (rec pause_nested ...) 1 in
                         let b = (let b = (+) y in
                                  b 1) in
                         unbox k as unbox_var in
                         unbox_var b
        # ∞
    },
    1,
    { resource_3 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Pause (_, k) ↦
                         delay 1 (return ());
                         let y = (rec pause_nested ...) 0 in
                         let b = (let b = (+) y in
                                  b 1) in
                         unbox k as unbox_var in
                         unbox_var b
        # ∞
    },
    1
  ]
  
  ======================================================================
  recursion_lock.tpe
  ======================================================================
  === Run 1 ===
  return (12, 2, 3)
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Ask (_, k) ↦
                       let b =
                         (let b = (let b = (rec count ...) 1 in
                                   (+) b) in
                          b 1) in
                       unbox k as unbox_var in
                       unbox_var b
        # 0,
      resource_3 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Ask (_, k) ↦
                       let b =
                         (let b = (let b = (rec count ...) 0 in
                                   (+) b) in
                          b 1) in
                       unbox k as unbox_var in
                       unbox_var b
        # 0,
      resource_5 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Ask (_, k) ↦
                       let b = (let b = (let b = (rec go ...) 2 in
                                         (+) b) in
                                b 1) in
                       unbox k as unbox_var in
                       unbox_var b
        # 0,
      resource_7 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Ask (_, k) ↦
                       let b = (let b = (let b = (rec go ...) 1 in
                                         (+) b) in
                                b 1) in
                       unbox k as unbox_var in
                       unbox_var b
        # 0,
      resource_9 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Ask (_, k) ↦
                       let b = (let b = (let b = (rec go ...) 0 in
                                         (+) b) in
                                b 1) in
                       unbox k as unbox_var in
                       unbox_var b
        # 0
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
  regex_costs_interval.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_costs_interval_reject.tpe
  ======================================================================
  File "regex_costs_interval_reject.tpe", lines 13-14, characters 2-5:
  13 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_costs_interval_reject.tpe", line 11, characters 28-29:
    11 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 12, characters 2-18:
    12 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_costs_interval_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_costs_interval_reject.tpe", line 18, characters 28-29:
    18 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 19, characters 2-18:
    19 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_costs_interval_runs_reject.tpe
  ======================================================================
  File "regex_costs_interval_runs_reject.tpe", line 12, characters 6-34:
  12 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_costs_interval_runs_reject.tpe", line 19, characters 33-61:
  19 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_costs_lower.tpe
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
  regex_costs_lower_reject.tpe
  ======================================================================
  File "regex_costs_lower_reject.tpe", lines 15-16, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_costs_lower_reject.tpe", line 12, characters 31-32:
    12 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_costs_lower_reject.tpe", line 13, characters 2-17:
    13 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_costs_lower_reject.tpe", line 14, characters 2-9:
    14 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 22-23, characters 2-5:
  22 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_costs_lower_reject.tpe", line 20, characters 29-30:
    20 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_costs_lower_reject.tpe", line 21, characters 2-10:
    21 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 29-30, characters 2-5:
  29 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_lower_reject.tpe", line 27, characters 25-26:
    27 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_costs_lower_reject.tpe", line 28, characters 2-58:
    28 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_costs_lower_runs_reject.tpe
  ======================================================================
  File "regex_costs_lower_runs_reject.tpe", line 11, characters 6-30:
  11 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_costs_rational_interval.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{0.5}, {1.5}] },
    [{0.5}, {0.5}]
  ]
  
  ======================================================================
  regex_costs_rational_interval_default_open_reject.tpe
  ======================================================================
  File "regex_costs_rational_interval_default_open_reject.tpe", line 9, characters 0-25:
  9 | default Send () = delay 2
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` has grade `[{2}, {2}]`, which does not match the declared grade `[{1}, {[0, 2)}]` of `Send`
    File "regex_costs_rational_interval_default_open_reject.tpe", line 6, characters 0-62:
    6 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 2)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
    Note: the effect inequality `[{2}, {2}] <= [{1}, {[0, 2)}]` does not hold
  
  File "regex_costs_rational_interval_default_open_reject.tpe", line 10, characters 0-25:
  10 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_costs_rational_interval_default_open_reject.tpe", line 7, characters 0-62:
    7 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_costs_rational_interval_open_reject.tpe
  ======================================================================
  File "regex_costs_rational_interval_open_reject.tpe", line 7, characters 0-25:
  7 | default Beep () = delay 1
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{(1, ∞)}, {2}]` of `Beep`
    File "regex_costs_rational_interval_open_reject.tpe", line 5, characters 0-62:
    5 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 2]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{(1, ∞)}, {2}]` does not hold
  ======================================================================
  regex_costs_rational_interval_reject.tpe
  ======================================================================
  File "regex_costs_rational_interval_reject.tpe", lines 13-14, characters 2-5:
  13 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Sample}, {Sample}]` accumulated since it was bound, which is not below its box grade `[{0.75}, {2}]`
    File "regex_costs_rational_interval_reject.tpe", line 11, characters 30-31:
    11 |   box [3/4, 2] (Token "t") as t in
                                       ^
    `t` is bound here
    File "regex_costs_rational_interval_reject.tpe", line 12, characters 10-27:
    12 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{Sample}, {Sample}] <= [{0.75}, {2}]` does not hold
  
  File "regex_costs_rational_interval_reject.tpe", lines 22-23, characters 2-5:
  22 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{0.5; Sample}, {0.5; Sample}]` accumulated since it was bound, which is not below its box grade `[{0.5}, {[0, 1)}]`
    File "regex_costs_rational_interval_reject.tpe", line 19, characters 39-40:
    19 |   box [{1/2}, {[0, 1)}] (Token "t") as t in
                                                ^
    `t` is bound here
    File "regex_costs_rational_interval_reject.tpe", line 20, characters 2-11:
    20 |   delay 1/2;
           ^^^^^^^^^
    grade `[{0.5}, {0.5}]` accumulates here (delay)
    File "regex_costs_rational_interval_reject.tpe", line 21, characters 10-27:
    21 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `[{Sample}, {Sample}]` accumulates here (operation `Sample`)
    Note: the resource inequality `[{0.5; Sample}, {0.5; Sample}] <= [{0.5}, {[0, 1)}]` does not hold
  ======================================================================
  regex_costs_rational_lower.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25}
  ]
  
  ======================================================================
  regex_costs_rational_lower_reject.tpe
  ======================================================================
  File "regex_costs_rational_lower_reject.tpe", lines 14-15, characters 2-5:
  14 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{0.25}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_costs_rational_lower_reject.tpe", line 12, characters 27-28:
    12 |   box {1/2} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_costs_rational_lower_reject.tpe", line 13, characters 2-11:
    13 |   delay 1/4;
           ^^^^^^^^^
    grade `{0.25}` accumulates here (delay)
    Note: the resource inequality `{0.25} <= {0.5}` does not hold
  
  File "regex_costs_rational_lower_reject.tpe", lines 21-22, characters 2-5:
  21 |   unbox s as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `s` is unboxed with grade `{3}` accumulated since it was bound, which is not below its box grade `{Send}`
    File "regex_costs_rational_lower_reject.tpe", line 19, characters 28-29:
    19 |   box {Send} (Token "s") as s in
                                     ^
    `s` is bound here
    File "regex_costs_rational_lower_reject.tpe", line 20, characters 2-9:
    20 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{3} <= {Send}` does not hold
  
  File "regex_costs_rational_lower_reject.tpe", lines 31-32, characters 2-5:
  31 |   unbox p as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `p` is unboxed with grade `{(0, 1)}` accumulated since it was bound, which is not below its box grade `{0.5}`
    File "regex_costs_rational_lower_reject.tpe", line 29, characters 27-28:
    29 |   box {1/2} (Token "p") as p in
                                    ^
    `p` is bound here
    File "regex_costs_rational_lower_reject.tpe", line 30, characters 2-15:
    30 |   some_pause ();
           ^^^^^^^^^^^^^
    grade `{(0, 1)}` accumulates here (this computation)
    Note: the resource inequality `{(0, 1)} <= {0.5}` does not hold
    Note: the grade `{1/3}` is below `{(0, 1)}` but not below `{0.5}`
  
  File "regex_costs_rational_lower_reject.tpe", line 35, characters 13-44:
  35 | let quick () : nat # {1} = perform Sample ()
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample}`, which does not match its annotated grade `{1}`
    Note: the effect inequality `{Sample} <= {1}` does not hold
  ======================================================================
  regex_costs_rational_upper.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {0.5},
    {0.25},
    {0.25}
  ]
  
  ======================================================================
  regex_costs_rational_upper_open.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # {[0, 2)} },
    {1.9}
  ]
  
  ======================================================================
  regex_costs_rational_upper_open_reject.tpe
  ======================================================================
  File "regex_costs_rational_upper_open_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Sample}` accumulated since it was bound, which is not below its box grade `{[0, 2)}`
    File "regex_costs_rational_upper_open_reject.tpe", line 10, characters 20-24:
    10 |   box {[0, 2)} 1 as slot in
                             ^^^^
    `slot` is bound here
    File "regex_costs_rational_upper_open_reject.tpe", line 11, characters 2-19:
    11 |   perform Sample ();
           ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    Note: the resource inequality `{Sample} <= {[0, 2)}` does not hold
  
  File "regex_costs_rational_upper_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 2
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{2}`, which does not match the declared grade `{[0, 2)}` of `Beep`
    File "regex_costs_rational_upper_open_reject.tpe", line 7, characters 0-54:
    7 | operation Beep : unit ~> unit # {Beep} within [1/2, 2)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{2} <= {[0, 2)}` does not hold
  ======================================================================
  regex_costs_rational_upper_reject.tpe
  ======================================================================
  File "regex_costs_rational_upper_reject.tpe", lines 16-17, characters 2-5:
  16 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; 1/3}` accumulated since it was bound, which is not below its box grade `{1.75}`
    File "regex_costs_rational_upper_reject.tpe", line 13, characters 27-28:
    13 |   box {7/4} (Token "t") as t in
                                    ^
    `t` is bound here
    File "regex_costs_rational_upper_reject.tpe", line 14, characters 10-27:
    14 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_costs_rational_upper_reject.tpe", line 15, characters 2-11:
    15 |   delay 1/3;
           ^^^^^^^^^
    grade `{1/3}` accumulates here (delay)
    Note: the resource inequality `{Sample; 1/3} <= {1.75}` does not hold
  
  File "regex_costs_rational_upper_reject.tpe", lines 25-26, characters 2-5:
  25 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Sample; Send}` accumulated since it was bound, which is not below its box grade `{Send; 2}`
    File "regex_costs_rational_upper_reject.tpe", line 22, characters 31-32:
    22 |   box {Send; 2} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_costs_rational_upper_reject.tpe", line 23, characters 10-27:
    23 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_costs_rational_upper_reject.tpe", line 24, characters 2-16:
    24 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; Send} <= {Send; 2}` does not hold
  
  File "regex_costs_rational_upper_reject.tpe", lines 37-38, characters 2-5:
  37 |   unbox b as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `b` is unboxed with grade `{[0, 0.5); Send; [0, 0.5)}` accumulated since it was bound, which is not below its box grade `{1.99}`
    File "regex_costs_rational_upper_reject.tpe", line 33, characters 28-29:
    33 |   box {1.99} (Token "b") as b in
                                     ^
    `b` is bound here
    File "regex_costs_rational_upper_reject.tpe", line 34, characters 2-16:
    34 |   short_pause ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    File "regex_costs_rational_upper_reject.tpe", line 35, characters 2-16:
    35 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_costs_rational_upper_reject.tpe", line 36, characters 2-16:
    36 |   short_pause ();
           ^^^^^^^^^^^^^^
    grade `{[0, 0.5)}` accumulates here (this computation)
    Note: the resource inequality `{[0, 0.5); Send; [0, 0.5)} <= {1.99}` does not hold
    Note: the grade `{64/129; Send; 64/129}` is below `{[0, 0.5); Send; [0, 0.5)}` but not below `{1.99}`
  
  File "regex_costs_rational_upper_reject.tpe", lines 46-47, characters 2-5:
  46 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Send; 1}` accumulated since it was bound, which is not below its box grade `{Send; ([0, 1] & ~1)}`
    File "regex_costs_rational_upper_reject.tpe", line 43, characters 43-44:
    43 |   box {Send; ([0, 1] & ~1)} (Token "l") as l in
                                                    ^
    `l` is bound here
    File "regex_costs_rational_upper_reject.tpe", line 44, characters 2-16:
    44 |   perform Send n;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    File "regex_costs_rational_upper_reject.tpe", line 45, characters 2-9:
    45 |   delay 1;
           ^^^^^^^
    grade `{1}` accumulates here (delay)
    Note: the resource inequality `{Send; 1} <= {Send; ([0, 1] & ~1)}` does not hold
  
  File "regex_costs_rational_upper_reject.tpe", lines 51-53, characters 19-19:
  51 | let two_samples () : nat # {5/2} =
                          ^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Sample; Sample}`, which does not match its annotated grade `{2.5}`
    Note: the effect inequality `{Sample; Sample} <= {2.5}` does not hold
  ======================================================================
  regex_costs_upper.tpe
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_costs_upper_open.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_costs_upper_open_reject.tpe
  ======================================================================
  File "regex_costs_upper_open_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_costs_upper_open_reject.tpe", line 10, characters 15-19:
    10 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_costs_upper_open_reject.tpe", line 11, characters 2-15:
    11 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_costs_upper_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_costs_upper_open_reject.tpe", line 7, characters 0-52:
    7 | operation Beep : unit ~> unit # {Beep} within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_costs_upper_reject.tpe
  ======================================================================
  File "regex_costs_upper_reject.tpe", lines 14-15, characters 2-5:
  14 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_upper_reject.tpe", line 12, characters 25-26:
    12 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_costs_upper_reject.tpe", line 13, characters 2-18:
    13 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 23-24, characters 2-5:
  23 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_costs_upper_reject.tpe", line 20, characters 30-31:
    20 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_costs_upper_reject.tpe", line 21, characters 2-18:
    21 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_costs_upper_reject.tpe", line 22, characters 2-16:
    22 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_costs_upper_reject.tpe", line 28, characters 37-38:
    28 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_costs_upper_reject.tpe", line 29, characters 2-49:
    29 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_costs_upper_reject.tpe", lines 34-36, characters 17-17:
  34 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_costs_upper_runs.tpe
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_costs_upper_runs_reject.tpe
  ======================================================================
  File "regex_costs_upper_runs_reject.tpe", line 12, characters 6-23:
  12 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 17, characters 26-43:
  17 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 20, characters 27-44:
  20 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  ======================================================================
  regex_rational.tpe
  ======================================================================
  ======================================================================
  regex_rational_reject.tpe
  ======================================================================
  File "regex_rational_reject.tpe", lines 14-15, characters 2-3:
  14 |   unbox t as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{1}` accumulated since it was bound, which is not below its box grade `{~1}`
    File "regex_rational_reject.tpe", line 11, characters 16-17:
    11 |   box {~1} 7 as t in
                         ^
    `t` is bound here
    File "regex_rational_reject.tpe", line 12, characters 2-11:
    12 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 13, characters 2-11:
    13 |   delay 0.5;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    Note: the resource inequality `{1} <= {~1}` does not hold
  
  File "regex_rational_reject.tpe", lines 23-24, characters 2-3:
  23 |   unbox due as u in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `due` is unboxed with grade `{Sample; 1; Send}` accumulated since it was bound, which is not below its box grade `{Sample; [0, 1); Send}`
    File "regex_rational_reject.tpe", line 18, characters 35-38:
    18 |   box {Sample; [0, 1); Send} () as due in
                                            ^^^
    `due` is bound here
    File "regex_rational_reject.tpe", line 19, characters 10-27:
    19 |   let v = perform Sample () in
                   ^^^^^^^^^^^^^^^^^
    grade `{Sample}` accumulates here (operation `Sample`)
    File "regex_rational_reject.tpe", line 20, characters 2-11:
    20 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 21, characters 2-11:
    21 |   delay 1/2;
           ^^^^^^^^^
    grade `{0.5}` accumulates here (delay)
    File "regex_rational_reject.tpe", line 22, characters 2-16:
    22 |   perform Send v;
           ^^^^^^^^^^^^^^
    grade `{Send}` accumulates here (operation `Send`)
    Note: the resource inequality `{Sample; 1; Send} <= {Sample; [0, 1); Send}` does not hold
  
  File "regex_rational_reject.tpe", line 26, characters 14-43:
  26 | let thirds () : unit # {(1/2)*} = delay 1/3
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{1/3}`, which does not match its annotated grade `{(0.5)*}`
    Note: the effect inequality `{1/3} <= {(0.5)*}` does not hold
  
  File "regex_rational_reject.tpe", lines 31-32, characters 2-3:
  31 |   unbox w as u in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `w` is unboxed with grade `{2 | 0.5}` accumulated since it was bound, which is not below its box grade `{[1, ∞)}`
    File "regex_rational_reject.tpe", line 29, characters 23-24:
    29 |   box {[1, ∞)} () as w in
                                ^
    `w` is bound here
    File "regex_rational_reject.tpe", line 30, characters 2-34:
    30 |   if b then delay 1/2 else delay 2;
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{2 | 0.5}` accumulates here (this computation)
    Note: the resource inequality `{2 | 0.5} <= {[1, ∞)}` does not hold
    Note: the grade `{0.5}` is below `{2 | 0.5}` but not below `{[1, ∞)}`
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
  File "regular_reject_auth.tpe", lines 15-17, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 13, characters 36-37:
    13 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 14, characters 2-18:
    14 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 22-23, characters 2-5:
  22 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 20, characters 41-42:
    20 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 21, characters 2-19:
    21 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 29-30, characters 2-3:
  29 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 26, characters 20-21:
    26 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 27, characters 2-18:
    27 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 28, characters 2-9:
    28 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe
  ======================================================================
  File "regular_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `regex-upper-bound-symbolic` grading monoid
  ======================================================================
  regular_reject_counterexample.tpe
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 13-18, characters 23-3:
  13 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 24-25, characters 2-5:
  24 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 22, characters 23-24:
    22 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 23, characters 2-49:
    23 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe
  ======================================================================
  File "regular_reject_protocol.tpe", line 16, characters 6-23:
  16 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 12, characters 15-16:
    12 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 13, characters 6-21:
    13 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 14, characters 6-22:
    14 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 15, characters 14-29:
    15 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 18-19, characters 16-34:
  18 | let unclosed () : nat # {Open; Read*; Close} =
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
    { resource_1 ↦
        fun op_var ↦
          handle
            let a = return op_var in
            let b = perform Reserve "b" (op_var. return op_var) in
            return (a, b)
          with handler
               | return x ↦ return x
               | Reserve (name, k) ↦
                           unbox k as unbox_var in
                           unbox_var (File name)
        # ([0, 1], 1),
      resource_3 ↦
        fun op_var ↦
          handle
            let b = return op_var in
            return (File "a", b)
          with handler
               | return x ↦ return x
               | Reserve (name, k) ↦
                           unbox k as unbox_var in
                           unbox_var (File name)
        # ([0, 1], 1)
    }
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
  File "resource_levels_by_resource_reject.tpe", lines 11-15, characters 14-19:
  11 | let relock () : unit # ((Files, 0, 2), (Locks, 0, 1)) =
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Locks, 0, 2)`, which does not match its annotated grade `((Files, 0, 2), (Locks, 0, 1))`
    Note: the effect inequality `(Locks, 0, 2) <= ((Files, 0, 2), (Locks, 0, 1))` does not hold
  
  File "resource_levels_by_resource_reject.tpe", lines 18-24, characters 19-17:
  18 | let three_files () : unit # (0, 2) =
                          ^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(Files, 0, 3)`, which does not match its annotated grade `(0, 2)`
    Note: the effect inequality `(Files, 0, 3) <= (0, 2)` does not hold
  
  File "resource_levels_by_resource_reject.tpe", lines 31-32, characters 2-3:
  31 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(Locks, 1, 1)` accumulated since it was bound, which is not below its box grade `(Files, 0, 1)`
    File "resource_levels_by_resource_reject.tpe", line 29, characters 25-26:
    29 |   box (Files, 0, 1) 7 as x in
                                  ^
    `x` is bound here
    File "resource_levels_by_resource_reject.tpe", line 30, characters 2-17:
    30 |   perform Lock ();
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
  File "resource_levels_reject.tpe", lines 9-15, characters 13-17:
  9 | let three () : unit # (0, 2) =
                   ^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(0, 3)`, which does not match its annotated grade `(0, 2)`
    Note: the effect inequality `(0, 3) <= (0, 2)` does not hold
  
  File "resource_levels_reject.tpe", lines 22-23, characters 2-3:
  22 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(0, 1)` accumulated since it was bound, which is not below its box grade `(0, 0)`
    File "resource_levels_reject.tpe", line 19, characters 18-19:
    19 |   box (0, 0) 7 as x in
                           ^
    `x` is bound here
    File "resource_levels_reject.tpe", line 20, characters 10-26:
    20 |   let f = perform Open "f" in
                   ^^^^^^^^^^^^^^^^
    grade `(1, 1)` accumulates here (operation `Open`)
    File "resource_levels_reject.tpe", line 21, characters 2-17:
    21 |   perform Close f;
           ^^^^^^^^^^^^^^^
    grade `(-1, 0)` accumulates here (operation `Close`)
    Note: the resource inequality `(0, 1) <= (0, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 27, characters 0-20:
  27 | default Close f = ()
       ^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Close` has grade `(0, 0)`, which does not match the declared grade `(-1, 0)` of `Close`
    File "resource_levels_reject.tpe", line 6, characters 0-40:
    6 | operation Close : file ~> unit # (-1, 0)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Close` is declared here
    Note: the effect inequality `(0, 0) <= (-1, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 34, characters 17-35:
  34 |   | Close f k -> continue k with ()
                        ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `(0, 0)` accumulated since it was bound, which is not below its box grade `(-1, 0)`
    File "resource_levels_reject.tpe", line 34, characters 12-13:
    34 |   | Close f k -> continue k with ()
                     ^
    `k` is bound here
    Note: the resource inequality `(0, 0) <= (-1, 0)` does not hold
  
  File "resource_levels_reject.tpe", line 38, characters 0-29:
  38 | default Open name = File name
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Open` has grade `(0, 0)`, which does not match the declared grade `(1, 1)` of `Open`
    File "resource_levels_reject.tpe", line 5, characters 0-40:
    5 | operation Open : string ~> file # (1, 1)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Open` is declared here
    Note: the effect inequality `(0, 0) <= (1, 1)` does not hold
  
  File "resource_levels_reject.tpe", line 45, characters 19-44:
  45 |   | Open name k -> continue k with File name
                          ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with the unit grade `(0, 0)` accumulated since it was bound, which is not below its box grade `(1, 1)`
    File "resource_levels_reject.tpe", line 45, characters 14-15:
    45 |   | Open name k -> continue k with File name
                       ^
    `k` is bound here
    Note: the resource inequality `(0, 0) <= (1, 1)` does not hold
  
  File "resource_levels_reject.tpe", lines 49-52, characters 18-3:
  49 | let rotate_late f : file # (-1, 0, 0) =
                         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(0, 1)`, which does not match its annotated grade `(-1, 0, 0)`
    Note: the effect inequality `(0, 1) <= (-1, 0, 0)` does not hold
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
  return id
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
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 3 ===
  return 4
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 4 ===
  return 8
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 5 ===
  return 15
  State: [
    { resource_0 ↦ 7 # [2, 5], resource_1 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  ======================================================================
  time_reject_within.tpe
  ======================================================================
  File "time_reject_within.tpe", line 6, characters 0-47:
  6 | operation Heat : unit ~> unit # 2 within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `time-lower-bound` grading monoid
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
    [{1}, {1}],
    { resource_0 ↦ Epoxy # [{8}, {11}],
      resource_2 ↦
        fun op_var ↦
          handle
            let printed = return op_var in
            delay 2 (return ());
            unbox printed as p in
            unbox resource_0 as g in
            perform Mount (p, g) (op_var. return op_var)
          with printer
        # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]
    },
    [{1}, {1}],
    [{3}, {3}],
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{2}, {2}],
    [{1}, {1}]
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
  Typing error: The default implementation of `Extrude` has grade `[{1}, {1}]`, which does not match the declared grade `[{3}, {5}]` of `Extrude`
    File "traces_intervals_default_bounds.tpe", line 7, characters 0-71:
    7 | operation Extrude : unit ~> unit # [{Extrude}, {Extrude}] within [3, 5]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{3}, {5}]` does not hold
  ======================================================================
  traces_intervals_default_open_reject.tpe
  ======================================================================
  File "traces_intervals_default_open_reject.tpe", line 9, characters 0-25:
  9 | default Send () = delay 3
      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Send` has grade `[{3}, {3}]`, which does not match the declared grade `[{1}, {2}]` of `Send`
    File "traces_intervals_default_open_reject.tpe", line 6, characters 0-62:
    6 | operation Send : unit ~> unit # [{Send}, {Send}] within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Send` is declared here
    Note: the effect inequality `[{3}, {3}] <= [{1}, {2}]` does not hold
  
  File "traces_intervals_default_open_reject.tpe", line 10, characters 0-25:
  10 | default Beep () = delay 1
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `[{1}, {1}]`, which does not match the declared grade `[{2}, {3}]` of `Beep`
    File "traces_intervals_default_open_reject.tpe", line 7, characters 0-62:
    7 | operation Beep : unit ~> unit # [{Beep}, {Beep}] within (1, 3]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `[{1}, {1}] <= [{2}, {3}]` does not hold
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
  File "traces_open_bounds_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "traces_open_bounds_reject.tpe", line 10, characters 15-19:
    10 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "traces_open_bounds_reject.tpe", line 11, characters 2-15:
    11 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "traces_open_bounds_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "traces_open_bounds_reject.tpe", line 7, characters 0-52:
    7 | operation Beep : unit ~> unit # {Beep} within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  traces_reject_allowance.tpe
  ======================================================================
  File "traces_reject_allowance.tpe", lines 10-11, characters 2-3:
  10 |   unbox r as x in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `r` is unboxed with grade `{Heat}` accumulated since it was bound, which is not below its box grade `{1}`
    File "traces_reject_allowance.tpe", line 8, characters 14-15:
    8 |   box 1 42 as r in
                      ^
    `r` is bound here
    File "traces_reject_allowance.tpe", line 9, characters 2-17:
    9 |   perform Heat ();
          ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Heat} <= {1}` does not hold
  ======================================================================
  traces_reject_bounds.tpe
  ======================================================================
  File "traces_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Heat : unit ~> unit # {Heat} within [3, 0]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: the running-time bounds of operation `Heat` must satisfy `lo <= hi`
  ======================================================================
  traces_reject_bounds_declared.tpe
  ======================================================================
  File "traces_reject_bounds_declared.tpe", line 6, characters 0-61:
  6 | operation Send : string ~> unit # {Tx | Tx; Tx} within [2, 6]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: operation `Send` is compound, so its running-time bounds follow from its grade `{Tx | Tx; Tx}` and must not be declared
  ======================================================================
  traces_reject_bounds_zero.tpe
  ======================================================================
  File "traces_reject_bounds_zero.tpe", line 4, characters 0-52:
  4 | operation Heat : unit ~> unit # {Heat} within [0, 0]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: the upper running-time bound of operation `Heat` must be positive
  ======================================================================
  traces_reject_default_bounds.tpe
  ======================================================================
  File "traces_reject_default_bounds.tpe", line 8, characters 0-28:
  8 | default Extrude () = delay 6
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Extrude` has grade `{6}`, which does not match the declared grade `{5}` of `Extrude`
    File "traces_reject_default_bounds.tpe", line 6, characters 0-58:
    6 | operation Extrude : unit ~> unit # {Extrude} within [3, 5]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Extrude` is declared here
    Note: the effect inequality `{6} <= {5}` does not hold
  ======================================================================
  traces_reject_default_nonatomic.tpe
  ======================================================================
  File "traces_reject_default_nonatomic.tpe", line 14, characters 0-39:
  14 | default PrintModel m = delay 6; Fresh m
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: a default implementation may only be given for an atomic operation, but the grade of `PrintModel` is `{Heat; Extrude; Cool}`; handle it with a handler in terms of the operations it names
  ======================================================================
  traces_reject_fractional_bound.tpe
  ======================================================================
  File "traces_reject_fractional_bound.tpe", line 5, characters 47-50:
  5 | operation Heat : unit ~> unit # {Heat} within [1/2, 1]
                                                     ^^^
  Syntax error: in the 'traces-cost-upper-bound' grading monoid, running-time bounds are delays, and delays are whole numbers of time steps; did you mean to use one of the 'traces-cost-lower-bound-rational', 'traces-cost-upper-bound-rational', 'traces-cost-interval-rational', 'regex-cost-lower-bound-rational-symbolic', 'regex-cost-upper-bound-rational-symbolic' or 'regex-cost-interval-rational-symbolic' grading monoids?
  ======================================================================
  traces_reject_missing_within.tpe
  ======================================================================
  File "traces_reject_missing_within.tpe", line 5, characters 0-38:
  5 | operation Heat : unit ~> unit # {Heat}
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: atomic operation `Heat` needs running-time bounds `within [lo, hi]` under the `traces-cost-upper-bound` grading monoid
  ======================================================================
  traces_reject_order.tpe
  ======================================================================
  File "traces_reject_order.tpe", line 20, characters 6-31:
  20 |       continue k with (Fresh m)
             ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Cool; Extrude; Heat}` accumulated since it was bound, which is not below its box grade `{Heat; Extrude; Cool}`
    File "traces_reject_order.tpe", line 16, characters 17-18:
    16 |   | PrintModel m k ->
                          ^
    `k` is bound here
    File "traces_reject_order.tpe", line 17, characters 6-21:
    17 |       perform Cool ();
               ^^^^^^^^^^^^^^^
    grade `{Cool}` accumulates here (operation `Cool`)
    File "traces_reject_order.tpe", line 18, characters 6-24:
    18 |       perform Extrude ();
               ^^^^^^^^^^^^^^^^^^
    grade `{Extrude}` accumulates here (operation `Extrude`)
    File "traces_reject_order.tpe", line 19, characters 6-21:
    19 |       perform Heat ();
               ^^^^^^^^^^^^^^^
    grade `{Heat}` accumulates here (operation `Heat`)
    Note: the resource inequality `{Cool; Extrude; Heat} <= {Heat; Extrude; Cool}` does not hold
  ======================================================================
  traces_reject_self_retry.tpe
  ======================================================================
  File "traces_reject_self_retry.tpe", line 6, characters 0-53:
  6 | operation Send : string ~> unit # {Send | Send; Send}
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: compound operation `Send` may not name itself in its grade `{Send | Send; Send}`
  ======================================================================
  traces_reject_undecided_condition.tpe
  ======================================================================
  File "traces_reject_undecided_condition.tpe", line 15, characters 49-50:
  15 | run handle (perform Op (); perform Tick ()) with h
                                                        ^
  Typing error: The condition `∀ε_Op. ε_Op · {1} <= {1} · ε_Op` of the case for `Op` cannot be established
    File "traces_reject_undecided_condition.tpe", line 13, characters 0-78:
    13 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `h` is defined here
    File "traces_reject_undecided_condition.tpe", line 11, characters 0-31:
    11 | operation Op : unit ~> unit # 1
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op` is declared here
    File "traces_reject_undecided_condition.tpe", line 13, characters 33-34:
    13 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
                                          ^
    `k` may have any grade `ε_Op`
    File "traces_reject_undecided_condition.tpe", line 13, characters 27-78:
    13 | let h = handler | x -> x | Op () k -> let r = continue k with () in delay 1; r
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the case for `Op` begins here
    Note: a run requires the effect inequality to hold for every grade the continuation `k` may have, and it is neither derived nor refuted
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
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Send ((), k) ↦
                        delay 1 (return ());
                        unbox k as unbox_var in
                        unbox_var ()
        # (1, (Send, {0}))
    },
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
  File "windowed_schedules_reject.tpe", lines 7-9, characters 17-17:
  7 | let late_send () : unit # (4, (Send, {2})) =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `(4, (Send, {3}))`, which does not match its annotated grade `(4, (Send, {2}))`
    Note: the effect inequality `(4, (Send, {3})) <= (4, (Send, {2}))` does not hold
  
  File "windowed_schedules_reject.tpe", lines 12-14, characters 12-17:
  12 | let slow () : unit # ([2, 3], (Send, {1 | 2})) =
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `([2, 4], (Send, {1; (0 | 1 | 2)}))`, which does not match its annotated grade `([2, 3], (Send, {1 | 2}))`
    Note: the effect inequality `([2, 4], (Send, {1; (0 | 1 | 2)})) <= ([2, 3], (Send, {1 | 2}))` does not hold
  
  File "windowed_schedules_reject.tpe", lines 21-22, characters 2-3:
  21 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `(2, (Send, {0}))` accumulated since it was bound, which is not below its box grade `[2, 4]`
    File "windowed_schedules_reject.tpe", line 18, characters 18-19:
    18 |   box [2, 4] 7 as x in
                           ^
    `x` is bound here
    File "windowed_schedules_reject.tpe", line 19, characters 2-17:
    19 |   perform Send ();
           ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    File "windowed_schedules_reject.tpe", line 20, characters 2-9:
    20 |   delay 1;
           ^^^^^^^
    grade `1` accumulates here (delay)
    Note: the resource inequality `(2, (Send, {0})) <= [2, 4]` does not hold
  
  File "windowed_schedules_reject.tpe", line 29, characters 51-69:
  29 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                                                          ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `(2, (Send, {0 | 1}))` accumulated since it was bound, which is not below its box grade `(1, (Send, {0}))`
    File "windowed_schedules_reject.tpe", line 29, characters 12-13:
    29 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                     ^
    `k` is bound here
    File "windowed_schedules_reject.tpe", line 29, characters 17-32:
    29 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                          ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    File "windowed_schedules_reject.tpe", line 29, characters 34-49:
    29 |   | Send () k -> perform Send (); perform Send (); continue k with ()
                                           ^^^^^^^^^^^^^^^
    grade `(1, (Send, {0}))` accumulates here (operation `Send`)
    Note: the resource inequality `(2, (Send, {0 | 1})) <= (1, (Send, {0}))` does not hold
  
  File "windowed_schedules_reject.tpe", line 32, characters 15-58:
  32 | let renamed () : unit # (1, (Recv, {0})) = perform Send ()
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
  >   ../tempore --grades regex-upper-bound-letter-automata $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "literals_reject_empty.tpe", line 4, characters 19-33:
  4 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: in the 'regex-upper-bound-letter-automata' grading monoid, this regular expression denotes the empty language, but grades are non-empty
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
  File "regular_reject_auth.tpe", lines 15-17, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 13, characters 36-37:
    13 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 14, characters 2-18:
    14 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 22-23, characters 2-5:
  22 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 20, characters 41-42:
    20 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 21, characters 2-19:
    21 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 29-30, characters 2-3:
  29 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 26, characters 20-21:
    26 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 27, characters 2-18:
    27 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 28, characters 2-9:
    28 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `regex-upper-bound-letter-automata` grading monoid
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 13-18, characters 23-3:
  13 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 24-25, characters 2-5:
  24 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 22, characters 23-24:
    22 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 23, characters 2-49:
    23 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-letter-automata)
  ======================================================================
  File "regular_reject_protocol.tpe", line 16, characters 6-23:
  16 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 12, characters 15-16:
    12 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 13, characters 6-21:
    13 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 14, characters 6-22:
    14 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 15, characters 14-29:
    15 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 18-19, characters 16-34:
  18 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold

The programs of the cost-model regular trace grades, run above under their
implementations by symbolic derivatives, under their implementations by
automata, the programs over rational delays excepted:

  $ for f in regex_costs_*.tpe
  > do
  >   case $f in
  >     regex_costs_rational_*.tpe) continue;;
  >     regex_costs_lower*.tpe) grades=regex-cost-lower-bound-letter-automata;;
  >     regex_costs_upper*.tpe) grades=regex-cost-upper-bound-letter-automata;;
  >     regex_costs_interval*.tpe) grades=regex-cost-interval-letter-automata;;
  >   esac
  >   echo "======================================================================"
  >   echo "$f ($grades)"
  >   echo "======================================================================"
  >   ../tempore --grades $grades $f
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  regex_costs_interval.tpe (regex-cost-interval-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_costs_interval_reject.tpe (regex-cost-interval-letter-automata)
  ======================================================================
  File "regex_costs_interval_reject.tpe", lines 13-14, characters 2-5:
  13 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_costs_interval_reject.tpe", line 11, characters 28-29:
    11 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 12, characters 2-18:
    12 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_costs_interval_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_costs_interval_reject.tpe", line 18, characters 28-29:
    18 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 19, characters 2-18:
    19 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_costs_interval_runs_reject.tpe (regex-cost-interval-letter-automata)
  ======================================================================
  File "regex_costs_interval_runs_reject.tpe", line 12, characters 6-34:
  12 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_costs_interval_runs_reject.tpe", line 19, characters 33-61:
  19 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_costs_lower.tpe (regex-cost-lower-bound-letter-automata)
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
  regex_costs_lower_reject.tpe (regex-cost-lower-bound-letter-automata)
  ======================================================================
  File "regex_costs_lower_reject.tpe", lines 15-16, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_costs_lower_reject.tpe", line 12, characters 31-32:
    12 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_costs_lower_reject.tpe", line 13, characters 2-17:
    13 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_costs_lower_reject.tpe", line 14, characters 2-9:
    14 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 22-23, characters 2-5:
  22 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_costs_lower_reject.tpe", line 20, characters 29-30:
    20 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_costs_lower_reject.tpe", line 21, characters 2-10:
    21 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 29-30, characters 2-5:
  29 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_lower_reject.tpe", line 27, characters 25-26:
    27 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_costs_lower_reject.tpe", line 28, characters 2-58:
    28 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_costs_lower_runs_reject.tpe (regex-cost-lower-bound-letter-automata)
  ======================================================================
  File "regex_costs_lower_runs_reject.tpe", line 11, characters 6-30:
  11 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_costs_upper.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_costs_upper_open.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_costs_upper_open_reject.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  File "regex_costs_upper_open_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_costs_upper_open_reject.tpe", line 10, characters 15-19:
    10 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_costs_upper_open_reject.tpe", line 11, characters 2-15:
    11 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_costs_upper_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_costs_upper_open_reject.tpe", line 7, characters 0-52:
    7 | operation Beep : unit ~> unit # {Beep} within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_costs_upper_reject.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  File "regex_costs_upper_reject.tpe", lines 14-15, characters 2-5:
  14 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_upper_reject.tpe", line 12, characters 25-26:
    12 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_costs_upper_reject.tpe", line 13, characters 2-18:
    13 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 23-24, characters 2-5:
  23 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_costs_upper_reject.tpe", line 20, characters 30-31:
    20 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_costs_upper_reject.tpe", line 21, characters 2-18:
    21 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_costs_upper_reject.tpe", line 22, characters 2-16:
    22 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_costs_upper_reject.tpe", line 28, characters 37-38:
    28 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_costs_upper_reject.tpe", line 29, characters 2-49:
    29 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_costs_upper_reject.tpe", lines 34-36, characters 17-17:
  34 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_costs_upper_runs.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_costs_upper_runs_reject.tpe (regex-cost-upper-bound-letter-automata)
  ======================================================================
  File "regex_costs_upper_runs_reject.tpe", line 12, characters 6-23:
  12 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 17, characters 26-43:
  17 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 20, characters 27-44:
  20 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations

The examples and programs of the regular trace grades under two further
implementations, by derivatives by letters instead of minterms
('-symbolic-by-letters') and by derivatives of expressions over single letters
instead of letter sets ('-letter-derivatives'), whose outputs are those of the
implementations above, the examples over rational delays excepted:

  $ for f in ../examples/regular/*.tpe ../examples/regular_costs/*.tpe \
  >   literals_reject_empty.tpe literals_regular.tpe regular_*.tpe regex_costs_*.tpe
  > do
  >   case $f in
  >     *_rational.tpe) continue;;
  >     regex_costs_rational_*.tpe) continue;;
  >     */regular_costs/lower_bounds.tpe | *costs_lower*.tpe) grades=regex-cost-lower-bound;;
  >     */regular_costs/upper_bounds.tpe | *costs_upper*.tpe) grades=regex-cost-upper-bound;;
  >     */regular_costs/intervals*.tpe | *costs_interval*.tpe) grades=regex-cost-interval;;
  >     *) grades=regex-upper-bound;;
  >   esac
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
  ../examples/regular_costs/intervals.tpe (regex-cost-interval-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1}, {1}],
    [{4}, {4}],
    [{1}, {1}],
    [{1}, {1}]
  ]
  
  ======================================================================
  ../examples/regular_costs/intervals.tpe (regex-cost-interval-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1}, {1}],
    [{4}, {4}],
    [{1}, {1}],
    [{1}, {1}]
  ]
  
  ======================================================================
  ../examples/regular_costs/lower_bounds.tpe (regex-cost-lower-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Part "gear")
  State: [
    { resource_0 ↦ Part "gear" # {Coat; 4} },
    {1},
    {4},
    {1}
  ]
  
  ======================================================================
  ../examples/regular_costs/lower_bounds.tpe (regex-cost-lower-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Part "gear")
  State: [
    { resource_0 ↦ Part "gear" # {Coat; 4} },
    {1},
    {4},
    {1}
  ]
  
  ======================================================================
  ../examples/regular_costs/upper_bounds.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {2; Send; 6} },
    {1},
    {2},
    {5}
  ]
  
  ======================================================================
  ../examples/regular_costs/upper_bounds.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {2; Send; 6} },
    {1},
    {2},
    {5}
  ]
  
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "literals_reject_empty.tpe", line 4, characters 19-33:
  4 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: in the 'regex-upper-bound-symbolic-by-letters' grading monoid, this regular expression denotes the empty language, but grades are non-empty
  ======================================================================
  literals_reject_empty.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "literals_reject_empty.tpe", line 4, characters 19-33:
  4 | let claim () = box {Read & Write} 1
                         ^^^^^^^^^^^^^^
  Syntax error: in the 'regex-upper-bound-letter-derivatives' grading monoid, this regular expression denotes the empty language, but grades are non-empty
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
  File "regular_reject_auth.tpe", lines 15-17, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 13, characters 36-37:
    13 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 14, characters 2-18:
    14 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 22-23, characters 2-5:
  22 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 20, characters 41-42:
    20 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 21, characters 2-19:
    21 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 29-30, characters 2-3:
  29 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 26, characters 20-21:
    26 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 27, characters 2-18:
    27 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 28, characters 2-9:
    28 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_auth.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_auth.tpe", lines 15-17, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{~(_ & ~Auth)*}`
    File "regular_reject_auth.tpe", line 13, characters 36-37:
    13 |   box {_*; Auth; _*} (Token "t") as t in
                                             ^
    `t` is bound here
    File "regular_reject_auth.tpe", line 14, characters 2-18:
    14 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {~(_ & ~Auth)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 22-23, characters 2-5:
  22 |   unbox c as cap in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Revoke}` accumulated since it was bound, which is not below its box grade `{(_ & ~Revoke)*}`
    File "regular_reject_auth.tpe", line 20, characters 41-42:
    20 |   box {~(_*; Revoke; _*)} (Token "c") as c in
                                                  ^
    `c` is bound here
    File "regular_reject_auth.tpe", line 21, characters 2-19:
    21 |   perform Revoke ();
           ^^^^^^^^^^^^^^^^^
    grade `{Revoke}` accumulates here (operation `Revoke`)
    Note: the resource inequality `{Revoke} <= {(_ & ~Revoke)*}` does not hold
  
  File "regular_reject_auth.tpe", lines 29-30, characters 2-3:
  29 |   unbox x as n in
         ^^^^^^^^^^^^^^^
  Typing error: Variable `x` is unboxed with grade `{Fetch; 3}` accumulated since it was bound, which is not below its box grade `{3; _*}`
    File "regular_reject_auth.tpe", line 26, characters 20-21:
    26 |   box {3; _*} 42 as x in
                             ^
    `x` is bound here
    File "regular_reject_auth.tpe", line 27, characters 2-18:
    27 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regular_reject_auth.tpe", line 28, characters 2-9:
    28 |   delay 3;
           ^^^^^^^
    grade `{3}` accumulates here (delay)
    Note: the resource inequality `{Fetch; 3} <= {3; _*}` does not hold
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `regex-upper-bound-symbolic-by-letters` grading monoid
  ======================================================================
  regular_reject_bounds.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_bounds.tpe", line 4, characters 0-52:
  4 | operation Send : unit ~> unit # {Send} within [1, 2]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: running-time bounds are only used by the trace and the regular expression grading monoids of timed operations, and must not be declared under the `regex-upper-bound-letter-derivatives` grading monoid
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 13-18, characters 23-3:
  13 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 24-25, characters 2-5:
  24 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 22, characters 23-24:
    22 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 23, characters 2-49:
    23 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_counterexample.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_counterexample.tpe", lines 13-18, characters 23-3:
  13 | let session (b : bool) : nat # {Open; Read*; Close} =
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read; (0 | Write); Close}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read; (0 | Write); Close} <= {Open; Read*; Close}` does not hold
    Note: the grade `{Open; Read; Write; Close}` is below `{Open; Read; (0 | Write); Close}` but not below `{Open; Read*; Close}`
  
  File "regular_reject_counterexample.tpe", lines 24-25, characters 2-5:
  24 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
    File "regular_reject_counterexample.tpe", line 22, characters 23-24:
    22 |   box {Auth; _*} 42 as t in
                                ^
    `t` is bound here
    File "regular_reject_counterexample.tpe", line 23, characters 2-49:
    23 |   if b then perform Auth () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Auth | Fetch}` accumulates here (this computation)
    Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
    Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regular_reject_protocol.tpe", line 16, characters 6-23:
  16 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 12, characters 15-16:
    12 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 13, characters 6-21:
    13 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 14, characters 6-22:
    14 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 15, characters 14-29:
    15 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 18-19, characters 16-34:
  18 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold
  ======================================================================
  regular_reject_protocol.tpe (regex-upper-bound-letter-derivatives)
  ======================================================================
  File "regular_reject_protocol.tpe", line 16, characters 6-23:
  16 |       continue k with x
             ^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{Open; Close; Read}` accumulated since it was bound, which is not below its box grade `{Open; Read*; Close}`
    File "regular_reject_protocol.tpe", line 12, characters 15-16:
    12 |   | Session () k ->
                        ^
    `k` is bound here
    File "regular_reject_protocol.tpe", line 13, characters 6-21:
    13 |       perform Open ();
               ^^^^^^^^^^^^^^^
    grade `{Open}` accumulates here (operation `Open`)
    File "regular_reject_protocol.tpe", line 14, characters 6-22:
    14 |       perform Close ();
               ^^^^^^^^^^^^^^^^
    grade `{Close}` accumulates here (operation `Close`)
    File "regular_reject_protocol.tpe", line 15, characters 14-29:
    15 |       let x = perform Read () in
                       ^^^^^^^^^^^^^^^
    grade `{Read}` accumulates here (operation `Read`)
    Note: the resource inequality `{Open; Close; Read} <= {Open; Read*; Close}` does not hold
  
  File "regular_reject_protocol.tpe", lines 18-19, characters 16-34:
  18 | let unclosed () : nat # {Open; Read*; Close} =
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Open; Read}`, which does not match its annotated grade `{Open; Read*; Close}`
    Note: the effect inequality `{Open; Read} <= {Open; Read*; Close}` does not hold
  ======================================================================
  regex_costs_interval.tpe (regex-cost-interval-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_costs_interval.tpe (regex-cost-interval-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # [{2}, {4}] },
    [{3}, {3}]
  ]
  
  ======================================================================
  regex_costs_interval_reject.tpe (regex-cost-interval-symbolic-by-letters)
  ======================================================================
  File "regex_costs_interval_reject.tpe", lines 13-14, characters 2-5:
  13 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_costs_interval_reject.tpe", line 11, characters 28-29:
    11 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 12, characters 2-18:
    12 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_costs_interval_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_costs_interval_reject.tpe", line 18, characters 28-29:
    18 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 19, characters 2-18:
    19 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_costs_interval_reject.tpe (regex-cost-interval-letter-derivatives)
  ======================================================================
  File "regex_costs_interval_reject.tpe", lines 13-14, characters 2-5:
  13 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{3}, {4}]`
    File "regex_costs_interval_reject.tpe", line 11, characters 28-29:
    11 |   box [3, 4] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 12, characters 2-18:
    12 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{3}, {4}]` does not hold
  
  File "regex_costs_interval_reject.tpe", lines 20-21, characters 2-5:
  20 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `[{Fetch}, {Fetch}]` accumulated since it was bound, which is not below its box grade `[{2}, {3}]`
    File "regex_costs_interval_reject.tpe", line 18, characters 28-29:
    18 |   box [2, 3] (Token "t") as t in
                                     ^
    `t` is bound here
    File "regex_costs_interval_reject.tpe", line 19, characters 2-18:
    19 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `[{Fetch}, {Fetch}]` accumulates here (operation `Fetch`)
    Note: the resource inequality `[{Fetch}, {Fetch}] <= [{2}, {3}]` does not hold
  ======================================================================
  regex_costs_interval_runs_reject.tpe (regex-cost-interval-symbolic-by-letters)
  ======================================================================
  File "regex_costs_interval_runs_reject.tpe", line 12, characters 6-34:
  12 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_costs_interval_runs_reject.tpe", line 19, characters 33-61:
  19 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_costs_interval_runs_reject.tpe (regex-cost-interval-letter-derivatives)
  ======================================================================
  File "regex_costs_interval_runs_reject.tpe", line 12, characters 6-34:
  12 |   box [{Fetch}, {_ & ~1 & ~Fetch}] (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  
  File "regex_costs_interval_runs_reject.tpe", line 19, characters 33-61:
  19 | operation Other : unit ~> unit # [{Fetch}, {_ & ~1 & ~Fetch}]
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `[{Fetch}, {_ & ~(1 | Fetch)}]` permits no trace over the declared operations
  ======================================================================
  regex_costs_lower.tpe (regex-cost-lower-bound-symbolic-by-letters)
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
  regex_costs_lower.tpe (regex-cost-lower-bound-letter-derivatives)
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
  regex_costs_lower_reject.tpe (regex-cost-lower-bound-symbolic-by-letters)
  ======================================================================
  File "regex_costs_lower_reject.tpe", lines 15-16, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_costs_lower_reject.tpe", line 12, characters 31-32:
    12 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_costs_lower_reject.tpe", line 13, characters 2-17:
    13 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_costs_lower_reject.tpe", line 14, characters 2-9:
    14 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 22-23, characters 2-5:
  22 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_costs_lower_reject.tpe", line 20, characters 29-30:
    20 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_costs_lower_reject.tpe", line 21, characters 2-10:
    21 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 29-30, characters 2-5:
  29 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_lower_reject.tpe", line 27, characters 25-26:
    27 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_costs_lower_reject.tpe", line 28, characters 2-58:
    28 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_costs_lower_reject.tpe (regex-cost-lower-bound-letter-derivatives)
  ======================================================================
  File "regex_costs_lower_reject.tpe", lines 15-16, characters 2-5:
  15 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Ping; 2}` accumulated since it was bound, which is not below its box grade `{Ping; 3}`
    File "regex_costs_lower_reject.tpe", line 12, characters 31-32:
    12 |   box {Ping; 3} (Token "t") as t in
                                        ^
    `t` is bound here
    File "regex_costs_lower_reject.tpe", line 13, characters 2-17:
    13 |   perform Ping ();
           ^^^^^^^^^^^^^^^
    grade `{Ping}` accumulates here (operation `Ping`)
    File "regex_costs_lower_reject.tpe", line 14, characters 2-9:
    14 |   delay 2;
           ^^^^^^^
    grade `{2}` accumulates here (delay)
    Note: the resource inequality `{Ping; 2} <= {Ping; 3}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 22-23, characters 2-5:
  22 |   unbox f as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `f` is unboxed with grade `{10}` accumulated since it was bound, which is not below its box grade `{Fetch}`
    File "regex_costs_lower_reject.tpe", line 20, characters 29-30:
    20 |   box {Fetch} (Token "f") as f in
                                      ^
    `f` is bound here
    File "regex_costs_lower_reject.tpe", line 21, characters 2-10:
    21 |   delay 10;
           ^^^^^^^^
    grade `{10}` accumulates here (delay)
    Note: the resource inequality `{10} <= {Fetch}` does not hold
  
  File "regex_costs_lower_reject.tpe", lines 29-30, characters 2-5:
  29 |   unbox q as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `q` is unboxed with grade `{Ping | Fetch; 1}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_lower_reject.tpe", line 27, characters 25-26:
    27 |   box {3} (Token "q") as q in
                                  ^
    `q` is bound here
    File "regex_costs_lower_reject.tpe", line 28, characters 2-58:
    28 |   if b then perform Fetch (); delay 1 else perform Ping ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Ping | Fetch; 1}` accumulates here (this computation)
    Note: the resource inequality `{Ping | Fetch; 1} <= {3}` does not hold
    Note: the grade `{Ping}` is below `{Ping | Fetch; 1}` but not below `{3}`
  ======================================================================
  regex_costs_lower_runs_reject.tpe (regex-cost-lower-bound-symbolic-by-letters)
  ======================================================================
  File "regex_costs_lower_runs_reject.tpe", line 11, characters 6-30:
  11 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_costs_lower_runs_reject.tpe (regex-cost-lower-bound-letter-derivatives)
  ======================================================================
  File "regex_costs_lower_runs_reject.tpe", line 11, characters 6-30:
  11 |   box {Ping; (_ & ~1 & ~Ping)} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The grade `{Ping; (_ & ~(1 | Ping))}` permits no trace over the declared operations
  ======================================================================
  regex_costs_upper.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_costs_upper.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "t")
  State: [
    { resource_0 ↦ Token "t" # {4} },
    {3}
  ]
  
  ======================================================================
  regex_costs_upper_open.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_costs_upper_open.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {2}
  ]
  
  ======================================================================
  regex_costs_upper_open_reject.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_costs_upper_open_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_costs_upper_open_reject.tpe", line 10, characters 15-19:
    10 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_costs_upper_open_reject.tpe", line 11, characters 2-15:
    11 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_costs_upper_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_costs_upper_open_reject.tpe", line 7, characters 0-52:
    7 | operation Beep : unit ~> unit # {Beep} within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_costs_upper_open_reject.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_costs_upper_open_reject.tpe", lines 12-13, characters 2-3:
  12 |   unbox slot as r in
         ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `slot` is unboxed with grade `{Tx}` accumulated since it was bound, which is not below its box grade `{2}`
    File "regex_costs_upper_open_reject.tpe", line 10, characters 15-19:
    10 |   box {2} 1 as slot in
                        ^^^^
    `slot` is bound here
    File "regex_costs_upper_open_reject.tpe", line 11, characters 2-15:
    11 |   perform Tx ();
           ^^^^^^^^^^^^^
    grade `{Tx}` accumulates here (operation `Tx`)
    Note: the resource inequality `{Tx} <= {2}` does not hold
  
  File "regex_costs_upper_open_reject.tpe", line 15, characters 0-25:
  15 | default Beep () = delay 3
       ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The default implementation of `Beep` has grade `{3}`, which does not match the declared grade `{2}` of `Beep`
    File "regex_costs_upper_open_reject.tpe", line 7, characters 0-52:
    7 | operation Beep : unit ~> unit # {Beep} within [1, 3)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Beep` is declared here
    Note: the effect inequality `{3} <= {2}` does not hold
  ======================================================================
  regex_costs_upper_reject.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_costs_upper_reject.tpe", lines 14-15, characters 2-5:
  14 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_upper_reject.tpe", line 12, characters 25-26:
    12 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_costs_upper_reject.tpe", line 13, characters 2-18:
    13 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 23-24, characters 2-5:
  23 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_costs_upper_reject.tpe", line 20, characters 30-31:
    20 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_costs_upper_reject.tpe", line 21, characters 2-18:
    21 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_costs_upper_reject.tpe", line 22, characters 2-16:
    22 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_costs_upper_reject.tpe", line 28, characters 37-38:
    28 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_costs_upper_reject.tpe", line 29, characters 2-49:
    29 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_costs_upper_reject.tpe", lines 34-36, characters 17-17:
  34 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_costs_upper_reject.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_costs_upper_reject.tpe", lines 14-15, characters 2-5:
  14 |   unbox t as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `t` is unboxed with grade `{Fetch}` accumulated since it was bound, which is not below its box grade `{3}`
    File "regex_costs_upper_reject.tpe", line 12, characters 25-26:
    12 |   box {3} (Token "t") as t in
                                  ^
    `t` is bound here
    File "regex_costs_upper_reject.tpe", line 13, characters 2-18:
    13 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    Note: the resource inequality `{Fetch} <= {3}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 23-24, characters 2-5:
  23 |   unbox l as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `l` is unboxed with grade `{Fetch; Log}` accumulated since it was bound, which is not below its box grade `{Log; 4}`
    File "regex_costs_upper_reject.tpe", line 20, characters 30-31:
    20 |   box {Log; 4} (Token "l") as l in
                                       ^
    `l` is bound here
    File "regex_costs_upper_reject.tpe", line 21, characters 2-18:
    21 |   perform Fetch ();
           ^^^^^^^^^^^^^^^^
    grade `{Fetch}` accumulates here (operation `Fetch`)
    File "regex_costs_upper_reject.tpe", line 22, characters 2-16:
    22 |   perform Log ();
           ^^^^^^^^^^^^^^
    grade `{Log}` accumulates here (operation `Log`)
    Note: the resource inequality `{Fetch; Log} <= {Log; 4}` does not hold
  
  File "regex_costs_upper_reject.tpe", lines 30-31, characters 2-5:
  30 |   unbox c as tok in
         ^^^^^^^^^^^^^^^^^
  Typing error: Variable `c` is unboxed with grade `{Fetch | Ping}` accumulated since it was bound, which is not below its box grade `{(Log | Ping)*}`
    File "regex_costs_upper_reject.tpe", line 28, characters 37-38:
    28 |   box {(Ping | Log)*} (Token "c") as c in
                                              ^
    `c` is bound here
    File "regex_costs_upper_reject.tpe", line 29, characters 2-49:
    29 |   if b then perform Ping () else perform Fetch ();
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{Fetch | Ping}` accumulates here (this computation)
    Note: the resource inequality `{Fetch | Ping} <= {(Log | Ping)*}` does not hold
    Note: the grade `{Fetch}` is below `{Fetch | Ping}` but not below `{(Log | Ping)*}`
  
  File "regex_costs_upper_reject.tpe", lines 34-36, characters 17-17:
  34 | let two_pings () : unit # {3} =
                        ^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{Ping; Ping}`, which does not match its annotated grade `{3}`
    Note: the effect inequality `{Ping; Ping} <= {3}` does not hold
  ======================================================================
  regex_costs_upper_runs.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_costs_upper_runs.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  === Run 1 ===
  return (Token "l")
  State: [
    { resource_0 ↦ Token "l" # {_ & ~(1 | Fetch)} },
    {1}
  ]
  
  ======================================================================
  regex_costs_upper_runs_reject.tpe (regex-cost-upper-bound-symbolic-by-letters)
  ======================================================================
  File "regex_costs_upper_runs_reject.tpe", line 12, characters 6-23:
  12 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 17, characters 26-43:
  17 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 20, characters 27-44:
  20 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  ======================================================================
  regex_costs_upper_runs_reject.tpe (regex-cost-upper-bound-letter-derivatives)
  ======================================================================
  File "regex_costs_upper_runs_reject.tpe", line 12, characters 6-23:
  12 |   box {_ & ~1 & ~Fetch} (Token "o") as o in
             ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 17, characters 26-43:
  17 | let annotated () : unit # {_ & ~1 & ~Fetch} = perform Fetch ()
                                 ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations
  
  File "regex_costs_upper_runs_reject.tpe", line 20, characters 27-44:
  20 | type pending = Pending of [{_ & ~1 & ~Fetch}]token
                                  ^^^^^^^^^^^^^^^^^
  Typing error: The grade `{_ & ~(1 | Fetch)}` permits no trace over the declared operations

The options: typechecking only reports errors and runs nothing, and the
single-dash form of the help option is not accepted.

  $ ../tempore --typecheck-only nat.tpe
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
    --debug           Show final internal state and top level typing results after execution
    --grades          Selects the grades (default: time-lower-bound); accepted:
        Time:
          time-lower-bound                         Lower bounds
          time-upper-bound                         Upper bounds
          time-interval                            Intervals
          time-lower-bound-rational                Lower bounds (rational)
          time-upper-bound-rational                Upper bounds (rational)
          time-interval-rational                   Intervals (rational)
        Traces:
          traces-upper-bound                       Upper bounds
          traces-upper-bound-rational              Upper bounds (rational)
        Traces of timed operations:
          traces-cost-lower-bound                  Lower bounds
          traces-cost-upper-bound                  Upper bounds
          traces-cost-interval                     Intervals
          traces-cost-lower-bound-rational         Lower bounds (rational)
          traces-cost-upper-bound-rational         Upper bounds (rational)
          traces-cost-interval-rational            Intervals (rational)
        Regular expressions:
          regex-upper-bound-symbolic               Upper bounds (symbolic)
              symbolic expressions over letter sets; inclusion by derivatives by minterms, depth-first
          regex-upper-bound-rational-symbolic      Upper bounds (rational, symbolic)
              minimal symbolic automata over letter and delay sets; inclusion by product with the complement, breadth-first
        Regular expressions of timed operations:
          regex-cost-lower-bound-symbolic          Lower bounds (symbolic)
              symbolic expressions over letter sets; inclusion by derivatives by minterms with closures, depth-first
          regex-cost-upper-bound-symbolic          Upper bounds (symbolic)
              symbolic expressions over letter sets; inclusion by derivatives by minterms with closures, depth-first
          regex-cost-interval-symbolic             Intervals (symbolic)
              symbolic expressions over letter sets; inclusion by derivatives by minterms with closures, depth-first
          regex-cost-lower-bound-rational-symbolic Lower bounds (rational, symbolic)
              minimal symbolic automata over letter and delay sets; inclusion by product with a closure reader, breadth-first
          regex-cost-upper-bound-rational-symbolic Upper bounds (rational, symbolic)
              minimal symbolic automata over letter and delay sets; inclusion by product with a closure reader, breadth-first
          regex-cost-interval-rational-symbolic    Intervals (rational, symbolic)
              minimal symbolic automata over letter and delay sets; inclusion by product with a closure reader, breadth-first
        Security levels:
          security-levels                          Levels
          time-lower-bound-levels                  Embargoes
          time-upper-bound-levels                  Expiring capabilities
          flow-levels                              Flow-sensitive outputs
        Semidirect products:
          resource-levels                          Resource levels
          windowed-schedules                       Windowed schedules
          mode-switch-costs                        Mode-switch costs
        Operation counts:
          counts-upper-bound                       Upper bounds
        Further implementations of the regular grades, kept for benchmarking, are accepted by --grades with the suffixes -letter-automata, -symbolic-by-letters and -letter-derivatives in place of -symbolic.
    --help            Display this list of options
    --no-stdlib       Do not load the standard library
    --typecheck-only  Typecheck the files without running them
  [2]

The rational-time example runs to its values under its intervals of hours.

  $ ../tempore --grades time-interval-rational ../examples/time/intervals_rational.tpe
  === Run 1 ===
  return 500
  State: [
    { resource_0 ↦ 500 # [4, 6] },
    [3.75, 3.75],
    [0.25, 0.25]
  ]
  
  === Run 2 ===
  return 25
  State: [
    { resource_0 ↦ 25 # (4, 6] },
    [4, 4],
    [0.25, 0.25]
  ]
  
  === Run 3 ===
  return 72
  State: [
    { resource_0 ↦ 72 # [1, 1] },
    [1/3, 1/3],
    [1/3, 1/3],
    [1/3, 1/3]
  ]
  

The staged-release case study runs to its values; the resource states are
omitted.

  $ ../tempore --grades time-lower-bound-levels ../examples/rollout/rollout.tpe | awk '/^State:/ { s = 1 } /^=== Run/ { s = 0 } !s'
  === Run 1 ===
  return (Stage ((Host "web-1")::[], 
                 Stage ((Host "web-2")::(Host "web-3")::[], 
                        Stage ((Host "db-1")::(Host "db-2")::[], Empty))))
  === Run 2 ===
  return 7
  === Run 3 ===
  return (Completed 5, 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "web-2"))::(Installed (Host "web-3"))::(Observed 0)::(Installed (Host "db-1"))::(Installed (Host "db-2"))::(Retried (Host "db-2"))::(Observed 0)::(Observed 0)::(Observed 0)::[])
  === Run 4 ===
  return (HostFailed (Host "db-2", 5), 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "web-2"))::(Installed (Host "web-3"))::(Observed 0)::(Installed (Host "db-1"))::(Installed (Host "db-2"))::(Reverted (Host "db-2"))::(Reverted (Host "db-1"))::(Reverted (Host "web-3"))::(Reverted (Host "web-2"))::(Reverted (Host "web-1"))::[])
  === Run 5 ===
  return (ErrorsObserved (1, 1), 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "cache-1"))::(Observed 1)::(Reverted (Host "cache-1"))::[])
  === Run 6 ===
  return (Completed 2, 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "db-3"))::(Retried (Host "db-3"))::(Retried (Host "db-3"))::(Reverted (Host "db-3"))::(Reverted (Host "web-1"))::(HotfixFetched 8)::(Built 8)::(Approved 8)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "db-3"))::(Observed 0)::(Observed 0)::(Observed 0)::[])
  === Run 7 ===
  return (HostFailed (Host "db-3", 2))
  === Run 8 ===
  return (Completed 5, "release notes")

The mail-session case study performs its operations by their defaults.

  $ ../tempore --grades regex-cost-upper-bound-symbolic ../examples/sessions/mail_session.tpe
  === Run 1 ===
  return (Checkpoint 5, 2)
  State: [
    { resource_0 ↦ Checkpoint 5 # {Login; (Fetch | Store)*; Logout} },
    {2},
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
    {2},
    {1},
    {1}
  ]
  
  === Run 3 ===
  return 3
  State: [
    { resource_1 ↦
        fun op_var ↦ handle
                       return op_var
                     with fetch_then_flag
        # {Login; (Fetch | Store)*; Logout}
    },
    {2},
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
  

The example of the trace grades without costs runs to its value under a
grade whose adjacent delays are merged.

  $ ../tempore --grades traces-upper-bound ../examples/traces/upper_bounds.tpe
  === Run 1 ===
  return "closed"
  State: [
    { resource_0 ↦ "closed" # {3 | 4} },
    {3}
  ]
  


The example of the trace grades without costs over rational delays runs to
its value under a grade whose adjacent delays are merged.

  $ ../tempore --grades traces-upper-bound-rational ../examples/traces/upper_bounds_rational.tpe
  === Run 1 ===
  return "ready"
  State: [
    { resource_0 ↦ "ready" # {1.5 | 2.5} },
    {1.5}
  ]
  

The coffee examples run to their values, the first by delays alone, the
second by the defaults of its operations.

  $ ../tempore --grades regex-upper-bound-rational-symbolic ../examples/introduction/coffee.tpe
  === Run 1 ===
  return (Cup (Brewed (Ground (Beans "arabica"))))
  State: [
    { resource_0 ↦ Brewed (Ground (Beans "arabica")) # {[5, ∞)} },
    {3},
    {2}
  ]
  
  $ ../tempore --grades regex-cost-interval-rational-symbolic ../examples/introduction/coffee_costs.tpe
  === Run 1 ===
  return (Cup (Brewed (Ground (Beans "arabica"))))
  State: [
    { resource_0 ↦
        Brewed (Ground (Beans "arabica"))
        # [{[5, ∞)}, {Pay; Brew; (Milk | Sugar)*}]
    },
    [{0.75}, {0.75}],
    [{5}, {5}],
    [{0.25}, {0.25}],
    [{0.25}, {0.25}]
  ]
  

The example of the regular trace grade over rational delays runs to its value
under a grade permitting the pauses of more than a second that are not whole.

  $ ../tempore --grades regex-upper-bound-rational-symbolic ../examples/regular/upper_bounds_rational.tpe
  === Run 1 ===
  return "settled"
  State: [
    { resource_0 ↦ "settled" # {(1, ∞) & ~1*} },
    {0.5},
    {1.25}
  ]
  

The example of the regular cost grades over rational delays, graded by
intervals, runs to its value, its operations performed by their defaults.

  $ ../tempore --grades regex-cost-interval-rational-symbolic ../examples/regular_costs/intervals_rational.tpe
  === Run 1 ===
  return ()
  State: [
    [{0.75}, {0.75}],
    [{0.25}, {0.25}],
    [{0.75}, {0.75}]
  ]
  
