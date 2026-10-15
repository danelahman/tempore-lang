open Grade

module type LANGUAGE = sig
  include Grade.S with type Delay.t = Delay.Nat.t
  module State : Map.OrderedType

  val concrete : string list -> t -> Dfa.t
  val traces : string list -> t -> State.t Dfa.automaton
  val representatives : t list -> (string * int) list -> (string * int) list
end

module type DECISIONS = sig
  type t

  val in_allowance : rigid:bool -> string list -> int list -> t -> t -> bool
  val in_coverage : string list -> int list -> t -> t -> bool

  val allowance :
    rigid:bool -> string list -> int list -> t -> t -> regex list option

  val coverage : string list -> int list -> t -> t -> regex list option
  val min_weight : string list -> int list -> t -> int option
  val max_weight : string list -> int list -> t -> int option
  val inhabited : string list -> t -> bool
end

(** Tables of the results of comparisons, by the least names of the classes,
    their running times, and the grades compared, by their representations. *)
module Tabulate (G : sig
  type t

  val compare : t -> t -> int
  val hash : t -> int
end) =
struct
  module Search = Memo.Make (struct
    type t = string list * int list * G.t * G.t

    let equal (names, running_times, rho, sigma)
        (names', running_times', rho', sigma') =
      List.equal String.equal names names'
      && List.equal Int.equal running_times running_times'
      && G.compare rho rho' = 0
      && G.compare sigma sigma' = 0

    let hash (names, running_times, rho, sigma) =
      Hashing.combine
        (Hashing.combine
           (Hashing.list String.hash names)
           (Hashing.list Int.hash running_times))
        (Hashing.combine (G.hash rho) (G.hash sigma))
  end)

  (** [tabulated f] is [f], its results tabulated by its arguments in a table of
      its own. *)
  let tabulated f =
    let f =
      Search.memoise (fun (names, running_times, rho, rho') ->
          f names running_times rho rho')
    in
    fun names running_times rho rho' -> f (names, running_times, rho, rho')
end

(** The decisions by the automata of traces of [L] and their closures, a verdict
    being that the search finds no word. *)
module ByLetters (L : LANGUAGE) = struct
  type t = L.t

  include Tabulate (L)
  module Traces = Dfa.Implicit (L.State)
  module Allowance = TimedClosure.Allowance (L.State)
  module Coverage = TimedClosure.Coverage (L.State)
  module Weights = TimedClosure.Weights (L.State)

  (** The products of the automata of traces with those of closures, whose
      states are sets of states of the automata of traces. *)
  module Closed =
    Dfa.Product
      (L.State)
      (struct
        type t = L.State.t list

        let compare = List.compare L.State.compare
      end)

  (** [letter_running_time running_times] is the running time of each letter of
      an operation, the [a]-th of [running_times] for the letter [a]. *)
  let letter_running_time running_times =
    let running_times = Array.of_list running_times in
    fun a -> running_times.(a - 1)

  (** The grades over given least names, by their representations. *)
  module Tables = Memo.Make (struct
    type t = string list * L.t

    let equal (names, rho) (names', rho') =
      List.equal String.equal names names' && L.compare rho rho' = 0

    let hash (names, rho) =
      Hashing.combine (Hashing.list String.hash names) (L.hash rho)
  end)

  (* [L.traces names rho], tabulated by its arguments. *)
  let traces =
    let traces = Tables.memoise (fun (names, rho) -> L.traces names rho) in
    fun names rho -> traces (names, rho)

  let letters names = List.length names + 1

  (** [symbols names word] is the word [word] over the letters [tick], numbered
      [0], and [names], numbered from [1], as its delays, its runs of ticks, and
      its names. *)
  let symbols names word =
    List.rev
      (List.fold_left
         (fun symbols a ->
           match (a, symbols) with
           | 0, Tick n :: rest -> Tick (n + 1) :: rest
           | 0, _ -> Tick 1 :: symbols
           | a, _ -> Letter (List.nth names (a - 1)) :: symbols)
         [] word)

  let allowance =
    let decide rigid =
      tabulated (fun names running_times rho rho' ->
          let running_time = letter_running_time running_times
          and letters = letters names in
          Option.map (symbols names)
            (Closed.counterexample letters (traces names rho)
               (Allowance.closure ~rigid ~running_time ~letters
                  (traces names rho'))))
    in
    let loose = decide false and rigid = decide true in
    fun ~rigid:r -> if r then rigid else loose

  let coverage =
    tabulated (fun names running_times rho rho' ->
        Option.map (symbols names)
          (Closed.counterexample (letters names) (traces names rho)
             (Coverage.closure
                ~running_time:(letter_running_time running_times)
                (traces names rho'))))

  let in_allowance ~rigid names running_times rho rho' =
    Option.is_none (allowance ~rigid names running_times rho rho')

  let in_coverage names running_times rho rho' =
    Option.is_none (coverage names running_times rho rho')

  let weight extreme names running_times rho =
    extreme
      ~running_time:(letter_running_time running_times)
      ~letters:(letters names) (traces names rho)

  let min_weight = weight Weights.min_weight
  let max_weight = weight Weights.max_weight

  let inhabited names rho =
    not (Traces.is_empty (letters names) (traces names rho))
end

(** The decisions by the graphs of the gap derivatives of the symbolic regular
    expressions ({!GapGraph}) and the readers and search of
    {!DelayTimedClosure.Graph} over them, at integer running times. *)
module ByGaps = struct
  type t = SymbolicRegex.t

  include Tabulate (struct
    type t = SymbolicRegex.t

    let compare = SymbolicRegex.compare_form
    let hash = SymbolicRegex.hash
  end)

  let world names running_times =
    List.map2
      (fun name c -> (name, DelaySet.Finite (Rational.of_int c, true)))
      names running_times

  (** Tables by lists of names and normal forms. *)
  module Graphs = Memo.Make (struct
    type t = string list * SymbolicRegex.t

    let equal (names, rho) (names', rho') =
      List.equal String.equal names names' && SymbolicRegex.equal_form rho rho'

    let hash (names, rho) =
      Hashing.combine (Hashing.list String.hash names) (SymbolicRegex.hash rho)
  end)

  (** [graph names rho] is {!GapGraph.graph}, tabulated by its arguments. *)
  let graph =
    let graph = Graphs.memoise (fun (names, rho) -> GapGraph.graph names rho) in
    fun names rho -> graph (names, rho)

  (** [on_graphs decide names running_times rho rho'] is [decide] on the graphs
      of [rho] and [rho'] over [names] at [running_times]. *)
  let on_graphs decide names running_times rho rho' =
    decide (world names running_times) (graph names rho) (graph names rho')

  (** [integer q] is the rational [q], an integer at integer running times. *)
  let integer q =
    match Rational.to_int q with
    | Some n -> n
    | None ->
        invalid_arg
          "RegularTimedTraceGrades.ByGaps.integer: a delay or weight that is \
           not an integer"

  (** [symbols word] is the word in gap form [word] as its non-zero delays,
      integers, and a member of each class of names. *)
  let symbols word =
    List.filter_map
      (function
        | DelayAutomaton.Delay d when Rational.sign d = 0 -> None
        | DelayAutomaton.Delay d -> Some (Tick (integer d))
        | DelayAutomaton.Operation c -> (
            match DelayAutomaton.Class.choose c with
            | Some name -> Some (Letter name)
            | None ->
                invalid_arg
                  "RegularTimedTraceGrades.ByGaps.symbols: an empty class of \
                   names"))
      word

  (** [by_order decide] is [decide ~rigid] for each [rigid], tabulated
      separately. *)
  let by_order decide =
    let loose = decide ~rigid:false and rigid = decide ~rigid:true in
    fun ~rigid:r -> if r then rigid else loose

  let in_allowance =
    by_order (fun ~rigid ->
        tabulated (on_graphs (DelayTimedClosure.Graph.in_allowance ~rigid)))

  let in_coverage = tabulated (on_graphs DelayTimedClosure.Graph.in_coverage)

  let allowance =
    by_order (fun ~rigid ->
        tabulated (fun names running_times rho rho' ->
            Option.map symbols
              (on_graphs
                 (DelayTimedClosure.Graph.allowance ~rigid)
                 names running_times rho rho')))

  let coverage =
    tabulated (fun names running_times rho rho' ->
        Option.map symbols
          (on_graphs DelayTimedClosure.Graph.coverage names running_times rho
             rho'))

  let weight extreme names running_times rho =
    Option.map
      (fun (q, _) -> integer q)
      (extreme (world names running_times) (graph names rho))

  let min_weight = weight DelayTimedClosure.Graph.min_weight
  let max_weight = weight DelayTimedClosure.Graph.max_weight
  let inhabited names rho = DelayTimedClosure.Graph.inhabited (graph names rho)
end

(** The grades over [L], decided by [D] over the least names of the classes of
    the names of a comparison and their running times, the rigid ones reading
    the literals, delays and top [S]. *)
module Over
    (L : LANGUAGE)
    (S : StrictDelays.GRADE with type grade = L.t and type delay = L.Delay.t)
    (D : DECISIONS with type t = L.t)
    (Variant : sig
      val suffix : string
    end) =
  RegularTimedOrders.Make (L) (S)
    (struct
      type grade = L.t
      type delay = L.Delay.t
      type world = string list * int list
      type word = regex list

      let suffix = Variant.suffix

      (** [alphabet bounds rhos] is the names of the operations of a comparison
          of the grades [rhos]: the declared operations and the names [rhos]
          mention. *)
      let alphabet bounds rhos =
        List.sort_uniq String.compare
          (bounds.operations @ List.concat_map L.events rhos)

      (** [classes running_time bounds rhos] is the least names of the classes
          of the names of a comparison of the grades [rhos] at the running times
          [running_time], in increasing order, and their running times. *)
      let classes running_time bounds rhos =
        List.split
          (L.representatives rhos
             (List.map
                (fun name -> (name, running_time name))
                (alphabet bounds rhos)))

      (* The running time of an operation is the value of the [endpoint] of
         its running-time bounds, in time steps; over whole time steps, the ends
         are closed where the bounds are declared ({!Grade.close_running_time}).
         The names that encode strict delays take no time. *)
      let world endpoint bounds =
        classes
          (fun name ->
            if GradeLiteral.is_marker name then 0
            else
              Delay.Nat.to_int
                (read_bound L.Delay.read
                   (end_value (endpoint (bounds.running_time name)))))
          bounds

      let in_allowance ~rigid (names, running_times) =
        D.in_allowance ~rigid names running_times

      let in_coverage (names, running_times) = D.in_coverage names running_times

      let allowance ~rigid (names, running_times) =
        D.allowance ~rigid names running_times

      let coverage (names, running_times) = D.coverage names running_times

      let weight extreme (names, running_times) rho =
        Option.map
          (fun w -> Closed (Rational.of_int w))
          (extreme names running_times rho)

      let min_weight = weight D.min_weight
      let max_weight = weight D.max_weight

      (* Inhabitation is decided over the classes of the names of any
         running time. *)
      let inhabited bounds rho =
        D.inhabited (fst (classes (Fun.const 0) bounds [ rho ])) rho

      (* The literal of the single trace of the delays and names [word], the
         delays between the names that encode a strict delay written as one. *)
      let literal_of_word word =
        let rec atoms = function
          | Letter o :: (Tick _ as d) :: Letter c :: word
            when String.equal o strict_opening && String.equal c strict_closing
            ->
              Strict d :: atoms word
          | r :: word -> r :: atoms word
          | [] -> []
        in
        match atoms word with
        | [] -> Braces (Tick 0)
        | r :: rs -> Braces (List.fold_left (fun r s -> Seq (r, s)) r rs)

      let single = function Int _ | Braces _ -> true | _ -> false
      let number = function Int n -> Some (Rational.of_int n) | _ -> None
      let close = close_integer
      let lower_shadow lo = L.of_delay (end_value lo)
      let upper_shadow hi = L.of_delay (end_value hi)
    end)

(** [every_name rhos letters] is [letters], every name a class of its own. *)
let every_name _rhos letters = letters

(** The regular trace grade by automata, its traces over given names explored in
    its table. *)
module Automata = struct
  include RegularTraceGrade
  module State = Int

  let traces names rho = Dfa.automaton (concrete names rho)
  let representatives = every_name
end

(** The regular trace grade by symbolic derivatives, its traces over given names
    explored by their derivatives. *)
module Derivatives = struct
  include RegularTraceGradeDerivative

  module State = struct
    type t = SymbolicRegex.t

    let compare = SymbolicRegex.compare_form
  end

  let by_name (name, _) (name', _) = String.compare name name'

  (** The grades of a comparison, by the numbers of their normal forms. *)
  module Roots = Memo.Make (struct
    type t = int list

    let equal = List.equal Int.equal
    let hash = Hashing.list Fun.id
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
      Roots.find_or_add table (List.map SymbolicRegex.id rhos) (fun () ->
          List.fold_left number ([], 0)
            (List.mapi (fun i m -> (i, m)) (SymbolicRegex.Minterms.blocks rhos)))

  (** [mem i running_time classes] is whether the class of the minterm [i] and
      the running time [running_time] is among [classes]. *)
  let rec mem i running_time = function
    | [] -> false
    | (i', running_time') :: classes ->
        (Int.equal i i' && Int.equal running_time running_time')
        || mem i running_time classes

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
    and classify i ((_, running_time) as letter) listed seen letters =
      if mem i running_time seen then keep listed seen letters
      else letter :: keep listed ((i, running_time) :: seen) letters
    in
    keep listed [] letters
end

(** The regular trace grade by the derivatives by concrete letters. *)
module ConcreteDerivatives = struct
  include RegularTraceGradeDerivative.Concrete
  module State = Derivatives.State

  let representatives = every_name
end

(** The regular trace grade by plain derivatives, its traces over given names
    explored by their derivatives. *)
module PlainDerivatives = struct
  include RegularTraceGradePlain

  module State = struct
    type t = Regex.t

    let compare = Regex.compare_form
  end

  let representatives = every_name
end

module Make (L : LANGUAGE) = Over (L) (StrictDelays.Without (L)) (ByLetters (L))

include
  Make
    (Automata)
    (struct
      let suffix = "-letter-automata"
    end)

module Symbolic =
  Over (Derivatives) (Derivatives.Strict) (ByGaps)
    (struct
      let suffix = "-symbolic"
    end)

module Concrete =
  Make
    (ConcreteDerivatives)
    (struct
      let suffix = "-symbolic-by-letters"
    end)

module Plain =
  Make
    (PlainDerivatives)
    (struct
      let suffix = "-letter-derivatives"
    end)
