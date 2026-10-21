(* Tests of the constraint solver: whole programs, compared command by command
   with fixed verdicts, and targeted checks of the solver's rules on small
   constraints and programs. Silent on success. *)

module Ast = Language.Ast
module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Reason = Inference.Reason
open SolvePrograms

let fail = TestSupport.Failures.fail
let verbose = Array.exists (( = ) "-v") Sys.argv

(* The expected output of each test file in the cram test: whether it shows a
   typing error, and whether a syntax error. *)
type expectation = { typing_error : bool; syntax_error : bool }

let expectations lines =
  let rule = String.make 70 '=' in
  let rec blocks current acc = function
    | [] -> List.rev (match current with Some b -> b :: acc | None -> acc)
    | l1 :: l2 :: l3 :: rest when String.trim l1 = rule && String.trim l3 = rule
      ->
        let acc = match current with Some b -> b :: acc | None -> acc in
        blocks (Some (String.trim l2, [])) acc rest
    | line :: rest -> (
        match current with
        | Some (name, ls) -> blocks (Some (name, line :: ls)) acc rest
        | None -> blocks None acc rest)
  in
  let contains sub line =
    let n = String.length sub and m = String.length line in
    let rec at i = i + n <= m && (String.sub line i n = sub || at (i + 1)) in
    at 0
  in
  List.map
    (fun (name, ls) ->
      ( name,
        {
          typing_error = List.exists (contains "Typing error") ls;
          syntax_error = List.exists (contains "Syntax error") ls;
        } ))
    (blocks None [] lines)

(* ------------------------------------------------------------------ *)
(* Whole programs, against fixed verdicts                              *)
(* ------------------------------------------------------------------ *)

let file_verdicts ?packages path grades =
  let (module P) = programs_of grades in
  let start = Unix.gettimeofday () in
  let verdicts = P.file ?packages path in
  (verdicts, Unix.gettimeofday () -. start)

(* The lines of the commands the solver rejects, by file, a path relative to
   the project root: every other command of the examples and the tests is
   accepted. *)
