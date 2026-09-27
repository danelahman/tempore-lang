(* Property tests of the cost-model regular trace grades and of the closures
   that decide them: the segment characterisations of allowance and coverage
   against [TimedTrace.allowance] and [TimedTrace.coverage]; the membership of
   short runs in the closures against a search of the runs of the greater
   language; the laws of the orders on samples; the embedding of the finite
   timed-trace grades; and examples of the closed world, of zero costs, of the
   laws that hold up to equivalence, and of the literals. *)

module Grade = Grades.Grade
module Dfa = Grades.Dfa
module CostClosure = Grades.CostClosure
module TimedTrace = Grades.TimedTrace
module TimedTraceGrades = Grades.TimedTraceGrades
module Regular = Grades.RegularTraceGrade
module Cost = Grades.RegularCostTraceGrades

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

(* [all name show p xs] checks [p] on every element of [xs], reporting the
   first failure by [show]. *)
let all name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true ""
  | Some x -> check name false ("fails on " ^ show x)

let implies a b = (not a) || b
let pairs xs = List.concat_map (fun x -> List.map (fun y -> (x, y)) xs) xs

(* {1 Runs} *)

type symbol = T | Op of string

let names = [ "A"; "B"; "C" ]
let symbols = T :: List.map (fun o -> Op o) names

let show_word = function
  | [] -> "ε"
  | w -> String.concat " " (List.map (function T -> "τ" | Op o -> o) w)

let encode w =
  TimedTrace.normalise
    (List.map (function T -> TimedTrace.Wait 1 | Op o -> TimedTrace.Ev o) w)

(* [words n] is the words of length at most [n] over [symbols]. *)
let words n =
  let extend ws =
    List.concat_map (fun w -> List.map (fun s -> s :: w) symbols) ws
  in
  let rec upto n ws = if n = 0 then ws else ws @ upto (n - 1) (extend ws) in
  List.sort_uniq compare (upto n [ [] ])

let random_word n state =
  List.init
    (Random.State.int state (n + 1))
    (fun _ -> List.nth symbols (Random.State.int state (List.length symbols)))

(* The factorisations [(u, v)] of [w = u v]. *)
let splits w =
  List.init
    (List.length w + 1)
    (fun i ->
      (List.filteri (fun j _ -> j < i) w, List.filteri (fun j _ -> j >= i) w))

let weight cost =
  List.fold_left (fun n -> function T -> n + 1 | Op o -> n + cost o) 0

let ticks w = List.length (List.filter (( = ) T) w)
let only_ticks = List.for_all (( = ) T)

