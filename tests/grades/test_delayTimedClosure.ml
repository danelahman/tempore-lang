(* Unit tests of the closures of timed regular languages under allowance and
   coverage over rational delays and running times, and of the regular trace
   grades of timed operations over rational delays: worked examples of the
   orders, including traces of open delays whose sums approach a bound; the
   readers of the closures and the inclusion decisions with their
   counterexamples against the recursions of the timed traces over rational
   delays, on bounds with finitely many paths; the implied running-time bounds,
   the closed world and the literals; and the agreement with the regular trace
   grades of timed operations over whole time steps on integer instances, scaled
   to a resolution of fractions of a time step as the grades over whole steps of
   a program resolution read them; the decisions on graphs given by their rows
   against those on automata; and the grades decided on the graphs of the gap
   derivatives against those decided on automata. *)

module Grade = Grades.Grade
module Rational = Grades.Rational
module DelaySet = Grades.DelaySet
module A = Grades.DelayAutomaton
module C = Grades.DelayTimedClosure
module Plain = Grades.RegularTraceGradeRational.Automata
module G = Grades.RegularTimedTraceGradesRational.Automata
module W = Grades.RegularTimedTraceGrades.Symbolic
module Trace = Grades.TimedTrace.Make (Grades.Delay.Rational)

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }
let is name b = check name b ""

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let every name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true (Printf.sprintf "%d cases" (List.length xs))
  | Some x -> check name false ("fails on " ^ show x)

let q = Rational.make
let qi = Rational.of_int
let show_regex r = "{" ^ Grade.show_regex r ^ "}"

(* {1 Literals} *)

module GS = Grades.GradeSystem.Identity (Plain)
module Grammar = Parser.Grammar.Make (GS)

(* [lit text] is the grade the parser reads [text] as, in the grade position of
   a box. *)
let lit text =
  let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
  match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
  | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
      rho
  | _ -> failwith ("not a box of a literal: " ^ text)

let automaton text = Plain.automaton (lit text)

(* The running times of operations with fractional running-time bounds, given
   by their ends. *)
