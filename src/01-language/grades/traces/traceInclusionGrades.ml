open Grade

module Make (D : Delay.S) (N : TimedTraceGrades.NAMES) = struct
  module Trace = TimedTrace.Base (D)

  module UpperBound = struct
    type t =
      | Within of Trace.traces  (** every run is a listed one *)
      | Unbounded  (** any run; printed as [⊤] *)

    module Delay = D

    let name = "traces-upper-bound" ^ N.suffix
    let one = Within (Trace.of_delay D.zero)

    let mul p q =
      match (p, q) with
      | Within p, Within q -> Within (Trace.product p q)
      | _ -> Unbounded

    let leq _bounds p q =
      match (p, q) with
      | _, Unbounded -> true
      | Unbounded, Within _ -> false
      | Within p, Within q -> Trace.subset p q

    let leq_symbol = "<="
    let top = Unbounded

    let join p q =
      match (p, q) with
      | Within p, Within q -> Within (Trace.union p q)
      | _ -> Unbounded

    let compare p q =
      match (p, q) with
      | Within p, Within q -> Trace.compare p q
      | Unbounded, Within _ -> -1
      | Within _, Unbounded -> 1
      | Unbounded, Unbounded -> 0

    let equal _bounds p q = compare p q = 0
    let is_top _bounds = function Unbounded -> true | Within _ -> false
    let hash = function Within p -> Trace.hash p | Unbounded -> -1

    (** The least run of the left side not listed by the right side; [⊤] itself
        where the right side alone is a set of runs. *)
    let counterexample _bounds p q =
      match (p, q) with
      | _, Unbounded -> None
      | Unbounded, Within _ -> Some Unbounded
      | Within p, Within q ->
          Option.map (fun s -> Within [ s ]) (Trace.missing p q)

    let unit_least = false
    let commutative = false
    let needs_op_bounds = false
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true
    let events = function Within p -> Trace.events p | Unbounded -> []
    let of_delay d = Within (Trace.of_delay d)

    (** The time shadow of exact bounds is their delay, and that of other bounds
        [⊤], which is above every delay between them. The operations declare no
        runtime bounds under these grades, so it is not used. *)
    let of_bounds b =
      let lo, hi = hull b in
      if D.equal lo hi then of_delay lo else Unbounded

    let of_lit = function
      | Top -> Unbounded
      | lit -> Within (Trace.of_lit ~number:N.number lit)

    let is_atomic name p = compare p (Within [ [ Trace.Ev name ] ]) = 0
    let show = function Within p -> Trace.show p | Unbounded -> "⊤"
    let witnesses ~degree:_ _bounds = sampled mul
  end
end

include
  Make
    (Delay.Nat)
    (struct
      let suffix = ""
      let number = "integer"
    end)

module Rational =
  Make
    (Delay.Rational)
    (struct
      let suffix = "-rational"
      let number = "number"
    end)
