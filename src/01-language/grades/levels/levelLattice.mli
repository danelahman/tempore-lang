(** Finite lattices of named levels, declared by chains of covering edges such
    as [Public < Team < Confidential, Public < Partner < Confidential].

    The levels are numbered [0 .. n-1] along a linear extension of the order,
    ties broken by the order of first mention, so that the numbering is also a
    total order compatible with the lattice order. *)

type t
(** A finite lattice of named levels. *)

val default : t
(** The two-point lattice [Low < High]. *)

val of_chains :
  at:Utils.Location.t -> string Utils.Location.located list list -> t
(** [of_chains ~at chains] is the lattice whose covering edges are the
    consecutive levels of each of [chains], declared at [at]: the order is their
    reflexive-transitive closure (Warshall's algorithm), and the join of two
    levels the least of their upper bounds.

    @raise Utils.Error.Error
      a syntax error, checked in this order, if a level is not a capitalised
      name or occurs twice in a chain, if the order has a cycle, if there is no
      least level, or if two levels have no least upper bound; each names the
      levels concerned. *)

val size : t -> int
(** The number of levels. *)

val label : t -> int -> string
(** [label l i] is the name of the level [i]. *)

val index : t -> string -> int option
(** [index l name] is the level named [name], if any. *)

val leq : t -> int -> int -> bool
(** The order of the levels. *)

val join : t -> int -> int -> int
(** The least upper bound of two levels. *)

val bottom : t -> int
(** The least level. *)

val top : t -> int
(** The greatest level. *)

val elements : t -> int list
(** Every level, in increasing numbering. *)

val equal : t -> t -> bool
(** Whether two lattices have the same names and the same order, however their
    chains are written. *)

val declaration : t -> string
(** The chains as declared, e.g. ["Low < High"]. *)

val declared_at : t -> Utils.Location.t option
(** Where the lattice was declared; [None] for {!default}. *)

val levels_are : t -> string
(** A description of the levels for a diagnostic, after a semicolon:
    ["the levels are `Low` and `High`"]; with more than four levels, their
    number, the least and the greatest, as in
    ["the 7 levels range from `Public` to `Secret`"]. *)

val the_levels : t -> string
(** A description of the levels as a noun phrase:
    ["the levels `Low` and `High`"]; with more than four levels, as in
    ["the 7 levels from `Public` to `Secret`"]. *)
