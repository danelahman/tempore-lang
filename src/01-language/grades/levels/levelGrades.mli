(** The security-level grades and their products with the time grades.

    The level of a computation is the highest level it touches; a box at level
    [ℓ] may be unboxed only while the level has not risen above [ℓ] since it was
    boxed. Ticks touch no level. *)

(** The two security levels, [Low < High], written [Low] and [High]. *)
type level = Low | High

module SecurityLevels : Grade.S with type t = level
(** The two-point lattice [Low < High] as a grade, ["security-levels"] (see
    {!GradeConstructions.OfLattice}); [⊤] is [High]. *)

module TimeLowerBoundLevels :
  Grade.S with type t = TimeGrades.LowerBound.t * level
(** The product of [time-lower-bound] and [security-levels],
    ["time-lower-bound-levels"]: [(n, ℓ)] is "at least [n] time steps, touching
    nothing above [ℓ]", an embargo with a taint check. *)

module TimeUpperBoundLevels :
  Grade.S with type t = TimeGrades.UpperBound.t * level
(** The product of [time-upper-bound] and [security-levels],
    ["time-upper-bound-levels"]: [(n, ℓ)] is "at most [n] time steps, touching
    nothing above [ℓ]", an expiring untainted capability. *)
