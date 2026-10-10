(** Normal forms of open grade expressions and the decisions made on them.

    {2 Normal forms}

    An expression is flattened to a sum of alternatives, each a product of
    atoms: constants and variables. Adjacent constants are multiplied, units
    dropped, products distributed over joins and repeated alternatives merged; a
    sum with the top among its alternatives is the top. Where the grade's
    product is commutative, each product is its constant followed by its
    variables in creation order. A sum is nonempty; a product may be empty, and
    is then the unit.

    {2 Decisions}

    Orderings are decided soundly, not completely: a positive answer is backed
    by a derivation from the laws and the hypotheses, and a negative one means
    only that none was found. Hypotheses are orderings carrying a payload of the
    caller's choosing, such as a source location; a decision reports the
    payloads of the hypotheses it uses, and a failed closed check the payloads
    of the hypotheses whose chain it refutes.

    Every operation depending on the grades' order or equality takes the running
    times {!Grades.Grade.bounds}. *)

type ('c, 'v) atom =
  | Const of 'c  (** a closed grade *)
  | Var of 'v  (** a variable *)

(** An atom of a product. *)

type ('e, 'a) ordering = { lhs : 'e; rhs : 'e; info : 'a }
(** The ordering [lhs ≾ rhs] between expressions of type ['e], with the payload
    [info]. *)

module Make (X : GradeExp.S) : sig
  (** The variable atoms of a resource product. *)
  type rho_var =
    | Resource of X.Rho_var.t  (** a resource variable *)
    | Image of X.Eps_var.t  (** the image [∣eps_var∣] of an effect variable *)

  type 'a hyps = {
    rho_hyps : (X.rho, 'a) ordering list;
    eps_hyps : (X.eps, 'a) ordering list;
  }
  (** Assumed orderings of both sorts. *)

  val no_hyps : 'a hyps
  (** The empty set of hypotheses. *)

  type 'a index = {
    hyps : 'a hyps Lazy.t;  (** every hypothesis *)
    rho_of : X.Rho_var.t -> (X.rho, 'a) ordering list;
        (** the resource hypotheses in which a resource variable occurs *)
    rho_of_image : X.Eps_var.t -> (X.rho, 'a) ordering list;
        (** the resource hypotheses in which an effect variable occurs *)
    eps_of : X.Eps_var.t -> (X.eps, 'a) ordering list;
        (** the effect hypotheses in which an effect variable occurs *)
  }
  (** Hypotheses of both sorts, found by the variables occurring in them. Each
      list may hold further hypotheses, and repeat them. *)

  (** The operations of one sort. *)
  module type SORT = sig
    type exp
    (** Expressions. *)

    type const
    (** Closed grades. *)

    type var
    (** Variable atoms. *)

    type product = (const, var) atom list
    (** A product of atoms, the empty product being the unit. *)

    type sum = product list
    (** A nonempty join of products. *)

    val normal : Grades.Grade.bounds -> exp -> sum
    (** [normal bounds e] is the normal form of [e]. *)

    val fold_sum : Grades.Grade.bounds -> sum -> sum
    (** [fold_sum bounds s] groups the alternatives of [s] by their sequence of
        variables, in the order of those sequences, and folds each group that
        varies in a single constant slot into one alternative, that slot holding
        the join of its constants. *)

    val canon_sum : Grades.Grade.bounds -> sum -> sum
    (** [canon_sum bounds s] is [s] with, where the unit is least, each product
        with the top among its factors replaced by the top, then grouped and
        folded as by {!fold_sum}, with every alternative decided below another
        at no hypotheses dropped, repeated until the sum stops shrinking. *)

    val read_back_product : product -> exp
    (** [read_back_product p] is [p] as a right-nested product, the empty
        product being the unit. *)

    val read_back : sum -> exp
    (** [read_back s] is [s] as a right-nested join.

        Raises [Invalid_argument] on the empty list, which is no sum. *)

    val canon : Grades.Grade.bounds -> exp -> exp
    (** [canon bounds e] is the canonical form of [e], the read-back of
        {!canon_sum} of its normal form. *)

    val alternatives : Grades.Grade.bounds -> exp -> exp list
    (** [alternatives bounds e] is the alternatives of the canonical form of
        [e], each the read-back of a product of {!canon_sum}, in order. *)

    val decide_leq :
      Grades.Grade.bounds -> 'a hyps -> exp -> exp -> 'a list option
    (** [decide_leq bounds hyps e e'] is [Some used] when [e ≾ e'] is derived
        from [hyps], [used] being the payloads of the hypotheses the derivation
        uses, in order and possibly repeated, and [None] when no derivation is
        found. Each alternative of [e] is compared with some alternative of the
        {!fold_sum} of [e'], product against product by an embedding of the left
        into the right, which matches atoms in order, passes over atoms above or
        below the unit, lets an atom above the top absorb a run of atoms, and
        multiplies constants on either side of an atom passed over; where the
        product commutes, as multisets. Atoms are compared by the grade's order,
        by identity, and along the chains between atoms of the graph of the
        hypotheses of {!check_closed}, with its steps from factors to products,
        whatever the sides the chains pass through; on the resource side also
        along the images of such effect chains. Where [e] is a side of a
        hypothesis, [e ≾ e'] is also derived along a chain of that graph from
        [e] to a side that is [e'] or is so derived below it.

        The steps from factors draw their evidence from [hyps], so the
        derivations are sound where the hypotheses hold together: conjuncts of a
        qualifier, not atoms of a disjunction or of a quantified condition.

        Applied to [bounds] and [hyps] alone, it is a decision procedure whose
        graph, with its chains through the sides that are not atoms, is built
        once, and whose chains out of each atom are computed when first needed,
        shared by the orderings it decides. At no hypotheses it is the embedding
        alone. *)

    val decide_leq_atomic :
      Grades.Grade.bounds -> 'a hyps -> exp -> exp -> 'a list option
    (** [decide_leq_atomic bounds hyps e e'] is the embedding of {!decide_leq}
        with atoms compared along the chains of the hypotheses whose both sides
        are single atoms only, on the resource side also along the images of
        such effect hypotheses: a fragment of {!decide_leq}. *)

    val decide_leq_atomic_indexed :
      Grades.Grade.bounds -> 'a index -> exp -> exp -> 'a list option
    (** [decide_leq_atomic_indexed bounds index e e'] succeeds exactly where
        {!decide_leq_atomic} at the hypotheses of [index] does, possibly with
        another derivation. The chains are found by breadth-first search along
        the hypotheses of the variables met, forward from a variable and
        backward to the target from a constant; all hypotheses are read only
        where a search meets a constant. Applied to [bounds] and [index] alone,
        each search runs once and is shared by the orderings decided. *)

    val split :
      Grades.Grade.bounds -> (exp, 'a) ordering -> (exp, 'a) ordering list
    (** [split bounds o] is one ordering per alternative of the canonical form
        of [o.lhs], each below the canonical form of [o.rhs] and carrying
        [o.info]. *)

    val canon_orderings :
      Grades.Grade.bounds -> (exp, 'a) ordering list -> (exp, 'a) ordering list
    (** [canon_orderings bounds os] is every ordering of [os] {!split}, in
        order. *)

    val value : exp -> const option
    (** [value e] is the grade a variable-free [e] evaluates to, and [None] when
        [e] has a variable. *)

    val is_atom : exp -> bool
    (** [is_atom e] is whether [e] is a single atom of {!decide_leq}: a
        variable, a constant or, on the resource side, the image of an effect
        variable. *)

    val closed_leq : Grades.Grade.bounds -> exp -> exp -> bool option
    (** [closed_leq bounds e e'] decides [e ≾ e'] by the grade's order when both
        sides are variable-free, and is [None] otherwise. *)

    val check_closed :
      ?factors:bool ->
      Grades.Grade.bounds ->
      (exp, 'a) ordering list ->
      ((exp, 'a) ordering list, (exp, 'a list) ordering) result
    (** [check_closed ~factors bounds os] decides by the grade's order the
        variable-free orderings of [os], and then the orderings between
        variable-free expressions, compared syntactically, joined by a chain of
        two or more steps. A step is an ordering of [os] or, when [factors] (the
        default), a step from a factor to a side of [os] whose normal form is a
        single product of two or more atoms, the other factors being above the
        unit: from each atom, and from the product of the constants, in order,
        when there are two or more. An atom is above the unit when it is a
        constant above it, or a variable where the unit is least, the variables
        of a resource image where the effect grade's unit is, or a variable that
        the steps reach from a variable-free side of [os] above the unit, the
        steps being computed again with the variables so found until none is
        added. This last evidence is drawn from [os] alone, and is sound only
        where the orderings of [os] hold together.

        It is [Error o] for the first ordering that fails, the orderings of [os]
        first, then the chains in the order of the sides and, for each pair, the
        shortest chain of {!Reach.chain}; [o.info] is the payloads of the
        orderings it follows from. It is otherwise [Ok] of the orderings of [os]
        that have a variable. A failure refutes the conjunction of [os], which
        are therefore conjuncts of a qualifier, not atoms of a disjunction or of
        a quantified condition. *)

    val refute_leq_unit : Grades.Grade.bounds -> exp -> const option
    (** [refute_leq_unit bounds e] is [Some c] when some alternative of the
        normal form of [e] has a constant factor [c] not below the unit, so that
        by the zero-product law no instance of [e] is below the unit, and [None]
        otherwise. *)
  end

  (** Resource grades. *)
  module Rho :
    SORT with type exp = X.rho and type const = X.GS.R.t and type var = rho_var

  (** Effect grades. *)
  module Eps :
    SORT
      with type exp = X.eps
       and type const = X.GS.E.t
       and type var = X.Eps_var.t

  (** A variable-free ordering found to fail, with the payloads of the
      hypotheses it follows from. *)
  type 'a closed_failure =
    | Rho_failure of (X.rho, 'a list) ordering
    | Eps_failure of (X.eps, 'a list) ordering

  val canon_hyps : Grades.Grade.bounds -> 'a hyps -> 'a hyps
  (** [canon_hyps bounds hyps] is [hyps] with each ordering {!SORT.split},
      applied to the orderings of both grade sorts. *)

  val check_closed_hyps :
    ?factors:bool ->
    Grades.Grade.bounds ->
    'a hyps ->
    ('a hyps, 'a closed_failure) result
  (** [check_closed_hyps ~factors bounds hyps] is {!SORT.check_closed} on each
      sort, the resource orderings first. *)
end
