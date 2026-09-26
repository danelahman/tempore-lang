(** The constraint solver.

    The solver traverses a constraint threading a state: a substitution on the
    unknowns, the set of unknowns in play, and a residual of undecided atoms
    ({!Residual}).

    - A subtyping atom is expanded together with the pending subtyping demands:
      the type unknowns are instantiated so that the two sides of every demand
      have the same shape ({!Skeleton.Make.expand}); the residual is decomposed
      again under the instantiation, and the atom is decomposed.
    - A grade ordering, an eternality demand and a var-rule disjunction are
      added to the residual, the decided ones dropped.
    - An existential scope brings its unknowns into play.
    - A rigid scope is solved with a residual of its own, expanded again, and
      closed ({!RigidScope}): its local unknowns receive values, its atoms are
      kept outside it or deferred as conditions on its rigid variable; the rigid
      may not occur in the value of an unknown outside the scope. Every deferred
      condition is retried after the close.

    After the whole constraint the deferred conditions are retried, the pending
    demands expanded and decomposed a last time, and the residual read as
    hypotheses; the orderings between variable-free sides, directly or through
    chains of hypotheses, are decided by the grades' order. *)

module Make (C : Constraint.S) : sig
  type context = Residual.Make(C).context
  (** The cost model and the type definitions. *)

  type failure = Residual.Make(C).failure
  (** Why a constraint has no solution. *)

  type stuck = RigidScope.Make(C).stuck
  (** A rigid scope that cannot be closed. *)

  type solution = {
    subst : C.subst;  (** the values of the unknowns solved *)
    hyps : Residual.Make(C).hyps;
        (** the atoms left on the unknowns, the qualifier [Q] *)
    obligations : Residual.Make(C).deferred list;
        (** the deferred rigid conditions, the obligations [R] *)
  }
  (** A solution: every instance of the unknowns satisfying [Q] and [R]
      satisfies the constraint through [subst]. *)

  (** The outcome of solving. *)
  type outcome = Solved of solution | Refuted of failure | Stuck of stuck

  val solve : context -> C.t -> outcome
  (** [solve context c] solves [c]; its free unknowns are in play from the
      start. *)

  val satisfiable : context -> solution -> (unit, failure) result
  (** [satisfiable context solution] searches a closed instance of the qualifier
      of [solution]: every unknown receives the value of the first rule of
      localisation that applies to it ({!RigidScope}), the deferred conditions
      are retried, and the orderings between variable-free sides decided. It is
      [Error] only when the search refutes the qualifier; an instance not found
      is no refutation. *)

  val qualifier : solution -> C.t
  (** [qualifier solution] is [Q ∧ R] as a constraint, each obligation under the
      rigid scopes of its rigids. *)

  val generalise : ?fixed:C.free -> C.ty -> solution -> C.scheme
  (** [generalise ~fixed ty solution] is the scheme of [ty] under [solution],
      quantified over every unknown free in the solved type or in
      {!qualifier}[ solution] other than those of [fixed], with qualifier
      {!qualifier}[ solution]. It stands for the generalisation of a top-level
      definition, [fixed] being the unknowns free in the environment. *)

  val print_outcome : outcome -> Format.formatter -> unit
  (** [print_outcome outcome ppf] prints [outcome], for debugging. *)
end
