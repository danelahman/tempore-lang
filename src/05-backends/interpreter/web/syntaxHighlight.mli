(** Tokenizer that turns a string of pretty-printed ML-style code into a list of
    Vdom nodes with class-tagged spans for syntax highlighting.

    Classification happens once, as offsets into the text; rendering is
    separate. That way the editor can overlay error spans without first cutting
    the text into independently tokenized pieces, which would break a comment or
    string that an error starts inside. *)

val resource_label_marker : char
(** Byte used by the state printer to bracket resource names that appear as
    binding labels, and only those; references to resources inside stored values
    are left unmarked. The byte does not occur in any user-visible string. *)

val active_state_marker : char
(** Byte used by the state printer to bracket the entire entry of the resource
    currently being acted on by the redex, so that the web interface can
    highlight it the same way as the active redex. *)

type 'msg marker = {
  href : string;  (** where it links to, such as the message explaining it *)
  attrs : 'msg Vdom.attribute list;
      (** What else goes on every one of the numbers, such as the handlers and
          the class by which the view makes them light up as one block. A class
          here is merged into the numbers' own. *)
}
(** What the line numbers of the lines a mark covers link to. *)

type 'msg mark = {
  from : int;
  until : int;
  mark_cls : string;
  id : string option;
  marker : 'msg marker option;
}
(** A range of the text to wrap in a class of its own, such as the span of an
    error, with an optional element id to scroll to or link to. Unlike tokens,
    marks may nest, overlap and be given in any order. *)

val highlight_text : string -> 'a Vdom.vdom list
(** [highlight_text s] is [s] as nodes, each token in the class of its kind. *)

val highlight_with_marks :
  ?line_numbers:bool -> marks:'a mark list -> string -> 'a Vdom.vdom list
(** [highlight_with_marks ~marks s] highlights [s] as {!highlight_text} does and
    wraps each mark's range in its class. Cutting at every token and mark
    boundary makes each segment lie inside one token and wholly inside or
    outside each mark, so it carries that token's class and every mark's. With
    [line_numbers], each line is preceded by its number. *)
