(** The grades the prototype offers. *)

val grade_modules : (string * (module Grade.S)) list
(** All available grades by name, the default first. The names accepted by the
    CLI's [--grades] option and listed by the web interface's grade selector are
    taken from here. *)

val accepting : Grade.lit -> string list
(** [accepting lit] lists the names of the grades that understand the literal
    [lit], in the order of {!grade_modules}. *)
