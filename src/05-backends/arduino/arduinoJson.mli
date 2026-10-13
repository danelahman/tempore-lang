(** JSON documents with the locations of their values, for the device manifests
    and board profiles of the Arduino backend.

    The syntax is that of RFC 8259. A number is kept as the text of its source,
    so that a decimal is read exactly; strings are UTF-8, and the escapes
    [\uXXXX] are decoded, surrogate pairs included. An object keeps its members
    in order. *)

type t = { value : value; at : Utils.Location.t }
(** A value with the span of its source. *)

and value =
  | Null
  | Bool of bool
  | Number of string  (** the text of the number *)
  | String of string
  | Array of t list
  | Object of (string Utils.Location.located * t) list
      (** the members, each with the location of its name *)

val parse : filename:string -> string -> t
(** [parse ~filename source] is the JSON document [source], whose locations are
    reported under [filename].

    @raise Utils.Error.Error
      a syntax error at the first character that is not part of a document. *)

val kind : t -> string
(** [kind v] is the kind of [v] in a message: ["a string"], ["a number"], ... *)

(** {1 Decoding}

    The decoders raise a compilation {!Utils.Error.Error} at the value that does
    not decode, its message naming the member by [what], e.g.
    ["the member 'period' of a task"]. *)

type fields
(** The members of an object. *)

val fields : what:string -> accepted:string list -> t -> fields
(** [fields ~what ~accepted v] is the members of the object [v], described by
    [what], e.g. ["a task"], each of whose names is one of [accepted], none
    twice. *)

val optional : fields -> string -> (what:string -> t -> 'a) -> 'a option
(** [optional fields name decode] is the member [name] of [fields] decoded by
    [decode], if present. *)

val required : fields -> string -> (what:string -> t -> 'a) -> 'a
(** [required fields name decode] is the member [name] of [fields] decoded by
    [decode].

    @raise Utils.Error.Error at the object if the member is missing. *)

val location : fields -> string -> Utils.Location.t
(** [location fields name] is the location of the value of the member [name] if
    present, and else that of the object. *)

val string : what:string -> t -> string
val bool : what:string -> t -> bool

val int : what:string -> t -> int
(** A number that is an integer from 0 to 2{^ 31} - 1. *)

val rational : what:string -> t -> Grades.Rational.t
(** A non-negative number without exponent, read exactly. *)

val list : (what:string -> t -> 'a) -> what:string -> t -> 'a list
(** [list decode ~what v] is the elements of the array [v], each decoded by
    [decode]. *)
