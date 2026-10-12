module Rational = Grades.Rational
module Grade = Grades.Grade

let within (lo, hi) d =
  let above =
    match (lo : Rational.t Grade.bound) with
    | Closed q -> Rational.compare q d <= 0
    | Open q -> Rational.compare q d < 0
    | Unbounded -> true
  and below =
    match (hi : Rational.t Grade.bound) with
    | Closed q -> Rational.compare d q <= 0
    | Open q -> Rational.compare d q < 0
    | Unbounded -> true
  in
  above && below

type verdict = Timeline.verdict = Within | Outside | Unchecked | Unfinished

(* The bounds [\[0, ∞)] hold of every duration, and are not monitored. *)
let monitored = function
  | Some ((lo, hi) : Grade.running_time) -> (
      match (lo, hi) with
      | Closed q, Unbounded when Rational.sign q = 0 -> None
      | _ -> Some (lo, hi))
  | None -> None

let verdict bounds (call : Timeline.call) =
  match (monitored bounds, call.elapsed) with
  | _, None -> Unfinished
  | None, Some _ -> Unchecked
  | Some bounds, Some d -> if within bounds d then Within else Outside
