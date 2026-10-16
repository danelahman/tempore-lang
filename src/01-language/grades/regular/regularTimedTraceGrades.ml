open Grade

module type LANGUAGE = sig
  include Grade.S with type Delay.t = Delay.Nat.t
  module State : Map.OrderedType

  val concrete : string list -> t -> Dfa.t
  val traces : string list -> t -> State.t Dfa.automaton
  val representatives : t list -> (string * int) list -> (string * int) list
end

(** The worlds of comparisons, hash-consed: the least names of the classes of
    the names of a comparison and their running times, equal lists being one
    world, identified by its number, and equal lists of names one number. *)
module World = struct
  type t = {
    names : string list;
    running_times : int list;
    id : int;
    names_id : int;
  }

  module Names =
    NormalForms.HashCons
      (struct
        type t = string list

        let equal = List.equal String.equal
        let hash = Hashing.list String.hash
      end)
      (struct
        type t = int

        let build id _ = id
      end)

  include
    NormalForms.HashCons
      (struct
        type t = string list * int list

        let equal (names, running_times) (names', running_times') =
          List.equal String.equal names names'
          && List.equal Int.equal running_times running_times'

        let hash (names, running_times) =
          Hashing.combine
            (Hashing.list String.hash names)
            (Hashing.list Int.hash running_times)
      end)
      (struct
        type nonrec t = t

        let build id (names, running_times) =
          { names; running_times; id; names_id = Names.make names }
      end)
end

module type DECISIONS = sig
  type t

  val in_allowance : rigid:bool -> World.t -> t -> t -> bool
  val in_coverage : World.t -> t -> t -> bool
  val allowance : rigid:bool -> World.t -> t -> t -> regex list option
  val coverage : World.t -> t -> t -> regex list option
  val min_weight : World.t -> t -> int option
  val max_weight : World.t -> t -> int option
  val inhabited : World.t -> t -> bool
end

