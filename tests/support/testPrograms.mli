(** The source files of the examples and tests, with the grades and packages
    their headers name. *)

val tpe_files : ?recursive:bool -> string -> string list
(** [tpe_files ?recursive dir] is the paths of the [.tpe] files under [dir],
    recursing into its subdirectories if [recursive] (the default), sorted
    within each directory. *)

val grade_module :
  ?levels:Grades.LevelLattice.t -> string -> (module Grades.Grade.S)
(** [grade_module ?levels name] is the registered grade named [name], over the
    lattice of levels [levels] if given and if it is built on levels.
    @raise Failure if there is none. *)

val levels_of_file : string -> Grades.LevelLattice.t option
(** [levels_of_file path] is the lattice of levels the file at [path] declares,
    if it declares a lattice; the parser reports a malformed declaration. *)

val packages :
  grades:string ->
  string ->
  (string * string * (string * Grades.Grade.running_time) list) list
(** [packages ~grades path] is the files of the peripheral packages of the
    Arduino backend named by [--package NAME] options in the header of the file
    at [path], under the grades [grades]: each with its name, its text and the
    running-time bounds of the board named by a [--board NAME] option, if any.
    @raise Failure if a package is unknown or has no files under [grades]. *)

val corpus :
  string ->
  (string
  * string
  * (string * string * (string * Grades.Grade.running_time) list) list)
  list
(** [corpus root] is the files typechecked by the solver tests: those of
    [root/examples], then those directly in [root/tests], each with its grades
    and, for the examples, its packages. *)
