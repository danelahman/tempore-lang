let tick = 0
let weight ~running_time a = if a = tick then 1 else running_time a

(** The lead of a state accepting no word. *)
let unbounded = Int.max_int

(** Transition functions tabulated, over states ordered by [State.compare]. *)
module Memo (State : Map.OrderedType) = struct
  module Steps = Map.Make (struct
    type t = State.t * int

    let compare (q, a) (q', a') =
      match Int.compare a a' with 0 -> State.compare q q' | c -> c
  end)

  (** [memoise step] is [step], its results tabulated. *)
  let memoise step =
    let table = ref Steps.empty in
    fun q a ->
      match Steps.find_opt (q, a) !table with
      | Some q' -> q'
      | None ->
          let q' = step q a in
          table := Steps.add (q, a) q' !table;
          q'
end

(** The label of an edge explored: a letter, or a run of [k] ticks. *)
type label = Letter of int | Run of int

let label_weight ~running_time = function
  | Letter a -> weight ~running_time a
  | Run k -> k

(** Explorations of the implicit automata over states ordered by
    [State.compare], over [letters] letters, the dead states left out. *)
module Explore (State : Map.OrderedType) = struct
  module States = Set.Make (State)

  let live m q = not (m.Dfa.dead q)

  (** [moves ~letters m q] is the live successors of [q], each with the label of
      its edge: by its [leap] by its lead [k] if [k ≥ 1], the others by the
      words of length at most [k] being dead, and otherwise by each letter. *)
  let moves ~letters m q =
    let k = m.Dfa.lead q in
    let edges =
      if k = 0 then List.init letters (fun a -> (Letter a, m.step q a))
      else if k = unbounded then []
      else [ (Run k, m.leap q k) ]
    in
    List.filter (fun (_, q') -> live m q') edges

  (** [successors ~letters m q] is the live successors of [q]: by its [leap] by
      its lead [k] if [k ≥ 1], and otherwise by each letter. *)
  let successors ~letters m q =
    let k = m.Dfa.lead q in
    let next =
      if k = 0 then List.init letters (m.step q)
      else if k = unbounded then []
      else [ m.leap q k ]
    in
    List.filter (live m) next

  (** [within m y x] is whether [x] is the successor of [y] by [0ʲ] for
      [0 < j ≤ k], [k] the lead of [y], and [k - j] that of [x]: [x] lies on the
      run of ticks of [y], at its end if [j = k]. *)
  let within m y x =
    let k = m.Dfa.lead y and k' = m.Dfa.lead x in
    k > k' && State.compare (m.leap y (k - k')) x = 0

  (** [reachable next s] is the set of the states reachable from the set [s] by
      [next], by depth-first search with an explicit stack, in a constant depth
      of the call stack. *)
  let reachable next s =
    let rec visit seen = function
      | [] -> seen
      | q :: stack when States.mem q seen -> visit seen stack
      | q :: stack -> visit (States.add q seen) (List.rev_append (next q) stack)
    in
    visit States.empty (States.elements s)
end

module Allowance (State : Map.OrderedType) = struct
  include Explore (State)

  include Memo (struct
    type t = State.t list

    let compare = List.compare State.compare
  end)

  (** [prune m s] is the states of [s] that lie within the run of ticks of no
      other state of [s], short of its end. *)
  let prune m s =
    let runs = States.filter (fun y -> m.Dfa.lead y >= 1) s in
    States.filter
      (fun x ->
        m.Dfa.lead x = 0 || not (States.exists (fun y -> within m y x) runs))
      s

  (** [closed ~letters m s] represents the set of the live states reachable from
      the set [s] of live states: by the states reached, a state of lead [k ≥ 1]
      followed by its [leap] by [k] only, but for those within the run of ticks
      of another, which the set holds with it. *)
  let closed ~letters m s = prune m (reachable (successors ~letters m) s)

  (** [at_least ~letters m n s] represents the set of the states reachable from
      the set represented by [s] by a word with at least [n] ticks: the chain of
      the sets reached with at least [0, 1, 2, …] ticks, each that reached from
      the successors by [tick] of the last, is descending, and followed until
      [n] or until it is stationary, so that large running times are cheap. The
      states without a live successor by [tick] leave the chain at once, and
      those that are their own successor by [tick] stay in it; where the others
      all have leads of at least [k ≥ 1], it moves [min n k] ticks at once by
      their [leap]s. *)
  let at_least ~letters m n s =
    let fixed q = State.compare (m.Dfa.step q tick) q = 0 in
    let rec go n s =
      if n = 0 || States.is_empty s then s
      else
        let ticking = States.filter (fun q -> live m (m.step q tick)) s in
        let moving = States.filter (fun q -> not (fixed q)) ticking in
        let k = States.fold (fun q k -> min k (m.Dfa.lead q)) moving n in
        let advance q =
          if k = 0 then m.step q tick else if fixed q then q else m.leap q k
        in
        let s' = closed ~letters m (States.map advance ticking) in
        if States.equal s' s then s else go (n - max k 1) s'
    in
    go n s

  (** [matched ~letters m x s] represents the set of the states reachable from
      the successors by the operation [x] of the set represented by [s]: those
      of its states of lead [0], the others having none that is live. *)
  let matched ~letters m x s =
    closed ~letters m
      (States.filter (live m)
         (States.filter_map
            (fun q -> if m.Dfa.lead q = 0 then Some (m.step q x) else None)
            s))

  (* The downward closure is prefix-closed, so that a set without a final
     state rejects every word, and all such sets are the empty set. The states
     within the run of ticks of another are not final. *)
  let closure ~running_time ~letters m =
    let final s =
      if States.exists m.Dfa.accepts s then States.elements s else []
    in
    let step s x =
      let s = States.of_list s in
      let bought = at_least ~letters m (weight ~running_time x) s in
      let matched = if x = tick then States.empty else matched ~letters m x s in
      final (prune m (States.union bought matched))
    in
    {
      Dfa.start =
        final
          (closed ~letters m
             (States.filter (live m) (States.singleton m.start)));
      step = memoise step;
      accepts = (fun s -> not (List.is_empty s));
      dead = List.is_empty;
      lead = Fun.const 0;
      leap = (fun s k -> final (at_least ~letters m k (States.of_list s)));
    }
