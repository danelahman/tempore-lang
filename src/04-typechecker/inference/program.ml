(* Type inference over whole programs. *)

module Ast = Language.Ast
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module StringMap = Utils.StringMap

module Make (C : Constraint.S) = struct
  module Gen = Generate.Make (C)
  module S = Solver.Make (C)

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
    let op_bounds = Gen.op_bounds env in
    {
      bounds =
        (fun event ->
          match StringMap.find_opt event op_bounds with
          | Some bounds -> bounds
          | None ->
              Error.typing ~loc
                "Unknown event `%s`; the events of a grade must be declared \
                 operations"
                event);
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

  (* The constraint of a command solved and its qualifier searched for a
     closed instance: its solution, or why it has none. *)
  let solved ~loc env constr =
    let context = context ~loc env in
    match S.solve context constr with
    | S.Solved solution ->
        Result.map_error
          (fun failure -> Refuted failure)
          (Result.map (fun () -> solution) (S.satisfiable context solution))
    | S.Refuted failure -> Error (Refuted failure)
    | S.Stuck stuck -> Error (Stuck stuck)

  (* [attempt f] is [f ()], a typing error it raises being [Malformed]. *)
  let attempt f =
    match f () with
    | result -> result
    | exception Error.Error ({ kind = Diagnostic.Typing; _ } as d) ->
        Error (Malformed d)

  let execute env (cmd : command) =
    let loc = cmd.at in
    let verdict outcome = { at = loc; outcome } in
    match cmd.it with
    | Ast.TyDef (eternality, defs) -> (
        match
          attempt (fun () ->
              Ok (Gen.add_type_definitions ~loc env (eternality, defs)))
        with
        | Ok env -> (env, verdict Accepted, Continue)
        | Error e -> (env, verdict (Rejected e), Stop))
    | Ast.OpSig signature -> (
        match
          attempt (fun () ->
              Ok (Gen.add_operation_signature ~loc env signature))
        with
        | Ok env -> (env, verdict Accepted, Continue)
        | Error e -> (env, verdict (Rejected e), Stop))
    | Ast.OpDefault (op, abs) -> (
        match
          attempt (fun () ->
              solved ~loc env (Gen.generate_default env ~loc op abs))
        with
        | Ok _ -> (Gen.add_operation_default env op, verdict Accepted, Continue)
        | Error e -> (env, verdict (Rejected e), Continue))
    | Ast.TopLet (x, e) -> (
        match
          attempt (fun () ->
              let ty, constr = Gen.generate_top_let env ~loc x e in
              Result.map (S.generalise ty) (solved ~loc env constr))
        with
        | Ok scheme ->
            ( Gen.add_global env x ~defined_at:(Some loc) scheme,
              verdict (Defined (x, scheme)),
              Continue )
        | Error e ->
            ( Gen.add_global env x ~defined_at:(Some loc) (assumed ()),
              verdict (Rejected e),
              Continue ))
    | Ast.TopDo c -> (
        match
          attempt (fun () ->
              let _, constr = Gen.generate_run env ~loc c in
              solved ~loc env constr)
        with
        | Ok _ -> (env, verdict Accepted, Continue)
        | Error e -> (env, verdict (Rejected e), Continue))

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
