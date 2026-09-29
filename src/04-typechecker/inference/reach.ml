module Int_set = Set.Make (Int)
module Int_map = Map.Make (Int)

type 'e graph = { successors : int list array; edges : (int * int * 'e) list }

let graph n edges =
  let out =
    List.fold_right
      (fun (a, b, _) out ->
        Int_map.add a
          (b :: Option.value (Int_map.find_opt a out) ~default:[])
          out)
      edges Int_map.empty
  in
  {
    successors =
      Array.init n (fun i -> Option.value (Int_map.find_opt i out) ~default:[]);
    edges;
  }

(* Depth-first search. *)
let reached g starts =
  let rec visit seen = function
    | [] -> seen
    | i :: rest when Int_set.mem i seen -> visit seen rest
    | i :: rest -> visit (Int_set.add i seen) (g.successors.(i) @ rest)
  in
  let seen = visit Int_set.empty starts in
  fun i -> Int_set.mem i seen

(* The least [k] such that a path from [i] to [j] has its intermediate
   vertices among [0, …, k], [-1] for an edge: a bottleneck path, by
   Dijkstra's algorithm with the maximum in place of the sum (Pollack,
   Operations Research 1960). The vertex [i] passed again costs nothing, a
   path through it being no better than its part after it. *)
let pivot g i j =
  let module Q = Set.Make (struct
    type t = int * int

    let compare = compare
  end) in
  let rec go cost queue =
    match Q.min_elt_opt queue with
    | None -> None
    | Some ((c, u) as least) ->
        let queue = Q.remove least queue in
        if u = j then Some c
        else
          let through = if u = i then -1 else Int.max c u in
          let relax (cost, queue) v =
            match Int_map.find_opt v cost with
            | Some c' when c' <= through -> (cost, queue)
            | Some c' ->
                ( Int_map.add v through cost,
                  Q.add (through, v) (Q.remove (c', v) queue) )
            | None -> (Int_map.add v through cost, Q.add (through, v) queue)
          in
          let cost, queue =
            List.fold_left relax (cost, queue) g.successors.(u)
          in
          go cost queue
  in
  go (Int_map.singleton i (-1)) (Q.singleton (-1, i))

(* The chain of Warshall's algorithm (Warshall, JACM 1962) with the vertices
   as pivots in increasing order, for one pair: the empty chain on the
   diagonal, else the label of the first edge joining the pair, else the
   chains to and from the first pivot that joins the pair, which is the least
   bound of {!pivot}. *)
let chain g i j =
  let rec between i j =
    if i = j then []
    else
      match List.find_opt (fun (a, b, _) -> a = i && b = j) g.edges with
      | Some (_, _, label) -> [ label ]
      | None -> (
          match pivot g i j with
          | Some k when k >= 0 -> between i k @ between k j
          | Some _ | None -> invalid_arg "Reach.chain: no path")
  in
  if reached g [ i ] j then Some (between i j) else None

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
