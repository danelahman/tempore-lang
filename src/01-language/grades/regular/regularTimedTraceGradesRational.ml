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

(* The worlds of comparisons, hash-consed: equal lists of operations with their
   running times are one world, identified by its number, and equal lists of
   their names one number. *)
module World = struct
  type t = { operations : Closure.world; id : int; names : int }

  (* Lists of names. *)
  module NameList = struct
    type t = string list

    let equal = List.equal String.equal
    let hash = Hashing.list String.hash
  end

  module Names =
    NormalForms.HashCons
      (NameList)
      (struct
        type t = int

        let build id _ = id
      end)

  include
    NormalForms.HashCons
      (struct
        type t = Closure.world

        let equal =
          List.equal (fun (n, c) (n', c') ->
              String.equal n n' && DelaySet.equal_extremum c c')

        let hash =
          Hashing.list (fun (n, c) ->
              Hashing.combine (String.hash n) (DelaySet.hash_extremum c))
      end)
      (struct
        type nonrec t = t

        let build id operations =
          { operations; id; names = Names.make (List.map fst operations) }
      end)
end

(* The decisions of the orders on the grades [t]: whether every trace of the
   lesser grade is in the closure of the greater one, a trace outside it, the
   extremal weights of the traces of a grade and its inhabitation, over the
   operations of a world. *)
module type DECISIONS = sig
  type t

  val in_allowance : World.t -> t -> t -> bool
  val in_coverage : World.t -> t -> t -> bool
  val allowance : World.t -> t -> t -> A.symbol list option
  val coverage : World.t -> t -> t -> A.symbol list option
  val min_weight : World.t -> t -> (Rational.t * bool) option
  val max_weight : World.t -> t -> (Rational.t * bool) option
  val inhabited : World.t -> t -> bool
  val consistent : World.t -> World.t -> t -> t -> bool
end

(* Tables by the numbers of two worlds and two grades. *)
module Quadruples = Memo.Make (struct
  type t = int * int * int * int

  let equal (i, j, k, l) (i', j', k', l') =
    Int.equal i i' && Int.equal j j' && Int.equal k k' && Int.equal l l'

  let hash (i, j, k, l) =
    Hashing.combine (Hashing.combine i j) (Hashing.combine k l)
end)

(* The decisions on the canonical automata of the grades, a verdict being that
   the search finds no word. *)
