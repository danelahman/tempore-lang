(** Runs of atoms: the bounded sets of rationals on a grid, as arrays of the
    bounds of their intervals.

    For a positive integer [g], the grid [1/g] partitions [ℚ≥0] into atoms: the
    point [k/g], atom [2k], and the open cell [(k/g, (k + 1)/g)], atom [2k + 1].
    A run [\[s, e)], [s < e], is the union of the atoms [a] with [s ≤ a < e]:
    the interval from [⌊s/2⌋/g] to [⌊e/2⌋/g], closed below iff [s] is even and
    closed above iff [e] is odd. Two runs [\[s, e)] and [\[s', e')] with
    [s ≤ s'] meet or touch iff [s' ≤ e]. A list of intervals whose ends are
    multiples of [1/g], sorted, disjoint and no two of which touch, is the array
    [[|s₀; e₀; s₁; e₁; …|]] of the bounds of its runs, [sᵢ < eᵢ < sᵢ₊₁]; the
    order of intervals by their lower ends, then by their upper ends, is that of
    the pairs [(sᵢ, eᵢ)]. Bounds are integers of arbitrary precision, which are
    immediate values when small. *)

type runs = Z.t array
(** The array of the bounds of the runs of a set. *)

val twice : Z.t -> Z.t
(** [twice k] is the atom [2k], the point [k/g]. *)

val half : Z.t -> Z.t
(** [half a] is [⌊a/2⌋], the number of the grid point at or below the atom [a].
*)

val count : runs -> int
(** [count r] is the number of the runs of [r]. *)

val last : runs -> Z.t
(** [last r] is the upper bound of the last run of the non-empty [r]. *)

val point_run : Z.t -> runs
(** [point_run k] is the run of the point [k/g]. *)

val full : Z.t -> runs
(** [full p] is the run of the interval [(0, p\]]. *)

val is_full : Z.t -> runs -> bool
(** [is_full p r] is whether [r] is {!full} [p]. *)

val translate : Z.t -> runs -> runs
(** [translate d r] is [r] shifted by [d] atoms. *)

val fold_runs : ('a -> Z.t -> Z.t -> 'a) -> 'a -> runs -> 'a
(** [fold_runs f acc r] folds [f] over the runs [\[s, e)] of [r] in increasing
    order. *)

val of_pairs : (Z.t * Z.t) list -> runs
(** [of_pairs pairs] is the array of the runs [\[s, e)] of the pairs [(s, e)],
    in order. *)

val search : int -> (int -> bool) -> int
(** [search n p] is the least [k] with [0 ≤ k < n] and [p k], and [n] if there
    is none, for a predicate [p] false and then true on [0, …, n - 1]: a binary
    search. *)

val member : runs -> Z.t -> bool
(** [member r a] is whether the atom [a] lies in a run of [r]. *)

val fresh : int -> runs
(** [fresh n] is an array of [n] bounds to write runs into.

    @raise Utils.Error.Error
      a typing error ({!Delay.out_of_range}) if [n] exceeds the greatest length
      of arrays. *)

val emit : runs -> int -> Z.t -> Z.t -> int
(** [emit out n s e] writes the run [\[s, e)], whose lower bound is not below
    those of the runs written, after the first [n] bounds of [out], joined with
    the last run if the two meet or touch, and is the new number of bounds. *)

val finish : runs -> int -> runs
(** [finish out n] is the first [n] bounds of [out]. *)

val coalesce : runs -> runs
(** [coalesce r] joins the runs of [r], sorted by their lower bounds, that meet
    or touch. *)

val append : runs -> runs -> runs
(** [append xs ys] is the union of [xs] and [ys], every run of [ys] beginning at
    or above the upper bound of the last run of [xs]. *)

val clip : Z.t -> Z.t -> runs -> runs
(** [clip lo hi r] is the intersection of [r] with the run [\[lo, hi)], found by
    binary search; [r] itself if it lies within. *)

val union_runs : runs -> runs -> runs
(** [union_runs xs ys] is the union of [xs] and [ys], by a merge sweep over both
    arrays, adaptive: when a run is taken from the same array as the one before,
    the runs following it that begin above the output and end below the next run
    of the other array are found by an exponential search and copied at once. *)

val inter_runs : runs -> runs -> runs
(** [inter_runs xs ys] is the intersection of [xs] and [ys], by a sweep over
    both arrays: the meet of two runs, then the one ending first left behind;
    adaptive, the runs of one array lying before the current run of the other
    skipped, and those lying within it copied at once, both found by an
    exponential search. *)

val within : Z.t -> Z.t -> runs -> runs
(** [within lo hi r] is the complement of [r], an array within the run
    [\[lo, hi)], relative to [\[lo, hi)]: the gaps between its runs. *)

val merge_all : runs list -> runs
(** [merge_all arrays] merges the arrays sorted by their lower bounds in
    [arrays], by balanced pairwise merges. *)

val sum_runs : runs -> runs -> runs
(** [sum_runs xs ys] is the Minkowski sum of [xs] and [ys]:
    [⟨a, b⟩ + ⟨c, d⟩ = ⟨a + c, b + d⟩], an end closed iff both are, which for
    runs [\[s, e)] and [\[s', e')] is the run from [s + s' - 1] if [s] and [s']
    are odd, and [s + s'] otherwise, to [e + e' - 1] if [e] or [e'] is odd, and
    [e + e'] otherwise. The translates of the longer array by each run of the
    shorter are sorted, since its lower bounds increase, and are merged. *)
