(** Timelines of interpreter runs.

    A timeline records, in the order they happen, the delays, the calls of
    operations that reach the top level, unhandled, and are performed by their
    default implementations, and the resources boxed and unboxed. Each entry
    carries its depth, the number of calls whose default implementations are
    still running, and the resource grade accumulated at the top level of its
    run before it ({!Backend.observation}). Grades are printed resource grades:
    the timeline does no arithmetic on them. *)

(** What an entry records. *)
type event =
  | Call of { op : string; grade : string; returned : bool }
      (** a call of [op] of the declared resource grade [grade]; [returned]
          holds once its default implementation has returned to the continuation
          of the call *)
  | Delay of { grade : string }  (** a delay of the resource grade [grade] *)
  | Box of { resource : string; name : string; grade : string }
      (** the resource [resource] (its name in the state), named [name], boxed
          at the resource grade [grade] *)
  | Unbox of { resource : string; name : string; grade : string }
      (** the resource [resource], named [name], boxed at the resource grade
          [grade], unboxed *)

type entry = {
  run : int;  (** the run, from 1 *)
  depth : int;  (** the number of calls still running *)
  start : string;  (** the resource grade accumulated before the entry *)
  event : event;
}
(** An entry of a timeline. *)

(** How a run ends. *)
type outcome =
  | Returned of string  (** at the value printed *)
  | Stopped of string
      (** at a call of the operation that has neither a handler nor a default
          implementation *)

type finished = {
  index : int;  (** the run, from 1 *)
  at : string;  (** the resource grade accumulated at its end *)
  outcome : outcome;
}
(** A run that has ended. *)

type t

val empty : t
(** The timeline at the start of the first run, without entries. *)

val observe : Backend.observation -> t -> t
(** [observe observation t] records [observation] in [t]: a delay, call, box or
    unbox as an entry at the current depth; the return of the innermost call
    still running; the name given to a resource, in the boxes and unboxes of the
    current run; or the end of the current run, leaving the calls still running
    unfinished, the next run following it. *)

val entries : t -> entry list
(** [entries t] is the entries of [t], in order. *)

val runs : t -> finished list
(** [runs t] is the runs of [t] that have ended, in order. *)

(** {1 Reports} *)

(** How a row of a report is marked. *)
type status =
  | Plain
  | Pending  (** a call whose default implementation has not returned *)

type row = {
  cells : string list;
  status : status;
  depth : int;
      (** the depth of its entry; a row of positive depth belongs to the default
          implementation of a call and is shown de-emphasised *)
}
(** A row of a report, a cell per column. *)

type report = {
  title : string;
  columns : string list;  (** the headings of the columns of the rows *)
  rows : row list;
  notes : string list;  (** lines shown after the rows *)
}
(** A report on a timeline, independent of how it is displayed. *)

val report : ?run:int -> t -> report
(** [report ?run t] is the report on [t], titled [Timeline], with the columns
    [Run], [Start], [Event] and [Grade], a row per entry of [t] in order and a
    note per run ended, [Run n returned v at g.] or
    [Run n ended at g at a call of Op, ...], [g] the grade accumulated at its
    end. With [run], only the entries and the note of that run.

    - [Start] is the grade accumulated before the entry, at depth 0; it is empty
      for the entries of a default implementation, which start at the start of
      the call at depth 0 they belong to.
    - [Event] is the operation called, [delay], [box x] or [unbox x], preceded
      by a mark [· ] per level of depth.
    - [Grade] is the declared grade of a call (the row pending until its default
      implementation has returned), the grade of a delay, or the box grade of a
      box or unbox. *)

val text : report -> string
(** [text report] is [report] as plain text: its title, then a line for the
    headings of the columns and a line per row, each cell padded to the widest
    of its column and the cells separated by two spaces, then a line per note.
*)
