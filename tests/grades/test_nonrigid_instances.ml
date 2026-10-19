(* The non-rigid grades of timed operations as instances of the grades with
   interval letters, on random literals with a fixed seed. A literal of a
   non-rigid grade is translated into one of the rigid grade of the same
   family, side and delays:

   - upper bounds: an operation [A] is the skippable [A?], a delay or a set of
     delays [D] the budget [≤ sup D];
   - lower bounds: an operation [A] is [≥0; A], a delay or a set of delays [D]
     the budget [≥ inf D], and the expression is followed by [≥0];
   - intervals: the lower translation of the lower end and the upper
     translation of the upper end.

   The translation is structural on [;], [|], [*] and [^c], and the literals
   have no wildcard, which also ranges over delays, and no intersection or
   complement, which the rigid grades do not take on whole expressions. Checked: the two grades decide [≤] alike on
   every pair; the translation of the concatenation and of the union of two
   literals is the product and the join of their translations, and the
   concatenation and the union are the product and the join of the non-rigid
   grade, so that the translation preserves products and joins of grades;
   under the upper translation the unit is preserved, under the lower one it is
   mapped to the top, which is not the unit. *)

module Grade = Grades.Grade
module Rat = Grades.Rational
open LawChecks

let q n d = Rat.make n d
let int n = Rat.of_int n

(* {1 Running times} *)

let operations = [ "A"; "B"; "C" ]

(* Positive running times, over whole steps and over the rationals, with an
   open end in the latter. *)
let bounds ~whole =
  let running_time = function
    | "A" -> (Grade.Closed (int 1), Grade.Closed (int 1))
    | "B" ->
        if whole then (Grade.Closed (int 1), Grade.Closed (int 2))
        else (Grade.Open (int 0), Grade.Closed (q 3 2))
    | "C" ->
        if whole then (Grade.Closed (int 2), Grade.Closed (int 3))
        else (Grade.Closed (q 1 2), Grade.Open (int 2))
    | n -> invalid_arg n
  in
  { Grade.running_time; operations }

(* {1 Literals} *)

(* [delays ~whole ~finite ()] is a random delay or, unless [finite], a random
   interval of delays, in halves over the rationals. *)
let delays ~whole ~finite () =
  let value () = if whole then int (Random.int 4) else q (Random.int 7) 2 in
  let end_ v =
    if (not whole) && Random.bool () then Grade.Open v else Grade.Closed v
  in
  match Random.int (if finite then 1 else 3) with
  | 0 -> Grade.rational_tick (value ())
  | 1 ->
      let a = value () and b = value () in
      let a, b = if Rat.compare a b <= 0 then (a, b) else (b, a) in
      if Rat.equal a b then Grade.Delays (Grade.Closed a, Grade.Closed b)
      else Grade.Delays (end_ a, end_ b)
  | _ -> Grade.Delays (end_ (value ()), Grade.Unbounded)

let letter ~whole ~finite () =
  match Random.int 5 with
  | 0 | 1 -> Grade.Letter (List.nth operations (Random.int 3))
  | _ -> delays ~whole ~finite ()

(* [expr ~whole ~finite ()] is a random expression of depth at most 3, with a
   star unless [finite]. *)
let expr ~whole ~finite () =
  let rec go depth =
    if depth = 0 then letter ~whole ~finite ()
    else
      match Random.int (if finite then 5 else 6) with
      | 0 | 1 ->
          let n = 2 + Random.int 2 in
          List.fold_left
            (fun acc r -> Grade.Seq (acc, r))
            (go (depth - 1))
            (List.init (n - 1) (fun _ -> go (depth - 1)))
      | 2 -> Grade.Union (go (depth - 1), go (depth - 1))
      | 3 ->
          Grade.Repeat
            (go (depth - 1), Grades.Count.make (Random.int 2) (Some 2))
      | 5 -> Grade.Star (go (depth - 1))
      | _ -> letter ~whole ~finite ()
  in
  go (1 + Random.int (if finite then 2 else 3))

(* [perturb ~whole ~finite r] is [r] with some of its letters changed: an
   operation left out or followed by a delay, a delay changed. *)
