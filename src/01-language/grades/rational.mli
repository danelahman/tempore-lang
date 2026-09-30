(** Exact rational numbers, of arbitrary precision.

    A rational is kept in lowest terms with a positive denominator, so that
    {!compare}, {!equal} and {!hash} are those of the numbers. *)

type t
(** A rational number. *)

val zero : t
(** The number [0]. *)

val of_int : int -> t
(** [of_int n] is the integer [n]. *)

val of_z : Z.t -> t
(** [of_z n] is the integer [n]. *)

val make : int -> int -> t
(** [make n d] is the fraction [n/d].

    @raise Division_by_zero if [d = 0]. *)

val make_z : Z.t -> Z.t -> t
(** [make_z n d] is the fraction [n/d].

    @raise Division_by_zero if [d = 0]. *)

val of_decimal : string -> t
(** [of_decimal s] is the number the decimal numeral [s] denotes exactly, e.g.
    ["1.5"], ["0.125"], ["-2.0"] or ["2.5e-3"], underscores ignored.

    @raise Invalid_argument if [s] is not a decimal numeral. *)

val add : t -> t -> t
(** [add p q] is [p + q]. *)

val neg : t -> t
(** [neg q] is [-q]. *)

val sub : t -> t -> t
(** [sub p q] is [p - q]. *)

val mul : t -> t -> t
(** [mul p q] is [p · q]. *)

val div : t -> t -> t
(** [div p q] is [p / q].

    @raise Division_by_zero if [q] is [0]. *)

val sign : t -> int
(** [sign q] is [-1], [0] or [1] as [q] is negative, zero or positive. *)

val compare : t -> t -> int
(** The order [≤] of the numbers. *)

val equal : t -> t -> bool
(** The equality of the numbers. *)

val hash : t -> int
(** A hash compatible with {!equal}. *)

val is_integer : t -> bool
(** [is_integer q] is whether [q] is an integer. *)

val to_int : t -> int option
(** [to_int q] is [Some n] if [q] is an integer [n] representable as an [int],
    and [None] otherwise. *)

val num : t -> Z.t
(** [num q] is the numerator of [q] in lowest terms. *)

val den : t -> Z.t
(** [den q] is the denominator of [q] in lowest terms, positive. *)

val denominator : t -> int
(** [denominator q] is the denominator of [q] in lowest terms.

    @raise Invalid_argument if it is not representable as an [int]. *)

val show : t -> string
(** [show q] prints [q] as an integer, e.g. [3]; otherwise as a decimal if its
    expansion terminates, i.e. if its denominator is [2ᵃ5ᵇ], e.g. [1.5] or
    [0.125]; and otherwise as a fraction, e.g. [1/3]. {!of_decimal} and the
    quotient of the integers of a fraction read each form back. *)