module ByAutomata = struct
  module L = RegularTraceGradeRational.Automata

  type t = L.t

  let on decide (world : World.t) rho rho' =
    decide world.operations (L.automaton rho) (L.automaton rho')

  let allowance = on Closure.allowance
  let coverage = on Closure.coverage
  let in_allowance world rho rho' = Option.is_none (allowance world rho rho')
  let in_coverage world rho rho' = Option.is_none (coverage world rho rho')

  let on_one decide (world : World.t) rho =
    decide world.operations (L.automaton rho)

  let min_weight = on_one Closure.min_weight
  let max_weight = on_one Closure.max_weight
  let inhabited = on_one Closure.inhabited

  (* The two worlds have the same names. *)
  let consistent (lo_world : World.t) (hi_world : World.t) rho rho' =
    let names = List.map fst lo_world.operations in
    JointWalk.consistent ~lo:lo_world.operations ~hi:hi_world.operations
      (Closure.of_automaton names (L.automaton rho))
      (Closure.of_automaton names (L.automaton rho'))
end

(* The decisions on the graphs of the gap derivatives of the expressions of the
   grades in normal form ({!GapGraph}), over the names of the world. *)
module ByGaps = struct
  module L = RegularTraceGradeRational

  type t = L.t

  (* [graph world rho] is {!RationalRegex.graph} over the names of [world],
     tabulated by the number of the names and that of the normal form. *)
  let graph =
    let table = Memo.Pairs.create 64 in
    fun (world : World.t) rho ->
      let r = L.form rho in
      Memo.Pairs.find_or_add table
        (world.names, RationalRegex.hash r)
        (fun () -> RationalRegex.graph (List.map fst world.operations) r)

  let on decide (world : World.t) rho =
    decide world.operations (graph world rho)

  let on_pair decide (world : World.t) rho rho' =
    decide world.operations (graph world rho) (graph world rho')

  (* [tabulated f] is [f], its results tabulated by the numbers of the world and
     of the normal forms of the grades in a table of its own. *)
  let tabulated f =
    let table = Memo.Triples.create 64 in
    fun (world : World.t) rho rho' ->
      Memo.Triples.find_or_add table
        ( world.id,
          RationalRegex.hash (L.form rho),
          RationalRegex.hash (L.form rho') )
        (fun () -> f world rho rho')

  let in_allowance = tabulated (on_pair Closure.Graph.in_allowance)
  let in_coverage = tabulated (on_pair Closure.Graph.in_coverage)
  let allowance = tabulated (on_pair Closure.Graph.allowance)
  let coverage = tabulated (on_pair Closure.Graph.coverage)
  let min_weight = on Closure.Graph.min_weight
  let max_weight = on Closure.Graph.max_weight
  let inhabited world rho = Closure.Graph.inhabited (graph world rho)

  (* The two worlds have the same names, and hence the same graphs; the
     results are tabulated by the numbers of the worlds and of the normal
     forms. *)
  let consistent =
    let table = Quadruples.create 64 in
    fun (lo_world : World.t) (hi_world : World.t) rho rho' ->
      Quadruples.find_or_add table
        ( lo_world.id,
          hi_world.id,
          RationalRegex.hash (L.form rho),
          RationalRegex.hash (L.form rho') )
        (fun () ->
          JointWalk.consistent ~lo:lo_world.operations ~hi:hi_world.operations
            (graph lo_world rho) (graph hi_world rho'))
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
      type world = World.t
      type word = A.symbol list

      let suffix = "-rational" ^ N.suffix

      (* [running_time endpoint bounds name] is the extremal value of the
         [endpoint] of the running-time bounds of the operation [name]. *)
      let running_time endpoint bounds name =
        extremum (endpoint (bounds.running_time name))

      (* [classes equal running_time names] is the classes of the names
         [names] of running times equal by [equal], each with its running
         time and its names in increasing order. *)
      let classes equal running_time names =
        List.fold_right
          (fun name classes ->
            let c = running_time name in
            let rec add = function
              | [] -> [ (c, [ name ]) ]
              | (c', names) :: classes when equal c c' ->
                  (c', name :: names) :: classes
              | class_ :: classes -> class_ :: add classes
            in
            add classes)
          (List.sort_uniq String.compare names)
          []

      (* [operations running_time classes mentioned] is the operations of a
         comparison of grades that mention the names [mentioned], in increasing
         order, each with its running time: the names [mentioned], and of the
         other declared operations, of the [classes] of their running times,
         which the grades do not tell apart, the least name of each class. *)
      let operations running_time classes mentioned =
        let representatives =
          List.filter_map
            (fun (c, names) ->
              Option.map
                (fun name -> (name, c))
                (List.find_opt
                   (fun name -> not (List.mem name mentioned))
                   names))
            classes
        in
        List.sort
          (fun (n, _) (n', _) -> String.compare n n')
          (List.map (fun name -> (name, running_time name)) mentioned
          @ representatives)

      (* The worlds of the comparisons of a program at an endpoint, by the names
         the grades compared mention: the classes of the declared operations
         are computed once per running times of a program, by their physical
         identity, and endpoint. *)
      let worlds =
        Memo.last (fun bounds ->
            Memo.by_identity (fun endpoint ->
                let running_time = running_time endpoint bounds in
                let classes =
                  classes DelaySet.equal_extremum running_time bounds.operations
                in
                let module Worlds = Memo.Make (World.NameList) in
                Worlds.memoise (fun mentioned ->
                    World.make (operations running_time classes mentioned))))

      (* [world endpoint bounds rhos] is the world of a comparison of the
         grades [rhos]: its operations, each with the extremal value of the
         [endpoint] of its running-time bounds as its running time, are the
         names [rhos] mention, and of the other declared operations, which
         [rhos] do not tell apart, the least name of each running time. *)

      let world endpoint bounds rhos =
        worlds bounds endpoint
          (List.sort_uniq String.compare (List.concat_map L.events rhos))

      (* The worlds of the joint decisions of a program, by the names the
         grades decided mention: as those of [worlds], the classes being those
         of equal pairs of the values of the ends of the running-time bounds,
         each attained, at the lower and at the upper ends. *)
      let joint_worlds =
        Memo.last (fun bounds ->
            let value endpoint name =
              DelaySet.Finite
                (end_value (endpoint (bounds.running_time name)), true)
            in
            let running_time name = (value fst name, value snd name) in
            let equal (lo, hi) (lo', hi') =
              DelaySet.equal_extremum lo lo' && DelaySet.equal_extremum hi hi'
            in
            let classes = classes equal running_time bounds.operations in
            let module Worlds = Memo.Make (World.NameList) in
            Worlds.memoise (fun mentioned ->
                let operations = operations running_time classes mentioned in
                ( World.make
                    (List.map (fun (name, (lo, _)) -> (name, lo)) operations),
                  World.make
                    (List.map (fun (name, (_, hi)) -> (name, hi)) operations) )))

      let consistent bounds lo hi =
        let lo_world, hi_world =
          joint_worlds bounds
            (List.sort_uniq String.compare (L.events lo @ L.events hi))
        in
        D.consistent lo_world hi_world lo hi

      let in_allowance = D.in_allowance
      let in_coverage = D.in_coverage
      let allowance = D.allowance
      let coverage = D.coverage

      let min_weight world rho =
        Option.map end_of_extremum (D.min_weight world rho)

      let max_weight world rho =
        Option.map end_of_extremum (D.max_weight world rho)

      (* The endpoint of running-time bounds at which every operation takes no
         time. *)
      let no_time (_ : running_time) = Closed Rational.zero
      let inhabited bounds rho = D.inhabited (world no_time bounds [ rho ]) rho
      let literal_of_word word = Braces (DelayRegex.of_word word)
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
