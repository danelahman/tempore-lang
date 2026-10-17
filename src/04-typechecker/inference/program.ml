(* Type inference over whole programs. Top-level definitions are generalised
   to constrained schemes as in HM(X) (Odersky, Sulzmann and Wehr, TAPOS
   1999); local definitions are not (Vytiniotis, Peyton Jones and Schrijvers,
   TLDI 2010). *)

module Ast = Language.Ast
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module StringMap = Utils.StringMap

module Make (C : Constraint.S) = struct
  module Gen = Generate.Make (C)
  module S = Solver.Make (C)
  module R = Residual.Make (C)

  type env = Gen.env
  type command = (Gen.program_rho, Gen.program_eps) Ast.command

  type error =
    | Malformed of Diagnostic.t
    | Refuted of S.failure
    | Stuck of S.stuck

  type outcome =
    | Accepted
    | Defined of Ast.variable * C.scheme
    | Rejected of error

  type verdict = { at : Location.t; outcome : outcome }
  type next = Continue | Stop

  let context env : S.context =
    {
      bounds = Gen.running_times env;
      find_definition =
        (fun name ->
          Option.map
            (fun (d : Gen.ty_definition) -> (d.params, d.definition))
            (Gen.find_type_definition env name));
      is_noneternal = Gen.is_noneternal env;
    }

  (* The scheme [∀α. α] of a rejected definition. *)
  let assumed () =
    let a = Ast.TyParamModule.fresh "assumed" in
    { (C.monomorphic (Ast.TyParam a)) with C.ty_params = [ a ] }

  (* The scheme of a top-level definition of type [ty]: its qualifier
     searched for a closed instance, then reported. *)
  let reported context ty solution =
    Result.bind (S.satisfiable context solution) (fun () ->
        S.generalise ty solution)

  let check (cmd : command) context ty solution =
    match cmd.it with
    | Ast.TopDo _ | Ast.OpDefault _ -> S.established context solution
    | Ast.TopLet _ -> Result.map ignore (reported context ty solution)
    | Ast.TyDef _ | Ast.OpSig _ -> S.satisfiable context solution

  (* The constraint of a command solved and its solution checked by [check]:
     what [check] gives, or why the constraint has no solution. *)
  let solved check env constr =
    let context = context env in
    match S.solve context constr with
    | S.Solved solution ->
        Result.map_error
          (fun failure -> Refuted failure)
          (check context solution)
    | S.Refuted failure -> Error (Refuted failure)
    | S.Stuck stuck -> Error (Stuck stuck)

  (* [check_duration ~loc env op abs] checks the duration of the default
     implementation [abs] of [op] at [loc] against the running-time bounds of
     [op], by the effect of its reported scheme; it is skipped where that effect
     is not a constant or the constraint has no solution. *)
  let check_duration ~loc env op abs =
    if C.X.GS.E.needs_op_bounds then
      let ty, constr = Gen.generate_default_effect env ~loc op abs in
      match S.solve (context env) constr with
      | S.Solved solution -> (
          match S.generalise ty solution with
          | Ok
              { C.ty = Ast.TyArrow (_, Ast.CompTy (_, C.X.Eps_const grade)); _ }
            ->
              Gen.check_default_duration env ~loc op grade
          | Ok _ | Error _ -> ())
      | S.Refuted _ | S.Stuck _ -> ()

  (* [terminating check result] is [result] once [check ()] has accepted the
     recursive functions, the default and the matches of a solved command. *)
  let terminating check =
    Result.map (fun solution ->
        check ();
        solution)

  (* [attempt f] is [f ()], a typing error it raises being [Malformed]. *)
  let attempt f =
    match f () with
    | result -> result
    | exception Error.Error ({ kind = Diagnostic.Typing; _ } as d) ->
        Error (Malformed d)

  type envs = { reported : env; unsimplified : env }

  let both f envs =
    { reported = f envs.reported; unsimplified = f envs.unsimplified }

  (* A declaration extends both environments by [extend]; a rejected one
     stops the program. *)
  let declaration verdict envs extend =
    match attempt (fun () -> Ok (both extend envs)) with
    | Ok envs -> (envs, verdict Accepted, Continue)
    | Error e -> (envs, verdict (Rejected e), Stop)

  (* A default implementation [abs] of [op], recorded with the operations it
     may perform once accepted. *)
  let default verdict envs (cmd : command) op abs =
    let loc = cmd.at and env = envs.reported in
    let performed =
      DefaultGraph.abstraction ~global:(Gen.global_performs env) abs
    in
    match
      attempt (fun () ->
          solved S.established env (Gen.generate_default env ~loc op abs)
          |> terminating (fun () ->
              Termination.check_abstraction abs;
              DefaultGraph.check_default
                ~default:(Gen.find_operation_default env)
                ~loc op performed;
              Exhaustiveness.check_abstraction
                ~constructors:(Gen.datatype_constructors env)
                abs;
              check_duration ~loc env op abs))
    with
    | Ok _ ->
        let default =
          {
            DefaultGraph.performs = DefaultGraph.operations performed;
            default_at = loc;
          }
        in
        ( both (fun env -> Gen.add_operation_default env op default) envs,
          verdict Accepted,
          Continue )
    | Error e -> (envs, verdict (Rejected e), Continue)

  (* A top-level definition [let x = e], of its generalised scheme in the
     reported environment and of its unsimplified one in the other; a rejected
     one is assumed of the scheme [∀α. α]. *)
  let top_let verdict envs (cmd : command) x e =
    let loc = cmd.at and env = envs.reported in
    let performs =
      DefaultGraph.operations
        (DefaultGraph.expression ~global:(Gen.global_performs env) e)
    in
    let add reported unsimplified =
      {
        reported =
          Gen.add_global envs.reported x ~defined_at:(Some loc) ~performs
            reported;
        unsimplified =
          Gen.add_global envs.unsimplified x ~defined_at:(Some loc) ~performs
            unsimplified;
      }
    in
    match
      attempt (fun () ->
          let ty, constr = Gen.generate_top_let env ~loc x e in
          Result.map
            (fun (scheme, solution) -> (scheme, S.unsimplified ty solution))
            (solved
               (fun context solution ->
                 Result.map
                   (fun scheme -> (scheme, solution))
                   (reported context ty solution))
               env constr
            |> terminating (fun () ->
                Termination.check_expression e;
                Exhaustiveness.check_expression
                  ~constructors:(Gen.datatype_constructors env)
                  e)))
    with
    | Ok (scheme, unsimplified) ->
        (add scheme unsimplified, verdict (Defined (x, scheme)), Continue)
    | Error e ->
        let scheme = assumed () in
        (add scheme scheme, verdict (Rejected e), Continue)

  (* A run [run c]. *)
  let run verdict envs (cmd : command) c =
    let loc = cmd.at and env = envs.reported in
    match
      attempt (fun () ->
          let _, constr = Gen.generate_run env ~loc c in
          solved S.established env constr
          |> terminating (fun () ->
              Termination.check_computation c;
              Exhaustiveness.check_computation
                ~constructors:(Gen.datatype_constructors env)
                c))
    with
    | Ok _ -> (envs, verdict Accepted, Continue)
    | Error e -> (envs, verdict (Rejected e), Continue)

  let execute_both envs (cmd : command) =
    let loc = cmd.at in
    let verdict outcome = { at = loc; outcome } in
    match cmd.it with
    | Ast.TyDef (eternality, defs) ->
        declaration verdict envs (fun env ->
            Gen.add_type_definitions ~loc env (eternality, defs))
    | Ast.OpSig signature ->
        declaration verdict envs (fun env ->
            Gen.add_operation_signature ~loc env signature)
    | Ast.OpDefault (op, abs) -> default verdict envs cmd op abs
    | Ast.TopLet (x, e) -> top_let verdict envs cmd x e
    | Ast.TopDo c -> run verdict envs cmd c

  let execute env cmd =
    let envs, verdict, next =
      execute_both { reported = env; unsimplified = env } cmd
    in
    (envs.reported, verdict, next)
end
