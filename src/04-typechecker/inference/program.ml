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

  let context ~loc env : S.context =
    {
      bounds = Gen.cost_model ~loc env;
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

  let check (cmd : command) =
    match cmd.it with
    | Ast.TopDo _ | Ast.OpDefault _ -> S.established
    | Ast.TyDef _ | Ast.OpSig _ | Ast.TopLet _ -> S.satisfiable

  (* The constraint of a command [cmd] solved and its qualifier checked: its
     solution, or why it has none. *)
  let solved (cmd : command) env constr =
    let context = context ~loc:cmd.at env in
    match S.solve context constr with
    | S.Solved solution ->
        Result.map_error
          (fun failure -> Refuted failure)
          (Result.map (fun () -> solution) (check cmd context solution))
    | S.Refuted failure -> Error (Refuted failure)
    | S.Stuck stuck -> Error (Stuck stuck)

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

  let execute_both envs (cmd : command) =
    let loc = cmd.at in
    let verdict outcome = { at = loc; outcome } in
    let env = envs.reported in
    match cmd.it with
    | Ast.TyDef (eternality, defs) -> (
        match
          attempt (fun () ->
              Ok
                (both
                   (fun env ->
                     Gen.add_type_definitions ~loc env (eternality, defs))
                   envs))
        with
        | Ok envs -> (envs, verdict Accepted, Continue)
        | Error e -> (envs, verdict (Rejected e), Stop))
    | Ast.OpSig signature -> (
        match
          attempt (fun () ->
              Ok
                (both
                   (fun env -> Gen.add_operation_signature ~loc env signature)
                   envs))
        with
        | Ok envs -> (envs, verdict Accepted, Continue)
        | Error e -> (envs, verdict (Rejected e), Stop))
    | Ast.OpDefault (op, abs) -> (
        let performed =
          DefaultGraph.abstraction ~global:(Gen.global_performs env) abs
        in
        match
          attempt (fun () ->
              solved cmd env (Gen.generate_default env ~loc op abs)
              |> terminating (fun () ->
                  Termination.check_abstraction abs;
                  DefaultGraph.check_default
                    ~default:(Gen.find_operation_default env)
                    ~loc op performed;
                  Exhaustiveness.check_abstraction
                    ~constructors:(Gen.datatype_constructors env)
                    abs))
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
        | Error e -> (envs, verdict (Rejected e), Continue))
    | Ast.TopLet (x, e) -> (
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
              Gen.add_global envs.unsimplified x ~defined_at:(Some loc)
                ~performs unsimplified;
          }
        in
        match
          attempt (fun () ->
              let ty, constr = Gen.generate_top_let env ~loc x e in
              Result.map
                (fun solution ->
                  (S.generalise ty solution, S.unsimplified ty solution))
                (solved cmd env constr
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
            (add scheme scheme, verdict (Rejected e), Continue))
    | Ast.TopDo c -> (
        match
          attempt (fun () ->
              let _, constr = Gen.generate_run env ~loc c in
              solved cmd env constr
              |> terminating (fun () ->
                  Termination.check_computation c;
                  Exhaustiveness.check_computation
                    ~constructors:(Gen.datatype_constructors env)
                    c))
        with
        | Ok _ -> (envs, verdict Accepted, Continue)
        | Error e -> (envs, verdict (Rejected e), Continue))

  let execute env cmd =
    let envs, verdict, next =
      execute_both { reported = env; unsimplified = env } cmd
    in
    (envs.reported, verdict, next)

  let print_outcome outcome ppf =
    match outcome with
    | Accepted -> Format.pp_print_string ppf "accepted"
    | Defined (x, scheme) ->
        Format.fprintf ppf "@[<hov 2>%t :@ %t@]" (Ast.Variable.print x)
          (C.print_scheme scheme)
    | Rejected (Malformed d) ->
        Format.fprintf ppf "rejected: %s" d.Diagnostic.message
    | Rejected (Refuted failure) ->
        Format.fprintf ppf "rejected: %t" (R.print_failure failure)
    | Rejected (Stuck stuck) ->
        Format.fprintf ppf "rejected: %t" (S.print_outcome (S.Stuck stuck))

  let execute_all env cmds =
    let rec go env verdicts = function
      | [] -> (env, List.rev verdicts)
      | cmd :: cmds -> (
          match execute env cmd with
          | env, verdict, Continue -> go env (verdict :: verdicts) cmds
          | env, verdict, Stop -> (env, List.rev (verdict :: verdicts)))
    in
    go env [] cmds
end
