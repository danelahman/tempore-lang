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
  RegularTimedOrders.Make
    (L)
    (struct
      type grade = L.t
      type delay = L.Delay.t
      type world = Closure.world
      type word = A.symbol list

      let suffix = "-rational" ^ N.suffix

      (* [world endpoint bounds rhos] is the operations of a comparison of the
         grades [rhos], each with the extremal value of the [endpoint] of its
         running-time bounds as its running time: the names [rhos] mention, and
         of the other declared operations, which [rhos] do not tell apart, the
         least name of each running time. *)
      let world endpoint bounds rhos =
        let mentioned =
          List.sort_uniq String.compare (List.concat_map L.events rhos)
        in
        let running_time name =
          extremum (endpoint (bounds.running_time name))
        in
        let others =
          List.filter
            (fun name -> not (List.mem name mentioned))
            (List.sort_uniq String.compare bounds.operations)
        in
        let representatives =
          List.fold_left
            (fun reps name ->
              let c = running_time name in
              if List.exists (fun (_, c') -> DelaySet.equal_extremum c c') reps
              then reps
              else (name, c) :: reps)
            [] others
        in
        List.sort
          (fun (n, _) (n', _) -> String.compare n n')
          (List.map (fun name -> (name, running_time name)) mentioned
          @ representatives)

      let in_allowance = D.in_allowance
      let in_coverage = D.in_coverage
      let allowance = D.allowance
      let coverage = D.coverage

      let min_weight world rho =
        Option.map end_of_extremum (D.min_weight world rho)

      let max_weight world rho =
        Option.map end_of_extremum (D.max_weight world rho)

      let inhabited bounds rho =
        D.inhabited
          (world (Fun.const (Closed Rational.zero)) bounds [ rho ])
          rho

      let grade_of_word word = L.of_lit (Braces (DelayRegex.of_word word))
      let single = function Int _ | Rat _ | Braces _ -> true | _ -> false
      let number = L.Delay.read

      (* [close ~lower a] is the bound of the open endpoint [a], a delay [q]:
         the delays above [q] for a lower endpoint, and those below [q] for an
         upper one. *)
      let close ~lower a =
        match L.Delay.read a with
        | Some q ->
            Braces
              (if lower then Delays (Open q, Unbounded)
               else Delays (Closed Rational.zero, Open q))
        | None -> a

      (* [lower_shadow lo] is the lower time shadow of the lower end [lo] of
         running-time bounds: [{lo}] if it is closed, and [{(lo, ∞)}], covered
         by the traces longer than [lo], if it is open. *)
      let lower_shadow = function
        | Open q -> L.of_lit (Braces (Delays (Open q, Unbounded)))
        | lo -> L.of_delay (end_value lo)

      (* [upper_shadow hi] is the upper time shadow of the upper end [hi] of
         running-time bounds: [{hi}] if it is closed, and [{[0, hi)}],
         permitting the traces shorter than [hi], if it is open. *)
      let upper_shadow = function
        | Open q -> L.of_lit (Braces (Delays (Closed Rational.zero, Open q)))
        | hi -> L.of_delay (end_value hi)
    end)

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
