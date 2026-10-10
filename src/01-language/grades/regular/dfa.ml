type t = { rows : int array array; finals : bool array }
(* Row [q] lists the successors of state [q] by letter; state [0] is the start.
   The arrays are not mutated after construction. *)

let letters l = Array.length l.rows.(0)
let states l = Array.length l.rows
let next l q a = l.rows.(q).(a)
let final l q = l.finals.(q)

let compare l m =
  match Grade.compare_array Bool.compare l.finals m.finals with
  | 0 -> Grade.compare_array (Grade.compare_array Int.compare) l.rows m.rows
  | c -> c

let equal l m = compare l m = 0

let hash l =
  let finals =
    Array.fold_left (fun h f -> Grade.combine h (Bool.to_int f)) 0 l.finals
  in
  Array.fold_left (Array.fold_left Grade.combine) finals l.rows

let range n = List.init n Fun.id
let sort_uniq = List.sort_uniq Int.compare

(** First-in first-out queues, as a front list and a reversed back list, with
    amortised constant-time operations (Burton, IPL 1982). *)
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
      [start] over [n] letters, numbered in the order of their discovery by
      breadth-first search, the letters of a state in increasing order. *)
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

  let compare (p, q) (p', q') =
    match Int.compare p p' with 0 -> Int.compare q q' | c -> c
end

module Pairs = Explore (Pair)

module Signatures = Map.Make (struct
  type t = bool * int array

  let compare (f, a) (f', a') =
    match Bool.compare f f' with
    | 0 -> Grade.compare_array Int.compare a a'
    | c -> c
end)

(** [refine final delta classes] is one round of Moore's partition refinement
    (Moore, Automata Studies 1956) of the partition [classes] of the states of
    the table [delta] of successors by letter, of final states [final], with its
    number of classes: two states stay together iff they agree on finality and
    on the classes of their successors. Classes are numbered in the order of
    their first member. *)
let refine final delta classes =
  let classify (seen, count) q =
    let signature = (final.(q), Array.map (Array.get classes) delta.(q)) in
    match Signatures.find_opt signature seen with
    | Some c -> ((seen, count), c)
    | None -> ((Signatures.add signature count seen, count + 1), count)
  in
  let (_, count), classes =
    List.fold_left_map classify (Signatures.empty, 0)
      (range (Array.length delta))
  in
  (count, Array.of_list classes)

(* The partition is reached by iterating {!refine} until the number of classes
   is stable. *)
let partition final delta =
  let rec go (count, classes) =
    let count', classes' = refine final delta classes in
    if count' = count then classes else go (count', classes')
  in
  go (1, Array.make (Array.length delta) 0)

(** [minimise l] is the canonical form of [l]: the quotient by {!partition},
    explored breadth-first from the class of the start. The quotient is the
    minimal automaton, unique up to isomorphism (Myhill–Nerode), and the
    breadth-first numbering fixes the isomorphism. *)
let minimise l =
  let classes = partition l.finals l.rows in
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
  let step i a = if i < len && Int.equal w.(i) a then i + 1 else len + 1 in
  minimise (Ints.table n ~start:0 ~next:step ~final:(Int.equal len))

(* The states of the chain are the numbers of ticks read, up to [hi], or up to
   [lo] with a loop on [lo] if [hi] is infinite, and a dead state. The chain is
   minimal: its live states accept the runs of ticks of pairwise distinct
   lengths. Its breadth-first table is thus canonical without minimisation. *)
let ticks n lo hi =
  let last = Option.value hi ~default:lo in
  let dead = last + 1 in
  let step i a =
    if Int.equal a 0 && i < last then i + 1
    else if Int.equal a 0 && Int.equal i last && Option.is_none hi then i
    else dead
  in
  if Option.fold ~none:false ~some:(fun hi -> hi < lo) hi then empty n
  else Ints.table n ~start:0 ~next:step ~final:(fun i -> lo <= i && i <= last)

(* States: [0] the start, [1] after one letter of [s], [2] dead. *)
let letter_set n s =
  let step q a =
    if Int.equal q 0 && List.exists (Int.equal a) s then 1 else 2
  in
  minimise (Ints.table n ~start:0 ~next:step ~final:(Int.equal 1))

(* The product construction (Rabin and Scott, IBM J. Res. Dev. 1959), over the
   reachable pairs of states. *)
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

  let compare (p, s) (p', s') =
    match Int.compare p p' with 0 -> List.compare Int.compare s s' | c -> c
end)

