(** The mode-cost grades: the costs of a computation between the modes of a
    device, such as a radio switched on and off, as max-plus matrices.

    A grade gives each pair of modes [(p, q)] the greatest cost of the runs that
    start in the mode [p] and end in the mode [q], or none if there is no such
    run. Besides the ordinary modes there is the absorbing mode [Stuck], in
    which a run is stuck: an operation performed only in some modes, or changing
    the mode, gets stuck from the other modes. A grade is total, having a run
    from every mode; its only run from [Stuck] is to [Stuck], at cost [0]; and
    each change between two distinct ordinary modes costs at least [1].
    Sequencing is the max-plus product of the matrices, the cost from [p] to [r]
    being the greatest over the modes [q] of the cost from [p] to [q] followed
    by that from [q] to [r]; the join and the order are taken pair by pair, no
    run being least. Delays cost nothing and keep the mode, and an idle draw is
    charged by operations such as [Sleep].

    These grades are closed under the product and the join, and the unit is the
    only grade below the unit: if [x · y ≾ 1], then [x] changes no mode and gets
    stuck from none, since a change costs at least [1] and [Stuck] is never
    left, hence [x ≾ 1] and [y ≾ 1].

    The modes are the capitalised names of the literals, [Stuck] naming the
    absorbing mode, a grade naming finitely many and treating all the others
    alike. *)

(** The costs: no run, below the natural numbers, below [∞]. *)
type cost = No_run | Cost of int | Unbounded

(** The mode-cost grade over any delays [D], as {!ModeCosts}. *)
module Make (D : Delay.S) : Grade.S with type Delay.t = D.t

module ModeCosts : Grade.S with type Delay.t = Delay.Nat.t
(** The mode-cost grade, ["mode-costs"], over {!Delay.Nat}.

    - The unit keeps every mode at cost [0], and the top costs [∞] between any
      two modes and into [Stuck]. The unit is not least, and [mul] does not
      commute.
    - [of_delay] and [of_bounds] are constantly the unit.
    - [of_lit] reads [⊤] as the top, a cost [n] or [∞] as keeping every mode at
      that cost, an entry [(From, To, n)] as the runs from [From] to [To] at
      cost [n], and a tuple of entries, each pair of modes listed once, as their
      runs. The modes not named are written [_]: [(p, _, n)] from [p] to a mode
      not named, [(_, q, n)] from a mode not named to [q], [(_, _, n)] keeping a
      mode not named, [(_, ≠, n)] from a mode not named to another and
      [(_, Stuck, n)] from a mode not named into [Stuck]. The runs the entries
      do not give are none, and a mode from which no entry starts, the modes not
      named starting from [_], is stuck at cost [0]. A change between two
      distinct ordinary modes costs at least [1], and the only entry from
      [Stuck] is [(Stuck, Stuck, 0)], which the grade holds in any case.
    - [show] prints alike, leaving implicit the entry [(From, Stuck, 0)] of a
      mode from which it is the only run, where another entry names the mode;
      the grade stuck at cost [0] from every mode is printed
      [(Stuck, Stuck, 0)]. Every printed grade reads back as itself.
    - No counterexample is offered, and the witnesses are the constants and
      their pairwise products, and partial. *)
