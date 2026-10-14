(** The parameters of the address of the web interface: the query
    [?example=p&grades=g&backend=b&line=n], naming a bundled example by its path
    [p] relative to the directory [examples], a key [g] of
    {!Grades.GradeRegistry.grade_modules}, a key [b] of
    {!BackendRegistry.entries} and a line [n] of the example, from 1; each
    parameter is optional. *)

type t = {
  example : string option;
      (** the path, relative to [examples] or to the project root *)
  grades : string option;
  backend : string option;
  line : int option;  (** a line of the example, from 1 *)
}

val empty : t
(** The parameters of a query without any. *)

(** A parameter of the address. *)
type parameter = Example | Grades | Backend | Line

val name : parameter -> string
(** [name p] is the key [p] is written under in a query. *)

val parse : string -> t * parameter list
(** [parse query] is the parameters of [query], with or without its leading [?],
    and the parameters whose values are malformed: not percent-encoded
    ({{:https://www.rfc-editor.org/rfc/rfc3986#section-2.1}RFC 3986, 2.1}, [+]
    standing for a space) or empty, and a [line] other than a positive number in
    decimal digits, leading zeros allowed. Of a repeated key the first
    occurrence counts; unknown keys are ignored. *)

val serialise : t -> string
(** [serialise link] is the query of [link], [?] followed by its parameters in
    the order [example], [grades], [backend], [line], percent-encoded except for
    unreserved characters and [/]; the empty string if [link] has none.
    [parse (serialise l) = (l, [])] for parameters [l] of non-empty values and a
    positive [line]. *)

type entry = {
  example : WebChoices.example;  (** its path relative to the project root *)
  grade : string;  (** the grades it is meant to be run with *)
  backend : string;  (** its backend *)
}
(** A bundled example, with the grades and the backend loading it selects. *)

type catalogue = {
  find : string -> entry option;
      (** the example at a path relative to the project root *)
  default_of : string -> entry option;
      (** the example selecting a backend loads, by the backend's key *)
}
(** The bundled examples. *)

val resolve :
  catalogue ->
  defaults:WebChoices.t ->
  WebChoices.t option ->
  t ->
  WebChoices.t * parameter list
(** [resolve catalogue ~defaults remembered link] is the choices the page opens
    with under the address parameters [link] and the choices [remembered] the
    browser keeps, or [defaults] without them, and the parameters ignored as
    naming no example, grades or backend.

    A known [example] replaces the remembered example, its own grades and
    backend applying and its settings replacing the remembered settings of its
    backend. Without one, a known [backend] keeps the remembered example if it
    is of that backend, and is otherwise accompanied by the backend's default
    example, if it has one, as selecting the backend loads it. Known [grades]
    and [backend] then override those of the example. The remaining choices are
    the remembered ones. A [line] is ignored without a known [example]; whether
    the example has that line is left to the caller. *)

val of_choices : catalogue -> WebChoices.t -> t
(** [of_choices catalogue choices] is the parameters naming [choices]: the
    example, and the grades and the backend where they differ from the example's
    own; without a known example, the grades and the backend alone. It names no
    line. *)

val line_bytes : string -> int -> (int * int) option
(** [line_bytes source n] is the bytes of line [n] of [source], counted from 1,
    from its first byte other than a space or a tab up to its newline or the end
    of [source]; [None] if [source] has no line [n]. The text after the last
    newline counts as a line, even if empty. *)
