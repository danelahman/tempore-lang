(** Constants and their types. *)

type t = Nat of Z.t | String of string | Boolean of bool | Float of float
type ty = NatTy | StringTy | BooleanTy | FloatTy

val is_eternal_ty : ty -> bool
(** Whether values of the type are eternal. *)

val of_nat : Z.t -> t
val of_string : string -> t
val of_boolean : bool -> t
val of_float : float -> t
val of_true : t
val of_false : t

val print : t -> Format.formatter -> unit
(** Prints a constant as a literal. *)

val print_ty : ty -> Format.formatter -> unit
(** Prints the name of a type of constants. *)

val infer_ty : t -> ty
(** The type of a constant. *)

val compare : t -> t -> int
(** A total order on constants of the same type.

    @raise Utils.Error.Error on constants of different types. *)

val equal : t -> t -> bool
(** Equality of constants of the same type, raising as {!compare}. *)
