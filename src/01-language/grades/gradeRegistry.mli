(** The grades the prototype offers. *)

val grade_modules : (string * (module Grade.S)) list
(** All available grades by name, the default first. The names accepted by the
    CLI's [--grades] option and listed by the web interface's grade selector are
    taken from here. *)

val accepting : Grade.lit -> string list
(** [accepting lit] lists the names of the grades that understand the literal
    [lit], in the order of {!grade_modules}. *)

type info = {
  title : string;
      (** A short descriptive name, e.g. ["Upper bounds"]; shown as the web
          selector's option text and, alongside the CLI name, by [--help]. *)
  description : string;
      (** One line describing the grade, e.g.
          ["At most n time steps; the unit 0 is least."]; shown as the web
          selector's option tooltip. *)
}
(** Descriptive metadata about a grade, shown next to its CLI name (a key of
    {!grade_modules}) by the web interface's selector and the CLI's [--help], in
    place of the bare name. *)

type group = {
  label : string;  (** The web selector's optgroup label, e.g. ["Time"]. *)
  grades : (string * info) list;
      (** The group's grades, each by its CLI name, in the order
          {!grade_modules} lists them. *)
}

val groups : group list
(** {!grade_modules} described and grouped for the web selector and the CLI's
    [--help]: the concatenation of every group's [grades] names the same grades
    as {!grade_modules}, in the same order. *)
