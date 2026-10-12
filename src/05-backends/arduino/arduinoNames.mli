(** C++ identifiers for the names of a program, and C++ literals. *)

val identifier : string -> int -> string
(** [identifier name index] is [name] made a C++ identifier, followed by [_] and
    [index]. ASCII letters and digits are kept; an operator character is spelt
    as a word, e.g. [+] as [plus] and a prime as [p], any other character as [u]
    followed by its code point in hexadecimal, and these words and the
    underscores, spaces and parentheses of [name] separate the parts of the
    identifier by single underscores. A name that is empty, starts with a digit
    or starts with [tempore] is preceded by [v]. The identifier is thus neither
    a C++ keyword nor a reserved identifier, and it differs from the names the
    compiler introduces, which start with [tempore]. *)

val base : string -> string
(** [base name] is [name] made a C++ identifier as by {!identifier}, without the
    index. *)

val operation : string -> string
(** [operation name] is the name of the C++ function that performs the operation
    [name]: [tempore_op_] followed by [name] made an identifier as by
    {!identifier}, without the index. *)

val binding : string -> string
(** [binding name] is the name of the C++ function of the bindings that
    implements the operation [name]: [binding_] followed by [name] made an
    identifier as by {!identifier}, without the index. *)

val string_literal : string -> string
(** [string_literal s] is a C++ string literal, in printable ASCII, of the bytes
    of [s]. *)
