(* Warshall's algorithm. *)

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

(* Kosaraju's algorithm on the vertices numbered: the vertices in decreasing
   order of the end of a depth-first visit, then the component of each, not
   yet assigned, collected along the reversed edges and named by it. *)
let representatives (type v) ~(compare : v -> v -> int) edges =
  let module M = Map.Make (struct
    type t = v

    let compare = compare
  end) in
  let number (index, n) v =
    if M.mem v index then (index, n) else (M.add v n index, n + 1)
  in
  let index, n =
    List.fold_left
      (fun acc (a, b) -> number (number acc a) b)
      (M.empty, 0) edges
  in
  let pairs = List.map (fun (a, b) -> (M.find a index, M.find b index)) edges in
  let succ = Array.make n [] and pred = Array.make n [] in
  List.iter
    (fun (i, j) ->
      succ.(i) <- j :: succ.(i);
      pred.(j) <- i :: pred.(j))
    (List.rev pairs);
  let seen = Array.make n false in
  let rec finish order i =
    if seen.(i) then order
    else begin
      seen.(i) <- true;
      i :: List.fold_left finish order succ.(i)
    end
  in
  let finished = List.fold_left finish [] (List.map fst pairs) in
  let component = Array.make n (-1) in
  let rec assign root i =
    if component.(i) < 0 then begin
      component.(i) <- root;
      List.iter (assign root) pred.(i)
    end
  in
  List.iter (fun i -> assign i i) finished;
  fun order ->
    let first = Array.make n None in
    List.iter
      (fun r ->
        match M.find_opt r index with
        | Some i when Option.is_none first.(component.(i)) ->
            first.(component.(i)) <- Some r
        | Some _ | None -> ())
      order;
    fun v ->
      match M.find_opt v index with
      | Some i -> first.(component.(i))
      | None -> List.find_opt (fun r -> compare r v = 0) order
