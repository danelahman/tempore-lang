open IntervalRegex

(* {1 Worlds} *)

type world = { id : int; names : string array; lo : cut array; hi : cut array }

module Worlds = Hashtbl.Make (struct
  type t = (string * (cut * cut)) list

  let equal =
    List.equal (fun (n, (l, h)) (n', (l', h')) ->
        String.equal n n'
        && DelaySet.equal_extremum l l'
        && DelaySet.equal_extremum h h')

  let hash =
    Hashing.list (fun (n, (l, h)) ->
        Hashing.combine (String.hash n)
          (Hashing.combine (DelaySet.hash_extremum l) (DelaySet.hash_extremum h)))
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
          lo = Array.of_list (List.map (fun (_, (l, _)) -> l) classes);
          hi = Array.of_list (List.map (fun (_, (_, h)) -> h) classes);
        }
      in
      Worlds.add worlds classes w;
      w

let id w = w.id

(* [classes world s] is the classes of [world] whose operations are in
   [s]. *)
let classes world s =
  List.filter
    (fun k -> Ops.mem world.names.(k) s)
    (List.init (Array.length world.names) Fun.id)

type item = Op of string * Rational.t | Wait of Rational.t

(* {1 Difference-bound matrices}

   A matrix [d] over variables [x₀, …, xₙ] bounds each difference
   [xᵢ − xⱼ] by [d.(i).(j)]: [Le q] for [≤ q], [Lt q] for [< q], [Inf] for
   no bound (Dill 1989). *)

type bound = Le of Rational.t | Lt of Rational.t | Inf

let compare_bound b b' =
  match (b, b') with
  | Inf, Inf -> 0
  | Inf, _ -> 1
  | _, Inf -> -1
  | (Le q | Lt q), (Le q' | Lt q') -> (
      match Rational.compare q q' with
      | 0 -> ( match (b, b') with Lt _, Le _ -> -1 | Le _, Lt _ -> 1 | _ -> 0)
      | c -> c)

let min_bound b b' = if compare_bound b b' <= 0 then b else b'

let add_bound b b' =
  match (b, b') with
  | Inf, _ | _, Inf -> Inf
  | Le q, Le q' -> Le (Rational.add q q')
  | (Le q | Lt q), (Le q' | Lt q') -> Lt (Rational.add q q')

let le_zero = Le Rational.zero

(* [close d] is the canonical form of [d], every bound tightened along the
   paths through the other variables (Floyd–Warshall). *)
let close d =
  let d = Array.map Array.copy d in
  let n = Array.length d in
  for k = 0 to n - 1 do
    for i = 0 to n - 1 do
      for j = 0 to n - 1 do
        d.(i).(j) <- min_bound d.(i).(j) (add_bound d.(i).(k) d.(k).(j))
      done
    done
  done;
  d

(* [tighten d entries] is the canonical form of [d] with the bounds [entries]
   added. *)
let tighten d entries =
  let d = Array.map Array.copy d in
  List.iter (fun (i, j, b) -> d.(i).(j) <- min_bound d.(i).(j) b) entries;
  close d

let is_empty d =
  let rec go i =
    i < Array.length d && (compare_bound d.(i).(i) le_zero < 0 || go (i + 1))
  in
  go 0

(* {2 Guards} *)

(* A guard on the length of a letter: within a lower cut, [≥ q] or [> q], or
   within an upper cut, [≤ q], [< q] or unbounded. *)
type guard = At_least of cut | At_most of cut

(* [entries ~var ~origin g] is the bounds of the matrix stating [g] of the
   difference [var − origin]. *)
let entries ~var ~origin = function
  | At_least (Finite (q, closed)) ->
      let q = Rational.neg q in
      [ (origin, var, if closed then Le q else Lt q) ]
  | At_least Infinite -> [ (origin, origin, Lt Rational.zero) ]
  | At_most (Finite (q, closed)) ->
      [ (var, origin, if closed then Le q else Lt q) ]
  | At_most Infinite -> []

(* {2 Zones}

   A zone is a canonical matrix over the reference [0] and the clocks [1] of
   the lower bound and [2] of the upper bound. *)

let start_zone = Array.make_matrix 3 3 le_zero

(* [up z] lets time pass: the clocks lose their upper bounds. *)
let up z =
  Array.mapi
    (fun i row ->
      Array.mapi (fun j b -> if j = 0 && i <> 0 then Inf else b) row)
    z

(* [reset z x] sets the clock [x] to [0]. *)
let reset z x =
  Array.init 3 (fun i ->
      Array.init 3 (fun j ->
          if i = x && j = x then le_zero
          else if i = x then z.(0).(j)
          else if j = x then z.(i).(0)
          else z.(i).(j)))

(* [extrapolate k z] is [z] with every bound beyond the greatest constant
   [k.(i)] of its clocks dropped or lowered to it (Extra_M; Bengtsson and Yi
   2004). *)
let extrapolate k z =
  close
    (Array.init 3 (fun i ->
         Array.init 3 (fun j ->
             let b = z.(i).(j) in
             if i = j then b
             else if i <> 0 && compare_bound b (Le k.(i)) > 0 then Inf
             else if j <> 0 && compare_bound b (Lt (Rational.neg k.(j))) < 0
             then Lt (Rational.neg k.(j))
             else b)))

let included z z' =
  let rec go i j =
    i = 3
    || (j = 3 && go (i + 1) 0)
    || (j < 3 && compare_bound z.(i).(j) z'.(i).(j) <= 0 && go i (j + 1))
  in
  go 0 0

(* {1 The automaton} *)

(* The letter in progress on one bound: none, a stretch transition, an
   operation of a class with the target of its transition, or an operation
   matched by the same operation of the other bound. *)
type phase = Between | Stretch of int | Op of int * int | Matched of int * int

(* A location: on each bound, a node and the letter in progress. *)
type location = { nl : int; pl : phase; nu : int; pu : phase }

(* What a transition does to the run: nothing, an operation of a class
   beginning, timed by a clock, or the operation timed by a clock ending. *)
type event = Silent | Begins of int * int | Ends of int

type transition = {
  target : location;
  guards : (int * guard) list;
  resets : int list;
  event : event;
}

type side = { graph : IntervalClosure.graph; lower : bool }

type context = {
  world : world;
  positive : guard;
  sides : side array;
  constants : Rational.t array;
}

let side ctx c = ctx.sides.(c - 1)
let get loc c = if c = 1 then (loc.nl, loc.pl) else (loc.nu, loc.pu)

let put loc c (n, p) =
  if c = 1 then { loc with nl = n; pl = p } else { loc with nu = n; pu = p }

let elapses loc = loc.pl <> Between && loc.pu <> Between

let accepting ctx loc =
  loc.pl = Between && loc.pu = Between
  && (side ctx 1).graph.final.(loc.nl)
  && (side ctx 2).graph.final.(loc.nu)

(* [admits_zero ~lower c] is whether the interval of the cut [c] on its side
   contains [0]. *)
let admits_zero ~lower = function
  | Finite (q, closed) ->
      if lower then Rational.sign q = 0 && closed
      else Rational.sign q > 0 || closed
  | Infinite -> not lower

(* [hosts ctx c phase k] is whether the letter [phase] in progress on the
   bound [c] admits an operation of the class [k] of the other bound beside
   it. *)
let hosts ctx c phase k =
  match phase with
  | Between -> true
  | Stretch e -> Ops.mem ctx.world.names.(k) (side ctx c).graph.set.(e)
  | Op _ | Matched _ -> false

(* [beside s phase] is whether a stretch of the set [s] may begin beside the
   letter [phase] of the other bound. *)
let beside ctx s = function
  | Op (k, _) -> Ops.mem ctx.world.names.(k) s
  | Matched _ -> false
  | Between | Stretch _ -> true

let op_guards ctx c k =
  [
    (c, At_least ctx.world.lo.(k));
    (c, At_most ctx.world.hi.(k));
    (c, ctx.positive);
  ]

let silent target guards resets = { target; guards; resets; event = Silent }

(* [moves ctx loc c] is the transitions of the bound [c] alone. *)
let moves ctx loc c =
  let o = 3 - c in
  let { graph = g; lower } = side ctx c in
  let _, other = get loc o in
  match get loc c with
  | n, Between ->
      List.concat_map
        (fun e ->
          (if admits_zero ~lower g.cut.(e) then
             [ silent (put loc c (g.dst.(e), Between)) [] [] ]
           else [])
          @
          if beside ctx g.set.(e) other then
            [ silent (put loc c (n, Stretch e)) [] [ c ] ]
          else [])
        g.out.(n)
      @ List.concat_map
          (fun (s, j) ->
            List.filter_map
              (fun k ->
                if hosts ctx o other k then
                  Some
                    {
                      target = put loc c (n, Op (k, j));
                      guards = [];
                      resets = [ c ];
                      event = Begins (k, c);
                    }
                else None)
              (classes ctx.world s))
          g.ops.(n)
  | _, Stretch e ->
      let guard = if lower then At_least g.cut.(e) else At_most g.cut.(e) in
      [ silent (put loc c (g.dst.(e), Between)) [ (c, guard) ] [] ]
  | _, Op (k, j) ->
      [
        {
          target = put loc c (j, Between);
          guards = op_guards ctx c k;
          resets = [];
          event = Ends c;
        };
      ]
  | _, Matched _ -> []

(* [matches ctx loc] is the transitions of both bounds at once: an operation
   matched on both, beginning and ending together, timed by the clock [1]. *)
let matches ctx loc =
  match (loc.pl, loc.pu) with
  | Between, Between ->
      let gl = (side ctx 1).graph and gu = (side ctx 2).graph in
      List.concat_map
        (fun (s, j) ->
          List.concat_map
            (fun (s', j') ->
              List.map
                (fun k ->
                  {
                    target =
                      { loc with pl = Matched (k, j); pu = Matched (k, j') };
                    guards = [];
                    resets = [ 1; 2 ];
                    event = Begins (k, 1);
                  })
                (classes ctx.world (Ops.inter s s')))
            gu.ops.(loc.nu))
        gl.ops.(loc.nl)
  | Matched (k, j), Matched (_, j') ->
      [
        {
          target = { nl = j; pl = Between; nu = j'; pu = Between };
          guards = op_guards ctx 1 k;
          resets = [];
          event = Ends 1;
        };
      ]
  | _ -> []

let transitions ctx loc = matches ctx loc @ moves ctx loc 1 @ moves ctx loc 2

(* [step ctx z t] is the zone reached from [z] by [t], with the time that
   may pass in its target, if non-empty. *)
let step ctx z t =
  let z =
    tighten z
      (List.concat_map (fun (c, g) -> entries ~var:c ~origin:0 g) t.guards)
  in
  if is_empty z then None
  else
    let z = List.fold_left reset z t.resets in
    Some (extrapolate ctx.constants (if elapses t.target then up z else z))

(* [search ctx] is the transitions of a path to an accepting location, each
   with its source: breadth-first search of the pairs of a location and a
   zone, a zone included in one of its location already reached being
   dropped. *)
let search ctx =
  let start = { nl = 0; pl = Between; nu = 0; pu = Between } in
  let passed = Hashtbl.create 64 and parent = Hashtbl.create 64 in
  let queue = Queue.create () in
  let visit loc z via =
    let zones = Option.value ~default:[] (Hashtbl.find_opt passed loc) in
    if not (List.exists (included z) zones) then begin
      let i = Hashtbl.length parent in
      Hashtbl.replace passed loc (z :: zones);
      Hashtbl.add parent i via;
      Queue.push (i, loc, z) queue
    end
  in
  let rec path i acc =
    match Hashtbl.find parent i with
    | None -> acc
    | Some (i', source, t) -> path i' ((source, t) :: acc)
  in
  let rec go () =
    match Queue.take_opt queue with
    | None -> None
    | Some (i, loc, _) when accepting ctx loc -> Some (path i [])
    | Some (i, loc, z) ->
        List.iter
          (fun t ->
            Option.iter
              (fun z' -> visit t.target z' (Some (i, loc, t)))
              (step ctx z t))
          (transitions ctx loc);
        go ()
  in
  visit start (extrapolate ctx.constants start_zone) None;
  go ()

(* {1 Runs} *)

(* [times path] is a time for each transition of [path], [0] first: the
   transitions are variables of a matrix bounding them by their order, the
   locations in which no time passes and the guards on the time since the
   last reset of each clock; each is fixed in turn, within the bounds that
   the times fixed before leave it, the least if attained. *)
let times path =
  let n = List.length path in
  let d =
    Array.init (n + 1) (fun i ->
        Array.init (n + 1) (fun j -> if i = j then le_zero else Inf))
  in
  let _, _, constraints =
    List.fold_left
      (fun (i, last, acc) (source, t) ->
        let i = i + 1 in
        let order =
          (i - 1, i, le_zero)
          :: (if elapses source then [] else [ (i, i - 1, le_zero) ])
        in
        let guards =
          List.concat_map
            (fun (c, g) -> entries ~var:i ~origin:(List.assoc c last) g)
            t.guards
        in
        let last =
          List.map
            (fun (c, r) -> (c, if List.mem c t.resets then i else r))
            last
        in
        (i, last, order @ guards @ acc))
      (0, [ (1, 0); (2, 0) ], [])
      path
  in
  let d = tighten d constraints in
  let half = Rational.make 1 2 in
  (* [fix d i v] is the canonical [d] with the variable [i] at [v]: the
     bounds through the two edges set are tightened. *)
  let fix d i v =
    let d = Array.map Array.copy d in
    let through x y c =
      for a = 0 to n do
        for b = 0 to n do
          d.(a).(b) <-
            min_bound d.(a).(b) (add_bound (add_bound d.(a).(x) c) d.(y).(b))
        done
      done
    in
    through i 0 (Le v);
    through 0 i (Le (Rational.neg v));
    d
  in
  let rec assign d i acc =
    if i > n then List.rev acc
    else
      let v =
        match (d.(0).(i), d.(i).(0)) with
        | Le a, _ -> Rational.neg a
        | Lt a, (Le b | Lt b) -> Rational.mul half (Rational.sub b a)
        | Lt a, Inf -> Rational.add (Rational.neg a) (Rational.of_int 1)
        | Inf, _ -> Rational.zero
      in
      assign (fix d i v) (i + 1) (v :: acc)
  in
  Array.of_list (Rational.zero :: assign d 1 [])

(* [run world path] is the run of [path]: its operations at the spans of
   their transitions, in order, and strict waits between them and to the
   end. *)
let run world path =
  let t = times path in
  let _, _, spans =
    List.fold_left
      (fun (i, opened, spans) (_, tr) ->
        let i = i + 1 in
        match tr.event with
        | Silent -> (i, opened, spans)
        | Begins (k, c) -> (i, (c, (t.(i), k)) :: opened, spans)
        | Ends c ->
            let s, k = List.assoc c opened in
            (i, List.remove_assoc c opened, (s, t.(i), k) :: spans))
      (0, [], []) path
  in
  let spans =
    List.sort (fun (s, _, _) (s', _, _) -> Rational.compare s s') spans
  in
  let wait a b =
    if Rational.compare a b < 0 then [ Wait (Rational.sub b a) ] else []
  in
  let cursor, items =
    List.fold_left
      (fun (cursor, items) (s, f, k) ->
        (f, items @ wait cursor s @ [ Op (world.names.(k), Rational.sub f s) ]))
      (Rational.zero, []) spans
  in
  items @ wait cursor t.(Array.length t - 1)

(* [greatest cuts] is the greatest finite value of [cuts], at least [1]. *)
let greatest cuts =
  List.fold_left
    (fun acc c ->
      match c with
      | Finite (q, _) when Rational.compare q acc > 0 -> q
      | _ -> acc)
    (Rational.of_int 1) cuts

let witness ~whole world ~lower ~upper =
  let times = Array.to_list world.lo @ Array.to_list world.hi in
  let constant (g : IntervalClosure.graph) =
    greatest (Array.to_list g.cut @ times)
  in
  let ctx =
    {
      world;
      positive =
        (if whole then At_least (Finite (Rational.of_int 1, true))
         else At_least (Finite (Rational.zero, false)));
      sides =
        [| { graph = lower; lower = true }; { graph = upper; lower = false } |];
      constants = [| Rational.zero; constant lower; constant upper |];
    }
  in
  Option.map (run world) (search ctx)
