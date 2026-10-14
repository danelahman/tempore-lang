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
  | Ast.Const _ | Ast.Annotated _ | Ast.Tuple _ | Ast.Variant _ | Ast.Lambda _
  | Ast.PureLambda _ | Ast.RecLambda _ | Ast.Handler _ ->
      Ast.fold_expression ~expression:(expression_into ~global)
        ~abstraction:(abstraction_into ~global) e acc

and computation_into ~global (c : ('rho, 'eps) Ast.computation) acc =
  let acc =
    match c.it with
    | Ast.Perform (op, _, _) -> add op (Performed c.at) acc
    | Ast.Return _ | Ast.Do _ | Ast.Match _ | Ast.Apply _ | Ast.Delay _
    | Ast.Box _ | Ast.Unbox _ | Ast.Handle _ ->
        acc
  in
  Ast.fold_computation ~expression:(expression_into ~global)
    ~computation:(computation_into ~global)
    ~abstraction:(abstraction_into ~global) c acc

and abstraction_into ~global ((_, c) : ('rho, 'eps) Ast.abstraction) acc =
  computation_into ~global c acc

let expression ~global e = expression_into ~global e OpNameMap.empty
let abstraction ~global abs = abstraction_into ~global abs OpNameMap.empty

let operations performed =
  OpNameMap.fold
    (fun op _ ops -> OpNameSet.add op ops)
    performed OpNameSet.empty

(* A shortest path [B₀; …; Bₖ] of the graph from an operation [B₀] of
   [performed] to [target = Bₖ], by breadth-first search (Moore, 1959); each
   queued operation carries the path before it, newest first, and the queue is
   a list of the operations to visit first and a reversed one of those queued
   after them. *)
let path ~default performed target =
  let rec search visited front back =
    match (front, back) with
    | [], [] -> None
    | [], back -> search visited (List.rev back) []
    | (op, before) :: _, _ when Ast.OpName.equal op target ->
        Some (List.rev (op :: before))
    | (op, before) :: front, back ->
        let next =
          match default op with
          | Some { performs; _ } -> OpNameSet.diff performs visited
          | None -> OpNameSet.empty
        in
        search
          (OpNameSet.union visited next)
          front
          (List.rev_append
             (List.map
                (fun op' -> (op', op :: before))
                (OpNameSet.elements next))
             back)
  in
  let start = operations performed in
  search start (List.map (fun op -> (op, [])) (OpNameSet.elements start)) []

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
