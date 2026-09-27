open Grade
module Letters = SymbolicRegex.Letters

type t = { names : string list; dfa : Dfa.t }
(* The letters of the automaton [dfa] are [tick], the operation [names] in
   increasing order, and the catch-all letter. Only names whose letter the
   language tells apart from the catch-all letter are kept. *)

let name = "traces-regex"
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

let counterexample _bounds rho rho' =
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

(** [letters names a] is the letter set of the letter [a] over [names]: [tick],
    a name, or the names other than [names]. *)
let letters names a =
  if a = tick then Letters.tick
  else if a = other names then
    Letters.compl
      (List.fold_left Letters.union Letters.tick (List.map Letters.name names))
  else Letters.name (List.nth names (a - 1))

(** [symbolic rho] is the automaton of [rho] over letter sets. *)
let symbolic rho =
  let letters = List.init (size rho.names) (letters rho.names) in
  let states = List.init (Dfa.states rho.dfa) Fun.id in
  SymbolicAutomaton.of_table
    ~final:(Array.of_list (List.map (Dfa.final rho.dfa) states))
    ~edges:
      (Array.of_list
         (List.map
            (fun q -> List.mapi (fun a p -> (p, Dfa.next rho.dfa q a)) letters)
            states))

let show rho = SymbolicAutomaton.show ~others:[] (symbolic rho)
