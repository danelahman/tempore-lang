(** Error reporting. *)

exception Error of Diagnostic.t
(** The exception by which every diagnosed error is raised. *)

val error :
  ?loc:Location.t ->
  ?labels:Diagnostic.label list ->
  ?notes:string list ->
  Diagnostic.kind ->
  ('a, Format.formatter, unit, 'b) format4 ->
  'a
(** [error ?loc ?labels ?notes kind fmt] raises an {!exception-Error} of [kind]
    with the message formatted by [fmt]. *)

val fatal : ?loc:Location.t -> ('a, Format.formatter, unit, 'b) format4 -> 'a
(** [fatal ?loc fmt] raises a fatal {!exception-Error}. *)

val syntax : loc:Location.t -> ('a, Format.formatter, unit, 'b) format4 -> 'a
(** [syntax ~loc fmt] raises a syntax {!exception-Error} at [loc]. *)

val typing :
  ?loc:Location.t ->
  ?labels:Diagnostic.label list ->
  ?notes:string list ->
  ('a, Format.formatter, unit, 'b) format4 ->
  'a
(** [typing ?loc ?labels ?notes fmt] raises a typing {!exception-Error}. *)

val runtime : ?loc:Location.t -> ('a, Format.formatter, unit, 'b) format4 -> 'a
(** [runtime ?loc fmt] raises a run-time {!exception-Error}. *)
