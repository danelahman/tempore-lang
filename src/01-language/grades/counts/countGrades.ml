module UpperBound = struct
  include GradeConstructions.Indexed.OfGrade (TimeGrades.UpperBound)

  let name = "counts-upper-bound"

  let of_nat n =
    let (_ : int) = Grade.check_nat "CountGrades.UpperBound" n in
    one

  let of_bounds _ = one
end
