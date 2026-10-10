open Grade
module R = SymbolicRegex
module Letters = SymbolicRegex.Letters

module type S = sig
  include Grade.S with type t = SymbolicRegex.t and type Delay.t = Delay.Nat.t

  val of_regex : Grade.regex -> t
  val concrete : string list -> t -> Dfa.t
  val traces : string list -> t -> t Dfa.automaton
  val canonical : t -> LetterRegex.t option
end

let ticks = R.ticks

let rec of_regex = function
  | Letter name -> R.letters (Letters.name name)
  | Tick n -> ticks n
  | Frac q -> fractional_tick q
  | Delays (lo, hi) -> of_regex (tick_delays lo hi)
  | Any -> R.letters Letters.any
  | Seq (r, s) -> R.concat (of_regex r) (of_regex s)
  | Union (r, s) -> R.union [ of_regex r; of_regex s ]
  | Inter (r, s) -> R.inter [ of_regex r; of_regex s ]
  | Star r -> R.star (of_regex r)
  | Compl r -> R.compl (of_regex r)

(** {1 Shared by the implementations} *)

module Constants = struct
  (* Delays in whole time steps: [n] steps are the word [tickⁿ]. *)
  module Delay : Delay.STEPPED with type t = int = Delay.Nat

  let leq_symbol = "<="
  let unit_least = false
  let commutative = false
  let needs_op_bounds = false
  let implied_bounds _bounds _rho = None
  let inhabited _bounds _rho = true
end

let of_lit_with ~ticks ~top ~of_regex ~is_empty = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> ticks n
  | Top -> top
  | Braces r as lit ->
      check_delays lit r;
      let rho = component_of_lit lit ~context:"" of_regex r in
      if is_empty rho then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else rho
  | lit ->
      invalid_lit lit
        "grades are regular expressions '{...}', plain integers or '⊤', not %s"
        (describe_lit lit)

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

module type DECISIONS = sig
  val is_empty : R.t -> bool
  val subset : R.t -> R.t -> bool
  val equal : R.t -> R.t -> bool
  val shortest : R.t -> R.t option
end

module ByLetters (Alphabet : SymbolicRegex.ALPHABET) = struct
  include R.Decide (Alphabet)

  (* The word is concatenated from its end, each run of ticks joining the
     next letter [tick] to it. *)
  let shortest r =
    Option.map
      (fun word ->
        List.fold_right
          (fun m r -> R.concat (R.letters (representative m)) r)
          word R.eps)
      (shortest r)
end

module ByGaps (Alphabet : SymbolicRegex.ALPHABET) = struct
  include R.GapDecide (Alphabet)

  let shortest r =
    Option.map
      (fun (steps, last) ->
        List.fold_right
          (fun (d, m) r ->
            R.concat (ticks d) (R.concat (R.letters (representative m)) r))
          steps (ticks last))
      (shortest r)
end

module Make
    (Alphabet : SymbolicRegex.ALPHABET)
    (D : DECISIONS)
    (Name : sig
      val name : string
    end) =
struct
  type t = R.t

  let name = Name.name
  let of_regex = of_regex
  let one = R.eps
  let mul = R.concat
  let join rho rho' = R.union [ rho; rho' ]
  let top = R.top
  let leq _bounds = D.subset
  let equal _bounds = D.equal
  let is_top _bounds = D.subset top
  let compare = R.compare_form
  let hash = R.hash

  include Constants

  let of_delay d = ticks (Delay.to_int d)
  let events = R.names

  (* The delays of [lo] to [hi] time steps. *)
  let of_bounds b =
    let lo, hi = hull b in
    R.runs lo hi

  let is_atomic name rho = D.equal rho (R.letters (Letters.name name))

  let counterexample _bounds rho rho' =
    D.shortest (R.inter [ rho; R.compl rho' ])

  let of_lit = of_lit_with ~ticks ~top ~of_regex ~is_empty:D.is_empty

  (** {1 Traces over given names} *)

  (** [letters names] is the letter set of each letter over [names]: [tick],
      numbered [0], and the names, numbered from [1] in their order. *)
  let letters names = Array.of_list (Letters.tick :: List.map Letters.name names)

  (* The emptiness of the states of the automaton of traces, decided by
     derivatives by letters, as the automaton is explored. *)
  module Letterwise = R.Decide (Alphabet)

  let traces names rho =
    let letters = letters names in
    {
      Dfa.start = rho;
      step = (fun r a -> R.derivative letters.(a) r);
      accepts = R.nullable;
      dead = Letterwise.is_empty;
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
  Make (R.Minterms) (ByGaps (R.Minterms))
    (struct
      let name = "regex-upper-bound-symbolic"
    end)

module Concrete =
  Make (R.Concrete) (ByLetters (R.Concrete))
    (struct
      let name = "regex-upper-bound-symbolic-by-letters"
    end)
