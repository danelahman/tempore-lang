module A = DelayAutomaton
module IntMap = Map.Make (Int)
module IntSet = Set.Make (Int)
module Fifo = Dfa.Fifo

(* {1 Extremal values} *)

type value = DelaySet.extremum = Finite of Rational.t * bool | Infinite
(* [Finite (a, true)] is [a]; [Finite (a, false)] is [a] approached from below
   in the allowance domain and from above in the coverage domain. *)

type world = (string * value) list

let exact q = Finite (q, true)
let zero = exact Rational.zero

let add x y =
  match (x, y) with
  | Finite (a, f), Finite (b, g) -> Finite (Rational.add a b, f && g)
  | Infinite, _ | _, Infinite -> Infinite

(* An order of extremal values: the domain of suprema, [a⁻ < a], or of infima,
   [a < a⁺], with the extremal value of a set of delays in it and [passes x t],
   whether a weight [x] is admitted by a set of delays of extremal value [t]. *)
type domain = {
  compare : value -> value -> int;
  passes : value -> value -> bool;
  extremum : DelaySet.t -> value option;
}

let compare_with flags x y =
  match (x, y) with
  | Infinite, Infinite -> 0
  | Infinite, Finite _ -> 1
  | Finite _, Infinite -> -1
  | Finite (a, f), Finite (b, g) -> (
      match Rational.compare a b with 0 -> flags f g | c -> c)

(* Suprema: [x ⊴ t] iff some delay of a set of supremum [t] is at least [x]. *)
let down =
  {
    compare = compare_with Bool.compare;
    passes =
      (fun x t ->
        match (x, t) with
        | _, Infinite -> true
        | Infinite, Finite _ -> false
        | Finite (a, f), Finite (c, g) ->
            let k = Rational.compare a c in
            k < 0 || (k = 0 && (g || not f)));
    extremum = DelaySet.sup;
  }

(* Infima: [x ⊵ t] iff some delay of a set of infimum [t] is at most [x]. *)
let up =
  {
    compare = compare_with (fun f g -> Bool.compare g f);
    passes =
      (fun x t ->
        match (x, t) with
        | Infinite, _ -> true
        | Finite _, Infinite -> false
        | Finite (b, f), Finite (c, g) ->
            let k = Rational.compare b c in
            k > 0 || (k = 0 && (g || not f)));
    extremum = DelaySet.inf;
  }

let greater domain x y = if domain.compare x y >= 0 then x else y
let lesser domain x y = if domain.compare x y <= 0 then x else y
let is_finite = function Finite _ -> true | Infinite -> false

(* {1 Automata over the operations of a comparison} *)

type graph = {
  gaps : (DelaySet.t * int) list array;
  ops : (string * int) list array;
  final : bool array;
  live : bool;
}
(* The automaton of a language over the names of a comparison, restricted to
   its live states, from which a final state is reachable: row [g] of [gaps]
   lists the transitions of the gap state [g], row [o] of [ops] those of the
   operation state [o] by each name; the rows of the other states are empty.
   [live] is whether the start is live, i.e. whether the language has a word
   over the names. *)

