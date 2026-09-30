module Letters = SymbolicRegex.Letters
module Fifo = Dfa.Fifo
module IntMap = Map.Make (Int)

module Class = struct
  type t = Letters.t

  let all = Letters.others []
  let name = Letters.name
  let union = Letters.union
  let inter = Letters.inter
  let compl c = Letters.inter (Letters.compl c) all
  let is_empty = Letters.is_empty
  let compare = Letters.compare

  let names (c : t) =
    match c.names with Letters.Only names | Letters.Except names -> names

  let hash (c : t) =
    match c.names with
    | Letters.Only names -> Grade.hash_list String.hash names
    | Letters.Except names ->
        Grade.combine 1 (Grade.hash_list String.hash names)
end

(* {1 Deterministic automata} *)

type t = {
  gaps : (DelaySet.t * int) array array;
  ops : (Class.t * int) array array;
  final : bool array;
}
(* Row [g] of [gaps] lists the transitions of gap state [g] to operation
   states, and row [o] of [ops] those of operation state [o] to gap states;
   gap state [0] is the start, and [final] marks the final operation states.
   The labels of the transitions of a state partition the delays, respectively
   the names. The arrays are not mutated after construction. *)

(* The breadth-first exploration of the deterministic automata whose gap states
   are ordered by [G.compare] and operation states by [O.compare]. *)
