module Letters = SymbolicRegex.Letters

type t = { finals : bool array; edges : (Letters.t * int) list array }
(* State [0] is the start; [edges.(q)] lists the edges out of [q] in the order
   of their labels. *)

let equal a b =
  Array.length a.finals = Array.length b.finals
  && Array.for_all2 Bool.equal a.finals b.finals
  && Array.for_all2
       (List.equal (fun (p, q) (p', q') -> Letters.equal p p' && Int.equal q q'))
       a.edges b.edges

let states a = Array.length a.finals
let final a q = a.finals.(q)
let edges a q = a.edges.(q)
let complement a = { a with finals = Array.map not a.finals }

(** {1 Minimisation} *)

(** [target edges m] is the target of the edge of [edges] whose label contains
    the block [m] of a partition the labels respect. *)
let target edges m =
  match
    List.find_opt
      (fun (p, _) -> not (Letters.is_empty (Letters.inter p m)))
      edges
  with
  | Some (_, q) -> q
  | None -> invalid_arg "SymbolicAutomaton.of_table: the labels miss a letter"

let next a q p = target a.edges.(q) p

module Signatures = Map.Make (struct
  type t = bool * int array

  let compare (f, a) (f', a') =
    match Bool.compare f f' with
    | 0 -> Grade.compare_array Int.compare a a'
    | c -> c
end)

(** [refine final delta classes] is one round of Moore's partition refinement
    (Moore, Automata Studies 1956) of the partition [classes] of the states of
    the table [delta] of successors by block, with its number of classes: two
    states stay together iff they agree on finality and on the classes of their
    successors. Classes are numbered in the order of their first member. *)
let refine final delta classes =
  let classify (seen, count) q =
    let signature = (final.(q), Array.map (Array.get classes) delta.(q)) in
    match Signatures.find_opt signature seen with
    | Some c -> ((seen, count), c)
    | None -> ((Signatures.add signature count seen, count + 1), count)
  in
  let (_, count), classes =
    List.fold_left_map classify (Signatures.empty, 0)
      (List.init (Array.length delta) Fun.id)
  in
  (count, Array.of_list classes)

(** [partition final delta] is the coarsest stable partition of the states: the
    classes of the states with equal languages. *)
let partition final delta =
  let rec go (count, classes) =
    let count', classes' = refine final delta classes in
    if count' = count then classes else go (count', classes')
  in
  go (1, Array.make (Array.length delta) 0)

(** [merge edges] joins the labels of the edges [edges] to the same target, and
    orders the edges by their labels. *)
