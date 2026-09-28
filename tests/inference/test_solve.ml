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

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt
let verbose = Array.exists (( = ) "-v") Sys.argv

(* ------------------------------------------------------------------ *)
(* Grade systems of the files                                          *)
(* ------------------------------------------------------------------ *)

let default_grades = "time-lower-bound"

let glob pattern name =
  match String.index_opt pattern '*' with
  | None -> pattern = name
  | Some i ->
      let prefix = String.sub pattern 0 i
      and suffix = String.sub pattern (i + 1) (String.length pattern - i - 1) in
      String.length name >= String.length prefix + String.length suffix
      && String.starts_with ~prefix name
      && String.ends_with ~suffix name

let words line = List.filter (( <> ) "") (String.split_on_char ' ' line)

let rec grades_option = function
  | "--grades" :: name :: _ -> Some name
  | _ :: rest -> grades_option rest
  | [] -> None

let case_table lines =
  List.filter_map
    (fun line ->
      match words line with
      | ">" :: pattern :: rest
        when String.ends_with ~suffix:")" pattern && List.mem "../tempore" rest
        ->
          let pattern = String.sub pattern 0 (String.length pattern - 1) in
          Some
            (pattern, Option.value (grades_option rest) ~default:default_grades)
      | _ -> None)
    lines

let header_grades path =
  In_channel.with_open_text path In_channel.input_lines
  |> List.filteri (fun i _ -> i < 12)
  |> List.find_map (fun line -> grades_option (words line))

let grades_of_test table name =
  List.find_map
    (fun (pattern, grades) -> if glob pattern name then Some grades else None)
    table
  |> Option.value ~default:default_grades

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

type command_verdict = { line : int; kind : string; ok : bool; detail : string }
(** The verdict of the solver on one command. *)

module Programs (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module P = Inference.Program.Make (C)
  module S = Inference.Solver.Make (C)
  module R = Inference.Residual.Make (C)
  module D = Desugarer.Make (GS)
  module Grammar = Parser.Grammar.Make (GS)

  type state = { desugarer : D.state; env : Gen.env }

  let parse lexbuf = Grammar.commands (Parser.Lexer.tokens ()) lexbuf

  let parse_source ~name source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = name };
    parse lexbuf

  let initial =
    List.fold_left
      (fun st prim ->
        let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
        {
          desugarer = D.load_primitive st.desugarer x prim;
          env = Gen.load_primitive st.env x prim;
        })
      { desugarer = D.initial_state; env = Gen.initial_env }
      Language.Primitives.primitives

  let kind_of (cmd : _ Ast.command) =
    match cmd.it with
    | Ast.TyDef _ -> "type"
    | Ast.OpSig _ -> "operation"
    | Ast.OpDefault _ -> "default"
    | Ast.TopLet (x, _) -> "let " ^ Ast.Variable.string_of x
    | Ast.TopDo _ -> "run"

  let detail_of = function
    | P.Accepted -> ""
    | P.Defined (_, scheme) when verbose ->
        Format.asprintf "%t" (C.print_scheme scheme)
    | P.Defined _ -> ""
    | P.Rejected (P.Malformed d) -> d.Diagnostic.message
    | P.Rejected (P.Refuted f) -> Format.asprintf "%t" (R.print_failure f)
    | P.Rejected (P.Stuck _) -> "stuck"

  (* Each command desugared, then executed, until one stops the others; the
     verdicts, in order. *)
  let run st cmds =
    let step (st, verdicts, next) cmd =
      match next with
      | P.Stop -> (st, verdicts, next)
      | P.Continue ->
          let desugarer, cmd = D.desugar_command st.desugarer cmd in
          let env, (verdict : P.verdict), next = P.execute st.env cmd in
          let ok =
            match verdict.outcome with
            | P.Accepted | P.Defined _ -> true
            | P.Rejected _ -> false
          in
          let v =
            {
              line = cmd.at.Location.start.line;
              kind = kind_of cmd;
              ok;
              detail = detail_of verdict.outcome;
            }
          in
          ({ desugarer; env }, v :: verdicts, next)
    in
    let st, verdicts, _ = List.fold_left step (st, [], P.Continue) cmds in
    (st, List.rev verdicts)

  let with_stdlib =
    lazy
      (let st, verdicts =
         run initial (parse_source ~name:"stdlib.tpe" Loader.stdlib_source)
       in
       List.iter
         (fun v ->
           if not v.ok then
             fail "stdlib (%s) line %d, %s: %s" G.name v.line v.kind v.detail)
         verdicts;
       st)

  (* [declare cmds st] is [st] in the program of the standard library, which
     declares no operations, and [cmds]. *)
  let declare cmds st =
    {
      st with
      env = Gen.declare_operations (Loader.declared_operations cmds) st.env;
    }

  (* The solver's verdict on each command of [source], after the standard
     library: the command, whether it is accepted, and why not. *)
  let definitions source =
    let cmds = parse_source ~name:"small" source in
    let st = declare cmds (Lazy.force with_stdlib) in
    let _, _, verdicts =
      List.fold_left
        (fun (desugarer, env, verdicts) cmd ->
          let desugarer, cmd = D.desugar_command desugarer cmd in
          let env, (verdict : P.verdict), _ = P.execute env cmd in
          let ok =
            match verdict.outcome with
            | P.Accepted | P.Defined _ -> true
            | P.Rejected _ -> false
          in
          ( desugarer,
            env,
            (kind_of cmd, ok, detail_of verdict.outcome) :: verdicts ))
        (st.desugarer, st.env, []) cmds
    in
    List.rev verdicts

  (* The verdicts on a file, or [None] when it does not parse or desugar. *)
  let file path =
    match Parser.Lexer.read_file parse path with
    | cmds -> (
        match run (declare cmds (Lazy.force with_stdlib)) cmds with
        | _, verdicts -> Some verdicts
        | exception Error.Error _ -> None)
    | exception Error.Error _ -> None
    | exception Grammar.Error -> None
