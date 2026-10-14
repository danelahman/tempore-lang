(** The policies of the monitors of the running-time bounds of the backends:
    what a monitor does when a running time is outside its bounds. *)

type t =
  | Abort
      (** the program stops: the Opentrons protocol ends with an error, and the
          device enters its safe state and halts its tasks *)
  | Warn  (** the violation is reported and the program goes on *)
  | Off  (** nothing is checked *)

val policies : (string * t) list
(** The policies with their names, [abort], [warn] and [off]. *)

val name : t -> string
(** [name policy] is the name of [policy]. *)

val of_name : string -> t option
(** [of_name s] is the policy named [s], if any. *)
