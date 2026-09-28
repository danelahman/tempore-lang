(** The structural termination check of recursive functions: a recursive
    function must have a parameter such that every occurrence of the function in
    its body is applied to a strict structural part of that parameter, that is,
    to a variable bound under a constructor or a successor pattern matched
    against it. The check is syntactic and runs on well-typed programs. *)

val check_expression : ('rho, 'eps) Language.Ast.expression -> unit
(** [check_expression e] checks every recursive function in [e], however deeply
    nested.

    @raise Utils.Error.Error
      a typing error at the first occurrence of a function that fails the check
*)

val check_computation : ('rho, 'eps) Language.Ast.computation -> unit
(** [check_computation c] checks every recursive function in [c]. *)

val check_abstraction : ('rho, 'eps) Language.Ast.abstraction -> unit
(** [check_abstraction abs] checks every recursive function in [abs]. *)
