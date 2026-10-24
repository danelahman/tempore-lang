(** Grade lattices: finite lattices of named elements, declared by chains of
    covering edges such as
    [Public < Team < Confidential, Public < Partner < Confidential].

    The elements are numbered [0 .. n-1] along a linear extension of the order,
    ties broken by the order of first mention, so that the numbering is also a
    total order compatible with the lattice order. *)

type t
(** A finite lattice of named elements. *)

val default : t
(** The two-point lattice [Low < High]. *)

val of_chains :
  at:Utils.Location.t -> string Utils.Location.located list list -> t
(** [of_chains ~at chains] is the lattice whose covering edges are the
    consecutive elements of each of [chains], declared at [at]: the order is
    their reflexive-transitive closure (Warshall's algorithm), and the join of
    two elements the least of their upper bounds.

    @raise Utils.Error.Error
      a syntax error, checked in this order, if an element is not a capitalised
      name or occurs twice in a chain, if the order has a cycle, if there is no
      least element, or if two elements have no least upper bound; each names
      the elements concerned. *)

val size : t -> int
(** The number of elements. *)

val label : t -> int -> string
(** [label l i] is the name of the element [i]. *)

val index : t -> string -> int option
(** [index l name] is the element named [name], if any. *)

val leq : t -> int -> int -> bool
(** The order of the elements. *)

val join : t -> int -> int -> int
(** The least upper bound of two elements. *)

val bottom : t -> int
(** The least element. *)

val top : t -> int
(** The greatest element. *)

val elements : t -> int list
(** Every element, in increasing numbering. *)

val equal : t -> t -> bool
(** Whether two lattices have the same names and the same order, however their
    chains are written. *)

val declaration : t -> string
(** The chains as declared, e.g. ["Low < High"]. *)

val declared_at : t -> Utils.Location.t option
(** Where the lattice was declared; [None] for {!default}. *)

val its_elements : t -> string
(** A description of the elements for a diagnostic, after a semicolon:
    ["its elements are `Low` and `High`"]; with more than four elements, their
    number, the least and the greatest, as in
    ["its 7 elements range from `Public` to `Secret`"]. *)

val the_elements : t -> string
(** A description of the elements as a noun phrase:
    ["the elements `Low` and `High`"]; with more than four elements, as in
    ["the 7 elements from `Public` to `Secret`"]. *)