let rec perturb ~whole ~finite r =
  match r with
  | Grade.Letter _ -> (
      match Random.int 6 with
      | 0 -> Grade.Tick 0
      | 1 -> Grade.Seq (r, delays ~whole ~finite ())
      | 2 -> letter ~whole ~finite ()
      | _ -> r)
  | Grade.Tick _ | Grade.Frac _ | Grade.Delays _ ->
      if Random.int 3 = 0 then delays ~whole ~finite () else r
  | Grade.Seq (a, b) ->
      Grade.Seq (perturb ~whole ~finite a, perturb ~whole ~finite b)
  | Grade.Union (a, b) ->
      Grade.Union (perturb ~whole ~finite a, perturb ~whole ~finite b)
  | Grade.Repeat (a, c) -> Grade.Repeat (perturb ~whole ~finite a, c)
  | Grade.Star a -> Grade.Star (perturb ~whole ~finite a)
  | r -> r

(* [related ~whole ~finite x] is a random expression, often built from [x]. *)
let related ~whole ~finite x =
  match Random.int 6 with
  | 0 -> Grade.Seq (x, expr ~whole ~finite ())
  | 1 -> Grade.Union (x, expr ~whole ~finite ())
  | 2 | 3 -> perturb ~whole ~finite x
  | _ -> expr ~whole ~finite ()

(* {1 Translations} *)

let infimum = function
  | Grade.Tick n -> Grade.Closed (int n)
  | Grade.Frac v -> Grade.Closed v
  | Grade.Delays (lo, _) -> lo
  | _ -> invalid_arg "infimum"

let supremum = function
  | Grade.Tick n -> Grade.Closed (int n)
  | Grade.Frac v -> Grade.Closed v
  | Grade.Delays (_, hi) -> hi
  | _ -> invalid_arg "supremum"

let rec structural letter = function
  | Grade.Seq (a, b) -> Grade.Seq (structural letter a, structural letter b)
  | Grade.Union (a, b) -> Grade.Union (structural letter a, structural letter b)
  | Grade.Star a -> Grade.Star (structural letter a)
  | Grade.Repeat (a, c) -> Grade.Repeat (structural letter a, c)
  | r -> letter r

(* The upper translation: [A ↦ A?], [D ↦ ≤ sup D]. *)
let upper =
  structural (function
    | Grade.Letter _ as a -> Grade.Union (a, Grade.Tick 0)
    | d -> Grade.Below (supremum d))

let flank = Grade.Above (Grade.Closed Rat.zero)

(* The lower translation: [A ↦ ≥0; A], [D ↦ ≥ inf D], then [≥0]. *)
let lower r =
  Grade.Seq
    ( structural
        (function
          | Grade.Letter _ as a -> Grade.Seq (flank, a)
          | d -> Grade.Above (infimum d))
        r,
      flank )

(* {1 Families} *)

type side = Upper | Lower | Interval

type family = {
  label : string;
  whole : bool;
  finite : bool;
  side : side;
  nonrigid : (module Grade.S);
  rigid : (module Grade.S);
}

(* A literal of a side: one expression, or the two ends of an interval. *)
type literal = One of Grade.regex | Ends of Grade.regex * Grade.regex

let lit_of = function
  | One r -> Grade.Braces r
  | Ends (l, u) ->
      Grade.Interval
        (Grade.Closed (Grade.Braces l), Grade.Closed (Grade.Braces u))

let translate side = function
  | One r -> One (if side = Upper then upper r else lower r)
  | Ends (l, u) -> Ends (lower l, upper u)

let show_literal = function
  | One r -> "{" ^ Grade.show_regex r ^ "}"
  | Ends (l, u) ->
      "[{" ^ Grade.show_regex l ^ "}, {" ^ Grade.show_regex u ^ "}]"

let random_literal f =
  match f.side with
  | Interval ->
      Ends
        ( expr ~whole:f.whole ~finite:f.finite (),
          expr ~whole:f.whole ~finite:f.finite () )
  | _ -> One (expr ~whole:f.whole ~finite:f.finite ())

let related_literal f = function
  | One r -> One (related ~whole:f.whole ~finite:f.finite r)
  | Ends (l, u) ->
      Ends
        ( related ~whole:f.whole ~finite:f.finite l,
          related ~whole:f.whole ~finite:f.finite u )

let combine op x y =
  match (x, y) with
  | One a, One b -> One (op a b)
  | Ends (l, u), Ends (l', u') -> Ends (op l l', op u u')
  | _ -> invalid_arg "combine"

let unit_literal = function
  | Interval -> Ends (Grade.Tick 0, Grade.Tick 0)
  | _ -> One (Grade.Tick 0)

