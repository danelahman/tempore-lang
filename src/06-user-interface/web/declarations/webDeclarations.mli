(** The declarations a backend loads before the program, such as those of the
    peripheral packages of a device manifest, as the editor shows them: above
    the program, read-only, with the names of the program linked to their
    definitions in them. *)

type source = { filename : string; text : string }
(** A source of declarations, under the file name its locations carry. *)

type place = {
  filename : string;  (** the file name of the source *)
  span : int * int;  (** the bytes of the source naming the definition *)
  line : int;  (** the line naming it, from 1 *)
  text : string;
      (** the line naming it and, for an operation, the more indented lines
          continuing its command *)
}
(** Where a definition lies among the sources of declarations. *)

val place :
  source list -> Desugarer.References.sort -> Utils.Location.t -> place option
(** [place sources sort definition] is the place of the definition of sort
    [sort] at [definition] in the source of [sources] of its file name, if there
    is one. *)

val package : string -> string
(** [package filename] is the name of the package of a file
    [libraries/NAME/FILE], and [filename] otherwise. *)

val title : source list -> string
(** [title sources] names the block of [sources]: [Package declarations: ]
    followed by their packages, each once, in order of their first file. *)
