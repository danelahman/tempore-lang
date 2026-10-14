(** Highlighting of C++ source, in the classes of the highlighting of Tempore
    source: keywords and preprocessor directives, strings and characters,
    numbers and comments. *)

val highlight : string -> 'a Vdom.vdom list
(** [highlight source] is [source] as nodes, each keyword, preprocessor
    directive, string or character literal, number and comment in a span of the
    class of its kind. *)
