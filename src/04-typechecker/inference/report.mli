(** Reports: a solved definition simplified into a qualified scheme
    [∀Θ. Q ∧ R ⇒ X], with [Q] the hypotheses on the unknowns, [R] the deferred
    rigid conditions and [X] the reported type.

    Unknowns of a given set, the fixed ones, are never eliminated nor
    quantified; the unknowns of the deferred conditions are fixed too.

    {2 Simplification}

    The hypotheses are written canonically: every grade canonical, an ordering
    with a join on its left side split into one ordering per alternative. Each
    var-rule disjunction [Et(A) ∨ ρ ≾ 1] is settled against the hypotheses and
    the disjunctions settled before it, the last first:
    - dropped when [ρ ≾ 1] is entailed;
    - replaced by [ρ ≾ 1] when [A] is eternal at no instance;
    - dropped when the type unknowns the eternality of [A] depends on are
      entailed eternal;
    - replaced by their eternality when [ρ ≾ 1] holds at no instance;
    - kept otherwise.

    A disjunction is then dropped when another of the same type has a grade
    entailed above its own; of two entailing each other the later is kept.
    Subtyping and eternality atoms entailed by the atoms kept before them are
    dropped, entailment being reachability along the subtyping atoms (in both
    directions for eternality); a grade ordering is dropped when reflexive or
    repeated.

    An ordering is entailed when it follows from the hypotheses
    ({!Entail.Make.SORT.follows}); for the equality of grades below, when it is
    one of them or follows from them along the orderings between two atoms only
    ({!Entail.Make.SORT.follows_atomic}).

    {2 Polarity}

    An unknown occurs in the reported type with the variance of each position: a
    function's domain and a box's grade reverse it, the input of a handler type
    and the arguments of a type application are invariant. In an ordering it is
    bounded above on the left side and below on the right side; in a subtyping
    atom likewise; the grade of a disjunction bounds it above; an eternality
    atom and the type of a disjunction bound nothing. An atom that holds at
    every instance, a reflexive one or an ordering decided at no hypotheses,
    bounds nothing either; it blocks no lowering or raising and is kept.

    {2 Elimination}

    Steps are taken one at a time, each at the first unknown, by creation, where
    its test succeeds, the first test that succeeds for some unknown being
    taken:
    + equality of grades: an ordering sets the unknown against an expression
      that is an earlier unknown or free of it, and the hypotheses entail both
      directions; the unknown is replaced by the expression, and the orderings
      made reflexive are dropped (effect unknowns first, then resource ones);
    + lowering: the unknown has lower bounds ({!Values.lower}), is bounded below
      by no other hypothesis, and occurs in the type at no contravariant
      position; it is replaced by the join of its lower bounds, and the
      orderings bounding it below are dropped;
    + raising: the unknown has an upper bound capping the others
      ({!Values.raise}), is bounded above by no other hypothesis, and occurs in
      the type at no covariant position; it is replaced by the bound, and the
      orderings bounding it above are dropped;
    + cycle elimination: a type unknown on a cycle of subtyping atoms is
      replaced by the representative of its strongly connected component, a
      fixed member if there is one and otherwise the earliest, and the atoms
      made reflexive are dropped;
    + a type unknown with a lower bound [β <: α], bounded below by no other atom
      and occurring in the type at no contravariant position, is replaced by
      [β].

    Then the type and the hypotheses are written canonically again, the
    disjunctions settled again, and every subtyping atom and grade ordering
    entailed by the others dropped: those kept and those not yet examined.

    {2 Strengthening}

    The scheme quantifies the unknowns that occur in the type, the hypotheses or
    the deferred conditions and are not fixed. *)

module Make (C : Constraint.S) : sig
  type context = Residual.Make(C).context
  (** The cost model and the type definitions. *)

  type hyps = Residual.Make(C).hyps
  (** Hypotheses. *)

  type deferred = Residual.Make(C).deferred
  (** Deferred rigid conditions. *)

  type t = {
    ty : C.ty;  (** the reported type [X] *)
    hyps : hyps;  (** the hypotheses [Q] *)
    obligations : deferred list;  (** the deferred conditions [R] *)
  }
  (** A report. *)

  val simplify : context -> hyps -> hyps
  (** [simplify context hyps] is [hyps] written canonically, its disjunctions
      settled and the entailed ones dropped, and its type atoms and repeated
      orderings pruned. *)

  val eliminate : context -> fixed:C.free -> C.ty -> hyps -> C.ty * hyps
  (** [eliminate context ~fixed ty hyps] is [ty] and [hyps] after the
      elimination steps, none at an unknown of [fixed]. *)

  val trim : context -> hyps -> hyps
  (** [trim context hyps] is [hyps] with its disjunctions settled again and
      every subtyping atom and grade ordering entailed by the others dropped. *)

  val report : context -> fixed:C.free -> C.ty -> hyps -> deferred list -> t
  (** [report context ~fixed ty hyps obligations] simplifies [hyps], eliminates
      the unknowns not in [fixed] nor in [obligations], writes the type and the
      hypotheses canonically, and trims the hypotheses; the obligations are
      written canonically. *)

  val scheme : fixed:C.free -> t -> C.scheme
  (** [scheme ~fixed report] is [∀Θ. Q ∧ R ⇒ X], [Θ] the unknowns of [report]
      not in [fixed]. *)
end
