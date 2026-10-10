(* Tests of constraint generation: generation over every command of the
   examples and tests, each under the grade system it is run with, and checks
   of the constraints generated for small terms. Silent on success. *)

module Ast = Language.Ast
module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Reason = Inference.Reason

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt

(* ------------------------------------------------------------------ *)
(* Grade systems of the files                                          *)
(* ------------------------------------------------------------------ *)

let default_grades = "time-lower-bound"

(* [glob pattern name] matches [name] against [pattern], whose [*] stands for
   any string. *)
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

(* The grades named by [--grades NAME] in [words], the default if none. *)
let rec grades_option = function
  | "--grades" :: name :: _ -> Some name
  | _ :: rest -> grades_option rest
  | [] -> None

(* The case table of the cram test: the file patterns and their grades. *)
let case_table path =
  In_channel.with_open_text path In_channel.input_lines
  |> List.filter_map (fun line ->
      match words line with
      | ">" :: pattern :: rest
        when String.ends_with ~suffix:")" pattern && List.mem "../tempore" rest
        ->
          let pattern = String.sub pattern 0 (String.length pattern - 1) in
          Some
            (pattern, Option.value (grades_option rest) ~default:default_grades)
      | _ -> None)

(* The grades a file names in its header comment. *)
let header_grades path =
  In_channel.with_open_text path In_channel.input_lines
  |> List.filteri (fun i _ -> i < 12)
  |> List.find_map (fun line -> grades_option (words line))

let grades_of_test table name =
  List.find_map
    (fun (pattern, grades) -> if glob pattern name then Some grades else None)
    table
  |> Option.value ~default:default_grades

(* The files with a program that a correct front end or generation rejects,
   with an error of their own rather than one of the solver. *)
let malformed =
  [
    "alias_cyclic_reject.tpe";
    "alias_cyclic_reject_argument.tpe";
    "alias_cyclic_reject_mutual.tpe";
    "alias_cyclic_reject_parameter.tpe";
    "alias_cyclic_reject_through_alias.tpe";
    "annotation_type_variables_reject.tpe";
    "annotation_type_variables_reject_operation.tpe";
    "error_unbox_nonvariable.tpe";
    "error_variant_arity.tpe";
    "default_reject_duplicate.tpe";
    "default_reject_unknown.tpe";
    "duplicate_variant_tydef_sum.tpe";
    "malformed_type_application.tpe";
    "noneternal_reject_alias.tpe";
    "shadow_label.tpe";
    "traces_reject_bounds.tpe";
    "traces_reject_bounds_declared.tpe";
    "traces_reject_bounds_zero.tpe";
    "traces_reject_fractional_bound.tpe";
    "traces_reject_default_nonatomic.tpe";
    "traces_reject_missing_within.tpe";
    "traces_reject_self_retry.tpe";
    "traces_reject_unknown_event.tpe";
    "use_undefined_type.tpe";
    "non_linear_pattern.tpe";
    "shadow_type.tpe";
    "time_reject_within.tpe";
    "rational_time_intervals_reject_within.tpe";
    "levels_reject_literal.tpe";
    "literals_reject_complement.tpe";
    "literals_reject_component.tpe";
    "literals_reject_counts.tpe";
    "literals_reject_empty.tpe";
    "literals_reject_flow.tpe";
    "literals_reject_inf.tpe";
    "literals_reject_large.tpe";
    "literals_reject_modes.tpe";
    "literals_reject_name.tpe";
    "literals_reject_negative.tpe";
    "literals_reject_peak.tpe";
    "literals_reject_windowed_schedules.tpe";
    "literals_reject_interval_closed_infinity.tpe";
    "literals_reject_interval_empty.tpe";
    "literals_reject_interval_no_step.tpe";
    "literals_reject_interval_reversed.tpe";
    "literals_reject_resource_levels_range_empty.tpe";
    "literals_reject_windowed_schedules_empty.tpe";
    "literals_reject_within_empty.tpe";
    "literals_reject_within_no_step.tpe";
    "nat_reject_negative.tpe";
    "nat_reject_successor_zero.tpe";
    "operation_reject_datatype.tpe";
    "operation_reject_higher_order.tpe";
    "positivity_reject_list.tpe";
    "positivity_reject_mutual.tpe";
    "positivity_reject_nested.tpe";
    "positivity_reject_omega.tpe";
    "positivity_reject_parameter.tpe";
    "literals_reject_star.tpe";
    "literals_reject_unknown.tpe";
    "literals_reject_rational_negative.tpe";
    "literals_reject_fraction.tpe";
    "literals_reject_fraction_operator.tpe";
    "literals_reject_fraction_zero.tpe";
    "delay_reject_expression.tpe";
    "delay_reject_fraction.tpe";
    "delay_reject_variable.tpe";
    "regular_reject_bounds.tpe";
    "regex_timed_interval_ticks_reject.tpe";
    "regex_timed_lower_ticks_reject.tpe";
    "regex_timed_upper_ticks_reject.tpe";
    "rational_traces_intervals_reject_open.tpe";
  ]

