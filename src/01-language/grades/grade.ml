include GradeLiteral

type running_time = Rational.t bound * Rational.t bound

type durations =
  | Duration_interval of Rational.t bound * Rational.t bound
  | Undetermined
  | Untimed

let end_value = function
  | Closed q | Open q -> q
  | Unbounded -> invalid_arg "Grade.end_value: an infinite end"

let map_end f = function
  | Closed q -> Closed (f q)
  | Open q -> Open (f q)
  | Unbounded -> Unbounded

let hull (lo, hi) = (end_value lo, end_value hi)

let add_ends b b' =
  match (b, b') with
  | Closed a, Closed a' -> Closed (Rational.add a a')
  | (Closed a | Open a), (Closed a' | Open a') -> Open (Rational.add a a')
  | Unbounded, _ | _, Unbounded -> Unbounded

let compare_ends ~lower b b' =
  let rank = function
    | Closed _ -> Bool.to_int (not lower)
    | _ -> Bool.to_int lower
  in
  match Rational.compare (end_value b) (end_value b') with
  | 0 -> Int.compare (rank b) (rank b')
  | c -> c

let close_running_time adjacent (lo, hi) =
  let close ~lower = function
    | Open q -> (
        match adjacent ~lower q with Some q' -> Closed q' | None -> Open q)
    | b -> b
  in
  (close ~lower:true lo, close ~lower:false hi)

let intersect_durations b b' =
  let upper hi hi' =
    match (hi, hi') with
    | Unbounded, hi | hi, Unbounded -> hi
    | _ -> if compare_ends ~lower:false hi hi' <= 0 then hi else hi'
  in
  match (b, b') with
  | Some (lo, hi), Some (lo', hi') ->
      Some
        ( (if compare_ends ~lower:true lo lo' >= 0 then lo else lo'),
          upper hi hi' )
  | Some b, None | None, Some b -> Some b
  | None, None -> None

type bounds = {
  running_time : string -> running_time;
  operations : string list;
}

type completeness = Delay.completeness = Complete | Partial

module type S = sig
  type t

  val name : string
  val one : t
  val mul : t -> t -> t
  val leq : bounds -> t -> t -> bool
  val leq_symbol : string
  val top : t
  val join : t -> t -> t

  module Delay : Delay.S

  val of_delay : Delay.t -> t
  val equal : bounds -> t -> t -> bool
  val is_top : bounds -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val counterexample : bounds -> t -> t -> t option
  val unit_least : bool
  val commutative : bool
  val needs_op_bounds : bool

  val duration_bounds :
    bounds -> t -> (Rational.t bound * Rational.t bound) option

  val inhabited : bounds -> t -> bool
  val events : t -> string list
  val of_lit : lit -> t
  val accepts : lit -> bool
  val of_bounds : Delay.t bound * Delay.t bound -> t
  val is_atomic : string -> t -> bool
  val show : t -> string
  val witnesses : degree:int -> bounds -> t list -> t list * completeness
end

let read_bound read q =
  match read (rational_lit q) with
  | Some d -> d
  | None -> invalid_arg ("Grade.read_bound: " ^ Rational.show q)

let fractional_tick q = invalid_lit (Rat q) "%s" (Delay.Nat.rejection (Rat q))

let tick_interval lo hi =
  let whole q =
    match Rational.to_int q with Some n -> n | None -> fractional_tick q
  in
  let a =
    match lo with Closed a -> whole a | Open a -> whole a + 1 | Unbounded -> 0
  in
  let b =
    match hi with
    | Closed b -> Some (whole b)
    | Open b -> Some (whole b - 1)
    | Unbounded -> None
  in
  match b with
  | Some b when b < a ->
      invalid_lit
        (Braces (Delays (lo, hi)))
        "the interval `%s` contains no whole number of time steps"
        (show_interval Rational.show lo hi)
  | b -> (a, b)

let tick_delays lo hi =
  match tick_interval lo hi with
  | a, None -> Seq (Tick a, Star (Tick 1))
  | a, Some b ->
      List.fold_left
        (fun r _ -> Seq (r, Union (Tick 0, Tick 1)))
        (Tick a)
        (List.init (b - a) Fun.id)

(* [negative_delay r] is a negative delay of the expression [r] of a brace
   literal, printed, if any: a negative number, or an interval atom whose lower
   endpoint is negative or infinite. *)
let rec negative_delay = function
  | Tick n when n < 0 -> Some (string_of_int n)
  | Frac q when Rational.sign q < 0 -> Some (Rational.show q)
  | Delays (((Closed a | Open a) as lo), hi) when Rational.sign a < 0 ->
      Some (show_interval Rational.show lo hi)
  | Delays ((Unbounded as lo), hi) -> Some (show_interval Rational.show lo hi)
  | Letter _ | Tick _ | Frac _ | Delays _ | Any -> None
  | Seq (r, s) | Union (r, s) | Inter (r, s) -> (
      match negative_delay r with Some d -> Some d | None -> negative_delay s)
  | Star r | Compl r | Strict r -> negative_delay r

let check_delays lit r =
  Option.iter
    (fun d -> invalid_lit lit "delays are non-negative, not %s" d)
    (negative_delay r)

let rec whole_delays ~names = function
  | Letter _ -> names
  | Tick _ | Any -> true
  | Frac _ -> false
  | Delays (lo, hi) -> (
      match tick_interval lo hi with
      | _ -> true
      | exception Invalid_literal _ -> false)
  | Seq (r, s) | Union (r, s) | Inter (r, s) ->
      whole_delays ~names r && whole_delays ~names s
  | Star r | Compl r | Strict r -> whole_delays ~names r

let whole_braces ~names r =
  Option.is_none (negative_delay r) && whole_delays ~names r

let rec positive = function
  | Letter _ | Tick _ | Frac _ | Delays _ | Any -> true
  | Seq (r, s) | Union (r, s) -> positive r && positive s
  | Star r -> positive r
  | Inter _ | Compl _ | Strict _ -> false

let sampled mul cs =
  (cs @ List.concat_map (fun c -> List.map (mul c) cs) cs, Partial)

let compare_array compare a b =
  let n = Array.length a in
  let rec from i =
    if i = n then 0
    else match compare a.(i) b.(i) with 0 -> from (i + 1) | c -> c
  in
  match Int.compare n (Array.length b) with 0 -> from 0 | c -> c
