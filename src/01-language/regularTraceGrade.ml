open Grade

type t = { names : string list; dfa : Dfa.t }
(* The letters of the automaton [dfa] are [tick], the operation [names] in
   increasing order, and the catch-all letter. Only names whose letter the
   language tells apart from the catch-all letter are kept. *)

let name = "regular-traces"
let tick = 0
let other names = List.length names + 1
let size names = List.length names + 2
let merge names names' = List.sort_uniq String.compare (names @ names')

(** [letter names name] is the letter of the operation [name] over [names]. *)
let letter names name =
  match List.find_index (String.equal name) names with
  | Some i -> i + 1
  | None -> other names

(** [translate ~from ~into dfa] is the automaton [dfa] over the names [from]
    read over the names [into], each name of [into] acting as its letter over
    [from]. *)
let translate ~from ~into dfa =
  if from = into then dfa
  else
    let source =
      Array.of_list ((tick :: List.map (letter from) into) @ [ other from ])
    in
    Dfa.relabel (size into) (Array.get source) dfa

(** [canonical names dfa] is the grade of the automaton [dfa] over [names],
    without the names that act as the catch-all letter. *)
let canonical names dfa =
  let distinct name = not (Dfa.alike dfa (letter names name) (other names)) in
  let kept = List.filter distinct names in
  { names = kept; dfa = translate ~from:names ~into:kept dfa }

let align names rho = translate ~from:rho.names ~into:names rho.dfa

let lift2 op rho rho' =
  let names = merge rho.names rho'.names in
  canonical names (op (align names rho) (align names rho'))

let rec names_of = function
  | Letter name -> [ name ]
  | Tick _ | Any -> []
  | Seq (r, s) | Union (r, s) | Inter (r, s) -> names_of r @ names_of s
  | Star r | Compl r -> names_of r

(** [dfa_of_regex names r] is the automaton over [names] of the regular
    expression [r], whose names are among [names]. *)
let dfa_of_regex names =
  let n = size names in
  let rec go = function
    | Letter name -> Dfa.word n [ letter names name ]
    | Tick k -> Dfa.word n (List.init k (Fun.const tick))
    | Any -> Dfa.letter_set n (List.init n Fun.id)
    | Seq (r, s) -> Dfa.concat (go r) (go s)
    | Union (r, s) -> Dfa.union (go r) (go s)
    | Inter (r, s) -> Dfa.inter (go r) (go s)
    | Star r -> Dfa.star (go r)
    | Compl r -> Dfa.complement (go r)
  in
  go

(** [of_regex r] is the language of [r] over the names it mentions; it may be
    empty. *)
let of_regex r =
  let names = List.sort_uniq String.compare (names_of r) in
  canonical names (dfa_of_regex names r)

let one = of_regex (Tick 0)
let mul = lift2 Dfa.concat
let join = lift2 Dfa.union
let top = { names = []; dfa = Dfa.all (size []) }

let leq _bounds rho rho' =
  let names = merge rho.names rho'.names in
  Dfa.subset (align names rho) (align names rho')

let leq_symbol = "<="
let equal _bounds rho rho' = rho = rho'
let of_nat n = of_regex (Tick (check_nat "RegularTraceGrade" n))
let unit_least = false
let commutative = false
let needs_op_bounds = false
let implied_bounds _bounds _rho = None
let events rho = rho.names

(* [lo] ticks followed by up to [hi - lo] more. *)
let of_bounds (lo, hi) =
  let tick_or_not = Union (Tick 0, Tick 1) in
  of_regex
    (List.fold_left
       (fun r _ -> Seq (r, tick_or_not))
       (Tick lo)
       (List.init (max 0 (hi - lo)) Fun.id))

let is_atomic name rho = rho = of_regex (Letter name)

let counterexample rho rho' =
  let names = merge rho.names rho'.names in
  Option.map
    (fun word -> canonical names (Dfa.word (size names) word))
    (Dfa.counterexample (align names rho) (align names rho'))

let of_lit = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> of_nat n
  | Top -> top
  | Braces r as lit ->
      let rho = of_regex r in
      if Dfa.is_empty rho.dfa then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else rho
  | lit ->
      invalid_lit lit
        "grades are regular expressions '{...}', plain integers or '⊤', not %s"
        (describe_lit lit)

(** {1 Printing} *)

let union_all = function
  | [] -> invalid_arg "RegularTraceGrade.show: empty language"
  | r :: rs -> List.fold_left (fun acc s -> Union (acc, s)) r rs

let seq_all = function
  | [] -> Tick 0
  | r :: rs -> List.fold_left (fun acc s -> Seq (acc, s)) r rs

let letter_regex names a =
  if a = tick then Tick 1 else Letter (List.nth names (a - 1))

(** [set_regex names s] is a regular expression for the one-letter words of the
    set [s] of letters over [names]. *)
let set_regex names s =
  let missing =
    List.filter (fun a -> not (List.mem a s)) (List.init (other names) Fun.id)
  in
  match (List.mem (other names) s, missing) with
  | false, _ -> union_all (List.map (letter_regex names) s)
  | true, [] -> Any
  | true, missing ->
      Inter (Any, Compl (union_all (List.map (letter_regex names) missing)))

(** [merge_ticks rs] joins adjacent delays of a concatenation. *)
let merge_ticks rs =
  let add r acc =
    match (r, acc) with
    | Tick m, Tick n :: acc -> Tick (m + n) :: acc
    | r, acc -> r :: acc
  in
  List.fold_right add rs []

let rec regex_of names = function
  | Dfa.Letters s -> set_regex names s
  | Dfa.Seq parts -> seq_all (merge_ticks (List.map (regex_of names) parts))
  | Dfa.Union parts -> union_all (List.map (regex_of names) parts)
  | Dfa.Star r -> Star (regex_of names r)

(** [show_regex prec r] prints [r] in the literal syntax, in parentheses if its
    operator binds more loosely than the precedence [prec]: [|] is [0], [&] is
    [1], [;] is [2], [~] is [3] and [*] is [4]. *)
let rec show_regex prec r =
  let wrap p s = if prec > p then "(" ^ s ^ ")" else s in
  match r with
  | Letter name -> name
  | Tick n -> string_of_int n
  | Any -> "_"
  | Union (r, s) -> wrap 0 (show_regex 0 r ^ " | " ^ show_regex 1 s)
  | Inter (r, s) -> wrap 1 (show_regex 1 r ^ " & " ^ show_regex 2 s)
  | Seq (r, s) -> wrap 2 (show_regex 2 r ^ "; " ^ show_regex 3 s)
  | Compl r -> wrap 3 ("~" ^ show_regex 3 r)
  | Star r -> wrap 4 (show_regex 4 r ^ "*")

let show rho =
  if Dfa.is_all rho.dfa then "⊤"
  else "{" ^ show_regex 0 (regex_of rho.names (Dfa.to_regex rho.dfa)) ^ "}"