module Explore (G : Map.OrderedType) (O : Map.OrderedType) = struct
  module Gs = Map.Make (G)
  module Os = Map.Make (O)

  (* [table ~start ~gap ~op ~final] is the table of the states reachable from
     the gap state [start], each kind numbered in the order of its discovery by
     breadth-first search, the transitions of a state in the order [gap] and
     [op] list them: [gap g] lists the transitions of the gap state [g] and
     [op o] those of the operation state [o]. *)
  let table ~start ~gap ~op ~final =
    let visit ids count fifo wrap find add state =
      match find state ids with
      | Some n -> (ids, count, fifo, n)
      | None ->
          (add state count ids, count + 1, Fifo.push (wrap state) fifo, count)
    in
    let rec go (gids, gn, oids, on, fifo) gaps ops finals =
      match Fifo.pop fifo with
      | None ->
          {
            gaps = Array.of_list (List.rev gaps);
            ops = Array.of_list (List.rev ops);
            final = Array.of_list (List.rev finals);
          }
      | Some (`Gap g, fifo) ->
          let (oids, on, fifo), row =
            List.fold_left_map
              (fun (oids, on, fifo) (s, o) ->
                let oids, on, fifo, n =
                  visit oids on fifo (fun o -> `Op o) Os.find_opt Os.add o
                in
                ((oids, on, fifo), (s, n)))
              (oids, on, fifo) (gap g)
          in
          go (gids, gn, oids, on, fifo) (Array.of_list row :: gaps) ops finals
      | Some (`Op o, fifo) ->
          let (gids, gn, fifo), row =
            List.fold_left_map
              (fun (gids, gn, fifo) (c, g) ->
                let gids, gn, fifo, n =
                  visit gids gn fifo (fun g -> `Gap g) Gs.find_opt Gs.add g
                in
                ((gids, gn, fifo), (c, n)))
              (gids, gn, fifo) (op o)
          in
          go (gids, gn, oids, on, fifo) gaps (Array.of_list row :: ops)
            (final o :: finals)
    in
    go
      (Gs.singleton start 0, 1, Os.empty, 0, Fifo.push (`Gap start) Fifo.empty)
      [] [] []
end

module Ints = Explore (Int) (Int)

(* {2 Canonical form} *)

(* [classify compare signatures] numbers the distinct elements of the array
   [signatures] in increasing order, and is the number of each and their
   count. *)
let classify compare signatures =
  let sorted =
    List.stable_sort
      (fun (_, s) (_, s') -> compare s s')
      (List.mapi (fun i s -> (i, s)) (Array.to_list signatures))
  in
  let _, count, ids =
    List.fold_left
      (fun (previous, count, ids) (i, s) ->
        let count =
          match previous with
          | Some p when compare p s = 0 -> count
          | _ -> count + 1
        in
        (Some s, count, IntMap.add i (count - 1) ids))
      (None, 0, IntMap.empty) sorted
  in
  (Array.init (Array.length signatures) (fun i -> IntMap.find i ids), count)

(* [merge union edges] is the transitions [edges] with the labels of those to
   the same target merged by [union], ordered by target. *)
let merge union edges =
  IntMap.bindings
    (List.fold_left
       (fun m (label, target) ->
         IntMap.update target
           (function None -> Some label | Some l -> Some (union l label))
           m)
       IntMap.empty edges)

let compare_signature compare_label (c, edges) (c', edges') =
  match Int.compare c c' with
  | 0 ->
      List.compare
        (fun (t, l) (t', l') ->
          match Int.compare t t' with 0 -> compare_label l l' | c -> c)
        edges edges'
  | c -> c

(* [canonical d] is the canonical form of the complete deterministic automaton
   [d]: its quotient by Moore's partition refinement (Moore, Automata Studies
   1956), each round splitting the classes of states by their class and the
   merged labels of their transitions to each class, until the number of
   classes is stable, explored breadth-first from the class of the start, the
   transitions of a class ordered by their labels. The quotient is the minimal
   automaton, and the numbering fixes its isomorphism. *)
let canonical d =
  let signatures gcls ocls =
    ( Array.map
        (fun row ->
          merge DelaySet.union
            (List.map (fun (s, o) -> (s, ocls.(o))) (Array.to_list row)))
        d.gaps,
      Array.map
        (fun row ->
          merge Class.union
            (List.map (fun (c, g) -> (c, gcls.(g))) (Array.to_list row)))
        d.ops )
  in
  let with_classes cls = Array.mapi (fun i edges -> (cls.(i), edges)) in
  let rec refine (gcls, gn) (ocls, on) =
    let gsig, osig = signatures gcls ocls in
    let gcls', gn' =
      classify (compare_signature DelaySet.compare) (with_classes gcls gsig)
    in
    let ocls', on' =
      classify (compare_signature Class.compare) (with_classes ocls osig)
    in
    if gn' = gn && on' = on then (gcls, ocls, gsig, osig)
    else refine (gcls', gn') (ocls', on')
  in
  let gcls, ocls, gsig, osig =
    refine
      (Array.make (Array.length d.gaps) 0, 1)
      (classify Bool.compare d.final)
  in
  (* The first member of each class. *)
  let representatives cls =
    Array.fold_left
      (fun (i, reps) c ->
        (i + 1, if IntMap.mem c reps then reps else IntMap.add c i reps))
      (0, IntMap.empty) cls
    |> snd
  in
  let greps = representatives gcls and oreps = representatives ocls in
  let sorted compare_label edges =
    List.sort
      (fun (l, _) (l', _) -> compare_label l l')
      (List.map (fun (t, l) -> (l, t)) edges)
  in
  Ints.table ~start:gcls.(0)
    ~gap:(fun c -> sorted DelaySet.compare gsig.(IntMap.find c greps))
    ~op:(fun c -> sorted Class.compare osig.(IntMap.find c oreps))
    ~final:(fun c -> d.final.(IntMap.find c oreps))

(* {2 Equality} *)

let compare_rows compare_label =
  Grade.compare_array (fun (l, t) (l', t') ->
      match compare_label l l' with 0 -> Int.compare t t' | c -> c)

let compare l m =
  match Grade.compare_array Bool.compare l.final m.final with
  | 0 -> (
      match
        Grade.compare_array (compare_rows DelaySet.compare) l.gaps m.gaps
      with
      | 0 -> Grade.compare_array (compare_rows Class.compare) l.ops m.ops
      | c -> c)
  | c -> c

let equal l m = compare l m = 0

let hash l =
  let row hash_label r =
    Array.fold_left
      (fun h (label, t) -> Grade.combine h (Grade.combine (hash_label label) t))
      0 r
  in
  let table hash_label t =
    Array.fold_left (fun h r -> Grade.combine h (row hash_label r)) 0 t
  in
  Grade.combine
    (table DelaySet.hash l.gaps)
    (Grade.combine (table Class.hash l.ops)
       (Array.fold_left (fun h b -> Grade.combine h (Bool.to_int b)) 0 l.final))

(* {2 Tables}

   The results of the binary operations and of the inclusion search, tabulated
   by their arguments in module-level tables, which only ever grow; an
   implementation device invisible through the interface. *)

module Pairs = Hashtbl.Make (struct
  type nonrec t = t * t

  let equal (l, m) (l', m') = equal l l' && equal m m'
  let hash (l, m) = Grade.combine (hash l) (hash m)
end)

let tabulated f =
  let table = Pairs.create 64 in
  fun l m ->
    match Pairs.find_opt table (l, m) with
    | Some r -> r
    | None ->
        let r = f l m in
        Pairs.add table (l, m) r;
        r

(* {1 Raw automata} *)

type raw = {
  size : int;
  starts : int list;
  accepts : int list;
  delay_moves : (int * DelaySet.t * int) list;
  op_moves : (int * Class.t * int) list;
}
(* The states are [0, …, size - 1]. *)

(* [gap_closure raw] maps each state [p] to the map from each state [q] to the
   non-empty set [Γ(p, q)] of the sums of the delays along the paths of delay
   transitions from [p] to [q], [{0}] included for the empty path from [p] to
   itself. It is Kleene's algorithm over the semiring of the sets of delays:
   for [k = 0, …, size - 1] in turn,
   [Γ(i, j) ∪= Γ(i, k) + Γ(k, k)* + Γ(k, j)], the right-hand sides read before
   the round, over the non-empty entries only. *)
let gap_closure raw =
  let add i j s g =
    IntMap.update i
      (fun row ->
        Some
          (IntMap.update j
             (function None -> Some s | Some s' -> Some (DelaySet.union s s'))
             (Option.value row ~default:IntMap.empty)))
      g
  in
  let states = List.init raw.size Fun.id in
  let round g k =
    match IntMap.find_opt k g with
    | None -> g
    | Some row ->
        let loop =
          match IntMap.find_opt k row with
          | Some s -> DelaySet.star s
          | None -> DelaySet.zero
        in
        IntMap.fold
          (fun i row_i g' ->
            match IntMap.find_opt k row_i with
            | None -> g'
            | Some s ->
                let a = DelaySet.sum s loop in
                IntMap.fold (fun j b g' -> add i j (DelaySet.sum a b) g') row g')
          g g
  in
  let g =
    List.fold_left round
      (List.fold_left
         (fun g (i, s, j) -> if DelaySet.is_empty s then g else add i j s g)
         IntMap.empty raw.delay_moves)
      states
  in
  List.fold_left (fun g p -> add p p DelaySet.zero g) g states

module Subsets =
  Explore
    (struct
      type t = int list

      let compare = List.compare Int.compare
    end)
    (struct
      type t = int list

      let compare = List.compare Int.compare
    end)

(* [local_successors ~all ~inter ~diff ~is_empty ~union labels] is the
   transitions of a subset whose members have the transitions [labels]: its
   successor by each minterm of the labels, the set of the targets of the
   labels containing it, the minterms of the same successor merged by
   [union]. The minterms are found by splitting every block by each label in
   turn, which records the labels containing each block. *)
let local_successors ~all ~inter ~diff ~is_empty ~union labels =
  let module Targets = Map.Make (struct
    type t = int list

    let compare = List.compare Int.compare
  end) in
  let split blocks (label, target) =
    List.concat_map
      (fun (block, targets) ->
        List.filter
          (fun (b, _) -> not (is_empty b))
          [
            (inter block label, target :: targets); (diff block label, targets);
          ])
      blocks
  in
  Targets.bindings
    (List.fold_left
       (fun m (block, targets) ->
         Targets.update
           (List.sort_uniq Int.compare targets)
           (function None -> Some block | Some b -> Some (union b block))
           m)
       Targets.empty
       (List.fold_left split [ (all, []) ] labels))
  |> List.map (fun (targets, label) -> (label, targets))

(* [determinise raw] is the canonical automaton of the normal form of [raw],
   whose gap states [p̂] and operation states [p̌] are those of [raw]: [p̂] moves
   to [q̌] on [Γ(p, q)], and [p̌] to [q̂] on the operation transitions from [p]
   to [q]; the start is the gap state of the starts of [raw], and the final
   states the operation states of its accepting states. It is the subset
   construction over the minterms of the labels leaving each subset, as for
   symbolic automata (D'Antoni and Veanes, POPL 2014), the empty subsets being
   the sinks. *)
let determinise raw =
  let closure = gap_closure raw in
  let gap_labels p =
    List.map
      (fun (q, s) -> (s, q))
      (IntMap.bindings
         (Option.value (IntMap.find_opt p closure) ~default:IntMap.empty))
  in
  let op_edges =
    List.fold_left
      (fun m (p, c, q) -> IntMap.add_to_list p (c, q) m)
      IntMap.empty raw.op_moves
  in
  let op_labels p = Option.value (IntMap.find_opt p op_edges) ~default:[] in
  canonical
    (Subsets.table
       ~start:(List.sort_uniq Int.compare raw.starts)
       ~gap:(fun subset ->
         local_successors ~all:DelaySet.all ~inter:DelaySet.inter
           ~diff:DelaySet.diff ~is_empty:DelaySet.is_empty ~union:DelaySet.union
           (List.concat_map gap_labels subset))
       ~op:(fun subset ->
         local_successors ~all:Class.all ~inter:Class.inter
           ~diff:(fun b c -> Class.inter b (Class.compl c))
           ~is_empty:Class.is_empty ~union:Class.union
           (List.concat_map op_labels subset))
       ~final:(List.exists (fun p -> List.mem p raw.accepts)))

(* [live d] is the gap and the operation states of [d] from which a final state
   is reachable, the least fixpoint from the final states. *)
let live d =
  let step (live_gap, live_op) =
    ( Array.map (Array.exists (fun (_, o) -> live_op.(o))) d.gaps,
      Array.mapi
        (fun o row ->
          d.final.(o) || Array.exists (fun (_, g) -> live_gap.(g)) row)
        d.ops )
  in
  let rec fix states =
    let states' = step states in
    if states' = states then states else fix states'
  in
  fix (Array.make (Array.length d.gaps) false, d.final)

(* [to_raw d] is the raw automaton of [d] without the states from which no
   final state is reachable: gap state [g] is state [g], and operation state
   [o] is state [ng + o], [ng] the number of gap states. *)
let to_raw d =
  let ng = Array.length d.gaps and no = Array.length d.ops in
  let live_gap, live_op = live d in
  let moves live live' rows =
    List.concat
      (List.mapi
         (fun p row ->
           if live.(p) then
             List.filter_map
               (fun (l, q) -> if live'.(q) then Some (p, l, q) else None)
               (Array.to_list row)
           else [])
         (Array.to_list rows))
  in
  {
    size = ng + no;
    starts = (if live_gap.(0) then [ 0 ] else []);
    accepts =
      List.filter_map
        (fun o -> if d.final.(o) then Some (ng + o) else None)
        (List.init no Fun.id);
    delay_moves =
      List.map (fun (g, s, o) -> (g, s, ng + o)) (moves live_gap live_op d.gaps);
    op_moves =
      List.map (fun (o, c, g) -> (ng + o, c, g)) (moves live_op live_gap d.ops);
  }

let shift_raw k raw =
  {
    raw with
    starts = List.map (( + ) k) raw.starts;
    accepts = List.map (( + ) k) raw.accepts;
    delay_moves = List.map (fun (p, s, q) -> (p + k, s, q + k)) raw.delay_moves;
    op_moves = List.map (fun (p, c, q) -> (p + k, c, q + k)) raw.op_moves;
  }

(* {1 Constructions} *)

let single_move ~delay ~op =
  determinise
    {
      size = 2;
      starts = [ 0 ];
      accepts = [ 1 ];
      delay_moves = Option.to_list (Option.map (fun s -> (0, s, 1)) delay);
      op_moves = Option.to_list (Option.map (fun c -> (0, c, 1)) op);
    }

let delays s = single_move ~delay:(Some s) ~op:None
let operations c = single_move ~delay:None ~op:(Some c)
let empty = delays DelaySet.empty
let epsilon = delays DelaySet.zero

(* Thompson's construction: the accepting states of [l] move to the start of
   [m] on the delay [0], and the gap closure adds the delays that meet. *)
let concat =
  tabulated @@ fun l m ->
  let a = to_raw l in
  let b = shift_raw a.size (to_raw m) in
  determinise
    {
      size = a.size + b.size;
      starts = a.starts;
      accepts = b.accepts;
      delay_moves =
        a.delay_moves @ b.delay_moves
        @ List.concat_map
            (fun f -> List.map (fun s -> (f, DelaySet.zero, s)) b.starts)
            a.accepts;
      op_moves = a.op_moves @ b.op_moves;
    }

(* Thompson's construction: a new start, also accepting, moves to the start of
   [l], and the accepting states of [l] back to it, on the delay [0]. *)
let star l =
  let a = to_raw l in
  let z = a.size in
  determinise
    {
      size = a.size + 1;
      starts = [ z ];
      accepts = [ z ];
      delay_moves =
        a.delay_moves
        @ List.map (fun s -> (z, DelaySet.zero, s)) a.starts
        @ List.map (fun f -> (f, DelaySet.zero, z)) a.accepts;
      op_moves = a.op_moves;
    }

module Pair = struct
  type t = int * int

  let compare (p, q) (p', q') =
    match Int.compare p p' with 0 -> Int.compare q q' | c -> c
end

module Products = Explore (Pair) (Pair)

(* [pairs inter is_empty row row'] is the transitions of a pair of states with
   the transitions [row] and [row']: the non-empty intersections of their
   labels, to the pairs of their targets. *)
let pairs inter is_empty row row' =
  List.concat_map
    (fun (s, x) ->
      List.filter_map
        (fun (s', y) ->
          let i = inter s s' in
          if is_empty i then None else Some (i, (x, y)))
        (Array.to_list row'))
    (Array.to_list row)

(* The product construction (Rabin and Scott, IBM J. Res. Dev. 1959) over the
   reachable pairs, an operation state final iff [combine] holds of the
   finality of its components. *)
let product combine l m =
  canonical
    (Products.table ~start:(0, 0)
       ~gap:(fun (x, y) ->
         pairs DelaySet.inter DelaySet.is_empty l.gaps.(x) m.gaps.(y))
       ~op:(fun (x, y) -> pairs Class.inter Class.is_empty l.ops.(x) m.ops.(y))
       ~final:(fun (x, y) -> combine l.final.(x) m.final.(y)))

let union = tabulated (product ( || ))
let inter = tabulated (product ( && ))

(* Flipping the final states of a canonical automaton keeps it minimal and its
   numbering breadth-first. *)
let compl l = { l with final = Array.map not l.final }
let universal = compl empty

(* {1 Decisions} *)

(* The states of a canonical automaton are all reachable. *)
let is_empty l = not (Array.mem true l.final)

type symbol = Delay of Rational.t | Operation of Class.t

module Visited = Map.Make (struct
  type t = [ `Gap of Pair.t | `Op of Pair.t ]

  let compare a b =
    match (a, b) with
    | `Gap p, `Gap q | `Op p, `Op q -> Pair.compare p q
    | `Gap _, `Op _ -> -1
    | `Op _, `Gap _ -> 1
end)

(* The breadth-first search of the pairs of states of [l] and [m] for an
   operation state final in [l] and not in [m], each pair recording the pair it
   was reached from and the symbol read. *)
let counterexample =
  tabulated @@ fun l m ->
  let rec path parent key acc =
    match Visited.find key parent with
    | None -> acc
    | Some (key', symbol) -> path parent key' (symbol :: acc)
  in
  let visit (parent, fifo) (key, from) =
    if Visited.mem key parent then (parent, fifo)
    else (Visited.add key (Some from) parent, Fifo.push key fifo)
  in
  let rec search (parent, fifo) =
    match Fifo.pop fifo with
    | None -> None
    | Some ((`Op (x, y) as key), _) when l.final.(x) && not m.final.(y) ->
        Some (path parent key [])
    | Some ((`Gap (x, y) as key), fifo) ->
        search
          (List.fold_left visit (parent, fifo)
             (List.map
                (fun (s, pair) ->
                  (`Op pair, (key, Delay (Option.get (DelaySet.choose s)))))
                (pairs DelaySet.inter DelaySet.is_empty l.gaps.(x) m.gaps.(y))))
    | Some ((`Op (x, y) as key), fifo) ->
        search
          (List.fold_left visit (parent, fifo)
             (List.map
                (fun (c, pair) -> (`Gap pair, (key, Operation c)))
                (pairs Class.inter Class.is_empty l.ops.(x) m.ops.(y))))
  in
  if equal l m then None
  else
    search
      (Visited.singleton (`Gap (0, 0)) None, Fifo.push (`Gap (0, 0)) Fifo.empty)

