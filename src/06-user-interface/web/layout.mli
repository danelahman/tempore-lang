(** Documents laid out within a width: Wadler's prettier printer (P. Wadler, "A
    prettier printer", 2003), in its strict form, with the alignment of Leijen's
    wl-pprint. Text is measured in characters, that is UTF-8 code points, each
    taken to fill one cell of a monospace font. *)

(** A document whose text is annotated by ['a]. *)
type 'a doc =
  | Text of 'a * string
  | Line  (** a space where its group is flat, a line break where it is not *)
  | Cat of 'a doc list
  | Nest of int * 'a doc  (** line breaks within indented further *)
  | Align of 'a doc  (** line breaks within indented to the current column *)
  | Group of 'a doc  (** flat where it fits on the rest of the line *)

val layout : width:int -> 'a doc -> ('a option * string) list list
(** [layout ~width doc] is the lines of [doc] laid out within [width] characters
    where it can be, each a list of runs of text with their annotations, [None]
    for spaces and indentation. *)
