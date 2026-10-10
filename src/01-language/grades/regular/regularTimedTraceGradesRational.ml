open Grade
module A = DelayAutomaton
module Closure = DelayTimedClosure

(* [extremum b] is the extremal value of the finite end [b] of running-time
   bounds, attained iff [b] is closed. *)
let extremum = function
  | Closed q -> DelaySet.Finite (q, true)
  | Open q -> DelaySet.Finite (q, false)
  | Unbounded -> DelaySet.Infinite

(* [end_of_extremum (q, attained)] is the end of running-time bounds of value
   [q], closed iff [attained]. *)
let end_of_extremum (q, attained) = if attained then Closed q else Open q

(* The decisions of the orders on the grades [t]: whether every trace of the
   lesser grade is in the closure of the greater one, a trace outside it, the
   extremal weights of the traces of a grade and its inhabitation, over the
   operations of a world. *)
module type DECISIONS = sig
  type t

  val in_allowance : Closure.world -> t -> t -> bool
  val in_coverage : Closure.world -> t -> t -> bool
  val allowance : Closure.world -> t -> t -> A.symbol list option
  val coverage : Closure.world -> t -> t -> A.symbol list option
  val min_weight : Closure.world -> t -> (Rational.t * bool) option
  val max_weight : Closure.world -> t -> (Rational.t * bool) option
  val inhabited : Closure.world -> t -> bool
end

(* The decisions on the canonical automata of the grades, a verdict being that
   the search finds no word. *)
module ByAutomata = struct
  module L = RegularTraceGradeRational.Automata

  type t = L.t

  let on decide world rho rho' =
    decide world (L.automaton rho) (L.automaton rho')

  let allowance = on Closure.allowance
  let coverage = on Closure.coverage
  let in_allowance world rho rho' = Option.is_none (allowance world rho rho')
  let in_coverage world rho rho' = Option.is_none (coverage world rho rho')
  let min_weight world rho = Closure.min_weight world (L.automaton rho)
  let max_weight world rho = Closure.max_weight world (L.automaton rho)
  let inhabited world rho = Closure.inhabited world (L.automaton rho)
end

(* The decisions on the graphs of the gap derivatives of the expressions of the
   grades in normal form ({!GapGraph}), over the names of the world. *)
