(** Reachability in a finite graph.

    {2 Numbered graphs}

    The vertices of a numbered graph are [0, …, n-1], and its edges carry
    labels. A chain joining two vertices is the list of the labels of the edges
    of a path from the one to the other. *)

type 'e graph
(** A graph over numbered vertices with edges labelled by ['e]. *)

val graph : int -> (int * int * 'e) list -> 'e graph
(** [graph n edges] is the graph over the vertices [0, …, n-1] with the edges
    [(source, target, label)], in order. *)

val reached : 'e graph -> int list -> int -> bool
(** [reached g starts] is whether a vertex is reached from [starts] along the
    edges, the starts included. Applied to [g] and [starts] alone, the vertices
    reached are computed once, in time linear in the edges. *)

val chain : 'e graph -> int -> int -> 'e list option
(** [chain g i j] is the chain from [i] to [j] that the reflexive–transitive
    closure of Warshall's algorithm assigns to the pair, taking the vertices as
    pivots in increasing order: the empty chain when [i = j], the label of the
    first edge from [i] to [j] where there is one, and otherwise the chain to
    and from the least pivot through which the pair is joined. It is [None] when
    [j] is not reached from [i]. It is computed for the pair alone, without the
    closure. *)

(** {2 Strongly connected components} *)

val representatives :
  compare:('v -> 'v -> int) -> ('v * 'v) list -> 'v list -> 'v -> 'v option
(** [representatives ~compare edges order v] is the first vertex of [order]
    joined to [v] in both directions along [edges], [v] being joined to itself:
    the first of [order] in the strongly connected component of [v]. Vertices
    are compared by [compare]. Applied to [edges] and [order] alone, the
    components are computed once, in time linear in the edges up to the cost of
    the comparisons. *)

val collapse :
  compare:('v -> 'v -> int) ->
  preferred:('v -> bool) ->
  movable:('v -> bool) ->
  ('v * 'v) list ->
  ('v * 'v) list
(** [collapse ~compare ~preferred ~movable edges] is cycle elimination
    (Fähndrich, Foster, Su and Aiken, PLDI 1998): each [movable] vertex of a
    cycle of [edges], in increasing order, paired with the representative of its
    strongly connected component where that is another vertex. The
    representative is the first member of the component ({!representatives}) in
    the order: the [preferred] vertices, then those neither preferred nor
    movable, then the movable ones, each in increasing order. *)
