(* Unit tests of the two implementations of the regular trace grade, by
   automata and by symbolic derivatives: their constructions, canonical or
   normal forms, inclusion with counterexamples, alphabet alignment, laws on
   samples, and the reading and printing of their literals, checked against a
   direct matcher of regular expressions and against the parser; and the
   agreement of the two on random expressions, on which equal grades have equal
   canonical automata and print alike unless the printing of one of them falls
   back to its normal form; and the time and size of the printing, bounded by
   the size of the normal form. *)

module Grade = Grades.Grade
module SugaredAst = SugaredAst

type implementation = Automata | Derivatives
type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let bounds = { Grade.cost = (fun _ -> (1, 2)); operations = [] }
let show_bool = string_of_bool
let show_names names = "[" ^ String.concat "; " names ^ "]"

(* [contains s sub] is whether [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

(* Random regular expressions of depth [depth] over the names [names]. *)
let random_regex ~names ~depth state =
  let count = List.length names in
  let atom () =
    match Random.State.int state (count + 3) with
    | i when i < count -> Grade.Letter (List.nth names i)
    | i when i = count -> Grade.Tick (Random.State.int state 3)
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
  include Grade.S

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
      | Derivatives -> "derivatives: ")
    ^ name

  let check name = check (label name)
  let expect name = expect (label name)
  let show_option = function Some rho -> G.show rho | None -> "none"

  (* Whether two grades are the same, by [equal]: for the automata, the equality
     of their canonical automata. *)
  let same = G.equal bounds

  (* Whether the printing of [rho] falls back to its normal form. *)
  let falls_back rho = Option.is_none (G.canonical rho)

  (* [parse text] is the grade the parser reads [text] as, in the grade
     position of a box. *)
  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox (rho, _); _ } -> Ok rho.it
    | _ -> Error "not a box"
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
          && (I.implementation = Derivatives || shown = expected))
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
      expect "join of the catch-alls" G.show ~expected:(lit "{_}")
        (G.join (lit "{_ & ~A}") (lit "{A}"));
      expect "join of two names" show_names ~expected:[ "A"; "B" ]
        (G.events (G.join (lit "{A}") (lit "{B}")));
      expect "product over aligned alphabets" G.show
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
          | Automata -> "traces-regex"
          | Derivatives -> "traces-regex-symbolic")
        G.name;
      expect "unit" G.show ~expected:(lit "{0}") G.one;
      expect "of_nat" G.show ~expected:(lit "{4}") (G.of_nat 4);
      expect "unit least" show_bool ~expected:false G.unit_least;
      expect "commutative" show_bool ~expected:false G.commutative;
      expect "no runtime bounds" show_bool ~expected:false G.needs_op_bounds;
      expect "atomic" show_bool ~expected:true
        (G.is_atomic "Send" (lit "{Send}"));
      expect "not atomic" show_bool ~expected:false
        (G.is_atomic "Send" (lit "{Send | Read}"));
      expect "time shadow" G.show ~expected:(lit "{1 | 2 | 3}")
        (G.of_bounds (1, 3));
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
      check "of_nat additive"
        (List.for_all
           (fun (m, n) ->
             eq (G.of_nat (m + n)) (G.mul (G.of_nat m) (G.of_nat n)))
           [ (0, 0); (0, 3); (2, 5); (7, 1) ])
        "";
    ]

  (* Printing stops within the size of the normal form: on the words whose
     [n + 1]-th letter from the end is [A], of 2^(n + 1) states, and on the grade
     at the end of examples/traces/regular_traces.tpe, of 2^13 states, each
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
      | Derivatives -> List.init 16 (fun n -> from_end "A" (n + 1)) @ [ slow ]
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
    printing @ lexing @ errors @ canonicity @ inclusion @ alignment @ properties
    @ semantics @ canonical_samples @ laws @ bounded_printing
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
      let implementation = Derivatives
    end)

(* The two implementations agree on the emptiness, inclusion and equality of
   random expressions over four names, and on the lengths of the
   counterexamples to inclusion; each reads the other's printed forms as the
   same grade. *)
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

let () =
  let checks = Automata.checks @ Derivatives.checks @ Cross.checks in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
