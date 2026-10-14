type names = Only of string list | Except of string list
type t = { tick : bool; names : names }

let compare_names a b =
  match (a, b) with
  | Only a, Only b | Except a, Except b -> List.compare String.compare a b
  | Only _, Except _ -> -1
  | Except _, Only _ -> 1

let compare p q =
  match Bool.compare p.tick q.tick with
  | 0 -> compare_names p.names q.names
  | c -> c

let equal p q = compare p q = 0
let empty = { tick = false; names = Only [] }
let any = { tick = true; names = Except [] }
let tick = { tick = true; names = Only [] }
let name n = { tick = false; names = Only [ n ] }

let others names =
  { tick = false; names = Except (List.sort_uniq String.compare names) }

(* Set operations on lists in increasing order. *)

let rec merge xs ys =
  match (xs, ys) with
  | [], zs | zs, [] -> zs
  | x :: xs', y :: ys' ->
      let c = String.compare x y in
      if c < 0 then x :: merge xs' ys
      else if c > 0 then y :: merge xs ys'
      else x :: merge xs' ys'

let rec meet xs ys =
  match (xs, ys) with
  | [], _ | _, [] -> []
  | x :: xs', y :: ys' ->
      let c = String.compare x y in
      if c < 0 then meet xs' ys
      else if c > 0 then meet xs ys'
      else x :: meet xs' ys'

let rec minus xs ys =
  match (xs, ys) with
  | [], _ -> []
  | xs, [] -> xs
  | x :: xs', y :: ys' ->
      let c = String.compare x y in
      if c < 0 then x :: minus xs' ys
      else if c > 0 then minus xs ys'
      else minus xs' ys'

let union_names a b =
  match (a, b) with
  | Only a, Only b -> Only (merge a b)
  | Only a, Except b | Except b, Only a -> Except (minus b a)
  | Except a, Except b -> Except (meet a b)

let inter_names a b =
  match (a, b) with
  | Only a, Only b -> Only (meet a b)
  | Only a, Except b | Except b, Only a -> Only (minus a b)
  | Except a, Except b -> Except (merge a b)

let union p q = { tick = p.tick || q.tick; names = union_names p.names q.names }
let inter p q = { tick = p.tick && q.tick; names = inter_names p.names q.names }

let compl p =
  {
    tick = not p.tick;
    names = (match p.names with Only a -> Except a | Except a -> Only a);
  }

let is_empty p =
  match p with { tick = false; names = Only [] } -> true | _ -> false

let hash p =
  let names, cofinite =
    match p.names with Only a -> (a, false) | Except a -> (a, true)
  in
  Hashing.combine
    (Hashing.combine (Bool.to_int p.tick) (Bool.to_int cofinite))
    (Hashing.list String.hash names)

(* [least p] is the least letter of [p]: [tick], then the names listed in
   increasing order, then the names not listed. *)
let least p =
  match p with
  | { tick = true; _ } -> (0, "")
  | { names = Only (n :: _); _ } -> (1, n)
  | _ -> (2, "")

let order p q =
  let (i, n), (j, m) = (least p, least q) in
  match Int.compare i j with
  | 0 -> ( match String.compare n m with 0 -> compare p q | c -> c)
  | c -> c

let mentioned p = match p.names with Only a | Except a -> a

(* The minterms of [sets], the atoms of the Boolean algebra they generate, as
   in symbolic automata (D'Antoni and Veanes, POPL 2014), by splitting every
   block by each set in turn. *)
let partition sets =
  let split block p =
    List.filter
      (fun b -> not (is_empty b))
      [ inter block p; inter block (compl p) ]
  in
  let refine blocks p = List.concat_map (fun b -> split b p) blocks in
  List.sort order (List.fold_left refine [ any ] sets)
