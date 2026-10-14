(** Rendering of a computation with its next redex marked. *)

val highlight_delimited : char -> string -> 'a Vdom.vdom list
(** [highlight_delimited marker s] is the syntax-highlighted text of [s] as
    nodes, its part between two occurrences of [marker] wrapped in an element of
    the class [active-redex]. If [marker] occurs other than twice, no part is
    wrapped and the occurrences are dropped. *)

module Make (GS : Grades.GradeSystem.S) : sig
  val view_computation_with_redexes :
    ('a, 'b) Interpreter.Types.context_frame
    Interpreter.Types.computation_reduction
    option ->
    (GS.R.t Language.Ast.rho, 'c) Language.Ast.computation ->
    'd Vdom.vdom list
  (** [view_computation_with_redexes reduction comp] is the syntax-highlighted
      text of [comp] as nodes, with the redex of [reduction], if any, within its
      context, wrapped in an element of the class [active-redex]. *)
end