(* ------------------------------------------------------------------ *)
(* Generation over whole programs                                      *)
(* ------------------------------------------------------------------ *)

module Program (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module D = Desugarer.Make (GS)
  module Grammar = Parser.Grammar.Make (GS)

  let parse lexbuf = Grammar.commands (Parser.Lexer.tokens ()) lexbuf

  let parse_source source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = "stdlib.tpe" };
    parse lexbuf

  let initial =
    List.fold_left
      (fun (desugarer, env) prim ->
        let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
        (D.load_primitive desugarer x prim, Gen.load_primitive env x prim))
      (D.initial_state, Gen.initial_env)
      Language.Primitives.primitives

  (* The scheme [∀α. α] of a definition whose type is not inferred yet. *)
  let assumed () =
    let a = Ast.TyParamModule.fresh "assumed" in
    { (C.monomorphic (Ast.TyParam a)) with C.ty_params = [ a ] }

  (* The generated constraint is printable, and its type and grade unknowns
     are bound but for those of [allowed]. *)
  let check_scope name constr (allowed : C.free) =
    ignore (C.to_string constr);
    ignore (C.freshen C.empty_subst constr);
    let free = C.free_vars constr in
    if
      not
        (Ast.TyParamSet.subset free.free_tys allowed.free_tys
        && X.Rho_var.Set.subset free.free_rhos allowed.free_rhos
        && X.Eps_var.Set.subset free.free_eps allowed.free_eps)
    then fail "%s: an unknown escapes its scope" name

  let execute name env (cmd : _ Ast.command) =
    let loc = cmd.at in
    match cmd.it with
    | Ast.TyDef (eternality, defs) ->
        Gen.add_type_definitions ~loc env (eternality, defs)
    | Ast.OpSig signature -> Gen.add_operation_signature ~loc env signature
    | Ast.OpDefault (op, abs) ->
        check_scope name (Gen.generate_default env ~loc op abs) C.no_free;
        Gen.add_operation_default env op
          { performs = Ast.OpNameSet.empty; default_at = loc }
    | Ast.TopLet (x, e) ->
        let ty, constr = Gen.generate_top_let env ~loc x e in
        check_scope name constr (C.free_vars_ty ty);
        Gen.add_global env x ~defined_at:(Some loc)
          ~performs:Ast.OpNameSet.empty (assumed ())
    | Ast.TopDo c ->
        let comp_ty, constr = Gen.generate_run env ~loc c in
        check_scope name constr (C.free_vars_comp_ty comp_ty);
        env

  (* Each command is desugared and generated for in turn; a typing error in a
     definition leaves it assumed, as the loader does. *)
  (* Each command is desugared and generated for in turn; a typing error in a
     definition leaves it assumed, as the loader does. The result counts the
     typing errors. *)
  let run name ~expect_errors (desugarer, env) cmds =
    List.fold_left
      (fun ((desugarer, env), errors) cmd ->
        let desugarer, cmd = D.desugar_command desugarer cmd in
        match execute name env cmd with
        | env -> ((desugarer, env), errors)
        | exception Error.Error { kind = Diagnostic.Typing; _ }
          when expect_errors -> (
            match cmd.it with
            | Ast.TopLet (x, _) ->
                ( ( desugarer,
                    Gen.add_global env x ~defined_at:(Some cmd.at)
                      ~performs:Ast.OpNameSet.empty (assumed ()) ),
                  errors + 1 )
            | _ -> ((desugarer, env), errors + 1)))
      ((desugarer, env), 0)
      cmds

  let with_stdlib =
    lazy
      (fst
         (run "stdlib" ~expect_errors:false initial
            (parse_source Loader.stdlib_source)))

  (* Whether the file was rejected; the program declares the operations of the
     file, the standard library declaring none. *)
  let file path ~expect_errors =
    let name = Filename.basename path in
    match Parser.Lexer.read_file parse path with
    | cmds -> (
        let desugarer, env = Lazy.force with_stdlib in
        let env =
          Gen.declare_operations (Loader.declared_operations cmds) env
        in
        match run name ~expect_errors (desugarer, env) cmds with
        | _, errors -> errors > 0
        | exception Error.Error _ when expect_errors -> true)
    | exception Error.Error _ when expect_errors -> true
    | exception Grammar.Error when expect_errors -> true
