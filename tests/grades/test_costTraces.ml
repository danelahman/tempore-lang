(* Property tests of the cost-model regular trace grades and of the closures
   that decide them: the segment characterisations of allowance and coverage
   against [TimedTrace.allowance] and [TimedTrace.coverage]; then, for each of
   the four implementations, by automata, by symbolic derivatives, by
   derivatives by letters and by derivatives over single letters, the
   membership of short runs in the closures against a search of the runs of
   the greater language, the laws of the orders on samples, the embedding of
   the finite trace grades, and examples of the closed world, of zero
   costs, of the laws that hold up to equivalence, of the literals and of the
   grades without runs; the agreement of the implementations on random
   grades and cost models, in their verdicts and their printing; long runs of
   ticks, taken at once by the implementations by derivatives; and the
   agreement of the implementations over cost models of many operations
   sharing costs, in their counterexamples too. *)

module Grade = Grades.Grade
module Dfa = Grades.Dfa
module CostClosure = Grades.CostClosure
module TimedTrace = Grades.TimedTrace
module TimedTraceGrades = Grades.TimedTraceGrades
module Cost = Grades.RegularCostTraceGrades
open LawChecks

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

(* {1 Grades} *)

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

(* Random regular expressions of depth [depth] over [A], [B] and delays of up
   to [longest] ticks, [2] by default, [C] being left to the catch-all letter;
   with [~finite], only sequences and unions of letters and delays. *)
let random_regex ?(finite = false) ?(longest = 2) ~depth state =
  let atom () =
    match Random.State.int state (if finite then 4 else 5) with
    | 0 -> Grade.Letter "A"
    | 1 -> Grade.Letter "B"
    | 2 -> Grade.Tick (Random.State.int state (longest + 1))
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

(* [Reader (G)] reads the literals of [G] by the parser, in the grade position
   of a box. *)
module Reader (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let lit text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> invalid_arg ("not a box of a literal: " ^ text)
end

(* [A] costs 1 to 3, [B] exactly 2 and [C] up to 5. *)
let costs = bounds_of [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)) ]
let holds name b = check name b ""
let fails name b = check name (not b) ""
let show_option show = function Some x -> show x | None -> "none"
let show_bounds = show_option (fun (lo, hi) -> Printf.sprintf "(%d, %d)" lo hi)

(* [agree tables (module F) (module G) lits] checks that the grades [F] and [G]
   order the literals [lits] alike and imply the same runtime bounds, under
   each of [tables]. *)
let agree tables (module F : Grade.S) (module G : Grade.S) lits =
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

(* [embeds (module Upper) (module Lower) (module Interval) tables lits] checks
   that the cost-model grades embed the trace grades on the finite
   literals [lits], and on the pairs of them as intervals. *)
let embeds (module Upper : Grade.S) (module Lower : Grade.S)
    (module Interval : Grade.S) tables lits =
  let pairs_of lits =
    List.map2 (fun l l' -> Grade.Tuple [ l; l' ]) lits (List.rev lits)
  in
  agree tables (module TimedTraceGrades.UpperBound) (module Upper) lits
  @ agree tables (module TimedTraceGrades.LowerBound) (module Lower) lits
  @ agree tables
      (module TimedTraceGrades.Interval)
      (module Interval)
      (pairs_of lits)

(* {1 The implementations} *)

module type IMPLEMENTATION = sig
  val name : string

  module L : Cost.LANGUAGE
  module Upper : Grade.S with type t = L.t
  module Lower : Grade.S with type t = L.t
  module Interval : Grade.S with type t = L.t * L.t
end

module Automata = struct
  let name = "automata"

  module L = Cost.Automata
  module Upper = Cost.Upper
  module Lower = Cost.Lower
  module Interval = Cost.Interval
end

module Derivatives = struct
  let name = "derivatives"

  module L = Cost.Derivatives
  include Cost.Symbolic
end

module ByLetters = struct
  let name = "derivatives by letters"

  module L = Cost.ConcreteDerivatives
  include Cost.Concrete
end

module Plain = struct
  let name = "plain derivatives"

  module L = Cost.PlainDerivatives
  include Cost.Plain
end

