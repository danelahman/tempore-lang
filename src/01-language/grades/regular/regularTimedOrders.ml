open Grade

module type WORLD = sig
  type grade
  type delay
  type world
  type word

  val suffix : string

  val world :
    (running_time -> Rational.t bound) -> bounds -> grade list -> world

  val in_allowance : world -> grade -> grade -> bool
  val in_coverage : world -> grade -> grade -> bool
  val allowance : world -> grade -> grade -> word option
  val coverage : world -> grade -> grade -> word option
  val min_weight : world -> grade -> Rational.t bound option
  val max_weight : world -> grade -> Rational.t bound option
  val inhabited : bounds -> grade -> bool
  val grade_of_word : word -> grade
  val single : lit -> bool
  val number : lit -> Rational.t option
  val close : lower:bool -> lit -> lit
  val lower_shadow : delay bound -> grade
  val upper_shadow : delay bound -> grade
end

module Make
    (L : Grade.S)
    (W : WORLD with type grade = L.t and type delay = L.Delay.t) =
struct
  type order = {
    holds : W.world -> L.t -> L.t -> bool;
    search : W.world -> L.t -> L.t -> W.word option;
    endpoint : running_time -> Rational.t bound;
    top : L.t;
  }
  (** An order on traces: whether every trace of the lesser grade is in the
      closure of the greater one, and the search for a trace outside it, over a
      world; the end of the running-time bounds it reads as the running time of
      an operation, and the representation of its greatest grade. *)

  let allowance =
    {
      holds = W.in_allowance;
      search = W.allowance;
      endpoint = snd;
      top = L.top;
    }

  let coverage =
    { holds = W.in_coverage; search = W.coverage; endpoint = fst; top = L.one }

  (** [trivial order bounds rho rho'] is whether [rho ≾ rho'] holds by the
      underlying grade: [rho] and [rho'] are the same language or [rho'] is
      represented as the top. *)
  let trivial order bounds rho rho' =
    L.equal bounds rho rho' || L.compare rho' order.top = 0

  (** [compared order bounds decide rho rho'] is [decide] over the world of a
      comparison of [rho] with [rho']. *)
  let compared order bounds decide rho rho' =
    decide (W.world order.endpoint bounds [ rho; rho' ]) rho rho'

  let leq order bounds rho rho' =
    trivial order bounds rho rho' || compared order bounds order.holds rho rho'

  (** [is_top order bounds rho] is whether [rho] is the top: by its
      representation, and otherwise by the order. *)
  let is_top order bounds rho =
    L.compare rho order.top = 0 || leq order bounds order.top rho

  (** [counterexample order bounds rho rho'] is the grade of a trace of [rho]
      outside the closure of [rho'] under [order]. *)
  let counterexample order bounds rho rho' =
    if trivial order bounds rho rho' then None
    else
      Option.map W.grade_of_word (compared order bounds order.search rho rho')

  let implied_bounds bounds lower upper =
    match
      ( W.min_weight (W.world fst bounds [ lower ]) lower,
        W.max_weight (W.world snd bounds [ upper ]) upper )
    with
    | Some fastest, Some slowest -> Some (fastest, slowest)
    | _ -> None

  (** The fields the grades share with the underlying regular trace grade. *)
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
    let inhabited = W.inhabited
    let events = L.events
    let compare = L.compare
    let hash = L.hash
    let is_atomic = L.is_atomic
    let show = L.show
    let witnesses = L.witnesses
  end

  module Lower = struct
    include Common

    let name = "regex-timed-lower-bound" ^ W.suffix
    let leq = leq coverage
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample coverage

    (** The unit [{0}], covered by every trace. *)
    let top = coverage.top

    let is_top = is_top coverage
    let unit_least = false
    let of_lit = function Top -> top | lit -> L.of_lit lit
    let of_bounds (lo, _hi) = W.lower_shadow lo
  end

  module Upper = struct
    include Common

    let name = "regex-timed-upper-bound" ^ W.suffix
    let leq = leq allowance
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample allowance
    let top = allowance.top
    let is_top = is_top allowance
    let unit_least = true
    let of_lit = L.of_lit
    let of_bounds (_lo, hi) = W.upper_shadow hi
  end

  module Interval = struct
    type t = L.t * L.t

    module Delay = L.Delay

    let name = "regex-timed-interval" ^ W.suffix
    let one = (Lower.one, Upper.one)
    let mul (lo, hi) (lo', hi') = (L.mul lo lo', L.mul hi hi')

    let leq bounds (lo, hi) (lo', hi') =
      Lower.leq bounds lo lo' && Upper.leq bounds hi hi'

    let leq_symbol = "<="
    let top = (Lower.top, Upper.top)
    let join (lo, hi) (lo', hi') = (L.join lo lo', L.join hi hi')
    let equal bounds p q = leq bounds p q && leq bounds q p

    let is_top bounds (lo, hi) =
      Lower.is_top bounds lo && Upper.is_top bounds hi

    let compare (lo, hi) (lo', hi') =
      match L.compare lo lo' with 0 -> L.compare hi hi' | c -> c

    let hash (lo, hi) = combine (L.hash lo) (L.hash hi)

    let counterexample bounds (lo, hi) (lo', hi') =
      match Lower.counterexample bounds lo lo' with
      | Some e -> Some (e, hi)
      | None ->
          Option.map (fun e -> (lo, e)) (Upper.counterexample bounds hi hi')

    let unit_least = false
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds (lo, hi) = implied_bounds bounds lo hi

    let inhabited bounds (lo, hi) =
      W.inhabited bounds lo && W.inhabited bounds hi

    let events (lo, hi) =
      List.sort_uniq String.compare (L.events lo @ L.events hi)

    let of_lit = function
      | Top -> top
      | lit when W.single lit ->
          let rho = L.of_lit lit in
          (rho, rho)
      | lit ->
          bounds_of_lit lit ~number:W.number ~close:W.close ~lower:Lower.of_lit
            ~upper:Upper.of_lit ~unbounded:Upper.top
            ~bounds:"regular expressions"

    let of_delay d = (L.of_delay d, L.of_delay d)
    let of_bounds (lo, hi) = (W.lower_shadow lo, W.upper_shadow hi)
    let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi

    let show (lo, hi) =
      show_bounds (Lower.show lo)
        (if L.compare hi Upper.top = 0 then None else Some (Upper.show hi))

    let witnesses ~degree:_ _bounds = sampled mul
  end
end
