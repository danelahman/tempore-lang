(* Unit tests of the sets of delays: their operations on random expressions
   against a bounded-window oracle that uses no periodicity, the laws of the
   Boolean algebra, of the sum and of the repetition decided on the canonical
   forms, worked cases of the repetition, extremal values, simplest elements,
   minterms and printing. *)

module DelaySet = Grades.DelaySet
module Rational = Grades.Rational

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let every name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true ""
  | Some x -> check name false ("fails on " ^ show x)

let q = Rational.make
let qi = Rational.of_int

(* Expressions over the sets of delays. *)
type expr =
  | Point of Rational.t
  | Interval of Rational.t * bool * Rational.t option * bool
  | Union of expr * expr
  | Inter of expr * expr
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
  | Compl e -> "∁" ^ show_expr e
  | Sum (e, f) -> "(" ^ show_expr e ^ " + " ^ show_expr f ^ ")"
  | Star e -> show_expr e ^ "*"

let rec build = function
  | Point x -> DelaySet.point x
  | Interval (lo, lo_closed, hi, hi_closed) ->
      DelaySet.interval ~lo ~lo_closed ~hi ~hi_closed
  | Union (e, f) -> DelaySet.union (build e) (build f)
  | Inter (e, f) -> DelaySet.inter (build e) (build f)
  | Compl e -> DelaySet.compl (build e)
  | Sum (e, f) -> DelaySet.sum (build e) (build f)
  | Star e -> DelaySet.star (build e)

(* {1 The oracle}

   Interval lists of its own: [e ∩ [0, X]] computed by interval arithmetic,
   sums as sums of the windows, since a sum of elements at most [X] uses only
   elements at most [X], and repetitions by iterating [R := R ∪ (R + A)] to a
   fixpoint, [A] the window without [0]. *)

type iv = Rational.t * bool * Rational.t * bool

let nonempty ((a, ac, b, bc) : iv) =
  let c = Rational.compare a b in
  c < 0 || (c = 0 && ac && bc)

let norm (ivs : iv list) =
  let key (a, ac, _, _) (b, bc, _, _) =
    match Rational.compare a b with 0 -> Bool.compare bc ac | c -> c
  in
  let sorted = List.sort key (List.filter nonempty ivs) in
  List.rev
    (List.fold_left
       (fun acc ((c, cc, d, dc) as i) ->
         match acc with
         | (a, ac, b, bc) :: rest
           when Rational.compare c b < 0 || (Rational.equal c b && (bc || cc))
           ->
             let hi, hc =
               match Rational.compare d b with
               | 0 -> (b, bc || dc)
               | k when k > 0 -> (d, dc)
               | _ -> (b, bc)
             in
             (a, ac, hi, hc) :: rest
         | _ -> i :: acc)
       [] sorted)

let meet ((a, ac, b, bc) : iv) ((c, cc, d, dc) : iv) : iv =
  let lo, lc =
    match Rational.compare a c with
    | 0 -> (a, ac && cc)
    | k when k > 0 -> (a, ac)
    | _ -> (c, cc)
  in
  let hi, hc =
    match Rational.compare b d with
    | 0 -> (b, bc && dc)
    | k when k < 0 -> (b, bc)
    | _ -> (d, dc)
  in
  (lo, lc, hi, hc)

let inter xs ys = norm (List.concat_map (fun x -> List.map (meet x) ys) xs)

let sum xs ys =
  norm
    (List.concat_map
       (fun (a, ac, b, bc) ->
         List.map
           (fun (c, cc, d, dc) ->
             (Rational.add a c, ac && cc, Rational.add b d, bc && dc))
           ys)
       xs)

(* The complement of [ivs] within [[0, x]]. *)
let complement x ivs =
  let gaps, (lo, lc) =
    List.fold_left
      (fun (gaps, (lo, lc)) (a, ac, b, bc) ->
        ((lo, lc, a, not ac) :: gaps, (b, not bc)))
      ([], (Rational.zero, true))
      ivs
  in
  norm ((lo, lc, x, true) :: gaps)

