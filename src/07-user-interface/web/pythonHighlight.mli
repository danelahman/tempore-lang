(** Highlighting of Python source, in the classes of the highlighting of Tempore
    source: keywords, strings, numbers and comments. *)

val highlight : string -> 'a Vdom.vdom list
(** [highlight source] is [source] as nodes, each keyword, string literal,
    number and comment in a span of the class of its kind. *)