let expected_rejections =
  [
    ("tests/alias_cyclic_reject.tpe", [ 3 ]);
    ("tests/alias_cyclic_reject_argument.tpe", [ 3 ]);
    ("tests/alias_cyclic_reject_mutual.tpe", [ 3 ]);
    ("tests/alias_cyclic_reject_parameter.tpe", [ 3 ]);
    ("tests/alias_cyclic_reject_through_alias.tpe", [ 3 ]);
    ("tests/andalso_reject_tuple.tpe", [ 4 ]);
    ("tests/annotation_grade_variables_cyclic_reject.tpe", [ 15; 25 ]);
    ("tests/annotation_grade_variables_interval_reject.tpe", [ 25 ]);
    ("tests/annotation_grade_variables_reject.tpe", [ 11; 18 ]);
    ("tests/annotation_recursion_reject.tpe", [ 4; 8 ]);
    ("examples/basics/basic_unbox.tpe", [ 20; 30 ]);
    ("examples/handlers/nested_reject.tpe", [ 18 ]);
    ("examples/opentrons/beads_reject.tpe", [ 32 ]);
    ("examples/opentrons/binding_reject.tpe", [ 42 ]);
    ("examples/opentrons/cleanup_reject.tpe", [ 33 ]);
    ("examples/opentrons/contamination_reject.tpe", [ 39 ]);
    ("examples/opentrons/elisa_reject.tpe", [ 31 ]);
    ("examples/opentrons/enzyme_reject.tpe", [ 44 ]);
    ("examples/opentrons/purification_reject.tpe", [ 125; 148; 167 ]);
    ("examples/opentrons/reagents_reject.tpe", [ 41 ]);
    ("examples/opentrons/staggered_reject.tpe", [ 30 ]);
    ("examples/opentrons/stopread_reject.tpe", [ 41 ]);
    ("examples/opentrons/washes_reject.tpe", [ 32 ]);
    ("tests/comp_type_annotation_reject.tpe", [ 3 ]);
    ("tests/comparison_reject_box.tpe", [ 3 ]);
    ("tests/comparison_reject_function.tpe", [ 5 ]);
    ("tests/comparison_reject_recursive_argument.tpe", [ 5 ]);
    ("tests/comp_type_annotation_upper_reject.tpe", [ 8 ]);
    ("tests/continuation_discard_abort_reject_lower.tpe", [ 13 ]);
    ("tests/continuation_discard_delay_reject_lower.tpe", [ 11 ]);
    ("tests/continuation_discard_reject_lower.tpe", [ 10 ]);
    ("tests/continuation_escape_reject.tpe", [ 11 ]);
    ("tests/continuation_nested_discard_reject_lower.tpe", [ 10 ]);
    ("tests/continuation_nested_escape_reject.tpe", [ 14 ]);
    ("tests/continuation_nested_twice_reject_upper.tpe", [ 12 ]);
    ("tests/continuation_twice_reject_upper.tpe", [ 11 ]);
    ("tests/counts_upper_reject.tpe", [ 11; 18; 23; 31 ]);
    ("tests/default_reject_bounds.tpe", [ 7 ]);
    ("tests/rational_time_intervals_reject.tpe", [ 10 ]);
    ("tests/rational_time_intervals_reject_within.tpe", [ 10 ]);
    ("tests/rational_time_lower_reject.tpe", [ 11; 15 ]);
    ("tests/rational_time_upper_reject.tpe", [ 8 ]);
    ("tests/rational_traces_intervals_default_open_reject.tpe", [ 15; 16 ]);
    ("tests/rational_traces_intervals_reject.tpe", [ 14 ]);
    ("tests/rational_traces_upper_open_reject.tpe", [ 13 ]);
    ("tests/rational_traces_upper_reject.tpe", [ 14 ]);
    ("tests/default_reject_cycle.tpe", [ 9 ]);
    ("tests/default_reject_duplicate.tpe", [ 8 ]);
    ("tests/default_reject_global.tpe", [ 11 ]);
    ("tests/default_reject_loop.tpe", [ 6 ]);
    ("tests/default_reject_type.tpe", [ 7 ]);
    ("tests/default_reject_closure.tpe", [ 19 ]);
    ("tests/default_reject_unestablished.tpe", [ 18 ]);
    ("tests/delay_reject_overflow.tpe", [ 8 ]);
    ("tests/error_apply_arg.tpe", [ 8 ]);
    ("tests/float_literals_reject_subtraction.tpe", [ 4 ]);
    ("tests/exhaustiveness_reject_bool.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_constructor.tpe", [ 5 ]);
    ("tests/exhaustiveness_reject_int.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_let.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_nat.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_nil.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_parameter.tpe", [ 3 ]);
    ("tests/exhaustiveness_reject_string.tpe", [ 3 ]);
    ("tests/error_earliest_failure.tpe", [ 11 ]);
    ("tests/error_handler_case.tpe", [ 7 ]);
    ("tests/error_unbox_nonvariable.tpe", [ 7 ]);
    ("tests/error_use_after_delay.tpe", [ 15 ]);
    ("tests/error_variant_arity.tpe", [ 12; 14; 16; 20 ]);
    ("tests/errors_multiple.tpe", [ 12; 14; 18 ]);
    ("tests/eternal_recursive_reject_argument.tpe", [ 10 ]);
    ("tests/eternal_tyvars_reject_function.tpe", [ 10 ]);
    ("tests/eternal_tyvars_reject_handler.tpe", [ 13 ]);
    ("tests/eternal_tyvars_reject_higher_order.tpe", [ 10 ]);
    ("tests/eternal_tyvars_reject_noneternal.tpe", [ 12 ]);
    ("tests/invalid_match_type.tpe", [ 4 ]);
    ("tests/flow_levels_reject.tpe", [ 12; 17; 22; 30 ]);
    ("tests/iterative_unbox.tpe", [ 4 ]);
    ("tests/unbox_annotation_reject.tpe", [ 4 ]);
    ("tests/unbox_nested_reject_lower.tpe", [ 10; 19 ]);
    ("tests/unbox_nested_reject_upper.tpe", [ 10; 19 ]);
    ("tests/less_than_function.tpe", [ 1 ]);
    ("tests/levels_reject.tpe", [ 12 ]);
    ("tests/levels_time_lower_reject.tpe", [ 14; 21 ]);
    ("tests/levels_time_upper_reject.tpe", [ 14; 21 ]);
    ("tests/list_constructor_reject.tpe", [ 3 ]);
    ("tests/malformed_type_application.tpe", [ 4 ]);
    ("tests/mode_switch_costs_reject.tpe", [ 13; 16; 23; 28; 35 ]);
    ("tests/mode_times_reject.tpe", [ 18; 25; 28 ]);
    ("tests/nat_reject_successor_pattern.tpe", [ 3; 5 ]);
    ("tests/noneternal_reject_after_delay.tpe", [ 11 ]);
    ("tests/noneternal_reject_alias.tpe", [ 9 ]);
    ("tests/noneternal_reject_unknown_grade.tpe", [ 18; 35 ]);
    ("tests/occurs_check.tpe", [ 1 ]);
    ("tests/occurs_check_related_annotation.tpe", [ 6 ]);
    ("tests/occurs_check_related_application.tpe", [ 7 ]);
    ("tests/occurs_check_related_pattern.tpe", [ 7 ]);
    ("tests/operation_reject_datatype.tpe", [ 5 ]);
    ("tests/operation_reject_higher_order.tpe", [ 8 ]);
    ("tests/plain_traces_upper_reject.tpe", [ 16; 22 ]);
    ("tests/polymorphism_id_id.tpe", [ 2 ]);
    ("tests/positivity_reject_list.tpe", [ 3 ]);
    ("tests/positivity_reject_mutual.tpe", [ 3 ]);
    ("tests/positivity_reject_nested.tpe", [ 3 ]);
    ("tests/positivity_reject_omega.tpe", [ 7 ]);
    ("tests/positivity_reject_parameter.tpe", [ 5 ]);
    ("tests/recursion_closure_reject_interval.tpe", [ 13 ]);
    ("tests/recursion_closure_reject_upper.tpe", [ 15; 19 ]);
    ("tests/recursion_effect_reject_invariant.tpe", [ 8 ]);
    ("tests/recursion_invariant_reject_upper.tpe", [ 15 ]);
    ("tests/recursion_effect_reject_lower.tpe", [ 7 ]);
    ("tests/recursion_effect_reject_unannotated.tpe", [ 8 ]);
    ("tests/recursion_effect_reject_unannotated_regular.tpe", [ 16 ]);
    ("tests/recursion_handler_reject_upper.tpe", [ 13; 23 ]);
    ("tests/recursion_lock_reject.tpe", [ 8 ]);
    ("tests/regex_timed_compound_named_later_reject.tpe", [ 10 ]);
    ("tests/regex_timed_interval_reject.tpe", [ 15; 22 ]);
    ("tests/regex_timed_interval_ticks_reject.tpe", [ 16; 24 ]);
    ("tests/regex_timed_lower_reject.tpe", [ 16; 24; 31 ]);
    ("tests/regex_timed_lower_ticks_reject.tpe", [ 15 ]);
    ("tests/regex_timed_rational_interval_default_open_reject.tpe", [ 14; 15 ]);
    ("tests/regex_timed_rational_interval_open_reject.tpe", [ 12 ]);
    ("tests/regex_timed_rational_interval_reject.tpe", [ 15; 23 ]);
    ("tests/regex_timed_rational_lower_reject.tpe", [ 16; 23; 33; 40 ]);
    ("tests/regex_timed_rational_upper_open_reject.tpe", [ 14; 20 ]);
    ("tests/regex_timed_rational_upper_reject.tpe", [ 17; 26; 37; 47; 56 ]);
    ("tests/regex_timed_rigid_interval_reject.tpe", [ 27 ]);
    ( "tests/regex_timed_rigid_rational_upper_reject.tpe",
      [ 24; 35; 43; 53; 63; 74 ] );
    ("tests/regex_timed_upper_open_reject.tpe", [ 14; 20 ]);
    ("tests/regex_timed_upper_reject.tpe", [ 16; 24; 32; 39 ]);
    ("tests/regex_timed_upper_ticks_reject.tpe", [ 16; 22; 25 ]);
    ("tests/regex_rational_reject.tpe", [ 15; 22; 31; 33 ]);
    ("tests/regular_reject_auth.tpe", [ 16; 23; 29 ]);
    ("tests/regular_reject_bounds.tpe", [ 9 ]);
    ("tests/regular_reject_counterexample.tpe", [ 18; 26 ]);
    ("tests/regular_reject_protocol.tpe", [ 14; 23 ]);
    ("tests/resource_levels_by_resource_reject.tpe", [ 16; 23; 33 ]);
    ("tests/resource_levels_reject.tpe", [ 13; 22; 31; 34; 42; 45; 53 ]);
    ("tests/strict_delays_lower_reject.tpe", [ 27 ]);
    ("tests/strict_delays_rational_reject.tpe", [ 31; 51; 70 ]);
    ("tests/strict_delays_traces_reject.tpe", [ 26 ]);
    ("tests/strict_delays_whole_reject.tpe", [ 27 ]);
    ("tests/termination_reject_ackermann.tpe", [ 4 ]);
    ("tests/termination_reject_countdown.tpe", [ 4 ]);
    ("tests/termination_reject_escape.tpe", [ 4 ]);
    ("tests/termination_reject_increasing.tpe", [ 3 ]);
    ("tests/termination_reject_loop.tpe", [ 3 ]);
    ("tests/termination_reject_spin.tpe", [ 3 ]);
    ("tests/time_reject_within.tpe", [ 6 ]);
    ("tests/traces_intervals_default_bounds.tpe", [ 14 ]);
    ("tests/traces_intervals_default_open_reject.tpe", [ 14; 15 ]);
    ("tests/traces_open_bounds_reject.tpe", [ 14; 20 ]);
    ("tests/traces_reject_allowance.tpe", [ 12 ]);
    ("tests/traces_reject_bounds.tpe", [ 8 ]);
    ("tests/traces_reject_bounds_declared.tpe", [ 11 ]);
    ("tests/traces_reject_bounds_zero.tpe", [ 9 ]);
    ("tests/traces_reject_bounds_zero_lower.tpe", [ 10 ]);
    ("tests/traces_reject_default_bounds.tpe", [ 13 ]);
    ("tests/traces_reject_default_nonatomic.tpe", [ 19 ]);
    ("tests/traces_reject_missing_within.tpe", [ 10 ]);
    ("tests/traces_reject_order.tpe", [ 17 ]);
    ("tests/traces_reject_self_retry.tpe", [ 11 ]);
    ("tests/traces_reject_undecided_condition.tpe", [ 20 ]);
    ("tests/traces_reject_unknown_event.tpe", [ 11 ]);
    ("tests/traces_rigid_upper_reject.tpe", [ 27 ]);
    ("tests/windowed_schedules_reject.tpe", [ 11; 16; 21; 29; 36 ]);
    ("tests/event_separation_reject.tpe", [ 18; 29; 40; 49; 58 ]);
    ("tests/event_separation_reject_runs.tpe", [ 20; 27; 33 ]);
    ("tests/event_separation_reject_unknown.tpe", [ 11 ]);
  ]