let rec oracle x e =
  let full = [ (Rational.zero, true, x, true) ] in
  match e with
  | Point p -> if Rational.compare p x <= 0 then [ (p, true, p, true) ] else []
  | Interval (a, ac, b, bc) ->
      let b, bc =
        match b with Some b -> (b, bc) | None -> (Rational.add x (qi 1), false)
      in
      inter [ (a, ac, b, bc) ] full
  | Union (e, f) -> norm (oracle x e @ oracle x f)
  | Inter (e, f) -> inter (oracle x e) (oracle x f)
  | Compl e -> complement x (oracle x e)
  | Sum (e, f) -> inter (sum (oracle x e) (oracle x f)) full
  | Star e -> (
      let a =
        inter (oracle x e)
          [ (Rational.zero, false, Rational.add x (qi 1), false) ]
      in
      let zero = [ (Rational.zero, true, Rational.zero, true) ] in
      match a with
      | [] -> zero
      | (lo, _, _, _) :: _ when Rational.sign lo = 0 -> full
      | _ ->
          let rec fix r =
            let r' = inter (norm (r @ sum r a)) full in
            if r' = r then r else fix r'
          in
          fix zero)

let window x s =
  List.map
    (fun (i : DelaySet.interval) -> (i.lo, i.lo_closed, i.hi, i.hi_closed))
    (DelaySet.intervals_upto x s)

let show_ivs ivs =
  String.concat " ∪ "
    (List.map
       (fun (a, ac, b, bc) ->
         (if ac then "[" else "(")
         ^ Rational.show a ^ ", " ^ Rational.show b
         ^ if bc then "]" else ")")
       ivs)

(* {1 Random expressions} *)

let random_rational st =
  q (Random.State.int st 13) (List.nth [ 1; 2; 3; 4 ] (Random.State.int st 4))

let rec random st depth =
  let int = Random.State.int st in
  if depth = 0 || Random.State.float st 1. < 0.3 then
    if Random.State.float st 1. < 0.4 then Point (random_rational st)
    else
      let a = random_rational st in
      let b =
        if Random.State.float st 1. < 0.15 then None
        else Some (Rational.add a (q (int 7) (List.nth [ 1; 2; 3; 5 ] (int 4))))
      in
      let ac = Random.State.bool st and bc = Random.State.bool st in
      match b with
      | Some b when Rational.equal a b -> Interval (a, true, Some b, true)
      | _ -> Interval (a, ac, b, bc)
  else
    match int 7 with
    | 0 -> Union (random st (depth - 1), random st (depth - 1))
    | 1 -> Inter (random st (depth - 1), random st (depth - 1))
    | 2 -> Compl (random st (depth - 1))
    | 3 | 4 -> Sum (random st (depth - 1), random st (depth - 1))
    | _ -> Star (random st (depth - 1))

let expressions =
  let st = Random.State.make [| 7 |] in
  List.init 1500 (fun _ -> random st 3)

let sets = List.map (fun e -> (e, build e)) expressions

(* {1 Checks} *)

let windows =
  let st = Random.State.make [| 13 |] in
  every "oracle: windows agree"
    (fun ((e, s), x) ->
      show_expr e ^ " up to " ^ Rational.show x ^ ": "
      ^ show_ivs (window x s)
      ^ " against "
      ^ show_ivs (oracle x e))
    (fun ((e, s), x) -> window x s = oracle x e)
    (List.map
       (fun es ->
         (es, qi (List.nth [ 20; 37; 60; 131 ] (Random.State.int st 4))))
       sets)

(* Membership at the ends of the intervals of the window, a little off them
   and between them, against the window. *)
let membership =
  let probes ivs =
    List.concat_map
      (fun (a, _, b, _) ->
        let eps = q 1 997 in
        [
          a;
          b;
          Rational.add a eps;
          Rational.sub b eps;
          Rational.div (Rational.add a b) (qi 2);
          Rational.add b eps;
        ])
      ivs
  in
  let x = qi 60 in
  every "mem agrees with the window"
    (fun (e, _) -> show_expr e)
    (fun (_, s) ->
      let w = window x s in
      List.for_all
        (fun p ->
          Rational.sign p < 0
          || Rational.compare p x > 0
          || DelaySet.mem p s
             = List.exists
                 (fun (a, ac, b, bc) ->
                   (Rational.compare a p < 0 || (ac && Rational.equal a p))
                   && (Rational.compare p b < 0 || (bc && Rational.equal p b)))
                 w)
        (probes w))
    sets