let merge edges =
  let add merged (p, q) =
    match List.assoc_opt q merged with
    | Some p' -> (q, Letters.union p p') :: List.remove_assoc q merged
    | None -> (q, p) :: merged
  in
  List.fold_left add [] edges
  |> List.map (fun (q, p) -> (p, q))
  |> List.sort (fun (p, _) (p', _) -> Letters.order p p')

(** [number start next] numbers the states reachable from [start] by [next],
    listing the targets of the edges out of a state, in the order of their
    discovery by breadth-first search; it is the array of the states by number,
    and the numbering. *)
let number start next =
  let numbers = Hashtbl.create 16 in
  let queue = Queue.create () in
  let visit c =
    if not (Hashtbl.mem numbers c) then begin
      Hashtbl.add numbers c (Hashtbl.length numbers);
      Queue.push c queue
    end
  in
  let rec go order =
    match Queue.take_opt queue with
    | None -> List.rev order
    | Some c ->
        List.iter visit (next c);
        go (c :: order)
  in
  visit start;
  (Array.of_list (go []), Hashtbl.find numbers)

(** [blocks edges] is the coarsest partition of the letters that the labels of
    the rows [edges] of a table respect. *)
let blocks edges =
  Letters.partition
    (List.sort_uniq Letters.compare
       (List.concat_map (List.map fst) (Array.to_list edges)))

(* Minimisation by {!partition} over the blocks of the labels, then the
   breadth-first numbering of {!number}. *)
let of_table ~final ~edges =
  let n = Array.length final in
  if n = 0 || Array.length edges <> n then
    invalid_arg "SymbolicAutomaton.of_table: malformed table";
  let blocks = blocks edges in
  let delta =
    Array.map (fun es -> Array.of_list (List.map (target es) blocks)) edges
  in
  let classes = partition final delta in
  let member = Hashtbl.create 16 in
  Array.iteri
    (fun q c -> if not (Hashtbl.mem member c) then Hashtbl.add member c q)
    classes;
  let class_edges c =
    let q = Hashtbl.find member c in
    merge (List.mapi (fun i m -> (m, classes.(delta.(q).(i)))) blocks)
  in
  let order, number =
    number classes.(0) (fun c -> List.map snd (class_edges c))
  in
  {
    finals = Array.map (fun c -> final.(Hashtbl.find member c)) order;
    edges =
      Array.map
        (fun c -> List.map (fun (p, c') -> (p, number c')) (class_edges c))
        order;
  }

(** {1 Exploration} *)

(** [explore (module H) ~limit ~blocks ~final ~next start] is the canonical form
    of the automaton of the states reachable from [start], of which [final]
    tells the final ones and [next m s] is the successor of [s] by the block [m]
    of [blocks], explored breadth-first; it is [None] if more than [limit]
    states are reachable, the exploration stopping as soon as it finds them. *)
let explore (type s) (module H : Hashtbl.S with type key = s) ~limit ~blocks
    ~final ~next (start : s) =
  let ids = H.create 64 in
  let queue = Queue.create () in
  let id s =
    match H.find_opt ids s with
    | Some i -> i
    | None ->
        let i = H.length ids in
        H.add ids s i;
        Queue.push s queue;
        i
  in
  let rec go rows =
    if H.length ids > limit then None
    else
      match Queue.take_opt queue with
      | None -> Some (List.rev rows)
      | Some s ->
          go ((final s, List.map (fun m -> (m, id (next m s))) blocks) :: rows)
  in
  ignore (id start);
  Option.map
    (fun rows ->
      of_table
        ~final:(Array.of_list (List.map fst rows))
        ~edges:(Array.of_list (List.map snd rows)))
    (go [])

module Forms = Hashtbl.Make (struct
  type t = SymbolicRegex.t

  let equal = SymbolicRegex.equal_form
  let hash = SymbolicRegex.hash
end)

(* Brzozowski's automaton of derivatives (Brzozowski, JACM 1964), its states the
   normal forms of the derivatives and its edges labelled by the blocks of a
   partition, e.g. minterms, as in symbolic automata. *)
let of_derivatives ~limit ~blocks r =
  explore
    (module Forms)
    ~limit ~blocks ~final:SymbolicRegex.nullable ~next:SymbolicRegex.derivative
    r

let of_regex ~limit r =
  of_derivatives ~limit ~blocks:(SymbolicRegex.minterms r) r

module IntMap = Map.Make (Int)
module IntSet = Set.Make (Int)

module Subsets = Hashtbl.Make (struct
  type t = IntSet.t

  let equal = IntSet.equal
  let hash s = IntSet.fold (fun q h -> Grade.combine h q) s 0
end)

(* Brzozowski's reversal (Brzozowski, Symp. Math. Theory of Automata 1962): the
   subset construction on the reverse of a deterministic automaton whose states
   are all reachable, here [a], yields the minimal automaton of the reversed
   language. A state is the set of the states of [a] from which the words read
   so far, reversed, lead to a final state. *)
let reverse ~limit a =
  let all = List.init (states a) Fun.id in
  let predecessors m s =
    IntSet.of_list
      (List.filter (fun q -> IntSet.mem (target a.edges.(q) m) s) all)
  in
  explore
    (module Subsets)
    ~limit ~blocks:(blocks a.edges) ~final:(IntSet.mem 0) ~next:predecessors
    (IntSet.of_list (List.filter (final a) all))

(** {1 State elimination} *)

type graph = {
  out : LetterRegex.t list IntMap.t IntMap.t;
      (** the alternatives of the label of the edge [p → q], at [q] in the row
          of [p]; the label is their union, built when the edge is used, so that
          it is the union of all of them at once *)
  into : IntSet.t IntMap.t;  (** the sources of the edges into each node *)
}

let successors g p =
  Option.value (IntMap.find_opt p g.out) ~default:IntMap.empty

let predecessors g q =
  Option.value (IntMap.find_opt q g.into) ~default:IntSet.empty

(** [label g p q] is the label of the edge [p → q] of [g], if any. *)
let label g p q =
  Option.map LetterRegex.union (IntMap.find_opt q (successors g p))

(** [add_edge g (p, q, r)] adds an edge [p → q] labelled [r] to [g], joined with
    the edge [p → q] of [g], if any. *)
let add_edge g (p, q, r) =
  let row = successors g p in
  let alternatives = Option.value (IntMap.find_opt q row) ~default:[] in
  {
    out = IntMap.add p (IntMap.add q (r :: alternatives) row) g.out;
    into = IntMap.add q (IntSet.add p (predecessors g q)) g.into;
  }

let remove_node g k =
  let out =
    IntSet.fold
      (fun p out -> IntMap.add p (IntMap.remove k (successors g p)) out)
      (predecessors g k) g.out
  in
  let into =
    IntMap.fold
      (fun q _ into -> IntMap.add q (IntSet.remove k (predecessors g q)) into)
      (successors g k) g.into
  in
  { out = IntMap.remove k out; into = IntMap.remove k into }

(** [paths g k] is the number of paths through [k] in [g], its loop aside. *)
let paths g k =
  IntSet.cardinal (IntSet.remove k (predecessors g k))
  * IntMap.cardinal (IntMap.remove k (successors g k))

(** [eliminate ~budget g k] removes the node [k] from [g], each path [p → k → q]
    becoming an edge [p → q] labelled [x; y*; z], [y] the label of the loop at
    [k]: one step of state elimination (Brzozowski and McCluskey, IEEE Trans.
    Electronic Computers 1963). It is the graph with the largest size of the
    labels it uses, those of the edges into, out of and looping at [k], or
    [None] if that exceeds [budget]. *)
let eliminate ~budget g k =
  let loop = label g k k in
  let ins =
    List.map
      (fun p ->
        match label g p k with
        | Some x -> (p, x)
        | None ->
            invalid_arg
              "SymbolicAutomaton.eliminate: a predecessor without an edge")
      (IntSet.elements (IntSet.remove k (predecessors g k)))
  in
  let outs =
    List.map
      (fun (q, alternatives) -> (q, LetterRegex.union alternatives))
      (IntMap.bindings (IntMap.remove k (successors g k)))
  in
  let largest =
    List.fold_left max 0
      (List.map LetterRegex.size
         (Option.to_list loop @ List.map snd ins @ List.map snd outs))
  in
  let loop = Option.fold ~none:LetterRegex.eps ~some:LetterRegex.star loop in
  let bypass g (p, x) =
    List.fold_left
      (fun g (q, z) -> add_edge g (p, q, LetterRegex.seq [ x; loop; z ]))
      g outs
  in
  if largest > budget then None
  else Some (List.fold_left bypass (remove_node g k) ins, largest)

(** [eliminate_all ~budget g nodes] eliminates the [nodes], listed in increasing
    order, one by one, each time the first with the fewest paths through it. It
    is the graph with the largest size of the labels used, or [None] as soon as
    that exceeds [budget]. *)
let eliminate_all ~budget g nodes =
  let open Option.Syntax in
  let rec go (g, largest) = function
    | [] -> Some (g, largest)
    | k :: ks as nodes ->
        let fewer k k' = if paths g k' < paths g k then k' else k in
        let best = List.fold_left fewer k ks in
        let* g, used = eliminate ~budget g best in
        go
          (g, max largest used)
          (List.filter (fun k -> not (Int.equal k best)) nodes)
  in
  go (g, 0) nodes

(** [live a] marks the states of [a] from which a final state is reachable, the
    least fixed point of backward reachability from the final states, by
    iteration. *)
let live a =
  let reaches marked q = List.exists (fun (_, q') -> marked.(q')) a.edges.(q) in
  let rec grow marked =
    let marked' = Array.mapi (fun q m -> m || reaches marked q) marked in
    if Array.for_all2 Bool.equal marked' marked then marked else grow marked'
  in
  grow a.finals

(** [elimination ~budget a] is the expression of [a] by state elimination, with
    the largest size of the labels used, itself included, or [None] as soon as
    that exceeds [budget]. *)
let elimination ~budget a =
  let open Option.Syntax in
  let n = states a in
  let source = n and sink = n + 1 in
  let live = live a in
  let nodes = List.filter (Array.get live) (List.init n Fun.id) in
  let edges q =
    List.filter_map
      (fun (p, q') ->
        if live.(q') then Some (q, q', LetterRegex.letters p) else None)
      a.edges.(q)
    @ if a.finals.(q) then [ (q, sink, LetterRegex.eps) ] else []
  in
  let initial =
    List.fold_left add_edge
      { out = IntMap.empty; into = IntMap.empty }
      ((source, 0, LetterRegex.eps) :: List.concat_map edges nodes)
  in
  let* g, largest = eliminate_all ~budget initial nodes in
  let r = Option.value (label g source sink) ~default:LetterRegex.empty in
  let largest = max largest (LetterRegex.size r) in
  if largest > budget then None else Some (r, largest)

let to_regex ~budget a = Option.map fst (elimination ~budget a)

(** {1 Printing} *)

(** [candidate ~budget ~states finish a] is the candidate [finish r], [r] the
    expression of [a] by state elimination, with its cost: the largest of
    [states], the sizes of the labels the elimination uses and the size of the
    candidate; it is [None] if the cost exceeds [budget]. *)
let candidate ~budget ~states finish a =
  let open Option.Syntax in
  let* r, largest = elimination ~budget a in
  let r = finish r in
  let cost = max states (max largest (LetterRegex.size r)) in
  if cost > budget then None else Some (cost, r)

let canonical ~budget a =
  let n = states a in
  let key (cost, r) = (cost, LetterRegex.size r) in
  let compare_key (c, s) (c', s') =
    match Int.compare c c' with 0 -> Int.compare s s' | k -> k
  in
  let least best c = if compare_key (key c) (key best) < 0 then c else best in
  if n > budget then None
  else
    let reversed =
      Option.bind (reverse ~limit:budget a) (fun a' ->
          candidate ~budget ~states:(max n (states a')) LetterRegex.reverse a')
    in
    match
      List.filter_map Fun.id
        [
          candidate ~budget ~states:n Fun.id a;
          candidate ~budget ~states:n LetterRegex.compl (complement a);
          reversed;
        ]
    with
    | [] -> None
    | c :: cs -> Some (snd (List.fold_left least c cs))
