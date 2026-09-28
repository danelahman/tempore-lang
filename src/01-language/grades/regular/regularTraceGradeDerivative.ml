open Grade
module R = SymbolicRegex
module Letters = SymbolicRegex.Letters

module type S = sig
  include Grade.S with type t = SymbolicRegex.t

  val of_regex : Grade.regex -> t
  val concrete : string list -> t -> Dfa.t
  val runs : string list -> t -> t Dfa.automaton
  val canonical : t -> LetterRegex.t option
end

let ticks = R.ticks

let rec of_regex = function
  | Letter name -> R.letters (Letters.name name)
  | Tick n -> ticks n
  | Any -> R.letters Letters.any
  | Seq (r, s) -> R.concat (of_regex r) (of_regex s)
  | Union (r, s) -> R.union [ of_regex r; of_regex s ]
  | Inter (r, s) -> R.inter [ of_regex r; of_regex s ]
  | Star r -> R.star (of_regex r)
  | Compl r -> R.compl (of_regex r)

(** [representative m] is the least letter of the block [m] of an alphabet:
    [tick], else its least name, else the block itself, the names the grades
    compared do not mention. *)
let representative (m : Letters.t) =
  match m with
  | { tick = true; _ } -> Letters.tick
  | { names = Only (name :: _); _ } -> Letters.name name
  | m -> m

(** {1 Printing} *)

let canonical rho =
  let budget = LetterRegex.size (LetterRegex.of_symbolic rho) in
  Option.bind
    (SymbolicAutomaton.of_regex ~limit:budget rho)
    (SymbolicAutomaton.canonical ~budget)

(* The printed grades, by the numbers of their normal forms. *)
let printed : (int, string) Hashtbl.t = Hashtbl.create 64

let show rho =
  match Hashtbl.find_opt printed (R.hash rho) with
  | Some text -> text
  | None ->
      let text =
        LetterRegex.literal
          (Option.value (canonical rho) ~default:(LetterRegex.of_symbolic rho))
      in
      Hashtbl.add printed (R.hash rho) text;
      text

module Make
    (Alphabet : SymbolicRegex.ALPHABET)
    (Name : sig
      val name : string
    end) =
struct
  module D = R.Decide (Alphabet)

  type t = R.t

  let name = Name.name
  let of_regex = of_regex
  let one = R.eps
  let mul = R.concat
  let join rho rho' = R.union [ rho; rho' ]
  let top = R.top
  let leq _bounds = D.subset
  let leq_symbol = "<="
  let equal _bounds = D.equal
  let is_top _bounds = D.subset top
  let compare = R.compare_form
  let hash = R.hash
  let of_nat n = ticks (check_nat "RegularTraceGradeDerivative" n)
  let of_duration = whole ~who:"RegularTraceGradeDerivative" of_nat
  let unit_least = false
  let commutative = false
  let needs_op_bounds = false
  let implied_bounds _bounds _rho = None
  let inhabited _bounds _rho = true
  let events = R.names

  (* The delays of [lo] to [hi] time steps. *)
  let of_bounds (lo, hi) =
    R.union (List.init (max 1 (hi - lo + 1)) (fun k -> ticks (lo + k)))

  let is_atomic name rho = D.equal rho (R.letters (Letters.name name))

  (* The word is concatenated from its end, each run of ticks joining the
     next letter [tick] to it. *)
  let counterexample _bounds rho rho' =
    Option.map
      (fun word ->
        List.fold_right
          (fun m r -> R.concat (R.letters (representative m)) r)
          word R.eps)
      (D.shortest (R.inter [ rho; R.compl rho' ]))

  let of_lit = function
    | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
    | Int n -> of_nat n
    | Top -> top
    | Braces r as lit ->
        let rho = of_regex r in
        if D.is_empty rho then
          invalid_lit lit
            "this regular expression denotes the empty language, but grades \
             are non-empty"
        else rho
    | lit ->
        invalid_lit lit
          "grades are regular expressions '{...}', plain integers or '⊤', not \
           %s"
          (describe_lit lit)

  (** {1 Runs over given names} *)

  (** [letters names] is the letter set of each letter over [names]: [tick],
      numbered [0], and the names, numbered from [1] in their order. *)
  let letters names = Array.of_list (Letters.tick :: List.map Letters.name names)

  let runs names rho =
    let letters = letters names in
    {
      Dfa.start = rho;
      step = (fun r a -> R.derivative letters.(a) r);
      accepts = R.nullable;
      dead = D.is_empty;
      lead = R.lead;
      leap = (fun r k -> R.leap k r);
    }

  module Tables = Dfa.Implicit (Int)

  (* No automaton has more than [max_int] states. *)
  let concrete names rho =
    let letters = letters names in
    let a =
      Option.get
        (SymbolicAutomaton.of_derivatives ~limit:Int.max_int
           ~blocks:(Alphabet.blocks [ rho ]) rho)
    in
    let step q x = SymbolicAutomaton.next a q letters.(x) in
    Tables.canonical (Array.length letters)
      {
        start = 0;
        step;
        accepts = SymbolicAutomaton.final a;
        dead = Fun.const false;
        lead = Fun.const 0;
        leap = Dfa.unrolled step;
      }

  let canonical = canonical
  let show = show
  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

include
  Make
    (R.Minterms)
    (struct
      let name = "traces-regex-symbolic"
    end)

module Concrete =
  Make
    (R.Concrete)
    (struct
      let name = "traces-regex-derivatives"
    end)
