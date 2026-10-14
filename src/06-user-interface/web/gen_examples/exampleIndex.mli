(** The example index [examples/index], which lists the examples of the web
    interface's gallery; its format is described in its header. *)

type entry = {
  group : string;
  title : string;
  grade : string;
      (** the grading monoid the web interface switches to when it is loaded *)
  path : string;  (** relative to the project root *)
  description : string;
  backend : string;  (** the key of its backend, ["interpreter"] unless given *)
  settings : (string * string) list;
      (** the values of inputs of its backend, by key; that of a text input is
          the path of the file holding it, relative to the project root *)
}
(** An example. *)

type summary = { label : string; short : string; summary : string }
(** A group's summary line: its label, the label's short form and the one-line
    summary. *)

(** A line of the example index. *)
type line = Example of entry | Summary of summary | Default of string

val line_of_string : string -> line option
(** [line_of_string line] is the line [line], its fields trimmed; [None] for a
    blank line or a comment.

    Raises [Failure] if the line is malformed. *)

val checked : entry -> entry
(** [checked entry] is [entry], if its grade is one that {!Grades.GradeRegistry}
    lists, its backend one that {!BackendRegistry} lists, and each of its
    settings names an input of the backend and, for an input of choices, one of
    its choices.

    Raises [Failure] otherwise. *)

val read : string -> summary list * entry list * string list
(** [read path] is the summaries, the {!checked} examples and the default paths
    of the example index at [path], each in the order of the index. *)

val group_entries : entry list -> (string * entry list) list
(** [group_entries entries] is [entries] grouped by [group], in the order of the
    index, both of the groups and within them; entries of one group are expected
    to be consecutive. *)

val summarised :
  summary list -> (string * entry list) list -> (summary * entry list) list
(** [summarised summaries groups] is each of [groups] paired with its summary.

    Raises [Failure] unless every group has exactly one summary, every summary
    names a group and no two groups have one short form. *)

val defaults : entry list -> string list -> (string * string) list
(** [defaults entries paths] is each of [paths] paired with the key of the
    backend of the example of [entries] it names: the example the web interface
    loads when that backend is selected, and, for the default backend, when the
    page is opened.

    Raises [Failure] unless every path names one of [entries], no two name
    examples of one backend and one names an example of
    {!BackendRegistry.default}. *)
