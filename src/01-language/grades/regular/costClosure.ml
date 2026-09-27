module States = Set.Make (Int)

let tick = 0
let weight ~cost a = if a = tick then 1 else cost a
let letters m = List.init (Dfa.letters m) Fun.id
let image m a s = States.map (fun q -> Dfa.next m q a) s

(** [reach m s] is the set of the states of [m] reachable from the set [s], by
    depth-first search. *)
let reach m s =
  let rec visit seen q =
    if States.mem q seen then seen
    else
      List.fold_left visit (States.add q seen)
        (List.map (Dfa.next m q) (letters m))
  in
  States.fold (fun q seen -> visit seen q) s States.empty

(** [at_least m n s] is the set of the states of [m] reachable from the set [s],
    closed under reachability, by a word with at least [n] ticks. The sets for
    [n = 0, 1, …] form a descending chain, which is stationary from its first
    repetition on. *)
let rec at_least m n s =
  if n = 0 then s
  else
    let s' = reach m (image m tick s) in
    if States.equal s' s then s else at_least m (n - 1) s'

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

module Subsets = Memo (struct
  type t = int list

  let compare = List.compare Int.compare
end)

(* The downward closure is prefix-closed, so that a set without a final state
   rejects every word, and all such sets are the empty set. *)
let allowance ~cost m =
  let step s x =
    let s = States.of_list s in
    let bought = at_least m (weight ~cost x) s in
    let matched = if x = tick then States.empty else reach m (image m x s) in
    let s' = States.union bought matched in
    if States.exists (Dfa.final m) s' then States.elements s' else []
  in
  {
    Dfa.start = States.elements (reach m (States.singleton 0));
    step = Subsets.memoise step;
    accepts = List.exists (Dfa.final m);
    dead = List.is_empty;
  }

module Coverage (State : Map.OrderedType) = struct
  module States = Set.Make (State)

  include Memo (struct
    type t = State.t list

    let compare = List.compare State.compare
  end)

  (** [delays m n q] is the set of the successors of the state [q] of [m] by [j]
      ticks for [j ≤ n], computed up to the first repetition. *)
  let delays m n q =
    let rec go seen j q =
      if j > n || States.mem q seen then seen
      else go (States.add q seen) (j + 1) (m.Dfa.step q tick)
    in
    go States.empty 0 q

  (* The upward closure is a right ideal, so that a set with a final state
     accepts every word, and is kept. *)
  let closure ~cost m =
    let accepts = List.exists m.Dfa.accepts in
    let targets y q =
      let banked = delays m (weight ~cost y) q in
      if y = tick then banked else States.add (m.step q y) banked
    in
    let step s y =
      if accepts s then s
      else
        States.elements
          (List.fold_left
             (fun targets' q -> States.union targets' (targets y q))
             States.empty s)
    in
    {
      Dfa.start = [ m.start ];
      step = memoise step;
      accepts;
      dead = List.for_all m.dead;
    }
end

module Tables = Coverage (Int)

let coverage ~cost m = Tables.closure ~cost (Dfa.automaton m)

(** [relax m better d] is one round of Bellman–Ford relaxation of the weights
    [d] of the states of [m] towards a final state, [better] choosing between
    two candidates, [None] standing for no path. *)
let relax ~cost m better d =
  let candidate q a = Option.map (( + ) (weight ~cost a)) d.(Dfa.next m q a) in
  let pick best c =
    match (best, c) with
    | None, c | c, None -> c
    | Some b, Some c -> Some (better b c)
  in
  Array.mapi
    (fun q dq ->
      List.fold_left (fun best a -> pick best (candidate q a)) dq (letters m))
    d

let finals m =
  Array.init (Dfa.states m) (fun q -> if Dfa.final m q then Some 0 else None)

let min_weight ~cost m =
  let rec go d =
    let d' = relax ~cost m min d in
    if d' = d then d.(0) else go d'
  in
  go (finals m)

let max_weight ~cost m =
  let rec go rounds d =
    let d' = relax ~cost m max d in
    if d' = d then d.(0) else if rounds = 0 then None else go (rounds - 1) d'
  in
  go (Dfa.states m) (finals m)
