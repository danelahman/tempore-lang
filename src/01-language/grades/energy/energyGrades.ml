module Energy = struct
  include GradeConstructions.Untimed (TimeGrades.UpperBound)

  let name = "energy"
end

module TimeUpperBoundEnergy = struct
  include GradeConstructions.Product (TimeGrades.UpperBound) (Energy)

  let name = "time-upper-bound-energy"
end