let subset l m = Option.is_none (counterexample l m)

let mem word l =
  (* The word in gap form: adjacent delays added, operations separating
     them. *)
  let rec gap_form acc d = function
    | [] -> List.rev (Delay d :: acc)
    | Delay e :: rest -> gap_form acc (Rational.add d e) rest
    | (Operation _ as a) :: rest ->
        gap_form (a :: Delay d :: acc) Rational.zero rest
  in
  let gap state d =
    Option.map snd
      (Array.find_opt (fun (s, _) -> DelaySet.mem d s) l.gaps.(state))
  in
  let op state c =
    Option.map snd
      (Array.find_opt
         (fun (c', _) -> not (Class.is_empty (Class.inter c c')))
         l.ops.(state))
  in
  let rec run state = function
    | [ Delay d ] ->
        Option.fold ~none:false ~some:(Array.get l.final) (gap state d)
    | Delay d :: Operation c :: rest -> (
        match Option.bind (gap state d) (fun o -> op o c) with
        | Some g -> run g rest
        | None -> false)
    | _ -> false
  in
  run 0 (gap_form [] Rational.zero word)

(* {1 Inspection} *)

let delay_part l =
  Array.fold_left
    (fun acc (s, o) -> if l.final.(o) then DelaySet.union acc s else acc)
    DelaySet.empty l.gaps.(0)

let names l =
  List.sort_uniq String.compare
    (List.concat_map
       (fun row ->
         List.concat_map (fun (c, _) -> Class.names c) (Array.to_list row))
       (Array.to_list l.ops))

let states l = Array.length l.gaps + Array.length l.ops