end

let grade_module name =
  match List.assoc_opt name Grades.GradeRegistry.grade_modules with
  | Some g -> g
  | None -> failwith ("unknown grades " ^ name)

let check_file path grades =
  let name = Filename.basename path in
  let expect_errors = List.mem name malformed in
  let (module G) = grade_module grades in
  let module P = Program (G) in
  match P.file path ~expect_errors with
  | rejected ->
      if expect_errors && not rejected then
        fail "%s (%s): listed as malformed but accepted" name grades
  | exception Error.Error d ->
      fail "%s (%s): unexpected error: %s" name grades d.Diagnostic.message
  | exception e ->
      fail "%s (%s): unexpected exception %s" name grades (Printexc.to_string e)

(* The '.tpe' files under [dir], recursing into subdirectories (examples are
   grouped into some), each named entries sorted within its own directory. *)
let rec tpe_files dir =
  Sys.readdir dir |> Array.to_list |> List.sort String.compare
  |> List.concat_map (fun name ->
      let path = Filename.concat dir name in
      if Sys.is_directory path then tpe_files path
      else if Filename.check_suffix name ".tpe" then [ path ]
      else [])

let programs () =
  let root = "../.." in
  let table = case_table (Filename.concat root "tests/run_tests.t") in
  List.iter
    (fun path ->
      check_file path
        (Option.value (header_grades path) ~default:default_grades))
    (tpe_files (Filename.concat root "examples"));
  List.iter
    (fun path ->
      check_file path (grades_of_test table (Filename.basename path)))
    (tpe_files (Filename.concat root "tests"))

(* ------------------------------------------------------------------ *)
(* Constraints of small terms                                          *)
(* ------------------------------------------------------------------ *)