(* The checks of the implementation [I]. *)
module Suite (I : IMPLEMENTATION) = struct
  include I
  module Coverage = CostClosure.Coverage (L.State)

  module Covering = Dfa.Implicit (struct
    type t = L.State.t list

    let compare = List.compare L.State.compare
  end)

  let grade r =
    match L.of_lit (Grade.Braces r) with
    | rho -> Some rho
    | exception Grade.Invalid_literal _ -> None

  (* {2 (b) Closure membership} *)

  (* [membership name table short (rho, members)] checks that a run of [short]
     is in a closure of [rho] under [table] iff it is below one of the
     [members] of [rho] in the order of [TimedTrace], that the closures of the
     table of [rho] are closure operators, and that the upward closure of the
     runs of [rho] is that of its table. *)
  let membership name table short (rho, members) =
    let name = I.name ^ ": " ^ name in
    let dfa = L.concrete names rho in
    let down = CostClosure.allowance ~cost:(letter_cost table snd) dfa in
    let up =
      Coverage.closure ~cost:(letter_cost table fst) (L.runs names rho)
    in
    let lo = lo_of table and hi = hi_of table in
    let show w =
      show_word w ^ " and " ^ L.show rho ^ " at " ^ show_table table
    in
    let n = Dfa.letters dfa in
    let closed = Subsets.canonical n in
    let show_rho = L.show rho ^ " at " ^ show_table table in
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
      check
        (name ^ ": coverage closure of the runs")
        (Dfa.equal (Covering.canonical n up)
           (closed (CostClosure.coverage ~cost:(letter_cost table fst) dfa)))
        show_rho;
    ]

  (* Finite languages, whose members are all known, and regular languages,
     whose members are searched among the runs of length at most 6: with costs
     at most 2, these include a member above each run of length at most 2 in
     the closure, for the samples. *)
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
              (rho, List.filter (member (L.concrete names rho)) (words 6)))
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

  (* {2 (c) Laws} *)

  let law_checks =
    let state = Random.State.make [| 5 |] in
    let samples =
      List.filter_map grade
        (List.init 14 (fun _ -> random_regex ~depth:2 state))
    in
    let intervals =
      List.filteri (fun i _ -> i < 8) (List.combine samples (List.rev samples))
    in
    let some_tables = List.filteri (fun i _ -> i mod 3 = 0) tables in
    List.concat_map
      (fun table ->
        let context = show_table table and bounds = bounds_of table in
        laws (module Upper) ~context bounds samples
        @ laws (module Lower) ~context bounds samples
        @ laws (module Interval) ~context bounds intervals)
      some_tables
    @ of_delay_laws
        (module Upper)
        (bounds_of (List.hd tables))
        ~monotone:true ()
    @ of_delay_laws
        (module Lower)
        (bounds_of (List.hd tables))
        ~monotone:false ()
    @ [
        all
          (Lower.name ^ ": the unit is the top")
          (fun table -> show_table table)
          (fun table -> Lower.equal (bounds_of table) Lower.top L.top)
          tables;
      ]

  (* {2 (d) Embedding of the finite trace grades} *)

  let embedding =
    let state = Random.State.make [| 13 |] in
    let finite =
      List.init 30 (fun _ ->
          Grade.Braces (random_regex ~finite:true ~depth:3 state))
    in
    embeds
      (module Upper)
      (module Lower)
      (module Interval)
      tables (Grade.Top :: finite)

  (* {2 (e) Examples} *)

  module U = Reader (Upper)
  module Lo = Reader (Lower)
  module In = Reader (Interval)

  let upper_examples =
    let leq a b = Upper.leq costs (U.lit a) (U.lit b) in
    let equal a b = Upper.equal costs (U.lit a) (U.lit b) in
    let name = ( ^ ) (Upper.name ^ ": ") in
    [
      holds (name "a delay pays for an operation at hi") (leq "{A}" "{3}");
      fails (name "an operation does not pay for a delay") (leq "{3}" "{A}");
      fails (name "a delay short of hi") (leq "{A}" "{2}");
      holds (name "equal up to the closure") (equal "{A | 3}" "{3}");
      fails (name "not equal as languages") (equal "{A}" "{3}");
      holds (name "a bound's operation may go unspent") (leq "{A}" "{A; B}");
      holds
        (name "an operation matched, another bought")
        (leq "{B; A}" "{B; 3}");
      fails (name "a match resets the budget") (leq "{A; B}" "{B; 3}");
      holds
        (name "the closure of a product is larger")
        (Upper.leq costs (U.lit "{A}") (Upper.mul (U.lit "{2}") (U.lit "{2}")));
      holds
        (name "the catch-all letter stands for C")
        (leq "{C}" "{_ & ~1 & ~A & ~B}");
      holds (name "any letter within the dearest cost") (leq "{_}" "{5}");
      fails (name "any letter beyond the dearest cost") (leq "{_}" "{4}");
      fails
        (name "a further declared operation")
        (Upper.leq
           (bounds_of
              [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)); ("D", (9, 9)) ])
           (U.lit "{_}") (U.lit "{5}"));
      holds (name "an unbounded time buys anything") (equal "{1*}" "⊤");
      holds
        (name "an operation is not excluded while time is unbounded")
        (equal "{(_ & ~A)*}" "⊤");
      holds
        (name "the top absorbs a product")
        (Upper.equal costs (Upper.mul (U.lit "{3}") Upper.top) Upper.top);
      holds (name "the top absorbs up to equality") (equal "{3; _*}" "⊤");
      holds
        (name "a zero cost is invisible")
        (Upper.equal (bounds_of [ ("A", (0, 0)) ]) (U.lit "{A*}") (U.lit "{0}"));
      expect (name "counterexample") (show_option Fun.id)
        ~expected:(Some "{A; 3}")
        (Option.map Upper.show
           (Upper.counterexample costs (U.lit "{A; 3 | 1}") (U.lit "{5}")));
      expect (name "implied bounds") show_bounds
        ~expected:(Some (1, 3))
        (Upper.implied_bounds costs (U.lit "{A | B; 1}"));
      expect
        (name "no implied bounds when unbounded")
        show_bounds ~expected:None
        (Upper.implied_bounds costs (U.lit "{A; B*}"));
      expect (name "time shadow") Fun.id ~expected:"{3}"
        (Upper.show (Upper.of_bounds (1, 3)));
      holds (name "atomic") (Upper.is_atomic "A" (U.lit "{A}"));
      holds (name "needs runtime bounds") Upper.needs_op_bounds;
      holds (name "unit least") Upper.unit_least;
      expect (name "top") Fun.id ~expected:"⊤" (Upper.show (U.lit "⊤"));
    ]

  let lower_examples =
    let leq a b = Lower.leq costs (Lo.lit a) (Lo.lit b) in
    let equal a b = Lower.equal costs (Lo.lit a) (Lo.lit b) in
    let name = ( ^ ) (Lower.name ^ ": ") in
    [
      holds (name "an operation covers a delay at lo") (leq "{A}" "{1}");
      fails (name "an operation short of a delay") (leq "{A}" "{2}");
      fails (name "a delay does not cover an operation") (leq "{3}" "{A}");
      holds
        (name "an operation and a delay cover their sum")
        (leq "{A; 1}" "{2}");
      holds (name "a demanded operation is matched") (leq "{1; A}" "{A}");
      fails (name "a demanded operation is not bought") (leq "{B}" "{A}");
      holds (name "equal up to the closure") (equal "{A | 1}" "{1}");
      holds (name "the unit is the top") (equal "⊤" "{_*}");
      fails (name "the unit is not least") (leq "{0}" "{A}");
      expect (name "counterexample") (show_option Fun.id) ~expected:(Some "{A}")
        (Option.map Lower.show
           (Lower.counterexample costs (Lo.lit "{A | 3}") (Lo.lit "{2}")));
      expect (name "implied bounds") show_bounds
        ~expected:(Some (1, 3))
        (Lower.implied_bounds costs (Lo.lit "{A | B; 1}"));
      expect (name "time shadow") Fun.id ~expected:"{1}"
        (Lower.show (Lower.of_bounds (1, 3)));
      fails (name "unit least") Lower.unit_least;
      expect (name "top") Fun.id ~expected:"{0}" (Lower.show (Lo.lit "⊤"));
    ]

  let interval_examples =
    let leq a b = Interval.leq costs (In.lit a) (In.lit b) in
    let name = ( ^ ) (Interval.name ^ ": ") in
    let reads text expected =
      expect
        (name ("reads " ^ text))
        Fun.id ~expected
        (Interval.show (In.lit text))
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
        (Interval.implied_bounds costs (In.lit "({A | B}, {B})"));
      expect (name "time shadow") Fun.id ~expected:"({1},{3})"
        (Interval.show (Interval.of_bounds (1, 3)));
      fails (name "unit least") Interval.unit_least;
    ]

  (* Grades without runs of the declared operations. *)
  let inhabitation_examples =
    let only_a = bounds_of [ ("A", (1, 3)) ] in
    let a_and_b = bounds_of [ ("A", (1, 3)); ("B", (2, 2)) ] in
    let none = bounds_of [] in
    let name = ( ^ ) (I.name ^ ": inhabited: ") in
    [
      fails
        (name "the catch-all letter where every operation is named")
        (Upper.inhabited only_a (U.lit "{_ & ~1 & ~A}"));
      holds
        (name "a further declared operation")
        (Upper.inhabited a_and_b (U.lit "{_ & ~1 & ~A}"));
      holds
        (name "the catch-all letter besides the runs")
        (Upper.inhabited only_a (U.lit "{_ & ~1 & ~A | 2}"));
      holds (name "a mentioned name") (Lower.inhabited none (Lo.lit "{B}"));
      fails
        (name "no operation declared")
        (Lower.inhabited none (Lo.lit "{_ & ~1}"));
      holds (name "ticks") (Lower.inhabited none (Lo.lit "{_*}"));
      fails
        (name "the lower component")
        (Interval.inhabited only_a (In.lit "({_ & ~1 & ~A}, {A})"));
      fails
        (name "the upper component")
        (Interval.inhabited only_a (In.lit "({A}, {_ & ~1 & ~A})"));
      holds (name "both components")
        (Interval.inhabited only_a (In.lit "({A}, {1})"));
    ]

  let examples =
    upper_examples @ lower_examples @ interval_examples @ inhabitation_examples

  let checks = closures @ law_checks @ embedding @ examples

  (* {2 Verdicts} *)

  (* [length rho] is the length of a shortest run of [rho] over [names]. *)
  let length rho =
    Option.map List.length
      (Dfa.counterexample (L.concrete names rho)
         (Dfa.empty (List.length names + 1)))

  (* [verdicts bounds (r, r')] is, for each grade, whether [r] is below [r'],
     whether they are equal, and the lengths of the shortest runs of the
     components of the counterexample, [r] and [r'] read as grades. *)
  let verdicts bounds (r, r') =
    match (grade r, grade r') with
    | Some rho, Some rho' ->
        let verdict (type a) (module G : Grade.S with type t = a) lengths x y =
          ( G.leq bounds x y,
            G.equal bounds x y,
            Option.map lengths (G.counterexample bounds x y) )
        in
        let single rho = [ length rho ] in
        let pair (lo, hi) = [ length lo; length hi ] in
        Some
          [
            verdict (module Upper) single rho rho';
            verdict (module Lower) single rho rho';
            verdict (module Interval) pair (rho, rho') (rho', rho);
          ]
    | _ -> None
end

module OfAutomata = Suite (Automata)
module OfDerivatives = Suite (Derivatives)
module OfByLetters = Suite (ByLetters)
module OfPlain = Suite (Plain)

(* {1 (f) Agreement of the implementations} *)

let agreement =
  let state = Random.State.make [| 17 |] in
  let regexes = List.init 16 (fun _ -> random_regex ~depth:3 state) in
  let show_regex r =
    match OfAutomata.grade r with
    | Some rho -> OfAutomata.L.show rho
    | None -> "∅"
  in
  List.map
    (fun table ->
      let bounds = bounds_of table in
      all "the implementations agree on leq, equal and counterexamples"
        (fun (r, r') ->
          show_regex r ^ ", " ^ show_regex r' ^ " at " ^ show_table table)
        (fun pair ->
          let verdicts = OfAutomata.verdicts bounds pair in
          OfDerivatives.verdicts bounds pair = verdicts
          && OfByLetters.verdicts bounds pair = verdicts
          && OfPlain.verdicts bounds pair = verdicts)
        (pairs regexes))
    tables

(* The implementations by derivatives print each grade alike, unless the
   printing of that over single letters or that by symbolic derivatives falls
   back. *)
let printing =
  let state = Random.State.make [| 23 |] in
  let regexes = List.init 64 (fun _ -> random_regex ~depth:3 state) in
  let module D = Grades.RegularTraceGradeDerivative in
  let module P = Grades.RegularTraceGradePlain in
  let alike r =
    match (OfDerivatives.grade r, OfByLetters.grade r, OfPlain.grade r) with
    | Some d, Some c, Some p ->
        OfByLetters.L.show c = D.show d
        && (P.show p = D.show d
           || Option.is_none (P.canonical p)
           || Option.is_none (D.canonical d))
    | None, None, None -> true
    | _ -> false
  in
  [
    all "the implementations by derivatives print alike"
      (fun r ->
        match OfDerivatives.grade r with Some d -> D.show d | None -> "∅")
      alike regexes;
  ]

(* The plain regular trace grades have a run whatever the operations. *)
let plain_inhabited =
  let none = bounds_of [] in
  let lit =
    Grade.Braces (Grade.Inter (Grade.Any, Grade.Compl (Grade.Tick 1)))
  in
  [
    holds "regex-upper-bound: inhabited"
      (Grades.RegularTraceGrade.inhabited none
         (Grades.RegularTraceGrade.of_lit lit));
    holds "regex-upper-bound-symbolic: inhabited"
      (Grades.RegularTraceGradeDerivative.inhabited none
         (Grades.RegularTraceGradeDerivative.of_lit lit));
    holds "regex-upper-bound-derivatives: inhabited"
      (Grades.RegularTraceGradeDerivative.Concrete.inhabited none
         (Grades.RegularTraceGradeDerivative.Concrete.of_lit lit));
    holds "regex-upper-bound-plain: inhabited"
      (Grades.RegularTraceGradePlain.inhabited none
         (Grades.RegularTraceGradePlain.of_lit lit));
  ]

(* {1 (g) Long runs of ticks} *)

(* Cost models with small costs, unit costs, and a large upper cost. *)
let long_tables =
  [
    List.hd tables;
    List.map (fun o -> (o, (1, 1))) names;
    [ ("A", (5, 5000)); ("B", (0, 3)); ("C", (2, 7)) ];
  ]

(* Random expressions shaped as grades over delays of up to [longest] ticks:
   alternatives of sequences of [letters], by default [A] and [B], delays, [_]
   and repetitions of names, ended by [_*] at times, and the intersections of
   such alternatives. The complement of a delay has no run of ticks, every word
   but the delay being in it, so that its closures explore each of its ticks;
   these leave it out. *)
let random_grade ?(letters = [ "A"; "B" ]) ~longest state =
  let pick xs = List.nth xs (Random.State.int state (List.length xs)) in
  let atom () =
    match Random.State.int state 5 with
    | 0 | 1 -> Grade.Tick (Random.State.int state (longest + 1))
    | 2 -> Grade.Letter (pick letters)
    | 3 -> Grade.Any
    | _ -> Grade.Star (Grade.Letter (pick letters))
  in
  let sequence () =
    let atoms = List.init (1 + Random.State.int state 3) (fun _ -> atom ()) in
    let ending =
      if Random.State.int state 3 = 0 then [ Grade.Star Grade.Any ] else []
    in
    match atoms @ ending with
    | r :: rs -> List.fold_left (fun r s -> Grade.Seq (r, s)) r rs
    | [] -> Grade.Tick 0
  in
  let alternatives () =
    Grade.Union
      ( sequence (),
        if Random.State.bool state then sequence () else Grade.Tick 0 )
  in
  if Random.State.int state 4 = 0 then
    Grade.Inter (alternatives (), alternatives ())
  else alternatives ()

(* [printed_length text] is the length of the run of a grade printed as
   [text], a sequence of names and delays: a delay counts as its number of
   ticks. *)
let printed_length text =
  let inner = String.sub text 1 (String.length text - 2) in
  List.fold_left
    (fun n part ->
      n + Option.value (int_of_string_opt (String.trim part)) ~default:1)
    0
    (String.split_on_char ';' inner)

(* The verdicts of the implementation [I] on long delays: under each order,
   whether a grade is below another, whether they are equal, and the length of
   the counterexample. *)
module Long (I : IMPLEMENTATION) = struct
  include I

  let grade r =
    match L.of_lit (Grade.Braces r) with
    | rho -> Some rho
    | exception Grade.Invalid_literal _ -> None

  let verdicts bounds (r, r') =
    match (grade r, grade r') with
    | Some rho, Some rho' ->
        let verdict (module G : Grade.S with type t = L.t) =
          ( G.leq bounds rho rho',
            G.equal bounds rho rho',
            Option.map
              (fun w -> printed_length (L.show w))
              (G.counterexample bounds rho rho') )
        in
        Some
          ( verdict (module Upper),
            verdict (module Lower),
            Interval.leq bounds (rho, rho') (rho', rho) )
    | _ -> None
end

module LongDerivatives = Long (Derivatives)
module LongByLetters = Long (ByLetters)
module LongPlain = Long (Plain)

(* The implementations by derivatives embed the finite trace grades,
   whose delays are numbers, on delays of up to 10⁴ ticks; they agree with each
   other on random grades over delays of up to 300 ticks, in their verdicts and
   the lengths of their counterexamples, and with the automata on delays of up
   to 30 ticks; and they decide long delays within a second. A comparison
   explores every tick of a delay that no run of ticks covers, as one within a
   complement, and a search moves by one tick at a time while one of its pairs
   has a lead of 0, as after a repetition before a delay: these grades keep
   the random delays short. *)
let long_runs =
  let state = Random.State.make [| 47 |] in
  let finite =
    Grade.Top
    :: List.init 16 (fun _ ->
        Grade.Braces (random_regex ~finite:true ~longest:10000 ~depth:3 state))
  in
  let embedding =
    List.concat_map
      (fun (module I : IMPLEMENTATION) ->
        embeds
          (module I.Upper)
          (module I.Lower)
          (module I.Interval)
          long_tables finite)
      [ (module Derivatives); (module ByLetters); (module Plain) ]
  in
  let grades = List.init 14 (fun _ -> random_grade ~longest:300 state) in
  let show_regex r =
    match LongDerivatives.grade r with
    | Some rho -> LongDerivatives.L.show rho
    | None -> "∅"
  in
  let derivatives =
    List.map
      (fun table ->
        let bounds = bounds_of table in
        all "the implementations by derivatives agree on long delays"
          (fun (r, r') ->
            show_regex r ^ ", " ^ show_regex r' ^ " at " ^ show_table table)
          (fun pair ->
            let verdicts = LongDerivatives.verdicts bounds pair in
            LongByLetters.verdicts bounds pair = verdicts
            && LongPlain.verdicts bounds pair = verdicts)
          (pairs grades))
      long_tables
  in
  let moderate =
    List.init 10 (fun i ->
        if i mod 2 = 0 then random_grade ~longest:30 state
        else random_regex ~longest:30 ~depth:3 state)
  in
  let automata =
    List.map
      (fun table ->
        let bounds = bounds_of table in
        all "the implementations agree on delays of up to 30 ticks"
          (fun (r, r') ->
            show_regex r ^ ", " ^ show_regex r' ^ " at " ^ show_table table)
          (fun pair ->
            let verdicts = OfAutomata.verdicts bounds pair in
            OfDerivatives.verdicts bounds pair = verdicts
            && OfByLetters.verdicts bounds pair = verdicts
            && OfPlain.verdicts bounds pair = verdicts)
          (pairs moderate))
      long_tables
  in
  let quickly name decide =
    let start = Sys.time () in
    let holds = decide () in
    let time = Sys.time () -. start in
    check name (holds && time < 1.) (Printf.sprintf "in %.2f s" time)
  in
  let timing (module I : IMPLEMENTATION) =
    let module U = Reader (I.Upper) in
    let module Lo = Reader (I.Lower) in
    let name what = I.name ^ ": " ^ what in
    [
      quickly (name "{9999; A} <= {10000; A} under the upper order") (fun () ->
          I.Upper.leq costs (U.lit "{9999; A}") (U.lit "{10000; A}"));
      quickly (name "{10001; A} </= {10000; A} under the upper order")
        (fun () ->
          not (I.Upper.leq costs (U.lit "{10001; A}") (U.lit "{10000; A}")));
      quickly (name "{A; 10000} <= {10003} under the upper order") (fun () ->
          I.Upper.leq costs (U.lit "{A; 10000}") (U.lit "{10003}"));
      quickly (name "{A; 10000} </= {10002} under the upper order") (fun () ->
          not (I.Upper.leq costs (U.lit "{A; 10000}") (U.lit "{10002}")));
      quickly (name "{10000; A} <= {9999; A} under the lower order") (fun () ->
          I.Lower.leq costs (Lo.lit "{10000; A}") (Lo.lit "{9999; A}"));
      quickly (name "{9999; A} </= {10000; A} under the lower order") (fun () ->
          not (I.Lower.leq costs (Lo.lit "{9999; A}") (Lo.lit "{10000; A}")));
      quickly (name "{10000; A} implies (10001, 10003)") (fun () ->
          I.Upper.implied_bounds costs (U.lit "{10000; A}") = Some (10001, 10003));
      quickly (name "counterexample of {10001; A} <= {10000; A}") (fun () ->
          Option.map I.Upper.show
            (I.Upper.counterexample costs (U.lit "{10001; A}")
               (U.lit "{10000; A}"))
          = Some "{10001; A}");
    ]
  in
  embedding @ derivatives @ automata
  @ List.concat_map timing
      [ (module Derivatives); (module ByLetters); (module Plain) ]

(* {1 (h) Canonical closure states} *)

(* The states of the closures over the runs of the implementation [I], along
   random words, against the explicit sets of the constructions: for the
   allowance, the set of the live states reachable, closed under reachability,
   of which the state holds those not strictly within the run of ticks of
   another; for the coverage, the subset of the states of the runs, of which
   the state holds those on whose run of ticks, end included, no other lies.
   The runs of ticks are followed letter by letter, so that equal explicit
   sets give equal states, and the states denote the same sets. *)
module Canonical (I : IMPLEMENTATION) = struct
  include I
  module States = Set.Make (L.State)
  module Allowance = CostClosure.Allowance (L.State)
  module Coverage = CostClosure.Coverage (L.State)
  module Sets = Map.Make (States)

  let letters = List.length names + 1
  let live (m : _ Dfa.automaton) q = not (m.dead q)

  let reach m s =
    let rec visit seen q =
      if States.mem q seen || not (live m q) then seen
      else
        List.fold_left visit (States.add q seen)
          (List.init letters (m.Dfa.step q))
    in
    States.fold (fun q seen -> visit seen q) s States.empty

  let image m a s = States.map (fun q -> m.Dfa.step q a) s

  (* [run m y] is the successors of [y] by [0ʲ] for [1 ≤ j ≤ k], [k] the lead
     of [y], letter by letter, and none if [y] accepts no word. *)
  let run (m : _ Dfa.automaton) y =
    let rec go j q =
      if j = 0 then []
      else
        let q' = m.step q 0 in
        q' :: go (j - 1) q'
    in
    if m.lead y = Int.max_int then [] else go (m.lead y) y

  let weight cost a = if a = 0 then 1 else cost a

  let allowed ~cost m =
    let rec at_least n s =
      if n = 0 then s
      else
        let s' = reach m (image m 0 s) in
        if States.equal s' s then s else at_least (n - 1) s'
    in
    let final s = if States.exists m.Dfa.accepts s then s else States.empty in
    let step s x =
      final
        (States.union
           (at_least (weight cost x) s)
           (if x = 0 then States.empty else reach m (image m x s)))
    in
    let interior s x =
      States.exists
        (fun y ->
          match List.rev (run m y) with
          | _ :: inner -> List.exists (fun q -> L.State.compare q x = 0) inner
          | [] -> false)
        s
    in
    let represent s = States.filter (fun x -> not (interior s x)) s in
    (final (reach m (States.singleton m.start)), step, represent)

  let covered ~cost m =
    let delays n q =
      let rec go seen j q =
        if j > n || States.mem q seen then seen
        else go (States.add q seen) (j + 1) (m.Dfa.step q 0)
      in
      go States.empty 0 q
    in
    let step s y =
      if States.exists m.Dfa.accepts s then s
      else
        States.fold
          (fun q t ->
            States.union t
              (States.union
                 (delays (weight cost y) q)
                 (if y = 0 then States.empty else States.singleton (m.step q y))))
          s States.empty
    in
    let dominated s y =
      List.exists
        (fun q -> States.mem q s && L.State.compare q y <> 0)
        (run m y)
    in
    let represent s = States.filter (fun y -> not (dominated s y)) s in
    (States.singleton m.start, step, represent)

  (* [walk name closure (start, step, represent) words] follows the [words] in
     the closure and in the explicit construction, checking that each state is
     the representation of the explicit set and that equal sets give equal
     states. *)
  let walk name (closure : L.State.t list Dfa.automaton)
      (start, step, represent) words =
    let wrong = ref 0 and states = ref Sets.empty in
    List.iter
      (fun word ->
        ignore
          (List.fold_left
             (fun (c, e) x ->
               let c = closure.step c x and e = step e x in
               let expected = States.elements (represent e) in
               if List.compare L.State.compare c expected <> 0 then incr wrong;
               (match Sets.find_opt e !states with
               | Some c' when List.compare L.State.compare c c' <> 0 ->
                   incr wrong
               | Some _ -> ()
               | None -> states := Sets.add e c !states);
               (c, e))
             (closure.start, start) word))
      words;
    check name (!wrong = 0) (Printf.sprintf "%d states differ" !wrong)

  let checks tables grades words =
    List.concat_map
      (fun table ->
        let lo = letter_cost table fst and hi = letter_cost table snd in
        List.concat_map
          (fun r ->
            match L.of_lit (Grade.Braces r) with
            | exception Grade.Invalid_literal _ -> []
            | rho ->
                let m = L.runs names rho in
                let name what =
                  Printf.sprintf "%s: canonical %s states of %s at %s" I.name
                    what (L.show rho) (show_table table)
                in
                [
                  walk (name "allowance")
                    (Allowance.closure ~cost:hi ~letters m)
                    (allowed ~cost:hi m) words;
                  walk (name "coverage")
                    (Coverage.closure ~cost:lo m)
                    (covered ~cost:lo m) words;
                ])
          grades)
      tables
end

let canonical =
  let state = Random.State.make [| 59 |] in
  let grades =
    List.init 12 (fun i ->
        if i mod 3 = 0 then random_regex ~longest:40 ~depth:3 state
        else random_grade ~longest:40 state)
  in
  let words =
    List.init 30 (fun _ ->
        List.init (Random.State.int state 150) (fun _ ->
            if Random.State.int state 4 > 0 then 0
            else 1 + Random.State.int state 3))
  in
  let tables =
    [ List.hd tables; [ ("A", (5, 50)); ("B", (0, 3)); ("C", (2, 7)) ] ]
  in
  let module D = Canonical (Derivatives) in
  let module B = Canonical (ByLetters) in
  let module P = Canonical (Plain) in
  D.checks tables grades words
  @ B.checks tables grades words
  @ P.checks tables grades words

(* {1 (i) Many operations sharing costs} *)

(* Cost models of [3 … 40] operations [Op01], [Op02], …, each of one of two or
   three pairs of runtime bounds, with random lower ends in [0 … 2] and upper
   ends up to three more. *)
let shared_tables =
  let state = Random.State.make [| 67 |] in
  List.init 10 (fun _ ->
      let classes =
        List.init
          (2 + Random.State.int state 2)
          (fun _ ->
            let lo = Random.State.int state 3 in
            (lo, lo + Random.State.int state 4))
      in
      List.init
        (3 + Random.State.int state 38)
        (fun i ->
          ( Printf.sprintf "Op%02d" (i + 1),
            List.nth classes (Random.State.int state (List.length classes)) )))

(* Random expressions of depth [depth] over up to four operations of [table],
   delays of up to [longest] ticks, [_] and unions of two operations, the other
   operations being left to the catch-all letter. *)
let random_shared ~longest ~depth table state =
  let pick xs = List.nth xs (Random.State.int state (List.length xs)) in
  let mentioned = List.init 4 (fun _ -> fst (pick table)) in
  let letter () = Grade.Letter (pick mentioned) in
  let atom () =
    match Random.State.int state 6 with
    | 0 | 1 -> letter ()
    | 2 -> Grade.Tick (Random.State.int state (longest + 1))
    | 3 -> Grade.Tick 1
    | 4 -> Grade.Union (letter (), letter ())
    | _ -> Grade.Any
  in
  let rec go depth =
    if depth = 0 then atom ()
    else
      match Random.State.int state 9 with
      | 0 | 1 -> atom ()
      | 2 | 3 -> Grade.Seq (go (depth - 1), go (depth - 1))
      | 4 | 5 -> Grade.Union (go (depth - 1), go (depth - 1))
      | 6 -> Grade.Inter (go (depth - 1), go (depth - 1))
      | 7 -> Grade.Star (go (depth - 1))
      | _ -> Grade.Compl (go (depth - 1))
  in
  go depth

(* The verdicts of the implementation [I] over the operations of a cost model:
   under each order, whether a grade is below another, whether they are equal,
   and the word of the counterexample over the operations, with whether it is a
   run of the lesser grade outside the closure of the greater; and the runtime
   bounds implied by the grades and their inhabitation. *)
module Shared (I : IMPLEMENTATION) = struct
  include I

  let grade r =
    match L.of_lit (Grade.Braces r) with
    | rho -> Some rho
    | exception Grade.Invalid_literal _ -> None

  (* [word names rho] is the shortest run of [rho] over [names], its ticks
     written [τ]. *)
  let word names rho =
    Option.map
      (List.map (fun a -> if a = 0 then "τ" else List.nth names (a - 1)))
      (Dfa.counterexample (L.concrete names rho)
         (Dfa.empty (List.length names + 1)))

  let verdicts table (r, r') =
    let bounds = bounds_of table and names = List.map fst table in
    match (grade r, grade r') with
    | Some rho, Some rho' ->
        let verdict (type a) (module G : Grade.S with type t = a) words x y =
          ( G.leq bounds x y,
            G.equal bounds x y,
            Option.map
              (fun e -> (words e, G.leq bounds e x && not (G.leq bounds e y)))
              (G.counterexample bounds x y) )
        in
        let single rho = [ word names rho ] in
        let pair (lo, hi) = [ word names lo; word names hi ] in
        Some
          ( [
              verdict (module Upper) single rho rho';
              verdict (module Lower) single rho rho';
              verdict (module Interval) pair (rho, rho') (rho', rho);
            ],
            [
              Upper.implied_bounds bounds rho;
              Lower.implied_bounds bounds rho;
              Interval.implied_bounds bounds (rho, rho');
            ],
            [ Upper.inhabited bounds rho; Lower.inhabited bounds rho ] )
    | _ -> None
end

module SharedAutomata = Shared (Automata)
module SharedDerivatives = Shared (Derivatives)
module SharedByLetters = Shared (ByLetters)
module SharedPlain = Shared (Plain)

(* The implementations agree over cost models of many operations sharing
   costs, most of them left to the catch-all letter, in their verdicts, their
   counterexamples, which are runs of the declared operations, and their
   runtime bounds: on random grades against the automata, and with each other
   on grades over delays of up to 120 ticks. *)
let shared =
  let state = Random.State.make [| 71 |] in
  let show_table table =
    Printf.sprintf "%d operations, %s" (List.length table)
      (String.concat ", "
         (List.sort_uniq compare
            (List.map
               (fun (_, (lo, hi)) -> Printf.sprintf "(%d,%d)" lo hi)
               table)))
  in
  let show_regex r =
    match SharedDerivatives.grade r with
    | Some rho -> SharedDerivatives.L.show rho
    | None -> "∅"
  in
  let sound = function
    | Some (orders, _, _) ->
        List.for_all
          (fun (_, _, found) ->
            match found with Some (_, valid) -> valid | None -> true)
          orders
    | None -> true
  in
  let agree name ~automata ~count random =
    List.map
      (fun table ->
        let grades = List.init count (fun _ -> random table) in
        all name
          (fun (r, r') ->
            show_regex r ^ ", " ^ show_regex r' ^ " at " ^ show_table table)
          (fun pair ->
            let verdicts = SharedDerivatives.verdicts table pair in
            sound verdicts
            && ((not automata) || SharedAutomata.verdicts table pair = verdicts)
            && SharedByLetters.verdicts table pair = verdicts
            && SharedPlain.verdicts table pair = verdicts)
          (pairs grades))
      shared_tables
  in
  let long table =
    let pick () =
      fst (List.nth table (Random.State.int state (List.length table)))
    in
    random_grade ~letters:[ pick (); pick () ] ~longest:120 state
  in
  let random table = random_shared ~longest:3 ~depth:4 table state in
  let agreement =
    agree "many operations sharing costs: the implementations agree"
      ~automata:true ~count:12 random
  in
  agreement
  @ agree "many operations sharing costs: agreement on long delays"
      ~automata:false ~count:5 long

let () =
  let checks =
    segments @ OfAutomata.checks @ OfDerivatives.checks @ OfByLetters.checks
    @ OfPlain.checks @ agreement @ printing @ plain_inhabited @ long_runs
    @ canonical @ shared
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
