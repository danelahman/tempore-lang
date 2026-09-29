(** The grades the prototype offers. *)

val grade_modules : (string * (module Grade.S)) list
(** All available grades by name, the default first. The names accepted by the
    CLI's [--grades] option and listed by the web interface's grade selector,
    those shown {!Everywhere}, are taken from here. *)

val accepting : Grade.lit -> string list
(** [accepting lit] lists the names of the grades shown {!Everywhere} that
    understand the literal [lit], in the order of {!grade_modules}. *)

val accepting_delay : Rational.t -> string list
(** [accepting_delay q] lists the names of the grades shown {!Everywhere} that
    have a delay of [q ≥ 0] time steps ({!Grade.S.of_duration}), in the order of
    {!grade_modules}. *)

(** Where a grade is offered. *)
type visibility =
  | Everywhere  (** By the CLI and the web interface's selector *)
  | Cli_only
      (** By the CLI only, e.g. the implementations kept for comparison *)

type info = {
  title : string;
      (** A short descriptive name, e.g. ["Upper bounds"]; shown as the web
          selector's option text and, alongside the CLI name, by [--help]. *)
  description : string;
      (** One line describing the grade, e.g.
          ["At most n time steps; the unit 0 is least."]; shown as the web
          selector's option tooltip. *)
  visibility : visibility;  (** Where the grade is offered. *)
}
(** Descriptive metadata about a grade, shown next to its CLI name (a key of
    {!grade_modules}) by the web interface's selector and the CLI's [--help], in
    place of the bare name. *)

type group = {
  label : string;  (** The web selector's optgroup label, e.g. ["Time"]. *)
  short : string;
      (** The label's short form, e.g. ["Regex"] for ["Regular expressions"];
          shown with the selected grade by the web selector's closed control.
          The short forms of distinct groups are distinct. *)
  grades : (string * info) list;
      (** The group's grades, each by its CLI name, in the order
          {!grade_modules} lists them. *)
}

val groups : group list
(** {!grade_modules} described and grouped for the web selector and the CLI's
    [--help]: the concatenation of every group's [grades] names the same grades
    as {!grade_modules}, in the same order. *)
