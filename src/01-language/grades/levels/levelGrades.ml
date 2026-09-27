type level = Low | High

(** The two-point lattice [Low < High]. *)
module LowHigh = struct
  type t = level

  let name = "security-levels"
  let bottom = Low
  let top = High
  let join l l' = match (l, l') with Low, Low -> Low | _ -> High
  let leq l l' = match (l, l') with High, Low -> false | _ -> true

  let of_lit = function
    | Grade.Name "Low" -> Low
    | Grade.Name "High" -> High
    | Grade.Name name as lit ->
        Grade.invalid_lit lit
          "unknown level '%s'; the levels are 'Low' and 'High'" name
    | lit ->
        Grade.invalid_lit lit "grades are the levels 'Low' and 'High', not %s"
          (Grade.describe_lit lit)

  let show = function Low -> "Low" | High -> "High"
end

module SecurityLevels = GradeConstructions.OfLattice (LowHigh)

module TimeLowerBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.LowerBound) (SecurityLevels)

  let name = "time-lower-bound-levels"
end

module TimeUpperBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.UpperBound) (SecurityLevels)

  let name = "time-upper-bound-levels"
end
