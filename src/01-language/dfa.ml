type t = { rows : int array array; finals : bool array }
(* Row [q] lists the successors of state [q] by letter; state [0] is the start.
   The arrays are not mutated after construction. *)

let letters l = Array.length l.rows.(0)
let states l = Array.length l.rows
let next l q a = l.rows.(q).(a)
let final l q = l.finals.(q)
let equal (l : t) m = l = m
let compare (l : t) m = Stdlib.compare l m
let range n = List.init n Fun.id
let sort_uniq = List.sort_uniq Int.compare

(** First-in first-out queues, as a front list and a reversed back list. *)
module Fifo = struct
  type 'a t = 'a list * 'a list

  let empty : 'a t = ([], [])
  let push x (front, back) = (front, x :: back)

  let rec pop = function
    | [], [] -> None
    | [], back -> pop (List.rev back, [])
    | x :: front, back -> Some (x, (front, back))
end

(** Breadth-first exploration of automata whose states are ordered by
    [State.compare]. *)
module Explore (State : Map.OrderedType) = struct
  module Ids = Map.Make (State)

  (** [table n ~start ~next ~final] is the table of the states reachable from
      [start] over [n] letters, numbered in the order of their discovery. *)
  let table n ~start ~next ~final =
    let visit s (ids, count, fifo) a =
      let s' = next s a in
      match Ids.find_opt s' ids with
      | Some id -> ((ids, count, fifo), id)
      | None -> ((Ids.add s' count ids, count + 1, Fifo.push s' fifo), count)
    in
    let rec go (ids, count, fifo) rows finals =
      match Fifo.pop fifo with
      | None ->
          {
            rows = Array.of_list (List.rev rows);
            finals = Array.of_list (List.rev finals);
          }
      | Some (s, fifo) ->
          let seen, row =
            List.fold_left_map (visit s) (ids, count, fifo) (range n)
          in
          go seen (Array.of_list row :: rows) (final s :: finals)
    in
    go (Ids.singleton start 0, 1, Fifo.push start Fifo.empty) [] []
end

module Ints = Explore (Int)

module Pair = struct
  type t = int * int

  let compare = Stdlib.compare
end

module Pairs = Explore (Pair)

module Signatures = Map.Make (struct
  type t = bool * int array

  let compare = Stdlib.compare
end)

(** [refine l classes] is the Moore refinement of the partition [classes] of the
    states of [l], with its number of classes: two states stay together iff they
    agree on finality and on the classes of their successors. Classes are
    numbered in the order of their first member. *)
let refine l classes =
  let classify (seen, count) q =
    let signature = (final l q, Array.map (Array.get classes) l.rows.(q)) in
    match Signatures.find_opt signature seen with
    | Some c -> ((seen, count), c)
    | None -> ((Signatures.add signature count seen, count + 1), count)
  in
  let (_, count), classes =
    List.fold_left_map classify (Signatures.empty, 0) (range (states l))
  in
  (count, Array.of_list classes)

(** [partition l] is the coarsest partition of the states of [l] stable under
    refinement: the classes of states with equal residual languages. *)
let partition l =
  let rec go (count, classes) =
    let count', classes' = refine l classes in
    if count' = count then classes else go (count', classes')
  in
  go (1, Array.make (states l) 0)

(** [minimise l] is the canonical form of [l]: the quotient by {!partition},
    explored breadth-first from the class of the start. *)
let minimise l =
  let classes = partition l in
  let first (count, reps) (q, c) =
    if c = count then (count + 1, q :: reps) else (count, reps)
  in
  let _, reps = Seq.fold_left first (0, []) (Array.to_seqi classes) in
  let reps = Array.of_list (List.rev reps) in
  Ints.table (letters l) ~start:classes.(0)
    ~next:(fun c a -> classes.(next l reps.(c) a))
    ~final:(fun c -> final l reps.(c))

let same_letters who l m =
  if letters l <> letters m then
    invalid_arg ("Dfa." ^ who ^ ": the alphabets differ")

let single_state n final = { rows = [| Array.make n 0 |]; finals = [| final |] }
let empty n = single_state n false
let all n = single_state n true

(* The states of a word automaton are the lengths of the prefixes matched, and
   one past the end for the dead state. *)
let word n w =
  let w = Array.of_list w in
  let len = Array.length w in
  let step i a = if i < len && w.(i) = a then i + 1 else len + 1 in
  minimise (Ints.table n ~start:0 ~next:step ~final:(Int.equal len))

(* States: [0] the start, [1] after one letter of [s], [2] dead. *)
let letter_set n s =
  let step q a = if q = 0 && List.mem a s then 1 else 2 in
  minimise (Ints.table n ~start:0 ~next:step ~final:(Int.equal 1))

let product who accept l m =
  same_letters who l m;
  minimise
    (Pairs.table (letters l) ~start:(0, 0)
       ~next:(fun (p, q) a -> (next l p a, next m q a))
       ~final:(fun (p, q) -> accept (final l p) (final m q)))

