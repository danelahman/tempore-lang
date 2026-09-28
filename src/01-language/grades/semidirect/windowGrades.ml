module R = SymbolicRegex

(** The set of all natural numbers, the words of ticks. *)
let naturals = R.star (R.ticks 1)

(** [interval lo hi] is the set of the numbers from [lo] to [hi]. *)
let interval lo hi =
  R.concat (R.ticks lo) (R.union (List.init (hi - lo + 1) R.ticks))

(** [from lo] is the set of the numbers from [lo] on. *)
let from lo = R.concat (R.ticks lo) naturals

(** [of_braces lit r] is the set of the numbers the brace literal [lit] with
    expression [r] denotes, over the letter [tick] alone: [_] is a single tick
    and a complement is taken within the natural numbers.

    @raise Grade.Invalid_literal if [r] names an operation. *)
let of_braces lit r =
  let rec go = function
    | Grade.Letter name ->
        Grade.invalid_lit lit
          "time windows are sets of numbers of ticks, and name no operation \
           such as '%s'"
          name
    | Grade.Tick n -> R.ticks n
    | Grade.Any -> R.ticks 1
    | Grade.Seq (r, s) -> R.concat (go r) (go s)
    | Grade.Union (r, s) -> R.union [ go r; go s ]
    | Grade.Inter (r, s) -> R.inter [ go r; go s ]
    | Grade.Star r -> R.star (go r)
    | Grade.Compl r -> R.inter [ R.compl (go r); naturals ]
  in
  go r

(** [least rho] is the least number in the non-empty set [rho]. *)
let least rho = Option.fold ~none:0 ~some:List.length (R.shortest rho)

(** [bounded_by] is the greatest upper end of the intervals [show] looks for. *)
let bounded_by = 64

module Durations = struct
  type t = R.t

  let name = "durations"
  let one = R.eps
  let mul = R.concat
  let leq _bounds = R.subset
  let leq_symbol = "<="
  let top = naturals
  let join rho rho' = R.union [ rho; rho' ]
  let of_nat n = R.ticks (Grade.check_nat "WindowGrades.Durations" n)
  let equal _bounds = R.equal
  let is_top _bounds = R.subset top
  let compare = R.compare_form
  let hash = R.hash
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let events _ = []

  let of_lit = function
    | Grade.Top -> top
    | Grade.Int n when n < 0 ->
        Grade.invalid_lit (Grade.Int n) "durations must be non-negative"
    | Grade.Int n -> R.ticks n
    | Grade.Tuple [ Grade.Int n; _ ] as lit when n < 0 ->
        Grade.invalid_lit lit "durations must be non-negative"
    | Grade.Tuple [ Grade.Int n; Grade.Int m ] as lit when m < n ->
        Grade.invalid_lit lit "interval endpoints must satisfy n <= m"
    | Grade.Tuple [ Grade.Int n; Grade.Int m ] -> interval n m
    | Grade.Tuple [ Grade.Int n; Grade.Inf ] -> from n
    | Grade.Braces r as lit ->
        let rho = of_braces lit r in
        if R.is_empty rho then
          Grade.invalid_lit lit "this set of durations is empty"
        else rho
    | lit ->
        Grade.invalid_lit lit
          "durations are plain integers, intervals '(n, m)' or brace literals \
           '{...}', not %s"
          (Grade.describe_lit lit)

  let of_bounds (lo, hi) = interval lo hi
  let is_atomic _name _ = true

  (* The upper end of an interval from [lo] containing [rho], if it is at
     most [bounded_by]. *)
  let upper_end lo rho =
    List.find_opt
      (fun hi -> R.subset rho (interval lo hi))
      (List.init (Int.max 0 (bounded_by - lo + 1)) (( + ) lo))

  let show rho =
    let lo = least rho in
    if R.equal rho (R.ticks lo) then string_of_int lo
    else if R.equal rho (from lo) then Printf.sprintf "(%d,∞)" lo
    else
      match upper_end lo rho with
      | Some hi when R.equal rho (interval lo hi) ->
          Printf.sprintf "(%d,%d)" lo hi
      | Some _ | None -> RegularTraceGradeDerivative.show rho

  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

module Times = struct
  type t = R.t

  let name = "times"
  let bottom = R.empty
  let top = naturals
  let join rho rho' = R.union [ rho; rho' ]
  let leq = R.subset
  let compare = R.compare_form
  let hash = R.hash

  let of_lit = function
    | Grade.Braces r as lit -> of_braces lit r
    | lit ->
        Grade.invalid_lit lit "times are brace literals '{...}', not %s"
          (Grade.describe_lit lit)

  let show = RegularTraceGradeDerivative.show
end

module Shift = struct
  type m = R.t
  type n = R.t

  let act = R.concat
end

module Indexed = GradeConstructions.Indexed
module TimesByName = Indexed.OfSemilattice (Times)
module ShiftByName = Indexed.Action (Times) (Shift)

module TimeWindows = struct
  include GradeConstructions.SemiDirect (Durations) (TimesByName) (ShiftByName)

  let name = "time-windows"

  (* The literals of entries [(Name, ...)], the times of an operation. *)
  let is_entry = function
    | Grade.Tuple (Grade.Name _ :: _ :: _) -> true
    | _ -> false

  let of_lit = function
    | Grade.Top -> top
    | lit -> (
        match Durations.of_lit lit with
        | durations -> (durations, TimesByName.bottom)
        | exception (Grade.Invalid_literal _ as rejection) -> (
            match lit with
            | Grade.Tuple (durations :: (_ :: _ as entries))
              when List.for_all is_entry entries ->
                ( Grade.component_of_lit lit ~context:"in the durations, "
                    Durations.of_lit durations,
                  Indexed.of_entries_lit ~compare:Times.compare
                    ~default:Times.bottom Times.of_lit lit entries )
            | Grade.Tuple [ _; Grade.Braces _ ] ->
                Grade.invalid_lit lit
                  "times are given by operation, e.g. '(1, (Send, {0}))' for \
                   'Send' at the start, or '(1, (_, {0}))' for any operation"
            | _ -> raise rejection))

  let show ((durations, times) as c) =
    if compare c top = 0 then "⊤"
    else if TimesByName.leq times TimesByName.bottom then
      Durations.show durations
    else
      "(" ^ Durations.show durations ^ ","
      ^ Indexed.show_entries
          ~is_default:(fun e -> Times.leq e Times.bottom)
          Times.show times
      ^ ")"
end
