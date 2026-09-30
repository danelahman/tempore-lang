(* Unit tests of the timed regular expressions and their automata, and of the
   regular trace grade over rational delays: the reading and printing of the
   literals by the parser, worked examples, laws of the expressions decided by
   the automata, the delays of an expression computed on the expression and on
   its automaton, the printing of sets of delays read back, membership against
   a direct matcher over timed words that splits delays on a grid, inclusion
   and its counterexamples against that matcher, and the agreement with the
   regular trace grade over whole time steps on integer instances. *)

module Grade = Grades.Grade
module Rational = Grades.Rational
module DelaySet = Grades.DelaySet
module A = Grades.DelayAutomaton
module R = Grades.DelayRegex
module G = Grades.RegularTraceGradeRational
module W = Grades.RegularTraceGrade

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let every name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true ""
  | Some x -> check name false ("fails on " ^ show x)

(* [contains s sub] is whether [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

let q = Rational.make
let qi = Rational.of_int
let bounds = { Grade.cost = (fun _ -> (qi 1, qi 2)); operations = [] }
let show_regex r = "{" ^ Grade.show_regex r ^ "}"

(* {1 Literals} *)

module GS = Grades.GradeSystem.Identity (G)
module Grammar = Parser.Grammar.Make (GS)

(* [parse text] is the grade the parser reads [text] as, in the grade position
   of a box. *)
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

let literals =
  [
    reads "{~1}" ~expected:"{~1}";
    reads "{_ & ~Read}" ~expected:"{_ & ~Read}";
    reads "{>0 & <1}" ~expected:"{>0 & <1}";
    reads "{(1/2)*}" ~expected:"{(0.5)*}";
    reads "{(>=1 & <=2)*}" ~expected:"{(>=1 & <=2)*}";
    reads "{≤1/3 | ≥2}" ~expected:"{<=1/3 | >=2}";
    reads "{>=1&<=2}" ~expected:"{>=1 & <=2}";
    reads "{~<1}" ~expected:"{~<1}";
    reads "{Read; <0.5; (Send | Write)}"
      ~expected:"{Read; <0.5; (Send | Write)}";
    reads "{A; (B; C)}" ~expected:"{A; B; C}";
    reads "{_*}" ~expected:"⊤";
    reads "3/2" ~expected:"{1.5}";
    reads "top" ~expected:"⊤";
    rejects "{<-1}" "unknown comparison '<-'";
    rejects "{Read & <1}" "denotes the empty language";
    rejects "{Read; < -0.5}" "durations must be non-negative";
  ]

(* The comparisons are rejected by the grades of whole time steps. *)
let whole_step_rejections =
  let module WS =
    Grades.GradeSystem.Identity (Grades.RegularTraceGradeDerivative) in
  let module WG = Parser.Grammar.Make (WS) in
  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match WG.payload (Parser.Lexer.tokens ()) lexbuf with
    | _ -> Error "read"
    | exception WG.Error -> Error "parser error"
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message
  in
  [
    (let reason =
       match parse "{Read; <1}" with Error reason -> reason | Ok () -> ""
     in
     check "whole steps: a comparison rejected"
       (contains reason
          "the comparison '<1' denotes a set of rational delays; did you mean \
           to use one of the 'regex-upper-bound-rational', \
           'regex-cost-lower-bound-rational', \
           'regex-cost-upper-bound-rational' or 'regex-cost-interval-rational' \
           grading monoids?")
       reason);
  ]

(* {1 Worked examples} *)

let word text =
  (* A timed word written as delays and names separated by spaces. *)
  List.map
    (fun token ->
      if token.[0] >= 'A' && token.[0] <= 'Z' then
        A.Operation (A.Class.name token)
      else
        A.Delay
          (match String.index_opt token '/' with
          | Some i ->
              q
                (int_of_string (String.sub token 0 i))
                (int_of_string
                   (String.sub token (i + 1) (String.length token - i - 1)))
          | None -> qi (int_of_string token)))
    (List.filter (( <> ) "") (String.split_on_char ' ' text))

let member text grade = A.mem (word text) (G.automaton (lit grade))
let delays grade = DelaySet.show (A.delay_part (G.automaton (lit grade)))

let examples =
  let is name b = check name b "" in
  [
    is "~1 holds the empty word" (member "" "{~1}");
    is "~1 holds Read" (member "Read" "{~1}");
    is "~1 holds 1/2" (member "1/2" "{~1}");
    is "~1 does not hold 1" (not (member "1" "{~1}"));
    is "~1 does not hold 1/2 1/2" (not (member "1/2 1/2" "{~1}"));
    is "~1 holds 1 Read" (member "1 Read" "{~1}");
    expect "delays of ~1" Fun.id ~expected:"<1 | >1" (delays "{~1}");
    is "_ & ~Read holds Write" (member "Write" "{_ & ~Read}");
    is "_ & ~Read holds 1/3" (member "1/3" "{_ & ~Read}");
    is "_ & ~Read does not hold Read" (not (member "Read" "{_ & ~Read}"));
    is "_ & ~Read does not hold the empty word" (not (member "" "{_ & ~Read}"));
    is "_ & ~Read does not hold Write Write"
      (not (member "Write Write" "{_ & ~Read}"));
    expect "delays of >0 & <1" Fun.id ~expected:">0 & <1" (delays "{>0 & <1}");
    is ">0 & <1 does not hold 1" (not (member "1" "{>0 & <1}"));
    expect "delays of (1/2)*" Fun.id ~expected:"(0.5)*" (delays "{(1/2)*}");
    is "(1/2)* holds 3/2" (member "3/2" "{(1/2)*}");
    is "(1/2)* does not hold 5/4" (not (member "5/4" "{(1/2)*}"));
    expect "delays of (>=1 & <=2)*" Fun.id ~expected:"0 | >=1"
      (delays "{(>=1 & <=2)*}");
    expect "delays of _; _" Fun.id ~expected:">0" (delays "{_; _}");
    is "Read; <1; Send holds Read 1/4 1/4 Send"
      (member "Read 1/4 1/4 Send" "{Read; <1; Send}");
    is "Read; <1; Send does not hold Read 1/2 1/2 Send"
      (not (member "Read 1/2 1/2 Send" "{Read; <1; Send}"));
  ]

(* {1 Laws of the expressions} *)

let same a b = G.equal bounds (lit a) (lit b)

let laws =
  let is name b = check name b "" in
  [
    is "_* is the top" (G.is_top bounds (lit "{_*}"));
    is "1; 1 = 2" (same "{1; 1}" "{2}");
    is "1/2; 1/2 = 1" (same "{1/2; 1/2}" "{1}");
    is "~1 & >=0 = <1 | >1" (same "{~1 & >=0}" "{<1 | >1}");
    is "_ & (_; _) = >0" (same "{_ & (_; _)}" "{>0}");
    is "(_ & (_; _))* & ~(1; _*) = <1"
      (same "{(_ & (_; _))* & ~(1; _*)}" "{<1}");
    is "(>0)* = >=0" (same "{(>0)*}" "{>=0}");
    is "2* & 3* = 6*" (same "{2* & 3*}" "{6*}");
    is "the unit is 0" (same "{0}" "{<=0}");
    is "~~(A; <1) = A; <1" (same "{~~(A; <1)}" "{A; <1}");
    is "De Morgan" (same "{~(A | >2)}" "{~A & ~(>2)}");
    is "_* ; A ; _* holds every word with an A"
      (member "1/2 B 3 A 1/3" "{_*; A; _*}");
    is "A* = A* ; A*" (same "{A*}" "{A*; A*}");
    is "(A; 1/2)* ; A = A; (1/2; A)*" (same "{(A; 1/2)*; A}" "{A; (1/2; A)*}");
  ]

(* {1 Random expressions} *)

let names = [ "A"; "B"; "C" ]

(* [random_regex st ~depth ~constant] is a random expression over [names],
   the delays and bounds drawn by [constant]. *)
let rec random_regex st ~depth ~constant =
  let int = Random.State.int st in
  let sub () = random_regex st ~depth:(depth - 1) ~constant in
  let pick xs = List.nth xs (int (List.length xs)) in
  match int (if depth = 0 then 4 else 10) with
  | 0 -> Grade.Letter (pick names)
  | 1 -> Grade.rational_tick (constant ())
  | 2 -> Grade.Compare (pick Grade.[ Lt; Le; Gt; Ge ], constant ())
  | 3 -> Grade.Any
  | 4 | 5 -> Grade.Seq (sub (), sub ())
  | 6 -> Grade.Union (sub (), sub ())
  | 7 -> Grade.Inter (sub (), sub ())
  | 8 -> Grade.Compl (sub ())
  | _ -> Grade.Star (sub ())

(* The constants on the grid of halves, up to [5/2]. *)
let halves st () = q (Random.State.int st 6) 2

let expressions =
  let st = Random.State.make [| 31 |] in
  List.init 250 (fun _ -> random_regex st ~depth:3 ~constant:(halves st))

let automata = List.map (fun r -> (r, R.automaton r)) expressions

(* The delays of an expression on the expression and on its automaton. *)
let delay_parts =
  [
    every "delays of the expression and of its automaton" show_regex
      (fun r ->
        DelaySet.equal (R.delays r) (A.delay_part (List.assq r automata)))
      expressions;
  ]

(* The canonical forms: equal languages built differently have equal
   automata. *)
let canonical_forms =
  let some = List.filteri (fun i _ -> i < 40) automata in
  let pairs = List.concat_map (fun x -> List.map (fun y -> (x, y)) some) some in
  let show2 ((r, _), (s, _)) = show_regex r ^ ", " ^ show_regex s in
  [
    every "canonical: union commutative and idempotent" show2
      (fun ((_, a), (_, b)) ->
        A.equal (A.union a b) (A.union b a) && A.equal (A.union a a) a)
      pairs;
    every "canonical: De Morgan" show2
      (fun ((_, a), (_, b)) ->
        A.equal (A.compl (A.union a b)) (A.inter (A.compl a) (A.compl b)))
      pairs;
    every "canonical: the unit of concatenation"
      (fun (r, _) -> show_regex r)
      (fun (_, a) ->
        A.equal (A.concat A.epsilon a) a && A.equal (A.concat a A.epsilon) a)
      some;
    every "canonical: star of a star"
      (fun (r, _) -> show_regex r)
      (fun (_, a) -> A.equal (A.star (A.star a)) (A.star a))
      some;
  ]

(* Sets of delays printed and read back. *)
let delay_printing =
  let st = Random.State.make [| 5 |] in
  let sets =
    List.map
      (fun r -> R.delays r)
      (List.init 300 (fun _ -> random_regex st ~depth:3 ~constant:(halves st)))
  in
  [
    every "sets of delays printed and read back"
      (fun s -> DelaySet.show s)
      (fun s ->
        let r = DelaySet.to_regex s in
        DelaySet.equal (R.delays r) s
        && DelaySet.equal (A.delay_part (R.automaton r)) s
        &&
        match parse ("{" ^ DelaySet.show s ^ "}") with
        | Ok rho -> DelaySet.equal (A.delay_part (G.automaton rho)) s
        | Error _ -> DelaySet.is_empty s)
      sets;
  ]

(* Grades printed and read back. *)
let grade_printing =
  [
    every "grades printed and read back" show_regex
      (fun r ->
        match G.of_lit (Grade.Braces r) with
        | rho -> (
            match parse (G.show rho) with
            | Ok rho' -> G.equal bounds rho rho'
            | Error _ -> false)
        | exception Grade.Invalid_literal _ -> true)
      expressions;
  ]

(* {1 The direct matcher}

   A timed word in gap form [d₀ a₁ d₁ ⋯ aₙ dₙ] has the positions [(i, x)],
   [0 ≤ x ≤ dᵢ] on a grid of [1/grid], and the part between two positions is a
   timed word. The matcher decides whether the part between two positions is
   in an expression by the denotation, splitting the delays at the positions
   only; the tests take their constants and delays on the grid of halves, so
   that the splits they need fall on the finer grid of the positions. *)

let grid = 8

type timed_word = { gaps : Rational.t array; ops : string array }

let of_symbols symbols =
  let gaps, ops, last =
    List.fold_left
      (fun (gaps, ops, d) -> function
        | A.Delay e -> (gaps, ops, Rational.add d e)
        | A.Operation c ->
            let name =
              match (c : A.Class.t).names with
              | Grades.SymbolicRegex.Letters.Only (name :: _) -> name
              | _ -> "Z"
            in
            (d :: gaps, name :: ops, Rational.zero))
      ([], [], Rational.zero) symbols
  in
  {
    gaps = Array.of_list (List.rev (last :: gaps));
    ops = Array.of_list (List.rev ops);
  }

let to_symbols w =
  List.concat
    (List.mapi
       (fun i d ->
         A.Delay d
         ::
         (if i < Array.length w.ops then
            [ A.Operation (A.Class.name w.ops.(i)) ]
          else []))
       (Array.to_list w.gaps))

let show_word w =
  String.concat " "
    (List.concat
       (List.mapi
          (fun i d ->
            Rational.show d
            :: (if i < Array.length w.ops then [ w.ops.(i) ] else []))
          (Array.to_list w.gaps)))

let matches r w =
  let n = Array.length w.ops in
  let steps i =
    Rational.to_int (Rational.mul w.gaps.(i) (qi grid)) |> Option.get
  in
  let at k = q k grid in
  (* Positions are pairs [(i, k)], the offset [k / grid] in gap [i]. *)
  let before (i, k) (j, l) = i < j || (i = j && k <= l) in
  let positions =
    List.concat
      (List.init (n + 1) (fun i -> List.init (steps i + 1) (fun k -> (i, k))))
  in
  let memo = Hashtbl.create 1024 in
  let rec go r s e =
    let key = (r, s, e) in
    match Hashtbl.find_opt memo key with
    | Some b -> b
    | None ->
        let b = eval r s e in
        Hashtbl.add memo key b;
        b
  and eval r ((i, k) as s) ((j, l) as e) =
    let delay () = if i = j then Some (at (l - k)) else None in
    let operation () =
      if j = i + 1 && k = steps i && l = 0 then Some w.ops.(i) else None
    in
    match r with
    | Grade.Letter a -> operation () = Some a
    | Grade.Tick m -> delay () = Some (qi m)
    | Grade.Frac p -> delay () = Some p
    | Grade.Compare (c, p) -> (
        match delay () with
        | Some d -> DelaySet.mem d (DelaySet.compare_with c p)
        | None -> false)
    | Grade.Any -> (
        match delay () with
        | Some d -> Rational.sign d > 0
        | None -> Option.is_some (operation ()))
    | Grade.Seq (r1, r2) ->
        List.exists
          (fun m -> before s m && before m e && go r1 s m && go r2 m e)
          positions
    | Grade.Union (r1, r2) -> go r1 s e || go r2 s e
    | Grade.Inter (r1, r2) -> go r1 s e && go r2 s e
    | Grade.Compl r1 -> not (go r1 s e)
    | Grade.Star r1 ->
        s = e
        || List.exists
             (fun m ->
               m <> s && before s m && before m e && go r1 s m && go r m e)
             positions
  in
  go r (0, 0) (n, steps n)

(* Timed words of up to two operations among [A], [B], [C] and [Z], with
   delays on the grid of halves up to [2]. *)
let timed_words =
  let st = Random.State.make [| 17 |] in
  List.init 120 (fun _ ->
      let n = Random.State.int st 3 in
      {
        gaps = Array.init (n + 1) (fun _ -> q (Random.State.int st 5) 2);
        ops =
          Array.init n (fun _ ->
              List.nth [ "A"; "B"; "C"; "Z" ] (Random.State.int st 4));
      })

let membership =
  let few = automata in
  [
    every "membership against the direct matcher"
      (fun ((r, _), w) -> show_regex r ^ " on " ^ show_word w)
      (fun ((r, a), w) -> A.mem (to_symbols w) a = matches r w)
      (List.concat_map (fun ra -> List.map (fun w -> (ra, w)) timed_words) few);
  ]

(* Inclusion against the matcher: every sampled word of the lesser language is
   in the greater where inclusion holds, and the counterexample, its delays on
   the grid, is in the lesser and not in the greater where it fails. *)
let inclusion =
  let few = List.filteri (fun i _ -> i < 60) automata in
  let pairs = List.concat_map (fun x -> List.map (fun y -> (x, y)) few) few in
  [
    every "inclusion against the direct matcher"
      (fun ((r, _), (s, _)) -> show_regex r ^ " <= " ^ show_regex s)
      (fun ((r, a), (s, b)) ->
        match A.counterexample a b with
        | None ->
            A.subset a b
            && List.for_all
                 (fun w -> (not (matches r w)) || matches s w)
                 timed_words
        | Some symbols ->
            let w = of_symbols symbols in
            (not (A.subset a b))
            && A.mem symbols a
            && (not (A.mem symbols b))
            &&
            if
              Array.for_all
                (fun d -> Rational.is_integer (Rational.mul d (qi grid)))
                w.gaps
              && Array.for_all (fun d -> Rational.compare d (qi 3) <= 0) w.gaps
              && Array.length w.ops <= 3
            then matches r w && not (matches s w)
            else true)
      pairs;
  ]

(* {1 Whole time steps}

   On integer instances the order agrees with that of the regular trace grade
   over whole time steps through the translation [ι]: [ι(_) = 1 | ops] and
   [ι(~r) = ~ι(r) & (ops | 1)*], [ops] the operations [_ & ~(>0)], the identity
   elsewhere: the timed words with whole delays are the words over ticks and
   operations, adjacent ticks merged. *)

let ops =
  Grade.Inter (Grade.Any, Grade.Compl (Grade.Compare (Grade.Gt, Rational.zero)))

let rec iota = function
  | Grade.Any -> Grade.Union (Grade.Tick 1, ops)
  | Grade.Compl r ->
      Grade.Inter
        (Grade.Compl (iota r), Grade.Star (Grade.Union (ops, Grade.Tick 1)))
  | Grade.Seq (r, s) -> Grade.Seq (iota r, iota s)
  | Grade.Union (r, s) -> Grade.Union (iota r, iota s)
  | Grade.Inter (r, s) -> Grade.Inter (iota r, iota s)
  | Grade.Star r -> Grade.Star (iota r)
  | (Grade.Letter _ | Grade.Tick _ | Grade.Frac _ | Grade.Compare _) as r -> r

let whole_steps =
  let st = Random.State.make [| 43 |] in
  let rec whole depth =
    let int = Random.State.int st in
    let sub () = whole (depth - 1) in
    match int (if depth = 0 then 3 else 8) with
    | 0 -> Grade.Letter (List.nth names (int 3))
    | 1 -> Grade.Tick (int 3)
    | 2 -> Grade.Any
    | 3 | 4 -> Grade.Seq (sub (), sub ())
    | 5 -> Grade.Union (sub (), sub ())
    | 6 -> Grade.Inter (Grade.Any, Grade.Compl (sub ()))
    | _ -> Grade.Star (sub ())
  in
  let grades =
    List.filter_map
      (fun r ->
        match (W.of_lit (Grade.Braces r), G.of_lit (Grade.Braces (iota r))) with
        | w, g -> Some (r, w, g)
        | exception Grade.Invalid_literal _ -> None)
      (List.init 60 (fun _ -> whole 3))
  in
  let pairs =
    List.concat_map (fun x -> List.map (fun y -> (x, y)) grades) grades
  in
  [
    every "whole steps: the orders agree through ι"
      (fun ((r, _, _), (s, _, _)) -> show_regex r ^ " <= " ^ show_regex s)
      (fun ((_, w, g), (_, w', g')) ->
        W.leq bounds w w' = G.leq bounds g g'
        && W.equal bounds w w' = G.equal bounds g g')
      pairs;
    every "whole steps: ι is the identity without _ and ~"
      (fun (r, _, _) -> show_regex r)
      (fun (r, _, _) ->
        let rec plain = function
          | Grade.Any | Grade.Compl _ -> false
          | Grade.Seq (r, s) | Grade.Union (r, s) | Grade.Inter (r, s) ->
              plain r && plain s
          | Grade.Star r -> plain r
          | _ -> true
        in
        (not (plain r))
        || G.equal bounds
             (G.of_lit (Grade.Braces r))
             (G.of_lit (Grade.Braces (iota r))))
      grades;
  ]

(* {1 Timing} *)

let timing =
  let quickly name f =
    let start = Sys.time () in
    let holds = f () in
    let time = Sys.time () -. start in
    check name (holds && time < 2.) (Printf.sprintf "in %.2f s" time)
  in
  [
    quickly "({1} | (>10 & <10.01))* is eventually every delay" (fun () ->
        let rho = lit "{A; ({1} | (>10 & <10.01))*; B}" in
        G.leq bounds (lit "{A; >=10010; B}") rho
        && not (G.leq bounds (lit "{A; 10.5; B}") rho));
    quickly "~(1/1000) is two intervals" (fun () ->
        G.equal bounds (lit "{~(1/1000) & >=0}") (lit "{<1/1000 | >1/1000}"));
  ]

let () =
  let checks =
    literals @ whole_step_rejections @ examples @ laws @ delay_parts
    @ canonical_forms @ delay_printing @ grade_printing @ membership @ inclusion
    @ whole_steps @ timing
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
