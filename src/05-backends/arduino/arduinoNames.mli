(** C++ identifiers for the names of a program. *)

val identifier : string -> int -> string
(** [identifier name index] is [name] made a C++ identifier, followed by [_] and
    [index]. ASCII letters and digits are kept; an operator character is spelt
    as a word, e.g. [+] as [plus] and a prime as [p], any other character as [u]
    followed by its code point in hexadecimal, and these words and the
    underscores, spaces and parentheses of [name] separate the parts of the
    identifier by single underscores. A name that is empty, starts with a digit
    or starts with [tempore] or [binding], in any case, is preceded by [v]. The
    identifier is thus neither a C++ keyword nor a reserved identifier, and it
    differs from the names the compiler introduces. The identifiers of distinct
    indices are distinct. *)

val base : string -> string
(** [base name] is the C++ name of [name] that follows the prefix of a name
    derived from it. A name of ASCII letters and digits with single underscores
    between them is kept; any other name is spelt as by {!identifier}, followed
    by [_], the bytes of [name] in hexadecimal, and [_]: [Show'] is
    [Show_p_53686f7727_]. The function is injective, and its values contain
    neither two consecutive underscores nor a leading one. *)

(** {2 Names derived from operations}

    Each is a prefix followed by the {!base} of the name of an operation. The
    prefixes differ from each other before their last underscore, so that the
    names are distinct for distinct operations and kinds. An operation name
    starts with an upper-case letter, and the names of the scaffold that start
    with [tempore_monitor_] or [tempore_bounds_] continue in lower case. *)

val operation : string -> string
(** [operation name] is the name of the C++ function that performs the operation
    [name], [tempore_op_] followed by its base. *)

val monitor : string -> string
(** [monitor name] is the name of the monitor of the operation [name],
    [tempore_monitor_] followed by its base. *)

val bounds : string -> string
(** [bounds name] is the name of the running-time bounds of the operation
    [name], [tempore_bounds_] followed by its base. *)

val binding : string -> string
(** [binding name] is the name of the C++ function of the bindings that
    implements the operation [name], [binding_] followed by its base. *)

val performs : string -> string
(** [performs name] is the macro defined when the program performs the operation
    [name], [TEMPORE_PERFORMS_] followed by its base. *)

val argument_type : string -> string
(** [argument_type name] is the type of the argument of the operation [name],
    [tempore_argument_] followed by its base. *)

val result_type : string -> string
(** [result_type name] is the type of the result of the operation [name],
    [tempore_result_] followed by its base. *)
