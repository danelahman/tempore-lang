(** Values for one grade unknown [v], read off the orderings of its sort.

    An ordering is valid when it holds at every instance ([valid]); it bounds
    [v] on neither side. A value is given where an occurrence oracle allows it:
    whether [v] may decrease, or increase, without changing the meaning of the
    atoms other than the orderings of its sort that the value discharges.
    Lowering and raising follow the elimination of variables by polarity
    (Pottier, ICFP 1996; Trifonov and Smith, SAS 1996).

    - Lowering: every ordering has [v] on no right side, is [x ≾ v] with [x]
      free of [v], a lower bound, is a cycle [p ≾ v] with [v] in [p] where the
      sort reads cycles, or is valid; some ordering is a lower bound, and [v]
      may decrease. The value is the join [L] of the lower bounds where every
      cycle holds at it, and otherwise the least closure of [L] the cycles admit
      ({!section-cycles}); it discharges the lower bounds and the cycles.
    - Raising: some ordering is [v ≾ U] with [U] free of [v], and every ordering
      is reflexive, has [v] on no left side, is [v ≾ x'] with [U ≾ x'] valid, or
      is valid; [v] may increase. The value is [U], the first such bound, and it
      discharges the orderings [v ≾ x'] it caps.
    - Least: the unit is least, the orderings are as for lowering with no lower
      bound, and [v] may decrease. The value is the unit where every cycle holds
      at it, and otherwise its least closure the cycles admit; it discharges the
      cycles.
    - Top: every ordering with [v] on its left side is valid, and [v] may
      increase. The value is the top.
    - Forced unit: the unit is least and an ordering [v ≾ y], its left side [v]
      when written canonically, has [y] decided below the unit. The value is the
      unit, at every solution of the ordering, whatever the occurrences of [v].
    - Equating: an ordering sets [v] against an expression [b], an earlier
      unknown or free of [v], that the hypotheses entail equal to [v]. The value
      is [b].

    {2:cycles Cycles}

    The value of [v] under lower bounds of join [L] and cycles is the first of
    the following at which every cycle holds, decided at no hypotheses: [L]; for
    a cycle [v · v ≾ v] and a variable-free [L], its closure [L⁺]
    ({!Grades.Grade.S.plus}); for the cycles [d · v ≾ v] with [d] variable-free,
    of join [D], the value [L ⊔ D⁺ · L]; for the cycles [v · d ≾ v],
    [L ⊔ L · D⁺]. Each is below every value of [v] above [L] meeting the cycles
    it is drawn from, by the laws of the closure, so the value is the least at
    which the lower bounds and the cycles hold: the rule is principal. Where
    none holds, there is no value. *)

(** The shape of the left side [p] of a cycle [p ≾ v]. *)
type 'e shape =
  | Square  (** [v · v] *)
  | Left of 'e  (** [d · v], [d] a constant *)
  | Right of 'e  (** [v · d], [d] a constant *)
  | Other  (** any other *)

type 'e cycles = {
  replace : 'e -> 'e -> 'e;
      (** [replace x e] is [e] with [v] replaced by [x] *)
  shape : 'e -> 'e shape;  (** the shape of a cycle's left side *)
  closure : 'e -> 'e option;
      (** the closure of a variable-free expression, where the grade declares
          one ({!Grades.Grade.S.plus}) *)
  mul : 'e -> 'e -> 'e;  (** the product of two expressions *)
}
(** How the cycles [p ≾ v] of a sort are read. *)

type 'e sort = {
  self : 'e;  (** [v] as an expression *)
  is_unknown : 'e -> bool;  (** whether an expression is [v] itself *)
  earlier : 'e -> bool option;
      (** for a variable, whether it is created before [v] *)
  occurs : 'e -> bool;  (** whether [v] occurs in an expression *)
  equal : 'e -> 'e -> bool;  (** syntactic equality of expressions *)
  valid : 'e -> 'e -> bool;
      (** an ordering holding at every instance ({!Entail.Make.SORT.valid}) *)
  join : 'e -> 'e -> 'e;  (** the join of two expressions *)
  canon : 'e -> 'e;  (** an expression written canonically *)
  below_unit : 'e -> bool;
      (** whether an expression is decided below the unit at no hypotheses *)
  unit : 'e;  (** the unit *)
  top : 'e;  (** the top *)
  unit_least : bool;
      (** whether the unit is least, so that an upper bound below the unit
          forces [v] to it *)
  cycles : 'e cycles option;
      (** how cycles are read, where the sort reads them; a cycle blocks
          lowering and the least element otherwise *)
}
(** How the expressions of one sort are read for the unknown [v]. *)