(* [run f n] checks the family [f] on [n] random pairs. *)
let run f n =
  let (module N : Grade.S) = f.nonrigid and (module R : Grade.S) = f.rigid in
  let bounds = bounds ~whole:f.whole in
  let nr l = N.of_lit (lit_of l)
  and rg l = R.of_lit (lit_of (translate f.side l)) in
  let disagreements = ref [] and products = ref [] and joins = ref [] in
  let accepted = ref 0 in
  for _ = 1 to n do
    let x = random_literal f in
    let y = related_literal f x in
    let nx = nr x and ny = nr y and rx = rg x and ry = rg y in
    let verdict = N.leq bounds nx ny in
    if verdict then incr accepted;
    if verdict <> R.leq bounds rx ry then
      disagreements := (x, y, verdict) :: !disagreements;
    let seq = combine (fun a b -> Grade.Seq (a, b)) x y
    and union = combine (fun a b -> Grade.Union (a, b)) x y in
    if
      not
        (N.equal bounds (nr seq) (N.mul nx ny)
        && R.equal bounds (rg seq) (R.mul rx ry))
    then products := (x, y) :: !products;
    if
      not
        (N.equal bounds (nr union) (N.join nx ny)
        && R.equal bounds (rg union) (R.join rx ry))
    then joins := (x, y) :: !joins
  done;
  let name law = Printf.sprintf "%s (%s)" f.label law in
  let pair (x, y) = show_literal x ^ ", " ^ show_literal y in
  let report law = function
    | [] -> check (name law) true ""
    | x :: _ as failures ->
        check (name law) false
          (Printf.sprintf "%d failures, e.g. %s" (List.length failures) (pair x))
  in
  let one = unit_literal f.side in
  let unit_check =
    let nr_unit = N.equal bounds (nr one) N.one and r_one = rg one in
    match f.side with
    | Upper ->
        check (name "unit preserved")
          (nr_unit && R.equal bounds r_one R.one)
          (R.show r_one)
    | Lower ->
        check (name "unit to the top")
          (nr_unit && R.equal bounds r_one R.top
          && not (R.equal bounds R.one R.top))
          (R.show r_one)
    | Interval ->
        check
          (name "unit to the top and the unit")
          (nr_unit
          && R.equal bounds r_one
               (R.of_lit (lit_of (Ends (flank, Grade.Tick 0))))
          && R.leq bounds R.one r_one
          && not (R.equal bounds R.one r_one))
          (R.show r_one)
  in
  [
    (match !disagreements with
    | [] ->
        check
          (name (Printf.sprintf "order, %d of %d below" !accepted n))
          true ""
    | (x, y, verdict) :: _ as failures ->
        check (name "order") false
          (Printf.sprintf "%d disagreements, e.g. %s: non-rigid %b"
             (List.length failures)
             (pair (x, y))
             verdict));
    report "products" !products;
    report "joins" !joins;
    unit_check;
  ]

module RS = Grades.RegularTimedTraceGrades.Symbolic
module RQ = Grades.RegularTimedTraceGradesRational
module T = Grades.TimedTraceGrades
module I = Grades.IntervalGrades

let family name ~whole ~finite side nonrigid rigid =
  { label = name; whole; finite; side; nonrigid; rigid }

let families =
  [
    family "regex upper" ~whole:true ~finite:false Upper
      (module RS.Upper)
      (module I.Regex.Upper);
    family "regex lower" ~whole:true ~finite:false Lower
      (module RS.Lower)
      (module I.Regex.Lower);
    family "regex interval" ~whole:true ~finite:false Interval
      (module RS.Interval)
      (module I.Regex.Interval);
    family "regex rational upper" ~whole:false ~finite:false Upper
      (module RQ.Upper)
      (module I.RegexRational.Upper);
    family "regex rational lower" ~whole:false ~finite:false Lower
      (module RQ.Lower)
      (module I.RegexRational.Lower);
    family "regex rational interval" ~whole:false ~finite:false Interval
      (module RQ.Interval)
      (module I.RegexRational.Interval);
    family "traces upper" ~whole:true ~finite:true Upper
      (module T.UpperBound)
      (module I.Traces.Upper);
    family "traces lower" ~whole:true ~finite:true Lower
      (module T.LowerBound)
      (module I.Traces.Lower);
    family "traces interval" ~whole:true ~finite:true Interval
      (module T.Interval)
      (module I.Traces.Interval);
    family "traces rational upper" ~whole:false ~finite:true Upper
      (module T.Rational.UpperBound)
      (module I.TracesRational.Upper);
    family "traces rational lower" ~whole:false ~finite:true Lower
      (module T.Rational.LowerBound)
      (module I.TracesRational.Lower);
    family "traces rational interval" ~whole:false ~finite:true Interval
      (module T.Rational.Interval)
      (module I.TracesRational.Interval);
  ]

let () =
  Random.init 2026;
  let checks = List.concat_map (fun f -> run f 1000) families in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
