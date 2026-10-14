(** The documentation view of the web interface: its pages, the READMEs of the
    project and of its backends, rendered from their Markdown sources. *)

val repository : string
(** The URL of the public repository of the project. *)

val repository_file : string -> string
(** [repository_file path] is the URL of the file at [path], relative to the
    project root, at the tip of [main] in {!repository}; the relative links of
    the READMEs are resolved against it. *)

val readme_class : string
(** The class of the element holding the README shown. *)

val view :
  WebDocPages.page ->
  current:string option ->
  Model.msg Vdom.vdom ->
  Model.msg Vdom.vdom list * Model.msg Vdom.vdom list
(** [view page ~current action] is the documentation view showing [page]: the
    blocks of its main column, the README of [page] rendered from its Markdown
    source, and those of its side column, the choice of the page and a table of
    contents of its README, the section of the heading [current] lit, or the
    first section without one, with [action] beside its heading. *)
