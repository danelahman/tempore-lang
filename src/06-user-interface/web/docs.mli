(** The documentation page of the web interface: the project's README rendered
    from its Markdown source. *)

val view :
  Model.msg Vdom.vdom -> Model.msg Vdom.vdom list * Model.msg Vdom.vdom list
(** [view action] is the documentation page: the blocks of its main column, the
    project's README rendered from its Markdown source, and those of its side
    column, a table of contents of the same, with [action] beside its heading.
*)
