(** Open grade expressions of the two sorts, resource grades [rho] and effect
    grades [eps], over a grade system.

    An expression is a variable, a closed grade, a product or a binary join; a
    resource expression may also be the image [∣eps∣] of an effect expression
    under the grade morphism. Variables are named symbols, so substitutions are
    finite maps and no expression is ever reindexed. *)

(** Variables of one sort. *)
module type VAR = sig
  include Utils.Symbol.S

  val fresh_indexed : unit -> t
  (** [fresh_indexed ()] is a fresh variable named by the sort's letter and the
      next subscript of the sort, e.g. [ρ₀], [ρ₁]. *)

  val equal : t -> t -> bool
  (** [equal x y] is whether [x] and [y] are the same variable. *)

  module Map : Map.S with type key = t
  (** Finite maps from variables. *)

  module Set : Set.S with type elt = t
  (** Finite sets of variables. *)
end

module Rho_var : VAR
(** Resource-grade variables, printed [ρ₀], [ρ₁], ..., shared by every grade
    system. *)

module Eps_var : VAR
(** Effect-grade variables, printed [ε₀], [ε₁], ..., shared by every grade
    system. *)

module type S = sig
  module GS : Language.GradeSystem.S
  (** The grade system the constants are drawn from. *)

  module Rho_var = Rho_var
  (** The resource-grade variables. *)

  module Eps_var = Eps_var
  (** The effect-grade variables. *)

  (** Effect-grade expressions. *)
  type eps =
    | Eps_var of Eps_var.t
    | Eps_const of GS.E.t
    | Eps_mul of eps * eps
    | Eps_join of eps * eps

  (** Resource-grade expressions. *)
  type rho =
    | Rho_var of Rho_var.t
    | Rho_const of GS.R.t
    | Rho_mul of rho * rho
    | Rho_join of rho * rho
    | Rho_map of eps  (** the image [∣eps∣] under {!GS.map} *)

  type subst = { rho_subst : rho Rho_var.Map.t; eps_subst : eps Eps_var.Map.t }
  (** A simultaneous substitution of both sorts, the identity outside its
      domain. *)

  val empty_subst : subst
  (** The identity substitution. *)

  (** Operations on effect-grade expressions. *)
  module Eps : sig
    type t = eps

    val var : Eps_var.t -> t
    (** [var eps_var] is the variable [eps_var]. *)

    val const : GS.E.t -> t
    (** [const c] is the closed grade [c]. *)

    val unit : t
    (** The unit constant. *)

    val top : t
    (** The top constant. *)

    val of_nat : int -> t
    (** [of_nat n] is the constant of [n] time steps. *)

    val mul : t -> t -> t
    (** [mul eps eps'] is the product [eps · eps']. *)

    val join : t -> t -> t
    (** [join eps eps'] is the join [eps ⊔ eps']. *)

    val free_vars : t -> Eps_var.Set.t
    (** [free_vars eps] is the set of variables of [eps]. *)

    val subst : subst -> t -> t
    (** [subst sigma eps] replaces each variable of [eps] by its image under
        [sigma]. *)

    val value : t -> GS.E.t option
    (** [value eps] is the grade a variable-free [eps] evaluates to, and [None]
        when [eps] has a variable. *)

    val equal : Language.Grade.bounds -> t -> t -> bool
    (** [equal bounds eps eps'] is syntactic equality, constants compared by the
        grade's [equal] under the cost model [bounds]. *)

    val print : t -> Format.formatter -> unit
    (** [print eps ppf] prints [eps], products binding tighter than joins. *)

    val to_string : t -> string
    (** [to_string eps] is the text {!print} prints. *)
  end

  (** Operations on resource-grade expressions. *)
  module Rho : sig
    type t = rho

    val var : Rho_var.t -> t
    (** [var rho_var] is the variable [rho_var]. *)

    val const : GS.R.t -> t
    (** [const c] is the closed grade [c]. *)

    val unit : t
    (** The unit constant. *)

    val top : t
    (** The top constant. *)

    val of_nat : int -> t
    (** [of_nat n] is the constant of [n] time steps. *)

    val mul : t -> t -> t
    (** [mul rho rho'] is the product [rho · rho']. *)

    val join : t -> t -> t
    (** [join rho rho'] is the join [rho ⊔ rho']. *)

    val map : eps -> t
    (** [map eps] is the image [∣eps∣]; the image of a constant is the constant
        {!GS.map} gives. *)

    val free_rho_vars : t -> Rho_var.Set.t
    (** [free_rho_vars rho] is the set of resource variables of [rho]. *)

    val free_eps_vars : t -> Eps_var.Set.t
    (** [free_eps_vars rho] is the set of effect variables of [rho], those under
        an image. *)

    val subst : subst -> t -> t
    (** [subst sigma rho] replaces each variable of [rho], of either sort, by
        its image under [sigma]. *)

    val value : t -> GS.R.t option
    (** [value rho] is the grade a variable-free [rho] evaluates to, an image
        through {!GS.map}, and [None] when [rho] has a variable. *)

    val equal : Language.Grade.bounds -> t -> t -> bool
    (** [equal bounds rho rho'] is syntactic equality, constants compared by the
        grades' [equal] under the cost model [bounds]. *)

    val print : t -> Format.formatter -> unit
    (** [print rho ppf] prints [rho], products binding tighter than joins. *)

    val to_string : t -> string
    (** [to_string rho] is the text {!print} prints. *)
  end
end

(** [Make (GS)] is the expressions over [GS]. *)
module Make (GS : Language.GradeSystem.S) : S with module GS = GS
