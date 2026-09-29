module Counts = GradeConstructions.Indexed.OfGrade (TimeGrades.UpperBound)

module Make (D : Delay.S) = struct
  include (
    Counts : Grade.S with type t = Counts.t and module Delay := Counts.Delay)

  module Delay = D

  let name = "counts-upper-bound"
  let of_delay _ = one
  let of_bounds _ = one
end

module UpperBound = Make (Delay.Nat)
