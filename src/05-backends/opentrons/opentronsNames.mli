(** Python identifiers for the variables, operations and labels of a program,
    and tags for its labels. *)

val is_identifier_start : char -> bool
(** [is_identifier_start c] holds if [c] is an ASCII letter or [_], a character
    that may start a Python identifier in ASCII. *)

val is_identifier_char : char -> bool
(** [is_identifier_char c] holds if [c] is an ASCII letter, digit or [_], a
    character of a Python identifier in ASCII. *)

type t
(** The identifiers of the variables bound in a program. *)

val identifier : string -> int -> string
(** [identifier name index] is [name] made a Python identifier, followed by [_]
    and [index]: the characters other than ASCII letters, digits and [_] are
    escaped, a prime as [_p] and any other character as [_u] followed by its
    code point in hexadecimal, and [v] is prepended to an empty name or one that
    starts with a digit. Since it ends in [_] and digits, it is neither a Python
    keyword nor a name of the builtins or of the runtime. *)

val operation : Language.Ast.operation -> string
(** [operation op] is the identifier of the declaration of [op] in the compiled
    program: [tempore_op_] followed by the name of [op] if it consists of ASCII
    letters and digits with single underscores between them, and otherwise by
    the name escaped as by {!identifier}, its runs of underscores reduced to
    one, followed by [_], the bytes of the name in hexadecimal and [_]. Distinct
    names have distinct identifiers. *)

val constructor : Language.Ast.label -> string
(** [constructor l] is the identifier of the class of the label [l] in the
    compiled program: [tempore_con_nil] and [tempore_con_cons] for the list
    constructors, and otherwise [tempore_con_] followed by the name of [l] made
    an identifier as by {!operation}. *)

val of_commands : ('rho, 'eps) Language.Ast.command list -> t
(** [of_commands commands] gives each variable bound in [commands] the
    {!identifier} of its name and of its position among the binders, in order of
    occurrence, so that distinct variables get distinct identifiers. *)

val variable : t -> Language.Ast.variable -> string option
(** [variable names x] is the identifier of [x], if [x] is bound in the program.
*)

type labels
(** The tags of the labels of a program. *)

val labels_of_commands : ('rho, 'eps) Language.Ast.command list -> labels
(** [labels_of_commands commands] numbers the labels of [commands], those of the
    lists included, from [0] in the order {!Language.Ast.Label.compare}, so that
    the order of tags is the order of labels the comparison primitives use. *)

val label_rank : labels -> Language.Ast.label -> int
(** [label_rank labels l] is the tag of [l]. *)

val label_list : labels -> Language.Ast.label list
(** [label_list labels] is the labels, in the order of their tags. *)
