open Grade

(* The grade over the canonical automata of its languages. *)
module Automata = struct
  type t = { automaton : DelayAutomaton.t; expression : regex }
  (* The [expression] denotes the language [automaton]; it is read only by the
     printing. *)

  let name = "regex-upper-bound-rational-automata"
  let automaton rho = rho.automaton

  let of_regex expression =
    { automaton = DelayRegex.automaton expression; expression }

  let one = of_regex (Tick 0)
  let top = of_regex (Star Any)
  let equal _bounds rho rho' = DelayAutomaton.equal rho.automaton rho'.automaton
  let is_top _bounds rho = DelayAutomaton.equal rho.automaton top.automaton
  let leq _bounds rho rho' = DelayAutomaton.subset rho.automaton rho'.automaton
  let leq_symbol = "<="
  let compare rho rho' = DelayAutomaton.compare rho.automaton rho'.automaton
  let hash rho = DelayAutomaton.hash rho.automaton

  (* [concatenation r s] is the expression [r; s], the factors of both
     concatenations listed in turn, the delays [0] left out and adjacent delays
     added. *)
  let concatenation r s =
    let rec factors = function
      | Seq (r, s) -> factors r @ factors s
      | r -> [ r ]
    in
    let delay = function
      | Tick n -> Some (Rational.of_int n)
      | Frac q -> Some q
      | _ -> None
    in
    let rec merge = function
      | x :: y :: rest -> (
          match (delay x, delay y) with
          | Some d, Some e -> merge (rational_tick (Rational.add d e) :: rest)
          | _ -> x :: merge (y :: rest))
      | factors -> factors
    in
    match
      merge
        (List.filter
           (function Tick 0 -> false | _ -> true)
           (factors r @ factors s))
    with
    | [] -> Tick 0
    | r :: rs -> List.fold_left (fun r s -> Seq (r, s)) r rs

  (* A product with the unit and a join with a grade below are the other
     operand, and the expression of a product is a {!concatenation}, which keeps
     the expressions printed short. *)
  let mul rho rho' =
    if DelayAutomaton.equal rho.automaton one.automaton then rho'
    else if DelayAutomaton.equal rho'.automaton one.automaton then rho
    else
      {
        automaton = DelayAutomaton.concat rho.automaton rho'.automaton;
        expression = concatenation rho.expression rho'.expression;
      }

  let join rho rho' =
    if DelayAutomaton.subset rho'.automaton rho.automaton then rho
    else if DelayAutomaton.subset rho.automaton rho'.automaton then rho'
    else
      {
        automaton = DelayAutomaton.union rho.automaton rho'.automaton;
        expression = Union (rho.expression, rho'.expression);
      }

  module Delay : Delay.MEASURED with type t = Rational.t = Delay.Rational

  let of_delay d = of_regex (rational_tick d)
  let unit_least = false
  let commutative = false
  let needs_op_bounds = false
  let implied_bounds _bounds _rho = None
  let inhabited _bounds _rho = true
  let events rho = DelayAutomaton.names rho.automaton

  let of_bounds = function
    | Closed lo, Closed hi when Rational.equal lo hi -> of_delay lo
    | lo, hi -> of_regex (Delays (lo, hi))

  let is_atomic name rho =
    DelayAutomaton.equal rho.automaton (of_regex (Letter name)).automaton

  let counterexample _bounds rho rho' =
    Option.map
      (fun word -> of_regex (DelayRegex.of_word word))
      (DelayAutomaton.counterexample rho.automaton rho'.automaton)

  (* [negative_delay r] is a negative delay [r] holds, if any. *)
  let rec negative_delay = function
    | Tick n when n < 0 -> Some (Rational.of_int n)
    | Frac q when Rational.sign q < 0 -> Some q
    | Letter _ | Tick _ | Frac _ | Delays _ | Any -> None
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> (
        match negative_delay r with
        | Some q -> Some q
        | None -> negative_delay s)
    | Star r | Compl r -> negative_delay r

  let of_lit = function
    | (Int _ | Rat _) as lit -> (
        match Delay.read lit with
        | Some d -> of_delay d
        | None -> invalid_lit lit "grades must be non-negative")
    | Top -> top
    | Braces r as lit -> (
        match negative_delay r with
        | Some q ->
            invalid_lit lit "delays are non-negative, not %s" (Rational.show q)
        | None ->
            let rho = of_regex r in
            if DelayAutomaton.is_empty rho.automaton then
              invalid_lit lit
                "this regular expression denotes the empty language, but \
                 grades are non-empty"
            else rho)
    | lit ->
        invalid_lit lit
          "grades are regular expressions '{...}', non-negative numbers or \
           '⊤', not %s"
          (describe_lit lit)

  let show rho =
    if DelayAutomaton.equal rho.automaton top.automaton then "⊤"
    else "{" ^ show_regex rho.expression ^ "}"

  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

include Automata

let name = "regex-upper-bound-rational-symbolic"
