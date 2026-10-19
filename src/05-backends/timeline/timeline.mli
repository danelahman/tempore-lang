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
  | Unbox of { resource : string; name : string }
      (** the resource [resource], named [name], unboxed *)

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

(** {1 Shortening} *)

(** Which part of a long grade is kept. *)
type keep = Beginning | End

val limit : int
(** [limit] is 40, the number of characters above which an end of a grade is
    shortened for display. *)

val shorten : keep -> string -> string
(** [shorten keep g] is the printed grade [g] shortened for display. [g] is read
    as an interval of ends separated by [, ] in brackets or parentheses, or as a
    single end; an end in braces is a group of items separated by [; ], the
    separators inside nested brackets, parentheses and braces excepted. If every
    end has at most {!limit} characters, [g] is unchanged. Otherwise every group
    of more than [k] items keeps only its first ([Beginning]) or last ([End])
    [k] items, the others replaced by […], [k] being the largest number for
    which every end has at most {!limit} characters, and at least 1. Items are
    never cut, so an end may exceed {!limit}. A grade without a brace group is
    cut to its first or last [limit - 1] characters, with […] after or before
    them. *)

(** {1 Reports} *)

(** How a row of a report is marked. *)
type status =
  | Plain
  | Pending  (** a call whose default implementation has not returned *)

type row = {
  cells : string list;
  short : string list;
      (** the cells shortened for display: the grade accumulated by
          {!shorten}[ End], the grades of events by {!shorten}[ Beginning] *)
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
  notes : string list;  (** lines shown after the rows, grades shortened *)
  full_notes : string list;  (** the notes with their grades in full *)
}
(** A report on a timeline, independent of how it is displayed. *)

val report : ?run:int -> t -> report
(** [report ?run t] is the report on [t], titled [Timeline], with the columns
    [Run], [Start], [Event] and [Grade], a row per entry of [t] in order and a
    note per run ended, [Run n returned v at g.] (the value in full) or
    [Run n ended at g at a call of Op, ...], [g] the grade accumulated at its
    end, shortened by {!shorten}[ End] ([full_notes] in full). With [run], only
    the entries and the note of that run.

    - [Start] is the grade accumulated before the entry, at depth 0; it is empty
      for the entries of a default implementation, which start at the start of
      the call at depth 0 they belong to.
    - [Event] is the operation called, [delay], [box x] or [unbox x], preceded
      by a mark [· ] per level of depth.
    - [Grade] is the declared grade of a call (the row pending until its default
      implementation has returned), the grade of a delay, or the grade a box is
      boxed at; it is empty for unboxes. Boxes and unboxes add nothing to the
      grade accumulated. *)

val text : ?full:bool -> report -> string
(** [text ?full report] is [report] as plain text: its title, then a line for
    the headings of the columns and a line per row, with the shortened cells of
    the rows and notes unless [full] (default [false]), each cell padded to the
    widest of its column and the cells separated by two spaces, then a line per
    note. *)