end

module Coverage (State : Map.OrderedType) = struct
  include Explore (State)

  include Memo (struct
    type t = State.t list

    let compare = List.compare State.compare
  end)

  (** [delays m n q] is the set of the successors of the state [q] of [m] by [j]
      ticks for [j ≤ n], computed up to the first repetition, but for those
      within the lead of a state: from a state of lead [k ≥ 1], its successors
      by fewer than [min n k] ticks are left out for that by [min n k], taken by
      its [leap]. *)
  let delays m n q =
    let rec go (visited, kept) n q =
      let k = m.Dfa.lead q in
      if n < 0 || States.mem q visited then kept
      else
        let visited = States.add q visited in
        if k = 0 || k = unbounded then
          go (visited, States.add q kept) (n - 1) (m.step q tick)
        else if n <= k then States.add (m.leap q n) kept
        else go (visited, kept) (n - k) (m.leap q k)
    in
    go (States.empty, States.empty) n q

  (** [prune m s] is the states of [s] on whose run of ticks no other state of
      [s] lies. *)
  let prune m s =
    States.filter
      (fun y ->
        let k = m.Dfa.lead y in
        k = 0 || k = unbounded || not (States.exists (fun x -> within m y x) s))
      s

  (* The upward closure is a right ideal, so that a set with a final state
     accepts every word, and is kept. *)
  let closure ~running_time m =
    let accepts = List.exists m.Dfa.accepts in
    let targets y q =
      let banked = delays m (weight ~running_time y) q in
      if y = tick then banked else States.add (m.step q y) banked
    in
    let union targets s =
      States.elements
        (prune m
           (List.fold_left
              (fun targets' q -> States.union targets' (targets q))
              States.empty s))
    in
    let step s y = if accepts s then s else union (targets y) s in
    {
      Dfa.start = [ m.start ];
      step = memoise step;
      accepts;
      dead = List.for_all m.dead;
      lead = Fun.const 0;
      leap = (fun s k -> if accepts s then s else union (delays m k) s);
    }
end

module Int_allowance = Allowance (Int)
module Int_coverage = Coverage (Int)

let allowance ~running_time m =
  Int_allowance.closure ~running_time ~letters:(Dfa.letters m) (Dfa.automaton m)

let coverage ~running_time m =
  Int_coverage.closure ~running_time (Dfa.automaton m)

module Weights (State : Map.OrderedType) = struct
  include Explore (State)
  module Ids = Map.Make (State)

  (** [graph ~running_time ~letters m] is the array of the finality and the
      weighted edges of the live states reachable from the start of [m],
      numbered from [0], the start, a state of lead [k ≥ 1] having one edge, of
      weight [k], to its [leap] by [k]. *)
  let graph ~running_time ~letters m =
    let states =
      if live m m.Dfa.start then
        reachable (successors ~letters m) (States.singleton m.start)
      else States.empty
    in
    let order =
      if States.is_empty states then []
      else m.start :: States.elements (States.remove m.start states)
    in
    let ids =
      List.fold_left
        (fun ids (i, q) -> Ids.add q i ids)
        Ids.empty
        (List.mapi (fun i q -> (i, q)) order)
    in
    let edges q =
      List.map
        (fun (label, q') -> (label_weight ~running_time label, Ids.find q' ids))
        (moves ~letters m q)
    in
    Array.of_list (List.map (fun q -> (m.accepts q, edges q)) order)

  (** [relax graph better d] is one round of Bellman–Ford relaxation of the
      weights [d] of the states of [graph] towards a final state, [better]
      choosing between two candidates, [None] standing for no path. *)
  let relax graph better d =
    let pick best c =
      match (best, c) with
      | None, c | c, None -> c
      | Some b, Some c -> Some (better b c)
    in
    Array.mapi
      (fun q dq ->
        List.fold_left
          (fun best (w, q') ->
            pick best
              (Option.map (Delay.checked_add ~quantity:"duration" w) d.(q')))
          dq
          (snd graph.(q)))
      d

  let finals graph =
    Array.map (fun (final, _) -> if final then Some 0 else None) graph

  let at_start d = if Array.length d = 0 then None else d.(0)

  let min_weight ~running_time ~letters m =
    let graph = graph ~running_time ~letters m in
    let rec go d =
      let d' = relax graph min d in
      if d' = d then at_start d else go d'
    in
    go (finals graph)

  let max_weight ~running_time ~letters m =
    let graph = graph ~running_time ~letters m in
    let rec go rounds d =
      let d' = relax graph max d in
      if d' = d then at_start d
      else if rounds = 0 then None
      else go (rounds - 1) d'
    in
    go (Array.length graph) (finals graph)
end
