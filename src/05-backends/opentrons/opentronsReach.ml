module Ast = Language.Ast
module VariableSet = Set.Make (Ast.Variable)

let rec pattern_variables (p : _ Ast.pattern) =
  match p.it with
  | Ast.PVar x -> VariableSet.singleton x
  | Ast.PAs (p, x) -> VariableSet.add x (pattern_variables p)
  | Ast.PAnnotated (p, _) | Ast.PVariant (_, Some p) | Ast.PSucc (p, _) ->
      pattern_variables p
  | Ast.PTuple ps ->
      List.fold_left
        (fun xs p -> VariableSet.union xs (pattern_variables p))
        VariableSet.empty ps
  | Ast.PVariant (_, None) | Ast.PConst _ | Ast.PNonbinding -> VariableSet.empty

let unions f xs =
  List.fold_left (fun acc x -> VariableSet.union acc (f x)) VariableSet.empty xs

let rec free_in_expression (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> VariableSet.singleton x
  | Ast.Const _ -> VariableSet.empty
  | Ast.Annotated (e, _) -> free_in_expression e
  | Ast.Tuple es -> unions free_in_expression es
  | Ast.Variant (_, e) ->
      Option.fold ~none:VariableSet.empty ~some:free_in_expression e
  | Ast.Lambda abs | Ast.PureLambda abs -> free_in_abstraction abs
  | Ast.RecLambda (f, _, abs) -> VariableSet.remove f (free_in_abstraction abs)
  | Ast.Handler (ret, ops) ->
      Ast.OpNameMap.fold
        (fun _ abs acc -> VariableSet.union acc (free_in_abstraction abs))
        ops (free_in_abstraction ret)

and free_in_computation (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e -> free_in_expression e
  | Ast.Do (c, abs) ->
      VariableSet.union (free_in_computation c) (free_in_abstraction abs)
  | Ast.Match (e, cases) ->
      VariableSet.union (free_in_expression e)
        (unions free_in_abstraction cases)
  | Ast.Apply (e1, e2) ->
      VariableSet.union (free_in_expression e1) (free_in_expression e2)
  | Ast.Delay (_, c) -> free_in_computation c
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) | Ast.Perform (_, e, abs) ->
      VariableSet.union (free_in_expression e) (free_in_abstraction abs)
  | Ast.Handle (c, e) ->
      VariableSet.union (free_in_computation c) (free_in_expression e)

and free_in_abstraction (p, c) =
  VariableSet.diff (free_in_computation c) (pattern_variables p)

(* The commands kept, walking [commands] from the last: every command but a
   top-level definition is kept, a definition only if a command kept after it
   uses it. Each kept command adds the variables it uses to [needed]. *)
let reachable commands =
  let keep (cmd : _ Ast.command) (needed, kept) =
    match cmd.it with
    | Ast.TopLet (x, e) when VariableSet.mem x needed ->
        (VariableSet.union needed (free_in_expression e), cmd :: kept)
    | Ast.TopLet _ -> (needed, kept)
    | Ast.TopDo c ->
        (VariableSet.union needed (free_in_computation c), cmd :: kept)
    | Ast.OpDefault (_, abs) ->
        (VariableSet.union needed (free_in_abstraction abs), cmd :: kept)
    | Ast.TyDef _ | Ast.OpSig _ -> (needed, cmd :: kept)
  in
  snd (List.fold_right keep commands (VariableSet.empty, []))

module OperationSet = Set.Make (String)

(* The operations a term performs and those its handlers have a case for. *)
type usage = { performed : OperationSet.t; handled : OperationSet.t }

let no_usage = { performed = OperationSet.empty; handled = OperationSet.empty }

let union u u' =
  {
    performed = OperationSet.union u.performed u'.performed;
    handled = OperationSet.union u.handled u'.handled;
  }

let usages f xs = List.fold_left (fun acc x -> union acc (f x)) no_usage xs

let rec expression_usage (e : _ Ast.expression) =
  match e.it with
  | Ast.Var _ | Ast.Const _ -> no_usage
  | Ast.Annotated (e, _) -> expression_usage e
  | Ast.Tuple es -> usages expression_usage es
  | Ast.Variant (_, e) -> Option.fold ~none:no_usage ~some:expression_usage e
  | Ast.Lambda abs | Ast.PureLambda abs | Ast.RecLambda (_, _, abs) ->
      abstraction_usage abs
  | Ast.Handler (ret, ops) ->
      Ast.OpNameMap.fold
        (fun op abs acc ->
          union
            {
              acc with
              handled = OperationSet.add (Ast.OpName.string_of op) acc.handled;
            }
            (abstraction_usage abs))
        ops (abstraction_usage ret)

and computation_usage (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e -> expression_usage e
  | Ast.Do (c, abs) -> union (computation_usage c) (abstraction_usage abs)
  | Ast.Match (e, cases) ->
      union (expression_usage e) (usages abstraction_usage cases)
  | Ast.Apply (e1, e2) -> union (expression_usage e1) (expression_usage e2)
  | Ast.Delay (_, c) -> computation_usage c
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) ->
      union (expression_usage e) (abstraction_usage abs)
  | Ast.Perform (op, e, abs) ->
      let u = union (expression_usage e) (abstraction_usage abs) in
      {
        u with
        performed = OperationSet.add (Ast.OpName.string_of op) u.performed;
      }
  | Ast.Handle (c, e) -> union (computation_usage c) (expression_usage e)

and abstraction_usage (_, c) = computation_usage c

type run_operations = {
  performed : OperationSet.t;
  handled : OperationSet.t;
  defaults : OperationSet.t;
}

module VariableMap = Map.Make (Ast.Variable)

(* The usage of a term of usage [own] and free variables [free], with that of
   the top-level definitions among [free], by [definitions]. *)
let closed definitions own free =
  VariableSet.fold
    (fun x acc ->
      match VariableMap.find_opt x definitions with
      | Some u -> union acc u
      | None -> acc)
    free own

(* The usage [u] with that of the default implementations in [defaults] of the
   operations it performs and [bound] does not hold of, up to a fixed point. *)
let rec with_defaults ~bound defaults (u : usage) =
  let u' =
    OperationSet.fold
      (fun op acc ->
        match List.assoc_opt op defaults with
        | Some d when not (bound op) -> union acc d
        | _ -> acc)
      u.performed u
  in
  if OperationSet.equal u'.performed u.performed then u'
  else with_defaults ~bound defaults u'

(* Walking [commands] in order: the usages of the top-level definitions, with
   those of the definitions they use, and of the default implementations
   declared so far, the last first. *)
let run_operations ~bound commands =
  let step (definitions, defaults, runs) (cmd : _ Ast.command) =
    match cmd.it with
    | Ast.TopLet (x, e) ->
        let u =
          closed definitions (expression_usage e) (free_in_expression e)
        in
        (VariableMap.add x u definitions, defaults, runs)
    | Ast.OpDefault (op, abs) ->
        let u =
          closed definitions (abstraction_usage abs) (free_in_abstraction abs)
        in
        (definitions, (Ast.OpName.string_of op, u) :: defaults, runs)
    | Ast.TopDo c ->
        let u =
          closed definitions (computation_usage c) (free_in_computation c)
        in
        let u = with_defaults ~bound defaults u in
        let run =
          {
            performed = u.performed;
            handled = u.handled;
            defaults = OperationSet.of_list (List.map fst defaults);
          }
        in
        (definitions, defaults, run :: runs)
    | Ast.TyDef _ | Ast.OpSig _ -> (definitions, defaults, runs)
  in
  let _, _, runs = List.fold_left step (VariableMap.empty, [], []) commands in
  List.rev runs
