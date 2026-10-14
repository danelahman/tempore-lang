(** Intervals of durations: non-empty intervals of non-negative rationals with a
    finite lower end, each finite end closed or open, the upper end possibly
    infinite; e.g. [[0, 5]], [(1/2, 3\]] or [\[2, ∞)]. They are the components
    of the summaries of {!SummaryTerms}. *)

type t = Rational.t Grade.bound * Rational.t Grade.bound
(** An interval [(lo, hi)]: [lo] is finite and the interval is non-empty. *)

val point : Rational.t -> t
(** [point q] is [[q, q]]. *)

val zero : t
(** The interval [[0, 0]]. *)

val unbounded : t
(** The interval [\[0, ∞)] of all durations. *)

val is_zero : t -> bool
(** [is_zero i] is whether [i] is [[0, 0]]. *)

val add : t -> t -> t
(** [add i j] is the Minkowski sum [i + j]: an end of the sum is attained iff
    both ends summed are, and infinite iff either is. *)

val hull : t -> t -> t
(** [hull i j] is the least interval containing [i] and [j]. *)

val subset : t -> t -> bool
(** [subset i j] is whether [i ⊆ j]. *)

val inter : t -> t -> t option
(** [inter i j] is the intersection [i ∩ j], [None] if it is empty. *)

val meets : t -> t -> bool
(** [meets i j] is whether [i ∩ j] is non-empty. *)

val from : t -> t
(** [from i] is the interval of the durations at least those of [i], from its
    lower end on: [i + \[0, ∞)]. *)

val compare : t -> t -> int
(** A total order on intervals, [0] exactly on equal intervals. *)

val hash : t -> int
(** A hash compatible with {!compare}. *)

val show : t -> string
(** [show i] prints [i] as an interval literal, e.g. [[0, 5]] or [(1/2, ∞)]. *)

val show_point : t -> string
(** [show_point i] prints [i] as a number if it is a single point, and as
    {!show} otherwise. *)

val of_lit : Grade.lit -> t
(** [of_lit lit] is the interval the literal [lit] denotes: a non-negative
    number [q] the point [[q, q]], and an interval literal, or a pair of numbers
    [(q, r)] for the open interval, as the rational time intervals read them
    ({!RationalTimeGrades.Interval}).

    @raise Grade.Invalid_literal on any other literal, or an empty interval. *)
