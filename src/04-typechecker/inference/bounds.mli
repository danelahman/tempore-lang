(** Values for one grade unknown [v], read off the orderings of its sort.

    An ordering is valid when it is reflexive or decided at no hypotheses
    ([leq]): it holds at every instance and bounds [v] on neither side.

    - Lowering: every ordering has [v] on no right side, is [x ≾ v] with [x]
      free of [v], a lower bound, or is valid; the value is the join of the
      lower bounds.
    - Raising: some ordering is [v ≾ U] with [U] free of [v], and every ordering
      is reflexive, has [v] on no left side, is [v ≾ x'] with [x'] the bound [U]
      or decided above it, or is valid; the value is [U], the first such bound.
*)

type 'e sort = {
  equal : 'e -> 'e -> bool;  (** syntactic equality of expressions *)
  occurs : 'e -> bool;  (** whether [v] occurs in an expression *)
  is_unknown : 'e -> bool;  (** whether an expression is [v] itself *)
  leq : 'e -> 'e -> bool;  (** an ordering decided at no hypotheses *)
  join : 'e -> 'e -> 'e;  (** the join of two expressions *)
}
(** How the expressions of one sort are read for the unknown [v]. *)

type ('e, 'a) lows = {
  lower : 'e list;  (** the lower bounds, in order *)
  lower_rest : ('e, 'a) GradeNormal.ordering list;
      (** the orderings other than [x ≾ v], in order *)
}
(** The lower bounds of [v]. *)

type ('e, 'a) ups = {
  cap : 'e;  (** the upper bound *)
  upper_rest : ('e, 'a) GradeNormal.ordering list;
      (** the orderings other than [v ≾ x'], in order *)
}
(** An upper bound of [v]. *)

val lows : 'e sort -> ('e, 'a) GradeNormal.ordering list -> ('e, 'a) lows option
(** [lows sort os] is the lower bounds of [v] in [os], and [None] when some
    ordering has [v] on its right side and is neither valid nor a lower bound.
*)

val ups : 'e sort -> ('e, 'a) GradeNormal.ordering list -> ('e, 'a) ups option
(** [ups sort os] is the first upper bound of [v] in [os] that caps the others,
    and [None] when there is none. *)

val free_right : 'e sort -> ('e, 'a) GradeNormal.ordering list -> bool
(** [free_right sort os] is whether each ordering of [os] is valid or has [v] on
    no right side. *)

val free_left : 'e sort -> ('e, 'a) GradeNormal.ordering list -> bool
(** [free_left sort os] is whether each ordering of [os] is valid or has [v] on
    no left side. *)

val join_all : 'e sort -> 'e -> 'e list -> 'e
(** [join_all sort x xs] is the join of [x] and [xs], from the left. *)