(* The files whose typechecking took over 2 s, reported but not failed:
   elapsed times depend on the machine and its load. *)
let slow = ref []

(* The verdicts on the file at [path] against [expected_rejections], or
   [None] when it does not parse or desugar. *)
let check ?packages path grades =
  let name = Filename.basename path in
  let root = "../../" in
  let key =
    if String.starts_with ~prefix:root path then
      String.sub path (String.length root)
        (String.length path - String.length root)
    else path
  in
  match file_verdicts ?packages path grades with
  | None, _ -> None
  | Some verdicts, time ->
      if time > 2. then slow := (name, time) :: !slow;
      if verbose then (
        Format.eprintf "%s (%s): %.2fs@." name grades time;
        if Sys.getenv_opt "SOLVE_FILE" = Some name then
          List.iter
            (fun v ->
              Format.eprintf "  line %d %s: %b@.    %s@." v.line v.kind v.ok
                v.detail)
            verdicts);
      let rejected =
        List.filter_map (fun v -> if v.ok then None else Some v.line) verdicts
      in
      let expected =
        Option.value (List.assoc_opt key expected_rejections) ~default:[]
      in
      if rejected <> expected then
        fail "%s: rejects lines [%s], expected [%s]" key
          (String.concat "; " (List.map string_of_int rejected))
          (String.concat "; " (List.map string_of_int expected));
      Some verdicts

