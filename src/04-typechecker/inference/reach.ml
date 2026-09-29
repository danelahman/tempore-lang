module Int_set = Set.Make (Int)
module Int_map = Map.Make (Int)

type 'e graph = (int * 'e) list array

let graph n edges =
  let out =
    List.fold_right
      (fun (a, b, label) out ->
        Int_map.add a
          ((b, label) :: Option.value (Int_map.find_opt a out) ~default:[])
          out)
      edges Int_map.empty
  in
  Array.init n (fun i -> Option.value (Int_map.find_opt i out) ~default:[])

(* Depth-first search. *)
let reached g starts =
  let rec visit seen = function
    | [] -> seen
    | i :: rest when Int_set.mem i seen -> visit seen rest
    | i :: rest -> visit (Int_set.add i seen) (List.map fst g.(i) @ rest)
  in
  let seen = visit Int_set.empty starts in
  fun i -> Int_set.mem i seen

(* Breadth-first search (Moore, International Symposium on the Theory of
   Switching, 1959), layer by layer: each vertex reached is recorded with the
   reversed chain of the first path found to it, the vertices of a layer
   taken in order and the edges out of each in order. *)
let chain g i =
  let rec layers chains = function
    | [] -> chains
    | layer ->
        let visit (chains, next) u =
          let to_u = Int_map.find u chains in
          List.fold_left
            (fun (chains, next) (v, label) ->
              if Int_map.mem v chains then (chains, next)
              else (Int_map.add v (label :: to_u) chains, v :: next))
            (chains, next) g.(u)
        in
        let chains, next = List.fold_left visit (chains, []) layer in
        layers chains (List.rev next)
  in
  let chains = layers (Int_map.singleton i []) [ i ] in
  fun j -> Option.map List.rev (Int_map.find_opt j chains)

(* Kosaraju's algorithm (Sharir, Computers & Mathematics with Applications,
   1981) on the vertices numbered: the vertices in decreasing order of the end
   of a depth-first visit, then the component of each, not yet assigned,
   collected along the reversed edges and named by it. *)
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

(* The members of both a source and a target of [edges], in increasing
   order. *)
let on_both_ends ~compare edges =
  let ends pick = List.sort_uniq compare (List.map pick edges) in
  let rec inter xs ys =
    match (xs, ys) with
    | x :: xs', y :: ys' ->
        let c = compare x y in
        if c = 0 then x :: inter xs' ys'
        else if c < 0 then inter xs' ys
        else inter xs ys'
    | [], _ | _, [] -> []
  in
  inter (ends fst) (ends snd)

(* Cycle elimination (Fähndrich, Foster, Su and Aiken, PLDI 1998). *)
let collapse ~compare ~preferred ~movable edges =
  let vertices = on_both_ends ~compare edges in
  let order =
    List.filter preferred vertices
    @ List.filter (fun v -> not (preferred v || movable v)) vertices
    @ List.filter movable vertices
  in
  let representative = representatives ~compare edges order in
  List.filter_map
    (fun v ->
      if movable v then
        match representative v with
        | Some rep when compare rep v <> 0 -> Some (v, rep)
        | Some _ | None -> None
      else None)
    vertices