end

let grade_module name =
  match List.assoc_opt name Grades.GradeRegistry.grade_modules with
  | Some g -> g
  | None -> failwith ("unknown grades " ^ name)

module type PROGRAMS = sig
  val file : string -> command_verdict list option
  val definitions : string -> (string * bool * string) list
end

(* The programs of each grade, the standard library loaded once. *)
let programs_of =
  let table = Hashtbl.create 8 in
  fun grades ->
    match Hashtbl.find_opt table grades with
    | Some p -> p
    | None ->
        let (module G) = grade_module grades in
        let p = (module Programs (G) : PROGRAMS) in
        Hashtbl.add table grades p;
        p

let file_verdicts path grades =
  let (module P) = programs_of grades in
  let start = Unix.gettimeofday () in
  let verdicts = P.file path in
  (verdicts, Unix.gettimeofday () -. start)

(* The '.tpe' files under [dir], recursing into subdirectories (examples are
   grouped into some), each named entries sorted within its own directory. *)
let rec tpe_files dir =
  Sys.readdir dir |> Array.to_list |> List.sort String.compare
  |> List.concat_map (fun name ->
      let path = Filename.concat dir name in
      if Sys.is_directory path then tpe_files path
      else if Filename.check_suffix name ".tpe" then [ path ]
      else [])

(* The lines of the commands the solver rejects, by file: every other command
   of the examples and the tests is accepted. *)