(* The subset construction (Rabin and Scott, IBM J. Res. Dev. 1959) of the
   concatenation, over the reachable states. *)
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

  let compare = Option.compare (List.compare Int.compare)
end)

(* The subset construction of the repetition: a state is [None], the start, or
   [Some s], the non-empty set [s] of states of [l] reached, closed under
   restarting [l] after a word of [l]. *)
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
let alike l a b = Array.for_all (fun row -> row.(a) = row.(b)) l.rows

(* [dead l] tells whether no final state is reachable from a state of the
   minimal automaton [l]: such a state is unique, and its own successor by
   every letter. *)
let dead l =
  let is_dead q = (not (final l q)) && Array.for_all (Int.equal q) l.rows.(q) in
  match List.find_opt is_dead (range (states l)) with
  | Some d -> Int.equal d
  | None -> Fun.const false

type 'state automaton = {
  start : 'state;
  step : 'state -> int -> 'state;
  accepts : 'state -> bool;
  dead : 'state -> bool;
  lead : 'state -> int;
  leap : 'state -> int -> 'state;
}

let rec unrolled step q k = if k = 0 then q else unrolled step (step q 0) (k - 1)

let automaton l =
  {
    start = 0;
    step = next l;
    accepts = final l;
    dead = dead l;
    lead = Fun.const 0;
    leap = unrolled (next l);
  }

(** The lead of a state accepting no word. *)
let unbounded = Int.max_int

(** [moves n a k q] is the successors of the state [q] of [a] a search explores,
    each with the letters of the word it is reached by, reversed: by [0ᵏ] alone
    if [k ≥ 1] is at most the lead of [q], and by each of the [n] letters if [k]
    is [0]. *)
let moves n a k q =
  if k = 0 then List.map (fun c -> (a.step q c, [ c ])) (range n)
  else [ (a.leap q k, List.init k (Fun.const 0)) ]

(** [successors n a k q] is the successors of {!moves} [n a k q], without their
    words. *)
let successors n a k q =
  if k = 0 then List.map (a.step q) (range n) else [ a.leap q k ]

module Implicit (State : Map.OrderedType) = struct
  module Table = Explore (State)
  module States = Set.Make (State)

  let canonical n a =
    minimise (Table.table n ~start:a.start ~next:a.step ~final:a.accepts)

  (* Depth-first search for a final state, the dead states not explored. *)
  let is_empty n a =
    let rec go seen = function
      | [] -> true
      | q :: _ when a.accepts q -> false
      | q :: stack ->
          let fresh q = not (a.dead q || States.mem q seen) in
          let k = a.lead q in
          let next =
            if k = unbounded then [] else List.filter fresh (successors n a k q)
          in
          go (List.fold_right States.add next seen) (next @ stack)
    in
    a.dead a.start || go (States.singleton a.start) [ a.start ]
end

module Product (Left : Map.OrderedType) (Right : Map.OrderedType) = struct
  module Pairs = Set.Make (struct
    type t = Left.t * Right.t

    let compare (p, q) (p', q') =
      match Left.compare p p' with 0 -> Right.compare q q' | c -> c
  end)

  (* Breadth-first search of the product of [a] and [b] for a pair of states
     final in [a] only, by depths, the first found giving a shortest word. The
     pairs whose state of [a] is dead are not explored, since they lead to no
     such pair. *)
  let counterexample n a b =
    let found ((p, q), _) = a.accepts p && not (b.accepts q) in
    let visit k (seen, next) ((p, q), rev_word) =
      let moves = List.combine (moves n a k p) (successors n b k q) in
      List.fold_left
        (fun (seen, next) ((p', word), q') ->
          let s = (p', q') in
          if a.dead p' || Pairs.mem s seen then (seen, next)
          else (Pairs.add s seen, (s, word @ rev_word) :: next))
        (seen, next) moves
    in
    let rec go seen level =
      match List.find_opt found level with
      | Some (_, rev_word) -> Some (List.rev rev_word)
      | None ->
          let k =
            List.fold_left
              (fun k ((p, _), _) -> min k (a.lead p))
              unbounded level
          in
          if k = unbounded then None
          else
            let seen, next = List.fold_left (visit k) (seen, []) level in
            go seen (List.rev next)
    in
    let start = (a.start, b.start) in
    go (Pairs.singleton start) [ (start, []) ]
end

module Tables = Product (Int) (Int)

let counterexample l m =
  same_letters "counterexample" l m;
  Tables.counterexample (letters l) (automaton l) (automaton m)

let subset l m = Option.is_none (counterexample l m)