(* [matched segment ok s t] is whether [s] and [t] factor as [s₀ o s'] and
   [t₀ o t'] with [segment s₀ t₀] and [ok s' t']. *)
let matched segment ok s t =
  List.exists
    (fun (s0, s') ->
      match s' with
      | Op o :: s' ->
          List.exists
            (fun (t0, t') ->
              match t' with
              | Op o' :: t' -> o = o' && segment s0 t0 && ok s' t'
              | _ -> false)
            (splits t)
      | _ -> false)
    (splits s)

(* [segments_allow cost s t] is the segment characterisation of [s ≼ᵃ t]: [s]
   and [t] factor with matched operations, the weight of each segment of [s]
   at most the number of ticks of that of [t]. *)
let rec segments_allow cost s t =
  let segment s0 t0 = weight cost s0 <= ticks t0 in
  segment s t || matched segment (segments_allow cost) s t

(* [segments_cover cost s t] is the segment characterisation of [s ≼ᶜ t]: the
   guarantee [s] and the run [t] factor with matched operations, each segment
   of [s] a word of ticks no longer than the weight of that of [t]. *)
let rec segments_cover cost s t =
  let segment s0 t0 = only_ticks s0 && List.length s0 <= weight cost t0 in
  segment s t || matched segment (segments_cover cost) s t

(* {1 Cost models} *)

(* Cost models over [names]: random lower ends in [0 … 2] and upper ends up to
   two more, then all ones and all zeros. *)
let tables =
  let state = Random.State.make [| 7 |] in
  let random () =
    List.map
      (fun o ->
        let lo = Random.State.int state 3 in
        (o, (lo, lo + Random.State.int state 3)))
      names
  in
  List.init 10 (fun _ -> random ())
  @ [
      List.map (fun o -> (o, (1, 1))) names;
      List.map (fun o -> (o, (0, 0))) names;
    ]

let bounds_of table =
  {
    Grade.cost = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

let show_table table =
  String.concat ", "
    (List.map (fun (o, (lo, hi)) -> Printf.sprintf "%s:(%d,%d)" o lo hi) table)

let lo_of table o = fst (List.assoc o table)
let hi_of table o = snd (List.assoc o table)

(* {1 (a) Segment characterisations} *)

let segments =
  let state = Random.State.make [| 11 |] in
  let samples =
    pairs (words 3)
    @ List.init 3000 (fun _ -> (random_word 6 state, random_word 7 state))
  in
  List.concat_map
    (fun table ->
      let show (s, t) =
        show_word s ^ " vs " ^ show_word t ^ " at " ^ show_table table
      in
      let lo = lo_of table and hi = hi_of table in
      [
        all "segments: allowance" show
          (fun (s, t) ->
            segments_allow hi s t
            = TimedTrace.allowance hi 0 (encode s) (encode t))
          samples;
        all "segments: coverage" show
          (fun (s, t) ->
            segments_cover lo s t
            = TimedTrace.coverage lo 0 (encode s) (encode t))
          samples;
      ])
    tables

(* {1 (b) Closure membership} *)

let letter = function
  | T -> 0
  | Op o -> 1 + Option.get (List.find_index (String.equal o) names)

let accepts (a : _ Dfa.automaton) w =
  a.accepts (List.fold_left (fun q s -> a.step q (letter s)) a.start w)

let member dfa w =
  let q = List.fold_left (fun q s -> Dfa.next dfa q (letter s)) 0 w in
  Dfa.final dfa q

module Subsets = Dfa.Implicit (struct
  type t = int list

  let compare = compare
end)

let letter_cost table endpoint a =
  endpoint (List.assoc (List.nth names (a - 1)) table)

(* Random regular expressions of depth [depth] over [A], [B] and delays, [C]
   being left to the catch-all letter; with [~finite], only sequences and
   unions of letters and delays. *)
let random_regex ?(finite = false) ~depth state =
  let atom () =
    match Random.State.int state (if finite then 4 else 5) with
    | 0 -> Grade.Letter "A"
    | 1 -> Grade.Letter "B"
    | 2 -> Grade.Tick (Random.State.int state 3)
    | 3 -> Grade.Tick 1
    | _ -> Grade.Any
  in
  let rec go depth =
    if depth = 0 then atom ()
    else
      match Random.State.int state (if finite then 6 else 9) with
      | 0 | 1 -> atom ()
      | 2 | 3 -> Grade.Seq (go (depth - 1), go (depth - 1))
      | 4 | 5 -> Grade.Union (go (depth - 1), go (depth - 1))
      | 6 -> Grade.Inter (go (depth - 1), go (depth - 1))
      | 7 -> Grade.Star (go (depth - 1))
      | _ -> Grade.Compl (go (depth - 1))
  in
  go depth

let grade r =
  match Regular.of_lit (Grade.Braces r) with
  | rho -> Some rho
  | exception Grade.Invalid_literal _ -> None

(* [membership name table short (rho, members)] checks that a run of [short]
   is in a closure of [rho] under [table] iff it is below one of the [members]
   of [rho] in the order of [TimedTrace]. *)
let membership name table short (rho, members) =
  let dfa = Regular.concrete names rho in
  let down = CostClosure.allowance ~cost:(letter_cost table snd) dfa in
  let up = CostClosure.coverage ~cost:(letter_cost table fst) dfa in
  let lo = lo_of table and hi = hi_of table in
  let show w =
    show_word w ^ " and " ^ Regular.show rho ^ " at " ^ show_table table
  in
  let n = Dfa.letters dfa in
  let closed = Subsets.canonical n in
  let show_rho = Regular.show rho ^ " at " ^ show_table table in
  let operator closure =
    let closure dfa = closed (closure dfa) in
    let m = closure dfa in
    Dfa.subset dfa m && Dfa.equal (closure m) m
  in
  let exists order w =
    List.exists (fun m -> order (encode w) (encode m)) members
  in
  [
    all (name ^ ": allowance") show
      (fun w -> accepts down w = exists (TimedTrace.allowance hi 0) w)
      short;
    all (name ^ ": coverage") show
      (fun w ->
        accepts up w = exists (fun w m -> TimedTrace.coverage lo 0 m w) w)
      short;
    check
      (name ^ ": allowance closure extensive and idempotent")
      (operator (CostClosure.allowance ~cost:(letter_cost table snd)))
      show_rho;
    check
      (name ^ ": coverage closure extensive and idempotent")
      (operator (CostClosure.coverage ~cost:(letter_cost table fst)))
      show_rho;
  ]

(* [finite_words r] is the words of the expression [r] without [*], [&], [~]
   and [_]. *)
let rec finite_words = function
  | Grade.Letter o -> [ [ Op o ] ]
  | Grade.Tick n -> [ List.init n (fun _ -> T) ]
  | Grade.Seq (r, s) ->
      List.concat_map
        (fun u -> List.map (fun v -> u @ v) (finite_words s))
        (finite_words r)
  | Grade.Union (r, s) -> finite_words r @ finite_words s
  | Grade.Any | Grade.Star _ | Grade.Inter _ | Grade.Compl _ ->
      invalid_arg "finite_words"

(* Finite languages, whose members are all known, and regular languages, whose
   members are searched among the runs of length at most 6: with costs at most
   2, these include a member above each run of length at most 2 in the closure,
   for the samples. *)
let closures =
  let state = Random.State.make [| 3 |] in
  let finite =
    List.filter_map
      (fun r -> Option.map (fun rho -> (rho, finite_words r)) (grade r))
      (List.init 30 (fun _ -> random_regex ~finite:true ~depth:3 state))
  in
  let regular =
    List.filter_map
      (fun r ->
        Option.map
          (fun rho ->
            (rho, List.filter (member (Regular.concrete names rho)) (words 6)))
          (grade r))
      (List.init 20 (fun _ -> random_regex ~depth:3 state))
  in
  let small table = List.for_all (fun (_, (_, hi)) -> hi <= 2) table in
  List.concat_map
    (fun table ->
      List.concat_map
        (membership "closure of a finite language" table (words 3))
        finite
      @
      if small table then
        List.concat_map (membership "closure" table (words 2)) regular
      else [])
    tables

(* {1 (c) Laws} *)

(* [laws (module G) table samples] checks the laws of a preorder with a
   monotone product and join on [samples] under [table]. *)
let laws (type a) (module G : Grade.S with type t = a) table (samples : a list)
    =
  let bounds = bounds_of table in
  let name law = G.name ^ ": " ^ law in
  let leq = G.leq bounds in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ show_table table in
  let show2 (x, y) = G.show x ^ ", " ^ G.show y ^ " at " ^ show_table table in
  let below = List.filter (fun (x, y) -> leq x y) (pairs samples) in
  let triples =
    List.concat_map (fun (x, y) -> List.map (fun z -> (x, y, z)) samples) below
  in
  [
    all (name "reflexive") show1 (fun x -> leq x x) samples;
    all (name "transitive")
      (fun (x, y, z) -> show2 (x, y) ^ ", " ^ G.show z)
      (fun (x, y, z) -> implies (leq y z) (leq x z))
      triples;
    all (name "product monotone")
      (fun (x, y, z) -> show2 (x, y) ^ ", " ^ G.show z)
      (fun (x, y, z) ->
        leq (G.mul x z) (G.mul y z) && leq (G.mul z x) (G.mul z y))
      triples;
    all
      (name "join an upper bound")
      show2
      (fun (x, y) -> leq x (G.join x y) && leq y (G.join x y))
      (pairs samples);
    all (name "join least")
      (fun (x, y, z) -> show2 (x, y) ^ ", " ^ G.show z)
      (fun (x, y, z) -> implies (leq x z && leq y z) (leq (G.join x y) z))
      (List.concat_map
         (fun (x, y) -> List.map (fun z -> (x, y, z)) samples)
         (pairs (List.filteri (fun i _ -> i < 8) samples)));
    all (name "top greatest") show1 (fun x -> leq x G.top) samples;
    all
      (name "equal is mutual leq")
      show2
      (fun (x, y) -> equal x y = (leq x y && leq y x))
      (pairs samples);
    all (name "counterexamples") show2
      (fun (x, y) ->
        match G.counterexample bounds x y with
        | None -> leq x y
        | Some e -> (not (leq x y)) && leq e x && not (leq e y))
      (pairs samples);
  ]
  @
  if G.unit_least then
    [
      all (name "unit least") show1 (fun x -> leq G.one x) samples;
      all
        (name "top absorbing up to equality")
        show1
        (fun x -> equal (G.mul x G.top) G.top && equal (G.mul G.top x) G.top)
        samples;
    ]
  else []

let of_nat_laws (module G : Grade.S) ~monotone =
  let bounds = bounds_of (List.hd tables) in
  let ns = pairs (List.init 5 Fun.id) in
  [
    all
      (G.name ^ ": of_nat a homomorphism")
      (fun (m, n) -> Printf.sprintf "%d, %d" m n)
      (fun (m, n) ->
        G.equal bounds (G.of_nat (m + n)) (G.mul (G.of_nat m) (G.of_nat n)))
      ns;
    all
      (G.name ^ ": of_nat ordered")
      (fun (m, n) -> Printf.sprintf "%d, %d" m n)
      (fun (m, n) ->
        G.leq bounds (G.of_nat m) (G.of_nat n)
        = if monotone then m <= n else m >= n)
      ns;
  ]

let law_checks =
  let state = Random.State.make [| 5 |] in
  let samples =
    List.filter_map grade (List.init 14 (fun _ -> random_regex ~depth:2 state))
  in
  let intervals =
    List.filteri (fun i _ -> i < 8) (List.combine samples (List.rev samples))
  in
  let some_tables = List.filteri (fun i _ -> i mod 3 = 0) tables in
  List.concat_map
    (fun table ->
      laws (module Cost.Upper) table samples
      @ laws (module Cost.Lower) table samples
      @ laws (module Cost.Interval) table intervals)
    some_tables
  @ of_nat_laws (module Cost.Upper) ~monotone:true
  @ of_nat_laws (module Cost.Lower) ~monotone:false
  @ [
      all "traces-regex-lower: the unit is the top"
        (fun table -> show_table table)
        (fun table ->
          Cost.Lower.equal (bounds_of table) Cost.Lower.top Regular.top)
        tables;
    ]

(* {1 (d) Embedding of the finite timed-trace grades} *)

let embedding =
  let state = Random.State.make [| 13 |] in
  let finite =
    List.init 30 (fun _ ->
        Grade.Braces (random_regex ~finite:true ~depth:3 state))
  in
  let lits = Grade.Top :: finite in
  let agree (module F : Grade.S) (module G : Grade.S) lits =
    List.concat_map
      (fun table ->
        let bounds = bounds_of table in
        let show (l, l') =
          G.show (G.of_lit l)
          ^ ", "
          ^ G.show (G.of_lit l')
          ^ " at " ^ show_table table
        in
        [
          all
            (G.name ^ ": embeds " ^ F.name)
            show
            (fun (l, l') ->
              F.leq bounds (F.of_lit l) (F.of_lit l')
              = G.leq bounds (G.of_lit l) (G.of_lit l'))
            (pairs lits);
          all
            (G.name ^ ": implied bounds as " ^ F.name)
            (fun l -> G.show (G.of_lit l) ^ " at " ^ show_table table)
            (fun l ->
              F.implied_bounds bounds (F.of_lit l)
              = G.implied_bounds bounds (G.of_lit l))
            lits;
        ])
      tables
  in
  let pairs_of lits =
    List.map2 (fun l l' -> Grade.Tuple [ l; l' ]) lits (List.rev lits)
  in
  agree (module TimedTraceGrades.UpperBound) (module Cost.Upper) lits
  @ agree (module TimedTraceGrades.LowerBound) (module Cost.Lower) lits
  @ agree
      (module TimedTraceGrades.Interval)
      (module Cost.Interval)
      (pairs_of lits)

(* {1 (e) Examples} *)

(* [Reader (G)] reads the literals of [G] by the parser, in the grade position
   of a box. *)
module Reader (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let lit text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox (rho, _); _ } -> rho
    | _ -> invalid_arg ("not a box: " ^ text)
end

module U = Reader (Cost.Upper)
module L = Reader (Cost.Lower)
module I = Reader (Cost.Interval)

(* [A] costs 1 to 3, [B] exactly 2 and [C] up to 5. *)
let costs = bounds_of [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)) ]
let holds name b = check name b ""
let fails name b = check name (not b) ""
let show_option show = function Some x -> show x | None -> "none"
let show_bounds = show_option (fun (lo, hi) -> Printf.sprintf "(%d, %d)" lo hi)

let upper_examples =
  let leq a b = Cost.Upper.leq costs (U.lit a) (U.lit b) in
  let equal a b = Cost.Upper.equal costs (U.lit a) (U.lit b) in
  let name = ( ^ ) "traces-regex-upper: " in
  [
    holds (name "a delay pays for an operation at hi") (leq "{A}" "{3}");
    fails (name "an operation does not pay for a delay") (leq "{3}" "{A}");
    fails (name "a delay short of hi") (leq "{A}" "{2}");
    holds (name "equal up to the closure") (equal "{A | 3}" "{3}");
    fails (name "not equal as languages") (equal "{A}" "{3}");
    holds (name "a bound's operation may go unspent") (leq "{A}" "{A; B}");
    holds (name "an operation matched, another bought") (leq "{B; A}" "{B; 3}");
    fails (name "a match resets the budget") (leq "{A; B}" "{B; 3}");
    holds
      (name "the closure of a product is larger")
      (Cost.Upper.leq costs (U.lit "{A}")
         (Cost.Upper.mul (U.lit "{2}") (U.lit "{2}")));
    holds
      (name "the catch-all letter stands for C")
      (leq "{C}" "{_ & ~1 & ~A & ~B}");
    holds (name "any letter within the dearest cost") (leq "{_}" "{5}");
    fails (name "any letter beyond the dearest cost") (leq "{_}" "{4}");
    fails
      (name "a further declared operation")
      (Cost.Upper.leq
         (bounds_of
            [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)); ("D", (9, 9)) ])
         (U.lit "{_}") (U.lit "{5}"));
    holds (name "an unbounded time buys anything") (equal "{1*}" "⊤");
    holds
      (name "an operation is not excluded while time is unbounded")
      (equal "{(_ & ~A)*}" "⊤");
    holds
      (name "the top absorbs a product")
      (Cost.Upper.equal costs
         (Cost.Upper.mul (U.lit "{3}") Cost.Upper.top)
         Cost.Upper.top);
    holds (name "the top absorbs up to equality") (equal "{3; _*}" "⊤");
    holds
      (name "a zero cost is invisible")
      (Cost.Upper.equal
         (bounds_of [ ("A", (0, 0)) ])
         (U.lit "{A*}") (U.lit "{0}"));
    expect (name "counterexample") (show_option Fun.id)
      ~expected:(Some "{A; 3}")
      (Option.map Cost.Upper.show
         (Cost.Upper.counterexample costs (U.lit "{A; 3 | 1}") (U.lit "{5}")));
    expect (name "implied bounds") show_bounds
      ~expected:(Some (1, 3))
      (Cost.Upper.implied_bounds costs (U.lit "{A | B; 1}"));
    expect
      (name "no implied bounds when unbounded")
      show_bounds ~expected:None
      (Cost.Upper.implied_bounds costs (U.lit "{A; B*}"));
    expect (name "time shadow") Fun.id ~expected:"{3}"
      (Cost.Upper.show (Cost.Upper.of_bounds (1, 3)));
    holds (name "atomic") (Cost.Upper.is_atomic "A" (U.lit "{A}"));
    holds (name "needs runtime bounds") Cost.Upper.needs_op_bounds;
    holds (name "unit least") Cost.Upper.unit_least;
    expect (name "top") Fun.id ~expected:"⊤" (Cost.Upper.show (U.lit "⊤"));
  ]

let lower_examples =
  let leq a b = Cost.Lower.leq costs (L.lit a) (L.lit b) in
  let equal a b = Cost.Lower.equal costs (L.lit a) (L.lit b) in
  let name = ( ^ ) "traces-regex-lower: " in
  [
    holds (name "an operation covers a delay at lo") (leq "{A}" "{1}");
    fails (name "an operation short of a delay") (leq "{A}" "{2}");
    fails (name "a delay does not cover an operation") (leq "{3}" "{A}");
    holds (name "an operation and a delay cover their sum") (leq "{A; 1}" "{2}");
    holds (name "a demanded operation is matched") (leq "{1; A}" "{A}");
    fails (name "a demanded operation is not bought") (leq "{B}" "{A}");
    holds (name "equal up to the closure") (equal "{A | 1}" "{1}");
    holds (name "the unit is the top") (equal "⊤" "{_*}");
    fails (name "the unit is not least") (leq "{0}" "{A}");
    expect (name "counterexample") (show_option Fun.id) ~expected:(Some "{A}")
      (Option.map Cost.Lower.show
         (Cost.Lower.counterexample costs (L.lit "{A | 3}") (L.lit "{2}")));
    expect (name "implied bounds") show_bounds
      ~expected:(Some (1, 3))
      (Cost.Lower.implied_bounds costs (L.lit "{A | B; 1}"));
    expect (name "time shadow") Fun.id ~expected:"{1}"
      (Cost.Lower.show (Cost.Lower.of_bounds (1, 3)));
    fails (name "unit least") Cost.Lower.unit_least;
    expect (name "top") Fun.id ~expected:"{0}" (Cost.Lower.show (L.lit "⊤"));
  ]

let interval_examples =
  let leq a b = Cost.Interval.leq costs (I.lit a) (I.lit b) in
  let name = ( ^ ) "traces-regex-interval: " in
  let reads text expected =
    expect
      (name ("reads " ^ text))
      Fun.id ~expected
      (Cost.Interval.show (I.lit text))
  in
  [
    reads "({A}, {3})" "({A},{3})";
    reads "{A | B}" "({A | B},{A | B})";
    reads "2" "({2},{2})";
    reads "(1, 3)" "({1},{3})";
    reads "({A}, ⊤)" "({A},⊤)";
    reads "⊤" "({0},⊤)";
    holds (name "componentwise") (leq "{A}" "(1, 3)");
    fails (name "the lower component") (leq "{A}" "(2, 3)");
    fails (name "the upper component") (leq "{A}" "(1, 2)");
    expect (name "implied bounds") show_bounds
      ~expected:(Some (1, 2))
      (Cost.Interval.implied_bounds costs (I.lit "({A | B}, {B})"));
    expect (name "time shadow") Fun.id ~expected:"({1},{3})"
      (Cost.Interval.show (Cost.Interval.of_bounds (1, 3)));
    fails (name "unit least") Cost.Interval.unit_least;
  ]

let examples = upper_examples @ lower_examples @ interval_examples

let () =
  let checks = segments @ closures @ law_checks @ embedding @ examples in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