let union = product "union" ( || )
let inter = product "inter" ( && )

(* Flipping the final states of a canonical automaton keeps it minimal and its
   numbering breadth-first. *)
let complement l = { l with finals = Array.map not l.finals }

module Subsets = Explore (struct
  type t = int * int list

  let compare = Stdlib.compare
end)

let concat l m =
  same_letters "concat" l m;
  let enter p s = if final l p then sort_uniq (0 :: s) else s in
  let step (p, s) a =
    let p' = next l p a in
    (p', enter p' (sort_uniq (List.map (fun q -> next m q a) s)))
  in
  minimise
    (Subsets.table (letters l)
       ~start:(0, enter 0 [])
       ~next:step
       ~final:(fun (_, s) -> List.exists (final m) s))

module Closures = Explore (struct
  type t = int list option

  let compare = Stdlib.compare
end)

(* A state is [None], the start, or [Some s], the non-empty set [s] of states of
   [l] reached, closed under restarting [l] after a word of [l]. *)
let star l =
  let close s =
    if List.exists (final l) s then sort_uniq (0 :: s) else sort_uniq s
  in
  let step s a =
    Some
      (close (List.map (fun q -> next l q a) (Option.value s ~default:[ 0 ])))
  in
  let accepts = function None -> true | Some s -> List.exists (final l) s in
  minimise (Closures.table (letters l) ~start:None ~next:step ~final:accepts)

let relabel n f l =
  if List.exists (fun a -> f a < 0 || f a >= letters l) (range n) then
    invalid_arg "Dfa.relabel: not a letter";
  minimise
    (Ints.table n ~start:0 ~next:(fun q a -> next l q (f a)) ~final:(final l))

(* The states of a canonical automaton are all reachable. *)
let is_empty l = not (Array.mem true l.finals)
let is_all l = not (Array.mem false l.finals)
let alike l a b = Array.for_all (fun row -> row.(a) = row.(b)) l.rows

module Pair_set = Set.Make (Pair)

let counterexample l m =
  same_letters "counterexample" l m;
  let rec go seen fifo =
    match Fifo.pop fifo with
    | None -> None
    | Some (((p, q), rev_word), _) when final l p && not (final m q) ->
        Some (List.rev rev_word)
    | Some (((p, q), rev_word), fifo) ->
        let visit (seen, fifo) a =
          let s = (next l p a, next m q a) in
          if Pair_set.mem s seen then (seen, fifo)
          else (Pair_set.add s seen, Fifo.push (s, a :: rev_word) fifo)
        in
        let seen, fifo =
          List.fold_left visit (seen, fifo) (range (letters l))
        in
        go seen fifo
  in
  go (Pair_set.singleton (0, 0)) (Fifo.push ((0, 0), []) Fifo.empty)

let subset l m = Option.is_none (counterexample l m)

type regex =
  | Letters of int list
  | Seq of regex list
  | Union of regex list
  | Star of regex

