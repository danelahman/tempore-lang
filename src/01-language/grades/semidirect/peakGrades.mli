(** The peak-usage grades: the levels reached by each resource held, such as the
    number of open files.

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

(** The peak-usage grades over any delays [D], which change nothing. *)
module Make (D : Delay.S) : sig
  (** {!PeakGrades.Upper} over [D]. *)
  module Upper : Grade.S with type t = bound * bound and type Delay.t = D.t

  (** {!PeakGrades.Lower} over [D]. *)
  module Lower : Grade.S with type t = bound * bound and type Delay.t = D.t

  (** {!PeakGrades.OneResource} over [D]. *)
  module OneResource :
    Grade.S
      with type t = (bound * bound) * (bound * bound)
       and type Delay.t = D.t

  (** {!PeakGrades.PeakUsage} over [D]. *)
  module PeakUsage :
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
    nothing. Its literals are integers and [∞]. It is a component of
    {!OneResource}, and its unit lacks the zero-product property. *)
module Upper :
  Grade.S with type t = bound * bound and type Delay.t = Delay.Nat.t

(** The lower bounds of the net change paired with the troughs,
    ["lower-net-change⋉trough"]: the mirror image of {!Upper}, the integers and
    [-∞] under addition, ordered by [≥], acting on [-∞], the integers and [∞]
    under the minimum: [(d1, t) · (d1', t') = (d1 + d1', min(t, d1 + t'))]. Its
    literals are integers and [⊤], standing for [-∞]. It is a component of
    {!OneResource}, and its unit lacks the zero-product property. *)
module Lower :
  Grade.S with type t = bound * bound and type Delay.t = Delay.Nat.t

(** The usage of one resource, ["resource-peak"]: the product
    {!GradeConstructions.Product} [(Lower) (Upper)] on the pairs
    [((d1, t), (d2, h))] of the grades [(t, [d1, d2], h)] above, whose unit is
    [(0, [0, 0], 0)] and top [(-∞, [-∞, ∞], ∞)].

    These pairs are closed under the product, the join and the top, and the unit
    is the only grade below the unit: [x · y ≾ 1] forces the trough and the peak
    of [x] to be [0], hence [x = 1] and [y ≾ 1].

    - The order is [t ≥ t'], [d1 ≥ d1'], [d2 ≤ d2'] and [h ≤ h'], and the join
      is componentwise the minimum or maximum accordingly. The unit is not
      least, and [mul] does not commute: closing a file and then opening one has
      the grade [(-1, [0, 0], 0)], the converse [(0, [0, 0], 1)].
    - [of_delay] and [of_bounds] are constantly the unit.
    - [of_lit] reads [⊤], pairs [(d, h)] of an exact net change [d] and a peak
      [h], pairs [((d1, d2), h)] of a range of net changes and a peak, the
      trough being [min(0, d1)] in both, and the triples [(t, d, h)] and
      [(t, (d1, d2), h)] with an explicit trough [t]. Troughs and lower ends of
      ranges are integers or [⊤], standing for [-∞]; peaks and upper ends are
      integers or [∞]; exact net changes are integers, [(∞, ∞)] being the top.
      The components must satisfy [t ≤ min(0, d1)], [d1 ≤ d2] and
      [h ≥ max(0, d2)].
    - [show] prints the top as [(∞,∞)] and any other grade in the shortest of
      these forms, omitting the trough when it is [min(0, d1)].
    - No counterexample is offered.
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

(** The peak-usage grade, ["peak-usage"]: the usage of each resource, by its
    name, {!GradeConstructions.Indexed.OfGrade} [(OneResource)].

    An entry [(R, d, h)], [(R, (d1, d2), h)], [(R, t, d, h)] or
    [(R, t, (d1, d2), h)] bounds the resource [R], and a plain grade of
    {!OneResource} every resource, so that a program with a single resource need
    not name it: [((Files, 0, 2), (Sockets, 0, 1))] holds at most two files and
    one socket at a time, releasing them all, [(Files, -1, 0, 0)] releases a
    file before acquiring one, and [(1, 1)] holds one more of each resource. The
    witnesses are partial, as those of {!OneResource} are. *)
module PeakUsage :
  Grade.S
    with type t = OneResource.t GradeConstructions.Indexed.t
     and type Delay.t = Delay.Nat.t
