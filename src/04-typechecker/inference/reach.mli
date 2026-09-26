(** Reachability in a finite graph: the reflexive–transitive closure of a list
    of labelled edges over a list of vertices, by Warshall's algorithm.

    The closure holds, for each pair of vertices, perhaps a chain of edge labels
    joining them: the empty chain on the diagonal, a single edge where one joins
    them, and, for each vertex [k] in turn, the concatenation of a chain to [k]
    and one from [k] where no chain is known yet. The chain found is some chain,
    not necessarily a shortest one. Completeness is not claimed. *)

type ('v, 'e) t
(** The closure over vertices of type ['v] and edge labels of type ['e]. *)

val closure :
  equal:('v -> 'v -> bool) -> 'v list -> ('v * 'v * 'e) list -> ('v, 'e) t
(** [closure ~equal vertices edges] is the closure of the edges
    [(source, target, label)] over [vertices], vertices being compared by
    [equal]. Edges with an end outside [vertices] are never followed. *)

val reach : ('v, 'e) t -> 'v -> 'v -> 'e list option
(** [reach closure a b] is a chain of labels joining [a] to [b], if the closure
    has one; [None] also when [a] or [b] is not a vertex. *)

val on_cycle : ('v, 'e) t -> 'v -> bool
(** [on_cycle closure a] is whether another vertex is joined to [a] in both
    directions. *)

val representative :
  ('v, 'e) t -> 'v list -> 'v -> ('v * 'e list * 'e list) option
(** [representative closure order a] is the first vertex [r] of [order] joined
    to [a] in both directions, with the chains from [a] to [r] and from [r] to
    [a]. *)
