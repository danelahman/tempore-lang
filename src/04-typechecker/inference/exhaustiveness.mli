(** The exhaustiveness check of pattern matching: the cases of every match must
    together match every value of the scrutinee's type, and every other pattern,
    of a function parameter, a [let], a handler clause, a default or a box, must
    match every value of its type. A match without cases is exhaustive, its
    scrutinee being typed [empty]. The check is syntactic and runs on well-typed
    programs; a datatype is known by its constructors, whose full set is looked
    up. *)

type constructors = Language.Ast.label -> (Language.Ast.label * bool) list
(** [constructors lbl] is every constructor of the datatype of [lbl], each with
    whether it takes an argument. *)

val check_expression :
  constructors:constructors -> ('rho, 'eps) Language.Ast.expression -> unit
(** [check_expression ~constructors e] checks every match and every pattern in
    [e], however deeply nested.

    @raise Utils.Error.Error
      a typing error at the first match or pattern that is not exhaustive,
      naming a value it does not match *)

val check_computation :
  constructors:constructors -> ('rho, 'eps) Language.Ast.computation -> unit
(** [check_computation ~constructors c] checks every match and every pattern in
    [c]. *)

val check_abstraction :
  constructors:constructors -> ('rho, 'eps) Language.Ast.abstraction -> unit
(** [check_abstraction ~constructors (p, c)] checks the pattern [p] and every
    match and pattern in [c]. *)
