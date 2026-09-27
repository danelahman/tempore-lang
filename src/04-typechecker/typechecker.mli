(** The typechecker: type inference over a grade system, command by command,
    with a diagnostic for each rejected command.

    A command is checked by {!Inference.Program}: a type definition or operation
    signature extends the environment, a default implementation, a top-level
    definition and a run have their constraint generated and solved. A rejected
    command is explained by {!Explain}. *)

module Ast = Language.Ast

module Make (GS : Language.GradeSystem.S) : sig
  type scheme
  (** The qualified type scheme of a top-level definition or primitive. *)

  type state
  (** The environment of the commands checked so far and the schemes of the
      top-level definitions and primitives. *)

  type command = (GS.R.t Ast.rho, GS.E.t Ast.eps) Ast.command
  (** Desugared commands. *)

  val initial_state : state
  (** The state of the built-in types, without primitives. *)

  val load_primitive :
    state -> Ast.variable -> Language.Primitives.primitive -> state
  (** [load_primitive state x prim] adds the primitive [prim] as [x]. *)

  (** How checking goes on after a rejected command. *)
  type recovery =
    | Continue of state
        (** the commands after it are checked in this state: a rejected
            definition is assumed to have the scheme [∀α. α], a rejected run or
            default leaves the state as it was *)
    | Stop  (** a type definition or operation signature was rejected *)

  val check : state -> command -> (state, Utils.Diagnostic.t * recovery) result
  (** [check state cmd] is the state after [cmd], or the diagnostic of its
      rejection and how to go on. *)

  val definitions : state -> (Ast.variable * scheme) list
  (** [definitions state] is the primitives and top-level definitions of [state]
      with their schemes, oldest first. *)

  val print_scheme : scheme -> Format.formatter -> unit
  (** [print_scheme scheme ppf] prints [scheme] with its qualifier. *)
end
