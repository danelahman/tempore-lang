(** Rendering of a computation with its next redex marked. *)

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
