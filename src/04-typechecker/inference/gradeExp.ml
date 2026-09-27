(* Open grade expressions. *)

module type VAR = sig
  include Utils.Symbol.S

  val fresh_indexed : unit -> t
  val equal : t -> t -> bool

  module Map : Map.S with type key = t
  module Set : Set.S with type elt = t
end

(* The subscript digits of a non-negative integer. *)
let subscript n =
  let digits = [| "₀"; "₁"; "₂"; "₃"; "₄"; "₅"; "₆"; "₇"; "₈"; "₉" |] in
  String.concat ""
    (List.map
       (fun d -> digits.(Char.code d - Char.code '0'))
       (List.of_seq (String.to_seq (string_of_int n))))

module Make_var
    (Letter : sig
      val letter : string
    end)
    () : VAR = struct
  include Utils.Symbol.Make ()

  (* The supply of subscripts. *)
  let next = Atomic.make 0

  let fresh_indexed () =
    fresh (Letter.letter ^ subscript (Atomic.fetch_and_add next 1))

  let equal x y = compare x y = 0

  module Ordered = struct
    type nonrec t = t

    let compare = compare
  end

  module Map = Stdlib.Map.Make (Ordered)
  module Set = Stdlib.Set.Make (Ordered)
end

module Rho_var =
  Make_var
    (struct
      let letter = "ρ"
    end)
    ()

module Eps_var =
  Make_var
    (struct
      let letter = "ε"
    end)
    ()

module type S = sig
  module GS : Grades.GradeSystem.S
  module Rho_var = Rho_var
  module Eps_var = Eps_var

  type eps =
    | Eps_var of Eps_var.t
    | Eps_const of GS.E.t
    | Eps_mul of eps * eps
    | Eps_join of eps * eps

  type rho =
    | Rho_var of Rho_var.t
    | Rho_const of GS.R.t
    | Rho_mul of rho * rho
    | Rho_join of rho * rho
    | Rho_map of eps

  type subst = { rho_subst : rho Rho_var.Map.t; eps_subst : eps Eps_var.Map.t }

  val empty_subst : subst

  module Eps : sig
    type t = eps

    val var : Eps_var.t -> t
    val const : GS.E.t -> t
    val unit : t
    val top : t
    val of_nat : int -> t
    val mul : t -> t -> t
    val join : t -> t -> t
    val free_vars : t -> Eps_var.Set.t
    val mem_var : Eps_var.t -> t -> bool
    val subst : subst -> t -> t
    val value : t -> GS.E.t option
    val equal : Grades.Grade.bounds -> t -> t -> bool
    val print : t -> Format.formatter -> unit
    val to_string : t -> string
  end

  module Rho : sig
    type t = rho

    val var : Rho_var.t -> t
    val const : GS.R.t -> t
    val unit : t
    val top : t
    val of_nat : int -> t
    val mul : t -> t -> t
    val join : t -> t -> t
    val map : eps -> t
    val free_rho_vars : t -> Rho_var.Set.t
    val free_eps_vars : t -> Eps_var.Set.t
    val mem_rho_var : Rho_var.t -> t -> bool
    val mem_eps_var : Eps_var.t -> t -> bool
    val subst : subst -> t -> t
    val value : t -> GS.R.t option
    val equal : Grades.Grade.bounds -> t -> t -> bool
    val print : t -> Format.formatter -> unit
    val to_string : t -> string
  end
end

(* [lift2 f x y] is [f] applied under the options [x] and [y]. *)
let lift2 f x y = match (x, y) with Some x, Some y -> Some (f x y) | _ -> None

(* [paren wrap body ppf] prints [body], in parentheses when [wrap]. *)
let paren wrap body ppf =
  if wrap then Format.fprintf ppf "(%t)" body else body ppf

(* Precedence levels: the operands of a join are printed at [join_level], those
   of a product at [mul_level], so that a join under a product is
   parenthesised. *)
let join_level = 0
let mul_level = 1

