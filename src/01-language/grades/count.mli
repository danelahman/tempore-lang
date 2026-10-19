(** Intervals of natural numbers, [[m, n]] or [\[m, ∞)]: the counts of a bounded
    repetition [r^C] of the regular expressions of grades, and the numbers of
    occurrences of the event-separation grades. *)

type t = { least : int; most : int option }
(** The numbers from [least] to [most], [most] being [None] where unbounded.
    [0 ≤ least] and [least ≤ most]. *)

val make : int -> int option -> t
(** [make m n] is the interval from [m] to [n].

    @raise Invalid_argument if it is empty or [m] is negative. *)

val point : int -> t
(** [point n] is [[n, n]]. *)

val unbounded : t
(** [\[0, ∞)], all natural numbers. *)

val mem : int -> t -> bool
(** [mem k c] is whether [k] is in [c]. *)

val is_point : int -> t -> bool
(** [is_point n c] is whether [c] is [[n, n]]. *)

val add : t -> t -> t
(** [add c c'] is the sum [{k + k' : k ∈ c, k' ∈ c'}]. *)

val shift : t -> int -> t option
(** [shift c j] is [c ⊖ j = {k - j : k ∈ c, k ≥ j}], [None] if it is empty. *)

val below : t -> t
(** [below c] is [[0, n]] for [c = [m, n]], and [\[0, ∞)] if [c] is unbounded:
    the counts of a repetition of a nullable expression, which contains the
    words of every smaller count. *)

val hull : t -> t -> t
(** [hull c c'] is the least interval containing [c] and [c']. *)

val union : t -> t -> t option
(** [union c c'] is [Some] of the union of [c] and [c'] if it is an interval: if
    they overlap or touch. *)

val nest : t -> t -> t option
(** [nest c c'] is [Some] of [c ⊛ c' = ⋃ {k·c : k ∈ c'}], [k·c] the [k]-fold sum
    of [c] and [0·c = [0, 0]], if it is an interval: the counts of [(r^c)^c'].
    It is one if [c'] is a single number [k], [[k·m, k·n]], or if the sums of
    consecutive numbers of [c = [m, n]] overlap or touch, [(k + 1)·m ≤ k·n + 1]
    for the [k] of [c'] below its greatest. *)

val subset : t -> t -> bool
(** [subset c c'] is whether [c] is contained in [c']. *)

val equal : t -> t -> bool
val compare : t -> t -> int
val hash : t -> int

val show : t -> string
(** [show c] prints [c] as the count of a repetition: [3], [[2, 5]] or
    [\[2, ∞)]. *)
