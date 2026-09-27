(* The typechecker: type inference over a grade system, with diagnostics. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Error = Utils.Error

module Make (GS : Language.GradeSystem.S) = struct
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module S = Inference.Solver.Make (C)
  module P = Inference.Program.Make (C)
  module E = Explain.Make (C)
  module Primitive_schemes = Inference.PrimitiveSchemes.Make (C)

  type scheme = C.scheme
  type command = P.command

  type state = {
    envs : P.envs;
    definitions : (Ast.variable * scheme) list;
        (** the primitives and top-level definitions, newest first *)
  }

  type recovery = Continue of state | Stop

  let initial_state =
    {
      envs = { reported = Gen.initial_env; unsimplified = Gen.initial_env };
      definitions = [];
    }

  let load_primitive state x prim =
    let scheme = Primitive_schemes.scheme prim in
    {
      envs =
        P.both
          (fun env -> Gen.add_global env x ~defined_at:None scheme)
          state.envs;
      definitions = (x, scheme) :: state.definitions;
    }

  (* The constraint of a command that has one, generated afresh. *)
  let constraint_of env (cmd : command) =
    let loc = cmd.at in
    match cmd.it with
    | Ast.TopLet (x, e) -> Some (snd (Gen.generate_top_let env ~loc x e))
    | Ast.TopDo c -> Some (snd (Gen.generate_run env ~loc c))
    | Ast.OpDefault (op, abs) -> Some (Gen.generate_default env ~loc op abs)
    | Ast.TyDef _ | Ast.OpSig _ -> None

  (* The failure of a constraint, solved and its qualifier searched for a
     closed instance as a command's is, with the hypotheses of the solution
     in the latter case and the provenance of a failed expansion in the
     former. *)
  let failure context constr =
    match S.solve_traced context constr with
    | S.Solved solution, _ -> (
        match S.satisfiable context solution with
        | Ok () -> None
        | Error failure -> Some (P.Refuted failure, Some solution.hyps, None))
    | S.Refuted failure, mismatch -> Some (P.Refuted failure, None, mismatch)
    | S.Stuck stuck, mismatch -> Some (P.Stuck stuck, None, mismatch)

  (* A rejection explained against the command's constraint generated afresh
     over the unsimplified schemes of the definitions, whose unknowns the
     failure of solving it again mentions; against the failure alone where
     that does not reproduce it. *)
  let explain (envs : P.envs) (cmd : command) error =
    let env = envs.unsimplified in
    let context = P.context ~loc:cmd.at env in
    let replayed =
      match constraint_of env cmd with
      | Some constr ->
          Option.map
            (fun (error, hyps, mismatch) ->
              (Some constr, hyps, mismatch, error))
            (failure context constr)
      | None -> None
      | exception Error.Error _ -> None
    in
    let constr, hyps, mismatch, error =
      Option.value replayed ~default:(None, None, None, error)
    in
    let source = { E.context; constr; hyps; mismatch } in
    match error with
    | P.Malformed d -> d
    | P.Refuted failure -> E.refuted source failure
    | P.Stuck stuck -> E.stuck source stuck

  (* The diagnostic of a rejected command, pinned to the command when it has
     no location of its own. *)
  let diagnostic envs (cmd : command) error =
    let d =
      match error with
      | P.Malformed d -> d
      | P.Refuted _ | P.Stuck _ -> explain envs cmd error
    in
    match d.Diagnostic.primary with
    | None -> { d with primary = Some cmd.at }
    | Some _ -> d

  let check state (cmd : command) =
    match P.execute_both state.envs cmd with
    | envs, { outcome = P.Defined (x, scheme); _ }, _ ->
        Ok { envs; definitions = (x, scheme) :: state.definitions }
    | envs, { outcome = P.Accepted; _ }, _ -> Ok { state with envs }
    | envs, { outcome = P.Rejected error; _ }, next ->
        let recovery =
          match next with
          | P.Continue -> Continue { state with envs }
          | P.Stop -> Stop
        in
        Error (diagnostic state.envs cmd error, recovery)

  let definitions state = List.rev state.definitions
  let print_scheme scheme ppf = C.print_scheme scheme ppf
end
