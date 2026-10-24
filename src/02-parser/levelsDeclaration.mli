(** The declaration of levels of a source, read before the source is parsed,
    since the grades of the source are read over the lattice it declares. *)

val scan :
  filename:string ->
  string ->
  (Utils.Location.t * string Utils.Location.located list list) option
(** [scan ~filename source] is the declaration of levels that opens [source],
    whose locations are reported under [filename]: its location and its chains,
    each a list of levels. A source that opens with no well-formed declaration,
    or that cannot be lexed, has none here; the parser reports its errors. *)