let expected_rejections =
  [
    ("annotation_grade_variables_reject.tpe", [ 10; 17 ]);
    ("annotation_recursion_reject.tpe", [ 4; 8 ]);
    ("basic_unbox.tpe", [ 20; 30 ]);
    ("handlers_nested_reject.tpe", [ 18 ]);
    ("comp_type_annotation_reject.tpe", [ 3 ]);
    ("comparison_reject_box.tpe", [ 3 ]);
    ("comparison_reject_function.tpe", [ 5 ]);
    ("comp_type_annotation_upper_reject.tpe", [ 3 ]);
    ("continuation_discard_abort_reject_lower.tpe", [ 13 ]);
    ("continuation_discard_delay_reject_lower.tpe", [ 11 ]);
    ("continuation_discard_reject_lower.tpe", [ 10 ]);
    ("continuation_escape_reject.tpe", [ 11 ]);
    ("continuation_nested_discard_reject_lower.tpe", [ 10 ]);
    ("continuation_nested_escape_reject.tpe", [ 13 ]);
    ("continuation_nested_twice_reject_upper.tpe", [ 11 ]);
    ("continuation_twice_reject_upper.tpe", [ 10 ]);
    ("counts_upper_reject.tpe", [ 7; 14; 19; 27 ]);
    ("default_reject_bounds.tpe", [ 7 ]);
    ("rational_time_intervals_reject.tpe", [ 9 ]);
    ("rational_time_lower_reject.tpe", [ 10; 14 ]);
    ("rational_time_upper_reject.tpe", [ 7 ]);
    ("default_reject_duplicate.tpe", [ 8 ]);
    ("default_reject_type.tpe", [ 7 ]);
    ("error_apply_arg.tpe", [ 8 ]);
    ("error_earliest_failure.tpe", [ 11 ]);
    ("error_handler_case.tpe", [ 7 ]);
    ("error_unbox_nonvariable.tpe", [ 7 ]);
    ("error_use_after_delay.tpe", [ 15 ]);
    ("error_variant_arity.tpe", [ 12; 14; 16; 20 ]);
    ("errors_multiple.tpe", [ 12; 14; 18 ]);
    ("eternal_tyvars_reject_function.tpe", [ 9 ]);
    ("eternal_tyvars_reject_handler.tpe", [ 12 ]);
    ("eternal_tyvars_reject_higher_order.tpe", [ 9 ]);
    ("eternal_tyvars_reject_noneternal.tpe", [ 11 ]);
    ("invalid_match_type.tpe", [ 4 ]);
    ("flow_levels_reject.tpe", [ 8; 13; 18; 26 ]);
    ("iterative_unbox.tpe", [ 4 ]);
    ("less_than_function.tpe", [ 1 ]);
    ("levels_reject.tpe", [ 8 ]);
    ("levels_time_lower_reject.tpe", [ 9; 16 ]);
    ("levels_time_upper_reject.tpe", [ 9; 16 ]);
    ("malformed_type_application.tpe", [ 4 ]);
    ("mode_costs_reject.tpe", [ 9; 12; 19; 24; 31 ]);
    ("nat_reject_successor_pattern.tpe", [ 3; 5 ]);
    ("noneternal_reject_after_delay.tpe", [ 10 ]);
    ("noneternal_reject_alias.tpe", [ 5 ]);
    ("noneternal_reject_unknown_grade.tpe", [ 17; 34 ]);
    ("occurs_check.tpe", [ 1 ]);
    ("operation_reject_datatype.tpe", [ 5 ]);
    ("operation_reject_higher_order.tpe", [ 8 ]);
    ("peak_resources_reject.tpe", [ 11; 18; 28 ]);
    ("peak_usage_reject.tpe", [ 9; 18; 27; 30 ]);
    ("polymorphism_id_id.tpe", [ 2 ]);
    ("positivity_reject_list.tpe", [ 3 ]);
    ("positivity_reject_mutual.tpe", [ 3 ]);
    ("positivity_reject_nested.tpe", [ 3 ]);
    ("positivity_reject_omega.tpe", [ 7 ]);
    ("positivity_reject_parameter.tpe", [ 5 ]);
    ("regex_costs_interval_reject.tpe", [ 10; 17 ]);
    ("regex_costs_interval_runs_reject.tpe", [ 11; 19 ]);
    ("regex_costs_lower_reject.tpe", [ 11; 19; 26 ]);
    ("regex_costs_lower_runs_reject.tpe", [ 10 ]);
    ("regex_costs_upper_reject.tpe", [ 11; 19; 27; 34 ]);
    ("regex_costs_upper_runs_reject.tpe", [ 11; 17; 20 ]);
    ("regular_reject_auth.tpe", [ 12; 19; 25 ]);
    ("regular_reject_bounds.tpe", [ 4 ]);
    ("regular_reject_counterexample.tpe", [ 13; 21 ]);
    ("regular_reject_protocol.tpe", [ 9; 18 ]);
    ("time_reject_within.tpe", [ 6 ]);
    ("traces_intervals_default_bounds.tpe", [ 9 ]);
    ("traces_reject_allowance.tpe", [ 7 ]);
    ("traces_reject_bounds.tpe", [ 4 ]);
    ("traces_reject_bounds_declared.tpe", [ 6 ]);
    ("traces_reject_default_bounds.tpe", [ 8 ]);
    ("traces_reject_default_nonatomic.tpe", [ 14 ]);
    ("traces_reject_missing_within.tpe", [ 5 ]);
    ("traces_reject_order.tpe", [ 13 ]);
    ("traces_reject_self_retry.tpe", [ 6 ]);
    ("traces_reject_undecided_condition.tpe", [ 15 ]);
    ("traces_reject_unknown_event.tpe", [ 6 ]);
    ("windows_reject.tpe", [ 7; 12; 17; 25; 32 ]);
  ]