let firsts n xs = List.filteri (fun i _ -> i < n) xs
let samples = List.map snd (firsts 60 sets)
let pairs xs = List.concat_map (fun x -> List.map (fun y -> (x, y)) xs) xs

let triples xs =
  List.concat_map (fun (x, y) -> List.map (fun z -> (x, y, z)) xs) (pairs xs)

let show1 = DelaySet.show
let show2 (s, r) = show1 s ^ ", " ^ show1 r
let show3 (s, r, u) = show2 (s, r) ^ ", " ^ show1 u
let ( === ) = DelaySet.equal
let some = firsts 18 samples

let laws =
  let open DelaySet in
  [
    every "union commutative" show2
      (fun (s, r) -> union s r === union r s)
      (pairs samples);
    every "inter commutative" show2
      (fun (s, r) -> inter s r === inter r s)
      (pairs samples);
    every "union associative" show3
      (fun (s, r, u) -> union s (union r u) === union (union s r) u)
      (triples some);
    every "inter distributes over union" show3
      (fun (s, r, u) -> inter s (union r u) === union (inter s r) (inter s u))
      (triples some);
    every "De Morgan" show2
      (fun (s, r) -> compl (union s r) === inter (compl s) (compl r))
      (pairs samples);
    every "complement involutive" show1 (fun s -> compl (compl s) === s) samples;
    every "complement a complement" show1
      (fun s -> is_empty (inter s (compl s)) && union s (compl s) === all)
      samples;
    every "subset is union absorption" show2
      (fun (s, r) -> subset s r = (union s r === r))
      (pairs samples);
    every "sum commutative" show2
      (fun (s, r) -> sum s r === sum r s)
      (pairs samples);
    every "sum associative" show3
      (fun (s, r, u) -> sum s (sum r u) === sum (sum s r) u)
      (triples some);
    every "sum unit {0} and zero ∅" show1
      (fun s -> sum zero s === s && is_empty (sum empty s))
      samples;
    every "sum distributes over union" show3
      (fun (s, r, u) -> sum s (union r u) === union (sum s r) (sum s u))
      (triples some);
    every "star unfolds" show1
      (fun s -> star s === union zero (sum s (star s)))
      samples;
    every "star idempotent" show1 (fun s -> star (star s) === star s) samples;
    every "star of a union" show2
      (fun (s, r) -> star (union s r) === sum (star s) (star r))
      (pairs some);
    every "star monotone" show2
      (fun (s, r) -> (not (subset s r)) || subset (star s) (star r))
      (pairs samples);
    every "compare compatible with equal and hash" show2
      (fun (s, r) ->
        compare s r = 0 = equal s r && ((not (equal s r)) || hash s = hash r))
      (pairs samples);
  ]

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let span ?(lo_closed = true) ?(hi_closed = true) lo hi =
  DelaySet.interval ~lo ~lo_closed ~hi ~hi_closed

let open_interval lo hi = span ~lo_closed:false ~hi_closed:false lo (Some hi)
let printed name s expected = expect name Fun.id ~expected (DelaySet.show s)