let graph ~gaps ~ops ~final =
  let ng = Array.length gaps in
  (* The least fixpoint of liveness from the final states. *)
  let step (live_gap, live_op) =
    ( Array.map (List.exists (fun (_, o) -> live_op.(o))) gaps,
      Array.mapi
        (fun o row -> final.(o) || List.exists (fun (_, g) -> live_gap.(g)) row)
        ops )
  in
  let same (g, o) (g', o') =
    Array.for_all2 Bool.equal g g' && Array.for_all2 Bool.equal o o'
  in
  let rec fix states =
    let states' = step states in
    if same states' states then states else fix states'
  in
  let live_gap, live_op = fix (Array.make ng false, final) in
  let keep live' live row =
    if live then List.filter (fun (_, q) -> live'.(q)) row else []
  in
  {
    gaps = Array.mapi (fun g row -> keep live_op live_gap.(g) row) gaps;
    ops = Array.mapi (fun o row -> keep live_gap live_op.(o) row) ops;
    final = Array.mapi (fun o f -> f && live_op.(o)) final;
    live = ng > 0 && live_gap.(0);
  }

let member name c = not (A.Class.is_empty (A.Class.inter (A.Class.name name) c))

let of_automaton names l =
  let ops =
    Array.init (A.operation_states l) (fun o ->
        List.filter_map
          (fun name ->
            List.find_map
              (fun (c, g) -> if member name c then Some (name, g) else None)
              (A.operation_transitions l o))
          names)
  in
  graph
    ~gaps:(Array.init (A.gap_states l) (A.gap_transitions l))
    ~ops
    ~final:(Array.init (A.operation_states l) (A.final l))

(* {1 Longest and shortest paths} *)

(* The graph of an automaton: gap state [g] is node [g] and operation state [o]
   node [ng + o], [ng] the number of gap states; [edges ~gap ~op a] is the
   array of the weighted edges out of each node, a transition by a set of
   delays [s] weighing [gap s] and one by a name [name] weighing [op name]. *)
let edges ~gap ~op (a : graph) =
  let ng = Array.length a.gaps in
  Array.append
    (Array.map (List.map (fun (s, o) -> (ng + o, gap s))) a.gaps)
    (Array.map (List.map (fun (name, g) -> (g, op name))) a.ops)

(* [paths ~add ~better ~cycle zero edges source] is the best weight of a path
   from the node [source] to each node, [None] if there is none, over the graph
   of the weighted edges [edges], the weight of a path the sum by [add] of the
   weights of its edges from [zero]. It is the label-correcting form of
   Bellman–Ford with a queue (Moore, "The shortest path through a maze",
   1959): a node whose weight becomes [better] is queued to relax its edges; a
   weight [x] reached along a path of as many edges as the graph has nodes,
   which then goes round a cycle that improves it, is replaced by [cycle x]. *)
let paths ~add ~better ~cycle zero edges source =
  let n = Array.length edges in
  let improve (weights, fifo) (v, x, length) =
    let x = if length >= n then cycle x else x in
    match IntMap.find_opt v weights with
    | Some (y, _) when not (better x y) -> (weights, fifo)
    | _ -> (IntMap.add v (x, length) weights, Fifo.push v fifo)
  in
  let rec relax (weights, fifo) =
    match Fifo.pop fifo with
    | None -> weights
    | Some (u, fifo) ->
        let x, length = IntMap.find u weights in
        relax
          (List.fold_left
             (fun acc (v, w) -> improve acc (v, add x w, length + 1))
             (weights, fifo) edges.(u))
  in
  let weights =
    relax (IntMap.singleton source (zero, 0), Fifo.push source Fifo.empty)
  in
  Array.init n (fun v -> Option.map fst (IntMap.find_opt v weights))

(* [longest edges source] is the greatest weight in the domain of suprema of a
   path from [source] to each node, the weights of the edges at least [0], and
   infinity where a cycle of positive weight is on the way. *)
let longest =
  paths ~add
    ~better:(fun x y -> down.compare x y > 0)
    ~cycle:(Fun.const Infinite) zero

let finite_part = function Finite (q, f) -> Some (q, f) | Infinite -> None

let running_time_of world name =
  match List.assoc_opt name world with
  | Some c -> c
  | None ->
      invalid_arg
        ("DelayTimedClosure.running_time_of: the name " ^ name
       ^ " is not an operation of the world")

let max_weight world (a : graph) =
  if not a.live then None
  else
    let ng = Array.length a.gaps in
    let d =
      longest
        (edges
           ~gap:(fun s -> Option.value (DelaySet.sup s) ~default:zero)
           ~op:(running_time_of world) a)
        0
    in
    Array.to_list a.final
    |> List.mapi (fun o f -> if f then d.(ng + o) else None)
    |> List.fold_left
         (fun best x ->
           match (best, x) with
           | best, None -> best
           | None, x -> x
           | Some b, Some x -> Some (greater down b x))
         None
    |> Fun.flip Option.bind finite_part

let min_weight world (a : graph) =
  if not a.live then None
  else
    let ng = Array.length a.gaps in
    let edges =
      edges
        ~gap:(fun s -> Option.value (DelaySet.inf s) ~default:zero)
        ~op:(running_time_of world) a
    in
    let pick best x =
      match (best, x) with
      | best, None -> best
      | None, x -> x
      | Some b, Some x -> Some (lesser up b x)
    in
    let d =
      paths ~add
        ~better:(fun x y -> up.compare x y < 0)
        ~cycle:Fun.id zero edges 0
    in
    List.fold_left pick None
      (List.mapi
         (fun o f -> if f then d.(ng + o) else None)
         (Array.to_list a.final))
    |> Fun.flip Option.bind finite_part

let inhabited (a : graph) = a.live

(* {1 Readers} *)

type config = value IntMap.t
(* A configuration of a reader: a weight for some gap states of the automaton
   of the bound. *)

type reader = {
  start : config;
  delay : value -> config -> config;
  operation : string -> config -> config;
  accepts : config -> bool;
}
(* A deterministic reader of a closure, its transitions normalising the
   configurations. *)

(* [set_weight better q x config] maps [q] to the [better] of [x] and its
   weight in [config]. *)
let set_weight better q x config =
  IntMap.update q
    (function None -> Some x | Some y -> Some (better x y))
    config

(* [largest values] is the greatest rational part of the finite [values],
   [0] if none. *)
let largest values =
  List.fold_left
    (fun m -> function
      | Finite (q, _) when Rational.compare q m > 0 -> q | _ -> m)
    Rational.zero values

(* The reader of [↓m], and a delay above every finite threshold it compares a
   weight with: the thresholds of a gap state [q] are the suprema [τ(q, o)] of
   the durations of the paths of [m] from [q] to each live operation state
   [o], operation transitions lasting [0]. *)
let allowance_reader world (a : graph) =
  let ng = Array.length a.gaps in
  let edges =
    edges
      ~gap:(fun s -> Option.value (DelaySet.sup s) ~default:zero)
      ~op:(Fun.const zero) a
  in
  let segments =
    Array.init ng (fun q ->
        if List.is_empty a.gaps.(q) then []
        else
          let d = longest edges q in
          List.filter_map
            (fun o -> Option.map (fun t -> (t, o)) d.(ng + o))
            (List.init (Array.length a.ops) Fun.id))
  in
  let finals =
    Array.map
      (fun row ->
        List.filter_map (fun (t, o) -> if a.final.(o) then Some t else None) row)
      segments
  in
  (* The gap states one delay and one operation after each gap state. *)
  let successors =
    Array.map (List.concat_map (fun (_, o) -> List.map snd a.ops.(o))) a.gaps
  in
  (* [prune config] is [config] without the weights [y] of the states [q] that
     [m] reaches from a state [p] of weight [x ≤ y] kept, by a path whose
     operations are not matched: [m] may continue from [p] through [q], the
     durations of the path adding to its budget. The states are visited in
     increasing order of weight, then of number, those reached from the states
     kept being marked by depth-first search. *)
  let prune config =
    let rec mark covered = function
      | [] -> covered
      | g :: gs ->
          if IntSet.mem g covered then mark covered gs
          else mark (IntSet.add g covered) (successors.(g) @ gs)
    in
    IntMap.bindings config
    |> List.stable_sort (fun (p, x) (q, y) ->
        match down.compare x y with 0 -> Int.compare p q | c -> c)
    |> List.fold_left
         (fun (kept, covered) (q, y) ->
           if IntSet.mem q covered then (kept, covered)
           else (IntMap.add q y kept, mark covered successors.(q)))
         (IntMap.empty, IntSet.empty)
    |> fst
  in
  let normalise config =
    prune
    @@ IntMap.filter_map
         (fun q x ->
           let thresholds = List.map fst segments.(q) in
           if not (List.exists (down.passes x) thresholds) then None
           else if
             is_finite x
             && not
                  (List.exists
                     (fun t -> is_finite t && down.passes x t)
                     thresholds)
           then Some Infinite
           else Some x)
         config
  in
  let delay v config = normalise (IntMap.map (add v) config) in
  let operation name config =
    let bought = IntMap.map (add (running_time_of world name)) config in
    let matched =
      IntMap.fold
        (fun p x targets ->
          List.fold_left
            (fun targets (t, o) ->
              if down.passes x t then
                List.filter_map
                  (fun (name', g) ->
                    if String.equal name' name then Some g else None)
                  a.ops.(o)
                @ targets
              else targets)
            targets segments.(p))
        config []
    in
    normalise
      (List.fold_left
         (fun c g -> set_weight (lesser down) g zero c)
         bought matched)
  in
  ( {
      start =
        normalise (if a.live then IntMap.singleton 0 zero else IntMap.empty);
      delay;
      operation;
      accepts =
        IntMap.exists (fun q x -> List.exists (down.passes x) finals.(q));
    },
    Rational.add (Rational.of_int 1)
      (largest (List.concat_map (List.map fst) (Array.to_list segments))) )

(* The reader of [↑m]: the thresholds of a gap state [q] are the infima of the
   sets of delays of its transitions, a segment of a guarantee being a single
   delay of [m]. *)
let coverage_reader world (a : graph) =
  let gaps =
    Array.map
      (List.filter_map (fun (s, o) ->
           Option.map (fun t -> (t, o)) (DelaySet.inf s)))
      a.gaps
  in
  let normalise config =
    IntMap.filter_map
      (fun q x ->
        match gaps.(q) with
        | [] -> None
        | row ->
            if List.for_all (fun (t, _) -> up.passes x t) row then Some Infinite
            else Some x)
      config
  in
  let delay v config = normalise (IntMap.map (add v) config) in
  let operation name config =
    let banked = IntMap.map (add (running_time_of world name)) config in
    let matched =
      IntMap.fold
        (fun q x targets ->
          List.fold_left
            (fun targets (t, o) ->
              if up.passes x t then
                List.filter_map
                  (fun (name', g) ->
                    if String.equal name' name then Some g else None)
                  a.ops.(o)
                @ targets
              else targets)
            targets gaps.(q))
        config []
    in
    normalise
      (List.fold_left
         (fun c g -> set_weight (greater up) g zero c)
         banked matched)
  in
  {
    start = normalise (if a.live then IntMap.singleton 0 zero else IntMap.empty);
    delay;
    operation;
    accepts =
      IntMap.exists (fun q x ->
          List.exists (fun (t, o) -> a.final.(o) && up.passes x t) gaps.(q));
  }

(* [operation_of world c] is the first name of [world] in the class [c]. *)
let operation_of world c =
  match List.find_opt (fun (name, _) -> member name c) world with
  | Some (name, _) -> name
  | None ->
      invalid_arg
        "DelayTimedClosure.operation_of: a class of names without an operation \
         of the world"

(* [reads world reader word] is whether [reader] accepts the word [word] over
   [world], its delays exact. *)
let reads world reader word =
  reader.accepts
    (List.fold_left
       (fun config -> function
         | A.Delay d -> reader.delay (exact d) config
         | A.Operation c -> reader.operation (operation_of world c) config)
       reader.start word)

let permits world m word = reads world (fst (allowance_reader world m)) word
let covers world m word = reads world (coverage_reader world m) word

(* {1 The product} *)

type node = Gap of int * config | Op of int * config

let compare_config = IntMap.compare (compare_with Bool.compare)

let compare_node n n' =
  match (n, n') with
  | Gap (p, c), Gap (p', c') | Op (p, c), Op (p', c') -> (
      match Int.compare p p' with 0 -> compare_config c c' | k -> k)
  | Gap _, Op _ -> -1
  | Op _, Gap _ -> 1

module Visited = Map.Make (struct
  type t = node

  let compare = compare_node
end)

type step = Read of DelaySet.t | Perform of string

(* [search domain reader l] is a shortest path of the graph [l] to a final
   state at which [reader] rejects, the delays
   of [l] read as their extremal values in [domain]: breadth-first search of the
   pairs of a state of [l] and a configuration, each recording the pair it was
   reached from and the step taken. *)
let search domain reader (a : graph) =
  let rec path parent node acc =
    match Visited.find node parent with
    | None -> acc
    | Some (node', step) -> path parent node' (step :: acc)
  in
  let visit (parent, fifo) (node, from) =
    if Visited.mem node parent then (parent, fifo)
    else (Visited.add node (Some from) parent, Fifo.push node fifo)
  in
  let rec go (parent, fifo) =
    match Fifo.pop fifo with
    | None -> None
    | Some ((Op (p, config) as node), _)
      when a.final.(p) && not (reader.accepts config) ->
        Some (path parent node [])
    | Some ((Gap (p, config) as node), fifo) ->
        go
          (List.fold_left visit (parent, fifo)
             (List.filter_map
                (fun (s, o) ->
                  Option.map
                    (fun v -> (Op (o, reader.delay v config), (node, Read s)))
                    (domain.extremum s))
                a.gaps.(p)))
    | Some ((Op (p, config) as node), fifo) ->
        go
          (List.fold_left visit (parent, fifo)
             (List.map
                (fun (name, g) ->
                  (Gap (g, reader.operation name config), (node, Perform name)))
                a.ops.(p)))
  in
  if not a.live then None
  else
    let start = Gap (0, reader.start) in
    go (Visited.singleton start None, Fifo.push start Fifo.empty)

(* {1 Counterexamples} *)

let half = Rational.make 1 2

let choose s =
  match DelaySet.choose s with
  | Some d -> d
  | None -> invalid_arg "DelayTimedClosure.choose: an empty set of delays"

let open_interval lo hi =
  DelaySet.interval ~lo ~lo_closed:false ~hi:(Some hi) ~hi_closed:false

(* [highest ~above eps s] is a delay of [s] close to its supremum: the maximum
   if attained, the simplest delay of [s] within [eps] below the supremum if it
   is finite, and the simplest delay of [s] from [above] if [s] is
   unbounded. *)
let highest ~above eps s =
  match DelaySet.sup s with
  | Some (Finite (q, true)) -> q
  | Some (Finite (q, false)) ->
      let top = List.hd (List.rev (DelaySet.intervals_upto q s)) in
      let lo = Rational.sub q eps in
      choose
        (open_interval
           (if Rational.compare top.lo lo > 0 then top.lo else lo)
           q)
  | Some Infinite ->
      choose
        (DelaySet.inter s
           (DelaySet.interval ~lo:above ~lo_closed:true ~hi:None
              ~hi_closed:false))
  | None -> invalid_arg "DelayTimedClosure.highest: an empty set of delays"

(* [lowest eps s] is a delay of [s] close to its infimum: the minimum if
   attained, and otherwise the simplest delay of [s] within [eps] above it. *)
let lowest eps s =
  match DelaySet.inf s with
  | Some (Finite (q, true)) -> q
  | Some (Finite (q, false)) ->
      let bottom = List.hd (DelaySet.intervals_upto (Rational.add q eps) s) in
      let hi = Rational.add q eps in
      choose
        (open_interval q
           (if Rational.compare bottom.hi hi < 0 then bottom.hi else hi))
  | Some Infinite | None ->
      invalid_arg "DelayTimedClosure.lowest: an empty set of delays"

(* [concretise delay rejects steps] is the word of the path [steps], each set
   of delays read as the delay [delay eps] chooses from it, for the first [eps]
   of [1, 1/2, 1/4, …] at which the word is rejected; one exists, since for
   every small enough [eps] the comparisons of the reader on the word agree
   with those made on the extremal values. The search stops after
   [max_halvings] halvings. *)
let max_halvings = 256

let concretise delay rejects steps =
  let word eps =
    List.map
      (function
        | Read s -> A.Delay (delay eps s)
        | Perform name -> A.Operation (A.Class.name name))
      steps
  in
  let rec attempt halvings eps =
    let w = word eps in
    if rejects w then w
    else if halvings >= max_halvings then
      invalid_arg
        "DelayTimedClosure.concretise: no rejected word within the bound on \
         the halvings of the distance"
    else attempt (halvings + 1) (Rational.mul half eps)
  in
  attempt 0 (Rational.of_int 1)

(* {1 Decisions} *)

module Graph = struct
  let allowance world l m =
    let reader, above = allowance_reader world m in
    Option.map
      (concretise (highest ~above) (fun w -> not (reads world reader w)))
      (search down reader l)

  let coverage world l m =
    let reader = coverage_reader world m in
    Option.map
      (concretise lowest (fun w -> not (reads world reader w)))
      (search up reader l)

  let in_allowance world l m =
    Option.is_none (search down (fst (allowance_reader world m)) l)

  let in_coverage world l m =
    Option.is_none (search up (coverage_reader world m) l)

  let permits = permits
  let covers = covers
  let max_weight = max_weight
  let min_weight = min_weight
  let inhabited = inhabited
end

(* {2 On automata} *)

let names world = List.map fst world
let on_automaton f world l = f world (of_automaton (names world) l)
let max_weight = on_automaton Graph.max_weight
let min_weight = on_automaton Graph.min_weight
let inhabited world l = Graph.inhabited (of_automaton (names world) l)
let permits world m = on_automaton Graph.permits world m
let covers world m = on_automaton Graph.covers world m

module Arguments = Hashtbl.Make (struct
  type t = world * A.t * A.t

  let equal (world, l, m) (world', l', m') =
    List.equal
      (fun (n, c) (n', c') -> String.equal n n' && DelaySet.equal_extremum c c')
      world world'
    && A.equal l l' && A.equal m m'

  let hash (world, l, m) =
    Grade.combine
      (Grade.hash_list
         (fun (n, c) ->
           Grade.combine (String.hash n) (DelaySet.hash_extremum c))
         world)
      (Grade.combine (A.hash l) (A.hash m))
end)

(* [tabulated decide] is [decide] on the graphs of the automata compared over
   the names of the comparison, tabulated by its arguments. *)
let tabulated decide =
  let table = Arguments.create 64 in
  fun world l m ->
    match Arguments.find_opt table (world, l, m) with
    | Some r -> r
    | None ->
        let names = names world in
        let r = decide world (of_automaton names l) (of_automaton names m) in
        Arguments.add table (world, l, m) r;
        r

let allowance = tabulated Graph.allowance
let coverage = tabulated Graph.coverage
