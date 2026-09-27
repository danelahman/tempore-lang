(* Unit tests of the two implementations of the regular trace grade, by
   automata and by symbolic derivatives: their constructions, canonical or
   normal forms, inclusion with counterexamples, alphabet alignment, laws on
   samples, and the reading and printing of their literals, checked against a
   direct matcher of regular expressions and against the parser; and the
   agreement of the two on random expressions, on which equal grades have equal
   canonical automata and print alike. *)

module Grade = Language.Grade
module LetterRegex = Language.LetterRegex
module SugaredAst = SugaredAst

type implementation = Automata | Derivatives
type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let bounds _ = (1, 2)
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

(* The checks of one implementation [G], the expected printed forms being those
   of [implementation]. *)
module Suite
    (G : Grade.S)
    (I : sig
      val implementation : implementation
    end) =
struct
  module GS = Language.GradeSystem.Identity (G)
  module Grammar = Parser.Grammar.Make (GS)

  let label name =
    (match I.implementation with
      | Automata -> "automata: "
      | Derivatives -> "derivatives: ")
    ^ name

  let check name = check (label name)
  let expect name = expect (label name)
  let show_option = function Some rho -> G.show rho | None -> "none"

  (* [printed ~automata ~derivatives] is the printed form expected of the
     implementation. *)
  let printed ~automata ~derivatives =
    match I.implementation with
    | Automata -> automata
    | Derivatives -> derivatives

  (* Whether two grades are the same: structurally for the automata, which are
     canonical, and by [equal] for the derivatives. *)
  let same rho rho' =
    match I.implementation with
    | Automata -> rho = rho'
    | Derivatives -> G.equal bounds rho rho'

  (* [parse text] is the grade the parser reads [text] as, in the grade
     position of a box. *)
  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox (rho, _); _ } -> Ok rho
    | _ -> Error "not a box"
    | exception Grammar.Error -> Error "parser error"
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message

  let lit text =
    match parse text with Ok rho -> rho | Error reason -> failwith reason

  let reads text ~automata ~derivatives =
    let expected = printed ~automata ~derivatives in
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
      reads "{Read; 3; Send}" ~automata:"{Read; 3; Send}"
        ~derivatives:"{Read; 3; Send}";
      reads "{Read | Send}" ~automata:"{Read | Send}"
        ~derivatives:"{Read | Send}";
      reads "{Open; (Read | Write)*; Close}"
        ~automata:"{Open; (Read | Write)*; Close}"
        ~derivatives:"{Open; (Read | Write)*; Close}";
      reads "{0}" ~automata:"{0}" ~derivatives:"{0}";
      reads "3" ~automata:"{3}" ~derivatives:"{3}";
      reads "⊤" ~automata:"⊤" ~derivatives:"⊤";
      reads "top" ~automata:"⊤" ~derivatives:"⊤";
      reads "{_*}" ~automata:"⊤" ~derivatives:"⊤";
      reads "{_}" ~automata:"{_}" ~derivatives:"{_}";
      reads "{(1; 1)*}" ~automata:"{2*}" ~derivatives:"{2*}";
      reads "{Read; Read*}" ~automata:"{Read; Read*}"
        ~derivatives:"{Read; Read*}";
      reads "{~(_*; Read; _*)}" ~automata:"{(_ & ~Read)*}"
        ~derivatives:"{(_ & ~Read)*}";
      reads "{~{_*; Revoke; _*}}" ~automata:"{(_ & ~Revoke)*}"
        ~derivatives:"{(_ & ~Revoke)*}";
      reads "{(_ & ~Auth)*; Auth; _*}" ~automata:"{~(_ & ~Auth)*}"
        ~derivatives:"{~(_ & ~Auth)*}";
      reads "{_*; Auth; _*}" ~automata:"{~(_ & ~Auth)*}"
        ~derivatives:"{~(_ & ~Auth)*}";
      reads "{3 | 2*}" ~automata:"{0 | 2; (0 | 1; {0 | 1; 2*})}"
        ~derivatives:"{3 | 2*}";
      reads "{1 | 2 | 3}" ~automata:"{1; (0 | 1; (0 | 1))}"
        ~derivatives:"{1 | 2 | 3}";
      reads "{Open; Read*; Close | Open; Write*; Close}"
        ~automata:"{Open; {Read* | Write*}; Close}"
        ~derivatives:"{Open; {Read* | Write*}; Close}";
      reads "{(Open; (Read | Write)*; Close | 1)*}"
        ~automata:"{(1 | Open; (Read | Write)*; Close)*}"
        ~derivatives:"{(1 | Open; (Read | Write)*; Close)*}";
      reads "{(A; A)* & (A; A; A)*}" ~automata:"{(A; A; A; A; A; A)*}"
        ~derivatives:"{(A; A)* & (A; A; A)*}";
      reads "{_ & ~(1 | Read)}" ~automata:"{_ & ~(1 | Read)}"
        ~derivatives:"{_ & ~(1 | Read)}";
      reads "{3; _*}" ~automata:"{3; _*}" ~derivatives:"{3; _*}";
    ]

  let lexing =
    [
      reads "{Read*|Send}" ~automata:"{Send | Read*}"
        ~derivatives:"{Send | Read*}";
      reads "{Read*&~Send}" ~automata:"{Read*}" ~derivatives:"{Read*}";
      reads "{~~Read}" ~automata:"{Read}" ~derivatives:"{Read}";
      reads "{Read**}" ~automata:"{Read*}" ~derivatives:"{Read*}";
      reads "{_&~Read|Read}" ~automata:"{_}" ~derivatives:"{_}";
      reads "{Read;(*a comment*)Send*|~_}" ~automata:"{~(_ & ~Read)}"
        ~derivatives:"{~(_ & ~Read)}";
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

  (* Mutual inclusion is sameness: structural equality for the automata, [equal]
     for the derivatives. *)
  let canonical_samples =
    let sample = take 80 nonempty in
    List.concat_map
      (fun rho ->
        List.filter_map
          (fun rho' ->
            let mutual = G.leq bounds rho rho' && G.leq bounds rho' rho in
            if mutual = same rho rho' then None
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

  let checks =
    printing @ lexing @ errors @ canonicity @ inclusion @ alignment @ properties
    @ semantics @ canonical_samples @ laws
end

module Automata =
  Suite
    (Language.RegularTraceGrade)
    (struct
      let implementation = Automata
    end)

module Derivatives =
  Suite
    (Language.RegularTraceGradeDerivative)
    (struct
      let implementation = Derivatives
    end)

(* The two implementations agree on the emptiness, inclusion and equality of
   random expressions over four names, and on the lengths of the
   counterexamples to inclusion; each reads the other's printed forms as the
   same grade. *)
module Cross = struct
  module A = Language.RegularTraceGrade
  module D = Language.RegularTraceGradeDerivative

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
        [
          check
            ("cross: printing of expression " ^ string_of_int i)
            read_back
            (A.show a ^ " and " ^ D.show d);
        ]
    | _ -> []

  let printing = List.concat (List.mapi print expressions)

  (* Whether the derivatives print [d] as its normal form rather than as an
     expression of its automaton. *)
  let prints_normal_form d =
    D.show d = "{" ^ LetterRegex.to_string (LetterRegex.of_symbolic d) ^ "}"

  (* Equal grades have equal automata and print alike: the automata always,
     the derivatives unless one of them prints its normal form, and the two
     implementations alike unless the derivatives print the normal form. *)
  let canonicity i (r, s) =
    match (grades r, grades s) with
    | (Some a, Some d), (Some a', Some d') when D.equal bounds d d' ->
        let name what = "cross: " ^ what ^ " of pair " ^ string_of_int i in
        let automaton = Language.SymbolicAutomaton.of_regex ~limit:256 in
        [
          check (name "equal automata")
            (match (automaton d, automaton d') with
            | Some x, Some y -> Language.SymbolicAutomaton.equal x y
            | _ -> true)
            (D.show d ^ " = " ^ D.show d');
          check
            (name "printing by automata")
            (A.show a = A.show a')
            (A.show a ^ " vs " ^ A.show a');
          check
            (name "printing by derivatives")
            (D.show d = D.show d'
            || prints_normal_form d || prints_normal_form d')
            (D.show d ^ " vs " ^ D.show d');
          check (name "printing by both")
            (D.show d = A.show a || prints_normal_form d)
            (D.show d ^ " vs " ^ A.show a);
        ]
    | _ -> []

  let canonical = List.concat (List.mapi canonicity pairs)
  let checks = emptiness @ decisions @ printing @ canonical
end

let () =
  let checks = Automata.checks @ Derivatives.checks @ Cross.checks in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