(** Smart constructors of regular expressions, simplifying as they build. *)
module Regex = struct
  let eps = Seq []

  let rec nullable = function
    | Letters _ -> false
    | Seq rs -> List.for_all nullable rs
    | Union rs -> List.exists nullable rs
    | Star _ -> true

  let seq rs =
    let parts = List.concat_map (function Seq rs -> rs | r -> [ r ]) rs in
    if List.mem (Union []) parts then Union []
    else match parts with [ r ] -> r | parts -> Seq parts

  (** [plus r] is [Some x] if [r] is [x; x*] or [x*; x]. *)
  let plus = function
    | Seq (Star x :: rest) when seq rest = x -> Some x
    | Seq parts -> (
        match List.rev parts with
        | Star x :: rev_init when seq (List.rev rev_init) = x -> Some x
        | _ -> None)
    | _ -> None

  (** [add_part parts r] adds [r] to the reversed list [parts] of the parts of a
      union, letter sets merging into the first one and duplicates dropped. *)
  let add_part parts r =
    let merge s = function
      | Letters s' -> Letters (sort_uniq (s' @ s))
      | r -> r
    in
    match r with
    | Letters s
      when List.exists (function Letters _ -> true | _ -> false) parts ->
        List.map (merge s) parts
    | r when List.mem r parts -> parts
    | r -> r :: parts

  (** [absorb_eps parts] drops the empty word from the parts of a union when
      another part contains it or turns into a repetition [x*] by it. *)
  let absorb_eps parts =
    let others = List.filter (( <> ) eps) parts in
    let star_plus r = match plus r with Some x -> Star x | None -> r in
    match others with
    | _ when others = parts -> parts
    | _ when List.exists nullable others -> others
    | _ when List.exists (fun r -> Option.is_some (plus r)) others ->
        List.map star_plus others
    | _ -> parts

  (** [group split parts] gathers the parts that [split] into the same key, in
      the order of their first occurrence, each with what [split] leaves of it;
      a part without a key forms a group of its own. *)
  let group split parts =
    let add groups part =
      match split part with
      | Some (key, x) when List.mem_assoc (Some key) groups ->
          List.map
            (fun (key', members) ->
              if key' = Some key then (key', (x, part) :: members)
              else (key', members))
            groups
      | Some (key, x) -> (Some key, [ (x, part) ]) :: groups
      | None -> (None, [ (part, part) ]) :: groups
    in
    List.rev_map
      (fun (key, members) -> (key, List.rev members))
      (List.fold_left add [] parts)

  (** [split_head r] is [Some (x, s)] if [r] is the concatenation [x; s] of at
      least two parts. *)
  let split_head = function
    | Seq (x :: (_ :: _ as rest)) -> Some (x, seq rest)
    | _ -> None

  let split_tail r = Option.map (fun (x, s) -> (s, x)) (split_head r)

  let rec union rs =
    let parts = List.concat_map (function Union rs -> rs | r -> [ r ]) rs in
    let parts = absorb_eps (List.rev (List.fold_left add_part [] parts)) in
    match factor parts with [ r ] -> r | parts -> Union parts

  (** [factor parts] factors the common tails, [x; s | y; s] becoming
      [(x | y); s], then the common heads, [x; s | x; t] becoming [x; (s | t)],
      out of the parts of a union. *)
  and factor parts =
    let rebuild join = function
      | Some key, (_ :: _ :: _ as members) ->
          [ join key (union (List.map fst members)) ]
      | _, members -> List.map snd members
    in
    let parts =
      List.concat_map
        (rebuild (fun s x -> seq [ x; s ]))
        (group split_tail parts)
    in
    List.concat_map (rebuild (fun x s -> seq [ x; s ])) (group split_head parts)

  let rec star = function
    | Seq [] | Union [] -> eps
    | Star _ as r -> r
    | Union parts when List.mem eps parts ->
        star (union (List.filter (( <> ) eps) parts))
    | r -> ( match plus r with Some x -> Star x | None -> Star r)
end

module Edges = Map.Make (Pair)

(* The two nodes added for state elimination. *)
let source = -1
let sink = -2

(** [live l] marks the states of [l] from which a final state is reachable. *)
let live l =
  let reaches marked q = Array.exists (Array.get marked) l.rows.(q) in
  let rec grow marked =
    let marked' = Array.mapi (fun q m -> m || reaches marked q) marked in
    if marked' = marked then marked else grow marked'
  in
  grow l.finals

let add_edge edges (key, r) =
  Edges.update key
    (fun old ->
      Some (Option.fold ~none:r ~some:(fun o -> Regex.union [ o; r ]) old))
    edges

(** [initial_edges l live] is the graph of the live states of [l], labelled by
    letter sets, with an edge from {!source} to the start and from each final
    state to {!sink}, both labelled by the empty word. *)
let initial_edges l live =
  let transitions p =
    List.filter_map
      (fun a ->
        let q = next l p a in
        if live.(q) then Some ((p, q), Letters [ a ]) else None)
      (range (letters l))
  in
  let from p =
    if not live.(p) then []
    else if final l p then ((p, sink), Regex.eps) :: transitions p
    else transitions p
  in
  List.fold_left add_edge Edges.empty
    (((source, 0), Regex.eps) :: List.concat_map from (range (states l)))

let incoming edges k =
  Edges.bindings (Edges.filter (fun (p, q) _ -> q = k && p <> k) edges)

let outgoing edges k =
  Edges.bindings (Edges.filter (fun (p, q) _ -> p = k && q <> k) edges)

let paths edges k =
  List.length (incoming edges k) * List.length (outgoing edges k)

(** [eliminate edges k] removes the node [k], each path through it becoming an
    edge labelled by the concatenation of the labels, the loop at [k] repeated.
*)
let eliminate edges k =
  let loop =
    Option.fold ~none:Regex.eps ~some:Regex.star (Edges.find_opt (k, k) edges)
  in
  let rest = Edges.filter (fun (p, q) _ -> p <> k && q <> k) edges in
  let bypass acc ((p, _), r_in) =
    List.fold_left
      (fun acc ((_, q), r_out) ->
        add_edge acc ((p, q), Regex.seq [ r_in; loop; r_out ]))
      acc (outgoing edges k)
  in
  List.fold_left bypass rest (incoming edges k)

(** [eliminate_all edges nodes] eliminates the [nodes] one by one, each time the
    first with the fewest paths through it. *)
let rec eliminate_all edges = function
  | [] -> edges
  | k :: ks as nodes ->
      let cheaper k k' = if paths edges k' < paths edges k then k' else k in
      let best = List.fold_left cheaper k ks in
      eliminate_all (eliminate edges best) (List.filter (( <> ) best) nodes)

let to_regex l =
  let live = live l in
  let nodes = List.filter (Array.get live) (range (states l)) in
  let edges = eliminate_all (initial_edges l live) nodes in
  Option.value (Edges.find_opt (source, sink) edges) ~default:(Union [])
