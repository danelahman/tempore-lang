open IntervalRegex
module IntMap = Map.Make (Int)
module IntSet = Set.Make (Int)

type weight = { value : cut; harm : bool }
type world = { id : int; names : string array; times : cut array }

module Worlds = Hashtbl.Make (struct
  type t = (string * cut) list

  let equal =
    List.equal (fun (n, c) (n', c') ->
        String.equal n n' && DelaySet.equal_extremum c c')

  let hash =
    Hashing.list (fun (n, c) ->
        Hashing.combine (String.hash n) (DelaySet.hash_extremum c))
end)

let worlds = Worlds.create 16

let world classes =
  match Worlds.find_opt worlds classes with
  | Some w -> w
  | None ->
      let w =
        {
          id = Worlds.length worlds;
          names = Array.of_list (List.map fst classes);
          times = Array.of_list (List.map snd classes);
        }
      in
      Worlds.add worlds classes w;
      w

type concrete = Name of string | Length of Ops.t * Rational.t

module Make
    (E : IntervalRegex.S)
    (Steps : sig
      val whole : bool
    end) =
struct
  let upper = E.side = Upper

  (* {1 Weights}

     A weight is an extremal length, a supremum on the upper side and an
     infimum on the lower one, with an infinitesimal [harm] against admission
     of lower order than the flag of the value: the excess of a weight over an
     end of the bound not attained, the lengths of the bound approaching their
     ends more closely than those of the word. *)

  let zero_cut = Finite (Rational.zero, true)
  let plain value = { value; harm = false }
  let zero = plain zero_cut

  let add_weights w v =
    { value = add_cuts w.value v.value; harm = w.harm || v.harm }

  (* [passes x t] is whether the length [x] lies in the interval of the cut
     [t]. *)
  let passes x t =
    match (x, t) with
    | _, Infinite -> upper
    | Infinite, Finite _ -> not upper
    | Finite (a, f), Finite (c, g) ->
        let k = Rational.compare a c in
        (if upper then k < 0 else k > 0) || (k = 0 && (g || not f))

  let tie x t =
    match (x, t) with
    | Finite (a, true), Finite (c, _) -> Rational.equal a c
    | _ -> false

  let admits w t = passes w.value t && not (w.harm && tie w.value t)

  (* [excess w t] is the weight [w] less the finite cut [t], harmed if [t] is
     not attained. *)
  let excess w t =
    match (w.value, t) with
    | Finite (a, f), Finite (c, g) ->
        { value = Finite (Rational.sub a c, f); harm = w.harm || not g }
    | _ -> plain Infinite

  (* The order of the values of the side: [a⁻ < a] among suprema and
     [a < a⁺] among infima. *)
  let compare_value x y =
    match (x, y) with
    | Infinite, Infinite -> 0
    | Infinite, Finite _ -> 1
    | Finite _, Infinite -> -1
    | Finite (a, f), Finite (b, g) -> (
        match Rational.compare a b with
        | 0 -> if upper then Bool.compare f g else Bool.compare g f
        | c -> c)

  (* [better w w'] is the weight of the two that admits more: the lesser on
     the upper side, the greater on the lower one, a harmed weight worse. *)
  let better w w' =
    let c =
      match compare_value w.value w'.value with
      | 0 -> Bool.compare w.harm w'.harm * if upper then 1 else -1
      | c -> c
    in
    if (upper && c <= 0) || ((not upper) && c >= 0) then w else w'

  (* {1 Graphs of partial derivatives}

     The automaton of the partial derivatives of an expression (Antimirov,
     "Partial derivatives of regular expressions and finite automaton
     constructions", 1996), by its letters: operation sets and stretches. *)

  type letter = LOp of Ops.t | LStretch of Ops.t * cut

  (* [ends r] is whether [r] has the empty word without a stretch: a stretch
     is read at an end of its interval, its length [0] where the interval
     admits it being taken by the reader of the bound and, in a word of the
     lesser grade, dominated by its extremal length. *)
  let ends =
    let table = Memo.Ints.create 256 in
    let rec go r =
      Memo.Ints.find_or_add table (E.id r) (fun () ->
          match E.view r with
          | E.Eps | E.Star _ -> true
          | E.Empty | E.Op _ | E.Stretch _ -> false
          | E.Concat (a, b) -> go a && go b
          | E.Union rs -> List.exists go rs
          | E.Repeat (a, c) -> c.least = 0 || go a)
    in
    go

  let linear_forms = Memo.Ints.create 256

  let rec linear r =
    Memo.Ints.find_or_add linear_forms (E.id r) (fun () ->
        let after s = List.map (fun (l, r') -> (l, E.concat r' s)) in
        match E.view r with
        | E.Empty | E.Eps -> []
        | E.Op s -> [ (LOp s, E.eps) ]
        | E.Stretch (s, c) -> [ (LStretch (s, c), E.eps) ]
        | E.Concat (a, b) ->
            after b (linear a) @ if ends a then linear b else []
        | E.Union rs -> List.concat_map linear rs
        | E.Star a -> after r (linear a)
        | E.Repeat (a, c) -> (
            match Count.shift c 1 with
            | Some c' -> after (E.repeat a c') (linear a)
            | None -> []))

  type graph = {
    final : bool array;
    ops : (Ops.t * int) list array;
    out : int list array;
    dst : int array;
    set : Ops.t array;
    cut : cut array;
  }
  (* Node [0] is the expression; [ops.(n)] are the operation transitions of
     node [n], [out.(n)] the numbers of its stretch transitions, the
     stretch transition [e] going to [dst.(e)] with the set
     [set.(e)] and the cut [cut.(e)]. *)

  let graphs = Memo.Ints.create 64

  let graph r =
    Memo.Ints.find_or_add graphs (E.id r) (fun () ->
        let index = Hashtbl.create 64 and nodes = ref [] and count = ref 0 in
        let node r =
          match Hashtbl.find_opt index (E.id r) with
          | Some i -> (i, false)
          | None ->
              let i = !count in
              incr count;
              Hashtbl.add index (E.id r) i;
              nodes := r :: !nodes;
              (i, true)
        in
        let ops = ref [] and stretches = ref [] in
        let rec explore = function
          | [] -> ()
          | (i, r) :: rest ->
              let fresh =
                List.fold_left
                  (fun fresh (l, r') ->
                    let j, is_new = node r' in
                    (match l with
                    | LOp s -> ops := (i, s, j) :: !ops
                    | LStretch (s, c) -> stretches := (i, j, s, c) :: !stretches);
                    if is_new then (j, r') :: fresh else fresh)
                  []
                  (List.sort_uniq compare
                     (List.map (fun (l, r') -> (l, E.id r', r')) (linear r)
                     |> List.map (fun (l, _, r') -> (l, r'))))
              in
              explore (List.rev_append fresh rest)
        in
        let root, _ = node r in
        explore [ (root, r) ];
        let n = !count in
        let exprs = Array.of_list (List.rev !nodes) in
        let ops_of = Array.make n [] and out = Array.make n [] in
        List.iter (fun (i, s, j) -> ops_of.(i) <- (s, j) :: ops_of.(i)) !ops;
        let stretches = Array.of_list (List.rev !stretches) in
        Array.iteri (fun e (i, _, _, _) -> out.(i) <- e :: out.(i)) stretches;
        {
          final = Array.map ends exprs;
          ops = ops_of;
          out = Array.map List.rev out;
          dst = Array.map (fun (_, j, _, _) -> j) stretches;
          set = Array.map (fun (_, _, s, _) -> s) stretches;
          cut = Array.map (fun (_, _, _, c) -> c) stretches;
        })

  (* [classes world s] is the classes of [world] whose operations are in
     [s]. *)
  let classes world s =
    List.filter
      (fun k -> Ops.mem world.names.(k) s)
      (List.init (Array.length world.names) Fun.id)

  (* {1 Readers}

     The reader of a bound [m] reads the items of a word of the lesser grade,
     each at its extremal length, and is in a configuration: the nodes of [m]
     reached between items, and for the stretches of [m] entered, the least
     (upper side) or greatest (lower side) weight poured into each. An item is
     an operation, matched by an operation transition or poured into a
     stretch whose set contains it, a strict wait, poured into any stretch, or
     a budget, poured into a stretch whose set contains its own. The part of
     an item beyond the end of a stretch flows on into the stretches after it
     that admit it, through those of length [0] that do not: on the upper
     side by the longest path of the capacities of these stretches, which
     fill to their ends, and on the lower side by the shortest path of their
     demands, which are met. A configuration is closed under leaving a
     stretch whose cut admits its weight, the stretches of a node reached
     entered at weight [0]. A word is accepted when a final node is reached
     after its last item. *)

  type kind = KOp of int | KStrict | KBudget of Ops.t
  type item = { kind : kind; weight : weight }
  type config = { cid : int; at : int list; opened : (int * weight) list }
  type flow = { admit : bool array; reach : (int * cut) list option array }
  (* The stretches that admit a kind of item, and for each node from which a
     part of the item flows on, once computed, the nodes it reaches with the
     capacity or the demand of the way. *)

  type reader = {
    g : graph;
    matches : int list array array;
    flows : (bool list, flow) Hashtbl.t;
    configs : (int list * (int * weight) list, config) Hashtbl.t;
    items : (item, int) Hashtbl.t;
    steps : (int * int, config) Hashtbl.t;
    distances : (int * cut) list array -> int -> cut option array;
    edges : (bool list, (int * cut) list array) Hashtbl.t;
    world : world;
  }

  let make_reader world m =
    let g = graph m in
    {
      g;
      matches =
        Array.map
          (fun ops ->
            Array.init (Array.length world.names) (fun k ->
                List.filter_map
                  (fun (s, j) ->
                    if Ops.mem world.names.(k) s then Some j else None)
                  ops))
          g.ops;
      flows = Hashtbl.create 8;
      configs = Hashtbl.create 64;
      items = Hashtbl.create 16;
      steps = Hashtbl.create 256;
      distances =
        (if upper then DelayTimedClosure.longest else DelayTimedClosure.shortest);
      edges = Hashtbl.create 8;
      world;
    }

  let readers = Hashtbl.create 64

  let reader world m =
    match Hashtbl.find_opt readers (world.id, E.id m) with
    | Some r -> r
    | None ->
        let r = make_reader world m in
        Hashtbl.add readers (world.id, E.id m) r;
        r

  let admitted world kind s =
    match kind with
    | KOp k -> Ops.mem world.names.(k) s
    | KStrict -> true
    | KBudget s' -> Ops.subset s' s

  let flow r kind =
    let admit = Array.map (admitted r.world kind) r.g.set in
    let key = Array.to_list admit in
    match Hashtbl.find_opt r.flows key with
    | Some f -> f
    | None ->
        let f = { admit; reach = Array.make (Array.length r.g.final) None } in
        Hashtbl.add r.flows key f;
        f

  (* [reached r f q] is the nodes reached from [q] by the parts of an item
     admitted by [f], with the capacity (upper side) or the demand (lower
     side) of the way. *)
  let reached r f q =
    match f.reach.(q) with
    | Some l -> l
    | None ->
        let key = Array.to_list f.admit in
        let edges =
          match Hashtbl.find_opt r.edges key with
          | Some edges -> edges
          | None ->
              let edges =
                Array.map
                  (List.filter_map (fun e ->
                       if f.admit.(e) then Some (r.g.dst.(e), r.g.cut.(e))
                       else if admits zero r.g.cut.(e) then
                         Some (r.g.dst.(e), zero_cut)
                       else None))
                  r.g.out
              in
              Hashtbl.add r.edges key edges;
              edges
        in
        let d = r.distances edges q in
        let l =
          List.filter_map
            (fun n -> Option.map (fun c -> (n, c)) d.(n))
            (List.init (Array.length d) Fun.id)
        in
        f.reach.(q) <- Some l;
        l

  let put e w opened =
    IntMap.update e
      (function None -> Some w | Some w' -> Some (better w w'))
      opened

  (* [close r at opened] is the configuration of the nodes [at] and the
     stretches [opened], closed. A stretch of every length has the weight
     [0] on the upper side, and a stretch whose demand is met the weight [∞]
     on the lower side: all such weights admit alike. *)

  let close r at opened =
    let g = r.g in
    let opened = ref opened and seen = ref IntSet.empty in
    let queue = Queue.create () in
    IntSet.iter (fun n -> Queue.push n queue) at;
    IntMap.iter
      (fun e w -> if admits w g.cut.(e) then Queue.push g.dst.(e) queue)
      !opened;
    while not (Queue.is_empty queue) do
      let n = Queue.pop queue in
      if not (IntSet.mem n !seen) then begin
        seen := IntSet.add n !seen;
        List.iter
          (fun e ->
            opened := put e zero !opened;
            if admits zero g.cut.(e) then Queue.push g.dst.(e) queue)
          g.out.(n)
      end
    done;
    let opened =
      IntMap.bindings
        (if upper then
           IntMap.mapi
             (fun e w -> if g.cut.(e) = Infinite then zero else w)
             !opened
         else
           IntMap.mapi
             (fun e w -> if admits w g.cut.(e) then plain Infinite else w)
             !opened)
    in
    let at = IntSet.elements !seen in
    match Hashtbl.find_opt r.configs (at, opened) with
    | Some c -> c
    | None ->
        let c = { cid = Hashtbl.length r.configs; at; opened } in
        Hashtbl.add r.configs (at, opened) c;
        c

  let start r = close r (IntSet.singleton 0) IntMap.empty
  let accepts r c = List.exists (fun n -> r.g.final.(n)) c.at

  let item_id r item =
    match Hashtbl.find_opt r.items item with
    | Some i -> i
    | None ->
        let i = Hashtbl.length r.items in
        Hashtbl.add r.items item i;
        i

  let lesser w w' = if better w w' == w then w' else w

  let step_uncached r c item =
    let g = r.g in
    let f = flow r item.kind in
    let at = ref IntSet.empty and opened = ref IntMap.empty in
    (match item.kind with
    | KOp k ->
        List.iter
          (fun n ->
            List.iter (fun t -> at := IntSet.add t !at) r.matches.(n).(k))
          c.at
    | KStrict | KBudget _ -> ());
    let flow_from q x =
      List.iter
        (fun (n, l) ->
          if upper && admits x l then at := IntSet.add n !at
          else if upper || admits x l then
            let rest = excess x l in
            List.iter
              (fun e ->
                if f.admit.(e) && ((not upper) || admits rest g.cut.(e)) then
                  opened := put e rest !opened)
              g.out.(n))
        (reached r f q)
    in
    List.iter
      (fun (e, w) ->
        if f.admit.(e) then begin
          let t = add_weights w item.weight in
          let fits = admits t g.cut.(e) in
          if fits || not upper then opened := put e t !opened;

          if upper && not fits then flow_from g.dst.(e) (excess t g.cut.(e))
          else if (not upper) && fits then
            flow_from g.dst.(e) (lesser (excess t g.cut.(e)) item.weight)
        end)
      c.opened;
    close r !at !opened

  let step r c item =
    let key = (c.cid, item_id r item) in
    match Hashtbl.find_opt r.steps key with
    | Some c' -> c'
    | None ->
        let c' = step_uncached r c item in
        Hashtbl.add r.steps key c';
        c'

  (* {1 Search} *)

  type reading = Skip | Read of item

  (* [readings world l n] is the transitions of node [n] of the graph [l] of
     the lesser grade, each with the items it is read as and its target: an
     operation transition read as each class of its set at its running time,
     a stretch at the end of its interval, and on the lower side a stretch
     that may have length [0] also as no item. *)
  let readings world (l : graph) n =
    List.concat_map
      (fun (s, j) ->
        List.map
          (fun k ->
            (`Op k, Read { kind = KOp k; weight = plain world.times.(k) }, j))
          (classes world s))
      l.ops.(n)
    @ List.concat_map
        (fun e ->
          let s = l.set.(e) and c = l.cut.(e) and j = l.dst.(e) in
          let kind = if Ops.is_empty s then KStrict else KBudget s in
          if (not upper) && admits zero c then
            let positive =
              if Steps.whole then Finite (Rational.of_int 1, true)
              else Finite (Rational.zero, false)
            in
            [
              (`Skip, Skip, j);
              (`Length (s, positive), Read { kind; weight = plain positive }, j);
            ]
          else [ (`Length (s, c), Read { kind; weight = plain c }, j) ])
        l.out.(n)

  (* [search r l] is a shortest path of the graph of [l] to a final node at
     which the reader [r] rejects: breadth-first search of the pairs of a node
     and a configuration. *)
  let search world r l =
    let lg = graph l in
    let parent = Hashtbl.create 256 and queue = Queue.create () in
    let s = (0, start r) in
    Hashtbl.add parent (0, (snd s).cid) None;
    Queue.push s queue;
    let rec path key acc =
      match Hashtbl.find parent key with
      | None -> acc
      | Some (key', step) -> path key' (step :: acc)
    in
    let rec go () =
      if Queue.is_empty queue then None
      else
        let n, c = Queue.pop queue in
        if lg.final.(n) && not (accepts r c) then Some (path (n, c.cid) [])
        else begin
          List.iter
            (fun (label, reading, j) ->
              let c' = match reading with Skip -> c | Read i -> step r c i in
              let key = (j, c'.cid) in
              if not (Hashtbl.mem parent key) then begin
                Hashtbl.add parent key (Some ((n, c.cid), label));
                Queue.push (j, c') queue
              end)
            (readings world lg n);
          go ()
        end
    in
    go ()

  (* {1 Counterexamples} *)

  let half = Rational.make 1 2

  (* [concretise world r steps] is the word of the path [steps], each length
     chosen within [eps] of its end, or above [big] for an unbounded one, for
     the first [eps] of [1, 1/2, …] and [big] of [b, 2b, …] at which [r]
     rejects the word; [b] exceeds the sum of the finite ends of [r]. *)
  let concretise world r steps =
    let b =
      Array.fold_left
        (fun acc c ->
          match c with Finite (q, _) -> Rational.add acc q | Infinite -> acc)
        (Rational.of_int 1) r.g.cut
    in
    let length eps big = function
      | Finite (q, true) -> q
      | Finite (q, false) ->
          if upper then
            Rational.sub q
              (if Rational.compare eps q < 0 then eps else Rational.mul half q)
          else Rational.add q eps
      | Infinite -> big
    in
    let word eps big =
      List.filter_map
        (function
          | `Skip -> None
          | `Op k -> Some (Name world.names.(k), `Op k)
          | `Length (s, c) ->
              let d = length eps big c in
              Some (Length (s, d), `Length (s, d)))
        steps
    in
    let rejects w =
      let c =
        List.fold_left
          (fun c (_, label) ->
            match label with
            | `Op k -> step r c { kind = KOp k; weight = plain world.times.(k) }
            | `Length (s, d) ->
                step r c
                  {
                    kind = (if Ops.is_empty s then KStrict else KBudget s);
                    weight = plain (Finite (d, true));
                  })
          (start r) w
      in
      not (accepts r c)
    in
    let rec attempt n eps big =
      let w = word eps big in
      if rejects w || n >= 64 then List.map fst w
      else attempt (n + 1) (Rational.mul half eps) (Rational.add big big)
    in
    attempt 0 (Rational.of_int 1) b

  (* {1 Decisions} *)

  let decisions = Hashtbl.create 256

  let counterexample world l m =
    if E.equal l m then None
    else
      let key = (world.id, E.id l, E.id m) in
      match Hashtbl.find_opt decisions key with
      | Some (None as verdict) -> verdict
      | _ ->
          let r = reader world m in
          let found = search world r l in
          Hashtbl.replace decisions key found;
          Option.map (concretise world r) found

  let leq world l m =
    E.equal l m
    ||
    let key = (world.id, E.id l, E.id m) in
    match Hashtbl.find_opt decisions key with
    | Some verdict -> Option.is_none verdict
    | None ->
        let found = search world (reader world m) l in
        Hashtbl.add decisions key found;
        Option.is_none found

  (* {1 Durations} *)

  (* [extreme ~longest world e] is the greatest (or least) duration of the
     words of [e], each operation at the running time of [world] and each
     stretch at the end of its interval (or at the other end), [None] if [e]
     has no word over [world]. *)
  let extreme ~longest world e =
    let g = graph e in
    (* The greater of two durations among suprema, [a⁻ < a], or the lesser
       among infima, [a < a⁺]. *)
    let pick_down c c' =
      let k =
        match (c, c') with
        | Infinite, Infinite -> 0
        | Infinite, _ -> 1
        | _, Infinite -> -1
        | Finite (a, f), Finite (b, g) -> (
            match Rational.compare a b with
            | 0 -> if longest then Bool.compare f g else Bool.compare g f
            | k -> k)
      in
      if longest then if k >= 0 then c else c' else if k <= 0 then c else c'
    in
    let edges =
      Array.mapi
        (fun n ops ->
          List.filter_map
            (fun (s, j) ->
              match classes world s with
              | [] -> None
              | k :: ks ->
                  Some
                    ( j,
                      List.fold_left
                        (fun c k -> pick_down c world.times.(k))
                        world.times.(k) ks ))
            ops
          @ List.map
              (fun e ->
                ( g.dst.(e),
                  match (upper, longest) with
                  | true, true | false, false -> g.cut.(e)
                  | true, false -> zero_cut
                  | false, true -> Infinite ))
              g.out.(n))
        g.ops
    in
    let d =
      (if longest then DelayTimedClosure.longest edges
       else DelayTimedClosure.shortest edges)
        0
    in
    let best = ref None in
    Array.iteri
      (fun n f ->
        if f then
          match d.(n) with
          | Some c ->
              best :=
                Some (match !best with None -> c | Some b -> pick_down b c)
          | None -> ())
      g.final;
    !best

  let max_weight = extreme ~longest:true
  let min_weight = extreme ~longest:false
  let inhabited world e = Option.is_some (min_weight world e)
end
