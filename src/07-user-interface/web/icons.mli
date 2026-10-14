(** The icons of the web interface, drawn in the current text colour so that
    they follow the hover styling of the link they sit in. The Octicons are MIT
    licensed, Copyright (c) GitHub Inc.; see THIRD-PARTY.md. *)

val book : 'msg Vdom.vdom
(** The Octicon of a book, the mark of the documentation. *)

val code : 'msg Vdom.vdom
(** The Octicon of code, the mark of the editor. *)

val link : 'msg Vdom.vdom
(** The Octicon of a link. *)

val github : 'msg Vdom.vdom
(** The GitHub mark, as in the Octicons. *)

val pipette : 'msg Vdom.vdom
(** A pipette. *)

val chip : 'msg Vdom.vdom
(** A microcontroller chip with its pins. *)

val tick : string -> 'msg Vdom.vdom
(** [tick classes] is a tick stroke, under the classes [classes] besides
    [check-status-mark]. *)

val cross : string -> 'msg Vdom.vdom
(** [cross classes] is a cross stroke, under the classes [classes] besides
    [check-status-mark]. *)
