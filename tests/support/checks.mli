(** Checks with a name, a verdict and a detail, reported together. *)

type check = { name : string; passed : bool; detail : string }

val check : string -> bool -> string -> check
(** [check name passed detail] is the check [name] with its verdict and the
    detail printed if it fails. *)

val expect : string -> ('a -> string) -> expected:'a -> 'a -> check
(** [expect name show ~expected actual] passes when [actual] is [expected], the
    two shown by [show] if it fails. *)

val report : check list -> unit
(** [report checks] prints the failed checks and the number of those passed, and
    exits with status 1 if any failed. *)
