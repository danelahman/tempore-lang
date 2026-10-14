(** Desugaring of [Parser.SugaredAst] commands into [Language.Ast] commands.

    [Make] is parameterised by a grade system, whose resource and effect grades
    grade the commands on either side. *)

module References = References

module Make (GS : Grades.GradeSystem.S) : sig
  type state

  val initial_state : state

  val load_primitive :
    state -> Language.Ast.variable -> Language.Primitives.primitive -> state

  val desugar_command :
    state ->
    ( GS.R.t SugaredAst.grade SugaredAst.annotated,
      GS.E.t SugaredAst.grade SugaredAst.annotated )
    SugaredAst.command ->
    state * Language.Ast.Graded(GS).command
end
