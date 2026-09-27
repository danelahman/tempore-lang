open Grade

module type LANGUAGE = sig
  include Grade.S
  module State : Map.OrderedType

  val concrete : string list -> t -> Dfa.t
  val runs : string list -> t -> State.t Dfa.automaton
end

module Make
    (L : LANGUAGE)
    (Variant : sig
      val suffix : string
    end) =
struct
  module Runs = Dfa.Implicit (L.State)
  module Coverage = CostClosure.Coverage (L.State)

  module Allowed =
    Dfa.Product
      (L.State)
      (struct
        type t = int list

        let compare = List.compare Int.compare
      end)

  module Covered =
    Dfa.Product
      (L.State)
      (struct
        type t = L.State.t list

        let compare = List.compare L.State.compare
      end)

  (** [letter_cost costs] is the cost of each letter of an operation, the [a]-th
      of [costs] for the letter [a]. *)
  let letter_cost costs =
    let costs = Array.of_list costs in
    fun a -> costs.(a - 1)

  (** [tabulated search] is [search], its results tabulated by the names, the
      costs of their operations and the grades. *)
  let tabulated search =
    let table = Hashtbl.create 64 in
    fun names costs rho rho' ->
      let key = (names, costs, rho, rho') in
      match Hashtbl.find_opt table key with
      | Some word -> word
      | None ->
          let word = search ~cost:(letter_cost costs) names rho rho' in
          Hashtbl.add table key word;
          word

  type order = {
    search : string list -> int list -> L.t -> L.t -> int list option;
    endpoint : int * int -> int;
  }
  (** An order on runs: the search for a shortest run of the lesser grade
      outside the closure of the greater one, over given names at given costs of
      their operations, and the end of the runtime bounds it reads as the cost
      of an operation. *)

  let letters names = List.length names + 1

  let allowance =
    {
      search =
        tabulated (fun ~cost names rho rho' ->
            Allowed.counterexample (letters names) (L.runs names rho)
              (CostClosure.allowance ~cost (L.concrete names rho')));
      endpoint = snd;
    }

  let coverage =
    {
      search =
        tabulated (fun ~cost names rho rho' ->
            Covered.counterexample (letters names) (L.runs names rho)
              (Coverage.closure ~cost (L.runs names rho')));
      endpoint = fst;
    }

  (** [alphabet bounds rhos] is the names of the operations of a comparison of
      the grades [rhos]: the declared operations and the names [rhos] mention.
  *)
  let alphabet bounds rhos =
    List.sort_uniq String.compare
      (bounds.operations @ List.concat_map L.events rhos)

  (** [costs endpoint bounds names] is the cost of each of [names], the
      [endpoint] of its runtime bounds. *)
  let costs endpoint bounds names =
    List.map (fun name -> endpoint (bounds.cost name)) names

  (** [find order bounds rho rho'] is a shortest run of [rho] outside the
      closure of [rho'] under [order], with the names its letters index; there
      is none if [rho] and [rho'] are the same language. *)
  let find order bounds rho rho' =
    if L.equal bounds rho rho' then None
    else
      let names = alphabet bounds [ rho; rho' ] in
      order.search names (costs order.endpoint bounds names) rho rho'
      |> Option.map (fun word -> (names, word))

  (** [inhabited bounds rho] is whether [rho] has a run over the declared
      operations and the names it mentions. *)
  let inhabited bounds rho =
    let names = alphabet bounds [ rho ] in
    not (Runs.is_empty (letters names) (L.runs names rho))

  (** [grade_of_word (names, word)] is the grade of the single run [word] over
      [names]. *)
  let grade_of_word (names, word) =
    let letter a = if a = 0 then Tick 1 else Letter (List.nth names (a - 1)) in
    L.of_lit
      (Braces (List.fold_left (fun r a -> Seq (r, letter a)) (Tick 0) word))

  let leq order bounds rho rho' = Option.is_none (find order bounds rho rho')

  let counterexample order bounds rho rho' =
    Option.map grade_of_word (find order bounds rho rho')

  (** [weight extreme endpoint bounds rho] is the [extreme] weight of a run of
      [rho], operations costing the [endpoint] of their runtime bounds. *)
  let weight extreme endpoint bounds rho =
    let names = alphabet bounds [ rho ] in
    extreme
      ~cost:(letter_cost (costs endpoint bounds names))
      (L.concrete names rho)

  let implied_bounds bounds lower upper =
    match
      ( weight CostClosure.min_weight fst bounds lower,
        weight CostClosure.max_weight snd bounds upper )
    with
    | Some fastest, Some slowest -> Some (fastest, slowest)
    | _ -> None

  (** The fields the grades share with the regular trace grade. *)
  module Common = struct
    type t = L.t

    let one = L.one
    let mul = L.mul
    let join = L.join
    let of_nat = L.of_nat
    let leq_symbol = "<="
    let commutative = false
    let needs_op_bounds = true
    let implied_bounds bounds rho = implied_bounds bounds rho rho
    let inhabited = inhabited
    let events = L.events
    let is_atomic = L.is_atomic
    let show = L.show
  end

  module Lower = struct
    include Common

    let name = "traces-regex-lower" ^ Variant.suffix
    let leq = leq coverage
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample coverage

    (** The unit [{0}], covered by every run. *)
    let top = one

    let unit_least = false
    let of_lit = function Top -> top | lit -> L.of_lit lit
    let of_bounds (lo, _hi) = of_nat lo
  end

  module Upper = struct
    include Common

    let name = "traces-regex-upper" ^ Variant.suffix
    let leq = leq allowance
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample allowance
    let top = L.top
    let unit_least = true
    let of_lit = L.of_lit
    let of_bounds (_lo, hi) = of_nat hi
  end

  module Interval = struct
    type t = L.t * L.t

    let name = "traces-regex-interval" ^ Variant.suffix
    let one = (Lower.one, Upper.one)
    let mul (lo, hi) (lo', hi') = (L.mul lo lo', L.mul hi hi')

    let leq bounds (lo, hi) (lo', hi') =
      Lower.leq bounds lo lo' && Upper.leq bounds hi hi'

    let leq_symbol = "<="
    let top = (Lower.top, Upper.top)
    let join (lo, hi) (lo', hi') = (L.join lo lo', L.join hi hi')
    let equal bounds p q = leq bounds p q && leq bounds q p

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

    let of_lit = function
      | Top -> top
      | (Int _ | Braces _) as lit ->
          let rho = L.of_lit lit in
          (rho, rho)
      | Tuple [ Int n; Int m ] as lit when n > m ->
          invalid_lit lit "interval endpoints must satisfy n <= m"
      | Tuple [ lo; hi ] as lit ->
          let lo = component_of_lit lit ~context:"" Lower.of_lit lo in
          let hi = component_of_lit lit ~context:"" Upper.of_lit hi in
          (lo, hi)
      | lit ->
          invalid_lit lit
            "grades are pairs '({...}, {...})' of regular expressions, or \
             abbreviations of them, not %s"
            (describe_lit lit)

    let of_nat n = (L.of_nat n, L.of_nat n)
    let of_bounds (lo, hi) = (L.of_nat lo, L.of_nat hi)
    let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi
    let show (lo, hi) = "(" ^ Lower.show lo ^ "," ^ Upper.show hi ^ ")"
  end
end

(** The regular trace grade by automata, its runs over given names explored in
    its table. *)
module Automata = struct
  include RegularTraceGrade
  module State = Int

  let runs names rho = Dfa.automaton (concrete names rho)
end

(** The regular trace grade by symbolic derivatives, its runs over given names
    explored by their derivatives. *)
module Derivatives = struct
  include RegularTraceGradeDerivative

  module State = struct
    type t = SymbolicRegex.t

    let compare = SymbolicRegex.compare_form
  end
end

(** The regular trace grade by the derivatives by concrete letters. *)
module ConcreteDerivatives = struct
  include RegularTraceGradeDerivative.Concrete
  module State = Derivatives.State
end

(** The regular trace grade by plain derivatives, its runs over given names
    explored by their derivatives. *)
module PlainDerivatives = struct
  include RegularTraceGradePlain

  module State = struct
    type t = Regex.t

    let compare = Regex.compare_form
  end
end

include
  Make
    (Automata)
    (struct
      let suffix = ""
    end)

module Symbolic =
  Make
    (Derivatives)
    (struct
      let suffix = "-symbolic"
    end)

module Concrete =
  Make
    (ConcreteDerivatives)
    (struct
      let suffix = "-derivatives"
    end)

module Plain =
  Make
    (PlainDerivatives)
    (struct
      let suffix = "-plain"
    end)
