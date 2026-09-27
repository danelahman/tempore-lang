(** Diagnostics of rejected commands: for each way a constraint fails, the
    sentence, the places pointed at and the notes.

    A failure names the atoms it follows from by their {!Inference.Reason.t};
    the types a message shows that no failing atom holds, such as the type of a
    variable used after time or of a function applied to a wrong argument, are
    read off a solution of the command's constraint without the failing atoms.
*)

module Make (C : Inference.Constraint.S) : sig
  type source = {
    context : Inference.Solver.Make(C).context;
        (** the cost model and type definitions *)
    constr : C.t option;
        (** the constraint of the command, whose unknowns the failure mentions,
            when known *)
    solution : Inference.Solver.Make(C).solution option;
        (** its solution, when the failure is found by the search for a closed
            instance of its qualifier, whose values the grades of the locks are
            shown at *)
    mismatch : Inference.Solver.Make(C).mismatch option;
        (** the provenance of the failure, when it is a failed expansion *)
  }
  (** What a failure is explained against. *)

  val refuted :
    source -> Inference.Residual.Make(C).failure -> Utils.Diagnostic.t
  (** [refuted source failure] is the diagnostic of [failure]. *)

  val stuck : source -> Inference.RigidScope.Make(C).stuck -> Utils.Diagnostic.t
  (** [stuck source s] is the diagnostic of a handler clause whose rigid scope
      cannot be closed. *)

  val refutes_effect : Inference.Residual.Make(C).failure -> bool
  (** [refutes_effect failure] is whether the ordering [failure] refutes, the
      one its diagnostic is built on, is an effect ordering: a bound on the
      effect of a computation. *)

  val without_refuted : Inference.Residual.Make(C).failure -> C.t -> C.t option
  (** [without_refuted failure c] is [c] without the atoms that [failure]
      refutes, the atoms its diagnostic is built on, when [c] has any. *)
end
