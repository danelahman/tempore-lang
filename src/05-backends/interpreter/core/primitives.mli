(** The built-in primitive functions of the interpreter. *)

module Make (GS : Grades.GradeSystem.S) : sig
  val primitive_function :
    Language.Primitives.primitive ->
    (GS.R.t Language.Ast.rho, 'a) Language.Ast.expression ->
    ('b, 'c) Language.Ast.computation
  (** [primitive_function prim arg] is the computation applying [prim] to the
      value [arg]; a result is located at [arg]. A mismatch of [arg] with the
      argument type of [prim] is a runtime error. *)
end