let cases =
  let open DelaySet in
  [
    printed "{q}* = qℕ" (star (point (q 1 2))) "(0.5)*";
    printed "2ℕ" (star (point (qi 2))) "2*";
    printed "(0, e)* = [0, ∞)" (star (open_interval (qi 0) (q 1 3))) "[0, ∞)";
    printed "(1, 1.1)*"
      (star (open_interval (qi 1) (q 11 10)))
      "0 | (1, 1.1) | (2, 2.2) | (3, 3.3) | (4, 4.4) | (5, 5.5) | (6, 6.6) | \
       (7, 7.7) | (8, 8.8) | (9, 9.9) | (10, 11) | (11, ∞)";
    printed "{7/3, 5/2}* eventually (1/6)ℕ"
      (inter
         (star (union (point (q 7 3)) (point (q 5 2))))
         (span ~lo_closed:false (qi 30) None))
      "91/3; (1/6)*";
    printed "[1, 2]*" (star (span (qi 1) (Some (qi 2)))) "0 | [1, ∞)";
    printed "{0} ∪ [5, 6) + 3ℕ"
      (union zero
         (sum
            (span ~hi_closed:false (qi 5) (Some (qi 6)))
            (star (point (qi 3)))))
      "0 | [5, 6); 3*";
    printed "complement of {1}" (compl (point (qi 1))) "[0, 1) | (1, ∞)";
    printed "positive" positive "(0, ∞)";
    printed "all" all "[0, ∞)";
    printed "empty" empty "~_*";
    printed "zero" zero "0";
    printed "[0, 1)" (span ~hi_closed:false (qi 0) (Some (qi 1))) "[0, 1)";
    expect "sup of (1, 2)"
      (function
        | Some (DelaySet.Finite (x, a)) -> Rational.show x ^ string_of_bool a
        | Some Infinite -> "∞"
        | None -> "none")
      ~expected:(Some (Finite (qi 2, false)))
      (sup (open_interval (qi 1) (qi 2)));
    expect "inf of (1, 2]"
      (function
        | Some (DelaySet.Finite (x, a)) -> Rational.show x ^ string_of_bool a
        | Some Infinite -> "∞"
        | None -> "none")
      ~expected:(Some (Finite (qi 1, false)))
      (inf (span ~lo_closed:false (qi 1) (Some (qi 2))));
    expect "sup of 2ℕ is ∞"
      (function Some Infinite -> "∞" | _ -> "finite")
      ~expected:(Some Infinite)
      (sup (star (point (qi 2))));
    expect "simplest of (0.3, 0.4)"
      (Option.fold ~none:"none" ~some:Rational.show)
      ~expected:(Some (q 1 3))
      (choose (open_interval (q 3 10) (q 4 10)));
    expect "simplest of (1/2, 3)"
      (Option.fold ~none:"none" ~some:Rational.show)
      ~expected:(Some (qi 1))
      (choose (open_interval (q 1 2) (qi 3)));
    expect "simplest of (2, ∞)"
      (Option.fold ~none:"none" ~some:Rational.show)
      ~expected:(Some (qi 3))
      (choose (span ~lo_closed:false (qi 2) None));
    expect "simplest of (0, 1)"
      (Option.fold ~none:"none" ~some:Rational.show)
      ~expected:(Some (q 1 2))
      (choose (open_interval (qi 0) (qi 1)));
    expect "minterms of [0, 2] and (1, 3)" Fun.id
      ~expected:"(1, 2]; (2, 3]; (3, ∞); [0, 1]"
      (String.concat "; "
         (List.sort String.compare
            (List.map show
               (minterms
                  [
                    span (qi 0) (Some (qi 2));
                    span ~lo_closed:false (qi 1) (Some (qi 3));
                  ]))));
  ]

(* The repetition of a set with large constants, and one of many points. *)
let timing =
  let quickly name f =
    let start = Sys.time () in
    let holds = f () in
    let time = Sys.time () -. start in
    check name (holds && time < 2.) (Printf.sprintf "in %.2f s" time)
  in
  let open DelaySet in
  [
    quickly "({1} ∪ (10, 10.01))* is eventually full from 10010" (fun () ->
        let s =
          star (union (point (qi 1)) (open_interval (qi 10) (q 1001 100)))
        in
        mem (q 100105 10) s
        && (not (mem (q 105 10) s))
        && subset (span ~lo_closed:false (qi 10010) None) s);
    quickly "{7, 11}* has the Frobenius number 59" (fun () ->
        let s = star (union (point (qi 7)) (point (qi 11))) in
        (not (mem (qi 59) s))
        && List.for_all (fun n -> mem (qi n) s) (List.init 20 (fun n -> n + 60))
        && not (mem (q 121 2) s));
  ]

let () =
  let checks = [ windows; membership ] @ laws @ cases @ timing in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
