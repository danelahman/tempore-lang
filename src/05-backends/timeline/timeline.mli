(** Timelines of interpreter runs.

    A timeline has a virtual clock, advanced by the delays of the program. It
    records each delay outside every default implementation still running; each
    call of an operation that reaches the top level, unhandled, and is performed
    by its default implementation: the run it belongs to, the time it starts,
    the number of such calls it is nested in, and the time its default
    implementation takes, once that has returned to the continuation of the
    call; and each box and unbox of a resource, at the time of the clock and the
    number of calls still running. A call whose run ends before its default
    implementation returns stays unfinished. The clock is not reset between
    runs. *)

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

type resource = {
  run : int;  (** the run of the event, from 1 *)
  start : Grades.Rational.t;  (** the time of the clock at the event *)
  depth : int;  (** the number of calls still running *)
  name : string;  (** the name of the resource *)
  grade : string;  (** the resource grade it is boxed at, printed *)
}
(** A resource boxed or unboxed. *)

(** An entry of a timeline. *)
type entry =
  | Call of call
  | Delay of wait
  | Box of resource
  | Unbox of resource

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
(** The timeline at the start of the first run: the clock at 0, no entries. *)

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

val box : name:string -> grade:string -> t -> t
(** [box ~name ~grade t] records the resource [name] boxed at the resource grade
    printed [grade], at the clock of [t]. *)

val unbox : name:string -> grade:string -> t -> t
(** [unbox ~name ~grade t] records the resource [name], boxed at the resource
    grade printed [grade], unboxed at the clock of [t]. *)

val finish : outcome -> t -> t
(** [finish outcome t] ends the current run of [t] with [outcome], leaving the
    calls still running unfinished; the next run starts at the same clock. *)

val observe : Backend.observation -> t -> t
(** [observe observation t] records [observation] in [t] by {!delay},
    {!perform}, {!resume}, {!box}, {!unbox} or {!finish}. *)

val entries : t -> entry list
(** [entries t] is the entries of [t], in the order of their start. *)

val calls : t -> call list
(** [calls t] is the calls of [t], in the order of their start. *)

val runs : t -> finished list
(** [runs t] is the runs of [t] that have ended, in order. *)

(** {1 Reports} *)

(** How a row of a report is marked. *)
type status =
  | Plain
  | Pending  (** a call whose default implementation has not returned *)

type row = { cells : string list; status : status }
(** A row of a report, a cell per column. *)

type report = {
  title : string;
  columns : string list;  (** the headings of the columns of the rows *)
  rows : row list;
  notes : string list;  (** lines shown after the rows *)
}
(** A report on a timeline, independent of how it is displayed. *)

val report : ?run:int -> ?time_unit:string -> t -> report
(** [report ?run ?time_unit t] is the report on [t], titled [Timeline], with the
    columns [Run], [Start], [Event], [Time] and [Grade], a row per entry of [t]
    in order and a note per run ended, followed by a note on the clock. With
    [run], only the entries and the note of that run, without the note on the
    clock. Times are numbers followed by the symbol [time_unit], if given.

    - A call is shown by its operation, indented by its depth, and its time, or
      [running] while its default implementation has not returned (the row then
      pending); its grade is empty.
    - A delay is shown by its duration; its grade is empty.
    - A box or unbox of the resource [x] is shown as [box x] or [unbox x],
      indented by its depth, with the resource grade [x] is boxed at. *)

val text : report -> string
(** [text report] is [report] as plain text: its title, then a line for the
    headings of the columns and a line per row, each cell padded to the widest
    of its column and the cells separated by two spaces, then a line per note.
*)
