(* Unit tests of the regular trace grade: its automata constructions, canonical
   form, inclusion with counterexamples, alphabet alignment, laws on samples,
   and the reading and printing of its literals, checked against a direct
   matcher of regular expressions and against the parser. *)

module Grade = Language.Grade
module G = Language.RegularTraceGrade
module GS = Language.GradeSystem.Identity (G)
module Grammar = Parser.Grammar.Make (GS)
module SugaredAst = SugaredAst

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let bounds _ = (1, 2)
let show_bool = string_of_bool
let show_names names = "[" ^ String.concat "; " names ^ "]"
let show_option = function Some rho -> G.show rho | None -> "none"

(* [contains s sub] is whether [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

(* [parse text] is the grade the parser reads [text] as, in the grade position
   of a box. *)
let parse text =
  let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
  match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
  | { it = SugaredAst.GenBox (rho, _); _ } -> Ok rho
  | _ -> Error "not a box"
  | exception Grammar.Error -> Error "parser error"
  | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message

let lit text =
  match parse text with Ok rho -> rho | Error reason -> failwith reason

let reads text expected =
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
    reads "{Read; 3; Send}" "{Read; 3; Send}";
    reads "{Read | Send}" "{Read | Send}";
    reads "{Open; (Read | Write)*; Close}" "{Open; (Read | Write)*; Close}";
    reads "{0}" "{0}";
    reads "3" "{3}";
    reads "⊤" "⊤";
    reads "top" "⊤";
    reads "{_*}" "⊤";
    reads "{_}" "{_}";
    reads "{(1; 1)*}" "{2*}";
    reads "{Read; Read*}" "{Read; Read*}";
    reads "{~(_*; Read; _*)}" "{(_ & ~Read)*}";
    reads "{_ & ~(1 | Read)}" "{_ & ~(1 | Read)}";
    reads "{3; _*}" "{3; _*}";
  ]

let lexing =
  [
    reads "{Read*|Send}" "{Read* | Send}";
    reads "{Read*&~Send}" "{Read*}";
    reads "{~~Read}" "{Read}";
    reads "{Read**}" "{Read*}";
    reads "{_&~Read|Read}" "{_}";
    reads "{Read;(*a comment*)Send*|~_}" "{0 | (Read | (_ & ~Read); _); _*}";
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
  let same a b =
    let rho = lit a and rho' = lit b in
    check (a ^ " = " ^ b) (rho = rho') (G.show rho ^ " vs " ^ G.show rho')
  in
  [
    same "{(A | B)*}" "{(A*; B*)*}";
    same "{A | ~A}" "⊤";
    same "{_ & ~A | A}" "{_}";
    same "{A; B | A; C}" "{A; (B | C)}";
    same "{1; (1; 1)*}" "{(1; 1)*; 1}";
    same "{~(~(A*) | ~((A; A)*))}" "{(A; A)*}";
    same "{(A | B | C) & ~C}" "{A | B}";
    same "{(A | 0); (B | 0)}" "{0 | A | B | A; B}";
    expect "redundant names are dropped" show_names ~expected:[]
      (G.events (lit "{_ & ~A | A}"));
    expect "distinguished names are kept" show_names ~expected:[ "A" ]
      (G.events (lit "{_ & ~A}"));
  ]

let inclusion =
  let leq a b = G.leq bounds (lit a) (lit b) in
  let cex a b = show_option (G.counterexample (lit a) (lit b)) in
  [
    check "{A; B} <= {A; _*}" (leq "{A; B}" "{A; _*}") "";
    check "{A; B; C} </= {A; B*}" (not (leq "{A; B; C}" "{A; B*}")) "";
    expect "counterexample of a word" Fun.id ~expected:"{A; B; C}"
      (cex "{A; B; C}" "{A; B*}");
    expect "shortest counterexample" Fun.id ~expected:"{B}"
      (cex "{(A | B)*}" "{A*}");
    expect "tick first" Fun.id ~expected:"{1}" (cex "⊤" "{A*}");
    expect "catch-all counterexample" Fun.id ~expected:"{_ & ~(1 | A)}"
      (cex "{_}" "{A | 1}");
    expect "no counterexample" Fun.id ~expected:"none" (cex "{A; B}" "{A; _*}");
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
    expect "name" Fun.id ~expected:"regular-traces" G.name;
    expect "unit" G.show ~expected:(lit "{0}") G.one;
    expect "of_nat" G.show ~expected:(lit "{4}") (G.of_nat 4);
    expect "unit least" show_bool ~expected:false G.unit_least;
    expect "commutative" show_bool ~expected:false G.commutative;
    expect "no runtime bounds" show_bool ~expected:false G.needs_op_bounds;
    expect "atomic" show_bool ~expected:true (G.is_atomic "Send" (lit "{Send}"));
    expect "not atomic" show_bool ~expected:false
      (G.is_atomic "Send" (lit "{Send | Read}"));
    expect "time shadow" G.show ~expected:(lit "{1 | 2 | 3}")
      (G.of_bounds (1, 3));
    check "no implied bounds" (G.implied_bounds bounds (lit "{Send}") = None) "";
    expect "events" show_names ~expected:[ "Read"; "Send" ]
      (G.events (lit "{Send; 2; Read*}"));
  ]

(* Random regular expressions over the names [A] and [B], with a third name
   [C] occurring only in some. *)
let random_regex state =
  let atom () =
    match Random.State.int state 6 with
    | 0 -> Grade.Letter "A"
    | 1 -> Grade.Letter "B"
    | 2 -> Grade.Tick (Random.State.int state 3)
    | 3 -> Grade.Any
    | 4 -> Grade.Letter "C"
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
  go 4

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

let grade_of_word w =
  let letter = function T -> Grade.Tick 1 | Op name -> Grade.Letter name in
  match List.map letter w with
  | [] -> G.one
  | r :: rs ->
      G.of_lit
        (Grade.Braces (List.fold_left (fun r s -> Grade.Seq (r, s)) r rs))

let word_grades = List.map (fun w -> (w, grade_of_word w)) words

let samples =
  let state = Random.State.make [| 2024 |] in
  List.init 300 (fun _ -> random_regex state)

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
                     (rho = rho')
                     ("read back as " ^ G.show rho')
               | Error reason -> check ("round trip " ^ G.show rho) false reason);
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

let take n l = List.filteri (fun i _ -> i < n) l

(* Mutual inclusion is structural equality. *)
let canonical_samples =
  let sample = take 80 nonempty in
  List.concat_map
    (fun rho ->
      List.filter_map
        (fun rho' ->
          let same = G.leq bounds rho rho' && G.leq bounds rho' rho in
          if same = (rho = rho') then None
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
         (fun (m, n) -> eq (G.of_nat (m + n)) (G.mul (G.of_nat m) (G.of_nat n)))
         [ (0, 0); (0, 3); (2, 5); (7, 1) ])
      "";
  ]

let () =
  let checks =
    printing @ lexing @ errors @ canonicity @ inclusion @ alignment @ properties
    @ semantics @ canonical_samples @ laws
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
