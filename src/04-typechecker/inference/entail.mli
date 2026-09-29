(** Entailment of grade orderings from hypotheses.

    An entailment is built once from the cost model and a set of hypotheses of
    both sorts, and answers every query on orderings [e ≾ e'] from them. The
    queries come at explicit strengths:

    - [closed]: the grade's order, where both sides are variable-free;
    - [derive]: the embedding of normal forms of
      {!GradeNormal.Make.SORT.decide_leq}, along the chains of the hypotheses
      whose both sides are single atoms, on the resource side also along the
      images of such effect hypotheses;
    - [follows]: [closed] where it holds, or [derive];
    - [entailed]: one of the hypotheses, or [follows];
    - [decided] and [valid] at no hypotheses: [closed] where both sides are
      variable-free and [derive] otherwise, and the latter also where the two
      sides are equal; an ordering [valid] holds at every instance.

    Every positive answer is backed by a derivation from the laws of the grades
    and the hypotheses: the decisions are sound. They are not complete: a
    negative answer means only that no derivation was found, and hypotheses
    other than atomic ones serve only by membership.

    The refutation of a set of hypotheses by chains between variable-free sides
    is {!check_closed}. *)

module Make (X : GradeExp.S) : sig
  type 'a hyps = 'a GradeNormal.Make(X).hyps
  (** Hypotheses of both sorts, carrying payloads of type ['a]. *)

  type 'a t
  (** The entailment from a set of hypotheses. *)

  val make : Grades.Grade.bounds -> 'a hyps -> 'a t
  (** [make bounds hyps] is the entailment from [hyps]. The chains along the
      hypotheses are computed when first needed, and shared by the queries. *)

  (** The queries on the orderings of one sort. *)
  module type SORT = sig
    type exp
    (** Expressions. *)

    val closed : Grades.Grade.bounds -> exp -> exp -> bool option
    (** [closed bounds e e'] is {!GradeNormal.Make.SORT.closed_leq}: the grade's
        order where [e] and [e'] are variable-free, and [None] otherwise. *)

    val derive : 'a t -> exp -> exp -> 'a list option
    (** [derive t e e'] is {!GradeNormal.Make.SORT.decide_leq} at the hypotheses
        of [t]: [Some used] with the payloads of the hypotheses used, or [None].
    *)

    val follows : 'a t -> exp -> exp -> bool
    (** [follows t e e'] is whether [closed] holds or [derive t] succeeds. *)

    val entailed : 'a t -> exp -> exp -> bool
    (** [entailed t e e'] is whether [e ≾ e'] is one of the hypotheses of [t],
        sides compared syntactically, or [follows t]. *)

    val decided : Grades.Grade.bounds -> exp -> exp -> bool
    (** [decided bounds e e'] is [closed] where it decides, and otherwise
        whether [derive] at no hypotheses succeeds. Applied to [bounds] alone,
        the decision procedure is shared by the orderings decided. *)

    val valid : Grades.Grade.bounds -> exp -> exp -> bool
    (** [valid bounds e e'] is whether [e] and [e'] are syntactically equal or
        [decided bounds e e']: the ordering holds at every instance. *)

    val is_atom : exp -> bool
    (** [is_atom e] is {!GradeNormal.Make.SORT.is_atom}: whether [e] is a single
        atom, so that a hypothesis between two atoms serves [derive]. *)

    val refute_leq_unit : Grades.Grade.bounds -> exp -> bool
    (** [refute_leq_unit bounds e] is whether some alternative of the normal
        form of [e] has a constant factor not below the unit, so that by the
        zero-product law no instance of [e] is below the unit
        ({!GradeNormal.Make.SORT.refute_leq_unit}). *)
  end

  module Rho : SORT with type exp = X.rho
  (** Resource orderings. *)

  module Eps : SORT with type exp = X.eps
  (** Effect orderings. *)

  type 'a closed_failure = 'a GradeNormal.Make(X).closed_failure =
    | Rho_failure of (X.rho, 'a list) GradeNormal.ordering
    | Eps_failure of (X.eps, 'a list) GradeNormal.ordering
        (** A variable-free ordering found to fail, with the payloads of the
            hypotheses it follows from. *)

  val check_closed :
    ?factors:bool ->
    Grades.Grade.bounds ->
    'a hyps ->
    ('a hyps, 'a closed_failure) result
  (** [check_closed ~factors bounds hyps] is
      {!GradeNormal.Make.SORT.check_closed} on each sort, the resource orderings
      first: the refutation of [hyps] by an ordering between variable-free sides
      that fails, of the hypotheses or of the chains of two or more steps along
      the hypotheses and, when [factors] (the default), from a factor of a
      product to the product. *)
end
