(** The source of a constraint atom: the construct it was generated for, the
    rule that generated it, and the position within a decomposed atom it came
    from.

    Reasons are parametric in the resource grades ['rho] and the effect grades
    ['eps] they mention, so that each grade keeps its sort: the grades of the
    locks of a context are resource grades, an ordering as stated may be of
    either sort. Apart from these grades a reason is plain data. *)

module Location = Utils.Location
module Ast = Language.Ast

type clause = {
  op : Ast.operation;  (** the operation the clause handles or implements *)
  signature_at : Location.t;  (** the operation's signature *)
  case_at : Location.t;  (** the clause, pattern and body *)
}
(** A handler clause or a default implementation of an operation. *)

(** The construct a lock of the context stands for. *)
type lock_kind =
  | Delayed of Grades.Rational.t  (** [delay q] *)
  | Performed of Ast.operation  (** [perform Op], before its continuation *)
  | Sequenced  (** the computation bound by [let] or [;] *)
  | Boxed  (** the payload of [box ρ], checked under the lock [⟨ρ⟩] *)
  | Handled
      (** the handled computation, before the return clause of a handler *)
  | Clause_lock of clause
      (** the lock [⟨⊤⟩] of a handler clause or of a default implementation *)

type 'rho lock = {
  grade : 'rho;
  at : Location.t;
  kind : lock_kind;
  declared : 'rho option;
      (** the grade its construct declares, when that is not the lock's grade:
          [n] of a [delay n] and the grade of [Op] mapped to a resource grade of
          a [perform Op e], each bound by [let] or [;] *)
}
(** A lock of the context, with its resource grade and its construct. *)

(** A position within a decomposed atom. *)
type step =
  | Argument  (** the domain of a function type *)
  | Result  (** the value type of the codomain of a function type *)
  | Effect  (** the effect of a computation type *)
  | Component of int  (** of a tuple, from 1 *)
  | Type_argument of int  (** of a type application, from 1 *)
  | Box_content  (** the type under a box *)
  | Box_grade  (** the grade of a box *)
  | Handler_input  (** the handled computation type of a handler type *)
  | Handler_output  (** the result computation type of a handler type *)

type rigid_origin = {
  clause : clause;  (** the clause *)
  continuation : Ast.variable option;
      (** the variable the clause binds the continuation to, if the pattern is
          one *)
  continuation_at : Location.t;
      (** the continuation's pattern, or the clause if there is none *)
}
(** The handler clause a rigid effect variable, the effect of the clause's
    continuation, belongs to. *)

(** The rule that generated an atom. Each constructor carries the places its
    messages point at. *)
type ('rho, 'eps) why =
  | Application of { func_at : Location.t; arg_at : Location.t }
      (** at = the application; the function's type is an arrow from the
          argument's type (step [Argument]) *)
  | Match_scrutinee of { scrutinee_at : Location.t }
      (** at = the pattern; the matched value has the pattern's shape *)
  | Match_branch
      (** at = the branch body; its type and effect are the match's *)
  | Annotation  (** at = the annotated expression *)
  | Pattern_annotation  (** at = the annotated pattern *)
  | Variant_argument of Ast.label  (** at = the argument of a constructor *)
  | Successor_pattern
      (** at = the argument of a successor pattern, which matches natural
          numbers *)
  | Boxed_value  (** at = the [box]; the payload's type is boxed *)
  | Unboxed of {
      var : Ast.variable;
      bound_at : Location.t option;
      locks : 'rho lock list;
    }
      (** at = the [unbox]; the variable's type is a box whose grade covers the
          grade accumulated since its binding, that of [locks], the locks since
          the binding, oldest first *)
  | Use_under_locks of {
      var : Ast.variable;
      bound_at : Location.t;
      locks : 'rho lock list;
    }
      (** at = the use; the type is eternal or the grade accumulated since the
          binding, that of [locks], the locks since the binding, oldest first,
          is below the unit *)
  | Op_case_capture of {
      var : Ast.variable;
      bound_at : Location.t;
      clause : clause;
      locks : 'rho lock list;
    }
      (** as [Use_under_locks], for a variable bound outside [clause], the
          outermost such clause, whose lock [⟨⊤⟩] is among the locks *)
  | Instance_of of {
      var : Ast.variable;
      defined_at : Location.t option;
      inner : ('rho, 'eps) t;
    }
      (** at = a use of [var]; an atom or obligation of its scheme's qualifier
          [Q ∧ R], generated for [inner] *)
  | Handler_case of { op : Ast.operation; signature_at : Location.t }
      (** at = the clause, or its pattern; the clause's pattern and result are
          the operation's parameter, continuation and the handler's result *)
  | Continuation_grade of { op : Ast.operation; signature_at : Location.t }
      (** at = the clause; its effect is below the operation's grade followed by
          the continuation's *)
  | Perform_argument of { op : Ast.operation; signature_at : Location.t }
      (** at = the argument of [perform] *)
  | Perform_continuation of { op : Ast.operation; signature_at : Location.t }
      (** at = the pattern binding the result of [perform] *)
  | Handle_with  (** at = the handler expression of a [handle] *)
  | Handled_computation
      (** at = the computation of a [handle]; its type and effect are the
          handler's input *)
  | Return_clause
      (** at = the return clause of a handler, or its pattern; its type and
          effect are the handler's input value and output *)
  | Recursive_definition of Ast.variable
      (** at = the recursive function; its body's type and effect are the
          function's result *)
  | Function_body
      (** at = the function; its body's type and effect are the function's
          result *)
  | Function_parameter  (** at = the parameter pattern of a function *)
  | Pure_body
      (** at = a pure or recursive function; its body's effect is the unit *)
  | Sequencing
      (** at = the computation bound by [let] or [;]; its type is the pattern's
          and its effect the lock of the continuation *)
  | Continuation_effect of lock_kind
      (** at = the computation under a lock of the given kind; its effect is
          composed after the lock's *)
  | Default_of of { op : Ast.operation; signature_at : Location.t }
      (** at = the default implementation; its parameter, result (steps
          [Argument], [Result]) and effect (step [Effect]) are bounded by the
          operation's signature and runtime bounds *)
  | Top_definition of Ast.variable
      (** at = a top-level definition; its type is the one generalised *)
  | Top_computation  (** at = a top-level computation *)
  | Compared_values
      (** at = none, the primitives having no source; the values a comparison
          compares have an eternal type *)

(** An ordering as it was generated, before the solver rewrote it. *)
and ('rho, 'eps) stated =
  | Stated_rho of 'rho * 'rho
  | Stated_eps of 'eps * 'eps

and ('rho, 'eps) t = {
  at : Location.t;  (** the construct the atom was generated for *)
  why : ('rho, 'eps) why;
  path : step list;
      (** the position within the generated atom the atom was decomposed out of,
          outermost first *)
  subject : Location.t option;
      (** the term or pattern whose type or effect the atom bounds, when the
          bound was set by the construct at [at] *)
  stated : ('rho, 'eps) stated option;
      (** the ordering as generated, when the solver has rewritten it *)
}
(** A reason. *)

val because : Location.t -> ('rho, 'eps) why -> ('rho, 'eps) t
(** [because at why] is the reason of an atom generated for the construct at
    [at] by [why], undecomposed. *)

val step : step -> ('rho, 'eps) t -> ('rho, 'eps) t
(** [step s reason] is [reason] with [s] appended to its path. *)

val against : Location.t -> ('rho, 'eps) t -> ('rho, 'eps) t
(** [against subject reason] is [reason] with the subject [subject]. *)

val with_stated : ('rho, 'eps) stated -> ('rho, 'eps) t -> ('rho, 'eps) t
(** [with_stated s reason] is [reason] recording [s] as stated, unless it
    records a stated ordering already. *)

val clause_of_locks : 'rho lock list -> clause option
(** [clause_of_locks locks] is the clause of the first lock of kind
    [Clause_lock] in [locks], the outermost one when [locks] is oldest first. *)

val map_grades :
  ('rho -> 'rho2) -> ('eps -> 'eps2) -> ('rho, 'eps) t -> ('rho2, 'eps2) t
(** [map_grades on_rho on_eps reason] applies [on_rho] to the resource grades
    and [on_eps] to the effect grades of [reason]. *)

val fold_grades :
  ('rho -> 'a -> 'a) -> ('eps -> 'a -> 'a) -> ('rho, 'eps) t -> 'a -> 'a
(** [fold_grades on_rho on_eps reason acc] folds [on_rho] over the resource
    grades and [on_eps] over the effect grades of [reason]. *)

val print_step : step -> Format.formatter -> unit
(** [print_step s ppf] prints [s]. *)

val print_why : ('rho, 'eps) why -> Format.formatter -> unit
(** [print_why why ppf] prints the name of the rule [why], for debugging. *)

val print : ('rho, 'eps) t -> Format.formatter -> unit
(** [print reason ppf] prints the rule, the location and the path of [reason],
    for debugging. *)
