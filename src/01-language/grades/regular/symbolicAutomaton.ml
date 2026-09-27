module Letters = SymbolicRegex.Letters

type t = { finals : bool array; edges : (Letters.t * int) list array }
(* State [0] is the start; [edges.(q)] lists the edges out of [q] in the order
   of their labels. *)

let equal (a : t) b = a = b
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

module Signatures = Map.Make (struct
  type t = bool * int array

  let compare = Stdlib.compare
end)

(** [refine final delta classes] is the Moore refinement of the partition
    [classes] of the states of the table [delta] of successors by block, with
    its number of classes: two states stay together iff they agree on finality
    and on the classes of their successors. Classes are numbered in the order of
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
    listing the targets of the edges out of a state, breadth-first; it is the
    array of the states by number, and the numbering. *)
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

let of_table ~final ~edges =
  let n = Array.length final in
  if n = 0 || Array.length edges <> n then
    invalid_arg "SymbolicAutomaton.of_table: malformed table";
  let blocks =
    Letters.partition
      (List.sort_uniq Letters.compare
         (List.concat_map (List.map fst) (Array.to_list edges)))
  in
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

(** {1 Derivatives} *)

module Forms = Hashtbl.Make (struct
  type t = SymbolicRegex.t

  let equal = SymbolicRegex.equal_form
  let hash = SymbolicRegex.hash
end)

let of_regex ~limit r =
  let blocks = SymbolicRegex.minterms r in
  let ids = Forms.create 64 in
  let queue = Queue.create () in
  let id d =
    match Forms.find_opt ids d with
    | Some i -> i
    | None ->
        let i = Forms.length ids in
        Forms.add ids d i;
        Queue.push d queue;
        i
  in
  let rec explore rows =
    if Forms.length ids > limit then None
    else
      match Queue.take_opt queue with
      | None -> Some (List.rev rows)
      | Some d ->
          let row =
            List.map (fun m -> (m, id (SymbolicRegex.derivative m d))) blocks
          in
          explore ((SymbolicRegex.nullable d, row) :: rows)
  in
  ignore (id r);
  Option.map
    (fun rows ->
      of_table
        ~final:(Array.of_list (List.map fst rows))
        ~edges:(Array.of_list (List.map snd rows)))
    (explore [])

(** {1 State elimination} *)

module IntMap = Map.Make (Int)
module IntSet = Set.Make (Int)

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

(** [eliminate g k] removes the node [k] from [g], each path [p → k → q]
    becoming an edge [p → q] labelled [x; y*; z], [y] the label of the loop at
    [k]. *)
let eliminate g k =
  let loop =
    Option.fold ~none:LetterRegex.eps ~some:LetterRegex.star (label g k k)
  in
  let ins =
    List.map
      (fun p -> (p, Option.get (label g p k)))
      (IntSet.elements (IntSet.remove k (predecessors g k)))
  in
  let outs =
    List.map
      (fun (q, alternatives) -> (q, LetterRegex.union alternatives))
      (IntMap.bindings (IntMap.remove k (successors g k)))
  in
  let bypass g (p, x) =
    List.fold_left
      (fun g (q, z) -> add_edge g (p, q, LetterRegex.seq [ x; loop; z ]))
      g outs
  in
  List.fold_left bypass (remove_node g k) ins

(** [eliminate_all g nodes] eliminates the [nodes], listed in increasing order,
    one by one, each time the first with the fewest paths through it. *)
let rec eliminate_all g = function
  | [] -> g
  | k :: ks as nodes ->
      let fewer k k' = if paths g k' < paths g k then k' else k in
      let best = List.fold_left fewer k ks in
      eliminate_all (eliminate g best) (List.filter (( <> ) best) nodes)

(** [live a] marks the states of [a] from which a final state is reachable. *)
let live a =
  let reaches marked q = List.exists (fun (_, q') -> marked.(q')) a.edges.(q) in
  let rec grow marked =
    let marked' = Array.mapi (fun q m -> m || reaches marked q) marked in
    if marked' = marked then marked else grow marked'
  in
  grow a.finals

let to_regex a =
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
  let g = eliminate_all initial nodes in
  Option.value (label g source sink) ~default:LetterRegex.empty

(** {1 Printing} *)

let show ~others a =
  if states a = 1 && final a 0 then "⊤"
  else
    let candidates =
      to_regex a :: LetterRegex.compl (to_regex (complement a)) :: others
    in
    "{" ^ LetterRegex.to_string (LetterRegex.smallest candidates) ^ "}"
