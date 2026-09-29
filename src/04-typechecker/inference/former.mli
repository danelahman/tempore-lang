(** Type formers and the variance of their parts.

    A type is viewed as its outermost former applied to its parts: value types,
    the grade of a box and the effects of computation types. {!decompose} states
    once how a subtyping demand between two types of one former relates their
    parts; skeleton unification, the alignment of skeletons and the
    decomposition of subtyping demands into atoms are all read off it. *)

module Ast = Language.Ast

(** How the parts at one position of two types of one former are related by a
    subtyping demand between the two. *)
type variance =
  | Covariant  (** in the direction of the demand *)
  | Contravariant  (** in the opposite direction *)
  | Invariant  (** in both directions *)

(** The outermost former of a type and its parts: the value types ['ty], the
    grade ['rho] of a box and the effects ['eps] of computation types. A type
    unknown has no former. *)
type ('ty, 'rho, 'eps) t =
  | Param of Ast.ty_param  (** a type unknown *)
  | Const of Language.Const.ty
  | Apply of Ast.ty_name * 'ty list
  | Tuple of 'ty list
  | Arrow of 'ty * 'ty * 'eps  (** the argument, the result and the effect *)
  | Box of 'rho * 'ty
  | Handler of ('ty * 'eps) * ('ty * 'eps)
      (** the input and the output, each a value type and an effect *)

val of_ty : ('rho, 'eps) Ast.ty -> (('rho, 'eps) Ast.ty, 'rho, 'eps) t
(** [of_ty ty] is the outermost former of [ty] and its parts. *)

(** A pair of parts at one position of two types of one former. *)
type ('ty, 'rho, 'eps) part =
  | Ty of variance * Ast.step * 'ty * 'ty  (** value types, at the step *)
  | Rho of variance * 'rho * 'rho  (** the grades of two boxes *)
  | Eps of variance * Ast.step option * 'eps * 'eps
      (** the effects of two function types, or of the computation types at the
          step *)

val decompose :
  ('ty, 'rho, 'eps) t ->
  ('ty, 'rho, 'eps) t ->
  ('ty, 'rho, 'eps) part list option
(** [decompose f g] is, when [f] and [g] have one former, the pairs of their
    parts, left to right, each with its variance, and [None] otherwise:
    - equal constants: none;
    - tuples of one length: the components, covariant (step [Component i]);
    - functions [A → B ! ε] and [A' → B' ! ε']: [A] and [A'] contravariant (step
      [Argument]), [B] and [B'] covariant (step [Result]), [ε] and [ε']
      covariant;
    - boxes [[ρ]A] and [[ρ']A']: [ρ] and [ρ'] contravariant, [A] and [A']
      covariant (step [BoxContent]);
    - applications of one name and arity: the arguments, invariant (step
      [TypeArgument i]);
    - handlers [(A ! ε ⇒ B ! δ)] and [(A' ! ε' ⇒ B' ! δ')]: [A] and [A']
      invariant (step [HandlerInput]) and [ε] and [ε'] invariant, [B] and [B']
      covariant (step [HandlerOutput]) and [δ] and [δ'] covariant.

    Components and arguments are counted from 1. A type unknown decomposes with
    nothing, and an application of an alias is decomposed as it stands. *)
