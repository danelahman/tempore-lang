(** Sets of delays: the ultimately periodic finite unions of intervals of
    non-negative rationals.

    A set [S ⊆ ℚ≥0] belongs to the class iff there are a threshold [T ≥ 0] and a
    period [p > 0] such that [S ∩ [0, T + p]] is a finite union of intervals
    with rational ends, each open or closed, and [x ∈ S ⇔ x + p ∈ S] for every
    [x > T]. Equivalently, [S] is a finite union of sets [I + pℕ], [I] an
    interval and [p ≥ 0]. The class is closed under the Boolean operations
    (relative to [ℚ≥0]), the Minkowski sum [S + R = {x + y : x ∈ S, y ∈ R}] and
    the repetition [S* = ⋃ₙ nS], [0S = {0}], and every operation is effective.

    {2 Canonical form}

    A set is kept as [(T, p, B, P)] with [S = B ∪ ⋃ₙ (T + np + P)],
    [B = S ∩ [0, T]] and [P ⊆ (0, p\]] sorted lists of disjoint intervals no two
    of which touch. A set that is eventually empty or eventually full has
    [p = 1]; otherwise [p] is its least eventual period. [T] is the least
    threshold, the supremum of the points below which [S] differs from the
    [p]-periodic extension of its tail. The representation of a set is thus
    unique, and {!equal}, {!compare} and {!hash} read it.

    {2 Representation}

    The grid of a set is [1/g], [g] the least common denominator of [T], [p] and
    the ends of the intervals of [B] and [P]. It divides [ℚ≥0] into atoms, the
    points [k/g] and the open cells between consecutive points, and the set is
    an ultimately periodic word over the atoms, whose least lasso, run-length
    encoded, is [(T, p, B, P)]: [B] and [P] are arrays of the integer bounds of
    their runs of atoms, of arbitrary precision and immediate values when small.

    {2 Costs}

    The Boolean operations align both operands to the least common multiple of
    their grids, a common threshold and the least common multiple of their
    periods, an intersection with, or a difference from, a bounded set reading
    the other operand only up to its supremum; the sum aligns the grids and the
    periods only, and the sum [pℕ + qℕ] of two progressions is the repetition of
    [{p, q}]. Both are linear, respectively quadratic, in the sizes after
    alignment. The union and the intersection are adaptive merges: the runs of
    one operand between two runs of the other are found by an exponential search
    and copied at once, so that an operation with a set of few intervals reads
    the other in a time logarithmic in its size, besides the copy of the result.
    The canonical form of a result takes a linear time: its least period is
    found by the failure function of Knuth, Morris and Pratt ("Fast pattern
    matching in strings", SIAM J. Comput. 6, 1977), its least threshold by
    comparing it with its translate by that period, and its grid by a greatest
    common divisor of its bounds. The repetition is pseudo-polynomial in the
    constants: its result may have a number of intervals proportional to the
    ratio of its constants, and it takes a time linear in that number up to a
    logarithmic factor. Examples: [997ℕ + 991ℕ] is listed point by point up to
    about the product of [997] and [991], and [(1 | (10, 10.001))*] has about
    [10⁴] intervals before its tail. The hash of a set is computed once, when it
    is first needed, and {!intersects} and {!subset} stop at the first common
    element found. *)

type t
(** A set of delays, in canonical form. *)

(** {1 Constructions} *)

val empty : t
(** The empty set. *)

val zero : t
(** The set [{0}]. *)

val all : t
(** The set [ℚ≥0] of all delays. *)

val positive : t
(** The set [ℚ>0] of the positive delays. *)

val naturals : t
(** The set [ℕ] of the integer delays. *)

val point : Rational.t -> t
(** [point q] is the set [{q}].

    Raises [Invalid_argument] if [q] is negative. *)

val interval :
  lo:Rational.t -> lo_closed:bool -> hi:Rational.t option -> hi_closed:bool -> t
(** [interval ~lo ~lo_closed ~hi ~hi_closed] is the interval from [lo] to [hi],
    closed at each end as the flags say, unbounded if [hi] is [None]; it is
    intersected with [ℚ≥0]. *)

val between :
  Rational.t GradeLiteral.bound -> Rational.t GradeLiteral.bound -> t
(** [between lo hi] is the interval from [lo] to [hi], each endpoint closed or
    open, an infinite lower endpoint being [0]; it is intersected with [ℚ≥0]. *)

val union : t -> t -> t
val inter : t -> t -> t

val compl : t -> t
(** [compl s] is [ℚ≥0 ∖ s]. *)

val diff : t -> t -> t
(** [diff s r] is [s ∖ r]. *)

val sum : t -> t -> t
(** [sum s r] is the Minkowski sum [{x + y : x ∈ s, y ∈ r}]. *)

val star : t -> t
(** [star s] is [⋃ₙ ns], with [0s = {0}] and [(n+1)s = s + ns].

    It is computed by cases on [s⁺ = s ∖ {0}]: [{0}] if [s⁺] is empty; [ℚ≥0] if
    [inf s⁺ = 0]; if [s⁺] contains an interval [⟨a, b⟩] with [0 < a < b], the
    multiples [n⟨a, b⟩] cover [(c, ∞)] from [c = n₀a], [n₀] the least [n] with
    [n(b - a) > a], and [s* ∩ [0, c]] is the least fixpoint of
    [R ↦ {0} ∪ (R + s⁺) ∩ [0, c]], computed by semi-naive iteration; and if [s⁺]
    is discrete, scaled to the integers by a common denominator [D], [s*] is
    read off the Apéry set of the numerical semigroup generated, with respect to
    its least element [μ], computed as shortest paths over the residues modulo
    [μ] by Dijkstra's algorithm (Nijenhuis, "A minimal-path algorithm for the
    money changing problem", Amer. Math. Monthly 86, 1979). *)

(** {1 Queries} *)

type interval = {
  lo : Rational.t;
  lo_closed : bool;
  hi : Rational.t;
  hi_closed : bool;
}
(** The interval from [lo] to [hi], containing each end iff it is closed. *)

val threshold : t -> Rational.t
(** [threshold s] is the threshold [T] of the canonical form of [s]. *)

val period : t -> Rational.t
(** [period s] is the period [p] of the canonical form of [s]. *)

val intervals_upto : Rational.t -> t -> interval list
(** [intervals_upto x s] is the list of the maximal intervals of [s ∩ [0, x]],
    in increasing order. *)

val mem : Rational.t -> t -> bool
(** [mem x s] is whether [x ∈ s]. *)

val is_empty : t -> bool

val intersects : t -> t -> bool
(** [intersects s r] is whether [s ∩ r] is non-empty, decided by a sweep over
    the intervals of both, without forming the intersection. *)

val subset : t -> t -> bool

val equal : t -> t -> bool
(** [equal s r] is whether [s] and [r] are the same set, read off their
    canonical forms. *)

val compare : t -> t -> int
(** A total order compatible with {!equal}. *)

val hash : t -> int
(** A hash compatible with {!equal}. *)

(** An extremal value of a set: a rational, attained or not, or infinity. *)
type extremum =
  | Finite of Rational.t * bool
      (** [Finite (q, attained)]: [q], a member of the set iff [attained] *)
  | Infinite  (** An unbounded set's supremum *)

val equal_extremum : extremum -> extremum -> bool
(** The equality of extremal values. *)

val hash_extremum : extremum -> int
(** A hash compatible with {!equal_extremum}. *)

val inf : t -> extremum option
(** [inf s] is the infimum of [s], [None] if [s] is empty; it is finite. *)

val sup : t -> extremum option
(** [sup s] is the supremum of [s], [None] if [s] is empty. *)

val choose : t -> Rational.t option
(** [choose s] is a simplest element of [s], [None] if [s] is empty: among the
    simplest rationals of the intervals of [s] below its threshold and of the
    first period above it, found by the Stern–Brocot search, the one of least
    denominator, and of these the least. *)

val minterms : t list -> t list
(** [minterms sets] is the partition of [ℚ≥0] into the non-empty sets that every
    set of [sets] is a union of, the atoms of the Boolean algebra they generate,
    by splitting every block by each set in turn. *)

(** {1 Printing} *)

val to_regex : t -> GradeLiteral.regex
(** [to_regex s] is an expression of the brace literals whose delays are [s]:
    the union of its maximal intervals below the periodic part, each a delay or
    an interval atom such as [\[5, 6)] or [(0, ∞)], and of the periodic part
    [X + pℕ] written [X; p*], [X] shifted as far down as [s] allows. The empty
    set is [~_*]. *)

val show : t -> string
(** [show s] prints {!to_regex}[ s], e.g. [0 | \[5, 6); 3*]. *)
