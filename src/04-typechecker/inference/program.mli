(** Type inference over whole programs, command by command, as the loader
    processes them.

    A type definition or operation signature extends the environment. A default
    implementation, a top-level definition and a run have their constraint
    generated and solved, and the qualifier of the solution searched for a
    closed instance ({!Solver.Make.satisfiable}); the command is rejected when
    either refutes. A definition is generalised over every unknown of its solved
    type and of its qualifier [Q ∧ R], none being free in the environment of
    top-level definitions; this stands for the simplification and satisfiability
    check that are to replace it.

    A rejected definition is assumed to have the scheme [∀α. α], so that its
    uses are checked; a rejected default leaves the operation without one; a
    rejected type definition or operation signature stops the program. *)

module Make (C : Constraint.S) : sig
  type env = Generate.Make(C).env
  (** Environments. *)

  type command =
    ( Generate.Make(C).program_rho,
      Generate.Make(C).program_eps )
    Language.Ast.command
  (** Desugared commands. *)

  (** Why a command is rejected. *)
  type error =
    | Malformed of Utils.Diagnostic.t
        (** an error of the environment or of generation *)
    | Refuted of Solver.Make(C).failure  (** the constraint has no solution *)
    | Stuck of Solver.Make(C).stuck
        (** a clause's rigid scope cannot be closed *)

  (** The outcome of a command. *)
  type outcome =
    | Accepted  (** a declaration, a default or a run *)
    | Defined of Language.Ast.variable * C.scheme
        (** a top-level definition, with its scheme *)
    | Rejected of error

  type verdict = { at : Utils.Location.t; outcome : outcome }
  (** The outcome of the command at [at]. *)

  val context : loc:Utils.Location.t -> env -> Solver.Make(C).context
  (** [context ~loc env] is the cost model and type definitions of [env]; the
      cost of an undeclared event is a typing error at [loc]. *)

  (** Whether the commands after one are processed. *)
  type next = Continue | Stop

  val execute : env -> command -> env * verdict * next
  (** [execute env cmd] is the environment after [cmd], its verdict, and whether
      the commands after it are processed. *)

  val execute_all : env -> command list -> env * verdict list
  (** [execute_all env cmds] executes [cmds] in order until one stops them. *)
end
