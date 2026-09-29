open Grade
module Letters = SymbolicRegex.Letters

module Regex = SymbolicRegex.Make (struct
  let letters = SymbolicRegex.Atoms
end)

module D = Regex.Decide (Regex.Concrete)

type t = { names : string list; regex : Regex.t }
(* The letters of [regex] are [tick], the operation [names] in increasing
   order, and the catch-all letter [Letters.others names]. *)

let name = "regex-upper-bound-plain"
let merge names names' = List.sort_uniq String.compare (names @ names')
let atom name = Regex.letters (Letters.name name)
let tick = Regex.letters Letters.tick
let ticks = Regex.ticks

(** [any names] is the union of the letters over [names]. *)
let any names =
  Regex.union
    ((tick :: List.map atom names) @ [ Regex.letters (Letters.others names) ])

(** [of_regex r] is the grade of [r] over the names it mentions, the wildcard
    being the union of the letters over them; it may be empty. *)
let of_regex r =
  let names = regex_names r in
  let rec go = function
    | Letter name -> atom name
    | Tick n -> ticks n
    | Any -> any names
    | Seq (r, s) -> Regex.concat (go r) (go s)
    | Union (r, s) -> Regex.union [ go r; go s ]
    | Inter (r, s) -> Regex.inter [ go r; go s ]
    | Star r -> Regex.star (go r)
    | Compl r -> Regex.compl (go r)
  in
  { names; regex = go r }

(** [Rebuild (T)] rebuilds the expressions by the smart constructors of [T]. *)
module Rebuild (T : SymbolicRegex.S) = struct
  (** [map letter r] is [r] with each letter [p] replaced by [letter p], for a
      [letter] that maps [tick] to itself, so that runs of ticks are kept; the
      shared subexpressions of [r] are rebuilt once. *)
  let map letter r =
    let table = Hashtbl.create 64 in
    let rec go r =
      match Hashtbl.find_opt table (Regex.hash r) with
      | Some r' -> r'
      | None ->
          let r' = rebuild r in
          Hashtbl.add table (Regex.hash r) r';
          r'
    and rebuild r =
      match Regex.view r with
      | Empty -> T.empty
      | Eps -> T.eps
      | Letters p -> letter p
      | Ticks n -> T.ticks n
      | Concat (r, s) -> T.concat (go r) (go s)
      | Union rs -> T.union (List.map go rs)
      | Inter rs -> T.inter (List.map go rs)
      | Compl r -> T.compl (go r)
      | Star r -> T.star (go r)
    in
    go r
end

module Substitution = Rebuild (Regex)

(** [align names rho] is the expression of [rho] over [names], which include
    those of [rho]: its catch-all letter is replaced by the union of the
    catch-all letter over [names] and the names only [names] list. *)
let align names rho =
  if List.equal String.equal names rho.names then rho.regex
  else
    let other = Letters.others rho.names in
    let others =
      Regex.union
        (Regex.letters (Letters.others names)
        :: List.map atom
             (List.filter (fun name -> not (List.mem name rho.names)) names))
    in
    Substitution.map
      (fun p -> if Letters.equal p other then others else Regex.letters p)
      rho.regex

(** [lift2 op rho rho'] is [op] on the expressions of [rho] and [rho'] over the
    union of their names. *)
let lift2 op rho rho' =
  let names = merge rho.names rho'.names in
  { names; regex = op (align names rho) (align names rho') }

let decide2 decide rho rho' =
  let names = merge rho.names rho'.names in
  decide (align names rho) (align names rho')

let one = { names = []; regex = Regex.eps }
let mul = lift2 Regex.concat
let join = lift2 (fun r s -> Regex.union [ r; s ])
let top = { names = []; regex = Regex.top }
let leq _bounds = decide2 D.subset
let leq_symbol = "<="
let equal _bounds = decide2 D.equal
let is_top _bounds = decide2 D.subset top

let compare rho rho' =
  match List.compare String.compare rho.names rho'.names with
  | 0 -> Regex.compare_form rho.regex rho'.regex
  | c -> c

let hash rho = combine (hash_list String.hash rho.names) (Regex.hash rho.regex)

(* Delays in whole time steps: [n] steps are the word [tickⁿ]. *)
module Delay : Delay.STEPPED with type t = int = Delay.Nat

let of_delay d = { names = []; regex = ticks (Delay.to_int d) }
let unit_least = false
let commutative = false
let needs_op_bounds = false
let implied_bounds _bounds _rho = None
let inhabited _bounds _rho = true

(* The delays of [lo] to [hi] time steps. *)
let of_bounds (lo, hi) =
  {
    names = [];
    regex =
      Regex.union (List.init (max 1 (hi - lo + 1)) (fun k -> ticks (lo + k)));
  }

let is_atomic name rho =
  decide2 D.equal rho { names = [ name ]; regex = atom name }

(** [letter names p] is the letter over [names] of the letter [p] of an
    expression over them: [p] itself, or, for the catch-all letter of an
    expression mentioning fewer names, the catch-all letter over [names]. *)
let letter names (p : Letters.t) =
  match p.names with Except _ -> Letters.others names | Only _ -> p

let counterexample _bounds rho rho' =
  let names = merge rho.names rho'.names in
  Option.map
    (fun word ->
      {
        names;
        regex =
          List.fold_right
            (fun p r -> Regex.concat (Regex.letters (letter names p)) r)
            word Regex.eps;
      })
    (D.shortest
       (Regex.inter [ align names rho; Regex.compl (align names rho') ]))

let of_lit = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> { names = []; regex = ticks n }
  | Top -> top
  | Braces r as lit ->
      let rho = of_regex r in
      if D.is_empty rho.regex then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else rho
  | lit ->
      invalid_lit lit
        "grades are regular expressions '{...}', plain integers or '⊤', not %s"
        (describe_lit lit)

(** {1 Letter sets} *)

module Conversion = Rebuild (SymbolicRegex)

(* The expressions over letter sets of the grades converted, by the numbers of
   their expressions. *)
let converted : (int, SymbolicRegex.t) Hashtbl.t = Hashtbl.create 64

let symbolic rho =
  match Hashtbl.find_opt converted (Regex.hash rho.regex) with
  | Some r -> r
  | None ->
      let r = Conversion.map SymbolicRegex.letters rho.regex in
      Hashtbl.add converted (Regex.hash rho.regex) r;
      r

let events rho = SymbolicRegex.names (symbolic rho)
let canonical rho = RegularTraceGradeDerivative.canonical (symbolic rho)
let show rho = RegularTraceGradeDerivative.show (symbolic rho)
let witnesses ~degree:_ _bounds = Grade.sampled mul

(** {1 Runs over given names} *)

let runs names rho =
  let letters =
    Array.of_list
      (Letters.tick
      :: List.map
           (fun name ->
             if List.mem name rho.names then Letters.name name
             else Letters.others rho.names)
           names)
  in
  {
    Dfa.start = rho.regex;
    step = (fun r a -> Regex.derivative letters.(a) r);
    accepts = Regex.nullable;
    dead = D.is_empty;
    lead = Regex.lead;
    leap = (fun r k -> Regex.leap k r);
  }

module Tables = Dfa.Implicit (struct
  type t = Regex.t

  let compare = Regex.compare_form
end)

let concrete names rho =
  Tables.canonical (List.length names + 1) (runs names rho)
