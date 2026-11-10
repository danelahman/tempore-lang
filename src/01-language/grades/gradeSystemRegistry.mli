(** The grade systems Tempore offers besides the identity ones: an effect grade
    algebra, a resource grade algebra and a morphism of grade algebras between
    them ({!GradeSystem.S}), selected by the CLI's [--grades] and
    [--resource-grades] options. *)

(** The grade system in which effects are graded by [E] and resources by the
    time grades [R], the image [∣e∣] of an effect grade [e] being the least
    grade of [R] admitting the durations of the runs of [e]: [R.of_durations] of
    [E.duration_bounds bounds e], the top where [e] admits no run, which the
    typechecker rejects wherever it is written. It declares no grade lattice,
    its morphism reflects the order at the unit as [P.unit_reflecting] states,
    and the witnesses of a condition are those of [E] for its effect constants,
    [Partial]. *)
module Durations
    (E : Grade.S)
    (R : TimeGrades.DURATIONS with type Delay.t = E.Delay.t)
    (P : sig
      val unit_reflecting : bool
    end) : GradeSystem.S with module R = R and module E = E

type entry = {
  effects : string;  (** The name of the effect grade algebra. *)
  resources : string;  (** The name of the resource grade algebra. *)
  system : (module GradeSystem.S);  (** The grade system. *)
  morphism : string;
      (** The morphism, in one line, e.g.
          ["∣[d, a]∣ = [d, ∞), the lower end kept with its openness"]; shown by
          [--help]. *)
}
(** A registered grade system. *)

val systems : entry list
(** The registered grade systems: the time intervals with the time lower bounds
    and with the time upper bounds, keeping one end of an interval, and the
    intervals of the timed regex grades, finite or not, with the time intervals,
    by the hull of their durations; each over whole time steps and over rational
    delays. *)

val find : effects:string -> resources:string -> (module GradeSystem.S) option
(** [find ~effects ~resources] is the registered grade system of the effect
    grade algebra [effects] and the resource grade algebra [resources], if there
    is one. *)

val effects_of : string -> string list
(** [effects_of resources] is the names of the effect grade algebras of the
    registered grade systems of the resource grade algebra [resources], in the
    order of {!systems}. *)

val resources_of : string -> string list
(** [resources_of effects] is the names of the resource grade algebras of the
    registered grade systems of the effect grade algebra [effects], in the order
    of {!systems}. *)
