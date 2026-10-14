(** Small view components shared by the web interface. *)

val panel :
  ?a:'a Vdom.attribute list ->
  ?action:'a Vdom.vdom ->
  string ->
  'a Vdom.vdom list ->
  'a Vdom.vdom
(** [panel ?a ?action heading blocks] is a panel of the side column. [action] is
    placed at the right of the heading, opposite its name. *)

val contains : sub:string -> string -> bool
(** [contains ~sub s] holds when [sub] occurs in [s]. *)
