open Grade

(* [concatenation r s] is the expression [r; s], the factors of both
   concatenations listed in turn, the delays [0] left out, adjacent budget
   delays added and runs of factors of the same base joined into bounded
   repetitions ({!Grade.sequence}); adjacent strict delays stay apart, as
   distinct words. *)
let concatenation r s =
  let rec factors = function
    | Seq (r, s) -> factors r @ factors s
    | r -> [ r ]
  in
  let value = function
    | Tick n -> Rational.of_int n
    | Frac q -> q
    | _ -> invalid_arg "RegularTraceGradeRational.concatenation: no delay"
  in
  let sum x y = rational_tick (Rational.add (value x) (value y)) in
  let rec merge = function
    | ((Tick _ | Frac _) as x) :: ((Tick _ | Frac _) as y) :: rest ->
        merge (sum x y :: rest)
    | x :: rest -> x :: merge rest
    | [] -> []
  in
  sequence
    (merge
       (List.filter
          (function Tick 0 | Strict (Tick 0) -> false | _ -> true)
          (factors r @ factors s)))

(* The languages of the grades. *)
module type LANGUAGE = sig
  type t

  val of_regex : regex -> t
  val of_strict_regex : regex -> t
  val strict_top : t
  val concat : t -> t -> t
  val union : t -> t -> t
  val is_empty : t -> bool
  val is_top : t -> bool
  val subset : t -> t -> bool
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val names : t -> string list
  val counterexample : t -> t -> DelayAutomaton.symbol list option
end

(* The grade over the languages [L], named [N.name]. *)
module Make
    (L : LANGUAGE)
    (N : sig
      val name : string
    end) =
struct
  type t = { language : L.t; expression : regex }
  (* The [expression] denotes the [language]; it is read only by the
     printing. *)

  let name = N.name
  let language rho = rho.language
  let expression rho = rho.expression
  let of_regex expression = { language = L.of_regex expression; expression }
  let one = of_regex (Tick 0)
  let top = of_regex (Star Any)
  let equal _bounds rho rho' = L.equal rho.language rho'.language
  let is_top _bounds rho = L.is_top rho.language
  let leq _bounds rho rho' = L.subset rho.language rho'.language
  let leq_symbol = "<="
  let compare rho rho' = L.compare rho.language rho'.language
  let hash rho = L.hash rho.language

  (* A product with the unit and a join with a grade below are the other
     operand, and the expression of a product is a {!concatenation}, which keeps
     the expressions printed short. *)
  let mul rho rho' =
    if L.equal rho.language one.language then rho'
    else if L.equal rho'.language one.language then rho
    else
      {
        language = L.concat rho.language rho'.language;
        expression = concatenation rho.expression rho'.expression;
      }

  let join rho rho' =
    if L.subset rho'.language rho.language then rho
    else if L.subset rho.language rho'.language then rho'
    else
      {
        language = L.union rho.language rho'.language;
        expression = Union (rho.expression, rho'.expression);
      }

  module Delay : Delay.MEASURED with type t = Rational.t = Delay.Rational

  let of_delay d = of_regex (rational_tick d)
  let unit_least = false
  let plus _ = None
  let commutative = false
  let needs_op_bounds = false
  let duration_bounds _bounds _ = None
  let inhabited _bounds _rho = true
  let events rho = L.names rho.language

  let of_bounds = function
    | Closed lo, Closed hi when Rational.equal lo hi -> of_delay lo
    | lo, hi -> of_regex (Delays (lo, hi))

  let is_atomic name rho =
    L.equal rho.language (of_regex (Letter name)).language

  let counterexample _bounds rho rho' =
    Option.map
      (fun word -> of_regex (DelayRegex.of_word word))
      (L.counterexample rho.language rho'.language)

  let of_lit = function
    | (Int _ | Rat _) as lit -> (
        match Delay.read lit with
        | Some d -> of_delay d
        | None -> invalid_lit lit "grades must be non-negative")
    | Top -> top
    | Braces r as lit ->
        check_delays lit r;
        let rho = component_of_lit lit ~context:"" of_regex r in
        if L.is_empty rho.language then
          invalid_lit lit
            "this regular expression denotes the empty language, but grades \
             are non-empty"
        else rho
    | lit ->
        invalid_lit lit
          "grades are regular expressions `{...}`, non-negative numbers or \
           `⊤`, not %s"
          (describe_lit lit)

  let accepts = reads_lit of_lit

  let show rho =
    if L.is_top rho.language || L.compare rho.language L.strict_top = 0 then "⊤"
    else "{" ^ show_regex rho.expression ^ "}"

  (** The literals, the delays and the top of the rigid grades of timed
      operations, with strict delays. *)
  module Strict = struct
    type grade = t
    type delay = Rational.t

    let of_regex expression =
      { language = L.of_strict_regex expression; expression }

    let top = { language = L.strict_top; expression = Star Any }
    let of_delay d = of_regex (Strict (rational_tick d))

    let of_lit = function
      | (Int _ | Rat _) as lit -> (
          match Delay.read lit with
          | Some d -> of_regex (rational_tick d)
          | None -> invalid_lit lit "grades must be non-negative")
      | Top -> top
      | Braces r as lit ->
          check_delays lit r;
          let rho = of_regex r in
          if L.is_empty rho.language then
            invalid_lit lit
              "this regular expression denotes the empty language, but grades \
               are non-empty"
          else rho
      | lit ->
          invalid_lit lit
            "grades are regular expressions `{...}`, non-negative numbers or \
             `⊤`, not %s"
            (describe_lit lit)

    let accepts = reads_lit of_lit
  end

  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

(* The canonical automata of the languages. *)
module Automata = struct
  include
    Make
      (struct
        include DelayAutomaton

        let of_regex = DelayRegex.automaton
        let universal = of_regex (Star Any)
        let of_strict_regex = of_regex
        let strict_top = universal
        let is_top a = equal a universal
      end)
      (struct
        let name = "regex-upper-bound-rational-automata"
      end)

  let automaton = language
end

(* The expressions in normal form, decided by their gap derivatives. *)
include
  Make
    (struct
      include RationalRegex

      let union r s = union [ r; s ]
      let is_top r = subset top r
      let compare = compare_form
    end)
    (struct
      let name = "regex-upper-bound-rational-symbolic"
    end)

let form = language
