(** The failures of a test, recorded as it runs and reported at its end. *)

val fail : ('a, Format.formatter, unit, unit) format4 -> 'a
(** [fail fmt ...] records a failure whose message is formatted by [fmt]. *)

val finish : ?success:string -> unit -> unit
(** [finish ?success ()] prints the messages of the failures recorded, in order,
    on the standard error and exits with status 1 if there is any; otherwise it
    prints [success], if given. *)
