open Grade
module L = RegularTraceGradeRational
module A = DelayAutomaton
module Closure = DelayCostClosure

(* [world endpoint bounds rhos] is the operations of a comparison of the grades
   [rhos], each with the [endpoint] of its runtime bounds as its cost: the
   names [rhos] mention, and of the other declared operations, which [rhos] do
   not tell apart, the least name of each cost. *)
let world endpoint bounds rhos =
  let mentioned =
    List.sort_uniq String.compare (List.concat_map L.events rhos)
  in
  let cost name = endpoint (bounds.cost name) in
  let others =
    List.filter
      (fun name -> not (List.mem name mentioned))
      (List.sort_uniq String.compare bounds.operations)
  in
  let representatives =
    List.fold_left
      (fun reps name ->
        let c = cost name in
        if List.exists (fun (_, c') -> Rational.equal c c') reps then reps
        else (name, c) :: reps)
      [] others
  in
  List.sort
    (fun (n, _) (n', _) -> String.compare n n')
    (List.map (fun name -> (name, cost name)) mentioned @ representatives)

type order = {
  decide : Closure.world -> A.t -> A.t -> A.symbol list option;
  endpoint : runtime -> Rational.t;
  top : L.t;
}
(* An order on runs: the search for a word of the lesser grade outside the
   closure of the greater one, the end of the runtime bounds it reads as the
   cost of an operation, and the representation of its greatest grade. *)

let allowance = { decide = Closure.allowance; endpoint = snd; top = L.top }
let coverage = { decide = Closure.coverage; endpoint = fst; top = L.one }

(* [find order bounds rho rho'] is a word of [rho] outside the closure of [rho']
   under [order]; there is none if [rho] and [rho'] are the same language or
   [rho'] is the top. *)
let find order bounds rho rho' =
  if L.compare rho rho' = 0 || L.compare rho' order.top = 0 then None
  else
    order.decide
      (world order.endpoint bounds [ rho; rho' ])
      (L.automaton rho) (L.automaton rho')

let leq order bounds rho rho' = Option.is_none (find order bounds rho rho')

let is_top order bounds rho =
  L.compare rho order.top = 0 || leq order bounds order.top rho

let counterexample order bounds rho rho' =
  Option.map
    (fun word -> L.of_lit (Braces (DelayRegex.of_word word)))
    (find order bounds rho rho')

let inhabited bounds rho =
  Closure.inhabited
    (world (Fun.const Rational.zero) bounds [ rho ])
    (L.automaton rho)

let implied_bounds bounds lower upper =
  match
    ( Closure.min_weight (world fst bounds [ lower ]) (L.automaton lower),
      Closure.max_weight (world snd bounds [ upper ]) (L.automaton upper) )
  with
  | Some fastest, Some slowest -> Some (fastest, slowest)
  | _ -> None

(* The fields the grades share with the regular trace grade over rational
   delays. *)
module Common = struct
  type t = L.t

  module Delay = L.Delay

  let one = L.one
  let mul = L.mul
  let join = L.join
  let of_delay = L.of_delay
  let leq_symbol = "<="
  let commutative = false
  let needs_op_bounds = true
  let implied_bounds bounds rho = implied_bounds bounds rho rho
  let inhabited = inhabited
  let events = L.events
  let compare = L.compare
  let hash = L.hash
  let is_atomic = L.is_atomic
  let show = L.show
  let witnesses = L.witnesses
end

module Lower = struct
  include Common

  let name = "regex-cost-lower-bound-rational"
  let leq = leq coverage
  let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
  let counterexample = counterexample coverage
  let top = coverage.top
  let is_top = is_top coverage
  let unit_least = false
  let of_lit = function Top -> top | lit -> L.of_lit lit
  let of_bounds (lo, _hi) = L.of_delay lo
end

module Upper = struct
  include Common

  let name = "regex-cost-upper-bound-rational"
  let leq = leq allowance
  let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
  let counterexample = counterexample allowance
  let top = allowance.top
  let is_top = is_top allowance
  let unit_least = true
  let of_lit = L.of_lit
  let of_bounds (_lo, hi) = L.of_delay hi
end

module Interval = struct
  type t = L.t * L.t

  module Delay = L.Delay

  let name = "regex-cost-interval-rational"
  let one = (Lower.one, Upper.one)
  let mul (lo, hi) (lo', hi') = (L.mul lo lo', L.mul hi hi')

  let leq bounds (lo, hi) (lo', hi') =
    Lower.leq bounds lo lo' && Upper.leq bounds hi hi'

  let leq_symbol = "<="
  let top = (Lower.top, Upper.top)
  let join (lo, hi) (lo', hi') = (L.join lo lo', L.join hi hi')
  let equal bounds p q = leq bounds p q && leq bounds q p
  let is_top bounds (lo, hi) = Lower.is_top bounds lo && Upper.is_top bounds hi

  let compare (lo, hi) (lo', hi') =
    match L.compare lo lo' with 0 -> L.compare hi hi' | c -> c

  let hash (lo, hi) = combine (L.hash lo) (L.hash hi)

  let counterexample bounds (lo, hi) (lo', hi') =
    match Lower.counterexample bounds lo lo' with
    | Some e -> Some (e, hi)
    | None -> Option.map (fun e -> (lo, e)) (Upper.counterexample bounds hi hi')

  let unit_least = false
  let commutative = false
  let needs_op_bounds = true
  let implied_bounds bounds (lo, hi) = implied_bounds bounds lo hi
  let inhabited bounds (lo, hi) = inhabited bounds lo && inhabited bounds hi
  let events (lo, hi) = List.sort_uniq String.compare (L.events lo @ L.events hi)

  (** [close ~lower a] is the bound of the open endpoint [a], a delay [q]: the
      delays above [q] for a lower endpoint, and those below [q] for an upper
      one. *)
  let close ~lower a =
    match Delay.read a with
    | Some q ->
        Braces
          (if lower then Delays (Open q, Unbounded)
           else Delays (Closed Rational.zero, Open q))
    | None -> a

  let of_lit = function
    | Top -> top
    | (Int _ | Rat _ | Braces _) as lit ->
        let rho = L.of_lit lit in
        (rho, rho)
    | lit ->
        bounds_of_lit lit ~number:Delay.read ~close ~lower:Lower.of_lit
          ~upper:Upper.of_lit ~unbounded:Upper.top ~bounds:"regular expressions"

  let of_delay d = (L.of_delay d, L.of_delay d)
  let of_bounds (lo, hi) = (L.of_delay lo, L.of_delay hi)
  let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi

  let show (lo, hi) =
    show_bounds (Lower.show lo)
      (if L.compare hi Upper.top = 0 then None else Some (Upper.show hi))

  let witnesses ~degree:_ _bounds = sampled mul
end
