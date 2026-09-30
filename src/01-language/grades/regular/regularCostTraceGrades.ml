open Grade

module type LANGUAGE = sig
  include Grade.S with type Delay.t = Delay.Nat.t
  module State : Map.OrderedType

  val concrete : string list -> t -> Dfa.t
  val runs : string list -> t -> State.t Dfa.automaton
  val representatives : t list -> (string * int) list -> (string * int) list
end

module Make
    (L : LANGUAGE)
    (Variant : sig
      val suffix : string
    end) =
struct
  module Runs = Dfa.Implicit (L.State)
  module Allowance = CostClosure.Allowance (L.State)
  module Coverage = CostClosure.Coverage (L.State)
  module Weights = CostClosure.Weights (L.State)

  (** The products of the automata of runs with those of closures, whose states
      are sets of states of runs. *)
  module Closed =
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

  (** The arguments of a search: the least names of the classes, their costs,
      and the grades compared, by their representations. *)
  module Search = Hashtbl.Make (struct
    type t = string list * int list * L.t * L.t

    let equal (names, costs, rho, sigma) (names', costs', rho', sigma') =
      List.equal String.equal names names'
      && List.equal Int.equal costs costs'
      && L.compare rho rho' = 0
      && L.compare sigma sigma' = 0

    let hash (names, costs, rho, sigma) =
      combine
        (combine (hash_list String.hash names) (hash_list Int.hash costs))
        (combine (L.hash rho) (L.hash sigma))
  end)

  (** [tabulated search] is [search], its results tabulated by its arguments. *)
  let tabulated search =
    let table = Search.create 64 in
    fun names costs rho rho' ->
      let key = (names, costs, rho, rho') in
      match Search.find_opt table key with
      | Some word -> word
      | None ->
          let word = search ~cost:(letter_cost costs) names rho rho' in
          Search.add table key word;
          word

  (** The grades over given least names, by their representations. *)
  module Tables = Hashtbl.Make (struct
    type t = string list * L.t

    let equal (names, rho) (names', rho') =
      List.equal String.equal names names' && L.compare rho rho' = 0

    let hash (names, rho) = combine (hash_list String.hash names) (L.hash rho)
  end)

  (** [runs names rho] is [L.runs names rho], tabulated by its arguments. *)
  let runs =
    let table = Tables.create 16 in
    fun names rho ->
      match Tables.find_opt table (names, rho) with
      | Some a -> a
      | None ->
          let a = L.runs names rho in
          Tables.add table (names, rho) a;
          a

  type order = {
    search : string list -> int list -> L.t -> L.t -> int list option;
    endpoint : runtime -> Rational.t bound;
    top : L.t;
  }
  (** An order on runs: the search for a shortest run of the lesser grade
      outside the closure of the greater one, over the classes of given least
      names at given costs, the end of the runtime bounds it reads as the cost
      of an operation, and the representation of its greatest grade. *)

  let letters names = List.length names + 1

  let allowance =
    {
      search =
        tabulated (fun ~cost names rho rho' ->
            let letters = letters names in
            Closed.counterexample letters (runs names rho)
              (Allowance.closure ~cost ~letters (runs names rho')));
      endpoint = snd;
      top = L.top;
    }

  let coverage =
    {
      search =
        tabulated (fun ~cost names rho rho' ->
            Closed.counterexample (letters names) (runs names rho)
              (Coverage.closure ~cost (runs names rho')));
      endpoint = fst;
      top = L.one;
    }

  (** [alphabet bounds rhos] is the names of the operations of a comparison of
      the grades [rhos]: the declared operations and the names [rhos] mention.
  *)
  let alphabet bounds rhos =
    List.sort_uniq String.compare
      (bounds.operations @ List.concat_map L.events rhos)

  (** [cost endpoint bounds name] is the cost of the operation [name], the value
      of the [endpoint] of its runtime bounds, in time steps; over whole time
      steps, the ends are closed where the bounds are declared
      ({!Grade.close_runtime}). *)
  let cost endpoint bounds name =
    Delay.Nat.to_int
      (read_bound L.Delay.read (end_value (endpoint (bounds.cost name))))

  (** [classes cost bounds rhos] is the least names of the classes of the names
      of a comparison of the grades [rhos] at the costs [cost], in increasing
      order, and their costs. *)
  let classes cost bounds rhos =
    let names = alphabet bounds rhos in
    List.split
      (L.representatives rhos (List.map (fun name -> (name, cost name)) names))

  (** [find order bounds rho rho'] is a shortest run of [rho] outside the
      closure of [rho'] under [order], with the least names of the classes its
      letters index; there is none if [rho] and [rho'] are the same language or
      [rho'] is the top. *)
  let find order bounds rho rho' =
    if L.equal bounds rho rho' || L.compare rho' order.top = 0 then None
    else
      let names, costs =
        classes (cost order.endpoint bounds) bounds [ rho; rho' ]
      in
      order.search names costs rho rho'
      |> Option.map (fun word -> (names, word))

  (** [inhabited bounds rho] is whether [rho] has a run over the declared
      operations and the names it mentions, the costs aside. *)
  let inhabited bounds rho =
    let names, _ = classes (Fun.const 0) bounds [ rho ] in
    not (Runs.is_empty (letters names) (runs names rho))

  (** [grade_of_word (names, word)] is the grade of the single run [word] over
      [names]. *)
  let grade_of_word (names, word) =
    let letter a = if a = 0 then Tick 1 else Letter (List.nth names (a - 1)) in
    L.of_lit
      (Braces (List.fold_left (fun r a -> Seq (r, letter a)) (Tick 0) word))

  let leq order bounds rho rho' = Option.is_none (find order bounds rho rho')

  (** [is_top order bounds rho] is whether [rho] is the top: by its
      representation, and otherwise by the order. *)
  let is_top order bounds rho =
    L.compare rho order.top = 0 || leq order bounds order.top rho

  let counterexample order bounds rho rho' =
    Option.map grade_of_word (find order bounds rho rho')

  (** [weight extreme endpoint bounds rho] is the [extreme] weight of a run of
      [rho], operations costing the [endpoint] of their runtime bounds. *)
  let weight extreme endpoint bounds rho =
    let names, costs = classes (cost endpoint bounds) bounds [ rho ] in
    extreme ~cost:(letter_cost costs) ~letters:(letters names) (runs names rho)

  let implied_bounds bounds lower upper =
    match
      ( weight Weights.min_weight fst bounds lower,
        weight Weights.max_weight snd bounds upper )
    with
    | Some fastest, Some slowest ->
        Some (Closed (Rational.of_int fastest), Closed (Rational.of_int slowest))
    | _ -> None

  (** The fields the grades share with the regular trace grade. *)
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

    let name = "regex-cost-lower-bound" ^ Variant.suffix
    let leq = leq coverage
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample coverage

    (** The unit [{0}], covered by every run. *)
    let top = coverage.top

    let is_top = is_top coverage
    let unit_least = false
    let of_lit = function Top -> top | lit -> L.of_lit lit
    let of_bounds b = L.of_delay (fst (hull b))
  end

  module Upper = struct
    include Common

    let name = "regex-cost-upper-bound" ^ Variant.suffix
    let leq = leq allowance
    let equal bounds rho rho' = leq bounds rho rho' && leq bounds rho' rho
    let counterexample = counterexample allowance
    let top = allowance.top
    let is_top = is_top allowance
    let unit_least = true
    let of_lit = L.of_lit
    let of_bounds b = L.of_delay (snd (hull b))
  end

  module Interval = struct
    type t = L.t * L.t

    module Delay = L.Delay

    let name = "regex-cost-interval" ^ Variant.suffix
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

    (** [integer lit] is the value of the integer literal [lit]. *)
    let integer = function Int n -> Some (Rational.of_int n) | _ -> None

    let of_lit = function
      | Top -> top
      | (Int _ | Braces _) as lit ->
          let rho = L.of_lit lit in
          (rho, rho)
      | lit ->
          bounds_of_lit lit ~number:integer ~close:close_integer
            ~lower:Lower.of_lit ~upper:Upper.of_lit ~unbounded:Upper.top
            ~bounds:"regular expressions"

    let of_delay d = (L.of_delay d, L.of_delay d)

    let of_bounds b =
      let lo, hi = hull b in
      (L.of_delay lo, L.of_delay hi)

    let is_atomic name (lo, hi) = L.is_atomic name lo && L.is_atomic name hi

    let show (lo, hi) =
      show_bounds (Lower.show lo)
        (if L.compare hi Upper.top = 0 then None else Some (Upper.show hi))

    let witnesses ~degree:_ _bounds = sampled mul
  end
end

(** [every_name rhos letters] is [letters], every name a class of its own. *)
let every_name _rhos letters = letters

(** The regular trace grade by automata, its runs over given names explored in
    its table. *)
module Automata = struct
  include RegularTraceGrade
  module State = Int

  let runs names rho = Dfa.automaton (concrete names rho)
  let representatives = every_name
end

(** The regular trace grade by symbolic derivatives, its runs over given names
    explored by their derivatives. *)
module Derivatives = struct
  include RegularTraceGradeDerivative

  module State = struct
    type t = SymbolicRegex.t

    let compare = SymbolicRegex.compare_form
  end

  let by_name (name, _) (name', _) = String.compare name name'

  (** The grades of a comparison, by the numbers of their normal forms. *)
  module Roots = Hashtbl.Make (struct
    type t = int list

    let equal = List.equal Int.equal
    let hash = Grade.hash_list Fun.id
  end)

  (** [blocks rhos] is the names listed by the finite minterms of the letter
      sets of [rhos], each with the number of its minterm, in increasing order,
      and the number of the one cofinite minterm, which holds the other names;
      tabulated by the normal forms of [rhos] in a module-level table that only
      ever grows. *)
  let blocks =
    let number (listed, cofinite) (i, (m : SymbolicRegex.Letters.t)) =
      match m.names with
      | Only names ->
          ( List.merge by_name listed (List.map (fun name -> (name, i)) names),
            cofinite )
      | Except _ -> (listed, i)
    in
    let table = Roots.create 64 in
    fun rhos ->
      let key = List.map SymbolicRegex.hash rhos in
      match Roots.find_opt table key with
      | Some blocks -> blocks
      | None ->
          let blocks =
            List.fold_left number ([], 0)
              (List.mapi
                 (fun i m -> (i, m))
                 (SymbolicRegex.Minterms.blocks rhos))
          in
          Roots.add table key blocks;
          blocks

  (** [mem i cost classes] is whether the class of the minterm [i] and the cost
      [cost] is among [classes]. *)
  let rec mem i cost = function
    | [] -> false
    | (i', cost') :: classes ->
        (Int.equal i i' && Int.equal cost cost') || mem i cost classes

  (* The names are listed in increasing order, as those of [blocks], so that
     merging the two finds the minterm of each, and the first name of a class
     is its least. *)
  let representatives rhos letters =
    let listed, cofinite = blocks rhos in
    let rec keep listed seen letters =
      match (letters, listed) with
      | [], _ -> []
      | ((name, _) as letter) :: letters', (name', i) :: listed' -> (
          match String.compare name name' with
          | 0 -> classify i letter listed' seen letters'
          | c when c > 0 -> keep listed' seen letters
          | _ -> classify cofinite letter listed seen letters')
      | letter :: letters', [] -> classify cofinite letter [] seen letters'
    and classify i ((_, cost) as letter) listed seen letters =
      if mem i cost seen then keep listed seen letters
      else letter :: keep listed ((i, cost) :: seen) letters
    in
    keep listed [] letters
end

(** The regular trace grade by the derivatives by concrete letters. *)
module ConcreteDerivatives = struct
  include RegularTraceGradeDerivative.Concrete
  module State = Derivatives.State

  let representatives = every_name
end

(** The regular trace grade by plain derivatives, its runs over given names
    explored by their derivatives. *)
module PlainDerivatives = struct
  include RegularTraceGradePlain

  module State = struct
    type t = Regex.t

    let compare = Regex.compare_form
  end

  let representatives = every_name
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