(** Tables by a number and grades, by their representations. *)
module Numbered (G : sig
  type t

  val compare : t -> t -> int
  val hash : t -> int
end) =
struct
  (** Tables by a number and a grade. *)
  module One = Memo.Make (struct
    type t = int * G.t

    let equal (i, rho) (i', rho') = Int.equal i i' && G.compare rho rho' = 0
    let hash (i, rho) = Hashing.combine i (G.hash rho)
  end)

  (** Tables by a number and two grades. *)
  module Two = Memo.Make (struct
    type t = int * G.t * G.t

    let equal (i, rho, sigma) (i', rho', sigma') =
      Int.equal i i' && G.compare rho rho' = 0 && G.compare sigma sigma' = 0

    let hash (i, rho, sigma) =
      Hashing.combine i (Hashing.combine (G.hash rho) (G.hash sigma))
  end)

  (** [tabulated f] is [f], its results tabulated by the number of the world and
      the grades compared in a table of its own. *)
  let tabulated f =
    let table = Two.create 64 in
    fun (world : World.t) rho rho' ->
      Two.find_or_add table (world.id, rho, rho') (fun () -> f world rho rho')
end

(** The decisions by the automata of traces of [L] and their closures, a verdict
    being that the search finds no word. *)
module ByLetters (L : LANGUAGE) = struct
  type t = L.t

  include Numbered (L)
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

  (* [traces world rho] is [L.traces] over the names of [world], tabulated by
     the number of the names and the representation of [rho]. *)
  let traces =
    let table = One.create 64 in
    fun (world : World.t) rho ->
      One.find_or_add table (world.names_id, rho) (fun () ->
          L.traces world.names rho)

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
      tabulated (fun (world : World.t) rho rho' ->
          let running_time = letter_running_time world.running_times
          and letters = letters world.names in
          Option.map (symbols world.names)
            (Closed.counterexample letters (traces world rho)
               (Allowance.closure ~rigid ~running_time ~letters
                  (traces world rho'))))
    in
    let loose = decide false and rigid = decide true in
    fun ~rigid:r -> if r then rigid else loose

  let coverage =
    tabulated (fun (world : World.t) rho rho' ->
        Option.map (symbols world.names)
          (Closed.counterexample (letters world.names) (traces world rho)
             (Coverage.closure
                ~running_time:(letter_running_time world.running_times)
                (traces world rho'))))

  let in_allowance ~rigid world rho rho' =
    Option.is_none (allowance ~rigid world rho rho')

  let in_coverage world rho rho' = Option.is_none (coverage world rho rho')

  let weight extreme (world : World.t) rho =
    extreme
      ~running_time:(letter_running_time world.running_times)
      ~letters:(letters world.names) (traces world rho)

  let min_weight = weight Weights.min_weight
  let max_weight = weight Weights.max_weight

  let inhabited (world : World.t) rho =
    not (Traces.is_empty (letters world.names) (traces world rho))
end

(** The decisions by the graphs of the gap derivatives of the symbolic regular
    expressions ({!GapGraph}) and the readers and search of
    {!DelayTimedClosure.Graph} over them, at integer running times. *)
module ByGaps = struct
  type t = SymbolicRegex.t

  include Numbered (struct
    type t = SymbolicRegex.t

    let compare = SymbolicRegex.compare_form
    let hash = SymbolicRegex.hash
  end)

  (** [operations world] is the operations of [world] with their running times,
      attained. *)
  let operations (world : World.t) =
    List.map2
      (fun name c -> (name, DelaySet.Finite (Rational.of_int c, true)))
      world.names world.running_times

  (** [graph world rho] is {!GapGraph.graph} over the names of [world],
      tabulated by the number of the names and that of the normal form. *)
  let graph =
    let table = Memo.Pairs.create 64 in
    fun (world : World.t) rho ->
      Memo.Pairs.find_or_add table
        (world.names_id, SymbolicRegex.hash rho)
        (fun () -> GapGraph.graph world.names rho)

  (** [on_graphs decide world rho rho'] is [decide] on the graphs of [rho] and
      [rho'] over [world]. *)
  let on_graphs decide world rho rho' =
    decide (operations world) (graph world rho) (graph world rho')

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
        tabulated (fun world rho rho' ->
            Option.map symbols
              (on_graphs
                 (DelayTimedClosure.Graph.allowance ~rigid)
                 world rho rho')))

  let coverage =
    tabulated (fun world rho rho' ->
        Option.map symbols
          (on_graphs DelayTimedClosure.Graph.coverage world rho rho'))

  let weight extreme world rho =
    Option.map
      (fun (q, _) -> integer q)
      (extreme (operations world) (graph world rho))

  let min_weight = weight DelayTimedClosure.Graph.min_weight
  let max_weight = weight DelayTimedClosure.Graph.max_weight
  let inhabited world rho = DelayTimedClosure.Graph.inhabited (graph world rho)
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
      type world = World.t
      type word = regex list

      let suffix = Variant.suffix

      (** [letters running_time declared mentioned] is the names of the
          operations of a comparison of grades that mention the names
          [mentioned], each with its running time: the union, merged in
          increasing order, of the declared operations [declared], in increasing
          order with their running times, and of the names [mentioned], in
          increasing order, at the running times [running_time]. *)
      let rec letters running_time declared mentioned =
        match (declared, mentioned) with
        | [], _ -> List.map (fun name -> (name, running_time name)) mentioned
        | _, [] -> declared
        | ((name, _) as letter) :: declared', name' :: mentioned' -> (
            match String.compare name name' with
            | 0 -> letter :: letters running_time declared' mentioned'
            | c when c < 0 -> letter :: letters running_time declared' mentioned
            | _ ->
                (name', running_time name')
                :: letters running_time declared mentioned')

      (** [classes running_time declared rhos] is the world of a comparison of
          the grades [rhos] at the running times [running_time]: the least names
          of the classes of its names, in increasing order, and their running
          times, the declared operations being [declared] with their running
          times. *)
      let classes running_time declared rhos =
        World.make
          (List.split
             (L.representatives rhos
                (letters running_time declared
                   (List.sort_uniq String.compare
                      (List.concat_map L.events rhos)))))

      (* The running time of an operation is the value of the [endpoint] of
         its running-time bounds, in time steps; over whole time steps, the ends
         are closed where the bounds are declared ({!Grade.close_running_time}).
         The names that encode strict delays take no time. *)
      let running_time endpoint bounds name =
        if GradeLiteral.is_marker name then 0
        else
          Delay.Nat.to_int
            (read_bound L.Delay.read
               (end_value (endpoint (bounds.running_time name))))

      (** [declared running_time bounds] is the operations [bounds] declares, in
          increasing order, each with its running time [running_time]. *)
      let declared running_time bounds =
        List.map
          (fun name -> (name, running_time name))
          (List.sort_uniq String.compare bounds.operations)

      (** Lists of grades, by their representations. *)
      module Grades = Memo.Make (struct
        type t = L.t list

        let equal = List.equal (fun rho rho' -> L.compare rho rho' = 0)
        let hash = Hashing.list L.hash
      end)

      (* The worlds of the comparisons of a program at an endpoint, by the
         grades compared: the declared operations with their running times are
         computed once per running times of a program, by their physical
         identity, and endpoint. *)
      let worlds =
        Memo.last (fun bounds ->
            Memo.by_identity (fun endpoint ->
                let running_time = running_time endpoint bounds in
                let declared = declared running_time bounds in
                Grades.memoise (classes running_time declared)))

      let world endpoint bounds rhos = worlds bounds endpoint rhos
      let in_allowance = D.in_allowance
      let in_coverage = D.in_coverage
      let allowance = D.allowance
      let coverage = D.coverage

      let weight extreme world rho =
        Option.map (fun w -> Closed (Rational.of_int w)) (extreme world rho)

      let min_weight = weight D.min_weight
      let max_weight = weight D.max_weight

      (* Inhabitation is decided over the classes of the names of any
         running time. *)
      let inhabited bounds rho =
        let no_time = Fun.const 0 in
        D.inhabited (classes no_time (declared no_time bounds) [ rho ]) rho

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
