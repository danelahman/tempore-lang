(** The lexer of the surface syntax. *)

val keywords : (string * Token.token) list
(** The keywords, each with its token. *)

val tokens : unit -> Lexing.lexbuf -> Token.token
(** [tokens ()] is a lexer for one source: the lexer of tokens outside brace
    literals and that of grade literals inside them. The lexer keeps the depth
    of the braces open, so each source needs a lexer of its own. *)

val read_file : (Lexing.lexbuf -> 'a) -> string -> 'a
(** [read_file parser filename] applies [parser] to the contents of the file
    [filename], whose locations are reported under its name. *)
