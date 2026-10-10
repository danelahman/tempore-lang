(** The primitive operations of the language. *)

type primitive =
  | CompareEq
  | CompareLt
  | CompareGt
  | CompareLe
  | CompareGe
  | CompareNe
  | NatAdd
  | NatMul
  | NatSub
  | NatDiv
  | NatMod
  | FloatAdd
  | FloatMul
  | FloatSub
  | FloatDiv
  | FloatPow
  | FloatNeg
  | ToString

val primitives : primitive list
(** Every primitive. *)

val primitive_name : primitive -> string
(** The name by which the standard library refers to a primitive. *)
