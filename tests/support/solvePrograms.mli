(** Whole programs checked command by command by the constraint solver. *)

type command_verdict = { line : int; kind : string; ok : bool; detail : string }
(** The verdict of the solver on one command. *)

module type PROGRAMS = sig
  val file :
    ?packages:(string * string * (string * Grades.Grade.running_time) list) list ->
    string ->
    command_verdict list option
  (** [file ?packages path] is the verdicts on the file at [path], after the
      standard library and the declarations of [packages], each of whose
      commands must be accepted; [None] if it does not parse or desugar. *)

  val definitions : string -> (string * bool * string) list
  (** [definitions source] is the command, whether it is accepted, and why not,
      for each command of [source], after the standard library. *)
end

val programs_of : ?levels:Grades.LevelLattice.t -> string -> (module PROGRAMS)
(** [programs_of ?levels grades] is the programs of the grades named [grades],
    over the lattice of levels [levels] if given, the standard library loaded
    once. *)
