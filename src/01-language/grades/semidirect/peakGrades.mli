(** The peak-usage grades: the net change of each resource held, such as the
    number of open files, paired with its peak.

    A grade [(d, h)] is "the amount held changes by [d] and rises at most [h]
    above its level at the start"; [h ≥ max(0, d)], since the peak includes both
    the start and the end. Sequencing adds the changes and shifts the later peak
    by the earlier change: [(d, h) · (d', h') = (d + d', max(h, d + h'))]. Ticks
    change nothing. *)

(** Integers with a least element [-∞] and a greatest element [∞]. *)
type bound =
  | Minus_inf  (** the least element [-∞] *)
  | Fin of int  (** an integer *)
  | Plus_inf  (** the greatest element [∞] *)

module NetChange : Grade.S with type t = bound
(** The net changes, ["net-change"]: the integers and [∞] under addition,
    ordered by [≤]; ticks change nothing, so [of_nat] is constantly [0]. Its
    literals are integers and [∞]. *)

module Peak : GradeConstructions.SEMILATTICE with type t = bound
(** The peaks, ["peak"]: [-∞], the integers and [∞] ordered by [≤], the join
    being the maximum. Its literals are integers and [∞]. *)

(** The action of a net change [d] on a peak [h], shifting it to [d + h]; [-∞]
    is fixed. *)
module Shift :
  GradeConstructions.ACTION with type m = NetChange.t and type n = Peak.t

module OneResource : Grade.S with type t = bound * bound
(** The peak usage of one resource, ["resource-peak"]: the semidirect product
    {!GradeConstructions.SemiDirect} [(NetChange) (Peak) (Shift)] on the pairs
    [(d, h)] with [h ≥ max(0, d)], whose unit is [(0, 0)].

    These pairs are the image of the endomorphism [(d, h) ↦ (d, max(h, 0, d))]
    of the product, which identifies the grades acting alike on the states whose
    peak is at least their level; they are closed under the product, the join
    and the top [(∞, ∞)], the only pair with [d = ∞].

    - The order is componentwise, so the unit is not least: [(-1, 0)] is below
      it. [mul] does not commute.
    - [of_nat] and [of_bounds] are constantly the unit.
    - [of_lit] reads [⊤] and pairs [(d, h)] of integers or [∞] with
      [h ≥ max(0, d)], [d] being [∞] only if [h] is; [show] prints [(d,h)].
    - No counterexample is offered.
    - The witnesses of the constants [cs] are partial: the pairs [(d, h)] with
      [-s-1 ≤ d ≤ s+1] and [h] one of [max(0, d)], [max(0, d) + 1], [s+1] and
      [∞], where [s] is the sum of the absolute values of the finite components
      of [cs]. *)

module PeakUsage :
  Grade.S with type t = (bound * bound) GradeConstructions.Indexed.t
(** The peak-usage grade, ["peak-usage"]: the peak usage of each resource, by
    its name, {!GradeConstructions.Indexed.OfGrade} [(OneResource)].

    An entry [(R, d, h)] bounds the resource [R], and a plain pair [(d, h)]
    every resource, so that a program with a single resource need not name it:
    [((Files, 0, 2), (Sockets, 0, 1))] holds at most two files and one socket at
    a time, releasing them all, and [(1, 1)] holds one more of each resource.
    The witnesses are partial, as those of {!OneResource} are. *)
