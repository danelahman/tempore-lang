(** The running-time monitors of a protocol over the calls of a timeline
    ({!Timeline}): the duration layer of the timelines of the Opentrons backend.
*)

val within : Grades.Grade.running_time -> Grades.Rational.t -> bool
(** [within (lo, hi) d] is whether the duration [d] lies in the interval of [lo]
    and [hi], each end closed, open or, for the upper end, infinite. *)

(** The verdict of the monitor of a call. *)
type verdict = Timeline.verdict =
  | Within  (** its time lies within the bounds of the operation *)
  | Outside  (** its time lies outside them *)
  | Unchecked
      (** the operation has no bounds other than [\[0, ∞)], and is not monitored
      *)
  | Unfinished  (** its default implementation has not returned *)

val verdict : Grades.Grade.running_time option -> Timeline.call -> verdict
(** [verdict bounds call] is the verdict of the monitor of [call], for an
    operation with the running-time bounds [bounds], as the monitors of a
    protocol check a binding function. *)
