(** Type inference over whole programs, command by command, as the loader
    processes them.

    A type definition or operation signature extends the environment. A default
    implementation, a top-level definition and a run have their constraint
    generated and solved, and the qualifier of the solution searched for a
    closed instance ({!Solver.Make.satisfiable}); the command is rejected when
    either refutes. A top-level definition is generalised to its reported scheme
    [∀Θ. Q ∧ R ⇒ A] ({!Solver.Make.generalise}), no unknown being free in the
    environment of top-level definitions; local definitions are not generalised.

    Satisfiability of a definition's qualifier is decided provisionally: the
    definition is accepted unless the search for a closed instance refutes its
    qualifier, and each use of the definition checks the qualifier instantiated
    at the use.

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
  (** [context ~loc env] is the cost model ({!Generate.Make.cost_model}) and the
      type definitions of [env]; the cost of an undeclared event is a typing
      error at [loc]. *)

  (** Whether the commands after one are processed. *)
  type next = Continue | Stop

  val execute : env -> command -> env * verdict * next
  (** [execute env cmd] is the environment after [cmd], its verdict, and whether
      the commands after it are processed. *)

  type envs = { reported : env; unsimplified : env }
  (** The environments of the definitions with their reported schemes and with
      their unsimplified schemes ({!Solver.Make.unsimplified}), against which
      failures are explained. *)

  val both : (env -> env) -> envs -> envs
  (** [both f envs] is [f] applied to each environment of [envs]. *)

  val execute_both : envs -> command -> envs * verdict * next
  (** [execute_both envs cmd] is {!execute} on [envs.reported], the environments
      after [cmd] extended alike except that a definition enters [unsimplified]
      with its unsimplified scheme. *)

  val execute_all : env -> command list -> env * verdict list
  (** [execute_all env cmds] executes [cmds] in order until one stops them. *)

  val print_outcome : outcome -> Format.formatter -> unit
  (** [print_outcome outcome ppf] prints [outcome]: a definition with its scheme
      ({!Constraint.S.print_scheme}), a rejection with its failure. *)
end
