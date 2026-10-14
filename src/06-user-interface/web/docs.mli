(** The documentation view of the web interface: its pages, the READMEs of the
    project and of its backends, rendered from their Markdown sources. *)

val view :
  WebDocPages.page ->
  Model.msg Vdom.vdom ->
  Model.msg Vdom.vdom list * Model.msg Vdom.vdom list
(** [view page action] is the documentation view showing [page]: the blocks of
    its main column, the README of [page] rendered from its Markdown source, and
    those of its side column, the choice of the page and a table of contents of
    its README, with [action] beside its heading. *)
