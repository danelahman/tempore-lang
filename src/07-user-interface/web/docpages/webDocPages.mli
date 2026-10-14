(** The pages of the documentation view of the web interface, each rendered from
    a README of the repository, and the targets of the links in them. *)

type page =
  | Main  (** the project's README *)
  | Arduino  (** the README of the Arduino backend *)
  | Opentrons  (** the README of the Opentrons backend *)

val all : page list
(** The pages in the order the side panel lists them, [Main] first. *)

val label : page -> string
(** [label p] is the short name of [p] in the side panel. *)

val title : page -> string
(** [title p] is the full name of [p]. *)

val path : page -> string
(** [path p] is the path of the README [p] is rendered from, relative to the
    project root. *)

val normalise : base:string -> string -> string
(** [normalise ~base dest] is the relative path [dest], written in the file at
    path [base], as a path relative to the project root: [dest] is appended to
    the directory of [base], or taken from the root when it starts with [/], and
    its segments [.] and [..] are removed as in
    {{:https://www.rfc-editor.org/rfc/rfc3986#section-5.2.4}RFC 3986, 5.2.4}, a
    [..] at the root being dropped. A trailing [/] is kept. *)

(** Where a link of a page leads. *)
type target =
  | Anchor of string  (** the heading of the identifier on the same page *)
  | Page of page * string option
      (** another page, at the heading of the identifier if one is given *)
  | Repository of string
      (** a path relative to the project root, with its fragment if any *)
  | External of string  (** an absolute URL *)

val resolve : from:page -> string -> target
(** [resolve ~from dest] is the target of the link destination [dest] on the
    page [from]. A destination starting with [http://], [https://] or [mailto:]
    is external, one starting with [#] an anchor; any other is a path relative
    to the README of [from], normalised by {!normalise}. A path to the README of
    a page is that page, or an anchor of [from] when it is [from]'s own README
    with a fragment. *)
