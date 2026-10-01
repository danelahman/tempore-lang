(* Unit tests of the four implementations of the regular trace grade, by
   automata, by symbolic derivatives, by derivatives by letters and by
   derivatives over single letters: their constructions, canonical or normal
   forms, inclusion with counterexamples, alphabet alignment, laws on samples,
   and the reading and printing of their literals, checked against a direct
   matcher of regular expressions and against the parser; and the agreement of
   the implementations on random expressions, on which equal grades have equal
   canonical automata and print alike unless the printing of one of them falls
   back to its normal form; the time and size of the printing, bounded by the
   size of the normal form; and long runs of ticks, taken at once by the
   derivatives. *)

module Grade = Grades.Grade
module SugaredAst = SugaredAst

type implementation = Automata | Symbolic | Concrete | Plain
type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let bounds =
  {
    Grade.cost =
      (fun _ ->
        Grades.Rational.(Grade.Closed (of_int 1), Grade.Closed (of_int 2)));
    operations = [];
  }

let show_bool = string_of_bool
let show_names names = "[" ^ String.concat "; " names ^ "]"

(* [contains s sub] is whether [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

(* Random regular expressions of depth [depth] over the names [names], the
   delays of up to [longest] ticks, [2] by default. *)
let random_regex ?(longest = 2) ~names ~depth state =
  let count = List.length names in
  let atom () =
    match Random.State.int state (count + 3) with
    | i when i < count -> Grade.Letter (List.nth names i)
    | i when i = count -> Grade.Tick (Random.State.int state (longest + 1))
    | i when i = count + 1 -> Grade.Any
    | _ -> Grade.Tick 1
  in
  let rec go depth =
    if depth = 0 then atom ()
    else
      match Random.State.int state 9 with
      | 0 | 1 -> atom ()
      | 2 | 3 -> Grade.Seq (go (depth - 1), go (depth - 1))
      | 4 -> Grade.Union (go (depth - 1), go (depth - 1))
      | 5 -> Grade.Inter (go (depth - 1), go (depth - 1))
      | 6 -> Grade.Star (go (depth - 1))
      | 7 -> Grade.Compl (go (depth - 1))
      | _ -> Grade.Union (go (depth - 1), atom ())
  in
  go depth

(* Random expressions shaped as grades over long delays, of up to [longest]
   ticks: alternatives of sequences of names, delays, [_] and repetitions of
   names, ended by [_*] or [1*] at times, and the intersections and
   complements of such alternatives. A delay after a repetition that can
   repeat a tick, or within a complement within a sequence, gives unions of
   the delays shortened by each number of ticks, which these leave out. *)
let random_grade ~longest ~names state =
  let pick xs = List.nth xs (Random.State.int state (List.length xs)) in
  let atom () =
    match Random.State.int state 5 with
    | 0 | 1 -> Grade.Tick (Random.State.int state (longest + 1))
    | 2 -> Grade.Letter (pick names)
    | 3 -> Grade.Any
    | _ -> Grade.Star (Grade.Letter (pick names))
  in
  let sequence () =
    let atoms = List.init (1 + Random.State.int state 4) (fun _ -> atom ()) in
    let ending =
      match Random.State.int state 4 with
      | 0 -> [ Grade.Star Grade.Any ]
      | 1 -> [ Grade.Star (Grade.Tick 1) ]
      | _ -> []
    in
    match atoms @ ending with
    | r :: rs -> List.fold_left (fun r s -> Grade.Seq (r, s)) r rs
    | [] -> Grade.Tick 0
  in
  let alternatives () =
    let r = sequence () in
    List.fold_left
      (fun r s -> Grade.Union (r, s))
      r
      (List.init (Random.State.int state 3) (fun _ -> sequence ()))
  in
  match Random.State.int state 5 with
  | 0 -> Grade.Inter (alternatives (), alternatives ())
  | 1 -> Grade.Compl (alternatives ())
  | _ -> alternatives ()

(* Random expressions over the names [A], [B] and [C]. *)
let samples =
  let state = Random.State.make [| 2024 |] in
  List.init 300 (fun _ -> random_regex ~names:[ "A"; "B"; "C" ] ~depth:4 state)

type symbol = T | Op of string

let splits w =
  List.init
    (List.length w + 1)
    (fun i ->
      (List.filteri (fun j _ -> j < i) w, List.filteri (fun j _ -> j >= i) w))

(* [matches r w] decides the membership of the word [w] in [r] directly. *)
let rec matches r w =
  match r with
  | Grade.Letter name -> w = [ Op name ]
  | Grade.Tick n -> w = List.init n (fun _ -> T)
  | Grade.Frac _ -> false
  | Grade.Delays (lo, hi) ->
      let n = Grades.Rational.of_int (List.length w) in
      let above = function
        | Grade.Closed a -> Grades.Rational.compare a n <= 0
        | Grade.Open a -> Grades.Rational.compare a n < 0
        | Grade.Unbounded -> true
      and below = function
        | Grade.Closed b -> Grades.Rational.compare n b <= 0
        | Grade.Open b -> Grades.Rational.compare n b < 0
        | Grade.Unbounded -> true
      in
      List.for_all (( = ) T) w && above lo && below hi
  | Grade.Any -> List.length w = 1
  | Grade.Seq (r, s) ->
      List.exists (fun (u, v) -> matches r u && matches s v) (splits w)
  | Grade.Union (r, s) -> matches r w || matches s w
  | Grade.Inter (r, s) -> matches r w && matches s w
  | Grade.Compl r -> not (matches r w)
  | Grade.Star r' ->
      w = []
      || List.exists
           (fun (u, v) -> u <> [] && matches r' u && matches r v)
           (splits w)

(* The words of length at most 3 over a tick, the names [A], [B] and [C], and a
   name [Z] no expression mentions. *)
let words =
  let symbols = [ T; Op "A"; Op "B"; Op "C"; Op "Z" ] in
  let extend ws =
    List.concat_map (fun w -> List.map (fun s -> s :: w) symbols) ws
  in
  let rec upto n ws = if n = 0 then ws else ws @ upto (n - 1) (extend ws) in
  List.sort_uniq compare (upto 3 [ [] ])

let take n l = List.filteri (fun i _ -> i < n) l

(* An implementation of the regular trace grade, whose [canonical] tells
   whether the printing of a grade falls back. *)
module type PRINTED = sig
  include Grade.S with type Delay.t = Grades.Delay.Nat.t

  val canonical : t -> Grades.LetterRegex.t option
end

(* The checks of one implementation [G], both printing each grade alike. *)
module Suite
    (G : PRINTED)
    (I : sig
      val implementation : implementation
    end) =
struct
  module GS = Grades.GradeSystem.Identity (G)
  module Grammar = Parser.Grammar.Make (GS)

  let label name =
    (match I.implementation with
      | Automata -> "automata: "
      | Symbolic -> "derivatives: "
      | Concrete -> "derivatives by letters: "
      | Plain -> "plain derivatives: ")
    ^ name

  let check name = check (label name)
  let expect name = expect (label name)
  let show_option = function Some rho -> G.show rho | None -> "none"

  (* Whether two grades are the same, by [equal]: for the automata, the equality
     of their canonical automata. *)
  let same = G.equal bounds

  (* [expect_grade name ~expected actual] checks that [actual] is the same
     grade as [expected] and prints alike. *)
  let expect_grade name ~expected actual =
    check name
      (same expected actual && G.show expected = G.show actual)
      ("expected " ^ G.show expected ^ ", got " ^ G.show actual)

  (* Whether the printing of [rho] falls back to its normal form. *)
  let falls_back rho = Option.is_none (G.canonical rho)

  (* [parse text] is the grade the parser reads [text] as, in the grade
     position of a box. *)
  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        Ok rho
    | _ -> Error "not a box of a literal"
    | exception Grammar.Error -> Error "parser error"
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message

  let lit text =
    match parse text with Ok rho -> rho | Error reason -> failwith reason

  let reads text ~expected =
    match parse text with
    | Ok rho -> expect ("reads " ^ text) Fun.id ~expected (G.show rho)
    | Error reason -> check ("reads " ^ text) false reason

  let rejects text fragment =
    match parse text with
    | Ok rho -> check ("rejects " ^ text) false ("read as " ^ G.show rho)
    | Error reason ->
        check ("rejects " ^ text) (contains reason fragment)
          ("the reason '" ^ reason ^ "' does not mention '" ^ fragment ^ "'")

  let printing =
    [
      reads "{Read; 3; Send}" ~expected:"{Read; 3; Send}";
      reads "{Read | Send}" ~expected:"{Read | Send}";
      reads "{Open; (Read | Write)*; Close}"
        ~expected:"{Open; (Read | Write)*; Close}";
      reads "{0}" ~expected:"{0}";
      reads "3" ~expected:"{3}";
      reads "⊤" ~expected:"⊤";
      reads "top" ~expected:"⊤";
      reads "{_*}" ~expected:"⊤";
      reads "{_}" ~expected:"{_}";
      reads "{(1; 1)*}" ~expected:"{2*}";
      reads "{Read; Read*}" ~expected:"{Read; Read*}";
      reads "{~(_*; Read; _*)}" ~expected:"{(_ & ~Read)*}";
      reads "{~{_*; Revoke; _*}}" ~expected:"{(_ & ~Revoke)*}";
      reads "{(_ & ~Auth)*; Auth; _*}" ~expected:"{~(_ & ~Auth)*}";
      reads "{_*; Auth; _*}" ~expected:"{~(_ & ~Auth)*}";
      reads "{3 | 2*}" ~expected:"{3 | 2*}";
      reads "{1 | 2 | 3}" ~expected:"{1 | 2 | 3}";
      reads "{Open; Read*; Close | Open; Write*; Close}"
        ~expected:"{Open; {Read* | Write*}; Close}";
      reads "{(Open; (Read | Write)*; Close | 1)*}"
        ~expected:"{(1 | Open; (Read | Write)*; Close)*}";
      reads "{(A; A)* & (A; A; A)*}" ~expected:"{(A; A)* & (A; A; A)*}";
      reads "{(A; A)* & (A; A; A)* | A; A; A; A; A; A; A; A; A; A; A; A}"
        ~expected:"{(A; A; A; A; A; A)*}";
      reads "{~(A*; (_ & ~A))*}" ~expected:"{_*; A}";
      reads "{_ & ~(1 | Read)}" ~expected:"{_ & ~(1 | Read)}";
      reads "{3; _*}" ~expected:"{3; _*}";
    ]

  let lexing =
    [
      reads "{Read*|Send}" ~expected:"{Send | Read*}";
      reads "{Read*&~Send}" ~expected:"{Read*}";
      reads "{~~Read}" ~expected:"{Read}";
      reads "{Read**}" ~expected:"{Read*}";
      reads "{_&~Read|Read}" ~expected:"{_}";
      reads "{Read;(*a comment*)Send*|~_}" ~expected:"{~(_ & ~Read)}";
    ]

  let errors =
    [
      rejects "{Read & Send}" "empty language";
      rejects "{~_*}" "empty language";
      rejects "{3 & 2}" "empty language";
      rejects "Read" "not names such as 'Read'";
      rejects "∞" "not '∞'";
      rejects "(1, 2)" "not pairs";
      rejects "{(1, 2)}" "'(1, 2)' contains no whole number of time steps";
      rejects "{[1/2, 2]}" "whole numbers of time steps";
      rejects "{(1, 1]}" "n < m at an open endpoint";
      rejects "{<1}" "parser error";
    ]

  (* Interval atoms abbreviate sets of numbers of ticks. *)
  let intervals =
    let same_lit a b =
      let rho = lit a and rho' = lit b in
      check (a ^ " = " ^ b) (same rho rho') (G.show rho ^ " vs " ^ G.show rho')
    in
    [
      same_lit "{[1, 3]}" "{1 | 2 | 3}";
      same_lit "{(1, 4)}" "{2 | 3}";
      same_lit "{[1, 4)}" "{1 | 2 | 3}";
      same_lit "{(1, 3]}" "{2 | 3}";
      same_lit "{[2, 2]}" "{2}";
      same_lit "{[2, ∞)}" "{2; 1*}";
      same_lit "{(1, inf)}" "{2; 1*}";
      same_lit "{A; [0, 1]; B}" "{A; B | A; 1; B}";
    ]

  let canonicity =
    let same_lit a b =
      let rho = lit a and rho' = lit b in
      check (a ^ " = " ^ b) (same rho rho') (G.show rho ^ " vs " ^ G.show rho')
    in
    [
      same_lit "{(A | B)*}" "{(A*; B*)*}";
      same_lit "{A | ~A}" "⊤";
      same_lit "{_ & ~A | A}" "{_}";
      same_lit "{A; B | A; C}" "{A; (B | C)}";
      same_lit "{1; (1; 1)*}" "{(1; 1)*; 1}";
      same_lit "{~(~(A*) | ~((A; A)*))}" "{(A; A)*}";
      same_lit "{(A | B | C) & ~C}" "{A | B}";
      same_lit "{(A | 0); (B | 0)}" "{0 | A | B | A; B}";
      expect "redundant names are dropped" show_names ~expected:[]
        (G.events (lit "{_ & ~A | A}"));
      expect "distinguished names are kept" show_names ~expected:[ "A" ]
        (G.events (lit "{_ & ~A}"));
    ]

  (* [length rho] is the length of the word of the grade [rho] of a single
     word. *)
  let length rho =
    let rec power n = if n = 0 then [] else Grade.Any :: power (n - 1) in
    let words n =
      match power n with
      | [] -> G.one
      | r :: rs ->
          G.of_lit
            (Grade.Braces (List.fold_left (fun r s -> Grade.Seq (r, s)) r rs))
    in
    let rec from n = if G.leq bounds rho (words n) then n else from (n + 1) in
    from 0

  (* [counterexample a b ~expected] checks that the counterexample of [a] and
     [b] is a word of [a] not in [b] as long as the word [expected], and, for
     the automata, that it is [expected]. *)
  let counterexample a b ~expected =
    let name = "counterexample of " ^ a ^ " and " ^ b in
    match G.counterexample bounds (lit a) (lit b) with
    | None -> check name false "none"
    | Some word ->
        let shown = G.show word in
        check name
          (G.leq bounds word (lit a)
          && (not (G.leq bounds word (lit b)))
          && length word = length (lit expected)
          && (I.implementation <> Automata || shown = expected))
          ("got " ^ shown ^ ", expected " ^ expected)

  let inclusion =
    let leq a b = G.leq bounds (lit a) (lit b) in
    [
      check "{A; B} <= {A; _*}" (leq "{A; B}" "{A; _*}") "";
      check "{A; B; C} </= {A; B*}" (not (leq "{A; B; C}" "{A; B*}")) "";
      counterexample "{A; B; C}" "{A; B*}" ~expected:"{A; B; C}";
      counterexample "{(A | B)*}" "{A*}" ~expected:"{B}";
      counterexample "⊤" "{A*}" ~expected:"{1}";
      counterexample "{_}" "{A | 1}" ~expected:"{_ & ~(1 | A)}";
      counterexample "{3; (A | B)*; C}" "{3; A*; C}" ~expected:"{3; B; C}";
      expect "no counterexample" Fun.id ~expected:"none"
        (show_option (G.counterexample bounds (lit "{A; B}") (lit "{A; _*}")));
      check "top is not absorbing"
        (not (G.equal bounds (G.mul (lit "{3}") G.top) G.top))
        "{3} · ⊤ = ⊤";
      check "top is below itself" (G.leq bounds G.top G.top) "";
    ]

  let alignment =
    let leq a b = G.leq bounds (lit a) (lit b) in
    [
      check "{B} <= {_ & ~A}" (leq "{B}" "{_ & ~A}") "";
      check "{A} </= {_ & ~A}" (not (leq "{A}" "{_ & ~A}")) "";
      check "{_ & ~A} <= {_}" (leq "{_ & ~A}" "{_}") "";
      check "{_} </= {_ & ~A}" (not (leq "{_}" "{_ & ~A}")) "";
      expect_grade "join of the catch-alls" ~expected:(lit "{_}")
        (G.join (lit "{_ & ~A}") (lit "{A}"));
      expect "join of two names" show_names ~expected:[ "A"; "B" ]
        (G.events (G.join (lit "{A}") (lit "{B}")));
      expect_grade "product over aligned alphabets"
        ~expected:(lit "{(_ & ~B); B}")
        (G.mul (lit "{_ & ~B}") (lit "{B}"));
      check "catch-all versus a later name"
        (not (leq "{(_ & ~A); _}" "{(_ & ~A); (_ & ~B)}"))
        "";
    ]

  let properties =
    [
      expect "name" Fun.id
        ~expected:
          (match I.implementation with
          | Automata -> "regex-upper-bound-letter-automata"
          | Symbolic -> "regex-upper-bound-symbolic"
          | Concrete -> "regex-upper-bound-symbolic-by-letters"
          | Plain -> "regex-upper-bound-letter-derivatives")
        G.name;
      expect_grade "unit" ~expected:(lit "{0}") G.one;
      expect_grade "of_delay" ~expected:(lit "{4}") (G.of_delay 4);
      expect "unit least" show_bool ~expected:false G.unit_least;
      expect "commutative" show_bool ~expected:false G.commutative;
      expect "no runtime bounds" show_bool ~expected:false G.needs_op_bounds;
      expect "atomic" show_bool ~expected:true
        (G.is_atomic "Send" (lit "{Send}"));
      expect "not atomic" show_bool ~expected:false
        (G.is_atomic "Send" (lit "{Send | Read}"));
      expect_grade "time shadow" ~expected:(lit "{1 | 2 | 3}")
        (G.of_bounds (Grade.Closed 1, Grade.Closed 3));
      check "no implied bounds"
        (G.implied_bounds bounds (lit "{Send}") = None)
        "";
      expect "events" show_names ~expected:[ "Read"; "Send" ]
        (G.events (lit "{Send; 2; Read*}"));
    ]

  let grade_of_word w =
    let letter = function T -> Grade.Tick 1 | Op name -> Grade.Letter name in
    match List.map letter w with
    | [] -> G.one
    | r :: rs ->
        G.of_lit
          (Grade.Braces (List.fold_left (fun r s -> Grade.Seq (r, s)) r rs))

  let word_grades = List.map (fun w -> (w, grade_of_word w)) words

  (* Each random expression is read as the language [matches] decides on short
     words, or rejected as empty when no short word matches it, and prints as a
     literal the parser reads back as the same grade. *)
  let semantics =
    List.concat
    @@ List.mapi
         (fun i r ->
           let name = "sample " ^ string_of_int i in
           match G.of_lit (Grade.Braces r) with
           | rho ->
               let wrong =
                 List.filter
                   (fun (w, word) -> G.leq bounds word rho <> matches r w)
                   word_grades
               in
               [
                 check ("membership " ^ name) (wrong = [])
                   (Printf.sprintf "%d words misclassified by %s"
                      (List.length wrong) (G.show rho));
                 (match parse (G.show rho) with
                 | Ok rho' ->
                     check
                       ("round trip " ^ G.show rho)
                       (same rho rho')
                       ("read back as " ^ G.show rho')
                 | Error reason ->
                     check ("round trip " ^ G.show rho) false reason);
               ]
           | exception Grade.Invalid_literal _ ->
               [
                 check ("empty " ^ name)
                   (not (List.exists (matches r) words))
                   "rejected as empty, but matches a short word";
               ])
         samples

  let nonempty =
    List.filter_map
      (fun r ->
        match G.of_lit (Grade.Braces r) with
        | rho -> Some rho
        | exception Grade.Invalid_literal _ -> None)
      samples

  (* Mutual inclusion is sameness; and the same grades print alike unless the
     printing of one of them falls back. *)
  let canonical_samples =
    let sample = take 80 nonempty in
    List.concat_map
      (fun rho ->
        List.filter_map
          (fun rho' ->
            let mutual = G.leq bounds rho rho' && G.leq bounds rho' rho in
            let alike =
              (not mutual)
              || G.show rho = G.show rho'
              || falls_back rho || falls_back rho'
            in
            if mutual = same rho rho' && alike then None
            else
              Some (check "canonical" false (G.show rho ^ " vs " ^ G.show rho')))
          sample)
      sample

  let laws =
    let sample = take 12 nonempty in
    let eq = G.equal bounds in
    let for_all2 f = List.for_all (fun x -> List.for_all (f x) sample) sample in
    let for_all3 f = for_all2 (fun x y -> List.for_all (f x y) sample) in
    [
      check "mul associative"
        (for_all3 (fun x y z -> eq (G.mul x (G.mul y z)) (G.mul (G.mul x y) z)))
        "";
      check "join commutative"
        (for_all2 (fun x y -> eq (G.join x y) (G.join y x)))
        "";
      check "join idempotent"
        (List.for_all (fun x -> eq (G.join x x) x) sample)
        "";
      check "unit"
        (List.for_all
           (fun x -> eq (G.mul G.one x) x && eq (G.mul x G.one) x)
           sample)
        "";
      check "below top" (List.for_all (fun x -> G.leq bounds x G.top) sample) "";
      check "join is an upper bound"
        (for_all2 (fun x y -> G.leq bounds x (G.join x y)))
        "";
      check "of_delay additive"
        (List.for_all
           (fun (m, n) ->
             eq (G.of_delay (m + n)) (G.mul (G.of_delay m) (G.of_delay n)))
           [ (0, 0); (0, 3); (2, 5); (7, 1) ])
        "";
    ]

  (* Printing stops within the size of the normal form: on the words whose
     [n + 1]-th letter from the end is [A], of 2^(n + 1) states, and on the grade
     at the end of examples/regular/regular_traces.tpe, of 2^13 states, each
     printed as its normal form. Reading the larger of these grades as automata
     takes seconds, by the subset construction; the automata are checked up to
     [n = 12] only. *)
  let bounded_printing =
    let from_end a n =
      String.concat "; " ("_*" :: a :: List.init n (Fun.const "_"))
    in
    let slow = "~(" ^ from_end "A" 12 ^ ") & ~(" ^ from_end "B" 12 ^ ")" in
    let texts =
      match I.implementation with
      | Automata -> List.init 12 (fun n -> from_end "A" (n + 1))
      | Symbolic | Concrete | Plain ->
          List.init 16 (fun n -> from_end "A" (n + 1)) @ [ slow ]
    in
    List.map
      (fun text ->
        let rho = lit ("{" ^ text ^ "}") in
        let start = Sys.time () in
        let shown = G.show rho in
        let time = Sys.time () -. start in
        check
          ("prints {" ^ text ^ "} quickly")
          (shown = "{" ^ text ^ "}" && time < 1.)
          (Printf.sprintf "printed as %s in %.2f s" shown time))
      texts

  let checks =
    printing @ lexing @ errors @ intervals @ canonicity @ inclusion @ alignment
    @ properties @ semantics @ canonical_samples @ laws @ bounded_printing
end

module Automata =
  Suite
    (Grades.RegularTraceGrade)
    (struct
      let implementation = Automata
    end)

module Derivatives =
  Suite
    (Grades.RegularTraceGradeDerivative)
    (struct
      let implementation = Symbolic
    end)

module ByLetters =
  Suite
    (Grades.RegularTraceGradeDerivative.Concrete)
    (struct
      let implementation = Concrete
    end)

module Plain =
  Suite
    (Grades.RegularTraceGradePlain)
    (struct
      let implementation = Plain
    end)

(* The implementations by automata and by symbolic derivatives agree on the
   emptiness, inclusion and equality of random expressions over four names,
   and on the lengths of the counterexamples to inclusion; each reads the
   other's printed forms as the same grade. *)
module Cross = struct
  module A = Grades.RegularTraceGrade
  module D = Grades.RegularTraceGradeDerivative

  let expressions =
    let state = Random.State.make [| 1789 |] in
    List.init 400 (fun i ->
        random_regex ~names:[ "A"; "B"; "C"; "D" ] ~depth:(4 + (i mod 2)) state)

  let grades r =
    let read of_lit =
      match of_lit (Grade.Braces r) with
      | rho -> Some rho
      | exception Grade.Invalid_literal _ -> None
    in
    (read A.of_lit, read D.of_lit)

  let emptiness =
    List.mapi
      (fun i r ->
        let a, d = grades r in
        check
          ("cross: emptiness of expression " ^ string_of_int i)
          (Option.is_some a = Option.is_some d)
          "the implementations disagree")
      expressions

  (* The pairs compared: each expression with the next, and with expressions
     denoting the same language. *)
  let pairs =
    let rec next = function
      | r :: (s :: _ as rest) -> (r, s) :: next rest
      | _ -> []
    in
    List.concat_map
      (fun (r, s) ->
        [
          (r, s);
          (s, r);
          (r, Grade.Union (r, Grade.Inter (r, s)));
          (r, Grade.Union (Grade.Inter (r, s), Grade.Inter (r, Grade.Compl s)));
          (Grade.Seq (r, s), Grade.Seq (r, Grade.Union (s, Grade.Inter (s, r))));
        ])
      (next expressions)

  (* Whether the counterexamples [w] and [w'] of the two implementations are
     both absent or of the same length. *)
  let same_length w w' =
    match (w, w') with
    | None, None -> true
    | Some w, Some w' -> Automata.length w = Derivatives.length w'
    | _ -> false

  let decide i (r, s) =
    match (grades r, grades s) with
    | (Some a, Some d), (Some a', Some d') ->
        let name what = "cross: " ^ what ^ " of pair " ^ string_of_int i in
        [
          check (name "inclusion")
            (A.leq bounds a a' = D.leq bounds d d')
            (D.show d ^ " <= " ^ D.show d');
          check (name "equality")
            (A.equal bounds a a' = D.equal bounds d d')
            (D.show d ^ " = " ^ D.show d');
          check (name "counterexample")
            (same_length
               (A.counterexample bounds a a')
               (D.counterexample bounds d d'))
            (D.show d ^ " <= " ^ D.show d');
        ]
    | _ -> []

  let decisions = List.concat (List.mapi decide pairs)

  let print i r =
    match grades r with
    | Some a, Some d ->
        let read_back =
          match (Automata.parse (D.show d), Derivatives.parse (A.show a)) with
          | Ok a', Ok d' -> A.equal bounds a a' && D.equal bounds d d'
          | _ -> false
        in
        let normal_form = Grades.LetterRegex.of_symbolic d in
        let name what =
          "cross: " ^ what ^ " of expression " ^ string_of_int i
        in
        [
          check (name "printing") read_back (A.show a ^ " and " ^ D.show d);
          check
            (name "size of the printing")
            (Option.for_all
               (fun r ->
                 Grades.LetterRegex.size r
                 <= Grades.LetterRegex.size normal_form)
               (D.canonical d))
            (D.show d ^ " for " ^ Grades.LetterRegex.literal normal_form);
          check (name "printing by both")
            (Option.is_none (D.canonical d) || A.show a = D.show d)
            (D.show d ^ " vs " ^ A.show a);
        ]
    | _ -> []

  let printing = List.concat (List.mapi print expressions)

  (* Whether the grades [x] and [y] of an implementation print alike or the
     printing of one of them falls back. *)
  let alike canonical show x y =
    show x = show y
    || Option.is_none (canonical x)
    || Option.is_none (canonical y)

  (* Equal grades have equal automata and print alike, by each implementation
     and by both, unless the printing of one of them falls back. *)
  let canonicity i (r, s) =
    match (grades r, grades s) with
    | (Some a, Some d), (Some a', Some d') when D.equal bounds d d' ->
        let name what = "cross: " ^ what ^ " of pair " ^ string_of_int i in
        let automaton = Grades.SymbolicAutomaton.of_regex ~limit:max_int in
        [
          check (name "equal automata")
            (Option.equal Grades.SymbolicAutomaton.equal (automaton d)
               (automaton d'))
            (D.show d ^ " = " ^ D.show d');
          check
            (name "printing by automata")
            (alike A.canonical A.show a a')
            (A.show a ^ " vs " ^ A.show a');
          check
            (name "printing by derivatives")
            (alike D.canonical D.show d d')
            (D.show d ^ " vs " ^ D.show d');
          check (name "printing by both")
            (alike D.canonical D.show d d' || A.show a = D.show d)
            (D.show d ^ " vs " ^ A.show a);
        ]
    | _ -> []

  let canonical = List.concat (List.mapi canonicity pairs)

  (* The pairs of distinct but equal expressions whose grades both print
     canonically, of which there are some. *)
  let canonical_pairs =
    let printed_canonically (r, s) =
      match (grades r, grades s) with
      | (_, Some d), (_, Some d') ->
          r <> s && D.equal bounds d d'
          && Option.is_some (D.canonical d)
          && Option.is_some (D.canonical d')
      | _ -> false
    in
    let count = List.length (List.filter printed_canonically pairs) in
    [
      check "cross: equal pairs printed canonically" (count > 0)
        (string_of_int count ^ " pairs");
    ]

  let checks = emptiness @ decisions @ printing @ canonical @ canonical_pairs
end

(* The implementation [G] agrees with those by automata and by symbolic
   derivatives on the expressions and pairs of [Cross]: on emptiness,
   inclusion, equality and the lengths of the counterexamples to inclusion;
   and it prints each grade as the implementation by symbolic derivatives
   unless the printing of one of them falls back. *)
module Agreement
    (G : PRINTED)
    (S : sig
      val suite : string
      val length : G.t -> int
    end) =
struct
  module A = Grades.RegularTraceGrade
  module D = Grades.RegularTraceGradeDerivative

  let grades r =
    let a, d = Cross.grades r in
    let g =
      match G.of_lit (Grade.Braces r) with
      | rho -> Some rho
      | exception Grade.Invalid_literal _ -> None
    in
    (a, d, g)

  let name what i = "cross, " ^ S.suite ^ ": " ^ what ^ " " ^ string_of_int i

  let emptiness =
    List.mapi
      (fun i r ->
        let a, d, g = grades r in
        check
          (name "emptiness of expression" i)
          (Option.is_some g = Option.is_some a
          && Option.is_some g = Option.is_some d)
          "the implementations disagree")
      Cross.expressions

  (* The length of a counterexample, if any. *)
  let length length = Option.map length

  let decide i (r, s) =
    match (grades r, grades s) with
    | (Some a, Some d, Some g), (Some a', Some d', Some g') ->
        let leq = G.leq bounds g g' and equal = G.equal bounds g g' in
        let found = length S.length (G.counterexample bounds g g') in
        [
          check
            (name "inclusion of pair" i)
            (leq = A.leq bounds a a' && leq = D.leq bounds d d')
            (G.show g ^ " <= " ^ G.show g');
          check
            (name "equality of pair" i)
            (equal = A.equal bounds a a' && equal = D.equal bounds d d')
            (G.show g ^ " = " ^ G.show g');
          check
            (name "counterexample of pair" i)
            (found = length Automata.length (A.counterexample bounds a a')
            && found = length Derivatives.length (D.counterexample bounds d d')
            )
            (G.show g ^ " <= " ^ G.show g');
        ]
    | _ -> []

  let decisions = List.concat (List.mapi decide Cross.pairs)

  let print i r =
    match grades r with
    | _, Some d, Some g ->
        [
          check
            (name "printing of expression" i)
            (G.show g = D.show d
            || Option.is_none (G.canonical g)
            || Option.is_none (D.canonical d))
            (G.show g ^ " vs " ^ D.show d);
        ]
    | _ -> []

  let printing = List.concat (List.mapi print Cross.expressions)
  let checks = emptiness @ decisions @ printing
end

module ByLettersAgreement =
  Agreement
    (Grades.RegularTraceGradeDerivative.Concrete)
    (struct
      let suite = "derivatives by letters"
      let length = ByLetters.length
    end)

module PlainAgreement =
  Agreement
    (Grades.RegularTraceGradePlain)
    (struct
      let suite = "plain derivatives"
      let length = Plain.length
    end)

(* Long runs of ticks: the leaps of the expressions against their derivatives
   letter by letter, the shortest words found with leaps against a search
   letter by letter on delays of up to 3000 ticks, the implementations by
   derivatives against each other on delays of up to 10⁴ ticks and against the
   automata on delays of up to 30, and the time of decisions on long
   delays. *)
module Runs = struct
  module R = Grades.SymbolicRegex
  module A = Grades.RegularTraceGrade
  module D = Grades.RegularTraceGradeDerivative
  module C = Grades.RegularTraceGradeDerivative.Concrete
  module P = Grades.RegularTraceGradePlain

  let tick = R.Letters.tick

  (* [steps k r] is the derivative of [r] by [tickᵏ], letter by letter. *)
  let rec steps k r = if k = 0 then r else steps (k - 1) (R.derivative tick r)

  let expressions ~seed ~count ~longest =
    let state = Random.State.make [| seed |] in
    List.init count (fun _ ->
        D.of_regex (random_grade ~longest ~names:[ "A"; "B" ] state))

  (* The leap by [k] denotes the language of [k] derivatives by [tick], on
     random expressions with delays of up to 60 ticks and on grades with delays
     of up to 10⁴, and is their normal form on runs, concatenations led by runs,
     repetitions of runs and the complements of these. *)
  let leaps =
    let state = Random.State.make [| 29 |] in
    let random n = Random.State.int state (n + 1) in
    let short =
      List.init 150 (fun _ ->
          D.of_regex
            (random_regex ~longest:60 ~names:[ "A"; "B" ] ~depth:4 state))
    in
    let long = expressions ~seed:31 ~count:40 ~longest:10000 in
    let exact s =
      let n = random 5000 and c = 1 + random 40 in
      [
        R.ticks n;
        R.concat (R.ticks n) s;
        R.star (R.ticks c);
        R.concat (R.ticks n) (R.star (R.ticks c));
        R.compl (R.concat (R.ticks n) s);
      ]
    in
    let same equal k r =
      check
        (Printf.sprintf "runs: leap by %d of %s" k (D.show r))
        (equal (R.leap k r) (steps k r))
        ""
    in
    List.map (fun r -> same R.equal (random 150) r) short
    @ List.map (fun r -> same R.equal (random 20000) r) long
    @ List.concat_map
        (fun s ->
          List.map (fun r -> same R.equal_form (random 8000) r) (exact s))
        (List.filteri (fun i _ -> i < 40) long)

  (* [reference r] is the least of the shortest words of [r] in the order of
     its minterms, by breadth-first search of its derivatives letter by
     letter. *)
  let reference r =
    let ms = R.minterms r in
    let seen = Hashtbl.create 64 in
    let visit (d, rev_word) =
      List.filter_map
        (fun m ->
          let d' = R.derivative m d in
          if Hashtbl.mem seen (R.hash d') then None
          else begin
            Hashtbl.add seen (R.hash d') ();
            Some (d', m :: rev_word)
          end)
        ms
    in
    let rec go = function
      | [] -> None
      | level -> (
          match List.find_opt (fun (d, _) -> R.nullable d) level with
          | Some (_, rev_word) -> Some (List.rev rev_word)
          | None -> go (List.concat_map visit level))
    in
    Hashtbl.add seen (R.hash r) ();
    go [ (r, []) ]

  (* The pairs of each expression with the next. *)
  let rec next = function
    | r :: (s :: _ as rest) -> (r, s) :: next rest
    | _ -> []

  let shortest =
    List.map
      (fun (r, s) ->
        let d = R.inter [ r; R.compl s ] in
        check
          ("runs: shortest word of " ^ D.show r ^ " not in " ^ D.show s)
          (Option.equal
             (List.equal R.Letters.equal)
             (R.shortest d) (reference d))
          "")
      (next (expressions ~seed:37 ~count:60 ~longest:3000))

  let grades r =
    let read of_lit =
      match of_lit (Grade.Braces r) with
      | rho -> Some rho
      | exception Grade.Invalid_literal _ -> None
    in
    (read D.of_lit, read C.of_lit, read P.of_lit)

  let grade_regexes ~seed ~count ~longest =
    let state = Random.State.make [| seed |] in
    List.init count (fun _ ->
        random_grade ~longest ~names:[ "A"; "B"; "C" ] state)

  (* [printed_length text] is the length of the word of a grade printed as
     [text], a sequence of letters and delays: a delay counts as its number of
     ticks. *)
  let printed_length text =
    let inner = String.sub text 1 (String.length text - 2) in
    List.fold_left
      (fun n part ->
        n + Option.value (int_of_string_opt (String.trim part)) ~default:1)
      0
      (String.split_on_char ';' inner)

  (* The implementations by derivatives agree on long delays. *)
  let derivatives =
    List.concat
    @@ List.mapi
         (fun i (r, s) ->
           match (grades r, grades s) with
           | (Some d, Some c, Some p), (Some d', Some c', Some p') ->
               let name what = Printf.sprintf "runs: %s of pair %d" what i in
               let leq = D.leq bounds d d' and equal = D.equal bounds d d' in
               let found =
                 Option.map
                   (fun w -> printed_length (D.show w))
                   (D.counterexample bounds d d')
               in
               [
                 check (name "inclusion")
                   (C.leq bounds c c' = leq && P.leq bounds p p' = leq)
                   (D.show d ^ " <= " ^ D.show d');
                 check (name "equality")
                   (C.equal bounds c c' = equal && P.equal bounds p p' = equal)
                   (D.show d ^ " = " ^ D.show d');
                 check (name "counterexample")
                   (Option.map
                      (fun w -> printed_length (C.show w))
                      (C.counterexample bounds c c')
                    = found
                   && Option.map
                        (fun w -> printed_length (P.show w))
                        (P.counterexample bounds p p')
                      = found)
                   (D.show d ^ " <= " ^ D.show d');
               ]
           | (d, c, p), (d', c', p') ->
               [
                 check
                   (Printf.sprintf "runs: emptiness of pair %d" i)
                   (Option.is_some c = Option.is_some d
                   && Option.is_some p = Option.is_some d
                   && Option.is_some c' = Option.is_some d'
                   && Option.is_some p' = Option.is_some d')
                   "the implementations disagree";
               ])
         (next (grade_regexes ~seed:41 ~count:80 ~longest:10000))

  (* The implementation by symbolic derivatives agrees with that by automata on
     delays of up to 30 ticks. *)
  let automata =
    List.concat
    @@ List.mapi
         (fun i (r, s) ->
           match (Cross.grades r, Cross.grades s) with
           | (Some a, Some d), (Some a', Some d') ->
               let name what = Printf.sprintf "runs: %s of pair %d" what i in
               [
                 check
                   (name "inclusion by automata")
                   (A.leq bounds a a' = D.leq bounds d d')
                   (D.show d ^ " <= " ^ D.show d');
                 check
                   (name "equality by automata")
                   (A.equal bounds a a' = D.equal bounds d d')
                   (D.show d ^ " = " ^ D.show d');
                 check
                   (name "counterexample by automata")
                   (Cross.same_length
                      (A.counterexample bounds a a')
                      (D.counterexample bounds d d'))
                   (D.show d ^ " <= " ^ D.show d');
               ]
           | (a, d), (a', d') ->
               [
                 check
                   (Printf.sprintf "runs: emptiness by automata of pair %d" i)
                   (Option.is_some a = Option.is_some d
                   && Option.is_some a' = Option.is_some d')
                   "the implementations disagree";
               ])
         (next
            (let state = Random.State.make [| 43 |] in
             List.init 150 (fun i ->
                 if i mod 2 = 0 then
                   random_grade ~longest:30 ~names:[ "A"; "B"; "C" ] state
                 else
                   random_regex ~longest:30 ~names:[ "A"; "B"; "C" ] ~depth:4
                     state)))

  (* Long delays are decided and printed within a second, by each
     implementation by derivatives. *)
  let timing =
    let quickly name decide =
      let start = Sys.time () in
      let holds = decide () in
      let time = Sys.time () -. start in
      check name (holds && time < 1.) (Printf.sprintf "in %.2f s" time)
    in
    let long (type a) (module G : PRINTED with type t = a) (lit : string -> a) =
      let name what = "runs: " ^ G.name ^ ": " ^ what in
      [
        quickly (name "{10000; Ready} <= {9999; _; _*}") (fun () ->
            G.leq bounds (lit "{10000; Ready}") (lit "{9999; _; _*}"));
        quickly (name "{5000; 5000} = {10000}") (fun () ->
            G.equal bounds (lit "{5000; 5000}") (lit "{10000}"));
        quickly (name "{10000; Ready} ≠ {10000; Ready | 20000}") (fun () ->
            not
              (G.equal bounds (lit "{10000; Ready}")
                 (lit "{10000; Ready | 20000}")));
        quickly (name "counterexample of {9999; Ready} <= {10000; _; _*}")
          (fun () ->
            Option.map G.show
              (G.counterexample bounds (lit "{9999; Ready}")
                 (lit "{10000; _; _*}"))
            = Some "{9999; Ready}");
      ]
    in
    long (module D) Derivatives.lit
    @ long (module C) ByLetters.lit
    @ long (module P) Plain.lit

  let checks = leaps @ shortest @ derivatives @ automata @ timing
end

let () =
  let checks =
    Automata.checks @ Derivatives.checks @ ByLetters.checks @ Plain.checks
    @ Cross.checks @ ByLettersAgreement.checks @ PlainAgreement.checks
    @ Runs.checks
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
