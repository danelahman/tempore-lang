(** Closing the rigid scope of a handler clause, and retrying the deferred rigid
    conditions.

    {2 Scopes}

    A clause is solved for every value of its rigid effect variable [j]. The
    unknowns outer to its scope are those free in the values of the unknowns the
    scope was entered with; [j] is one of them, and never receives a value. The
    other unknowns are local to the scope.

    {2 Localisation}

    Before the scope closes, its local grade unknowns receive values by chaotic
    iteration with a worklist (Cousot and Cousot, POPL 1977). The atoms are kept
    in canonical form: both sides of every ordering and every disjunction's
    grade written canonically, one ordering per alternative of a left side, the
    orderings decided at no hypotheses dropped; an atom is rewritten when a
    value changes it. Each local member of a cycle of orderings between whole
    unknowns is sent to a representative of the cycle: an outer member where
    there is one, else one that may not move, else the least, each by creation;
    this is done at the start and whenever a rewritten ordering closes a cycle.
    The worklist starts with every local unknown, the effect unknowns first,
    each sort latest created first. A local unknown taken from it that occurs in
    no type receives the value of the first of these rules that applies:
    - lowering: the join of its lower bounds, where it occurs on a right side
      only as the whole side; the orderings with it on the right are dropped;
    - raising: an upper bound decided at no hypotheses below its other upper
      bounds, where it occurs on a left side only as the whole side and in no
      disjunction's grade;
    - the unit, where it has no lower bound, occurs, and the unit is least;
    - the top, where it occurs on no left side and in no disjunction's grade.

    A value keeps the deferred conditions of inner scopes: lowering, and the
    unit, where the unknown is on no greater side of a condition; raising, and
    the top, where it is on no smaller side. The local unknowns of the atoms a
    value changes or drops are added to the worklist. Where the worklist is
    empty, a disjunction whose grade follows below the unit from the orderings
    ({!Entail.Make.SORT.follows}) is dropped, and a disjunction whose type is
    never eternal becomes its grade below the unit, the unknowns of each added
    to the worklist. Where no disjunction is so settled, a set of local unknowns
    reached from [j] is sent to the top at once: each is bounded below by an
    expression decided to be the top once [j] and the members before it are;
    each ordering with a member on its left has on its right an expression
    decided to be the top once the members are, or one of outer unknowns other
    than [j] alone; no member occurs in a type or a disjunction's grade.

    {2 Split}

    Then each atom of the scope is kept outside it, discharged, deferred or
    blocks the close:
    - an atom free of [j] is kept;
    - an ordering that follows from the orderings free of [j] is discharged;
    - an ordering with [j] on its right side only is kept at [j] the unit, when
      the unit of the effect grades is least;
    - an ordering with [j] on its left side only is kept at [j] the top, when
      its right side has outer unknowns alone;
    - any other ordering of outer unknowns and [j] alone is deferred, the
      deferred orderings forming one new condition quantified over [j];
    - a disjunction is kept at [j] the top, its type being free of [j];
    - a deferred condition of an inner scope is carried outward, quantified over
      [j] where it mentions it, when it has outer unknowns and rigids alone.

    An ordering or an inner condition that mentions a local unknown and cannot
    be kept blocks the close: the scope is stuck. A demand or disjunction whose
    type mentions [j] refutes it.

    {2 Retry}

    A deferred condition's ordering is dropped when it follows from the
    orderings of the residual ({!Entail.Make.SORT.follows}), the rigids being
    opaque. An ordering whose unknowns are rigids alone is otherwise evaluated
    at every assignment to the rigids it mentions of the unit, the top, the
    grade of one delay step and the witnesses the grades supply for its
    constants and the number of occurrences of the rigids on either side
    ({!Grades.GradeSystem.S.witnesses}): it refutes the condition at the first
    assignment where it fails, and is dropped when it holds at all of them and
    mentions no rigid, or a single one whose witnesses are complete. An ordering
    in several rigids is thus refuted, never discharged, by the grid of their
    witnesses. A condition left with no ordering is dropped.

    {2 Closed instances}

    The orderings and deferred conditions of a residual are split into
    components sharing unknowns, and each component is searched depth first with
    backtracking, within a budget of trials of its own, for a grade per unknown
    at which every one of its items holds: an ordering decided true between
    variable-free sides, a condition discharged by its retry. An effect unknown
    ranges over the unit, the top, the grade of one delay step, the effect
    constants of the component and the witnesses the grades supply for its
    constants; a resource unknown over the unit, the top, one time step, the
    resource constants, the images of the effect constants and the witnesses for
    them. The witnesses are those for the largest number of occurrences of the
    component's unknowns on one side of an item. The unknowns occurring in more
    items are assigned first, and an item is checked once its last unknown is.
    The type unknowns are sent to [unit]. *)

module Make (C : Constraint.S) : sig
  type residual = Residual.Make(C).t
  (** Residuals. *)

  type scope = {
    rigid : C.X.Eps_var.t;  (** the rigid variable [j] *)
    outer_rhos : C.X.Rho_var.Set.t;  (** the outer resource unknowns *)
    outer_eps : C.X.Eps_var.Set.t;
        (** the outer effect unknowns, other than [j] *)
  }
  (** A rigid scope being closed. *)

  (** What blocks the close of a scope. *)
  type blocking =
    | Blocking_rho of Residual.Make(C).rho_ordering
    | Blocking_eps of Residual.Make(C).eps_ordering
    | Blocking_deferred of Residual.Make(C).deferred

  type stuck = { stuck_origin : Reason.rigid_origin; blocking : blocking }
  (** A scope that cannot be closed: its clause, and the atom that blocks it. *)

  (** Why a scope does not close. *)
  type error = Refused of Residual.Make(C).failure | Stuck of stuck

  val localise :
    Residual.Make(C).context -> scope -> residual -> C.X.subst * residual
  (** [localise context scope r] is the values given to local unknowns of
      [scope] and the residual [r] under them. *)

  val localise_all :
    Residual.Make(C).context -> residual -> C.X.subst * residual
  (** [localise_all context r] is {!localise} with every unknown local and no
      rigid: a search for a closed instance of [r]. *)

  val split :
    Residual.Make(C).context ->
    scope ->
    Reason.rigid_origin ->
    residual ->
    (residual, error) result
  (** [split context scope origin r] is the atoms of [r] kept outside [scope]
      and its deferred conditions, [j] no longer free in them; [origin] is the
      clause of [j]. *)

  val retry :
    Residual.Make(C).context ->
    residual ->
    (residual, Residual.Make(C).failure) result
  (** [retry context r] is [r] with each deferred condition retried against the
      orderings of [r]. *)

  val default_budget : int
  (** The number of candidates {!instance} tries by default in each component:
      100 000. *)

  val instance :
    ?budget:int ->
    Residual.Make(C).context ->
    residual ->
    (C.X.subst, Residual.Make(C).failure) result
  (** [instance ~budget context r] is the grades of a closed instance of the
      orderings and deferred conditions of [r], [unit] for its type unknowns
      meeting its other atoms once [r] is decomposed ({!Residual.Make.atomise}).
      It is [Error (Unestablished _)] with the items of a component when no
      assignment of the grades tried meets them all, [abandoned] when [budget]
      ({!default_budget} by default) candidates were tried in the component
      before its search ended. An instance not found is no refutation: the
      grades tried are finitely many. *)
end