module Small = struct
  module G = Grades.TimeGrades.LowerBound
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)

  let pos = { Location.line = 1; column = 1; offset = 0 }
  let loc = { Location.filename = "test"; start = pos; stop = pos }
  let at it = Ast.located loc it
  let var x = at (Ast.Var x)
  let unit_expr = at (Ast.Tuple [])
  let return e = at (Ast.Return e)
  let pvar x = at (Ast.PVar x)
  let alpha = Ast.TyParam (Ast.TyParamModule.fresh "a")
  let because = Reason.because loc Reason.Top_computation
  let expect bound = { Gen.bound; because }
  let unit_eps = expect X.Eps.unit

  let expect_text name ~expected constr =
    let actual = C.to_string constr in
    if actual <> expected then
      fail "%s: expected@.%s@.got@.%s" name expected actual

  let rec atoms = function
    | C.And (c, d) -> atoms c @ atoms d
    | C.Exists (_, c) | C.Forall_eps (_, _, c) -> atoms c
    | c -> [ c ]

  let x = Ast.Variable.fresh "x"
  let y = Ast.Variable.fresh "y"
  let env_x = Gen.bind Gen.initial_env x alpha ~bound_at:loc

  (* A variable: the subtyping atom and the disjunction at the unit. *)
  let variable () =
    expect_text "variable" ~expected:"α <: α\nEt(α) ∨ 0 ≾ 0"
      (Gen.generate_expression env_x (var x) (expect alpha))

  (* The same variable behind the lock of a clause: the accumulated grade is
     the top, and the use a capture by the clause. *)
  let variable_in_clause () =
    let op = Ast.OpName.fresh "Op" in
    let clause = { Reason.op; signature_at = loc; case_at = loc } in
    let env =
      Gen.lock env_x
        {
          grade = X.Rho.top;
          at = loc;
          kind = Reason.Clause_lock clause;
          declared = None;
        }
    in
    let constr = Gen.generate_expression env (var x) (expect alpha) in
    expect_text "variable in clause" ~expected:"α <: α\nEt(α) ∨ 0 ≾ 0" constr;
    match atoms constr with
    | [ _; C.Eternal_or_unit ({ why = Reason.Op_case_capture _; _ }, _, _) ] ->
        ()
    | _ -> fail "variable in clause: expected a capture by the clause"

  (* [rec f y. return (x, f, y)]: the body behind the lock of the recursive
     function, [x] a capture by it, [y] used under no locks, and [f] owing no
     obligation. *)
  let recursive_body () =
    let f = Ast.Variable.fresh "f" in
    let body = return (at (Ast.Tuple [ var x; var f; var y ])) in
    let e = at (Ast.RecLambda (f, None, (pvar y, body))) in
    let obligations =
      List.filter_map
        (function
          | C.Eternal_or_unit ({ why; _ }, _, _) -> Some why | _ -> None)
        (atoms (Gen.generate_expression env_x e (expect alpha)))
    in
    match obligations with
    | [
     Reason.Rec_capture
       { var; f = f'; locks = [ { kind = Reason.Recursive_lock _; _ } ]; _ };
     Reason.Use_under_locks { var = var'; locks = []; _ };
    ]
      when Ast.Variable.compare var x = 0
           && Ast.Variable.compare f f' = 0
           && Ast.Variable.compare var' y = 0 ->
        ()
    | _ -> fail "recursive body: expected a capture of x by f and a use of y"

  (* [box 3 () as y in return y]: the payload under the lock [⟨3⟩], the
     binding at the boxed type. *)
  let box () =
    let c =
      at
        (Ast.Box
           ( Ast.RhoConst (G.of_delay 3, None),
             unit_expr,
             (pvar y, return (var y)) ))
    in
    expect_text "box"
      ~expected:
        "∃α.\n\
        \  unit <: α\n\
        \  α <: unit\n\
        \  [3]α <: [3]unit\n\
        \  Et([3]α) ∨ 0 ≾ 0\n\
        \  0 ≾ 0"
      (Gen.generate_computation Gen.initial_env c
         (expect (Ast.TyBox (X.Rho.of_delay 3, Ast.TyTuple [])))
         unit_eps)

  (* [let y = delay 2 (return ()) in return x]: [x] is used under the lock of
     the bound computation's effect. *)
  let sequencing () =
    let bound = at (Ast.Delay (Grades.Rational.of_int 2, return unit_expr)) in
    let c = at (Ast.Do (bound, (pvar y, return (var x)))) in
    let constr = Gen.generate_computation env_x c (expect alpha) unit_eps in
    let locks =
      List.filter_map
        (function
          | C.Eternal_or_unit ({ why = Reason.Use_under_locks u; _ }, _, rho) ->
              Some (u.locks, rho)
          | _ -> None)
        (atoms constr)
    in
    match locks with
    | [ ([ { kind = Reason.Delayed q; _ } ], X.Rho_map (X.Eps_var _)) ]
      when Grades.Rational.to_int q = Some 2 ->
        ()
    | _ ->
        fail "sequencing: expected the lock of the bound effect, got@.%s"
          (C.to_string constr)

  (* [unbox x as y in return y] for [x : [3]nat] bound before [delay 2]: the
     box type is pinned and the accumulated grade below its grade. *)
  let unbox () =
    let boxed =
      Ast.TyBox (X.Rho.of_delay 3, Ast.TyConst Language.Const.NatTy)
    in
    let env =
      Gen.lock
        (Gen.bind Gen.initial_env x boxed ~bound_at:loc)
        {
          grade = X.Rho.of_delay 2;
          at = loc;
          kind = Reason.Delayed (Grades.Rational.of_int 2);
          declared = None;
        }
    in
    let c = at (Ast.Unbox (var x, (pvar y, return (var y)))) in
    expect_text "unbox"
      ~expected:
        "∃α ρ₀.\n\
        \  [3]nat <: [ρ₀]α\n\
        \  [ρ₀]α <: [3]nat\n\
        \  2 ≾ ρ₀\n\
        \  α <: β\n\
        \  Et(α) ∨ 0 ≾ 0\n\
        \  0 ≾ 0"
      (Gen.generate_computation env c (expect alpha) unit_eps)

  (* A handler with a clause for [Op] using [x] from outside: the clause is
     generated under [∀ε] and the lock [⟨⊤⟩], its continuation boxed at the
     operation's grade. *)
  let handler_clause () =
    let op = Ast.OpName.fresh "Op" in
    let env =
      Gen.add_operation_signature ~loc env_x
        ( op,
          Ast.TyTuple [],
          Ast.TyTuple [],
          Ast.EpsConst (G.of_delay 2, None),
          None )
    in
    let k = Ast.Variable.fresh "k" in
    let u = Ast.Variable.fresh "u" in
    let z = Ast.Variable.fresh "z" in
    let resume =
      at (Ast.Unbox (var k, (pvar u, at (Ast.Apply (var u, unit_expr)))))
    in
    let body = at (Ast.Do (resume, (pvar z, return (var x)))) in
    let clause = (at (Ast.PTuple [ pvar y; pvar k ]), body) in
    let ret = (pvar y, return (var y)) in
    let h = at (Ast.Handler (ret, Ast.OpNameMap.singleton op clause)) in
    let constr = Gen.generate_expression env h (expect alpha) in
    let rec clauses = function
      | C.And (c, d) -> clauses c @ clauses d
      | C.Exists (_, c) -> clauses c
      | C.Forall_eps (rigid, origin, c) -> [ (rigid, origin, c) ]
      | _ -> []
    in
    match clauses constr with
    | [ (rigid, origin, body) ] ->
        if origin.Reason.continuation <> Some k then
          fail "handler clause: the continuation is not named";
        let captures =
          List.filter
            (function
              | C.Eternal_or_unit
                  ( {
                      why =
                        Reason.Op_case_capture
                          {
                            locks =
                              {
                                grade = X.Rho_const top;
                                kind = Clause_lock _;
                                _;
                              }
                              :: _;
                            _;
                          };
                      _;
                    },
                    _,
                    _ ) ->
                  G.equal
                    {
                      running_time =
                        (fun _ ->
                          ( Grade.Closed Grades.Rational.zero,
                            Grade.Closed Grades.Rational.zero ));
                      operations = [];
                    }
                    top G.top
              | _ -> false)
            (atoms body)
        in
        if List.length captures <> 1 then
          fail "handler clause: expected one capture of x at ⊤, got@.%s"
            (C.to_string constr);
        let continuation_boxed =
          List.exists
            (function
              | C.Sub
                  ( _,
                    Ast.TyBox
                      ( X.Rho_const _,
                        Ast.TyArrow (_, Ast.CompTy (_, X.Eps_var e)) ),
                    _ ) ->
                  X.Eps_var.equal e rigid
              | _ -> false)
            (atoms body)
        in
        let effect_bounded =
          List.exists
            (function
              | C.Eps_leq (_, _, X.Eps_mul (X.Eps_const _, X.Eps_var e)) ->
                  X.Eps_var.equal e rigid
              | _ -> false)
            (atoms body)
        in
        if not (continuation_boxed && effect_bounded) then
          fail "handler clause: unexpected clause@.%s" (C.to_string constr)
    | _ -> fail "handler clause: expected one rigid scope"

  (* Instances of a qualified scheme rename its bound unknowns apart and owe
     its qualifier for the use. *)
  let instance () =
    let a = Ast.TyParamModule.fresh "a" in
    let e = X.Eps_var.fresh_indexed () in
    let bound_e = X.Eps_var.fresh_indexed () in
    let qualifier =
      C.Exists
        ( { C.no_vars with eps_vars = [ bound_e ] },
          C.Eps_leq (because, X.Eps.var bound_e, X.Eps.var e) )
    in
    let scheme =
      {
        C.ty_params = [ a ];
        rho_params = [];
        eps_params = [ e ];
        qualifier;
        ty = Ast.TyArrow (Ast.TyParam a, Ast.CompTy (Ast.TyParam a, X.Eps.var e));
      }
    in
    let f = Ast.Variable.fresh "f" in
    let env =
      Gen.add_global Gen.initial_env f ~defined_at:(Some loc)
        ~performs:Ast.OpNameSet.empty scheme
    in
    let use () = Gen.generate_expression env (var f) (expect alpha) in
    let bound_of = function
      | C.And (_, C.Exists ({ eps_vars = [ v ]; _ }, C.Eps_leq (r, _, _))) ->
          (match r.Reason.why with
          | Reason.Instance_of _ -> ()
          | _ -> fail "instance: the qualifier's reason is not an instance");
          Some v
      | _ -> None
    in
    match (bound_of (use ()), bound_of (use ())) with
    | Some v, Some v' ->
        if X.Eps_var.equal v v' || X.Eps_var.equal v bound_e then
          fail "instance: bound unknowns are not renamed apart"
    | _ -> fail "instance: unexpected instance@.%s" (C.to_string (use ()))

  let run () =
    variable ();
    variable_in_clause ();
    recursive_body ();
    box ();
    sequencing ();
    unbox ();
    handler_clause ();
    instance ()
end

let () =
  programs ();
  Small.run ();
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
