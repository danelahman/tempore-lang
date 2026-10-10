(** Generic pretty-printing functions. *)

val subscript : int -> string
(** [subscript n] is the decimal numeral of the non-negative integer [n] in
    Unicode subscript digits. *)

val print :
  ?at_level:int ->
  ?max_level:int ->
  Format.formatter ->
  ('a, Format.formatter, unit) format ->
  'a
(** [print ?at_level ?max_level ppf fmt] prints by [fmt], in parentheses where
    [at_level], the precedence level of the printed construct, exceeds
    [max_level], the greatest level admitted by the context. *)

val print_sequence :
  string ->
  ('a -> Format.formatter -> unit) ->
  'a list ->
  Format.formatter ->
  unit
(** [print_sequence sep pp vs] prints the elements of [vs] by [pp], separated by
    [sep] and a break hint. *)

val print_tuple :
  ?max_level:int ->
  (?max_level:int -> 'a -> Format.formatter -> unit) ->
  'a list ->
  Format.formatter ->
  unit
(** [print_tuple ?max_level pp vs] prints [vs] as a parenthesised,
    comma-separated tuple, [()] when [vs] is empty. *)
