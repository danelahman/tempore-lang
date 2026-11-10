(** The grade systems Tempore offers besides the identity ones: an effect grade
    algebra, a resource grade algebra and a morphism of grade algebras between
    them ({!GradeSystem.S}), selected by the CLI's [--grades] and
    [--resource-grades] options. *)

(** The grade system in which effects are graded by [E] and resources by the
    time grades [R], the image [∣e∣] of an effect grade [e] being the least
    grade of [R] admitting the durations of the runs of [e]: [R.of_durations] of
    [E.duration_bounds bounds e], each open end of the running times [bounds]
    first replaced by the closed one it abbreviates over the delays
    ({!Grade.close_running_time}), and the top where [e] admits no run, which
    the typechecker rejects wherever it is written. It declares no grade
    lattice, its morphism reflects the order at the unit as [P.unit_reflecting]
    states, and the witnesses of a condition are those of [E] for its effect
    constants, [Partial]. *)
module Durations
    (E : Grade.S)
    (R : TimeGrades.DURATIONS with type Delay.t = E.Delay.t)
    (P : sig
      val unit_reflecting : bool
    end) : GradeSystem.S with module R = R and module E = E

(** The grade system in which effects are graded by [E] and resources by [R],
    with the morphism [M.map], in a program declaring the grade lattice
    [M.lattice], its morphism reflecting the order at the unit as
    [M.unit_reflecting] states; the witnesses of a condition are those of [E]
    for its effect constants, [Partial]. *)
module Mapped
    (E : Grade.S)
    (R : Grade.S with type Delay.t = E.Delay.t)
    (M : sig
      val map : Grade.bounds -> E.t -> R.t
      val lattice : GradeLattice.t option
      val unit_reflecting : bool
    end) : GradeSystem.S with module R = R and module E = E

type entry = {
  effects : string;  (** The name of the effect grade algebra. *)
  resources : string;  (** The name of the resource grade algebra. *)
  system : (module GradeSystem.S);
      (** The grade system, in a program declaring no grade lattice. *)
  over_lattice : (GradeLattice.t -> (module GradeSystem.S)) option;
      (** The grade system in a program declaring a grade lattice, over it,
          where its grade algebras are built on one. *)
  morphism : string;
      (** The resource grade of an effect grade, in words, e.g. the lower end of
          an effect grade; shown by [--help] after the effect algebras. *)
}
(** A registered grade system. *)

val systems : entry list
(** The registered grade systems: the time intervals with the time lower bounds
    and with the time upper bounds, keeping one end of an interval; the timed
    regex grades, finite or not, with the time grades of the same sides, by the
    durations of their runs; the trace grades with banked delays with the time
    grades of the same sides, by the durations of their traces; each of these
    over whole time steps and over rational delays; the finite run sets with the
    at-most counts and with the at-least counts with a top, and the lower trace
    bounds with the at-least counts, by the calls of their traces, over whole
    time steps; and the projections of the time lower bounds paired with a grade
    lattice. *)

val find :
  ?lattice:GradeLattice.t ->
  effects:string ->
  resources:string ->
  unit ->
  (module GradeSystem.S) option
(** [find ?lattice ~effects ~resources ()] is the registered grade system of the
    effect grade algebra [effects] and the resource grade algebra [resources],
    if there is one, over the grade lattice [lattice] where its grade algebras
    are built on one. *)

val effects_of : string -> string list
(** [effects_of resources] is the names of the effect grade algebras of the
    registered grade systems of the resource grade algebra [resources], in the
    order of {!systems}. *)

val resources_of : string -> string list
(** [resources_of effects] is the names of the resource grade algebras of the
    registered grade systems of the effect grade algebra [effects], in the order
    of {!systems}. *)

val morphism : effects:string -> resources:string -> string option
(** [morphism ~effects ~resources] is the description of the morphism of the
    registered grade system of the effect grade algebra [effects] and the
    resource grade algebra [resources], if there is one. *)

val select :
  ?lattice:GradeLattice.t ->
  effects:string ->
  resources:string option ->
  (module Grade.S) ->
  ((module GradeSystem.S), string) result
(** [select ?lattice ~effects ~resources (module G)] is the grade system of the
    effect grade algebra [effects], [G] being that algebra over the grade
    lattice [lattice] the program declares, if any: the registered grade system
    of [effects] and [resources] over [lattice] ({!find}) if [resources] names
    another algebra, and otherwise the identity system of [G], declaring
    [lattice]. A pair without a registered grade system is an error, its message
    naming the resource grade algebras of [effects]. *)

val by_resources : (string * (string list * string) list) list
(** The registered grade systems grouped by resource grade algebra, in the order
    in which the algebras first occur in {!systems}: each algebra with its
    clauses, the names of the effect grade algebras sharing a morphism
    description and that description, in the order of {!systems}. *)