let bounds_of table =
  {
    Grade.running_time = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

(* [closed (lo, hi)] is the closed running-time bounds [[lo, hi]]. *)
let closed (lo, hi) = (Grade.Closed lo, Grade.Closed hi)

(* [exact world] is the world of the running times [world], each attained. *)
let exact world =
  List.map (fun (name, c) -> (name, DelaySet.Finite (c, true))) world

(* [strict world] is the world of the running times [world], none attained. *)
let strict world =
  List.map (fun (name, c) -> (name, DelaySet.Finite (c, false))) world

let bounds =
  bounds_of
    (List.map
       (fun (name, b) -> (name, closed b))
       [
         ("A", (q 1 2, qi 1));
         ("B", (qi 0, q 1 2));
         ("S", (q 1 2, q 3 2));
         ("T", (q 1 4, qi 1));
       ])

let upper a b = G.Upper.leq bounds (lit a) (lit b)
let lower a b = G.Lower.leq bounds (lit a) (lit b)
let show_counterexample show = function Some e -> show e | None -> "none"

(* {1 Worked examples} *)

let examples =
  [
    is "upper: a shorter delay between matched operations"
      (upper "{A; 1/2; B}" "{A; 1; B}");
    is "upper: not a longer one" (not (upper "{A; 1; B}" "{A; 1/2; B}"));
    is "upper: a delay pays for an operation at its upper bound"
      (upper "{S}" "{3/2}");
    is "upper: not below it" (not (upper "{S}" "{1.4}"));
    is "upper: a match resets the budget" (not (upper "{S; T}" "{T; 2}"));
    is "upper: the unit is least" (upper "{0}" "{A; B}");
    is "upper: delays of the bound buy any operation"
      (G.Upper.is_top bounds (lit "{(_ & ~A)*}"));
    is "upper: a complement of a delay is the top"
      (G.Upper.is_top bounds (lit "{~1}"));
    is "upper: a bound without delays buys none"
      (not (G.Upper.is_top bounds (lit "{(A | B | S)*}")));
    is "upper: open delays approach their sum"
      (not (upper "{[0, 1); [0, 1)}" "{1.99}"));
    is "upper: open delays stay below it" (upper "{[0, 1); A; [0, 1)}" "{3}");
    is "upper: open delays pay for no more"
      (not (upper "{[0, 1); A; [0, 1)}" "{2.9}"));
    is "upper: a closed delay at the bound" (upper "{[0, 1]; A; [0, 1]}" "{3}");
    is "upper: an unbounded delay" (not (upper "{(1, ∞); A}" "{A; 100}"));
    is "upper: interval atoms as bounds" (upper "{A; 1/2}" "{A; [0, 1/2]}");
    is "upper: an open bound admits no delay at it"
      (not (upper "{A; 1/2}" "{A; [0, 1/2)}"));
    is "upper: an open bound admits every delay below it"
      (upper "{A; [0, 1/2)}" "{A; [0, 1/2) | B}");
    is "upper: a complement of a delay admits every delay but it"
      (upper "{A; 1/3}" "{A; ~(1/2)}");
    is "upper: a complement admits delays nearby"
      (upper "{A; 1/2}" "{A; (1/2, 1)}");
    is "lower: a longer delay covers a shorter one" (lower "{A; 1}" "{A; 1/2}");
    is "lower: not conversely" (not (lower "{A; 1/2}" "{A; 1}"));
    is "lower: an operation banks its lower bound" (lower "{S}" "{1/2}");
    is "lower: not more" (not (lower "{S}" "{3/4}"));
    is "lower: a demanded operation is performed" (not (lower "{1}" "{S}"));
    is "lower: open delays above a bound cover it" (lower "{(1/2, ∞)}" "{1/2}");
    is "lower: open delays near 0 cover none" (not (lower "{(0, 1)}" "{1/2}"));
    is "lower: the unit is the top" (G.Lower.is_top bounds (lit "{0}"));
    is "lower: all traces are the top" (G.Lower.is_top bounds (lit "⊤"));
    is "lower: A; _* is not the top"
      (not (G.Lower.is_top bounds (lit "{A; _*}")));
    expect "upper: counterexample of open delays" Fun.id
      ~expected:"{2/3; A; 2/3}"
      (show_counterexample G.Upper.show
         (G.Upper.counterexample bounds (lit "{[0, 1); A; [0, 1)}") (lit "{2}")));
    expect "upper: counterexample of an unbounded delay" Fun.id
      ~expected:"{A; 10}"
      (show_counterexample G.Upper.show
         (G.Upper.counterexample bounds (lit "{A; [1/2, ∞)}") (lit "{A; 5 | 9}")));
    expect "lower: counterexample of an open delay" Fun.id ~expected:"{0.5}"
      (show_counterexample G.Lower.show
         (G.Lower.counterexample bounds (lit "{(0, 1)}") (lit "{3/4}")));
    expect "lower: counterexample of a missed operation" Fun.id ~expected:"{B}"
      (show_counterexample G.Lower.show
         (G.Lower.counterexample bounds (lit "{B | S}") (lit "{S | 1/2}")));
  ]

(* The traces [(0, 1); A; (0, 1); ⋯] of [k] open delays and [k - 1] operations
   of running time [1] weigh less than [2k - 1], and approach it: they are below
   [{2k - 1}] and not below [{2k - 2}], also with delays [(0, 1]]. *)
let open_delays =
  let world = exact [ ("A", qi 1) ] in
  let traces k gap =
    automaton ("{" ^ String.concat "; A; " (List.init k (Fun.const gap)) ^ "}")
  in
  let delay n = A.delays (DelaySet.point (qi n)) in
  List.concat_map
    (fun k ->
      let within gap n =
        Option.is_none (C.allowance world (traces k gap) (delay n))
      in
      [
        is
          (Printf.sprintf "open delays: %d below %d" k ((2 * k) - 1))
          (within "(0, 1)" ((2 * k) - 1));
        is
          (Printf.sprintf "open delays: %d not below %d" k ((2 * k) - 2))
          (k = 1 || not (within "(0, 1)" ((2 * k) - 2)));
        is
          (Printf.sprintf "half-open delays: %d below %d" k ((2 * k) - 1))
          (within "(0, 1]" ((2 * k) - 1));
        is
          (Printf.sprintf "half-open delays: %d not below %d" k ((2 * k) - 2))
          (k = 1 || not (within "(0, 1]" ((2 * k) - 2)));
      ])
    [ 1; 2; 3; 4; 5; 6; 7; 8 ]

(* {1 Implied running-time bounds and the closed world} *)

let show_bounds = function
  | Some (lo, hi) -> Grade.show_interval Rational.show lo hi
  | None -> "none"

let implied =
  let implied text = show_bounds (G.Upper.implied_bounds bounds (lit text)) in
  [
    expect "implied: a compound operation" Fun.id ~expected:"[1, 2.75]"
      (implied "{S; 1/4; T}");
    expect "implied: an open delay" Fun.id ~expected:"(0.75, 3)"
      (implied "{S; (0, 1/2); T}");
    expect "implied: a choice" Fun.id ~expected:"[0.25, 1.5]"
      (implied "{S | T}");
    expect "implied: unbounded" Fun.id ~expected:"none" (implied "{S*}");
    expect "implied: unbounded delays" Fun.id ~expected:"none"
      (implied "{S; (1, ∞)}");
    expect "implied: a catch-all" Fun.id ~expected:"[0, 1.5]"
      (implied "{_ & ~(0, ∞)}");
    expect "implied: an interval" Fun.id ~expected:"[0.5, 1]"
      (show_bounds
         (G.Interval.implied_bounds bounds
            (G.Interval.of_lit
               (Grade.Interval
                  ( Grade.Closed (Grade.Braces (Grade.Letter "S")),
                    Grade.Closed (Grade.Braces (Grade.Letter "T")) )))));
  ]

(* {1 Running-time bounds with open ends} *)

let open_running_times =
  let bounds_for x = bounds_of [ ("X", x) ] in
  let half_open = bounds_for (Grade.Closed (qi 1), Grade.Open (qi 2))
  and closed_x = bounds_for (closed (qi 1, qi 2))
  and open_below = bounds_for (Grade.Open (qi 1), Grade.Closed (qi 2)) in
  let shows (type a) (module M : Grade.S with type t = a) name b expected =
    expect
      ("open running times: " ^ name)
      Fun.id ~expected
      (M.show (M.of_bounds b))
  in
  [
    is "open running times: within [1, 2) is below {[0, 2)}"
      (G.Upper.leq half_open (lit "{X}") (lit "{[0, 2)}"));
    is "open running times: within [1, 2] is not below {[0, 2)}"
      (not (G.Upper.leq closed_x (lit "{X}") (lit "{[0, 2)}")));
    is "open running times: within [1, 2) is below {2}"
      (G.Upper.leq half_open (lit "{X}") (lit "{2}"));
    is "open running times: within [1, 2) is not below {1.99}"
      (not (G.Upper.leq half_open (lit "{X}") (lit "{1.99}")));
    is
      "open running times: a strict running time and a delay below a strict sum"
      (G.Upper.leq half_open (lit "{X; 1/2}") (lit "{[0, 5/2)}"));
    is "open running times: within (1, 2] covers {(1, ∞)}"
      (G.Lower.leq open_below (lit "{X}") (lit "{(1, ∞)}"));
    is "open running times: within [1, 2] does not cover {(1, ∞)}"
      (not (G.Lower.leq closed_x (lit "{X}") (lit "{(1, ∞)}")));
    is "open running times: within (1, 2] covers {1}"
      (G.Lower.leq open_below (lit "{X}") (lit "{1}"));
    is "open running times: the allowance closure reads a strict running time"
      (Option.is_none
         (C.allowance
            [ ("X", DelaySet.Finite (qi 2, false)) ]
            (automaton "{X}") (automaton "{[0, 2)}")));
    is "open running times: and an attained one"
      (Option.is_some
         (C.allowance
            (exact [ ("X", qi 2) ])
            (automaton "{X}") (automaton "{[0, 2)}")));
    expect "open running times: counterexample of a strict running time" Fun.id
      ~expected:"{X; 0.5}"
      (show_counterexample G.Upper.show
         (G.Upper.counterexample half_open (lit "{X; 1/2}") (lit "{2}")));
    expect "open running times: implied bounds" Fun.id ~expected:"[2, 3)"
      (show_bounds (G.Upper.implied_bounds half_open (lit "{X; 1}")));
    expect "open running times: implied bounds of a choice" Fun.id
      ~expected:"[1, 2]"
      (show_bounds (G.Upper.implied_bounds half_open (lit "{X | 2}")));
    expect "open running times: implied bounds of an interval" Fun.id
      ~expected:"(1.5, 2.5]"
      (show_bounds
         (G.Interval.implied_bounds open_below
            (G.Interval.of_lit
               (Grade.Interval
                  ( Grade.Closed
                      (Grade.Braces
                         (Grade.Seq (Grade.Letter "X", Grade.Frac (q 1 2)))),
                    Grade.Closed (Grade.Braces (Grade.Frac (q 5 2))) )))));
    shows
      (module G.Upper)
      "upper shadow"
      (Grade.Closed (qi 1), Grade.Open (qi 2))
      "{[0, 2)}";
    shows (module G.Upper) "closed upper shadow" (closed (qi 1, qi 2)) "{2}";
    shows
      (module G.Lower)
      "lower shadow"
      (Grade.Open (qi 1), Grade.Closed (qi 2))
      "{(1, ∞)}";
    shows
      (module G.Interval)
      "interval shadow"
      (Grade.Open (qi 1), Grade.Open (qi 2))
      "[{(1, ∞)}, {[0, 2)}]";
    is
      "open running times: a default of exactly 2 is not below the upper shadow"
      (not
         (G.Upper.leq half_open (lit "{2}")
            (G.Upper.of_bounds (Grade.Closed (qi 1), Grade.Open (qi 2)))));
    is "open running times: a default of 1.9 is"
      (G.Upper.leq half_open (lit "{1.9}")
         (G.Upper.of_bounds (Grade.Closed (qi 1), Grade.Open (qi 2))));
    is
      "open running times: a default of exactly 1 does not cover the lower \
       shadow"
      (not
         (G.Lower.leq open_below (lit "{1}")
            (G.Lower.of_bounds (Grade.Open (qi 1), Grade.Closed (qi 2)))));
  ]

let closed_world =
  let only_a = bounds_of [ ("A", closed (qi 1, qi 1)) ] in
  [
    is "closed world: an operation other than A and a delay"
      (G.Upper.inhabited only_a (lit "{_ & ~A}"));
    is "closed world: no operation other than A"
      (not (G.Upper.inhabited only_a (lit "{_ & ~(0, ∞) & ~A}")));
    is "closed world: the catch-all matches A"
      (G.Upper.leq only_a (lit "{A}") (lit "{(_ & ~(0, ∞))*}"));
    is "closed world: a declared operation bought"
      (upper "{T}" "{(_ & ~(0, ∞) & ~S)*}");
    is "closed world: a declared operation not bought"
      (not (upper "{S}" "{(_ & ~(0, ∞) & ~S)*}"));
  ]

let literals =
  let reads (type a) (module M : Grade.S with type t = a) lit' expected =
    expect ("literal: " ^ expected) Fun.id ~expected (M.show (M.of_lit lit'))
  in
  let rejects (type a) (module M : Grade.S with type t = a) name lit' =
    is
      ("literal rejected: " ^ name)
      (match M.of_lit lit' with
      | _ -> false
      | exception Grade.Invalid_literal _ -> true)
  in
  let frac n d = Grade.Rat (q n d) in
  [
    reads (module G.Upper) (frac 3 2) "{1.5}";
    reads (module G.Upper) Grade.Top "⊤";
    reads (module G.Lower) Grade.Top "{0}";
    reads
      (module G.Interval)
      (Grade.Interval (Grade.Closed (frac 1 2), Grade.Closed (frac 3 2)))
      "[{0.5}, {1.5}]";
    reads (module G.Interval) (frac 1 3) "[{1/3}, {1/3}]";
    reads
      (module G.Interval)
      (Grade.Braces
         (Grade.Delays (Grade.Closed Rational.zero, Grade.Open (qi 1))))
      "[{[0, 1)}, {[0, 1)}]";
    rejects
      (module G.Interval)
      "reversed interval"
      (Grade.Interval (Grade.Closed (frac 3 2), Grade.Closed (frac 1 2)));
    reads
      (module G.Interval)
      (Grade.Tuple [ frac 1 2; frac 3 2 ])
      "[{(0.5, ∞)}, {[0, 1.5)}]";
    reads
      (module G.Interval)
      (Grade.Interval (Grade.Closed (frac 1 2), Grade.Open (frac 3 2)))
      "[{0.5}, {[0, 1.5)}]";
    reads
      (module G.Interval)
      (Grade.Interval (Grade.Open (frac 1 2), Grade.Unbounded))
      "[{(0.5, ∞)}, ∞)";
    rejects
      (module G.Interval)
      "empty open interval"
      (Grade.Tuple [ frac 1 2; frac 1 2 ]);
    rejects (module G.Upper) "negative delay" (frac (-1) 2);
    rejects
      (module G.Upper)
      "empty language"
      (Grade.Braces (Grade.Inter (Grade.Letter "A", Grade.Tick 1)));
  ]

(* {1 Against the recursions of the timed traces}

   The bounds are unions of sequences of operations and sets of delays closed
   at the top (allowance) or at the bottom (coverage), so that each sequence
   has a greatest (least) word, and a word is in the closure iff it is below
   (above) the greatest (least) word of one of them by the recursions of the
   timed traces. *)

type item = Gap of DelaySet.t | Op of string

let names = [ "A"; "B" ]
let running_times_hi = [ ("A", qi 1); ("B", q 1 2) ]
let running_times_lo = [ ("A", q 1 2); ("B", qi 0) ]

let trace_of_word word =
  Trace.normalise
    (List.map
       (function
         | A.Delay d -> Trace.Wait d
         | A.Operation c -> Trace.Ev (List.hd (A.Class.names c)))
       word)

let extreme_word pick items =
  trace_of_word
    (List.map
       (function
         | Gap s -> A.Delay (pick s)
         | Op name -> A.Operation (A.Class.name name))
       items)

let greatest s =
  match DelaySet.sup s with
  | Some (DelaySet.Finite (x, _)) -> x
  | Some DelaySet.Infinite | None -> qi 1000

let least s =
  match DelaySet.inf s with
  | Some (DelaySet.Finite (x, _)) -> x
  | Some DelaySet.Infinite | None -> qi 0

let in_down bound word =
  List.exists
    (fun items ->
      Trace.allowance
        (fun o -> List.assoc o running_times_hi)
        Rational.zero (trace_of_word word)
        (extreme_word greatest items))
    bound

let in_up bound word =
  List.exists
    (fun items ->
      Trace.coverage
        (fun o -> List.assoc o running_times_lo)
        Rational.zero (extreme_word least items) (trace_of_word word))
    bound

let automaton_of_bound bound =
  List.fold_left A.union A.empty
    (List.map
       (fun items ->
         List.fold_left
           (fun a item ->
             A.concat a
               (match item with
               | Gap s -> A.delays s
               | Op name -> A.operations (A.Class.name name)))
           A.epsilon items)
       bound)

let random_bound st ~closed_top =
  let int = Random.State.int st in
  let value () = q (int 7) (1 + int 3) in
  let gap () =
    let lo = value () in
    match int 5 with
    | 0 -> DelaySet.point lo
    | 1 ->
        DelaySet.interval ~lo
          ~lo_closed:((not closed_top) || int 2 = 0)
          ~hi:None ~hi_closed:false
    | _ ->
        DelaySet.interval ~lo
          ~lo_closed:((not closed_top) || int 2 = 0)
          ~hi:(Some (Rational.add lo (q (1 + int 4) 2)))
          ~hi_closed:(closed_top || int 2 = 0)
  in
  List.init
    (1 + int 3)
    (fun _ ->
      List.concat
        (List.init (int 4) (fun i ->
             (if i > 0 || int 2 = 0 then [ Op (List.nth names (int 2)) ] else [])
             @ List.init (int 3) (fun _ -> Gap (gap ())))))

(* [interval_atom k q] is the interval atom of the delays below, up to,
   above or from [q], for [k] = 0, 1, 2 or 3; no delay is below [0], and the
   empty language is written [~_*]. *)
let interval_atom k q =
  let zero = Grade.Closed Rational.zero in
  if k = 0 && Rational.sign q = 0 then Grade.Compl (Grade.Star Grade.Any)
  else
    let lo, hi =
      match k with
      | 0 -> (zero, Grade.Open q)
      | 1 -> (zero, Grade.Closed q)
      | 2 -> (Grade.Open q, Grade.Unbounded)
      | _ -> (Grade.Closed q, Grade.Unbounded)
    in
    Grade.Delays (lo, hi)

let rec random_regex st depth =
  let int = Random.State.int st in
  let sub () = random_regex st (depth - 1) in
  let value () = q (int 7) (1 + int 3) in
  match int (if depth = 0 then 4 else 10) with
  | 0 -> Grade.Letter (List.nth names (int 2))
  | 1 -> Grade.rational_tick (value ())
  | 2 -> interval_atom (int 4) (value ())
  | 3 -> Grade.Any
  | 4 | 5 -> Grade.Seq (sub (), sub ())
  | 6 -> Grade.Union (sub (), sub ())
  | 7 -> Grade.Inter (sub (), sub ())
  | 8 -> Grade.Compl (sub ())
  | _ -> Grade.Star (sub ())

(* [sample_delays s] is some delays of [s]: the ends of its intervals up to
   [8], points just inside them, their midpoints and a large delay. *)
let sample_delays s =
  let near = q 1 997 in
  List.sort_uniq Rational.compare
    (List.filter
       (fun x -> DelaySet.mem x s)
       (qi 50
       :: List.concat_map
            (fun (i : DelaySet.interval) ->
              [
                i.lo;
                i.hi;
                Rational.add i.lo near;
                Rational.sub i.hi near;
                Rational.div (Rational.add i.lo i.hi) (qi 2);
              ])
            (DelaySet.intervals_upto (qi 8) s)))

(* [sample_words st l] is some words of [l] of at most two operations. *)
let sample_words st l =
  let rec from_gap g ops =
    List.concat_map
      (fun (s, o) ->
        let delays = sample_delays s in
        let delays =
          List.filteri (fun i _ -> i < 3 || Random.State.int st 3 = 0) delays
        in
        List.concat_map
          (fun d ->
            (if A.final l o then [ [ A.Delay d ] ] else [])
            @
            if ops = 0 then []
            else
              List.concat_map
                (fun name ->
                  match
                    List.find_opt
                      (fun (c, _) ->
                        not
                          (A.Class.is_empty
                             (A.Class.inter c (A.Class.name name))))
                      (A.operation_transitions l o)
                  with
                  | Some (_, g') ->
                      List.map
                        (fun w ->
                          A.Delay d :: A.Operation (A.Class.name name) :: w)
                        (from_gap g' (ops - 1))
                  | None -> [])
                names)
          delays)
      (A.gap_transitions l g)
  in
  let words = from_gap 0 2 in
  List.filteri (fun i _ -> i < 40 || Random.State.int st 8 = 0) words

let show_word word =
  String.concat " "
    (List.map
       (function
         | A.Delay d -> Rational.show d
         | A.Operation c -> String.concat "," (A.Class.names c))
       word)

let show_items items =
  String.concat " "
    (List.map (function Gap s -> DelaySet.show s | Op n -> n) items)

let show_bound bound = String.concat " | " (List.map show_items bound)

(* [against_recursions ~closed_top ~decide ~reads ~member] checks the decision
   [decide] and the reader [reads] of a closure against the membership
   [member] by the recursions on random pairs. *)
let against_recursions name ~seed ~closed_top ~world ~decide ~reads ~member =
  let st = Random.State.make [| seed |] in
  let cases =
    List.filter_map
      (fun _ ->
        let r = random_regex st 3 in
        match Plain.of_lit (Grade.Braces r) with
        | exception Grade.Invalid_literal _ -> None
        | rho ->
            let bound = random_bound st ~closed_top in
            Some (r, Plain.automaton rho, bound, automaton_of_bound bound))
      (List.init 400 Fun.id)
  in
  let show (r, _, bound, _) = show_regex r ^ " against " ^ show_bound bound in
  let verdicts =
    List.map (fun ((_, l, _, m) as case) -> (case, decide world l m)) cases
  in
  let included = List.filter (fun (_, v) -> Option.is_none v) verdicts in
  [
    every
      (name ^ ": the reader agrees with the recursions")
      (fun (((_, _, bound, _) as case), word) ->
        show case ^ " on " ^ show_word word
        ^ Printf.sprintf " (recursions %b)" (member bound word))
      (fun ((_, _, bound, m), word) -> reads world m word = member bound word)
      (List.concat_map
         (fun ((_, l, _, _) as case) ->
           List.map (fun w -> (case, w)) (sample_words st l))
         (List.filteri (fun i _ -> i < 120) cases));
    every
      (name ^ ": included, every sampled word is in the closure")
      (fun (case, _) -> show case)
      (fun ((_, l, bound, _), _) ->
        List.for_all (member bound) (sample_words st l))
      included;
    every
      (name ^ ": not included, the counterexample is outside")
      (fun (case, w) -> show case ^ ": " ^ show_counterexample show_word w)
      (fun ((_, l, bound, _), w) ->
        match w with
        | None -> true
        | Some w -> A.mem w l && not (member bound w))
      verdicts;
    check
      (name ^ ": both verdicts occur")
      (List.length included > 20
      && List.length verdicts - List.length included > 20)
      (Printf.sprintf "%d included of %d" (List.length included)
         (List.length verdicts));
  ]

(* The running times not attained agree with the recursions at their values:
   against a bound closed at the top, a word is permitted at every running time
   below a supremum iff at the supremum, and against one closed at the bottom it
   covers at every running time above an infimum iff at the infimum. *)
let recursions =
  against_recursions "allowance" ~seed:5 ~closed_top:true
    ~world:(exact running_times_hi) ~decide:C.allowance ~reads:C.permits
    ~member:in_down
  @ against_recursions "coverage" ~seed:7 ~closed_top:false
      ~world:(exact running_times_lo) ~decide:C.coverage ~reads:C.covers
      ~member:in_up
  @ against_recursions "allowance, open running times" ~seed:17 ~closed_top:true
      ~world:(strict running_times_hi) ~decide:C.allowance ~reads:C.permits
      ~member:in_down
  @ against_recursions "coverage, open running times" ~seed:19 ~closed_top:false
      ~world:(strict running_times_lo) ~decide:C.coverage ~reads:C.covers
      ~member:in_up

(* {1 The grades by gap graphs against the grades by automata}

   The verdicts, implied running-time bounds and inhabitation of the grades
   decided on the graphs of the gap derivatives against those decided on the
   automata, exactly, on random pairs of grades and running-time bounds with
   closed and open ends; and their counterexamples, which are traces of the
   lesser grade outside the closure of the greater one, with no more
   operations than those of the automata. *)

module Gaps = Grades.RegularTimedTraceGradesRational
module Expr = Grades.RegularTraceGradeRational

let gap_bounds =
  [
    bounds;
    bounds_of
      [
        ("A", (Grade.Open (q 1 2), Grade.Closed (qi 1)));
        ("B", (Grade.Closed (qi 0), Grade.Open (q 1 2)));
        ("C", (Grade.Closed (q 1 3), Grade.Closed (q 1 3)));
      ];
  ]

(* Random pairs of grades over [A] and [B], each read by both
   implementations. *)
let gap_cases =
  let st = Random.State.make [| 71 |] in
  let grade () =
    let r = random_regex st 3 in
    match (Expr.of_lit (Grade.Braces r), Plain.of_lit (Grade.Braces r)) with
    | exception Grade.Invalid_literal _ -> None
    | x, a -> Some (r, x, a)
  in
  let grades = List.filter_map (fun _ -> grade ()) (List.init 50 Fun.id) in
  List.concat_map (fun x -> List.map (fun y -> (x, y)) grades) grades

let show_case ((r, _, _), (s, _, _)) = show_regex r ^ ", " ^ show_regex s

(* [operations e] is the number of operations of the expression [e] of a
   trace, a concatenation of delays and operations. *)
let operations e =
  let rec factors = function
    | Grade.Seq (r, s) -> factors r @ factors s
    | r -> [ r ]
  in
  List.length
    (List.filter
       (function Grade.Tick _ | Grade.Frac _ -> false | _ -> true)
       (factors e))

(* [valid leq c rho rho'] is whether the trace grade [c], read by the automata,
   is in [rho] and not below [rho'] under [leq]. *)
let valid leq bounds c rho rho' =
  let c = Plain.of_lit (Grade.Braces (Expr.expression c)) in
  A.subset (Plain.automaton c) (Plain.automaton rho) && not (leq bounds c rho')

let gap_agreement =
  List.concat_map
    (fun bounds ->
      [
        every "gaps: upper verdicts as by automata" show_case
          (fun ((_, x, a), (_, y, b)) ->
            Gaps.Upper.leq bounds x y = G.Upper.leq bounds a b
            && Gaps.Upper.equal bounds x y = G.Upper.equal bounds a b)
          gap_cases;
        every "gaps: lower verdicts as by automata" show_case
          (fun ((_, x, a), (_, y, b)) ->
            Gaps.Lower.leq bounds x y = G.Lower.leq bounds a b
            && Gaps.Lower.equal bounds x y = G.Lower.equal bounds a b)
          gap_cases;
        every "gaps: interval verdicts as by automata" show_case
          (fun ((_, x, a), (_, y, b)) ->
            Gaps.Interval.leq bounds (x, y) (y, x)
            = G.Interval.leq bounds (a, b) (b, a))
          gap_cases;
        every "gaps: tops, implied bounds and inhabitation as by automata"
          show_case
          (fun ((_, x, a), _) ->
            Gaps.Upper.is_top bounds x = G.Upper.is_top bounds a
            && Gaps.Lower.is_top bounds x = G.Lower.is_top bounds a
            && Gaps.Upper.implied_bounds bounds x
               = G.Upper.implied_bounds bounds a
            && Gaps.Interval.implied_bounds bounds (x, x)
               = G.Interval.implied_bounds bounds (a, a)
            && Gaps.Upper.inhabited bounds x = G.Upper.inhabited bounds a)
          (List.filteri (fun i _ -> i mod 50 = 0) gap_cases);
        every "gaps: upper counterexamples valid and no longer" show_case
          (fun ((_, x, a), (_, y, b)) ->
            match
              ( Gaps.Upper.counterexample bounds x y,
                G.Upper.counterexample bounds a b )
            with
            | None, None -> true
            | Some c, Some c' ->
                valid G.Upper.leq bounds c a b
                && operations (Expr.expression c)
                   <= operations (Plain.expression c')
            | _ -> false)
          gap_cases;
        every "gaps: lower counterexamples valid and no longer" show_case
          (fun ((_, x, a), (_, y, b)) ->
            match
              ( Gaps.Lower.counterexample bounds x y,
                G.Lower.counterexample bounds a b )
            with
            | None, None -> true
            | Some c, Some c' ->
                valid G.Lower.leq bounds c a b
                && operations (Expr.expression c)
                   <= operations (Plain.expression c')
            | _ -> false)
          gap_cases;
      ])
    gap_bounds

(* The orders on single traces are preorders compatible with concatenation, on
   random traces over [A], [B] and delays of halves. *)
let preorders =
  let st = Random.State.make [| 13 |] in
  let symbols =
    [ Trace.Ev "A"; Trace.Ev "B"; Trace.Wait (q 1 2); Trace.Wait (qi 1) ]
  in
  let trace () =
    Trace.normalise
      (List.init (Random.State.int st 4) (fun _ ->
           List.nth symbols (Random.State.int st 4)))
  in
  let hi o = List.assoc o running_times_hi
  and lo o = List.assoc o running_times_lo in
  let orders =
    [
      ("allowance", fun s t -> Trace.allowance hi Rational.zero s t);
      ("coverage", fun s t -> Trace.coverage lo Rational.zero s t);
    ]
  in
  let triples = List.init 3000 (fun _ -> (trace (), trace (), trace ())) in
  let quadruples =
    List.init 3000 (fun _ -> (trace (), trace (), trace (), trace ()))
  in
  List.concat_map
    (fun (name, le) ->
      [
        is (name ^ ": reflexive")
          (List.for_all (fun (s, _, _) -> le s s) triples);
        is (name ^ ": transitive")
          (List.for_all
             (fun (s, t, u) -> (not (le s t && le t u)) || le s u)
             triples);
        is
          (name ^ ": compatible with concatenation")
          (List.for_all
             (fun (s, t, s', t') ->
               (not (le s t && le s' t'))
               || le (Trace.concat s s') (Trace.concat t t'))
             quadruples);
      ])
    orders

(* {1 Whole time steps}

   On integer instances the orders agree with those of the regular trace grades
   of timed operations over whole time steps through the translation [ι] of
   [test_delayRegex]: [ι(_) = 1 | ops] and [ι(~r) = ~ι(r) & (ops | 1)*], [ops]
   the operations [_ & ~(>0)], the identity elsewhere. Scaling every delay and
   every running time by [1/N] keeps the verdicts: the grades over whole steps
   of a program resolution [N] read a delay [q] as [qN] steps of [1/N], [_] as
   [1/N | ops] and complements among the traces of steps of [1/N]. *)

let ops =
  Grade.Inter
    ( Grade.Any,
      Grade.Compl (Grade.Delays (Grade.Open Rational.zero, Grade.Unbounded)) )

let rec iota n = function
  | Grade.Any -> Grade.Union (Grade.rational_tick (q 1 n), ops)
  | Grade.Compl r ->
      Grade.Inter
        ( Grade.Compl (iota n r),
          Grade.Star (Grade.Union (ops, Grade.rational_tick (q 1 n))) )
  | Grade.Seq (r, s) -> Grade.Seq (iota n r, iota n s)
  | Grade.Union (r, s) -> Grade.Union (iota n r, iota n s)
  | Grade.Inter (r, s) -> Grade.Inter (iota n r, iota n s)
  | Grade.Star r -> Grade.Star (iota n r)
  | Grade.Tick k -> Grade.rational_tick (q k n)
  | (Grade.Letter _ | Grade.Frac _ | Grade.Delays _) as r -> r

let whole_names = [ "A"; "B"; "C" ]
let whole_running_times = [ ("A", (1, 3)); ("B", (0, 2)); ("C", (2, 2)) ]

let scaled_bounds n =
  bounds_of
    (List.map
       (fun (name, (lo, hi)) -> (name, closed (q lo n, q hi n)))
       whole_running_times)

let whole_steps =
  let st = Random.State.make [| 43 |] in
  let rec whole depth =
    let int = Random.State.int st in
    let sub () = whole (depth - 1) in
    match int (if depth = 0 then 3 else 8) with
    | 0 -> Grade.Letter (List.nth whole_names (int 3))
    | 1 -> Grade.Tick (int 3)
    | 2 -> Grade.Any
    | 3 | 4 -> Grade.Seq (sub (), sub ())
    | 5 -> Grade.Union (sub (), sub ())
    | 6 -> Grade.Inter (Grade.Any, Grade.Compl (sub ()))
    | _ -> Grade.Star (sub ())
  in
  let expressions = List.init 36 (fun _ -> whole 3) in
  let agree order name (module Wg : Grade.S) (module Gg : Grade.S) n =
    let bounds = scaled_bounds n in
    let whole_bounds = scaled_bounds 1 in
    let grades =
      List.filter_map
        (fun r ->
          match
            (Wg.of_lit (Grade.Braces r), Gg.of_lit (Grade.Braces (iota n r)))
          with
          | w, g when Wg.inhabited whole_bounds w && Gg.inhabited bounds g ->
              Some (r, w, g)
          | _ -> None
          | exception Grade.Invalid_literal _ -> None)
        expressions
    in
    let pairs =
      List.concat_map (fun x -> List.map (fun y -> (x, y)) grades) grades
    in
    every
      (Printf.sprintf "whole steps, %s at resolution %d: %s agrees through ι"
         order n name)
      (fun ((r, _, _), (s, _, _)) -> show_regex r ^ " <= " ^ show_regex s)
      (fun ((_, w, g), (_, w', g')) ->
        Wg.leq whole_bounds w w' = Gg.leq bounds g g')
      pairs
  in
  List.concat_map
    (fun n ->
      [
        agree "upper" "allowance"
          (module W.Upper : Grade.S)
          (module G.Upper : Grade.S)
          n;
        agree "lower" "coverage"
          (module W.Lower : Grade.S)
          (module G.Lower : Grade.S)
          n;
      ])
    [ 1; 3 ]

(* {1 Timing} *)

let timing =
  let quickly name f =
    let start = Sys.time () in
    let holds = f () in
    let time = Sys.time () -. start in
    check name holds (Printf.sprintf "in %.2f s" time)
  in
  let world = exact [ ("A", q 1 100); ("B", qi 1) ] in
  [
    quickly "a cycle of small weight against a large bound" (fun () ->
        Option.is_some
          (C.allowance world (automaton "{A*}") (automaton "{100}")));
    quickly "a cycle of small weight within a bound" (fun () ->
        Option.is_none
          (C.allowance world (automaton "{(A; B)*; B}")
             (automaton "{(A | B | 1)*}")));
    quickly "a long sum of thirds" (fun () ->
        let trace = String.concat "; " (List.init 30 (Fun.const "B; 1/3")) in
        Option.is_none
          (C.allowance world (automaton ("{" ^ trace ^ "}")) (automaton "{40}"))
        && Option.is_some
             (C.allowance world
                (automaton ("{" ^ trace ^ "}"))
                (automaton "{39.99}")));
  ]

(* {1 Graphs} *)

(* A graph given by its rows, nondeterministic in its delays and with a state
   from which no final state is reachable, decides as the automaton of the
   same language: [(1 | 2); A], the delays read by distinct transitions
   followed by distinct operation states. *)
let graphs =
  let world = exact [ ("A", q 1 2) ] in
  let names = List.map fst world in
  let point x = DelaySet.point x in
  let m =
    C.graph
      ~gaps:
        [|
          [ (point (qi 1), 0); (point (qi 2), 1); (point (qi 3), 3) ];
          [ (DelaySet.zero, 2) ];
        |]
      ~ops:[| [ ("A", 1) ]; [ ("A", 1) ]; []; [] |]
      ~final:[| false; false; true; false |]
  in
  let m' = automaton "{(1 | 2); A}" in
  let dead =
    C.graph ~gaps:[| [ (DelaySet.all, 0) ] |] ~ops:[| [] |] ~final:[| false |]
  in
  let cases =
    [ "{1/2; A}"; "{2; A}"; "{5/2; A}"; "{3; A}"; "{1; A; 1}"; "{A}" ]
  in
  let same name decide decide' =
    every name Fun.id
      (fun text ->
        let l = automaton text in
        Option.map List.length (decide (C.of_automaton names l))
        = Option.map List.length (decide' l))
      cases
  in
  [
    same "graphs: allowance"
      (fun l -> C.Graph.allowance world l m)
      (fun l -> C.allowance world l m');
    same "graphs: coverage"
      (fun l -> C.Graph.coverage world l m)
      (fun l -> C.coverage world l m');
    is "graphs: weights"
      (C.Graph.max_weight world m = C.max_weight world m'
      && C.Graph.min_weight world m = C.min_weight world m');
    is "graphs: a graph without a final state is empty"
      ((not (C.Graph.inhabited dead)) && C.Graph.inhabited m);
  ]

let () =
  let checks =
    examples @ open_delays @ implied @ open_running_times @ closed_world
    @ literals @ recursions @ gap_agreement @ preorders @ whole_steps @ timing
    @ graphs
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  if List.mem "-v" (Array.to_list Sys.argv) then
    List.iter
      (fun c -> if c.passed then Printf.printf "ok %s %s\n" c.name c.detail)
      checks;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
