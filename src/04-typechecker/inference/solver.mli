(** The constraint solver.

    The solver traverses a constraint threading a state: a substitution on the
    unknowns, the set of unknowns in play, a residual of undecided atoms
    ({!Residual}), and the unifier of the skeletons of the subtyping atoms met
    ({!Skeleton.unifier}).

    - The skeletons of the two sides of a subtyping atom are unified under the
      unifier, once. The type unknowns of the classes this binds to a skeleton
      other than an unknown are instantiated so that the two sides of every
      demand have the same shape ({!Skeleton.Make.expand_traced}), and the
      residual is decomposed again under the instantiation. The atom is then
      decomposed.
    - A grade ordering, an eternality demand and a var-rule disjunction are
      added to the residual ({!Residual}): the variable-free orderings and the
      disjunctions decided are dropped.
    - An existential scope brings its unknowns into play.
    - A rigid scope is solved with a residual of its own and closed
      ({!RigidScope}): its local unknowns receive values, its atoms are kept
      outside it or deferred as conditions on its rigid variable; the rigid may
      not occur in the value of an unknown outside the scope, the escape check
      of skolem constants (Peyton Jones, Vytiniotis, Weirich and Shields, JFP
      2007). When the scope instantiated type unknowns, the pending demands are
      decomposed again. Every deferred condition is retried after the close.

    After the whole constraint the deferred conditions are retried and the
    residual read as hypotheses; the orderings between variable-free sides,
    directly or through chains of hypotheses, are decided by the grades' order.
    The search for a closed instance of the qualifier
    ({!Solver.Make.satisfiable}) decides them also through chains that pass from
    a factor of a product to the product when the other factors are above the
    unit, by the grade or along the hypotheses. *)

module Make (C : Constraint.S) : sig
  type context = Residual.Make(C).context
  (** The running times and the type definitions. *)

  type failure = Residual.Make(C).failure
  (** Why a constraint has no solution. *)

  type stuck = RigidScope.Make(C).stuck
  (** A rigid scope that cannot be closed. *)

  type solution = {
    subst : C.subst;  (** the values of the unknowns solved *)
    hyps : Residual.Make(C).hyps;
        (** the atoms left on the unknowns, the hypotheses [Q] *)
    obligations : Residual.Make(C).deferred list;
        (** the deferred rigid conditions, the obligations [R] *)
    context : context;
        (** the running times and type definitions solved under *)
  }
  (** A solution: every instance of the unknowns satisfying [Q] and [R]
      satisfies the constraint through [subst]. *)

  (** The outcome of solving. *)
  type outcome = Solved of solution | Refuted of failure | Stuck of stuck

  val solve : context -> C.t -> outcome
  (** [solve context c] solves [c]; its free unknowns are in play from the
      start. *)

  (** {1 Provenance} *)

  type decision = {
    reason : C.reason;
        (** the atom whose expansion, or whose decomposition, gave the unknown
            its value *)
    path : Language.Ast.step list;
        (** the position within the atom, outermost first, after the unfolding
            of aliases *)
  }
  (** Where a type unknown was decided: the atom, and the position within it,
      whose unification bound the class of the unknown to a skeleton other than
      an unknown. A class bound facing an unknown decided before, or facing the
      part of an atom's side that such an unknown stands for, inherits its
      decision; the part of a type at a path was decided where the innermost
      unknown on the way to it was. *)

  type mismatch = {
    atom : Residual.Make(C).sub;
        (** the atom whose expansion fails, its sides under the values of the
            unknowns solved before; the undecomposed atom when it is one the
            constraint states *)
    lhs_decided : decision option;
        (** where the part of its left side that fails was decided, when an
            unknown decided before stands for it or for a part enclosing it *)
    rhs_decided : decision option;  (** likewise for its right side *)
    related : (decision * Skeleton.t) list;
        (** the atoms other than [atom], each once, whose unification placed the
            unknowns of the failure in one class, each with the skeleton the
            class stands for ({!Skeleton.trace}) *)
  }
  (** The provenance of a shape mismatch or an occurs check. *)

  val solve_traced : context -> C.t -> outcome * mismatch option
  (** [solve_traced context c] is [solve context c] with the provenance of its
      failure when it is a failed expansion. *)

  val satisfiable : context -> solution -> (unit, failure) result
  (** [satisfiable context solution] searches a closed instance of the qualifier
      of [solution]: every unknown receives the value of the first rule of
      localisation that applies to it ({!RigidScope}), the deferred conditions
      are retried, and the orderings between variable-free sides decided,
      directly or through chains that run along the hypotheses and from a factor
      of a product to the product when the other factors are above the unit, by
      the grade or along the hypotheses. It is [Error] only when the search
      refutes the qualifier; an instance not found is no refutation.

      This is a provisional choice for top-level definitions: a definition is
      accepted unless the search refutes its qualifier, and each use of it
      checks the qualifier instantiated at the use. A qualifier that has no
      closed instance the search refutes is thus reported at the uses of the
      definition, not at the definition itself. *)

  val established : context -> solution -> (unit, failure) result
  (** [established context solution] finds a closed instance of the whole
      qualifier [Q ∧ R] of [solution]. It is {!satisfiable}, then
      [Error (Undecided_condition d)] when the search leaves a deferred
      condition [d] without unknowns neither discharged nor refuted, and
      otherwise the search for grades of the unknowns left at which the
      remaining orderings and conditions hold ({!RigidScope.Make.instance}):
      [Error (Unestablished _)] when none of the grades tried meets them. It is
      the check of a run, whose program is closed: there no later use may refute
      an obligation. *)

  val qualifier : solution -> C.t
  (** [qualifier solution] is [Q ∧ R] as a constraint, each obligation under the
      rigid scopes of its rigids. *)

  val generalise : ?fixed:C.free -> C.ty -> solution -> C.scheme
  (** [generalise ~fixed ty solution] is the reported scheme of [ty] under
      [solution] ({!Report}): the solved type and the hypotheses simplified, the
      unknowns not needed by the type or the obligations eliminated, and the
      scheme quantified over the unknowns that remain other than those of
      [fixed]. The unknowns of [fixed], those free in the environment, are never
      eliminated nor quantified. It is the generalisation of a top-level
      definition. *)

  val unsimplified : ?fixed:C.free -> C.ty -> solution -> C.scheme
  (** [unsimplified ~fixed ty solution] is the scheme of [ty] under [solution]
      as solved: the solved type, the qualifier {!qualifier}, and the scheme
      quantified over their unknowns other than those of [fixed]. It is
      equivalent to {!generalise}, and keeps the atoms the simplification
      eliminates, through which the explanation of a failure at a use of the
      definition is traced. *)

  val print_outcome : outcome -> Format.formatter -> unit
  (** [print_outcome outcome ppf] prints [outcome], for debugging. *)
end