module Make (GS : Grades.GradeSystem.S) = struct
  module GS = GS
  module Rho_var = Rho_var
  module Eps_var = Eps_var

  type eps =
    | Eps_var of Eps_var.t
    | Eps_const of GS.E.t
    | Eps_mul of eps * eps
    | Eps_join of eps * eps

  type rho =
    | Rho_var of Rho_var.t
    | Rho_const of GS.R.t
    | Rho_mul of rho * rho
    | Rho_join of rho * rho
    | Rho_map of eps

  type subst = { rho_subst : rho Rho_var.Map.t; eps_subst : eps Eps_var.Map.t }

  let empty_subst =
    { rho_subst = Rho_var.Map.empty; eps_subst = Eps_var.Map.empty }

  module Eps = struct
    type t = eps

    let var eps_var = Eps_var eps_var
    let const c = Eps_const c
    let unit = Eps_const GS.E.one
    let top = Eps_const GS.E.top
    let of_nat n = Eps_const (GS.E.of_nat n)
    let mul eps eps' = Eps_mul (eps, eps')
    let join eps eps' = Eps_join (eps, eps')

    let rec free_vars = function
      | Eps_var eps_var -> Eps_var.Set.singleton eps_var
      | Eps_const _ -> Eps_var.Set.empty
      | Eps_mul (eps, eps') | Eps_join (eps, eps') ->
          Eps_var.Set.union (free_vars eps) (free_vars eps')

    let rec mem_var k = function
      | Eps_var eps_var -> Eps_var.equal k eps_var
      | Eps_const _ -> false
      | Eps_mul (eps, eps') | Eps_join (eps, eps') ->
          mem_var k eps || mem_var k eps'

    let rec subst sigma = function
      | Eps_var eps_var as eps ->
          Option.value ~default:eps
            (Eps_var.Map.find_opt eps_var sigma.eps_subst)
      | Eps_const _ as eps -> eps
      | Eps_mul (eps, eps') -> Eps_mul (subst sigma eps, subst sigma eps')
      | Eps_join (eps, eps') -> Eps_join (subst sigma eps, subst sigma eps')

    let rec value = function
      | Eps_var _ -> None
      | Eps_const c -> Some c
      | Eps_mul (eps, eps') -> lift2 GS.E.mul (value eps) (value eps')
      | Eps_join (eps, eps') -> lift2 GS.E.join (value eps) (value eps')

    let rec equal bounds eps eps' =
      match (eps, eps') with
      | Eps_var x, Eps_var y -> Eps_var.equal x y
      | Eps_const c, Eps_const d -> GS.E.equal bounds c d
      | Eps_mul (e1, e2), Eps_mul (e1', e2')
      | Eps_join (e1, e2), Eps_join (e1', e2') ->
          equal bounds e1 e1' && equal bounds e2 e2'
      | (Eps_var _ | Eps_const _ | Eps_mul _ | Eps_join _), _ -> false

    let rec print_at level eps ppf =
      match eps with
      | Eps_var eps_var -> Eps_var.print eps_var ppf
      | Eps_const c -> Format.pp_print_string ppf (GS.E.show c)
      | Eps_mul (eps, eps') ->
          paren (level > mul_level)
            (fun ppf ->
              Format.fprintf ppf "%t · %t" (print_at mul_level eps)
                (print_at mul_level eps'))
            ppf
      | Eps_join (eps, eps') ->
          paren (level > join_level)
            (fun ppf ->
              Format.fprintf ppf "%t ⊔ %t" (print_at join_level eps)
                (print_at join_level eps'))
            ppf

    let print eps ppf = print_at join_level eps ppf
    let to_string eps = Format.asprintf "%t" (print eps)
  end

  module Rho = struct
    type t = rho

    let var rho_var = Rho_var rho_var
    let const c = Rho_const c
    let unit = Rho_const GS.R.one
    let top = Rho_const GS.R.top
    let of_nat n = Rho_const (GS.R.of_nat n)
    let mul rho rho' = Rho_mul (rho, rho')
    let join rho rho' = Rho_join (rho, rho')

    let map = function
      | Eps_const c -> Rho_const (GS.map c)
      | (Eps_var _ | Eps_mul _ | Eps_join _) as eps -> Rho_map eps

    let rec free_rho_vars = function
      | Rho_var rho_var -> Rho_var.Set.singleton rho_var
      | Rho_const _ | Rho_map _ -> Rho_var.Set.empty
      | Rho_mul (rho, rho') | Rho_join (rho, rho') ->
          Rho_var.Set.union (free_rho_vars rho) (free_rho_vars rho')

    let rec free_eps_vars = function
      | Rho_var _ | Rho_const _ -> Eps_var.Set.empty
      | Rho_map eps -> Eps.free_vars eps
      | Rho_mul (rho, rho') | Rho_join (rho, rho') ->
          Eps_var.Set.union (free_eps_vars rho) (free_eps_vars rho')

    let rec mem_rho_var k = function
      | Rho_var rho_var -> Rho_var.equal k rho_var
      | Rho_const _ | Rho_map _ -> false
      | Rho_mul (rho, rho') | Rho_join (rho, rho') ->
          mem_rho_var k rho || mem_rho_var k rho'

    let rec mem_eps_var k = function
      | Rho_var _ | Rho_const _ -> false
      | Rho_map eps -> Eps.mem_var k eps
      | Rho_mul (rho, rho') | Rho_join (rho, rho') ->
          mem_eps_var k rho || mem_eps_var k rho'

    let rec subst sigma = function
      | Rho_var rho_var as rho ->
          Option.value ~default:rho
            (Rho_var.Map.find_opt rho_var sigma.rho_subst)
      | Rho_const _ as rho -> rho
      | Rho_mul (rho, rho') -> Rho_mul (subst sigma rho, subst sigma rho')
      | Rho_join (rho, rho') -> Rho_join (subst sigma rho, subst sigma rho')
      | Rho_map eps -> Rho_map (Eps.subst sigma eps)

    let rec value = function
      | Rho_var _ -> None
      | Rho_const c -> Some c
      | Rho_mul (rho, rho') -> lift2 GS.R.mul (value rho) (value rho')
      | Rho_join (rho, rho') -> lift2 GS.R.join (value rho) (value rho')
      | Rho_map eps -> Option.map GS.map (Eps.value eps)

    let rec equal bounds rho rho' =
      match (rho, rho') with
      | Rho_var x, Rho_var y -> Rho_var.equal x y
      | Rho_const c, Rho_const d -> GS.R.equal bounds c d
      | Rho_mul (r1, r2), Rho_mul (r1', r2')
      | Rho_join (r1, r2), Rho_join (r1', r2') ->
          equal bounds r1 r1' && equal bounds r2 r2'
      | Rho_map eps, Rho_map eps' -> Eps.equal bounds eps eps'
      | (Rho_var _ | Rho_const _ | Rho_mul _ | Rho_join _ | Rho_map _), _ ->
          false

    let rec print_at level rho ppf =
      match rho with
      | Rho_var rho_var -> Rho_var.print rho_var ppf
      | Rho_const c -> Format.pp_print_string ppf (GS.R.show c)
      | Rho_map eps -> Format.fprintf ppf "∣%t∣" (Eps.print eps)
      | Rho_mul (rho, rho') ->
          paren (level > mul_level)
            (fun ppf ->
              Format.fprintf ppf "%t · %t" (print_at mul_level rho)
                (print_at mul_level rho'))
            ppf
      | Rho_join (rho, rho') ->
          paren (level > join_level)
            (fun ppf ->
              Format.fprintf ppf "%t ⊔ %t" (print_at join_level rho)
                (print_at join_level rho'))
            ppf

    let print rho ppf = print_at join_level rho ppf
    let to_string rho = Format.asprintf "%t" (print rho)
  end
end
