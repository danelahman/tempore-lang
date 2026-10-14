(** C++ source text, for the compiled programs ({!ArduinoEmit}) and the
    generated projects ({!ArduinoProject}): statements, declarations, includes
    and literals. Types, expressions and names are strings of C++. *)

(** {1 Statements} *)

type stmt =
  | Line of string  (** a line *)
  | Block of string * stmt list * string
      (** a header line, followed by [{], an indented body and a closing line *)
  | If of (string option * stmt list) list
      (** a chain of [if], [else if] and [else]: the conditions, [None] for the
          last [else], each with its body *)

val render : stmt list -> string
(** [render stmts] is the text of [stmts], each line ended by a newline, each
    body indented by two spaces more than its header. *)

val blank : stmt
(** An empty line. *)

val comment : string -> stmt
(** [comment text] is the line comment [// text]. *)

val block : string -> stmt list -> stmt
(** [block header body] is [header {], the indented [body], and [}]. *)

val statement : string -> stmt
(** [statement e] is the expression statement [e;]. *)

val return : string -> stmt
(** [return e] is [return e;]. *)

val assign : string -> string -> stmt
(** [assign x e] is [x = e;]. *)

(** {1 Declarations} *)

val constant : ?static:bool -> string -> string -> string -> stmt
(** [constant ~static ty x e] is [const ty x = e;], preceded by [static] if
    [static] (default [false]). *)

val variable : ?init:string -> string -> string -> stmt
(** [variable ~init ty x] is [ty x = init;], or [ty x{};], the variable
    value-initialised, without [init]. *)

val declarator :
  ?static:bool ->
  ?inline:bool ->
  string ->
  string ->
  (string * string option) list ->
  string
(** [declarator ~static ~inline result name parameters] is the declarator of the
    function [name] of result type [result] and of [parameters], each a type
    with its name, if any: [result name(ty1 x1, ty2)], preceded by [static] or
    [inline] if requested (default [false]). *)

val prototype : ?static:bool -> string -> string -> string list -> stmt
(** [prototype ~static result name types] is the declaration
    [result name(types);] of a function. *)

val definition :
  ?static:bool ->
  ?inline:bool ->
  string ->
  string ->
  (string * string option) list ->
  stmt list ->
  stmt
(** [definition ~static ~inline result name parameters body] is the definition
    of a function, the block of its {!declarator}. *)

val typedef : string -> string -> stmt
(** [typedef ty name] is [typedef ty name;]. *)

val null_terminated : string -> string list -> stmt list
(** [null_terminated declaration elements] is the definition
    [declaration = {...}] of an array of [elements] ended by [nullptr], one
    element per line, indented by four spaces. *)

(** {1 Preprocessor} *)

val system_include : string -> stmt
(** [system_include h] is [#include <h>]. *)

val local_include : string -> stmt
(** [local_include h] is [#include "h"]. *)

val define : string -> stmt
(** [define m] is [#define m]. *)

(** {1 Identifiers} *)

val is_identifier_start : char -> bool
(** [is_identifier_start c] is whether [c] may start an identifier: an ASCII
    letter or [_]. *)

val is_identifier_char : char -> bool
(** [is_identifier_char c] is whether [c] may occur in an identifier: an ASCII
    letter, a digit or [_]. *)

(** {1 Expressions} *)

val call : string -> string list -> string
(** [call f arguments] is [f(a1, a2, ...)]. *)

val string_literal : string -> string
(** [string_literal s] is a C++ string literal, in printable ASCII, of the bytes
    of [s]. *)
