open Grade

module type LANGUAGE = sig
  include Grade.S

  val concrete : string list -> t -> Dfa.t
end

type order = {
  closure : cost:(int -> int) -> Dfa.t -> int list Dfa.automaton;
  endpoint : int * int -> int;
}
(** An order on runs: the closure it takes of the greater grade, and the end of
    the runtime bounds it reads as the cost of an operation. *)

let allowance = { closure = CostClosure.allowance; endpoint = snd }
let coverage = { closure = CostClosure.coverage; endpoint = fst }

module Subsets = Dfa.Implicit (struct
  type t = int list

  let compare = Stdlib.compare
end)

module Make
    (L : LANGUAGE)
    (Variant : sig
      val suffix : string
    end) =
struct
  (** [alphabet bounds rhos] is the names of the operations of a comparison of
      the grades [rhos]: the declared operations and the names [rhos] mention.
  *)
  let alphabet bounds rhos =
    List.sort_uniq String.compare
      (bounds.operations @ List.concat_map L.events rhos)

  (** [costs endpoint bounds names] is the cost of each letter of an operation
      over [names], the [endpoint] of its runtime bounds. *)
  let costs endpoint bounds names =
    let costs =
      Array.of_list (List.map (fun name -> endpoint (bounds.cost name)) names)
    in
    fun a -> costs.(a - 1)

  (** [find order bounds rho rho'] is a shortest run of [rho] outside the
      closure of [rho'] under [order], with the names its letters index; there
      is none if [rho] and [rho'] are the same language. *)
  let find order bounds rho rho' =
    if L.equal bounds rho rho' then None
    else
      let names = alphabet bounds [ rho; rho' ] in
      let cost = costs order.endpoint bounds names in
      Subsets.counterexample (L.concrete names rho)
        (order.closure ~cost (L.concrete names rho'))
      |> Option.map (fun word -> (names, word))

  (** [grade_of_word (names, word)] is the grade of the single run [word] over
      [names]. *)
  let grade_of_word (names, word) =
    let letter a = if a = 0 then Tick 1 else Letter (List.nth names (a - 1)) in
    L.of_lit
      (Braces (List.fold_left (fun r a -> Seq (r, letter a)) (Tick 0) word))

  let leq order bounds rho rho' = Option.is_none (find order bounds rho rho')

  let counterexample order bounds rho rho' =
    Option.map grade_of_word (find order bounds rho rho')

  (** [weight extreme endpoint bounds rho] is the [extreme] weight of a run of
      [rho], operations costing the [endpoint] of their runtime bounds. *)
  let weight extreme endpoint bounds rho =
    let names = alphabet bounds [ rho ] in
    extreme ~cost:(costs endpoint bounds names) (L.concrete names rho)

  let implied_bounds bounds lower upper =
    match
      ( weight CostClosure.min_weight fst bounds lower,
        weight CostClosure.max_weight snd bounds upper )
    with
    | Some fastest, Some slowest -> Some (fastest, slowest)
    | _ -> None

  (** The fields the grades share with the regular trace grade. *)
  module Common = struct
    type t = L.t

    let one = L.one
    let mul = L.mul
    let join = L.join
    let of_nat = L.of_nat
    let leq_symbol = "<="
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds rho = implied_bounds bounds rho rho
    let events = L.events
    let is_atomic = L.is_atomic
    let show = L.show
  end

  module Lower = struct
    include Common

    let name = "traces-regex-lower" ^ Variant.suffix
    let leq = leq coverage
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample coverage

    (** The unit [{0}], covered by every run. *)
    let top = one

    let unit_least = false
    let of_lit = function Top -> top | lit -> L.of_lit lit
    let of_bounds (lo, _hi) = of_nat lo
  end

  module Upper = struct
    include Common

    let name = "traces-regex-upper" ^ Variant.suffix
    let leq = leq allowance
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample allowance
    let top = L.top
    let unit_least = true
    let of_lit = L.of_lit
    let of_bounds (_lo, hi) = of_nat hi
  end

  module Interval = struct
    type t = L.t * L.t

    let name = "traces-regex-interval" ^ Variant.suffix
    let one = (Lower.one, Upper.one)
    let mul (lo, hi) (lo', hi') = (L.mul lo lo', L.mul hi hi')

    let leq bounds (lo, hi) (lo', hi') =
      Lower.leq bounds lo lo' && Upper.leq bounds hi hi'

    let leq_symbol = "<="
    let top = (Lower.top, Upper.top)
    let join (lo, hi) (lo', hi') = (L.join lo lo', L.join hi hi')
    let equal bounds p q = leq bounds p q && leq bounds q p

    let counterexample bounds (lo, hi) (lo', hi') =
      match Lower.counterexample bounds lo lo' with
      | Some e -> Some (e, hi)
      | None ->
          Option.map (fun e -> (lo, e)) (Upper.counterexample bounds hi hi')

    let unit_least = false
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds (lo, hi) = implied_bounds bounds lo hi

    let events (lo, hi) =
      List.sort_uniq String.compare (L.events lo @ L.events hi)

    let of_lit = function
      | Top -> top
      | (Int _ | Braces _) as lit ->
          let rho = L.of_lit lit in
          (rho, rho)
      | Tuple [ Int n; Int m ] as lit when n > m ->
          invalid_lit lit "interval endpoints must satisfy n <= m"
      | Tuple [ lo; hi ] as lit ->
          let lo = component_of_lit lit ~context:"" Lower.of_lit lo in
          let hi = component_of_lit lit ~context:"" Upper.of_lit hi in
          (lo, hi)
      | lit ->
          invalid_lit lit
            "grades are pairs '({...}, {...})' of regular expressions, or \
             abbreviations of them, not %s"
            (describe_lit lit)

    let of_nat n = (L.of_nat n, L.of_nat n)
    let of_bounds (lo, hi) = (L.of_nat lo, L.of_nat hi)
    let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi
    let show (lo, hi) = "(" ^ Lower.show lo ^ "," ^ Upper.show hi ^ ")"
  end
end

include
  Make
    (RegularTraceGrade)
    (struct
      let suffix = ""
    end)
