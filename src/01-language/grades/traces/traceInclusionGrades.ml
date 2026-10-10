open Grade

module Make (D : Delay.S) (N : TimedTraceGrades.NAMES) = struct
  module Trace = TimedTrace.Base (D)

  module UpperBound = struct
    include TimedTraceGrades.Bounded (D)
    module Delay = D

    let name = "traces-upper-bound" ^ N.suffix

    let leq _bounds p q =
      match (p, q) with
      | _, Unbounded -> true
      | Unbounded, Within _ -> false
      | Within p, Within q -> Trace.subset p q

    let leq_symbol = "<="
    let top = Unbounded
    let equal _bounds p q = compare p q = 0

    (** The least trace of the left side not listed by the right side; [⊤]
        itself where the right side alone is a set of traces. *)
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

    (** The time shadow of exact bounds is their delay, and that of other bounds
        [⊤], which is above every delay between them. The operations declare no
        running-time bounds under these grades, so it is not used. *)
    let of_bounds b =
      let lo, hi = hull b in
      if D.equal lo hi then of_delay lo else Unbounded

    let of_lit = of_lit ~number:N.number
    let is_atomic name p = compare p (Within [ [ Trace.Ev name ] ]) = 0
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
