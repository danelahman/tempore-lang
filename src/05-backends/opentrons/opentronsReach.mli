(** Free variables of terms, and the top-level definitions a program uses. *)

module VariableSet : Set.S with type elt = Language.Ast.variable

val pattern_variables : ('rho, 'eps) Language.Ast.pattern -> VariableSet.t
(** [pattern_variables p] is the variables [p] binds. *)

val free_in_expression : ('rho, 'eps) Language.Ast.expression -> VariableSet.t
(** [free_in_expression e] is the free variables of [e]. *)

val free_in_computation : ('rho, 'eps) Language.Ast.computation -> VariableSet.t
(** [free_in_computation c] is the free variables of [c]. *)

val free_in_abstraction : ('rho, 'eps) Language.Ast.abstraction -> VariableSet.t
(** [free_in_abstraction (p, c)] is the free variables of [c] that [p] does not
    bind. *)

val reachable :
  ('rho, 'eps) Language.Ast.command list ->
  ('rho, 'eps) Language.Ast.command list
(** [reachable commands] is [commands] without the top-level definitions that no
    [run] command and no default implementation of an operation uses, directly
    or through other definitions. *)
