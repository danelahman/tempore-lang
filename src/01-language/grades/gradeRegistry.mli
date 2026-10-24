(** The grades the prototype offers. *)

val grade_modules : (string * (module Grade.S)) list
(** All available grades by name, the default first. The names accepted by the
    CLI's [--grades] option and listed by the web interface's grade selector,
    those shown {!Everywhere}, are taken from here. *)

val default_name : string
(** The name of the default grade, the first of {!grade_modules}. *)

val accepting : ?lattice:GradeLattice.t -> Grade.lit -> string list
(** [accepting ?lattice lit] lists the names of the grades shown {!Everywhere}
    that understand the literal [lit] ({!Grade.S.accepts}), in the order of
    {!grade_modules}. With a grade lattice [lattice], only the grades built on a
    grade lattice are considered, over it. *)

val accepting_delay : ?lattice:GradeLattice.t -> Grade.lit -> string list
(** [accepting_delay ?lattice lit] lists the names of the grades shown
    {!Everywhere} whose delays read the literal [lit] ({!Delay.S.read}), in the
    order of {!grade_modules}, considered as by {!accepting}. *)

val accepting_bounds : ?lattice:GradeLattice.t -> Grade.lit -> string list
(** [accepting_bounds ?lattice lit] lists the names of the grades shown
    {!Everywhere} that read running-time bounds ({!Grade.S.needs_op_bounds}) and
    whose delays read the literal [lit], in the order of {!grade_modules},
    considered as by {!accepting}. *)

val over_lattice : string -> GradeLattice.t -> (module Grade.S) option
(** [over_lattice name lattice] is the grade [name] of {!grade_modules} built
    over the grade lattice [lattice], if it is built on a grade lattice. *)

val uses_lattice : string -> bool
(** [uses_lattice name] is whether the grade [name] of {!grade_modules} is built
    on a grade lattice. *)

val without_lattice : string -> string
(** [without_lattice name] is the diagnostic of a declaration of a grade lattice
    under the grade [name], which is not built on a grade lattice. *)

(** Where a grade is offered. *)
type visibility =
  | Everywhere  (** Listed by [--help] and the web interface's selector *)
  | Hidden
      (** Accepted by [--grades] but listed nowhere, e.g. the implementations
          kept for benchmarking *)

type implementation = {
  representation : string;
      (** The data structure representing a grade, e.g.
          ["minimal deterministic automata over single letters, built with the
           grade"]; shown by the web interface's tooltip. *)
  representation_short : string;
      (** A short form of {!representation}, e.g.
          ["minimal automata over single letters"]; shown below the grade's
          title by [--help]. *)
  inclusion : string;
      (** How inclusion is decided, e.g.
          ["emptiness of the product with the complement, by breadth-first
           search"]; shown by the web interface's tooltip. *)
  inclusion_short : string;
      (** A short form of {!inclusion}, e.g.
          ["product with the complement, breadth-first"]; shown below the
          grade's title by [--help]. *)
}
(** How a regular grade is decided. *)

val implementation_text : implementation -> string
(** [implementation_text i] is ["Represented as "] followed by
    [i.representation], then ["Inclusion: "] followed by [i.inclusion], e.g.
    ["Represented as minimal deterministic automata over single letters, built
     with the grade. Inclusion: emptiness of the product with the complement, by
     breadth-first search."]. *)

type info = {
  title : string;
      (** A short descriptive name, e.g. ["Upper bounds"]; shown as the web
          selector's option text and, alongside the CLI name, by [--help]. *)
  description : string;
      (** One line saying what the grades are, e.g.
          ["At most n time steps; the unit 0 is least."]; shown as the web
          selector's option tooltip. *)
  visibility : visibility;  (** Where the grade is offered. *)
  implementation : implementation option;
      (** How the grade is decided, for the regular grades, and [None] for the
          others; shown by [--help] as its [representation_short] and
          [inclusion_short], and by the web selector's option tooltip, after the
          description, as {!implementation_text}. *)
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
    [--help], the groups in the order of their first grades: the concatenation
    of every group's [grades] names the same grades as {!grade_modules}, in the
    same order where the grades of each group are listed together. *)

val info : string -> info option
(** [info name] is the description of the grade [name] of {!grade_modules}, if
    it is one. *)

val listed : group -> (string * info) list
(** [listed g] is the grades of [g] shown {!Everywhere}, in order. *)
