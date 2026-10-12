module Ast = Language.Ast
module Primitives = Language.Primitives

(** What a step of an interpreter run shows of the operations performed and the
    time passed, for models of the operations of runs. *)
type observation =
  | Delayed of Grades.Rational.t  (** a delay of the given duration *)
  | Performed of string
      (** a call of the operation, unhandled, performed by its default
          implementation *)
  | Resumed
      (** the default implementation of the innermost call still running has
          returned to the continuation of the call *)
  | Returned of string  (** the run has returned the value printed *)
  | Stopped of string
      (** the run has ended at a call of the operation, which has neither a
          handler nor a default implementation *)

module type S = sig
  module Grades : Grades.GradeSystem.S
  (** The grade system grading the programs the backend runs. *)

  type load_state

  type evaluation_environment = {
    state :
      ( Ast.Variable.t,
        (Ast.Graded(Grades).rho * Ast.Graded(Grades).expression)
        Ast.VariableMap.t,
        Ast.Graded(Grades).rho )
      Ast.context_elem_ty
      list;
    variables :
      ( Ast.Variable.t,
        Ast.Graded(Grades).expression Ast.VariableMap.t,
        Ast.Graded(Grades).rho )
      Ast.context_elem_ty
      list;
    builtin_functions :
      ( Ast.Variable.t,
        (Ast.Graded(Grades).expression -> Ast.Graded(Grades).computation)
        Ast.VariableMap.t,
        Ast.Graded(Grades).rho )
      Ast.context_elem_ty
      list;
    resource_counter : int;
    op_signatures : Ast.Graded(Grades).eps Ast.OpNameMap.t;
    op_defaults : Ast.Graded(Grades).abstraction Ast.OpNameMap.t;
  }

  val initial_load_state : load_state

  val load_primitive :
    load_state -> Ast.variable -> Primitives.primitive -> load_state

  val load_ty_def :
    load_state ->
    Ast.eternality
    * (Ast.ty_param list * Ast.ty_name * Ast.Graded(Grades).ty_def) list ->
    load_state

  val load_top_let :
    load_state -> Ast.variable -> Ast.Graded(Grades).expression -> load_state

  val load_top_do : load_state -> Ast.Graded(Grades).computation -> load_state

  val load_op_sig :
    load_state -> Ast.OpName.t -> Ast.Graded(Grades).eps -> load_state

  val load_op_default :
    load_state -> Ast.OpName.t -> Ast.Graded(Grades).abstraction -> load_state

  type run_state
  type step_label

  type step = {
    environment : evaluation_environment;
    label : step_label;
    next_state : unit -> run_state;
  }

  val run : load_state -> run_state
  val steps : run_state -> step list
end
