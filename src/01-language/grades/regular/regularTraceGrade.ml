open Grade
module Letters = SymbolicRegex.Letters
module Expression = RegularTraceGradeDerivative

type t = { names : string list; dfa : Dfa.t; expression : SymbolicRegex.t }
(* The letters of the automaton [dfa] are [tick], the operation [names] in
   increasing order, and the catch-all letter. Only names whose letter the
   language tells apart from the catch-all letter are kept. The [expression]
   denotes the same language: it is built alongside [dfa] by the operations of
   {!RegularTraceGradeDerivative}, and read only by the printing. *)

let name = "regex-upper-bound-letter-automata"
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
  if List.equal String.equal from into then dfa
  else
    let source =
      Array.of_list ((tick :: List.map (letter from) into) @ [ other from ])
    in
    Dfa.relabel (size into) (Array.get source) dfa

(** [restrict names dfa expression] is the grade of the automaton [dfa] over
    [names], without the names that act as the catch-all letter, and of the
    [expression]. *)
let restrict names dfa expression =
  let distinct name = not (Dfa.alike dfa (letter names name) (other names)) in
  let kept = List.filter distinct names in
  { names = kept; dfa = translate ~from:names ~into:kept dfa; expression }

let align names rho = translate ~from:rho.names ~into:names rho.dfa

let lift2 op op' rho rho' =
  let names = merge rho.names rho'.names in
  restrict names
    (op (align names rho) (align names rho'))
    (op' rho.expression rho'.expression)

(** [dfa_of_regex names r] is the automaton over [names] of the regular
    expression [r], whose names are among [names], built by recursion on [r]
    with the product and subset constructions of {!Dfa}, a run of ticks and an
    interval of delays being the chain {!Dfa.ticks}. *)
let dfa_of_regex names =
  let n = size names in
  let rec go = function
    | Letter name -> Dfa.word n [ letter names name ]
    | Tick k -> Dfa.ticks n k (Some k)
    | Frac q -> fractional_tick q
    | Delays (lo, hi) ->
        let lo, hi = tick_interval lo hi in
        Dfa.ticks n lo hi
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
  let names = regex_names r in
  restrict names (dfa_of_regex names r) (Expression.of_regex r)

let one = of_regex (Tick 0)
let mul = lift2 Dfa.concat Expression.mul
let join = lift2 Dfa.union Expression.join
let top = { names = []; dfa = Dfa.all (size []); expression = Expression.top }

let leq _bounds rho rho' =
  let names = merge rho.names rho'.names in
  Dfa.subset (align names rho) (align names rho')

(** [same rho rho'] is whether [rho] and [rho'] denote the same language:
    whether their names and automata are equal. *)
let same rho rho' =
  List.equal String.equal rho.names rho'.names && Dfa.equal rho.dfa rho'.dfa

let equal _bounds = same
let is_top _bounds = same top

let compare rho rho' =
  match List.compare String.compare rho.names rho'.names with
  | 0 -> Dfa.compare rho.dfa rho'.dfa
  | c -> c

let hash rho = combine (hash_list String.hash rho.names) (Dfa.hash rho.dfa)

include Expression.Constants

let of_delay d = of_regex (Tick (Delay.to_int d))
let events rho = rho.names

(* The runs of [lo] to [hi] ticks, the ends of the closed hull. *)
let of_bounds b =
  let lo, hi = hull b in
  restrict []
    (Dfa.ticks (size []) lo (Some (max lo hi)))
    (Expression.of_bounds b)

let is_atomic name rho = same rho (of_regex (Letter name))

let concrete names rho =
  let source = Array.of_list (tick :: List.map (letter rho.names) names) in
  Dfa.relabel (List.length names + 1) (Array.get source) rho.dfa

(** [letters names a] is the letter set of the letter [a] over [names]: [tick],
    a name, or the names other than [names]. *)
let letters names a =
  if a = tick then Letters.tick
  else if a = other names then Letters.others names
  else Letters.name (List.nth names (a - 1))

(** [word names w] is the grade of the word [w] over [names]. *)
let word names w =
  restrict names
    (Dfa.word (size names) w)
    (List.fold_left
       (fun r a ->
         SymbolicRegex.concat r (SymbolicRegex.letters (letters names a)))
       SymbolicRegex.eps w)

let counterexample _bounds rho rho' =
  let names = merge rho.names rho'.names in
  Option.map (word names)
    (Dfa.counterexample (align names rho) (align names rho'))

let of_lit =
  Expression.of_lit_with
    ~ticks:(fun n -> of_regex (Tick n))
    ~top ~of_regex
    ~is_empty:(fun rho -> Dfa.is_empty rho.dfa)

(** {1 Printing} *)

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

let canonical rho =
  let budget = LetterRegex.size (LetterRegex.of_symbolic rho.expression) in
  if Dfa.states rho.dfa > budget then None
  else SymbolicAutomaton.canonical ~budget (symbolic rho)

let show rho =
  LetterRegex.literal
    (Option.value (canonical rho)
       ~default:(LetterRegex.of_symbolic rho.expression))

let witnesses ~degree:_ _bounds = Grade.sampled mul