module ByGaps = struct
  module L = RegularTraceGradeRational

  type t = L.t

  (* Tables by lists of names and normal forms. *)
  module Graphs = Hashtbl.Make (struct
    type t = string list * RationalRegex.t

    let equal (names, r) (names', r') =
      List.equal String.equal names names' && RationalRegex.equal_form r r'

    let hash (names, r) =
      Grade.combine (Grade.hash_list String.hash names) (RationalRegex.hash r)
  end)

  (* [graph names rho] is {!RationalRegex.graph}, tabulated by its arguments. *)
  let graph =
    let table = Graphs.create 16 in
    fun names rho ->
      let key = (names, L.form rho) in
      match Graphs.find_opt table key with
      | Some g -> g
      | None ->
          let g = RationalRegex.graph names (L.form rho) in
          Graphs.add table key g;
          g

  let names world = List.map fst world
  let on decide world rho = decide world (graph (names world) rho)

  let on_pair decide world rho rho' =
    decide world (graph (names world) rho) (graph (names world) rho')

  (* The verdicts and searches decided, by the world and the grades. *)
  module Comparisons = Hashtbl.Make (struct
    type t = Closure.world * int * int

    let equal (w, i, j) (w', i', j') =
      Int.equal i i' && Int.equal j j'
      && List.equal
           (fun (n, c) (n', c') ->
             String.equal n n' && DelaySet.equal_extremum c c')
           w w'

    let hash (w, i, j) =
      combine
        (hash_list
           (fun (n, c) -> combine (String.hash n) (DelaySet.hash_extremum c))
           w)
        (combine i j)
  end)

  (* [tabulated f] is [f], its results tabulated by its arguments in a table of
     its own. *)
  let tabulated f =
    let table = Comparisons.create 64 in
    fun world rho rho' ->
      let key =
        ( world,
          RationalRegex.hash (L.form rho),
          RationalRegex.hash (L.form rho') )
      in
      match Comparisons.find_opt table key with
      | Some r -> r
      | None ->
          let r = f world rho rho' in
          Comparisons.add table key r;
          r

  let in_allowance = tabulated (on_pair Closure.Graph.in_allowance)
  let in_coverage = tabulated (on_pair Closure.Graph.in_coverage)
  let allowance = tabulated (on_pair Closure.Graph.allowance)
  let coverage = tabulated (on_pair Closure.Graph.coverage)
  let min_weight = on Closure.Graph.min_weight
  let max_weight = on Closure.Graph.max_weight
  let inhabited world rho = Closure.Graph.inhabited (graph (names world) rho)
end

(* The grades over the languages [L], decided by [D], their names ending in
   [N.suffix]. *)
module Make
    (L : Grade.S with type Delay.t = Delay.Rational.t)
    (D : DECISIONS with type t = L.t)
    (N : sig
      val suffix : string
    end) =
struct
  (* [world endpoint bounds rhos] is the operations of a comparison of the
     grades [rhos], each with the extremal value of the [endpoint] of its
     running-time bounds as its running time: the names [rhos] mention, and of
     the other declared operations, which [rhos] do not tell apart, the least
     name of each running time. *)
  let world endpoint bounds rhos =
    let mentioned =
      List.sort_uniq String.compare (List.concat_map L.events rhos)
    in
    let running_time name = extremum (endpoint (bounds.running_time name)) in
    let others =
      List.filter
        (fun name -> not (List.mem name mentioned))
        (List.sort_uniq String.compare bounds.operations)
    in
    let representatives =
      List.fold_left
        (fun reps name ->
          let c = running_time name in
          if List.exists (fun (_, c') -> DelaySet.equal_extremum c c') reps then
            reps
          else (name, c) :: reps)
        [] others
    in
    List.sort
      (fun (n, _) (n', _) -> String.compare n n')
      (List.map (fun name -> (name, running_time name)) mentioned
      @ representatives)

  type order = {
    holds : Closure.world -> L.t -> L.t -> bool;
    search : Closure.world -> L.t -> L.t -> A.symbol list option;
    endpoint : running_time -> Rational.t bound;
    top : L.t;
  }
  (* An order on traces: whether every trace of the lesser grade is in the
     closure of the greater one, the search for a trace outside it, the end of
     the running-time bounds it reads as the running time of an operation, and
     the representation of its greatest grade. *)

  let allowance =
    {
      holds = D.in_allowance;
      search = D.allowance;
      endpoint = snd;
      top = L.top;
    }

  let coverage =
    { holds = D.in_coverage; search = D.coverage; endpoint = fst; top = L.one }

  (* [trivial order rho rho'] is whether [rho ≾ rho'] holds by the
     representations: [rho] and [rho'] are the same language or [rho'] is the
     top. *)
  let trivial order rho rho' =
    L.compare rho rho' = 0 || L.compare rho' order.top = 0

  (* [compared order bounds decide rho rho'] is [decide] over the world of a
     comparison of [rho] with [rho']. *)
  let compared order bounds decide rho rho' =
    decide (world order.endpoint bounds [ rho; rho' ]) rho rho'

  let leq order bounds rho rho' =
    trivial order rho rho' || compared order bounds order.holds rho rho'

  let is_top order bounds rho =
    L.compare rho order.top = 0 || leq order bounds order.top rho

  let counterexample order bounds rho rho' =
    if trivial order rho rho' then None
    else
      Option.map
        (fun word -> L.of_lit (Braces (DelayRegex.of_word word)))
        (compared order bounds order.search rho rho')

  let inhabited bounds rho =
    D.inhabited (world (Fun.const (Closed Rational.zero)) bounds [ rho ]) rho

  let implied_bounds bounds lower upper =
    match
      ( D.min_weight (world fst bounds [ lower ]) lower,
        D.max_weight (world snd bounds [ upper ]) upper )
    with
    | Some fastest, Some slowest ->
        Some (end_of_extremum fastest, end_of_extremum slowest)
    | _ -> None

  (* [lower_shadow lo] is the lower time shadow of the lower end [lo] of
     running-time bounds: [{lo}] if it is closed, and [{(lo, ∞)}], covered by
     the traces longer than [lo], if it is open. *)
  let lower_shadow = function
    | Open q -> L.of_lit (Braces (Delays (Open q, Unbounded)))
    | lo -> L.of_delay (end_value lo)

  (* [upper_shadow hi] is the upper time shadow of the upper end [hi] of
     running-time bounds: [{hi}] if it is closed, and [{[0, hi)}], permitting
     the traces shorter than [hi], if it is open. *)
  let upper_shadow = function
    | Open q -> L.of_lit (Braces (Delays (Closed Rational.zero, Open q)))
    | hi -> L.of_delay (end_value hi)

  (* The fields the grades share with the regular trace grade over rational
     delays. *)
  module Common = struct
    type t = L.t

    module Delay = L.Delay

    let one = L.one
    let mul = L.mul
    let join = L.join
    let of_delay = L.of_delay
    let leq_symbol = "<="
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds rho = implied_bounds bounds rho rho
    let inhabited = inhabited
    let events = L.events
    let compare = L.compare
    let hash = L.hash
    let is_atomic = L.is_atomic
    let show = L.show
    let witnesses = L.witnesses
  end

  module Lower = struct
    include Common

    let name = "regex-timed-lower-bound-rational" ^ N.suffix
    let leq = leq coverage
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample coverage
    let top = coverage.top
    let is_top = is_top coverage
    let unit_least = false
    let of_lit = function Top -> top | lit -> L.of_lit lit
    let of_bounds (lo, _hi) = lower_shadow lo
  end

  module Upper = struct
    include Common

    let name = "regex-timed-upper-bound-rational" ^ N.suffix
    let leq = leq allowance
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample allowance
    let top = allowance.top
    let is_top = is_top allowance
    let unit_least = true
    let of_lit = L.of_lit
    let of_bounds (_lo, hi) = upper_shadow hi
  end

  module Interval = struct
    type t = L.t * L.t

    module Delay = L.Delay

    let name = "regex-timed-interval-rational" ^ N.suffix
    let one = (Lower.one, Upper.one)
    let mul (lo, hi) (lo', hi') = (L.mul lo lo', L.mul hi hi')

    let leq bounds (lo, hi) (lo', hi') =
      Lower.leq bounds lo lo' && Upper.leq bounds hi hi'

    let leq_symbol = "<="
    let top = (Lower.top, Upper.top)
    let join (lo, hi) (lo', hi') = (L.join lo lo', L.join hi hi')
    let equal bounds p q = leq bounds p q && leq bounds q p

    let is_top bounds (lo, hi) =
      Lower.is_top bounds lo && Upper.is_top bounds hi

    let compare (lo, hi) (lo', hi') =
      match L.compare lo lo' with 0 -> L.compare hi hi' | c -> c

    let hash (lo, hi) = combine (L.hash lo) (L.hash hi)

    let counterexample bounds (lo, hi) (lo', hi') =
      match Lower.counterexample bounds lo lo' with
      | Some e -> Some (e, hi)
      | None ->
          Option.map (fun e -> (lo, e)) (Upper.counterexample bounds hi hi')

    let unit_least = false
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds (lo, hi) = implied_bounds bounds lo hi
    let inhabited bounds (lo, hi) = inhabited bounds lo && inhabited bounds hi

    let events (lo, hi) =
      List.sort_uniq String.compare (L.events lo @ L.events hi)

    (** [close ~lower a] is the bound of the open endpoint [a], a delay [q]: the
        delays above [q] for a lower endpoint, and those below [q] for an upper
        one. *)
    let close ~lower a =
      match Delay.read a with
      | Some q ->
          Braces
            (if lower then Delays (Open q, Unbounded)
             else Delays (Closed Rational.zero, Open q))
      | None -> a

    let of_lit = function
      | Top -> top
      | (Int _ | Rat _ | Braces _) as lit ->
          let rho = L.of_lit lit in
          (rho, rho)
      | lit ->
          bounds_of_lit lit ~number:Delay.read ~close ~lower:Lower.of_lit
            ~upper:Upper.of_lit ~unbounded:Upper.top
            ~bounds:"regular expressions"

    let of_delay d = (L.of_delay d, L.of_delay d)
    let of_bounds (lo, hi) = (lower_shadow lo, upper_shadow hi)
    let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi

    let show (lo, hi) =
      show_bounds (Lower.show lo)
        (if L.compare hi Upper.top = 0 then None else Some (Upper.show hi))

    let witnesses ~degree:_ _bounds = sampled mul
  end
end

include
  Make (RegularTraceGradeRational) (ByGaps)
    (struct
      let suffix = "-symbolic"
    end)

module Automata =
  Make (RegularTraceGradeRational.Automata) (ByAutomata)
    (struct
      let suffix = "-automata"
    end)
