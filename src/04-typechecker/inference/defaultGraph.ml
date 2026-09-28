(* The operations a term may perform, read off its syntax, and the graph of
   default implementations, with an edge from [A] to [B] when the default of
   [A] may perform [B]. *)

module Ast = Language.Ast
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module OpNameMap = Ast.OpNameMap
module OpNameSet = Ast.OpNameSet

(* Where a term may perform an operation: a [perform] of it, or a use of a
   top-level definition that may perform it. *)
type source = Performed of Location.t | Through of Ast.variable * Location.t
type performed = source OpNameMap.t
type default = { performs : OpNameSet.t; default_at : Location.t }

let add op source performed =
  if OpNameMap.mem op performed then performed
  else OpNameMap.add op source performed

let rec expression_into ~global (e : ('rho, 'eps) Ast.expression) acc =
  match e.it with
  | Ast.Var x ->
      OpNameSet.fold
        (fun op acc -> add op (Through (x, e.at)) acc)
        (global x) acc
  | Ast.Const _ | Ast.Variant (_, None) -> acc
  | Ast.Annotated (e, _) | Ast.Variant (_, Some e) ->
      expression_into ~global e acc
  | Ast.Tuple es ->
      List.fold_left (fun acc e -> expression_into ~global e acc) acc es
  | Ast.Lambda abs | Ast.PureLambda abs | Ast.RecLambda (_, abs) ->
      abstraction_into ~global abs acc
  | Ast.Handler (ret, ops) ->
      OpNameMap.fold
        (fun _ abs acc -> abstraction_into ~global abs acc)
        ops
        (abstraction_into ~global ret acc)

and computation_into ~global (c : ('rho, 'eps) Ast.computation) acc =
  match c.it with
  | Ast.Return e -> expression_into ~global e acc
  | Ast.Do (c1, abs) ->
      abstraction_into ~global abs (computation_into ~global c1 acc)
  | Ast.Match (e, cases) ->
      List.fold_left
        (fun acc abs -> abstraction_into ~global abs acc)
        (expression_into ~global e acc)
        cases
  | Ast.Apply (e1, e2) ->
      expression_into ~global e2 (expression_into ~global e1 acc)
  | Ast.Delay (_, c) -> computation_into ~global c acc
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) ->
      abstraction_into ~global abs (expression_into ~global e acc)
  | Ast.Perform (op, e, abs) ->
      abstraction_into ~global abs
        (expression_into ~global e (add op (Performed c.at) acc))
  | Ast.Handle (c, e) ->
      expression_into ~global e (computation_into ~global c acc)

and abstraction_into ~global ((_, c) : ('rho, 'eps) Ast.abstraction) acc =
  computation_into ~global c acc

let expression ~global e = expression_into ~global e OpNameMap.empty
let abstraction ~global abs = abstraction_into ~global abs OpNameMap.empty

let operations performed =
  OpNameMap.fold
    (fun op _ ops -> OpNameSet.add op ops)
    performed OpNameSet.empty

(* A shortest path [B₀; …; Bₖ] of the graph from an operation [B₀] of
   [performed] to [target = Bₖ], by breadth-first search; each queued
   operation carries the path before it, newest first. *)
let path ~default performed target =
  let rec search visited = function
    | [] -> None
    | (op, before) :: _ when Ast.OpName.compare op target = 0 ->
        Some (List.rev (op :: before))
    | (op, before) :: queue ->
        let next =
          match default op with
          | Some { performs; _ } -> OpNameSet.diff performs visited
          | None -> OpNameSet.empty
        in
        search
          (OpNameSet.union visited next)
          (queue
          @ List.map (fun op' -> (op', op :: before)) (OpNameSet.elements next)
          )
  in
  let start = operations performed in
  search start (List.map (fun op -> (op, [])) (OpNameSet.elements start))

let name op = Printf.sprintf "`%s`" (Ast.OpName.string_of op)

let enumeration = function
  | [] -> ""
  | [ op ] -> name op
  | ops -> (
      match List.rev ops with
      | last :: rest ->
          Printf.sprintf "%s and %s"
            (String.concat ", " (List.rev_map name rest))
            (name last)
      | [] -> "")

let reject ~default ~loc op performed path =
  let here = Diagnostic.place in
  let first =
    match path with
    | first :: _ -> (
        match OpNameMap.find_opt first performed with
        | Some (Performed at) ->
            [
              {
                Diagnostic.span = at;
                text = Printf.sprintf "%s is performed %s" (name first) here;
              };
            ]
        | Some (Through (x, at)) ->
            [
              {
                Diagnostic.span = at;
                text =
                  Printf.sprintf "`%s`, which may perform %s, is used %s"
                    (Ast.Variable.string_of x) (name first) here;
              };
            ]
        | None -> [])
    | [] -> []
  in
  let rec edges = function
    | b :: (c :: _ as rest) ->
        let label =
          Option.map
            (fun { default_at; _ } ->
              {
                Diagnostic.span = default_at;
                text =
                  Printf.sprintf
                    "the default of %s, which may perform %s, is defined %s"
                    (name b) (name c) here;
              })
            (default b)
        in
        Option.to_list label @ edges rest
    | [ _ ] | [] -> []
  in
  let through =
    match List.rev path with
    | _ :: (_ :: _ as rest) ->
        Printf.sprintf ", through the default%s of %s"
          (if List.length rest > 1 then "s" else "")
          (enumeration (List.rev rest))
    | [ _ ] | [] -> ""
  in
  Error.typing ~loc
    ~labels:(first @ edges path)
    ~notes:
      [
        "a default runs in place of an unhandled operation, so a cycle through \
         defaults does not terminate";
      ]
    "The default of %s may perform %s again%s" (name op) (name op) through

let check_default ~default ~loc op performed =
  match path ~default performed op with
  | Some path -> reject ~default ~loc op performed path
  | None -> ()
