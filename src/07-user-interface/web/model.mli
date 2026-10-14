(** The state of the web interface and its update by messages. *)

include module type of struct
  include ModelTypes
end

val is_warning : load_error -> bool
(** [is_warning e] is whether [e] is a warning rather than an error. *)

val backend : edit_model -> BackendRegistry.entry
(** [backend edit_model] is the selected backend, or the default one if the key
    selected names none. *)

val settings : edit_model -> BackendRegistry.settings
(** [settings edit_model] is the values of the inputs of the selected backend
    that have been set. *)

val init : model
(** The model as the page opens. *)

val choices : edit_model -> WebChoices.t
(** [choices edit_model] is the choices of [edit_model] the browser remembers.
*)

val opened : query:string -> string option -> model * side_effect list
(** [opened ~query stored] is the model as the page opens at an address of query
    [query] ({!WebLink}), with the choices encoded by [stored], and the effects
    it asks for: the query replaced by the one naming the resulting choices,
    which are remembered if [query] has parameters. Without parameters, the
    choices encoded by [stored] ({!WebChoices.encode}) are restored as far as
    they are still valid: the example, found by its path or else by its group
    and title, loaded as from the gallery, or else the default one; then the
    grades and the backend selected, if known, the latter without loading its
    default example; then the inputs set; without [stored], or if it encodes no
    choices, the model is {!init}. With parameters, the choices
    {!WebLink.resolve} yields are restored likewise, with a notice of the
    parameters ignored. A [line] of the example loaded is kept in the query,
    scrolled to with the caret placed at its start, and highlighted briefly; a
    [line] the example has not got is ignored. *)

val line_links : model -> bool
(** [line_links model] holds when a click on a line number of the editor copies
    the link to that line: the editor shows the program, and the program is the
    example last loaded, unedited. *)

val indentation : string
(** What a Tab in the editor inserts; the editor's [tab-size] matches. *)

val byte_offset : string -> int -> int
(** [byte_offset source offset] is the byte of [source] the browser's [offset]
    points at: a selection counts UTF-16 code units, an OCaml string UTF-8
    bytes, and the two part company outside ASCII. *)

val example_of_path : string -> (string * Examples_tpe.example) option
(** [example_of_path path] is the group label and the bundled example at [path],
    relative to the project root, if there is one. *)

val example_group : string -> Examples_tpe.group option
(** [example_group label] is the group of bundled examples of label [label], if
    there is one. *)

val link_at : link list -> int -> int option
(** [link_at links offset] is the index of the first of [links] whose name
    covers the byte [offset] of the editor's text, its end included. *)

val update : model -> msg -> model * side_effect list
(** [update model msg] is the model after [msg] and the effects it asks for. *)
