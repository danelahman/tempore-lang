module type S = sig
  type key
  type 'a t

  val create : int -> 'a t
  val find_opt : 'a t -> key -> 'a option
  val replace : 'a t -> key -> 'a -> unit
  val find_or_add : 'a t -> key -> (unit -> 'a) -> 'a
  val memoise : (key -> 'a) -> key -> 'a
end

(* The operations of a table, from its lookup and its addition of a key absent
   from it. *)
module Table (T : sig
  type key
  type 'a t

  val create : int -> 'a t
  val find_opt : 'a t -> key -> 'a option
  val add : 'a t -> key -> 'a -> unit
  val replace : 'a t -> key -> 'a -> unit
end) =
struct
  include T

  let find_or_add table key compute =
    match find_opt table key with
    | Some v -> v
    | None ->
        let v = compute () in
        add table key v;
        v

  let memoise f =
    let table = create 64 in
    fun key ->
      match find_opt table key with
      | Some v -> v
      | None ->
          let v = f key in
          add table key v;
          v
end

module Make (K : Hashtbl.HashedType) = Table (Hashtbl.Make (K))

module Ordered (K : Map.OrderedType) = Table (struct
  module M = Map.Make (K)

  type key = K.t
  type 'a t = 'a M.t ref

  let create _ = ref M.empty
  let find_opt table key = M.find_opt key !table
  let add table key v = table := M.add key v !table
  let replace = add
end)

module Weak (K : Hashtbl.HashedType) = Table (Ephemeron.K1.Make (K))

module Weak2 (K1 : Hashtbl.HashedType) (K2 : Hashtbl.HashedType) =
  Table (Ephemeron.K2.Make (K1) (K2))

module Ints = Make (Int)

module Pairs = Make (struct
  type t = int * int

  let equal (i, j) (i', j') = Int.equal i i' && Int.equal j j'
  let hash (i, j) = Hashing.combine i j
end)

module Triples = Make (struct
  type t = int * int * int

  let equal (i, j, k) (i', j', k') =
    Int.equal i i' && Int.equal j j' && Int.equal k k'

  let hash (i, j, k) = Hashing.combine (Hashing.combine i j) k
end)
