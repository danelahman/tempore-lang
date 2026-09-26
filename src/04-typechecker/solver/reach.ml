(* Warshall's algorithm, after [SolverImpl/Reach.agda]. *)

type ('v, 'e) t = {
  equal : 'v -> 'v -> bool;
  vertices : 'v array;
  table : 'e list option array array;
      (* [table.(a).(b)] is a chain from vertex [a] to vertex [b], if known *)
}

(* The empty chain on the diagonal, else the first edge joining the two. *)
let start ~equal edges a b =
  if equal a b then Some []
  else
    List.find_map
      (fun (c, d, label) ->
        if equal c a && equal d b then Some [ label ] else None)
      edges

(* The pairs joined through pivot [k] gain an entry where they have none. *)
let through table k =
  Array.mapi
    (fun a row ->
      match table.(a).(k) with
      | None -> row
      | Some to_pivot ->
          Array.mapi
            (fun b entry ->
              match entry with
              | Some _ -> entry
              | None ->
                  Option.map
                    (fun from_pivot -> to_pivot @ from_pivot)
                    table.(k).(b))
            row)
    table

let closure ~equal vertices edges =
  let vertices = Array.of_list vertices in
  let initial =
    Array.map
      (fun a -> Array.map (fun b -> start ~equal edges a b) vertices)
      vertices
  in
  let pivots = List.init (Array.length vertices) Fun.id in
  { equal; vertices; table = List.fold_left through initial pivots }

(* The position of a vertex, if it is one. *)
let index closure v =
  Seq.find_map
    (fun (i, w) -> if closure.equal v w then Some i else None)
    (Array.to_seqi closure.vertices)

let reach closure a b =
  match (index closure a, index closure b) with
  | Some i, Some j -> closure.table.(i).(j)
  | _ -> None

let joined closure a v =
  match (reach closure a v, reach closure v a) with
  | Some there, Some back -> Some (there, back)
  | _ -> None

let on_cycle closure a =
  Array.exists
    (fun v -> (not (closure.equal v a)) && Option.is_some (joined closure a v))
    closure.vertices

let representative closure order a =
  List.find_map
    (fun v ->
      Option.map (fun (there, back) -> (v, there, back)) (joined closure a v))
    order
