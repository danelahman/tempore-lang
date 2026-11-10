(* The counts bounded by the time grades [C], name by name, delays counting
   nothing. *)
module Counts (C : Grade.S) =
  GradeConstructions.Untimed (GradeConstructions.Indexed.OfGrade (C))

module AtMost = struct
  include Counts (TimeGrades.UpperBound)

  let name = "at-most-counts"
end

module AtLeast = struct
  include Counts (TimeGrades.LowerBound)

  let name = "at-least-counts"
end
