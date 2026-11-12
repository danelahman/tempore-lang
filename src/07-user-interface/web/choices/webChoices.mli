(** The choices of the web interface that the browser remembers across page
    loads: whether the standard library is loaded, the example last loaded, the
    grades, the backend, the inputs of every backend and the resource grades.
    The program text is not among them. *)

type example = {
  path : string;  (** relative to the project root *)
  group : string;  (** the label of its group *)
  title : string;
}
(** A bundled example, by its path and, should the path change, by its group and
    title. *)

type t = {
  use_stdlib : bool;
  example : example option;
  grade : string option;  (** the name of the grades selected *)
  backend : string option;  (** the key of the backend selected *)
  settings : (string * BackendRegistry.settings) list;
      (** the values of the inputs set, by the key of their backend *)
  resources : string option;
      (** the name of the resource grade algebra selected, [None] for the
          identity grade system of the grades *)
}

val key : string
(** The key the choices are stored under; it names the version of the encoding,
    so that a stored value of another version is not read. *)

val encode : t -> string
(** [encode choices] is [choices] as a string, each field a token written as its
    length in bytes, a colon and its bytes; the resource grades are the last
    field, written only when selected. *)

val decode : string -> t option
(** [decode s] is the choices [s] encodes, or [None] if [s] is malformed.
    [decode (encode c) = Some c]. *)

val valid_resources : grade:string -> string option -> string option
(** [valid_resources ~grade resources] is [resources] if a grade system of
    {!Grades.GradeSystemRegistry.systems} pairs the effect grade algebra [grade]
    with it, and [None] otherwise. *)

val sanitise : t -> t
(** [sanitise choices] is [choices] without a grade not in
    {!Grades.GradeRegistry.grade_modules}, resource grades unless a registered
    grade system pairs them with the grade kept, a backend not in
    {!BackendRegistry.entries}, the settings of an unknown backend, the values
    of inputs its backend does not have or of choices it does not offer, and
    every repeated key but the first. *)
