(** The small-step interpreter of Tempore programs: the commands of a program
    are loaded into a state, and its top-level [run] commands are executed by
    reductions of their computations in reduction contexts. *)

(** The kinds of reductions and the labels of steps, independent of the grade
    system. *)
module Types : sig
  type computation_redex =
    | Match
    | ApplyFun
    | DoReturn
    | DoOp
    | Delay
    | Box
    | Unbox
    | HandleReturn
    | HandleOp
    | DefaultOp

  (** A frame of a reduction context: a [do] or a [handle] around the hole, with
      the location of that node and its part outside the hole. *)
  type ('abstraction, 'expression) context_frame =
    | DoFrame of Utils.Location.t * 'abstraction
    | HandleFrame of Utils.Location.t * 'expression

  type 'frame computation_reduction = {
    context : 'frame list;
    redex : computation_redex;
  }
  (** A reduction: a redex in a reduction context, given by its frames, the
      innermost first. *)

  (** A step of a top-level [run] command: a reduction of its computation, or
      the end of the command at a returned value or at an unhandled operation
      call. *)
  type 'frame run_step_label =
    | ComputationReduction of 'frame computation_reduction
    | Return
    | Unhandled
end

(** The interpreter for the grade system [GS]. *)
module Make (GS : Grades.GradeSystem.S) : sig
  module Grades : module type of struct
    include GS
  end

  module Graded : module type of Language.Ast.Graded (GS)

  include module type of struct
    include Types
  end

  type evaluation_environment = {
    state :
      ( Language.Ast.Variable.t,
        (Graded.rho * Graded.expression) Language.Ast.VariableMap.t,
        Graded.rho )
      Language.Ast.context_elem_ty
      list;
    variables :
      ( Language.Ast.Variable.t,
        Graded.expression Language.Ast.VariableMap.t,
        Graded.rho )
      Language.Ast.context_elem_ty
      list;
    builtin_functions :
      ( Language.Ast.Variable.t,
        (Graded.expression -> Graded.computation) Language.Ast.VariableMap.t,
        Graded.rho )
      Language.Ast.context_elem_ty
      list;
    resource_counter : int;
    op_signatures : Graded.eps Language.Ast.OpNameMap.t;
    op_defaults : Graded.abstraction Language.Ast.OpNameMap.t;
  }
  (** The state holds each resource with the resource grade it was boxed at,
      interleaved with the resource grades that have passed; operations are
      graded by effect grades. *)

  type frame = (Graded.abstraction, Graded.expression) context_frame

  type focus = { frames : frame list; subject : Graded.computation }
  (** A computation decomposed into a reduction context, its frames the
      innermost first, and the subcomputation in its hole. Unless the context is
      empty, the subcomputation is not a [return] or an operation call. *)

  val computation : focus -> Graded.computation
  (** [computation focus] is the computation [focus] decomposes. *)

  val returned_value :
    evaluation_environment -> Graded.computation -> Graded.computation
  (** [returned_value env comp] is [comp] with the value it returns, if it is a
      [return], given by its top-level variables replaced by their values in
      [env]. *)

  type load_state
  (** The commands of a program loaded so far. *)

  val initial_load_state : load_state

  val load_primitive :
    load_state ->
    Language.Ast.variable ->
    Language.Primitives.primitive ->
    load_state
  (** [load_primitive state x prim] binds [x] to the primitive [prim]. *)

  val load_ty_def :
    load_state ->
    Language.Ast.eternality
    * (Language.Ast.ty_param list * Language.Ast.ty_name * Graded.ty_def) list ->
    load_state
  (** A type definition does not change the state. *)

  val load_top_let :
    load_state -> Language.Ast.variable -> Graded.expression -> load_state
  (** [load_top_let state x e] binds [x] to the value of [e]. *)

  val load_top_do : load_state -> Graded.computation -> load_state
  (** [load_top_do state c] adds the [run] command of [c], executed in the
      environment of the commands above it. *)

  val load_op_sig :
    load_state -> Language.Ast.OpName.t -> Graded.eps -> load_state
  (** [load_op_sig state op eps] declares the effect grade of [op]. *)

  val load_op_default :
    load_state -> Language.Ast.OpName.t -> Graded.abstraction -> load_state
  (** [load_op_default state op abs] declares the default implementation of
      [op]. *)

  type run_state = {
    environment : evaluation_environment;
    current : focus option;
    pending : (evaluation_environment * Graded.computation) list;
  }
  (** The computation of the current [run] command, if any, decomposed at its
      redex, with its environment, and the [run] commands after it, each with
      the environment of the commands above it. *)

  type step_label = frame run_step_label

  type step = {
    environment : evaluation_environment;
    label : step_label;
    next_state : unit -> run_state;
  }
  (** A step of a run state: the environment it is taken in, its label and the
      state after it. *)

  val run : load_state -> run_state
  (** [run state] is the state at the start of the first [run] command of
      [state], or its final state if there is none. *)

  val steps : run_state -> step list
  (** [steps state] are the steps available from [state]: none once all [run]
      commands have completed. *)
end