type ('e, 'a) oracle = {
  may_lower : ('e, 'a) GradeNormal.ordering list -> bool;
      (** whether [v] may decrease, the given orderings discharged *)
  may_raise : ('e, 'a) GradeNormal.ordering list -> bool;
      (** whether [v] may increase, the given orderings discharged *)
}
(** Whether the atoms other than some orderings of the sort of [v] keep their
    meaning when [v] moves. *)

type ('e, 'a) value = {
  value : 'e;  (** the value of [v] *)
  discharged : ('e, 'a) GradeNormal.ordering list;
      (** the orderings it discharges, in order *)
}
(** A value of [v] and the orderings it discharges. *)

(** {2 Rules}

    Each rule reads the orderings of the sort of [v], in order. *)

val lower :
  'e sort ->
  ('e, 'a) oracle ->
  ('e, 'a) GradeNormal.ordering list ->
  ('e, 'a) value option
(** [lower sort oracle os] is the join of the lower bounds of [v] in [os], or
    its least closure that the cycles of [v] admit. *)

val raise :
  'e sort ->
  ('e, 'a) oracle ->
  ('e, 'a) GradeNormal.ordering list ->
  ('e, 'a) value option
(** [raise sort oracle os] is the first upper bound of [v] in [os] that caps the
    others. *)

val least :
  'e sort ->
  ('e, 'a) oracle ->
  ('e, 'a) GradeNormal.ordering list ->
  ('e, 'a) value option
(** [least sort oracle os] is the unit, or its least closure that the cycles of
    [v] admit, where the unit is least and [v] has no lower bound in [os]. *)

val top :
  'e sort ->
  ('e, 'a) oracle ->
  ('e, 'a) GradeNormal.ordering list ->
  ('e, 'a) value option
(** [top sort oracle os] is the top, where [v] has no upper bound in [os]. *)

val forces_unit : 'e sort -> ('e, 'a) GradeNormal.ordering -> bool
(** [forces_unit sort o] is whether [o] forces [v] to the unit. *)

val equate :
  'e sort ->
  entails:('e -> 'e -> bool) ->
  ('e, 'a) GradeNormal.ordering list ->
  'e option
(** [equate sort ~entails os] is the first expression that an ordering of [os]
    sets against [v], the right side where [v] is the left side and else the
    left side where [v] is the right side, that is an earlier unknown or free of
    [v] and equal to [v] in both directions of [entails]. *)

(** {2 Occurrences} *)

val free_right : 'e sort -> ('e, 'a) GradeNormal.ordering list -> bool
(** [free_right sort os] is whether each ordering of [os] is valid or has [v] on
    no right side. *)

val free_left : 'e sort -> ('e, 'a) GradeNormal.ordering list -> bool
(** [free_left sort os] is whether each ordering of [os] is valid or has [v] on
    no left side. *)

(** {2 The sorts of a grade system} *)

module Make (X : GradeExp.S) : sig
  val eps : Grades.Grade.bounds -> X.Eps_var.t -> X.eps sort
  (** [eps bounds k] is the effect expressions read for the effect unknown [k].
  *)

  val rho : Grades.Grade.bounds -> X.Rho_var.t -> X.rho sort
  (** [rho bounds k] is the resource expressions read for the resource unknown
      [k]. *)

  val image : Grades.Grade.bounds -> X.Eps_var.t -> X.rho sort
  (** [image bounds k] is the resource expressions read for the effect unknown
      [k] through its image [∣k∣]: [k] occurs in them through its image, [∣k∣]
      is the unknown, and an upper bound of [∣k∣] below the resource unit forces
      [k] to the effect unit where that is least and the map reflects the unit
      ({!Grades.GradeSystem.S.unit_reflecting}). The value of a rule is one for
      [∣k∣]. *)
end
