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
