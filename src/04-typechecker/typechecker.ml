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
    env : Gen.env;
    definitions : (Ast.variable * scheme) list;
        (** the primitives and top-level definitions, newest first *)
  }

  type recovery = Continue of state | Stop

  let initial_state = { env = Gen.initial_env; definitions = [] }

  let load_primitive state x prim =
    let scheme = Primitive_schemes.scheme prim in
    {
      env = Gen.add_global state.env x ~defined_at:None scheme;
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
     in the latter case. *)
  let failure context constr =
    match S.solve context constr with
    | S.Solved solution -> (
        match S.satisfiable context solution with
        | Ok () -> None
        | Error failure -> Some (P.Refuted failure, Some solution.hyps))
    | S.Refuted failure -> Some (P.Refuted failure, None)
    | S.Stuck stuck -> Some (P.Stuck stuck, None)

  (* A rejection explained against the command's constraint generated afresh,
     whose unknowns the failure of solving it again mentions; against the
     failure alone where that does not reproduce it. *)
  let explain env (cmd : command) error =
    let context = P.context ~loc:cmd.at env in
    let replayed =
      match constraint_of env cmd with
      | Some constr ->
          Option.map
            (fun (error, hyps) -> (Some constr, hyps, error))
            (failure context constr)
      | None -> None
      | exception Error.Error _ -> None
    in
    let constr, hyps, error =
      Option.value replayed ~default:(None, None, error)
    in
    let source = { E.context; constr; hyps } in
    match error with
    | P.Malformed d -> d
    | P.Refuted failure -> E.refuted source failure
    | P.Stuck stuck -> E.stuck source stuck

  (* The diagnostic of a rejected command, pinned to the command when it has
     no location of its own. *)
  let diagnostic env (cmd : command) error =
    let d =
      match error with
      | P.Malformed d -> d
      | P.Refuted _ | P.Stuck _ -> explain env cmd error
    in
    match d.Diagnostic.primary with
    | None -> { d with primary = Some cmd.at }
    | Some _ -> d

  let check state (cmd : command) =
    match P.execute state.env cmd with
    | env, { outcome = P.Defined (x, scheme); _ }, _ ->
        Ok { env; definitions = (x, scheme) :: state.definitions }
    | env, { outcome = P.Accepted; _ }, _ -> Ok { state with env }
    | env, { outcome = P.Rejected error; _ }, next ->
        let recovery =
          match next with
          | P.Continue -> Continue { state with env }
          | P.Stop -> Stop
        in
        Error (diagnostic state.env cmd error, recovery)

  let definitions state = List.rev state.definitions
  let print_scheme scheme ppf = C.print_scheme scheme ppf
end
