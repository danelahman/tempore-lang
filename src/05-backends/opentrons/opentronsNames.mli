(** Python identifiers for the variables of a program, and tags for its labels.
*)

type t
(** The identifiers of the variables bound in a program. *)

val identifier : string -> int -> string
(** [identifier name index] is [name] made a Python identifier, followed by [_]
    and [index]: the characters other than ASCII letters, digits and [_] are
    escaped, a prime as [_p] and any other character as [_u] followed by its
    code point in hexadecimal, and [v] is prepended to an empty name or one that
    starts with a digit. Since it ends in [_] and digits, it is neither a Python
    keyword nor a name of the builtins or of the runtime. *)

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

val label_names : labels -> string list
(** [label_names labels] is the names of the labels, in the order of their tags.
*)
