(** The default graph. Its nodes are operations, with an edge from [A] to [B]
    when the default implementation of [A] may perform [B]: its body performs
    [B], or uses a top-level definition that may perform [B]. A term may perform
    the operations it performs syntactically, anywhere in it, and those of the
    top-level definitions it uses; operations handled inside the term are
    counted too. A default may not perform its own operation, directly or
    through the defaults of the operations it may perform. *)

type performed
(** The operations a term may perform, each with where it does so first. *)

val expression :
  global:(Language.Ast.variable -> Language.Ast.OpNameSet.t) ->
  ('rho, 'eps) Language.Ast.expression ->
  performed
(** [expression ~global e] is the operations [e] may perform, [global x] being
    the operations the top-level definition [x] may perform. *)

val abstraction :
  global:(Language.Ast.variable -> Language.Ast.OpNameSet.t) ->
  ('rho, 'eps) Language.Ast.abstraction ->
  performed
(** [abstraction ~global abs] is the operations the body of [abs] may perform.
*)

val operations : performed -> Language.Ast.OpNameSet.t
(** [operations performed] is the set of operations of [performed]. *)

type default = {
  performs : Language.Ast.OpNameSet.t;  (** the operations it may perform *)
  default_at : Utils.Location.t;  (** the [default] command *)
}
(** A default implementation of an operation, the edges out of it. *)

val check_default :
  default:(Language.Ast.operation -> default option) ->
  loc:Utils.Location.t ->
  Language.Ast.operation ->
  performed ->
  unit
(** [check_default ~default ~loc op performed] checks the default of [op] at
    [loc], whose body may perform [performed], against the defaults [default]
    declared so far: [op] must not be reachable in the graph from an operation
    of [performed].

    @raise Utils.Error.Error
      a typing error at [loc] labelled with a shortest path to [op] otherwise *)
