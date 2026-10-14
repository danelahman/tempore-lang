(** Free variables of terms, and the top-level definitions a program uses. *)

val pattern_variables :
  ('rho, 'eps) Language.Ast.pattern -> Language.Ast.VariableSet.t
(** [pattern_variables p] is the variables [p] binds. *)

val free_in_expression :
  ('rho, 'eps) Language.Ast.expression -> Language.Ast.VariableSet.t
(** [free_in_expression e] is the free variables of [e]. *)

val free_in_computation :
  ('rho, 'eps) Language.Ast.computation -> Language.Ast.VariableSet.t
(** [free_in_computation c] is the free variables of [c]. *)

val free_in_abstraction :
  ('rho, 'eps) Language.Ast.abstraction -> Language.Ast.VariableSet.t
(** [free_in_abstraction (p, c)] is the free variables of [c] that [p] does not
    bind. *)

val reachable :
  ('rho, 'eps) Language.Ast.command list ->
  ('rho, 'eps) Language.Ast.command list
(** [reachable commands] is [commands] without the top-level definitions that no
    [run] command and no default implementation of an operation uses, directly
    or through other definitions. *)

(** {1 Operations of runs} *)

module OperationSet : Set.S with type elt = string

type run_operations = {
  performed : OperationSet.t;  (** the operations the run's code may perform *)
  handled : OperationSet.t;
      (** the operations a handler in the run's code has a case for *)
  defaults : OperationSet.t;
      (** the operations with a default implementation declared above the run *)
}
(** The operations of a [run] command, by name. *)

val run_operations :
  bound:(string -> bool) ->
  ('rho, 'eps) Language.Ast.command list ->
  run_operations list
(** [run_operations ~bound commands] is the operations of each [run] command of
    [commands], in order. The code of a run is its computation, the top-level
    definitions it uses, directly or through other definitions, and the default
    implementations, declared above it, of the operations its code performs and
    [bound] does not hold of. *)
