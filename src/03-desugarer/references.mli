(** The definitions the names of a program refer to.

    Names are resolved with the scoping of the desugarer: variables are bound by
    patterns, [let], [let rec] and top-level definitions; constructors, type
    names and operations by the commands declaring them. Operations are resolved
    in [perform] only. A name without a definition in the source, such as a
    primitive or a built-in type, is not resolved. *)

type sort =
  | Value  (** a variable, local or top-level *)
  | Constructor
  | Type
  | Operation

type link = {
  use : Utils.Location.t;  (** the occurrence of the name *)
  definition : Utils.Location.t;  (** where the command or pattern names it *)
  sort : sort;
}
(** An occurrence of a name and its definition. *)

type env
(** The names in scope at the top level, with their definitions. *)

val empty : env

val command : env -> ('rho, 'eps) SugaredAst.command -> env * link list
(** [command env cmd] is the environment after [cmd] and the links of the names
    [cmd] uses, ordered by their occurrences. *)
