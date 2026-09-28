(** The mode-cost grades: the costs of a computation between the modes of a
    device, such as a radio switched on and off, as max-plus matrices.

    A grade gives each pair of modes [(p, q)] the greatest cost of the runs that
    start in the mode [p] and end in the mode [q], or none if there is no such
    run: an operation performed only in some modes, or changing the mode, has no
    run from the other modes. Sequencing is the max-plus product of the
    matrices, the cost from [p] to [r] being the greatest over the modes [q] of
    the cost from [p] to [q] followed by that from [q] to [r]; the join and the
    order are taken pair by pair. Delays cost nothing and keep the mode, and an
    idle draw is charged by operations such as [Sleep].

    The modes are the capitalised names of the literals, a grade naming finitely
    many and treating all the others alike. *)

(** The costs: no run, below the natural numbers, below [∞]. *)
type cost = No_run | Cost of int | Unbounded

module ModeCosts : Grade.S
(** The mode-cost grade, ["mode-costs"].

    - The unit keeps every mode at cost [0], and the top costs [∞] between any
      two modes. The unit is not least, and [mul] does not commute.
    - [of_nat] and [of_bounds] are constantly the unit.
    - [of_lit] reads [⊤] as the top, a cost [n] or [∞] as keeping every mode at
      that cost, an entry [(From, To, n)] as the runs from [From] to [To] at
      cost [n], and a tuple of entries, each pair of modes listed once, as their
      runs; the runs an entry does not give are none. [show] prints alike, and
      the costs of the modes not named as entries of [_]: [(p,_,n)] from [p] to
      another mode, [(_,q,n)] from another mode to [q], [(_,_,n)] keeping
      another mode and [(_,≠,n)] between two others; these have no literal. A
      grade of no run is printed [⊥].
    - No counterexample is offered, and the witnesses are the constants and
      their pairwise products, and partial. *)
