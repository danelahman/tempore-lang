(* Property tests of the sets of delays against the implementation of
   [DelaySetReference], which keeps them as lists of intervals with rational
   ends: on random sets, mixed, dense, point-heavy and on grids of coprime
   denominators, and on the families with long finite parts at small sizes,
   every operation of the interface gives the same sets, printed and hashed
   alike, and the same answers. *)

module D = Grades.DelaySet
module R = DelaySetReference
module Rational = Grades.Rational

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let every name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true ""
  | Some x -> check name false ("fails on " ^ show x)

let q = Rational.make
let qi = Rational.of_int

(* {1 Expressions} *)

type expr =
  | Point of Rational.t
  | Interval of Rational.t * bool * Rational.t option * bool
  | Union of expr * expr
  | Inter of expr * expr
  | Diff of expr * expr
  | Compl of expr
  | Sum of expr * expr
  | Star of expr

let rec show_expr = function
  | Point x -> Rational.show x
  | Interval (a, ac, b, bc) ->
      (if ac then "[" else "(")
      ^ Rational.show a ^ ", "
      ^ (match b with Some b -> Rational.show b | None -> "∞")
      ^ if bc then "]" else ")"
  | Union (e, f) -> "(" ^ show_expr e ^ " ∪ " ^ show_expr f ^ ")"
  | Inter (e, f) -> "(" ^ show_expr e ^ " ∩ " ^ show_expr f ^ ")"
  | Diff (e, f) -> "(" ^ show_expr e ^ " ∖ " ^ show_expr f ^ ")"
  | Compl e -> "∁" ^ show_expr e
  | Sum (e, f) -> "(" ^ show_expr e ^ " + " ^ show_expr f ^ ")"
  | Star e -> show_expr e ^ "*"

let rec build = function
  | Point x -> D.point x
  | Interval (lo, lo_closed, hi, hi_closed) ->
      D.interval ~lo ~lo_closed ~hi ~hi_closed
  | Union (e, f) -> D.union (build e) (build f)
  | Inter (e, f) -> D.inter (build e) (build f)
  | Diff (e, f) -> D.diff (build e) (build f)
  | Compl e -> D.compl (build e)
  | Sum (e, f) -> D.sum (build e) (build f)
  | Star e -> D.star (build e)

let rec reference = function
  | Point x -> R.point x
  | Interval (lo, lo_closed, hi, hi_closed) ->
      R.interval ~lo ~lo_closed ~hi ~hi_closed
  | Union (e, f) -> R.union (reference e) (reference f)
  | Inter (e, f) -> R.inter (reference e) (reference f)
  | Diff (e, f) -> R.diff (reference e) (reference f)
  | Compl e -> R.compl (reference e)
  | Sum (e, f) -> R.sum (reference e) (reference f)
  | Star e -> R.star (reference e)

(* {1 Random expressions}

   Atoms whose ends are multiples of [1/d] for a denominator [d] drawn from
   [dens], below [range], of widths below [width] and points with probability
   [points]; expressions of depth at most [depth], with sums and repetitions
   only if [sums]. *)

let pick st xs = List.nth xs (Random.State.int st (List.length xs))

