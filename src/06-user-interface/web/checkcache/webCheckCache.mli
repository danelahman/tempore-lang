(** The last successful check of the program in the web interface, reused while
    every input of the check is unchanged. *)

type key = {
  source : string;  (** the program in the editor *)
  grades : string;  (** the name of the grades selected *)
  use_stdlib : bool;  (** whether the standard library is loaded *)
  declared : BackendRegistry.source list;
      (** the declarations the selected backend loads before the program *)
}
(** The inputs of a check, compared by structural equality. *)

type 'a t
(** At most one outcome of a successful check, under its key. *)

val empty : 'a t
(** The cache without an entry. *)

val find : 'a t -> key -> 'a option
(** [find cache key] is the entry of [cache] if it is under [key]. *)

val checked :
  'a t -> key -> (unit -> ('a, 'e) result) -> ('a, 'e) result * bool * 'a t
(** [checked cache key check] is the entry of [cache] under [key], [true] and
    [cache], if there is one; otherwise the outcome [r] of [check ()], [false]
    and, where [r] is [Ok v], the cache holding [v] under [key] alone, else
    [cache]. *)
