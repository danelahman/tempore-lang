(* Type inference over whole programs. *)

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
        match
          attempt (fun () ->
              solved ~loc env (Gen.generate_default env ~loc op abs))
        with
        | Ok _ ->
            ( both (fun env -> Gen.add_operation_default env op) envs,
              verdict Accepted,
              Continue )
        | Error e -> (envs, verdict (Rejected e), Continue))
    | Ast.TopLet (x, e) -> (
        let add reported unsimplified =
          {
            reported =
              Gen.add_global envs.reported x ~defined_at:(Some loc) reported;
            unsimplified =
              Gen.add_global envs.unsimplified x ~defined_at:(Some loc)
                unsimplified;
          }
        in
        match
          attempt (fun () ->
              let ty, constr = Gen.generate_top_let env ~loc x e in
              Result.map
                (fun solution ->
                  (S.generalise ty solution, S.unsimplified ty solution))
                (solved ~loc env constr))
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
              solved ~loc env constr)
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