let programs () =
  let root = "../.." in
  let cram =
    In_channel.with_open_text
      (Filename.concat root "tests/run_tests.t")
      In_channel.input_lines
  in
  let expected = expectations cram in
  List.iter
    (fun path ->
      let grades = TestSupport.Header.grades path in
      ignore (check ~packages:(TestPrograms.packages ~grades path) path grades))
    (TestPrograms.tpe_files (Filename.concat root "examples"));
  List.iter
    (fun path ->
      let name = Filename.basename path in
      let grades = TestSupport.Header.grades path in
      match (check path grades, List.assoc_opt name expected) with
      | None, _ | _, None -> ()
      | Some verdicts, Some e ->
          let rejected = List.exists (fun v -> not v.ok) verdicts in
          if rejected <> e.typing_error && not e.syntax_error then
            fail "%s: the cram test shows it %s, the solver %s" name
              (if e.typing_error then "rejected" else "accepted")
              (if rejected then "rejects" else "accepts"))
    (TestPrograms.tpe_files ~recursive:false (Filename.concat root "tests"))

(* ------------------------------------------------------------------ *)
(* The solver on small constraints                                     *)
(* ------------------------------------------------------------------ *)

module Small (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module P = Inference.Program.Make (C)
  module S = Inference.Solver.Make (C)
  module R = Inference.Residual.Make (C)
  module RS = Inference.RigidScope.Make (C)

  (* [delay k] is the grade of the delay of the literal [k]. *)
  let delay k = G.of_delay (Option.get (G.Delay.read (Grade.Int k)))
  let name = G.name

  let no_bounds =
    {
      Grade.running_time =
        (fun _ ->
          (Grade.Closed Grades.Rational.zero, Grade.Closed Grades.Rational.zero));
      operations = [];
    }

  (* A location per line: a failure names the atom it comes from by its
     line. *)
  let at line =
    let pos = { Location.line; column = 1; offset = 0 } in
    { Location.filename = "small"; start = pos; stop = pos }

  let because line = Reason.because (at line) Reason.Annotation
  let line_of (reason : C.reason) = reason.at.start.line
  let ty_var () = Ast.TyParamModule.fresh "ty"
  let rho_var () = X.Rho_var.fresh_indexed ()
  let eps_var () = X.Eps_var.fresh_indexed ()
  let param a = Ast.TyParam a
  let nat = Ast.TyConst Language.Const.NatTy
  let bool = Ast.TyConst Language.Const.BooleanTy
  let arrow a b e = Ast.TyArrow (a, Ast.CompTy (b, X.Eps.var e))

  let unit_arrow =
    Ast.TyArrow (Ast.TyTuple [], Ast.CompTy (Ast.TyTuple [], X.Eps.unit))

  let vars ?(tys = []) ?(rhos = []) ?(eps = []) () =
    { C.ty_vars = tys; rho_vars = rhos; eps_vars = eps }

  let op = Ast.OpName.fresh "Op"

  let origin line : Reason.rigid_origin =
    {
      clause = { op; signature_at = at line; case_at = at line };
      continuation = None;
      continuation_at = at line;
    }

  let solve ?(env = Gen.initial_env) c = S.solve (P.context env) c

  let solved label c =
    match solve c with
    | S.Solved solution -> Some solution
    | outcome ->
        fail "%s (%s): expected a solution, got %t" label name
          (S.print_outcome outcome);
        None

  let expect label ok =
    if not ok then fail "%s (%s): unexpected solution" label name

  let has_sub (hyps : R.hyps) a b path =
    List.exists
      (fun (s : R.sub) ->
        s.lhs = param a && s.rhs = param b && s.info.path = path)
      hyps.sub_vars

  let has_rho (hyps : R.hyps) lhs rhs path =
    List.exists
      (fun (o : R.rho_ordering) ->
        X.Rho.equal no_bounds o.lhs lhs
        && X.Rho.equal no_bounds o.rhs rhs
        && o.info.path = path)
      hyps.rho_hyps

  let has_eps (hyps : R.hyps) lhs rhs path =
    List.exists
      (fun (o : R.eps_ordering) ->
        X.Eps.equal no_bounds o.lhs lhs
        && X.Eps.equal no_bounds o.rhs rhs
        && o.info.path = path)
      hyps.eps_hyps

  (* [[ρ₁](a → b ! ε₁) <: [ρ₂](c → d ! ε₂)]: the box grade and the domain
     contravariant, the result and the effect covariant. *)
  let decomposition () =
    let a = ty_var () and b = ty_var () and c = ty_var () and d = ty_var () in
    let r1 = rho_var () and r2 = rho_var () in
    let e1 = eps_var () and e2 = eps_var () in
    let constr =
      C.Exists
        ( vars ~tys:[ a; b; c; d ] ~rhos:[ r1; r2 ] ~eps:[ e1; e2 ] (),
          C.Sub
            ( because 1,
              Ast.TyBox (X.Rho.var r1, arrow (param a) (param b) e1),
              Ast.TyBox (X.Rho.var r2, arrow (param c) (param d) e2) ) )
    in
    Option.iter
      (fun (s : S.solution) ->
        let h = s.hyps in
        expect "decomposition"
          (has_sub h c a [ Reason.Box_content; Reason.Argument ]
          && has_sub h b d [ Reason.Box_content; Reason.Result ]
          && has_rho h (X.Rho.var r2) (X.Rho.var r1) [ Reason.Box_grade ]
          && has_eps h (X.Eps.var e1) (X.Eps.var e2)
               [ Reason.Box_content; Reason.Effect ]))
      (solved "decomposition" constr)

  (* Handler types: the input invariant, the output covariant. *)
  let handler_decomposition () =
    let a = ty_var () and b = ty_var () and c = ty_var () and d = ty_var () in
    let e1 = eps_var () and e2 = eps_var () and e3 = eps_var () in
    let e4 = eps_var () in
    let handler a e b e' =
      Ast.TyHandler
        (Ast.CompTy (param a, X.Eps.var e), Ast.CompTy (param b, X.Eps.var e'))
    in
    let constr =
      C.Exists
        ( vars ~tys:[ a; b; c; d ] ~eps:[ e1; e2; e3; e4 ] (),
          C.Sub (because 1, handler a e1 b e2, handler c e3 d e4) )
    in
    let input = [ Reason.Handler_input ]
    and output = [ Reason.Handler_output ] in
    let at_effect path = path @ [ Reason.Effect ] in
    Option.iter
      (fun (s : S.solution) ->
        let h = s.hyps in
        expect "handler decomposition"
          (has_sub h a c input && has_sub h c a input && has_sub h b d output
          && (not (has_sub h d b output))
          && has_eps h (X.Eps.var e1) (X.Eps.var e3) (at_effect input)
          && has_eps h (X.Eps.var e3) (X.Eps.var e1) (at_effect input)
          && has_eps h (X.Eps.var e2) (X.Eps.var e4) (at_effect output)))
      (solved "handler decomposition" constr)

  (* Type-application arguments are invariant; an alias is unfolded. *)
  let applications () =
    let a = ty_var () and b = ty_var () in
    let list t = Ast.TyApply (Ast.list_ty_name, [ t ]) in
    let arg = [ Reason.Type_argument 1 ] in
    Option.iter
      (fun (s : S.solution) ->
        expect "invariant arguments"
          (has_sub s.hyps a b arg && has_sub s.hyps b a arg))
      (solved "invariant arguments"
         (C.Exists
            ( vars ~tys:[ a; b ] (),
              C.Sub (because 1, list (param a), list (param b)) )));
    Option.iter
      (fun (s : S.solution) ->
        expect "alias" (s.hyps.sub_vars = [] && s.hyps.rho_hyps = []))
      (solved "alias"
         (C.Sub (because 1, Ast.TyApply (Ast.bool_ty_name, []), bool)));
    match
      solve (C.Sub (because 7, Ast.TyApply (Ast.nat_ty_name, []), bool))
    with
    | S.Refuted (R.Shape_mismatch f) when line_of f.info = 7 -> ()
    | outcome ->
        fail "alias mismatch (%s): got %t" name (S.print_outcome outcome)

  (* [a <: nat → b ! ε]: [a] is expanded to an arrow from [nat]. *)
  let expansion () =
    let a = ty_var () and b = ty_var () and e = eps_var () in
    let constr =
      C.Exists
        ( vars ~tys:[ a; b ] ~eps:[ e ] (),
          C.Sub (because 1, param a, arrow nat (param b) e) )
    in
    Option.iter
      (fun (s : S.solution) ->
        match Ast.TyParamMap.find_opt a s.subst.ty_subst with
        | Some
            (Ast.TyArrow
               ( Ast.TyConst Language.Const.NatTy,
                 Ast.CompTy (Ast.TyParam b', X.Eps_var e') )) ->
            expect "expansion"
              (has_sub s.hyps b' b [ Reason.Result ]
              && has_eps s.hyps (X.Eps.var e') (X.Eps.var e) [ Reason.Effect ])
        | _ -> fail "expansion (%s): not expanded to an arrow from nat" name)
      (solved "expansion" constr)

  (* Shape and occurs failures name the atom they come from. *)
  let mismatches () =
    (match solve (C.Sub (because 7, nat, bool)) with
    | S.Refuted (R.Shape_mismatch f) when line_of f.info = 7 -> ()
    | outcome -> fail "mismatch (%s): got %t" name (S.print_outcome outcome));
    let a = ty_var () and b = ty_var () and e = eps_var () in
    match
      solve
        (C.Exists
           ( vars ~tys:[ a; b ] ~eps:[ e ] (),
             C.Sub (because 8, param a, arrow (param a) (param b) e) ))
    with
    | S.Refuted (R.Occurs_check f) when line_of f.info = 8 -> ()
    | outcome -> fail "occurs (%s): got %t" name (S.print_outcome outcome)

  (* Eternality: reduced to type unknowns, or never. *)
  let eternality () =
    let a = ty_var () and e = eps_var () in
    let never label ?env ty =
      match
        solve ?env
          (C.Exists (vars ~tys:[ a ] ~eps:[ e ] (), C.Eternal (because 9, ty)))
      with
      | S.Refuted (R.Never_eternal { reason; _ }) when line_of reason = 9 -> ()
      | outcome -> fail "%s (%s): got %t" label name (S.print_outcome outcome)
    and on_a label ty =
      Option.iter
        (fun (s : S.solution) ->
          expect label
            (List.map (fun (e : R.eternal) -> e.eternal_ty) s.hyps.eternal_hyps
            = [ param a ]))
        (solved label
           (C.Exists (vars ~tys:[ a ] (), C.Eternal (because 9, ty))))
    in
    let token = Ast.TyName.fresh "token" in
    let env =
      Gen.add_type_definitions ~loc:(at 0) Gen.initial_env
        ( Ast.Noneternal,
          [ ([], token, Ast.TySum [ (Ast.Label.fresh "Token", None) ]) ] )
    in
    never "arrow never eternal" (arrow nat nat e);
    never "box never eternal" (Ast.TyBox (X.Rho.unit, nat));
    never "list of arrows never eternal"
      (Ast.TyApply (Ast.list_ty_name, [ arrow nat nat e ]));
    never "noneternal type" ~env (Ast.TyApply (token, []));
    never "list of a noneternal type" ~env
      (Ast.TyApply (Ast.list_ty_name, [ Ast.TyApply (token, []) ]));
    on_a "tuple eternal by its unknown" (Ast.TyTuple [ param a; nat ]);
    on_a "list eternal by its argument"
      (Ast.TyApply (Ast.list_ty_name, [ param a ]))

  (* The var-rule disjunction: its grade decided against the unit first,
     then its type. Where the unit is the top every grade is below it. *)
  let disjunction () =
    let a = ty_var () and r = rho_var () in
    let disj ty grade =
      C.Exists
        ( vars ~tys:[ a ] ~rhos:[ r ] (),
          C.Eternal_or_unit (because 5, ty, grade) )
    in
    let unit_least = G.unit_least in
    Option.iter
      (fun (s : S.solution) ->
        expect "disjunction at a function"
          (if unit_least then has_rho s.hyps (X.Rho.var r) X.Rho.unit []
           else s.hyps.rho_hyps = []))
      (solved "disjunction at a function" (disj unit_arrow (X.Rho.var r)));
    Option.iter
      (fun (s : S.solution) ->
        expect "disjunction at nat"
          (s.hyps.rho_hyps = [] && s.hyps.disj_hyps = []))
      (solved "disjunction at nat" (disj nat (X.Rho.var r)));
    Option.iter
      (fun (s : S.solution) ->
        expect "disjunction at an unknown"
          (List.length s.hyps.disj_hyps = if unit_least then 1 else 0))
      (solved "disjunction at an unknown" (disj (param a) (X.Rho.var r)));
    Option.iter
      (fun (s : S.solution) ->
        expect "disjunction at the unit grade" (s.hyps.rho_hyps = []))
      (solved "disjunction at the unit grade" (disj unit_arrow X.Rho.unit));
    match solve (disj unit_arrow (X.Rho.const (delay 3))) with
    | S.Refuted (R.Refuted_rho { info = [ reason ]; _ })
      when unit_least && line_of reason = 5 ->
        ()
    | S.Solved _ when not unit_least -> ()
    | outcome ->
        fail "disjunction at a late function (%s): got %t" name
          (S.print_outcome outcome)

  (* [hi ≾ ρ ≾ lo] with [hi] not below [lo]: refuted through the chain, with
     the reasons of both atoms. *)
  let chain () =
    let hi, lo =
      if G.leq no_bounds (delay 3) (delay 2) then (2, 3) else (3, 2)
    in
    let r = rho_var () in
    let constr =
      C.Exists
        ( vars ~rhos:[ r ] (),
          C.And
            ( C.Rho_leq (because 1, X.Rho.const (delay hi), X.Rho.var r),
              C.Rho_leq (because 2, X.Rho.var r, X.Rho.const (delay lo)) ) )
    in
    match solve constr with
    | S.Refuted (R.Refuted_rho { lhs; rhs; info })
      when List.map line_of info = [ 1; 2 ]
           && X.Rho.equal no_bounds lhs (X.Rho.const (delay hi))
           && X.Rho.equal no_bounds rhs (X.Rho.const (delay lo)) ->
        ()
    | outcome -> fail "chain (%s): got %t" name (S.print_outcome outcome)

  let forall line e c = C.Forall_eps (e, origin line, c)
  let leq line lhs rhs = C.Eps_leq (because line, lhs, rhs)
  let ( * ) = X.Eps.mul
  let v = X.Eps.var

  (* A cycle of local unknowns bounded below by the rigid: collapsed, then
     sent to the rigid. *)
  let localisation () =
    let j = eps_var () and a = eps_var () and b = eps_var () in
    let constr =
      forall 1 j
        (C.Exists
           ( vars ~eps:[ a; b ] (),
             C.conj_all
               [
                 leq 2 (v j) (v a);
                 leq 3 (v a) (v b);
                 leq 4 (v b) (v a);
                 leq 5 (v b) (v j);
               ] ))
    in
    let sent_to_j k (s : S.solution) =
      match X.Eps_var.Map.find_opt k s.subst.grade_subst.eps_subst with
      | Some (X.Eps_var j') -> X.Eps_var.equal j j'
      | _ -> false
    in
    Option.iter
      (fun (s : S.solution) ->
        expect "localisation"
          (s.hyps.eps_hyps = [] && s.obligations = [] && sent_to_j a s
         && sent_to_j b s))
      (solved "localisation" constr)

  (* [c · j ≾ j] for an outer [c], where the unit is least: deferred as a
     condition on [j]. *)
  let deferral () =
    let j = eps_var () and c = eps_var () in
    let constr =
      C.Exists (vars ~eps:[ c ] (), forall 1 j (leq 2 (v c * v j) (v j)))
    in
    Option.iter
      (fun (s : S.solution) ->
        match s.obligations with
        | [ { rigids = [ (j', _) ]; eps_conditions = [ o ]; _ } ] ->
            expect "deferral" (X.Eps_var.equal j j' && line_of o.info = 2)
        | _ -> fail "deferral (%s): expected one condition on the rigid" name)
      (solved "deferral" constr)

  (* One side mentioning the rigid: kept with the rigid at the top on the
     left, at the unit on the right where the unit is least, and otherwise
     deferred. *)
  let strips () =
    let j = eps_var () and c = eps_var () in
    Option.iter
      (fun (s : S.solution) ->
        expect "strip at the top"
          (has_eps s.hyps X.Eps.top (v c) [] && s.obligations = []))
      (solved "strip at the top"
         (C.Exists (vars ~eps:[ c ] (), forall 1 j (leq 2 (v j) (v c)))));
    Option.iter
      (fun (s : S.solution) ->
        expect "strip at the unit"
          (if G.unit_least then
             has_eps s.hyps (v c) X.Eps.unit [] && s.obligations = []
           else List.length s.obligations = 1))
      (solved "strip at the unit"
         (C.Exists (vars ~eps:[ c ] (), forall 1 j (leq 2 (v c) (v j)))))

  (* [j · j ≾ j] where the unit is least: refuted by the witness one step. *)
  let retry () =
    let j = eps_var () in
    match solve (forall 1 j (leq 2 (v j * v j) (v j))) with
    | S.Refuted (R.Refuted_condition { condition; witness = [ w ] })
      when G.equal no_bounds w (delay 1)
           && List.length condition.eps_conditions = 1 ->
        ()
    | outcome -> fail "retry (%s): got %t" name (S.print_outcome outcome)

  (* An inner condition refuted once the outer scope gives its unknown a
     value: [∀j₁. ∃a. 1 ≾ a ∧ ∀j₂. a · j₂ ≾ j₂]. *)
  let retry_after_close () =
    let j1 = eps_var () and j2 = eps_var () and a = eps_var () in
    let constr =
      forall 1 j1
        (C.Exists
           ( vars ~eps:[ a ] (),
             C.And
               ( leq 2 (X.Eps.const (delay 1)) (v a),
                 forall 3 j2 (leq 4 (v a * v j2) (v j2)) ) ))
    in
    match solve constr with
    | S.Refuted (R.Refuted_condition { condition; _ })
      when condition.origin.clause.case_at.start.line = 3 ->
        ()
    | outcome ->
        fail "retry after close (%s): got %t" name (S.print_outcome outcome)

  (* [∃c. ∀j. ∃a. j · a ≾ a ≾ c · j] where the unit is least: no rule gives
     [a] a value. *)
  let stuck () =
    let j = eps_var () and c = eps_var () and a = eps_var () in
    let constr =
      C.Exists
        ( vars ~eps:[ c ] (),
          forall 1 j
            (C.Exists
               ( vars ~eps:[ a ] (),
                 C.And (leq 2 (v j * v a) (v a), leq 3 (v a) (v c * v j)) )) )
    in
    match solve constr with
    | S.Stuck { stuck_origin; _ }
      when stuck_origin.clause.case_at.start.line = 1 ->
        ()
    | outcome -> fail "stuck (%s): got %t" name (S.print_outcome outcome)

  (* [∃ε. ε · ε · 1 ≾ ε ∧ ε ≾ 3] under time-upper-bound: satisfiable is not
     refuted, established finds no closed instance, and the search at a budget
     of one trial is abandoned. *)
  let unestablished () =
    let e = eps_var () in
    let constr =
      C.Exists
        ( vars ~eps:[ e ] (),
          C.And
            ( leq 1 (v e * v e * X.Eps.const (delay 1)) (v e),
              leq 2 (v e) (X.Eps.const (delay 3)) ) )
    in
    let context = P.context Gen.initial_env in
    Option.iter
      (fun (s : S.solution) ->
        (match (S.satisfiable context s, S.established context s) with
        | Ok (), Error (R.Unestablished { eps_orderings; abandoned = false; _ })
          when List.length eps_orderings = 2 ->
            ()
        | _, Error f ->
            fail "unestablished (%s): got %t" name (R.print_failure f)
        | _, Ok () -> fail "unestablished (%s): established" name);
        let residual =
          {
            R.empty with
            rho_orderings = s.hyps.rho_hyps;
            eps_orderings = s.hyps.eps_hyps;
          }
        in
        match RS.instance ~budget:1 context residual with
        | Error (R.Unestablished { abandoned = true; _ }) -> ()
        | Error f -> fail "abandoned (%s): got %t" name (R.print_failure f)
        | Ok _ -> fail "abandoned (%s): an instance found" name)
      (solved "unestablished" constr)

  (* [∃ε. ε · ε ≾ ε ∧ 1 ≾ ε ∧ ε ≾ 1] under time-upper-bound: solved, and
     refuted by its report, which equates [ε] with [1] and leaves the closed
     ordering [1 · 1 ≾ 1]. *)
  let reported_closed () =
    let e = eps_var () and one = X.Eps.const (delay 1) in
    let constr =
      C.Exists
        ( vars ~eps:[ e ] (),
          C.And
            (leq 1 (v e * v e) (v e), C.And (leq 2 one (v e), leq 3 (v e) one))
        )
    in
    Option.iter
      (fun (s : S.solution) ->
        match S.generalise (Ast.TyTuple []) s with
        | Error (R.Refuted_eps _) -> ()
        | Error f ->
            fail "reported closed (%s): got %t" name (R.print_failure f)
        | Ok _ -> fail "reported closed (%s): not refuted" name)
      (solved "reported closed" constr)

  let run () =
    decomposition ();
    handler_decomposition ();
    applications ();
    expansion ();
    mismatches ();
    eternality ();
    disjunction ();
    chain ();
    localisation ();
    strips ();
    if G.unit_least then (
      deferral ();
      retry ();
      retry_after_close ();
      stuck ());
    if G.name = "time-upper-bound" then (
      unestablished ();
      reported_closed ())
end

(* ------------------------------------------------------------------ *)
(* Programs on handlers, boxes and annotations                        *)
(* ------------------------------------------------------------------ *)

(* Programs on handlers, boxes and annotations, with the verdict each has
   where the unit is least (right-sided grades) and where it is the top
   (left-sided ones). [Read] reads a value that is not eternal. *)
type expected = Typed | Refuted

let small_programs ~lit ~read =
  let src =
    [
      "noneternal type reading = Reading of nat";
      read;
      (* Handlers *)
      "let relay m = handle m () with (handler | x -> () | Read p k -> let a = \
       perform Read p in unbox k as k' in let h = fun x -> x in let g = h (fun \
       u -> k' a) in let g' = h g in g' ())";
      "let relay_boxed m = handle m () with (handler | x -> () | Read p k -> \
       let h = fun x -> x in let k1 = h k in let k2 = h k1 in let a = perform \
       Read p in unbox k2 as k' in k' a)";
      "let discard m = handle m () with (handler | x -> () | Read p k -> ())";
      "let resume_twice m = handle m () with (handler | x -> () | Read p k -> \
       let a = perform Read p in unbox k as k' in k' a; k' a)";
      (* Boxes *)
      "let stale_call f = delay 1; f ()";
      Printf.sprintf
        "let boxed_call f = box %s f as g in delay 1; unbox g as g' in g' ()"
        (lit 1);
      "let handed_box_call b = delay 1; unbox b as g in g ()";
      Printf.sprintf "let boxing_an_argument x = box %s x as b in b" (lit 1);
      Printf.sprintf
        "let claim_on_time u = box %s () as x in delay 3; unbox x as y in y"
        (lit 3);
      Printf.sprintf
        "let claim_late u = box %s () as x in delay 4; unbox x as y in y"
        (lit 3);
      Printf.sprintf
        "let claim_early u = box %s () as x in delay 2; unbox x as y in y"
        (lit 3);
      "let inferred_grade b = delay 2; unbox b as y in y";
      "let kept_and_claimed b = (b, (fun u -> delay 2; unbox b as y in y))";
      Printf.sprintf
        "let escaping_on_time u = let mk = fun v -> box %s () as x in x in let \
         r = mk () in delay 2; unbox r as y in y"
        (lit 2);
      Printf.sprintf
        "let escaping_late u = let mk = fun v -> box %s () as x in x in let r \
         = mk () in delay 4; unbox r as y in y"
        (lit 2);
      Printf.sprintf
        "let escaping_early u = let mk = fun v -> box %s () as x in x in let r \
         = mk () in delay 1; unbox r as y in y"
        (lit 2);
      "let branches c b = if c then (delay 1; unbox b as y in y) else (delay \
       3; unbox b as y in y)";
      "let nested b = delay 1; unbox b as c in delay 2; unbox c as z in z";
      Printf.sprintf
        "let nesting u = box %s () as x in box %s x as y in delay 1; unbox y \
         as x' in delay 2; unbox x' as z in z"
        (lit 2) (lit 1);
      Printf.sprintf
        "let claimed_in_clause_unit m = box %s () as x in handle m () with \
         (handler | r -> r | Read p k -> unbox x as y in let a = perform Read \
         p in unbox k as k' in k' a)"
        (lit 0);
      Printf.sprintf
        "let claimed_in_clause_one m = box %s () as x in handle m () with \
         (handler | r -> r | Read p k -> unbox x as y in let a = perform Read \
         p in unbox k as k' in k' a)"
        (lit 1);
      "let handed_to_clause m b = handle m () with (handler | r -> r | Read p \
       k -> unbox b as y in let a = perform Read p in unbox k as k' in k' a)";
      (* Annotations *)
      "let id_bool (x : bool) = x";
      "let id_unit = (fun x -> x : unit -> unit)";
      Printf.sprintf "let compose_g f g x = f ((g : unit -> unit # %s) x)"
        (lit 0);
    ]
  in
  String.concat "\n" src

(* The verdicts, by definition: where the unit is least, and where it is the
   top. *)
let small_program_verdicts =
  [
    ("relay", (Typed, Typed));
    ("relay_boxed", (Typed, Typed));
    ("discard", (Typed, Refuted));
    ("resume_twice", (Refuted, Typed));
    ("stale_call", (Refuted, Typed));
    ("boxed_call", (Refuted, Typed));
    ("handed_box_call", (Typed, Typed));
    ("boxing_an_argument", (Typed, Typed));
    ("claim_on_time", (Typed, Typed));
    ("claim_late", (Refuted, Typed));
    ("claim_early", (Typed, Refuted));
    ("inferred_grade", (Typed, Typed));
    ("kept_and_claimed", (Typed, Typed));
    ("escaping_on_time", (Typed, Typed));
    ("escaping_late", (Refuted, Typed));
    ("escaping_early", (Typed, Refuted));
    ("branches", (Typed, Typed));
    ("nested", (Typed, Typed));
    ("nesting", (Refuted, Typed));
    ("claimed_in_clause_unit", (Refuted, Typed));
    ("claimed_in_clause_one", (Refuted, Refuted));
    ("handed_to_clause", (Typed, Typed));
    ("id_bool", (Typed, Typed));
    ("id_unit", (Typed, Typed));
    ("compose_g", (Typed, Typed));
  ]

let check_small_programs grades =
  let (module G) = TestPrograms.grade_module grades in
  let (module P) = programs_of grades in
  let traces = String.starts_with ~prefix:"traces" grades in
  let lit n = if traces then Printf.sprintf "{%d}" n else string_of_int n in
  let read =
    if traces then "operation Read : unit ~> reading # {Read} within [1, 1]"
    else "operation Read : unit ~> reading # 1"
  in
  let verdicts = P.definitions (small_programs ~lit ~read) in
  if verbose then
    List.iter
      (fun (kind, ok, detail) ->
        Format.eprintf "%s %s: %b %s@." grades kind ok detail)
      verdicts;
  List.iter
    (fun (definition, (least, top)) ->
      let expected = if G.unit_least then least else top in
      match
        List.find_opt (fun (k, _, _) -> k = "let " ^ definition) verdicts
      with
      | None -> fail "%s (%s): no verdict" definition grades
      | Some (_, ok, detail) ->
          if ok <> (expected = Typed) then
            fail "%s (%s): expected %s, got %s %s" definition grades
              (if expected = Typed then "typed" else "refuted")
              (if ok then "typed" else "refuted")
              detail)
    small_program_verdicts

let four_grades =
  [
    "time-lower-bound";
    "time-upper-bound";
    "traces-timed-lower-bound";
    "traces-timed-upper-bound";
  ]

let () =
  List.iter
    (fun grades ->
      let (module G) = TestPrograms.grade_module grades in
      let module T = Small (G) in
      T.run ();
      check_small_programs grades)
    four_grades;
  programs ();
  List.iter
    (fun (name, time) -> Format.eprintf "Note: %s took %.1fs@." name time)
    !slow;
  TestSupport.Failures.finish ()
