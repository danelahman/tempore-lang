(** Timelines of runs whose operations are performed by their default
    implementations.

    A timeline has a virtual clock, advanced by the delays of the program. It
    records each delay outside every default implementation still running, and
    each call of an operation that reaches the top level, unhandled, and is
    performed by its default implementation: the run it belongs to, the time it
    starts, the number of such calls it is nested in, and the time its default
    implementation takes, once that has returned to the continuation of the
    call. A call whose run ends before its default implementation returns stays
    unfinished. The clock is not reset between runs, as in a protocol. *)

type call = {
  run : int;  (** the run of the call, from 1 *)
  op : string;  (** the operation called *)
  depth : int;
      (** the number of calls whose default implementations perform it *)
  start : Grades.Rational.t;  (** the time of the clock at the call *)
  elapsed : Grades.Rational.t option;
      (** the time its default implementation takes, once it has returned *)
}

type wait = {
  run : int;  (** the run of the delay, from 1 *)
  start : Grades.Rational.t;  (** the time of the clock at the delay *)
  duration : Grades.Rational.t;  (** the duration of the delay *)
}
(** A delay outside every default implementation still running. *)

(** An entry of a timeline. *)
type entry = Call of call | Delay of wait

(** How a run ends. *)
type outcome =
  | Returned of string  (** at the value printed *)
  | Stopped of string
      (** at a call of the operation that has neither a handler nor a default
          implementation *)

type finished = {
  index : int;  (** the run, from 1 *)
  at : Grades.Rational.t;  (** the time of the clock at its end *)
  outcome : outcome;
}
(** A run that has ended. *)

type t

val empty : t
(** The timeline at the start of the first run: the clock at 0, no calls. *)

val clock : t -> Grades.Rational.t
(** [clock t] is the time of the clock of [t]. *)

val delay : Grades.Rational.t -> t -> t
(** [delay q t] advances the clock of [t] by [q], and records the delay if no
    default implementation of a call of [t] is still running; a delay inside one
    counts towards the time of the call. *)

val perform : string -> t -> t
(** [perform op t] records a call of [op] performed by its default
    implementation, starting at the clock of [t]. *)

val resume : t -> t
(** [resume t] records that the default implementation of the innermost call of
    [t] still running has returned to the continuation of the call, which then
    takes the time elapsed since its start; [t] itself without such a call. *)

val finish : outcome -> t -> t
(** [finish outcome t] ends the current run of [t] with [outcome], leaving the
    calls still running unfinished; the next run starts at the same clock. *)

val entries : t -> entry list
(** [entries t] is the calls and the delays recorded of [t], in the order of
    their start. *)

val calls : t -> call list
(** [calls t] is the calls of [t], in the order of their start. *)

val runs : t -> finished list
(** [runs t] is the runs of [t] that have ended, in order. *)

val within : Grades.Grade.running_time -> Grades.Rational.t -> bool
(** [within (lo, hi) d] is whether the duration [d] lies in the interval of [lo]
    and [hi], each end closed, open or, for the upper end, infinite. *)

(** The verdict of the monitor of a call. *)
type verdict =
  | Within  (** its time lies within the bounds of the operation *)
  | Outside  (** its time lies outside them *)
  | Unchecked
      (** the operation has no bounds other than [\[0, ∞)], and is not monitored
      *)
  | Unfinished  (** its default implementation has not returned *)

val verdict : Grades.Grade.running_time option -> call -> verdict
(** [verdict bounds call] is the verdict of the monitor of [call], for an
    operation with the running-time bounds [bounds], as the monitors of a
    protocol check a binding function. *)
