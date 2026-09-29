(** The typechecker: type inference over a grade system, command by command,
    with a diagnostic for each rejected command.

    A command is checked by {!Inference.Program}: a type definition or operation
    signature extends the environment, a default implementation, a top-level
    definition and a run have their constraint generated and solved. A rejected
    command is explained by {!Explain}, against its constraint generated again
    over the unsimplified schemes of the definitions.

    Of the failing requirements of a command, each found by solving its
    constraint again without the atoms refuted by those found before, the one
    met first in reading order is explained: an effect bound at the end of the
    place its diagnostic points at, any other requirement where that place
    begins, the first found among those met at one point. *)

module Ast = Language.Ast

module Make (GS : Grades.GradeSystem.S) : sig
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

  val declare_operations :
    (string * Grades.Grade.runtime option) list -> state -> state
  (** [declare_operations declarations state] is [state] in a program whose
      operation declarations, in all its sources, are [declarations], each an
      operation name with its runtime bounds if it declares them. The grades of
      every command are read over the operations the program declares with
      runtime bounds ({!Inference.Generate.Make.declare_operations}), whether
      declared before or after the command; an operation is still performed only
      after its declaration. *)

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

  val print_scheme : state -> scheme -> Format.formatter -> unit
  (** [print_scheme state scheme ppf] prints [scheme] with its qualifier, an
      effect of the unit under the cost model of [state] not shown. *)

  val scheme_layout : state -> scheme -> Inference.Constraint.layout
  (** [scheme_layout state scheme] is the parts of the scheme that
      {!print_scheme} prints, laid out apart: the parameters, the conjuncts of
      the qualifier and the type in parts around its arrows, to be applied in
      this order. *)
end
