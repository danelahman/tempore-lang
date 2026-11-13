(** The watermark grades: the levels reached by each system resource held, such
    as the number of open files.

    A grade [(t, [d1, d2], h)] records, relative to the level at the start of a
    computation, its trough [t], the lowest level reached; the range [[d1, d2]]
    of its net change, the level at the end; and its peak [h], the highest level
    reached. It satisfies [t ≤ d1 ≤ d2 ≤ h] and [t ≤ 0 ≤ h]. Sequencing adds the
    net changes and shifts the later trough and peak by the earlier net change:
    {v
    (t, [d1, d2], h) · (t', [d1', d2'], h')
      = (min(t, d1 + t'), [d1 + d1', d2 + d2'], max(h, d2 + h'))
    v}
    Delays change nothing. *)

(** Integers with a least element [-∞] and a greatest element [∞]. *)
type bound =
  | Minus_inf  (** the least element [-∞] *)
  | Fin of int  (** an integer *)
  | Plus_inf  (** the greatest element [∞] *)

(** The watermark grades over any delays [D], which change nothing. *)
module Make (D : Delay.S) : sig
  (** {!WatermarkGrades.Upper} over [D]. *)
  module Upper : Grade.S with type t = bound * bound and type Delay.t = D.t

  (** {!WatermarkGrades.Lower} over [D]. *)
  module Lower : Grade.S with type t = bound * bound and type Delay.t = D.t

  (** {!WatermarkGrades.OneResource} over [D]. *)
  module OneResource :
    Grade.S
      with type t = (bound * bound) * (bound * bound)
       and type Delay.t = D.t

  (** {!WatermarkGrades.Watermarks} over [D]. *)
  module Watermarks :
    Grade.S
      with type t = OneResource.t GradeConstructions.Indexed.t
       and type Delay.t = D.t
end

(** The upper bounds of the net change paired with the peaks,
    ["upper-net-change⋉peak"]: the semidirect product
    {!GradeConstructions.SemiDirect} of the grade of the integers and [∞] under
    addition, ordered by [≤], and the semilattice of [-∞], the integers and [∞]
    under the maximum, a net change [d] acting on a peak [h] as [d + h], fixing
    [-∞]: [(d2, h) · (d2', h') = (d2 + d2', max(h, d2 + h'))]. Delays change
    nothing. Its literals are integers and [∞]. The action is compatible with
    closures, and [plus] is the closure: [(d2, h)] is its own closure if
    [d2 ≤ 0], and has the closure [(∞, ∞)] otherwise, or [(∞, -∞)] if [h = -∞].
    It is a component of {!OneResource}, and its unit lacks the unit-product
    property. *)
module Upper :
  Grade.S with type t = bound * bound and type Delay.t = Delay.Nat.t

(** The lower bounds of the net change paired with the troughs,
    ["lower-net-change⋉trough"]: the mirror image of {!Upper}, the integers and
    [-∞] under addition, ordered by [≥], acting on [-∞], the integers and [∞]
    under the minimum: [(d1, t) · (d1', t') = (d1 + d1', min(t, d1 + t'))]. Its
    literals are integers and [⊤], standing for [-∞]. [(d1, t)] is its own
    closure if [d1 ≥ 0], and has the closure [(-∞, -∞)] otherwise, or [(-∞, ∞)]
    if [t = ∞]. It is a component of {!OneResource}, and its unit lacks the
    unit-product property. *)
module Lower :
  Grade.S with type t = bound * bound and type Delay.t = Delay.Nat.t

(** The levels of one resource, ["one-watermark"]: the product
    {!GradeConstructions.Product} [(Lower) (Upper)] on the pairs
    [((d1, t), (d2, h))] of the grades [(t, [d1, d2], h)] above, whose unit is
    [(0, [0, 0], 0)] and top [(-∞, (-∞, ∞), ∞)].

    These pairs are closed under the product, the join and the top, and the unit
    is the only grade below the unit: [x · y ≾ 1] forces the trough and the peak
    of [x] to be [0], hence [x = 1] and [y ≾ 1].

    - The order is [t ≥ t'], [d1 ≥ d1'], [d2 ≤ d2'] and [h ≤ h'], and the join
      is componentwise the minimum or maximum accordingly. The unit is not
      least, and [mul] does not commute: closing a file and then opening one has
      the grade [(-1, [0, 0], 0)], the converse [(0, [0, 0], 1)].
    - [plus] is the closure componentwise, in {!Lower} and in {!Upper}, which
      keeps the constraints on the components: a grade with the net change [0]
      is its own closure, and the closure of any other replaces a lower end
      [d1 < 0] and the trough by [-∞], and an upper end [d2 > 0] and the peak by
      [∞].
    - [of_delay] and [of_bounds] are constantly the unit.
    - [of_lit] reads [⊤], pairs [(d, h)] of an exact net change [d] and a peak
      [h], pairs [([d1, d2], h)] of a range of net changes and a peak, the
      trough being [min(0, d1)] in both, and the triples [(t, d, h)] and
      [(t, [d1, d2], h)] with an explicit trough [t]. Troughs are integers or
      [⊤], standing for [-∞]; peaks are integers or [∞]; exact net changes and
      the finite ends of ranges are integers, a range unbounded below or above
      being written [(-∞, d2\]] or [\[d1, ∞)], and [(∞, ∞)] is the top. An open
      end abbreviates a closed one, the range [(d1, d2)] being
      [[d1 + 1, d2 - 1]], and must leave the range non-empty. The components
      must satisfy [t ≤ min(0, d1)], [d1 ≤ d2] and [h ≥ max(0, d2)].
    - [show] prints the top as [(∞, ∞)] and any other grade in the shortest of
      these forms, omitting the trough when it is [min(0, d1)].
    - A failure of the order in the trough or the peak is witnessed by the
      lesser grade; no other counterexample is offered.
    - The witnesses of the constants [cs] are partial: with [s] the sum of the
      absolute values of the finite components of [cs], for each [d] with
      [-s-1 ≤ d ≤ s+1], the grades with the net change [d], the trough
      [min(0, d)] and a peak among [max(0, d)], [max(0, d) + 1], [s+1] and [∞],
      or the peak [max(0, d)] and a trough among [min(0, d) - 1], [-s-1] and
      [-∞]; and the grades whose net change ranges from [d] to [s+1] or [∞], or
      from [-s-1] or [-∞] to [d], with the trough [min(0, d1)] and the peak
      [max(0, d2)] of their range [[d1, d2]]. *)
module OneResource :
  Grade.S
    with type t = (bound * bound) * (bound * bound)
     and type Delay.t = Delay.Nat.t

(** The watermark grade, ["watermarks"]: the levels of each resource, by its
    name, {!GradeConstructions.Indexed.OfGrade} [(OneResource)].

    An entry [(R, d, h)], [(R, [d1, d2], h)], [(R, t, d, h)] or
    [(R, t, [d1, d2], h)] bounds the resource [R], and a plain grade of
    {!OneResource} every resource, so that a program with a single resource need
    not name it: [((Files, 0, 2), (Sockets, 0, 1))] holds at most two files and
    one socket at a time, releasing them all, [(Files, -1, 0, 0)] releases a
    file before acquiring one, and [(1, 1)] holds one more of each resource. The
    witnesses are partial, as those of {!OneResource} are. *)
module Watermarks :
  Grade.S
    with type t = OneResource.t GradeConstructions.Indexed.t
     and type Delay.t = Delay.Nat.t
