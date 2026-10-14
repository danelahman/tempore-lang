(** The header of a source file: its leading comment, whose run command names
    the options the file is run with. *)

val options : string -> string -> string list
(** [options path option] is the values of the option [option] in the header of
    the file at [path], in order. *)

val grades : string -> string
(** [grades path] is the grades named by [--grades NAME] in the header of the
    file at [path], the default grades of the command-line interface if it names
    none. *)

val run_options : string -> string list
(** [run_options path] is the options of the run command in the header of the
    file at [path]: its grades, then its packages, then its board, if any. *)