let random_atom st ~dens ~range ~width ~points =
  let d = pick st dens in
  let a = q (Random.State.int st (range * d)) d in
  if Random.State.float st 1. < points then Point a
  else
    let d' = pick st dens in
    let b =
      if Random.State.float st 1. < 0.15 then None
      else Some (Rational.add a (q (Random.State.int st ((width * d') + 1)) d'))
    in
    match b with
    | Some b when Rational.equal a b -> Point a
    | _ -> Interval (a, Random.State.bool st, b, Random.State.bool st)

let rec random st ~atom ~sums depth =
  if depth = 0 || Random.State.float st 1. < 0.3 then atom st
  else
    let sub () = random st ~atom ~sums (depth - 1) in
    match Random.State.int st (if sums then 8 else 4) with
    | 0 -> Union (sub (), sub ())
    | 1 -> Inter (sub (), sub ())
    | 2 -> Diff (sub (), sub ())
    | 3 -> Compl (sub ())
    | 4 | 5 -> Sum (sub (), sub ())
    | _ -> Star (sub ())

let pool ~seed ~n ~dens ~range ~width ~points ~depth =
  let st = Random.State.make [| seed |] in
  List.init n (fun _ ->
      random st ~sums:true depth ~atom:(random_atom ~dens ~range ~width ~points))

let mixed =
  pool ~seed:1 ~n:900 ~dens:[ 1; 2; 3; 4 ] ~range:13 ~width:7 ~points:0.4
    ~depth:3

let dense =
  pool ~seed:2 ~n:500 ~dens:[ 1; 2; 5; 10 ] ~range:12 ~width:3 ~points:0.1
    ~depth:3

let point_heavy =
  pool ~seed:3 ~n:500 ~dens:[ 1 ] ~range:30 ~width:2 ~points:0.9 ~depth:3

let coprime =
  pool ~seed:4 ~n:500 ~dens:[ 5; 7; 9; 11; 13 ] ~range:4 ~width:2 ~points:0.5
    ~depth:2

(* The families with long finite parts, at small sizes, and their
   complements. *)
let families =
  let point n = Point (qi n) and frac a b = Point (q a b) in
  let base =
    List.map
      (fun n -> Star (Union (point n, point (n + 1))))
      [ 2; 3; 5; 8; 13; 20 ]
    @ List.map
        (fun (a, b) -> Sum (Star a, Star b))
        [
          (point 3, point 5);
          (point 9, point 7);
          (point 4, point 6);
          (point 17, point 19);
          (frac 1 2, frac 1 3);
          (frac 2 3, frac 3 4);
          (point 3, frac 5 2);
          (frac 1 7, frac 1 11);
        ]
    @ List.map
        (fun w ->
          Star
            (Union
               ( point 1,
                 Interval (qi 10, false, Some (Rational.add (qi 10) w), false)
               )))
        [ q 1 2; q 1 3; q 1 5; q 1 10; q 1 20 ]
    @ List.map
        (fun (a, b) -> Star (Union (frac 1 a, frac 1 b)))
        [ (7, 5); (13, 11); (97, 89) ]
    @ List.map
        (fun w ->
          Star (Interval (qi 1, true, Some (Rational.add (qi 1) w), true)))
        [ q 1 2; q 1 10; q 1 100 ]
  in
  base @ List.map (fun e -> Compl e) base

let expressions = mixed @ dense @ point_heavy @ coprime @ families
let sets = List.map (fun e -> (e, build e, reference e)) expressions

(* {1 Comparisons} *)

let same s r = String.equal (D.show s) (R.show r) && D.hash s = R.hash r

let same_extremum (x : D.extremum option) (y : R.extremum option) =
  match (x, y) with
  | None, None -> true
  | Some D.Infinite, Some R.Infinite -> true
  | Some (D.Finite (a, f)), Some (R.Finite (b, g)) ->
      Rational.equal a b && Bool.equal f g
  | _ -> false

let rec same_intervals (xs : D.interval list) (ys : R.interval list) =
  match (xs, ys) with
  | [], [] -> true
  | i :: xs, j :: ys ->
      Rational.equal i.lo j.lo
      && Bool.equal i.lo_closed j.lo_closed
      && Rational.equal i.hi j.hi
      && Bool.equal i.hi_closed j.hi_closed
      && same_intervals xs ys
  | _ -> false

let rec same_lists xs ys =
  match (xs, ys) with
  | [], [] -> true
  | s :: xs, r :: ys -> same s r && same_lists xs ys
  | _ -> false

let show1 (e, _, _) = show_expr e
let show2 (x, y) = show1 x ^ " and " ^ show1 y
let show3 (x, y, z) = show2 (x, y) ^ " and " ^ show1 z
let firsts n xs = List.filteri (fun i _ -> i < n) xs
let lasts n xs = List.filteri (fun i _ -> i >= List.length xs - n) xs

(* Probes: the ends of the first and the last intervals of a set up to its
   threshold plus two periods, a little off them, between them, and off the
   grid. *)
let probes s =
  let x = Rational.add (R.threshold s) (Rational.mul (qi 2) (R.period s)) in
  let eps = q 1 997 and ivs = R.intervals_upto x s in
  qi (-1) :: q 7 3 :: q 101 1000
  :: List.concat_map
       (fun (i : R.interval) ->
         [
           i.lo;
           i.hi;
           Rational.add i.lo eps;
           Rational.sub i.hi eps;
           Rational.div (Rational.add i.lo i.hi) (qi 2);
           Rational.add i.hi eps;
         ])
       (firsts 30 ivs @ lasts 30 ivs)

(* [draw n xs] is [n] random pairs of elements of [xs]. *)
let draw seed n xs =
  let st = Random.State.make [| seed |] and a = Array.of_list xs in
  List.init n (fun _ ->
      ( a.(Random.State.int st (Array.length a)),
        a.(Random.State.int st (Array.length a)) ))

(* [moderate n (_, _, r)] is whether the set [r] has at most [n] intervals up
   to its threshold plus a period. *)
let moderate n (_, _, r) =
  List.compare_length_with
    (R.intervals_upto (Rational.add (R.threshold r) (R.period r)) r)
    n
  <= 0

(* The pairs of the random sets, and of a family of at most 1000 intervals and
   a random set. *)
let small = firsts (List.length expressions - List.length families) sets

let with_families =
  List.filter (moderate 1000) (lasts (List.length families) sets)

let pairs =
  draw 5 2500 small
  @ List.map2
      (fun (f, _) (_, x) -> (f, x))
      (draw 6 300 with_families) (draw 7 300 small)

(* The pairs of the random sets of at most 100 intervals up to their
   threshold plus a period, whose sums are of a moderate size. *)
let small_pairs =
  List.filter
    (fun (x, y) -> moderate 100 x && moderate 100 y)
    (draw 8 2500 small)

let triples =
  List.map2
    (fun (x, y) (z, _) -> (x, y, z))
    (draw 9 300 small) (draw 10 300 sets)

(* Sets of the same threshold and period on different grids, ordered by the
   closure of an end of equal value. *)
let across_grids =
  let sets =
    List.concat_map
      (fun (lo_closed, hi_closed) ->
        List.map
          (fun x ->
            let e =
              Union
                ( Union
                    (Interval (qi 0, lo_closed, Some (qi 1), hi_closed), Point x),
                  Point (qi 2) )
            in
            (e, build e, reference e))
          [ q 3 2; q 4 3; q 5 4 ])
      [ (true, true); (true, false); (false, true); (false, false) ]
  in
  List.concat_map (fun x -> List.map (fun y -> (x, y)) sets) sets

let unary name f g = every name show1 (fun (_, s, r) -> same (f s) (g r)) sets

let binary name f g xs =
  every name show2 (fun ((_, s, r), (_, s', r')) -> same (f s s') (g r r')) xs

let answer name f g xs =
  every name show2 (fun ((_, s, r), (_, s', r')) -> f s s' = g r r') xs

let checks =
  [
    every "built sets" show1 (fun (_, s, r) -> same s r) sets;
    every "threshold and period" show1
      (fun (_, s, r) ->
        Rational.equal (D.threshold s) (R.threshold r)
        && Rational.equal (D.period s) (R.period r))
      sets;
    every "is_empty" show1 (fun (_, s, r) -> D.is_empty s = R.is_empty r) sets;
    every "inf and sup" show1
      (fun (_, s, r) ->
        same_extremum (D.inf s) (R.inf r) && same_extremum (D.sup s) (R.sup r))
      sets;
    every "choose" show1
      (fun (_, s, r) -> Option.equal Rational.equal (D.choose s) (R.choose r))
      sets;
    every "mem" show1
      (fun (_, s, r) ->
        List.for_all (fun x -> D.mem x s = R.mem x r) (probes r))
      sets;
    every "intervals_upto" show1
      (fun (_, s, r) ->
        List.for_all
          (fun x ->
            same_intervals (D.intervals_upto x s) (R.intervals_upto x r))
          (firsts 12 (probes r)))
      sets;
    every "to_regex" show1 (fun (_, s, r) -> D.to_regex s = R.to_regex r) sets;
    unary "compl" D.compl R.compl;
    unary "star" D.star R.star;
    binary "union" D.union R.union pairs;
    binary "inter" D.inter R.inter pairs;
    binary "diff" D.diff R.diff pairs;
    binary "sum" D.sum R.sum small_pairs;
    answer "intersects" D.intersects R.intersects pairs;
    answer "subset" D.subset R.subset pairs;
    answer "equal" D.equal R.equal pairs;
    answer "compare" D.compare R.compare pairs;
    answer "compare across grids" D.compare R.compare across_grids;
    every "equal and compare of a set and its copy" show1
      (fun (e, s, _) ->
        let s' = build e in
        D.equal s s' && D.compare s s' = 0 && D.hash s = D.hash s')
      sets;
    every "minterms" show3
      (fun ((_, s, r), (_, s', r'), (_, s'', r'')) ->
        same_lists (D.minterms [ s; s'; s'' ]) (R.minterms [ r; r'; r'' ]))
      triples;
  ]

let () =
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
