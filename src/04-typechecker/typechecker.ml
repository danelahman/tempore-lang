(* The typechecker: type inference over a grade system, with diagnostics. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Error = Utils.Error
module Location = Utils.Location

type function_effect =
  | Not_a_function
  | Effect_variable
  | Effect of { grade : string; durations : Grades.Grade.durations }

module Make (GS : Grades.GradeSystem.S) = struct
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
      envs = P.both (fun env -> Gen.add_primitive env x scheme) state.envs;
      definitions = (x, scheme) :: state.definitions;
    }

  let declare_operations declarations state =
    {
      state with
      envs = P.both (Gen.declare_operations declarations) state.envs;
    }

  (* The type and the constraint of a command that has one, generated afresh;
     the type of a run or a default is the unit type, which {!P.check} does not
     read. *)
  let constraint_of env (cmd : command) =
    let loc = cmd.at in
    match cmd.it with
    | Ast.TopLet (x, e) -> Some (Gen.generate_top_let env ~loc x e)
    | Ast.TopDo c -> Some (Ast.TyTuple [], snd (Gen.generate_run env ~loc c))
    | Ast.OpDefault (op, abs) ->
        Some (Ast.TyTuple [], Gen.generate_default env ~loc op abs)
    | Ast.TyDef _ | Ast.OpSig _ -> None

  (* The failure of the constraint of a command [cmd], solved and its
     qualifier checked as the command's is, with what it is explained
     against: the solution in the latter case, the provenance of a failed
     expansion in the former. *)
  let failure cmd context ty constr =
    let source solution mismatch =
      { E.context; constr = Some constr; solution; mismatch }
    in
    match S.solve_traced context constr with
    | S.Solved solution, _ -> (
        match P.check cmd context ty solution with
        | Ok () -> None
        | Error failure -> Some (source (Some solution) None, P.Refuted failure)
        )
    | S.Refuted failure, mismatch ->
        Some (source None mismatch, P.Refuted failure)
    | S.Stuck stuck, mismatch -> Some (source None mismatch, P.Stuck stuck)

  let is_refutation = function
    | _, P.Refuted _ -> true
    | _, (P.Malformed _ | P.Stuck _) -> false

  (* The failures of a constraint in the order they are found: its failure,
     then, after a refutation, the refutations of the constraint without the
     atoms it refutes. *)
  let rec failures cmd context ty constr =
    match failure cmd context ty constr with
    | None -> []
    | Some ((_, P.Refuted refuted) as found) ->
        let rest =
          match E.without_refuted refuted constr with
          | Some constr ->
              List.filter is_refutation (failures cmd context ty constr)
          | None -> []
        in
        found :: rest
    | Some found -> [ found ]

  (* The command whose conditions a diagnostic names. *)
  let subject (cmd : command) =
    match cmd.it with
    | Ast.OpDefault _ -> Some "this default implementation"
    | Ast.TopDo _ | Ast.TopLet _ | Ast.TyDef _ | Ast.OpSig _ -> None

  let diagnose cmd source = function
    | P.Malformed d -> d
    | P.Refuted failure -> E.refuted ?subject:(subject cmd) source failure
    | P.Stuck stuck -> E.stuck source stuck

  (* The point at which a failing requirement is met in reading order: for
     an effect bound, once the computation it bounds has been read, at the end
     of the place its diagnostic points at; for any other requirement, where
     that place begins. *)
  let met_at error (d : Diagnostic.t) =
    Option.map
      (fun (at : Location.t) ->
        match error with
        | P.Refuted failure when E.refutes_effect failure ->
            { at with start = at.stop }
        | P.Refuted _ | P.Stuck _ | P.Malformed _ -> { at with stop = at.start })
      d.primary

  (* Whether a point is read before another; no point is read last. *)
  let read_before point point' =
    match (point, point') with
    | Some at, Some at' -> Location.compare at at' < 0
    | Some _, None -> true
    | None, (Some _ | None) -> false

  (* The diagnostic of the failing requirement met first, the first found
     among those met at one point. *)
  let first_met cmd found =
    let met (source, error) =
      let d = diagnose cmd source error in
      (met_at error d, d)
    in
    let earlier ((point, _) as first) ((point', _) as next) =
      if read_before point' point then next else first
    in
    match List.map met found with
    | [] -> None
    | first :: rest -> Some (snd (List.fold_left earlier first rest))

  (* A rejection explained against the command's constraint generated afresh
     over the unsimplified schemes of the definitions, whose unknowns the
     failures of solving it again mention: the failing requirement met first
     in reading order, explained against the constraint it is found in;
     against the failure alone where solving again does not reproduce it, or
     where generating it again raises a typing error. *)
  let explain (envs : P.envs) (cmd : command) error =
    let env = envs.unsimplified in
    let context = P.context env in
    let found =
      match constraint_of env cmd with
      | Some (ty, constr) -> failures cmd context ty constr
      | None -> []
      | exception Error.Error { kind = Diagnostic.Typing; _ } -> []
    in
    match first_met cmd found with
    | Some d -> d
    | None ->
        diagnose cmd
          { E.context; constr = None; solution = None; mismatch = None }
          error

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

  (* The running times of the operations the program declares. *)
  let running_times state = Gen.running_times state.envs.reported

  (* The names of a scheme, the unit effect decided under the running times of
     the operations the program declares. *)
  let names state = C.names ~bounds:(running_times state) ()

  let print_scheme state scheme ppf =
    C.print_scheme ~names:(names state) scheme ppf

  let scheme_layout state scheme = C.scheme_layout ~names:(names state) scheme

  let function_effect state (scheme : scheme) =
    match scheme.ty with
    | Ast.TyArrow (_, Ast.CompTy (_, eps)) -> (
        match X.Eps.value eps with
        | None -> Effect_variable
        | Some grade ->
            Effect
              {
                grade = GS.E.show grade;
                durations =
                  (let bounds = running_times state in
                   match GS.E.duration_bounds bounds grade with
                   | Some (lo, hi) -> Grades.Grade.Duration_interval (lo, hi)
                   | None when GS.E.duration_bounds bounds GS.E.one = None ->
                       Grades.Grade.Untimed
                   | None -> Grades.Grade.Undetermined);
              })
    | _ -> Not_a_function
end
