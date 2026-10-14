open Grade

type t = Rational.t bound * Rational.t bound

let point q = (Closed q, Closed q)
let zero = point Rational.zero
let unbounded = (Closed Rational.zero, Unbounded)

let is_zero = function
  | Closed q, Closed q' -> Rational.sign q = 0 && Rational.sign q' = 0
  | _ -> false

let add (lo, hi) (lo', hi') = (add_ends lo lo', add_ends hi hi')

(* [compare_upper b b'] orders upper ends by the sets they bound, the infinite
   end last. *)
let compare_upper b b' =
  match (b, b') with
  | Unbounded, Unbounded -> 0
  | Unbounded, _ -> 1
  | _, Unbounded -> -1
  | _ -> compare_ends ~lower:false b b'

let hull (lo, hi) (lo', hi') =
  ( (if compare_ends ~lower:true lo lo' <= 0 then lo else lo'),
    if compare_upper hi hi' >= 0 then hi else hi' )

let subset (lo, hi) (lo', hi') =
  compare_ends ~lower:true lo' lo <= 0 && compare_upper hi hi' <= 0

let inter (lo, hi) (lo', hi') =
  let lo = if compare_ends ~lower:true lo lo' >= 0 then lo else lo' in
  let hi = if compare_upper hi hi' <= 0 then hi else hi' in
  match emptiness lo hi with None -> Some (lo, hi) | Some _ -> None

let meets i j = Option.is_some (inter i j)
let from (lo, _) = (lo, Unbounded)
let upto (_, hi) = (Closed Rational.zero, hi)

let closure (lo, hi) =
  let close = function Open q -> Closed q | b -> b in
  (close lo, close hi)

let compare_bound b b' =
  match (b, b') with
  | Closed q, Closed q' | Open q, Open q' -> Rational.compare q q'
  | Unbounded, Unbounded -> 0
  | Closed _, _ -> -1
  | _, Closed _ -> 1
  | Open _, _ -> -1
  | _, Open _ -> 1

let compare (lo, hi) (lo', hi') =
  match compare_bound lo lo' with 0 -> compare_bound hi hi' | c -> c

let hash_bound = function
  | Closed q -> Hashing.combine 1 (Rational.hash q)
  | Open q -> Hashing.combine 2 (Rational.hash q)
  | Unbounded -> 3

let hash (lo, hi) = Hashing.combine (hash_bound lo) (hash_bound hi)
let show (lo, hi) = show_interval Rational.show lo hi

let show_point = function
  | Closed q, Closed q' when Rational.equal q q' -> Rational.show q
  | i -> show i

(* The running times of no operation, for the orders that read none. *)
let no_bounds =
  {
    running_time =
      (fun op -> invalid_arg ("DurationIntervals: the operation " ^ op));
    operations = [];
  }

let of_lit lit =
  match open_pair lit with
  | Int _ | Rat _ -> (
      match Delay.Rational.read lit with
      | Some q -> point q
      | None -> invalid_lit lit "durations are non-negative")
  | Interval _ as interval -> (
      match
        RationalTimeGrades.Interval.duration_bounds no_bounds
          (RationalTimeGrades.Interval.of_lit interval)
      with
      | Some i -> i
      | None -> invalid_arg "DurationIntervals.of_lit")
  | lit ->
      invalid_lit lit
        "durations are non-negative numbers or intervals %s, not %s"
        interval_forms (describe_lit lit)
