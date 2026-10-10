(** The view of the web interface: the page drawn from the model. *)

val primary_id : int -> string
(** [primary_id i] is the id of the primary span of the [i]th error in the
    editor. *)

val error_id : int -> string
(** [error_id i] is the id of the message of the [i]th error. *)

val target_key : Model.popover_target -> string
(** The key of a popover target, which the spans it describes carry in their
    classes after [EditorDom.key_prefix], and a gutter marker in its
    [data-popover] attribute. *)

val load_error_target : int -> Model.load_error -> string
(** [load_error_target i error] is the id of what to scroll to for the [i]th
    error: its highlighted primary span when it has one in the editor, otherwise
    its message block under the editor. *)

val status_id : string
(** The id of the status line of the last check. *)

val current_example_id : string
(** The id of the card of the example last loaded, which the page focuses when
    the gallery opens. *)

val view : Model.model -> Model.msg Vdom.vdom
(** The page for a model. *)