let slow = ref []

(* The verdicts on the file at [path] against [expected_rejections], or
   [None] when it does not parse or desugar. *)
let check path grades =
  let name = Filename.basename path in
  match file_verdicts path grades with
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
        Option.value (List.assoc_opt name expected_rejections) ~default:[]
      in
      if rejected <> expected then
        fail "%s: rejects lines [%s], expected [%s]" name
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
  let table = case_table cram and expected = expectations cram in
  List.iter
    (fun path ->
      let grades = Option.value (header_grades path) ~default:default_grades in
      ignore (check path grades))
    (tpe_files (Filename.concat root "examples"));
  List.iter
    (fun path ->
      let name = Filename.basename path in
      let grades = grades_of_test table name in
      match (check path grades, List.assoc_opt name expected) with
      | None, _ | _, None -> ()
      | Some verdicts, Some e ->
          let rejected = List.exists (fun v -> not v.ok) verdicts in
          if rejected <> e.typing_error && not e.syntax_error then
            fail "%s: the cram test shows it %s, the solver %s" name
              (if e.typing_error then "rejected" else "accepted")
              (if rejected then "rejects" else "accepts"))
    (tpe_files (Filename.concat root "tests"))

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

  let name = G.name
  let no_bounds = { Grade.cost = (fun _ -> (0, 0)); operations = [] }

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

  let solve ?(env = Gen.initial_env) c = S.solve (P.context ~loc:(at 0) env) c

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
    match solve (disj unit_arrow (X.Rho.of_nat 3)) with
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
      if G.leq no_bounds (G.of_nat 3) (G.of_nat 2) then (2, 3) else (3, 2)
    in
    let r = rho_var () in
    let constr =
      C.Exists
        ( vars ~rhos:[ r ] (),
          C.And
            ( C.Rho_leq (because 1, X.Rho.of_nat hi, X.Rho.var r),
              C.Rho_leq (because 2, X.Rho.var r, X.Rho.of_nat lo) ) )
    in
    match solve constr with
    | S.Refuted (R.Refuted_rho { lhs; rhs; info })
      when List.map line_of info = [ 1; 2 ]
           && X.Rho.equal no_bounds lhs (X.Rho.of_nat hi)
           && X.Rho.equal no_bounds rhs (X.Rho.of_nat lo) ->
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
      when G.equal no_bounds w (G.of_nat 1)
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
               ( leq 2 (X.Eps.of_nat 1) (v a),
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
      stuck ())
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
  let (module G) = grade_module grades in
  let (module P) = programs_of grades in
  let traces = String.starts_with ~prefix:"traces" grades in
  let lit n = if traces then Printf.sprintf "{%d}" n else string_of_int n in
  let read =
    if traces then "operation Read : unit ~> reading # {Read} within (1, 1)"
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
    "traces-lower-bound";
    "traces-upper-bound";
  ]

let () =
  List.iter
    (fun grades ->
      let (module G) = grade_module grades in
      let module T = Small (G) in
      T.run ();
      check_small_programs grades)
    four_grades;
  programs ();
  List.iter (fun (name, time) -> fail "%s is slow: %.1fs" name time) !slow;
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
