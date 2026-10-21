(* Unit and property tests of the event-separation grade: the laws on random
   terms over the operations [A], [B] and [C] under random running-time
   bounds; the summaries of random concrete computations of a term against its
   evaluation, computed directly from the computation; the acceptance of a
   concrete computation by a specification against its gaps; the reading back
   of printed grades; and the literals, the loop invariants, the durations, the
   inhabitation and the counterexamples on examples. *)

module Grade = Grades.Grade
module Rational = Grades.Rational
module I = Grades.DurationIntervals
module E = Grades.EventSeparationGrades
module Indexed = Grades.GradeConstructions.Indexed
open LawChecks

let q = Rational.make
let names = [ "A"; "B"; "C" ]

(* The running times [table] of the operations, by name. *)
let bounds_of table =
  {
    Grade.running_time = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

let closed a b = (Grade.Closed a, Grade.Closed b)

(* Random rationals with denominators of at most 4, below 6. *)
let random_rational st = q (Random.State.int st 24) (1 + Random.State.int st 4)

(* A random non-empty interval, each end open or closed, the upper end
   infinite if [unbounded]. *)
let random_interval ?(unbounded = false) ?(positive = false) st =
  let a = random_rational st in
  let b = Rational.add a (random_rational st) in
  let b = if positive && Rational.sign b = 0 then Rational.of_int 1 else b in
  let lo = if Random.State.int st 3 = 0 then Grade.Open a else Grade.Closed a in
  let hi =
    if unbounded && Random.State.int st 4 = 0 then Grade.Unbounded
    else if Random.State.int st 3 = 0 then Grade.Open b
    else Grade.Closed b
  in
  match Grade.emptiness lo hi with None -> (lo, hi) | Some _ -> closed a b

(* Random running-time bounds of [A], [B] and [C], with positive upper ends. *)
let random_bounds st =
  bounds_of (List.map (fun o -> (o, random_interval ~positive:true st)) names)

(* A random specification of one or two names, each entry of a form with or
   without a count, with a total duration or none; an entry of count [0]
   without silent durations is drawn again. *)
let rec random_specification st =
  let interval () =
    let lo, hi = random_interval ~unbounded:true st in
    Grade.Interval
      (Grade.map_end Grade.rational_lit lo, Grade.map_end Grade.rational_lit hi)
  in
  let count () =
    let n = Random.State.int st 4 in
    match Random.State.int st 3 with
    | 0 -> Grade.Int n
    | 1 -> Grade.Interval (Grade.Closed (Grade.Int n), Grade.Unbounded)
    | _ ->
        Grade.Interval
          ( Grade.Closed (Grade.Int n),
            Grade.Closed (Grade.Int (n + Random.State.int st 3)) )
  in
  let entry name =
    Grade.Tuple
      (match Random.State.int st 5 with
      | 0 -> [ Grade.Name name; interval () ]
      | 1 -> [ Grade.Name name; interval (); interval (); interval () ]
      | 2 -> [ count (); Grade.Name name; interval () ]
      | 3 -> [ count (); Grade.Name name; interval (); interval () ]
      | _ ->
          [ count (); Grade.Name name; interval (); interval (); interval () ])
  in
  let entries =
    List.map entry (List.filter (fun _ -> Random.State.bool st) names)
  in
  let entries = if entries = [] then [ entry "A" ] else entries in
  match
    E.of_lit
      (match entries with
      | [ entry ] when Random.State.bool st -> entry
      | entries ->
          Grade.Tuple
            (entries @ if Random.State.bool st then [] else [ interval () ]))
  with
  | c -> c
  | exception Grade.Invalid_literal _ -> random_specification st

(* A random term of depth at most [depth], with specifications if [specs]. *)
let rec random_term ~specs st depth =
  match Random.State.int st (if depth = 0 then 3 else 6) with
  | 0 ->
      E.of_lit
        (Grade.Braces (Grade.Letter (List.nth names (Random.State.int st 3))))
  | 1 ->
      if Random.State.bool st then E.of_delay (random_rational st)
      else
        let lo, hi = random_interval ~unbounded:true st in
        E.of_lit (Grade.Braces (Grade.Delays (lo, hi)))
  | 2 when specs -> random_specification st
  | 2 -> E.of_delay (random_rational st)
  | 3 | 4 ->
      E.mul
        (random_term ~specs st (depth - 1))
        (random_term ~specs st (depth - 1))
  | _ ->
      E.join
        (random_term ~specs st (depth - 1))
        (random_term ~specs st (depth - 1))

(* {1 Laws} *)

let laws =
  let st = Random.State.make [| 7 |] in
  List.concat_map
    (fun round ->
      let bounds = random_bounds st in
      let context =
        String.concat ", "
          (List.map
             (fun o ->
               let lo, hi = bounds.running_time o in
               o ^ ":" ^ Grade.show_interval Rational.show lo hi)
             names)
        ^ Printf.sprintf " (round %d)" round
      in
      let samples =
        [ E.one; E.top ] @ List.init 16 (fun _ -> random_term ~specs:true st 3)
      in
      order_laws ~thirds:10 (module E) ~context bounds samples
      @ algebra_laws ~width:10 (module E) ~context bounds samples
      @ declared_laws (module E) ~context bounds samples
      @ counterexample_laws (module E) ~offered:true ~context bounds samples
      @ of_delay_laws (module E) bounds ()
      @ of_bounds_laws (module E) bounds)
    (List.init 6 Fun.id)

(* {1 Concrete computations} *)

(* A step of a concrete computation: an occurrence of an operation taking a
   duration, or a delay. *)
type step = Occurrence of string * Rational.t | Wait of Rational.t

(* [member x i] is whether [x ∈ i]. *)
let member x (lo, hi) =
  (match lo with
    | Grade.Closed a -> Rational.compare a x <= 0
    | Grade.Open a -> Rational.compare a x < 0
    | Grade.Unbounded -> true)
  &&
  match hi with
  | Grade.Closed b -> Rational.compare x b <= 0
  | Grade.Open b -> Rational.compare x b < 0
  | Grade.Unbounded -> true

(* A random point of the non-empty interval [i]. *)
let random_point st ((lo, hi) as i) =
  let value = function
    | Grade.Closed a | Grade.Open a -> Some a
    | Grade.Unbounded -> None
  in
  let a = Option.get (value lo) in
  let b =
    Option.value (value hi) ~default:(Rational.add a (random_rational st))
  in
  let mid = Rational.div (Rational.add a b) (Rational.of_int 2) in
  let candidates =
    List.filter (fun x -> member x i) [ a; b; mid; Rational.add a (q 1 7) ]
  in
  List.nth candidates (Random.State.int st (List.length candidates))

(* [concrete bounds st c] is a random computation of the term [c] without
   specifications under the running times [bounds]. *)
let rec concrete (bounds : Grade.bounds) st c =
  match E.Terms.view c with
  | E.Terms.Op (name, ()) ->
      [ Occurrence (name, random_point st (bounds.running_time name)) ]
  | E.Terms.Delays i -> [ Wait (random_point st i) ]
  | E.Terms.Fixed _ -> invalid_arg "concrete: a specification"
  | E.Terms.Mul cs -> List.concat_map (concrete bounds st) cs
  | E.Terms.Join cs ->
      concrete bounds st (List.nth cs (Random.State.int st (List.length cs)))

let duration = function Occurrence (_, d) | Wait d -> d

(* The summary of the name [name] in the computation [steps], directly: the
   total duration, and [None] if silent, or the count, the lead, the gaps and
   the tail. *)
let observe name steps =
  let total, starts =
    List.fold_left
      (fun (t, starts) step ->
        ( Rational.add t (duration step),
          match step with
          | Occurrence (o, _) when String.equal o name -> t :: starts
          | Occurrence _ | Wait _ -> starts ))
      (Rational.zero, []) steps
  in
  match List.rev starts with
  | [] -> (total, None)
  | first :: _ as starts ->
      let rec gaps = function
        | s :: (s' :: _ as rest) -> Rational.sub s' s :: gaps rest
        | [ _ ] | [] -> []
      in
      let last = List.hd (List.rev starts) in
      ( total,
        Some (List.length starts, first, gaps starts, Rational.sub total last)
      )

(* Whether the summary of [name] in [steps] lies within the entry [e] and
   [total]. *)
let within name steps (e : E.Summary.entry) total =
  let d, active = observe name steps in
  member d total
  &&
  match (active, e) with
  | None, { silent = Some i; _ } -> member d i
  | None, { silent = None; _ } -> false
  | Some (k, a, gaps, b), { active = Some x; _ } -> (
      x.count.least <= k
      && Option.fold ~none:true ~some:(fun m -> k <= m) x.count.most
      && member a x.lead && member b x.tail
      &&
      match (gaps, x.gaps) with
      | [], _ -> true
      | _ :: _, None -> false
      | gaps, Some g -> List.for_all (fun gap -> member gap g) gaps)
  | Some _, { active = None; _ } -> false

let show_steps steps =
  String.concat "; "
    (List.map
       (function
         | Occurrence (o, d) -> o ^ "@" ^ Rational.show d
         | Wait d -> Rational.show d)
       steps)

(* Every random computation of a random term lies within its evaluation, at
   [A], [B], [C] and a name it does not mention. *)
let oracle =
  let st = Random.State.make [| 13 |] in
  List.init 300 (fun _ ->
      let bounds = random_bounds st in
      let c = random_term ~specs:false st 4 in
      let s = E.Terms.evaluate bounds c in
      let steps = concrete bounds st c in
      check "event-separation: a computation lies within its evaluation"
        (List.for_all
           (fun name -> within name steps (Indexed.at s.entries name) s.total)
           ("D" :: names))
        (E.show c ^ " by " ^ show_steps steps))

(* Under exact running times, the term of a concrete computation is below a
   specification iff the counts, gaps, leads, tails, silent durations and the
   total duration of the computation satisfy it. *)
let exact_specifications =
  let st = Random.State.make [| 17 |] in
  let table =
    [
      ("A", closed (q 1 2) (q 1 2));
      ("B", closed (q 1 1) (q 1 1));
      ("C", closed (q 3 2) (q 3 2));
    ]
  in
  let bounds = bounds_of table in
  let cases =
    List.init 400 (fun _ ->
        let c = random_term ~specs:false st 4 in
        let steps = concrete bounds st c in
        let term =
          List.fold_left
            (fun t -> function
              | Occurrence (o, _) ->
                  E.mul t (E.of_lit (Grade.Braces (Grade.Letter o)))
              | Wait d -> E.mul t (E.of_delay d))
            E.one steps
        in
        let spec = random_specification st in
        let s = E.Terms.evaluate bounds spec in
        ( spec,
          steps,
          E.leq bounds term spec,
          List.for_all
            (fun name -> within name steps (Indexed.at s.entries name) s.total)
            ("D" :: names) ))
  in
  check "event-separation: specifications accept and reject computations"
    (List.exists (fun (_, _, _, e) -> e) cases
    && List.exists (fun (_, _, _, e) -> not e) cases)
    ""
  :: List.map
       (fun (spec, steps, verdict, expected) ->
         check "event-separation: a specification accepts exactly by the gaps"
           (verdict = expected)
           (E.show spec ^ " on " ^ show_steps steps))
       cases

(* {1 Printing} *)

(* [Reader] reads the literals of the grade by the parser, in the grade
   position of a box. *)
module Reader = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (E))

  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        Ok rho
    | _ -> Error "not a box of a literal"
    | exception Grammar.Error -> Error "parser error"
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message
end

(* A random grade of one literal: a brace literal, a delay, an interval or a
   specification. *)
let random_literal_grade st =
  match Random.State.int st 3 with
  | 0 -> random_term ~specs:false st 3
  | 1 ->
      let lo, hi = random_interval ~unbounded:true st in
      E.of_lit
        (Grade.Interval
           ( Grade.map_end Grade.rational_lit lo,
             Grade.map_end Grade.rational_lit hi ))
  | _ -> random_specification st

let read_back =
  let st = Random.State.make [| 19 |] in
  List.init 300 (fun _ ->
      let c = random_literal_grade st in
      check "event-separation: a printed literal reads back"
        (match Reader.parse (E.show c) with
        | Ok c' -> E.compare c c' = 0
        | Error _ -> false)
        (E.show c))

(* {1 Examples} *)

let bounds =
  bounds_of
    [
      ("Beat", closed (q 1 10) (q 1 2));
      ("Work", closed (q 1 1) (q 3 1));
      ("Beep", closed (q 1 10) (q 1 2));
    ]

(* [parse text] is the grade of the text [text], factors separated by [·]
   multiplied. *)
let parse text =
  let read text =
    match Reader.parse text with
    | Ok c -> c
    | Error reason -> failwith (text ^ ": " ^ reason)
  in
  let rec factors i =
    match String.index_from_opt text i '\xc2' with
    | Some j when j + 1 < String.length text && text.[j + 1] = '\xb7' ->
        String.sub text i (j - i) :: factors (j + 2)
    | Some _ | None -> [ String.sub text i (String.length text - i) ]
  in
  List.fold_left
    (fun c factor -> E.mul c (read (String.trim factor)))
    E.one (factors 0)

let holds name text text' =
  check
    ("event-separation: " ^ name)
    (E.leq bounds (parse text) (parse text'))
    (text ^ " <= " ^ text')

let fails name text text' =
  check
    ("event-separation: " ^ name)
    (not (E.leq bounds (parse text) (parse text')))
    (text ^ " not <= " ^ text')

let rejected name text fragment =
  match Reader.parse text with
  | Ok c -> check ("event-separation: " ^ name) false ("read as " ^ E.show c)
  | Error reason ->
      let n = String.length reason and k = String.length fragment in
      let rec from i =
        i + k <= n && (String.sub reason i k = fragment || from (i + 1))
      in
      check ("event-separation: " ^ name) (from 0) reason

let vacuous name text expected =
  expect
    ("event-separation: " ^ name)
    Fun.id ~expected
    (Option.value ~default:"none" (E.vacuous bounds (parse text)))

let inhabited name text =
  check ("event-separation: " ^ name) (E.inhabited bounds (parse text)) text

let invariant = "(Beat, [0, 0], [0, 5], [0, 5])"
let short = "(Beat, [0, 5])"

let examples =
  [
    check "event-separation: the invariant squared below it"
      (E.leq bounds
         (E.mul (parse invariant) (parse invariant))
         (parse invariant))
      invariant;
    check "event-separation: the short form not closed under sequencing"
      (not (E.leq bounds (E.mul (parse short) (parse short)) (parse short)))
      short;
    holds "a body within the invariant" "{Beat; Work}" invariant;
    check "event-separation: a fast body keeps the invariant"
      (E.leq bounds
         (E.mul (parse "{Beat; Work}") (parse invariant))
         (parse invariant))
      "{Beat; Work}";
    check "event-separation: a slow body breaks the invariant"
      (not
         (E.leq bounds
            (E.mul (parse "{Beat; Work; Work}") (parse invariant))
            (parse invariant)))
      "{Beat; Work; Work}";
    check "event-separation: a short form fails as an invariant"
      (not
         (E.leq bounds
            (E.mul (parse "{Beat; Work}") (parse short))
            (parse short)))
      short;
    holds "the unit within the invariant" "0" invariant;
    holds "the unit within a lead of 0" "0" "(Beep, 0, [2, ∞), [0, ∞))";
    fails "a delay beyond a lead of 0" "1" "(Beep, 0, [2, ∞), [0, ∞))";
    holds "a rate limit kept" "{Beep; 2} · (Beep, [2, ∞))" "(Beep, [2, ∞))";
    fails "a rate limit broken" "{Beep; 1} · (Beep, [2, ∞))" "(Beep, [2, ∞))";
    holds "names not mentioned unconstrained" "{Work; Beep; Work}"
      "(Beat, [0, 10])";
    fails "a name not mentioned is silent in a term" "(Beat, [0, 10])" "{Work}";
    holds "a total duration" "{Beat; 2}" "((Beat, [0, 10]), [2, 3])";
    fails "a total duration exceeded" "{Beat; 3}" "((Beat, [0, 10]), [2, 3])";
    rejected "an entry of the others" "((Beat, [0, 1]), (_, [0, 5]))"
      "the others being unconstrained";
    holds "exactly two beeps" "{1; Beep; 2; Beep}"
      "(2, Beep, [1, 3], [2, 3], [0, 1])";
    fails "one beep for exactly two" "{1; Beep}"
      "(2, Beep, [1, 3], [2, 3], [0, 1])";
    fails "three beeps for exactly two" "{1; Beep; 2; Beep; 2; Beep}"
      "(2, Beep, [1, 3], [2, 3], [0, 1])";
    holds "exactly one with a lead and a tail" "{Beat; 1; Beep}"
      "(1, Beep, [1, 2], [0, 0.5])";
    fails "a late single beep" "{Beat; 3; Beep}" "(1, Beep, [1, 2], [0, 0.5])";
    holds "the single reading of the indirect form"
      "(1, Beep, [1, 2], [0, 0.5])" "(Beep, [1, 2], [0, 0], [0, 0.5])";
    holds "the indirect form within the count" "{Beat; 1; Beep}"
      "(Beep, [1, 2], [0, 0], [0, 0.5])";
    holds "a count interval" "{Beep; 1; Beep}" "([1, 3], Beep, [0, 2])";
    fails "a count interval exceeded" "{Beep; Beep; Beep; Beep}"
      "([1, 3], Beep, [0, 2])";
    holds "no occurrence" "{Beat; 2}" "(0, Beep, [0, ∞))";
    fails "an occurrence for none" "{Beep}" "(0, Beep, [0, ∞))";
    holds "a count added up to an unbounded one"
      "{Beep} · ([1, ∞), Beep, [0, ∞))" "([2, ∞), Beep, [0, ∞))";
    fails "a count added beyond an unbounded one"
      "{Beep} · ([1, ∞), Beep, [0, ∞))" "([3, ∞), Beep, [0, ∞))";
    rejected "a count of 0 without silent durations" "(0, Beep, [0, 0], [1, 1])"
      "admits no computation";
    fails "counts add under sequencing"
      "(1, Beep, [0, 1], [0, 1]) · (1, Beep, [0, 1], [0, 1])"
      "(1, Beep, [0, 1], [0, 2])";
    check "event-separation: too many occurrences are not inhabited"
      (not
         (E.inhabited bounds
            (parse "((3, Beep, [0, 1], [1, 2], [0, 1]), [0, 1])")))
      "";
    rejected "a count without an interval" "(2, Beep)" "lists one interval";
    rejected "a negative count" "(-1, Beep, [0, 1])" "non-negative";
    rejected "a fractional count" "(1.5, Beep, [0, 1])" "natural numbers";
    rejected "a count of six components" "(1, Beep, 0, 1, 2, 3)"
      "lists one interval";
    expect "event-separation: printing a count" Fun.id
      ~expected:"((1, Beep, [1, 2], [0, 0.5]), ([2, 3], Work, [0, 5]), [0, 20])"
      (E.show
         (parse "((1, Beep, [1, 2], [0, 0.5]), ([2, 3], Work, [0, 5]), [0, 20])"));
    expect "event-separation: printing an unbounded count" Fun.id
      ~expected:"([2, ∞), Beep, [0, 1], [1, 2], [0, 1])"
      (E.show (parse "([2, ∞), Beep, [0, 1], [1, 2], [0, 1])"));
    expect "event-separation: an unconstrained count not printed" Fun.id
      ~expected:"(Beep, [0, 2])"
      (E.show (parse "([0, ∞), Beep, [0, 2])"));
    expect "event-separation: the durations of a sequence" Fun.id
      ~expected:"[3.1, 5.5]"
      (Option.fold ~none:"none" ~some:I.show
         (E.duration_bounds bounds (parse "{Beat; Work; 2}")));
    check "event-separation: contradictory components are not inhabited"
      (not
         (E.inhabited bounds (parse "((Beat, [0, 0], [1, 2], [3, 4]), [0, 1])")))
      "";
    check "event-separation: a specification is inhabited"
      (E.inhabited bounds (parse "((Beat, [0, 5]), [10, 20])"))
      "";
    vacuous "entries forcing different totals"
      "((1, Beat, [10, 10], [1, 1]), (1, Beep, [0, 0], [1, 1]))"
      "admits no run: the entries of `Beat` and `Beep` admit no common total \
       duration in [0, ∞)";
    vacuous "totals between those of the counts"
      "(([1, 2], Beat, [0, 0], [10, 10], [1, 1]), [4, 6])"
      "admits no run: the entry of `Beat` admits no total duration in [4, 6]";
    vacuous "gaps below the running time" "(2, Work, [0, 0.01])"
      "admits no run: the entry of `Work` admits no total duration in [0, ∞)";
    vacuous "a tail below the running time" "(1, Work, [0, 1], [0, 0.5])"
      "admits no run: the entry of `Work` admits no total duration in [0, ∞)";
    vacuous "three entries without a common total"
      "(([1, 2], Beat, [0, 0], [10, 10], [1, 1]), (1, Beep, [0, 5], [1, 1]), \
       (1, Work, [4, 8], [1, 3]), [0, 20])"
      "admits no run: its entries admit no common total duration in [0, 20]";
    vacuous "totals beyond the greatest count"
      "(([2, 3], Beat, [0, 0], [1, 2], [1, 1]), (5, 6])"
      "admits no run: the entry of `Beat` admits no total duration in (5, 6]";
    inhabited "a total at the greatest count"
      "(([2, 3], Beat, [0, 0], [1, 2], [1, 1]), [5, 6])";
    vacuous "a total between two counts of fixed gaps"
      "(([2, 3], Beat, [0, 0], [2, 2], [1, 1]), [4, 4])"
      "admits no run: the entry of `Beat` admits no total duration in [4, 4]";
    inhabited "a large count of fixed gaps"
      "(([1, 100000], Beat, [0, 0], [1, 1], [1, 1]), [99999, 99999])";
    vacuous "beyond a large count of fixed gaps"
      "(([1, 100000], Beat, [0, 0], [1, 1], [1, 1]), [100000.5, 100001])"
      "admits no run: the entry of `Beat` admits no total duration in \
       [100000.5, 100001]";
    inhabited "an unbounded count reaching a total"
      "(([1, ∞), Beat, [0, 0], [10, 10], [1, 1]), [101, 101])";
    inhabited "a tail at the running time" "(1, Work, [0, 1], [1, 2])";
    inhabited "entries meeting a common total"
      "((1, Beat, [0, 3], [1, 1]), (1, Beep, [1, 3], [1, 1]), [3, 4])";
    inhabited "names interleaved at once, over-approximated"
      "((1, Beat, [0, 0], [1, 1]), (1, Beep, [0, 0], [1, 1]))";
    check "event-separation: an occurrence is atomic"
      (E.is_atomic "Beat" (parse "{Beat}")
      && not (E.is_atomic "Beat" (parse "{Beat; 1}")))
      "";
    expect "event-separation: events" (String.concat ", ")
      ~expected:[ "Beat"; "Beep"; "Work" ]
      (E.events (parse "{Beat; Work} · ((Beep, [0, 1]), [0, 9])"));
    expect "event-separation: printing a product" Fun.id
      ~expected:"{Beat; 2} · (Beat, [0, 0], [0, 5], [0, 5])"
      (E.show (E.mul (parse "{Beat; 2}") (parse invariant)));
    expect "event-separation: the counterexample of a slow body" Fun.id
      ~expected:
        "⟨Beat: active ([0, 0], [0, 6.5], [0, 6.5]); Work: active ([2, ∞), \
         [0.1, 0.5], [0, ∞), [0, ∞)); _: silent [2.1, ∞), active ([2.1, ∞), \
         [0, ∞), [0, ∞)); total [2.1, ∞)⟩"
      (Option.fold ~none:"none" ~some:E.show
         (E.counterexample bounds
            (E.mul (parse "{Beat; Work; Work}") (parse invariant))
            (parse invariant)));
    rejected "a repetition" "{Beat*}" "without `*`";
    holds "a finite count is its unrolling" "{(1; Beep)^2}" "{1; Beep; 1; Beep}";
    holds "an unrolling is a finite count" "{1; Beep; 1; Beep}" "{(1; Beep)^2}";
    rejected "an unbounded count" "{Beat^[1, ∞)}" "without `*`, `^[m, ∞)`";
    rejected "an empty interval" "(Beat, [3, 2])" "n <= m";
    rejected "two totals" "((Beat, [0, 1]), [0, 1], [0, 2])"
      "at most one interval";
    rejected "an entry of three components" "(Beat, 1, 2)" "lists one interval";
    rejected "a bare name" "Beat" "written `{Beat}`";
    rejected "a name listed twice" "((Beat, [0, 1]), (Beat, [0, 2]))"
      "listed twice";
    (match
       E.of_lit
         (Grade.Braces (Grade.Seq (Grade.Letter "Beat", Grade.Tick (-1))))
     with
    | c -> check "event-separation: a negative delay" false (E.show c)
    | exception Grade.Invalid_literal (_, reason) ->
        check "event-separation: a negative delay"
          (reason = "delays are non-negative, not -1")
          reason);
  ]

let () =
  let checks = laws @ oracle @ exact_specifications @ read_back @ examples in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
