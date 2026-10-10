(** Measurements of the editor on the page: what the pointer is over and where a
    popover goes. The text of the editor lies under a transparent textarea,
    which takes the pointer's events, so its spans are found by their rectangles
    rather than as the targets of events. *)

val get : Ojs.t -> string -> Ojs.t
(** [get obj key] is the property [key] of [obj]. *)

val call : Ojs.t -> string -> Ojs.t list -> Ojs.t
(** [call obj name args] calls the method [name] of [obj] on [args]. *)

val document : Ojs.t
(** The document of the page. *)

val is_nothing : Ojs.t -> bool
(** Whether a value is [null] or [undefined]. *)

val number : Ojs.t -> string -> float
(** [number obj key] is the numeric property [key] of [obj]. *)

val closest : Ojs.t -> string -> Ojs.t option
(** [closest element selector] is the nearest ancestor of [element], itself
    included, matching [selector], if any. *)

type rect = { left : float; top : float; right : float; bottom : float }
(** A rectangle of the viewport. *)

val bounding : Ojs.t -> rect
(** The bounding rectangle of an element or range. *)

val key_prefix : string
(** The prefix of the class naming the popover target of a marked span. *)

val point : Ojs.t -> float * float
(** The viewport position of a mouse event. *)

val under :
  precedence:(string -> bool) list ->
  Ojs.t ->
  [> `Key of string | `Nothing | `Popover ]
(** [under ~precedence event] is what the pointer of a mouse [event] is over:
    [`Popover], a gutter marker or a marked span by the key of its target, the
    first of [precedence] among the keys of the spans at the point, or
    [`Nothing]. *)

val moves_within : string -> Ojs.t -> bool
(** [moves_within selector event] holds when the element a mouse [event] moves
    to, if any, lies in an element matching [selector]. *)

val placement :
  key:string -> point:(float * float) option -> Model.placement option
(** [placement ~key ~point] places the drawn popover by the first line of the
    span of target [key], or its line at [point] when there is one: centred
    under it, within the editor and away from its sides, and above it when the
    viewport has no room below and more above. [None] when the card or the span
    is not drawn. *)

val modifier_held : Ojs.t -> bool
(** Whether the modifier that turns names into links, the command key on Apple's
    platforms and Ctrl elsewhere, is held in the mouse or keyboard event. *)

val is_modifier : string -> bool
(** Whether a key, the key of a keyboard event, is that modifier. *)

val link_prefix : string
(** The prefix of the class naming the link of a name. *)

val flash_id : string
(** The id of the definition flashed after going to it. *)

val link_at : float * float -> int option
(** [link_at point] is the link whose name lies at [point] of the viewport, by
    its index. *)

val jump : int -> unit
(** [jump offset] places the caret of the editor at [offset], in UTF-16 code
    units, without scrolling, and scrolls the flashed definition to the upper
    part of the viewport when it lies outside its middle part; smoothly unless
    reduced motion is preferred. *)
