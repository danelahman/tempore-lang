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
  markers : bool;
  strict : bool array;
}
(* The automaton of a language over the names of a comparison, restricted to
   its live states, from which a final state is reachable: row [g] of [gaps]
   lists the transitions of the gap state [g], row [o] of [ops] those of the
   operation state [o] by each name; the rows of the other states are empty.
   [live] is whether the start is live, i.e. whether the language has a word
   over the names. [markers] is whether a transition reads a name that opens
   or closes a strict delay, and then [strict] marks the gap states entered by
   the opening name, whose delays are strict; it is empty otherwise. *)

let graph ~gaps ~ops ~final =
  let ng = Array.length gaps and no = Array.length ops in
  (* The least fixpoint of liveness from the final states, by a search of the
     reversed transitions, linear in the size of the automaton. *)
  let into_op = Array.make no [] and into_gap = Array.make ng [] in
  Array.iteri
    (fun g row -> List.iter (fun (_, o) -> into_op.(o) <- g :: into_op.(o)) row)
    gaps;
  Array.iteri
    (fun o row ->
      List.iter (fun (_, g) -> into_gap.(g) <- o :: into_gap.(g)) row)
    ops;
  let live_gap = Array.make ng false and live_op = Array.make no false in
  let rec search = function
    | [] -> ()
    | `Op o :: rest when not live_op.(o) ->
        live_op.(o) <- true;
        search (List.rev_map (fun g -> `Gap g) into_op.(o) @ rest)
    | `Gap g :: rest when not live_gap.(g) ->
        live_gap.(g) <- true;
        search (List.rev_map (fun o -> `Op o) into_gap.(g) @ rest)
    | _ :: rest -> search rest
  in
  search
    (List.filter_map
       (fun o -> if final.(o) then Some (`Op o) else None)
       (List.init no Fun.id));
  let keep live' live row =
    if live then List.filter (fun (_, q) -> live'.(q)) row else []
  in
  let ops = Array.mapi (fun o row -> keep live_gap live_op.(o) row) ops in
  let markers =
    Array.exists
      (List.exists (fun (name, _) -> GradeLiteral.is_marker name))
      ops
  in
  let strict =
    if markers then
      let opened =
        Array.fold_left
          (List.fold_left (fun opened (name, g) ->
               if String.equal name GradeLiteral.strict_opening then
                 IntSet.add g opened
               else opened))
          IntSet.empty ops
      in
      Array.init ng (fun g -> IntSet.mem g opened)
    else [||]
  in
  {
    gaps = Array.mapi (fun g row -> keep live_op live_gap.(g) row) gaps;
    ops;
    final = Array.mapi (fun o f -> f && live_op.(o)) final;
    live = ng > 0 && live_gap.(0);
    markers;
    strict;
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

(* [paths ~add ~better ~through zero edges source] is the best weight of a
   path from the node [source] to each node, [None] if there is none, over the
   graph of the weighted edges [edges], the weight of a path the sum by [add]
   of the weights of its edges from [zero], a weight [x] reached at a node [v]
   replaced by [through v x]. It is the label-correcting form of Bellman–Ford
   with a queue (Moore, "The shortest path through a maze", 1959): a node whose
   weight becomes [better] is queued to relax its edges. It terminates where
   [through] removes every cycle that improves a weight. *)
let paths ~add ~better ~through zero edges source =
  let n = Array.length edges in
  let improve (weights, fifo) (v, x) =
    let x = through v x in
    match IntMap.find_opt v weights with
    | Some y when not (better x y) -> (weights, fifo)
    | _ -> (IntMap.add v x weights, Fifo.push v fifo)
  in
  let rec relax (weights, fifo) =
    match Fifo.pop fifo with
    | None -> weights
    | Some (u, fifo) ->
        let x = IntMap.find u weights in
        relax
          (List.fold_left
             (fun acc (v, w) -> improve acc (v, add x w))
             (weights, fifo) edges.(u))
  in
  let weights = relax (improve (IntMap.empty, Fifo.empty) (source, zero)) in
  Array.init n (fun v -> IntMap.find_opt v weights)

(* [components edges] is the number of the strongly connected component of
   each node of the graph of the edges [edges], by Tarjan's algorithm (Tarjan,
   "Depth-first search and linear graph algorithms", 1972), its depth-first
   search kept on an explicit stack of the nodes entered with their edges not
   yet followed. *)
let components edges =
  let n = Array.length edges in
  let index = Array.make n (-1)
  and low = Array.make n 0
  and on_stack = Array.make n false
  and component = Array.make n (-1) in
  let stack = ref [] and entered = ref 0 and found = ref 0 in
  let enter v =
    index.(v) <- !entered;
    low.(v) <- !entered;
    incr entered;
    stack := v :: !stack;
    on_stack.(v) <- true
  in
  (* Pops the nodes of the component of the root [r] off the stack [nodes]. *)
  let rec pop r = function
    | v :: nodes ->
        on_stack.(v) <- false;
        component.(v) <- !found;
        if v = r then nodes else pop r nodes
    | [] -> []
  in
  let rec search = function
    | [] -> ()
    | (v, []) :: calls ->
        if low.(v) = index.(v) then begin
          stack := pop v !stack;
          incr found
        end;
        (match calls with
        | (u, _) :: _ -> low.(u) <- min low.(u) low.(v)
        | [] -> ());
        search calls
    | (v, (w, _) :: rest) :: calls ->
        if index.(w) < 0 then begin
          enter w;
          search ((w, edges.(w)) :: (v, rest) :: calls)
        end
        else begin
          if on_stack.(w) then low.(v) <- min low.(v) index.(w);
          search ((v, rest) :: calls)
        end
  in
  for v = 0 to n - 1 do
    if index.(v) < 0 then begin
      enter v;
      search [ (v, edges.(v)) ]
    end
  done;
  component

(* [longest edges source] is the greatest weight in the domain of suprema of a
   path from [source] to each node, the weights of the edges at least [0], and
   infinity where a cycle of positive weight is on the way: at the nodes of the
   strongly connected components with an edge of positive weight between two
   of their nodes. The components are computed once, for every [source]. *)
let longest edges =
  let component = components edges in
  let pumped = Array.make (Array.length edges) false in
  Array.iteri
    (fun u ->
      List.iter (fun (v, w) ->
          if component.(u) = component.(v) && down.compare w zero > 0 then
            pumped.(component.(u)) <- true))
    edges;
  paths ~add
    ~better:(fun x y -> down.compare x y > 0)
    ~through:(fun v x -> if pumped.(component.(v)) then Infinite else x)
    zero edges

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
        ~through:(fun _ x -> x)
        zero edges 0
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

let compare_config : config -> config -> int =
  IntMap.compare (compare_with Bool.compare)

type 'c reader = {
  start : 'c;
  delay : strict:bool -> value -> 'c -> 'c;
  operation : string -> 'c -> 'c;
  accepts : 'c -> bool;
  compare : 'c -> 'c -> int;
}
(* A deterministic reader of a closure over configurations ['c] ordered by
   [compare], its transitions normalising the configurations; [delay ~strict]
   reads a delay, strict if [strict]. The names that open and close strict
   delays are not given to it. *)

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

(* [entered domain rows name config] is the gap states that the automaton [a]
   enters by [name] from an operation state [o] of a row [(t, o)] of a state
   [q] of [config] whose weight passes [t] in [domain]: the states at which
   [name] is matched. *)
let entered domain (a : graph) rows name config =
  IntMap.fold
    (fun q x targets ->
      List.fold_left
        (fun targets (t, o) ->
          if domain.passes x t then
            List.filter_map
              (fun (name', g) ->
                if String.equal name' name then Some g else None)
              a.ops.(o)
            @ targets
          else targets)
        targets rows.(q))
    config []

(* [gap_rows extremum a] is, for each gap state of [a], the extremal value
   [extremum] of the set of delays of each of its transitions, with the
   operation state it leads to. *)
let gap_rows extremum (a : graph) =
  Array.map
    (List.filter_map (fun (s, o) -> Option.map (fun t -> (t, o)) (extremum s)))
    a.gaps

(* The reader of [↓m], and a delay above every finite threshold it compares a
   weight with. The thresholds of a gap state [q] are, for each live operation
   state [o], the supremum [τ(q, o)] of the durations of the segments of [m]
   from [q] to [o]: under the rigid order, the supremum of the set of delays of
   a transition of [q] to [o], a segment being one delay of [m]; otherwise that
   of the durations of the paths of [m] from [q] to [o], operation transitions
   lasting [0]. *)
let allowance_reader ~rigid world (a : graph) =
  let ng = Array.length a.gaps in
  let segments =
    if rigid then gap_rows DelaySet.sup a
    else
      let edges =
        edges
          ~gap:(fun s -> Option.value (DelaySet.sup s) ~default:zero)
          ~op:(Fun.const zero) a
      in
      let longest = longest edges in
      Array.init ng (fun q ->
          if List.is_empty a.gaps.(q) then []
          else
            let d = longest q in
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
     kept being marked by depth-first search. Under the rigid order, which
     matches every operation of [m], it is the identity. *)
  let prune config =
    let rec mark covered = function
      | [] -> covered
      | g :: gs ->
          if IntSet.mem g covered then mark covered gs
          else mark (IntSet.add g covered) (successors.(g) @ gs)
    in
    if rigid then config
    else
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
  let delay ~strict:_ v config = normalise (IntMap.map (add v) config) in
  let operation name config =
    let bought = IntMap.map (add (running_time_of world name)) config in
    normalise
      (List.fold_left
         (fun c g -> set_weight (lesser down) g zero c)
         bought
         (entered down a segments name config))
  in
  ( {
      start =
        normalise (if a.live then IntMap.singleton 0 zero else IntMap.empty);
      delay;
      operation;
      accepts =
        IntMap.exists (fun q x -> List.exists (down.passes x) finals.(q));
      compare = compare_config;
    },
    Rational.add (Rational.of_int 1)
      (largest (List.concat_map (List.map fst) (Array.to_list segments))) )

(* The reader of [↑m]: the thresholds of a gap state [q] are the infima of the
   sets of delays of its transitions, a segment of a guarantee being a single
   delay of [m]. *)
let coverage_reader world (a : graph) =
  let gaps = gap_rows DelaySet.inf a in
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
  let delay ~strict:_ v config = normalise (IntMap.map (add v) config) in
  let operation name config =
    let banked = IntMap.map (add (running_time_of world name)) config in
    normalise
      (List.fold_left
         (fun c g -> set_weight (greater up) g zero c)
         banked
         (entered up a gaps name config))
  in
  {
    start = normalise (if a.live then IntMap.singleton 0 zero else IntMap.empty);
    delay;
    operation;
    accepts =
      IntMap.exists (fun q x ->
          List.exists (fun (t, o) -> a.final.(o) && up.passes x t) gaps.(q));
    compare = compare_config;
  }

(* {2 Readers of bounds with strict delays}

   A gap of a bound with strict delays is a sequence of pieces, budget and
   strict delays, each read from a gap state of its automaton: a strict piece
   is entered by the name that opens it and left by the one that closes it.
   The segment of a word between two matched operations is split among the
   pieces of the gap it faces, a strict delay of the word possibly divided
   between consecutive pieces, and a strict piece admits strict delays of the
   word only. A configuration maps each piece to the weight read in it, and is
   closed under leaving a piece whose delay admits its weight for the next
   piece, of weight [0]; a strict delay that exceeds a piece passes its excess
   into the next ones. *)

type weight = { value : value; harm : bool }
(* A weight of a reader of a bound with strict delays. [harm] is an
   infinitesimal against acceptance, of lower order than the flag of [value]:
   the excess of a weight over a delay of the bound approached, not attained,
   the delays of the bound approaching their extremal values more closely than
   those of the word. *)

let plain value = { value; harm = false }
let weigh x v = { x with value = add x.value v }

(* [tie x t] is whether the exact value [x] equals the finite value [t]. *)
let tie x t =
  match (x, t) with
  | Finite (a, true), Finite (c, _) -> Rational.equal a c
  | _ -> false

(* [admits domain x t] is whether a set of delays of extremal value [t] admits
   the weight [x], its [harm] failing a tie. *)
let admits (domain : domain) x t =
  domain.passes x.value t && not (x.harm && tie x.value t)

(* [excess x t] is the weight [x] less the finite value [t], harmed if [t] is
   not attained. *)
let excess x t =
  match (x.value, t) with
  | Finite (a, f), Finite (c, g) ->
      { value = Finite (Rational.sub a c, f); harm = x.harm || not g }
  | Infinite, _ | _, Infinite -> plain Infinite

(* [compare_weight domain x y] orders the weights in [domain], a harmed weight
   being worse: greater among suprema and lesser among infima. *)
let compare_weight (domain : domain) x y =
  match domain.compare x.value y.value with
  | 0 ->
      let c = Bool.compare x.harm y.harm in
      if domain == up then -c else c
  | c -> c

(* [positive v] is whether the extremal value [v] of a delay is not the delay
   [0], that is, whether the delay is there. *)
let positive v = not (tie v zero)

(* [pieces_reader domain ~extremum ~overflow ~cost a] is the reader of the
   closure of the bound [a] with strict delays in [domain], over suprema for
   the allowance order and over infima for coverage: a delay of [a] counts by
   its [extremum]; an operation not matched costs [cost name] in a budget
   piece; the weight of a piece is the least read in the domain of suprema
   and the greatest in that of infima; [overflow before after v t] is the
   weight that a strict delay [v], which brings the weight of a piece from
   [before] to [after], passes into the next pieces beyond the extremal value
   [t] of its delay, if any. *)
let pieces_reader (domain : domain) ~extremum ~overflow ~cost (a : graph) =
  let better x y =
    let c = compare_weight domain x y in
    if (domain == up && c >= 0) || (domain == down && c <= 0) then x else y
  in
  let rows = gap_rows extremum a in
  let next =
    Array.map
      (List.filter_map (fun (name, g) ->
           if GradeLiteral.is_marker name then Some g else None))
      a.ops
  in
  let finals =
    Array.map
      (fun row ->
        List.filter_map (fun (t, o) -> if a.final.(o) then Some t else None) row)
      rows
  in
  let set q x config =
    IntMap.update q
      (function None -> Some x | Some y -> Some (better x y))
      config
  in
  let same = IntMap.equal (fun x y -> compare_weight domain x y = 0) in
  (* The closure under leaving the pieces whose delays admit their weights. *)
  let rec advance config =
    let config' =
      IntMap.fold
        (fun q x c ->
          List.fold_left
            (fun c (t, o) ->
              if admits domain x t then
                List.fold_left (fun c g -> set g (plain zero) c) c next.(o)
              else c)
            c rows.(q))
        config config
    in
    if same config config' then config else advance config'
  in
  (* A weight that no delay of its state admits is dropped. Under the
     allowance order, one that no finite delay admits, where an infinite one
     does, is set to infinity, and under coverage, one that every delay of its
     state admits. *)
  let normalise config =
    advance
      (IntMap.filter_map
         (fun q x ->
           let thresholds = List.map fst rows.(q) in
           if domain == down then
             if not (List.exists (admits down x) thresholds) then None
             else if
               is_finite x.value
               && not
                    (List.exists
                       (fun t -> is_finite t && admits down x t)
                       thresholds)
             then Some (plain Infinite)
             else Some x
           else if List.is_empty thresholds then None
           else if List.for_all (admits up x) thresholds then
             Some (plain Infinite)
           else Some x)
         config)
  in
  let budget_only config = IntMap.filter (fun q _ -> not a.strict.(q)) config in
  (* [flow config pending] passes the excess of the weights [pending], each a
     state with its weight before and after a strict delay, into the next
     pieces, and on. *)
  let rec flow config = function
    | [] -> config
    | (q, before, after, v) :: pending ->
        let passed =
          List.concat_map
            (fun (t, o) ->
              match if is_finite t then overflow before after v t else None with
              | Some rest -> List.map (fun g -> (g, rest)) next.(o)
              | None -> [])
            rows.(q)
        in
        let config, pending =
          List.fold_left
            (fun (config, pending) (g, rest) ->
              match IntMap.find_opt g config with
              | Some y when compare_weight domain (better y rest) y = 0 ->
                  (config, pending)
              | _ ->
                  ( IntMap.add g rest config,
                    (g, plain zero, rest, rest) :: pending ))
            (config, pending) passed
        in
        flow config pending
  in
  let delay ~strict v config =
    if strict then
      normalise
        (flow
           (IntMap.map (fun x -> weigh x v) config)
           (IntMap.fold
              (fun q x pending -> (q, x, weigh x v, plain v) :: pending)
              config []))
    else if positive v then
      normalise (IntMap.map (fun x -> weigh x v) (budget_only config))
    else config
  in
  let operation name config =
    let unmatched =
      IntMap.map (fun x -> weigh x (cost name)) (budget_only config)
    in
    let matched =
      IntMap.fold
        (fun q x targets ->
          List.fold_left
            (fun targets (t, o) ->
              if admits domain x t then
                List.filter_map
                  (fun (name', g) ->
                    if String.equal name' name then Some g else None)
                  a.ops.(o)
                @ targets
              else targets)
            targets rows.(q))
        config []
    in
    normalise
      (List.fold_left (fun c g -> set g (plain zero) c) unmatched matched)
  in
  {
    start =
      normalise
        (if a.live then IntMap.singleton 0 (plain zero) else IntMap.empty);
    delay;
    operation;
    accepts =
      IntMap.exists (fun q x -> List.exists (admits domain x) finals.(q));
    compare = IntMap.compare (compare_weight domain);
  }

(* The reader of [↓ʳm] for a bound [m] with strict delays: a strict delay
   overflows a piece that admits the weight before it but not after it, by the
   excess of the weight after it. *)
let pieces_allowance_reader world a =
  pieces_reader down ~extremum:DelaySet.sup
    ~overflow:(fun before after _ t ->
      if admits down before t && not (admits down after t) then
        Some (excess after t)
      else None)
    ~cost:(running_time_of world) a

(* The reader of [↑m] for a guarantee [m] with strict delays: a strict delay
   that covers the delay of a piece passes into the next ones what of it
   exceeds the delay, at most itself: the rest of the weight of the piece is
   made of earlier events, which do not follow the piece. *)
let pieces_coverage_reader world a =
  pieces_reader up ~extremum:DelaySet.inf
    ~overflow:(fun _ after v t ->
      if admits up after t then
        let rest = excess after t in
        Some (if compare_weight up rest v <= 0 then rest else v)
      else None)
    ~cost:(running_time_of world) a

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
    (fst
       (List.fold_left
          (fun (config, strict) -> function
            | A.Delay d -> (reader.delay ~strict (exact d) config, strict)
            | A.Operation c -> (
                match operation_of world c with
                | name when String.equal name GradeLiteral.strict_opening ->
                    (config, true)
                | name when String.equal name GradeLiteral.strict_closing ->
                    (config, false)
                | name -> (reader.operation name config, strict)))
          (reader.start, false) word))

type 'r use = { use : 'c. 'c reader -> 'r }
(* A use of a reader, whatever its configurations. *)

(* [with_allowance_reader ~rigid world m k] is [k.use] on the reader of
   [↓m], [↓ʳm] if [rigid], by whether [m] has strict delays. *)
let with_allowance_reader ~rigid world (m : graph) k =
  if rigid && m.markers then k.use (pieces_allowance_reader world m)
  else k.use (fst (allowance_reader ~rigid world m))

(* [with_coverage_reader world m k] is [k.use] on the reader of [↑m]. *)
let with_coverage_reader world (m : graph) k =
  if m.markers then k.use (pieces_coverage_reader world m)
  else k.use (coverage_reader world m)

let permits ~rigid world m word =
  with_allowance_reader ~rigid world m
    { use = (fun reader -> reads world reader word) }

let covers world m word =
  with_coverage_reader world m { use = (fun reader -> reads world reader word) }

(* {1 The product} *)

type 'c node = Gap of int * 'c | Op of int * 'c

let compare_node compare n n' =
  match (n, n') with
  | Gap (p, c), Gap (p', c') | Op (p, c), Op (p', c') -> (
      match Int.compare p p' with 0 -> compare c c' | k -> k)
  | Gap _, Op _ -> -1
  | Op _, Gap _ -> 1

type step = Read of DelaySet.t | Perform of string

(* [readings s] is the sets of delays that a budget delay of the language
   included, read from [s] and facing a guarantee with strict delays, is taken
   from, each by its extremal value: [{0}] and the positive delays of [s]
   apart, the delay [0] being no delay and any positive one excluded by a
   strict delay. *)
let readings s =
  if DelaySet.mem Rational.zero s && not (DelaySet.equal s DelaySet.zero) then
    [ DelaySet.zero; DelaySet.diff s DelaySet.zero ]
  else [ s ]

(* [search domain ~pieces reader l] is a shortest path of the graph [l] to a
   final state at which [reader] rejects, the delays of [l] read as their
   extremal values in [domain], a budget delay from the sets of {!readings} if
   [pieces], the guarantee having strict delays:
   breadth-first search of the pairs of a state of [l] and a configuration,
   each recording the pair it was reached from and the step taken. The names
   that open and close strict delays are not read. *)
let search (type c) domain ~pieces (reader : c reader) (a : graph) =
  let module Visited = Map.Make (struct
    type t = c node

    let compare = compare_node reader.compare
  end) in
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
        let strict = a.markers && a.strict.(p) in
        let read (s, o) =
          Option.map
            (fun v -> (Op (o, reader.delay ~strict v config), (node, Read s)))
            (domain.extremum s)
        in
        go
          (List.fold_left visit (parent, fifo)
             (if pieces && not strict then
                List.concat_map
                  (fun (s, o) ->
                    List.filter_map (fun s -> read (s, o)) (readings s))
                  a.gaps.(p)
              else List.filter_map read a.gaps.(p)))
    | Some ((Op (p, config) as node), fifo) ->
        let operation name =
          if a.markers && GradeLiteral.is_marker name then config
          else reader.operation name config
        in
        go
          (List.fold_left visit (parent, fifo)
             (List.map
                (fun (name, g) ->
                  (Gap (g, operation name), (node, Perform name)))
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
  let allowance ~rigid world l m =
    let above = snd (allowance_reader ~rigid world m) in
    with_allowance_reader ~rigid world m
      {
        use =
          (fun reader ->
            Option.map
              (concretise (highest ~above) (fun w -> not (reads world reader w)))
              (search down ~pieces:false reader l));
      }

  let coverage world l m =
    with_coverage_reader world m
      {
        use =
          (fun reader ->
            Option.map
              (concretise lowest (fun w -> not (reads world reader w)))
              (search up ~pieces:m.markers reader l));
      }

  let in_allowance ~rigid world l m =
    with_allowance_reader ~rigid world m
      {
        use =
          (fun reader -> Option.is_none (search down ~pieces:false reader l));
      }

  let in_coverage world l m =
    with_coverage_reader world m
      {
        use =
          (fun reader -> Option.is_none (search up ~pieces:m.markers reader l));
      }

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
let permits ~rigid world m = on_automaton (Graph.permits ~rigid) world m
let covers world m = on_automaton Graph.covers world m

module Arguments = Memo.Make (struct
  type t = world * A.t * A.t

  let equal (world, l, m) (world', l', m') =
    List.equal
      (fun (n, c) (n', c') -> String.equal n n' && DelaySet.equal_extremum c c')
      world world'
    && A.equal l l' && A.equal m m'

  let hash (world, l, m) =
    Hashing.combine
      (Hashing.list
         (fun (n, c) ->
           Hashing.combine (String.hash n) (DelaySet.hash_extremum c))
         world)
      (Hashing.combine (A.hash l) (A.hash m))
end)

(* [tabulated decide] is [decide] on the graphs of the automata compared over
   the names of the comparison, tabulated by its arguments. *)
let tabulated decide =
  let decide =
    Arguments.memoise (fun (world, l, m) ->
        let names = names world in
        decide world (of_automaton names l) (of_automaton names m))
  in
  fun world l m -> decide (world, l, m)

let allowance =
  let loose = tabulated (Graph.allowance ~rigid:false)
  and rigid = tabulated (Graph.allowance ~rigid:true) in
  fun ~rigid:r -> if r then rigid else loose

let coverage = tabulated Graph.coverage
