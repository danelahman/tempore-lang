open GradeLiteral
module A = TimedAutomaton

let any = A.union (A.delays DelaySet.positive) (A.operations A.Class.all)

let rec automaton = function
  | Letter name -> A.operations (A.Class.name name)
  | Tick n -> A.delays (DelaySet.point (Rational.of_int n))
  | Frac q -> A.delays (DelaySet.point q)
  | Compare (c, q) -> A.delays (DelaySet.compare_with c q)
  | Any -> any
  | Seq (r, s) -> A.concat (automaton r) (automaton s)
  | Union (r, s) -> A.union (automaton r) (automaton s)
  | Inter (r, s) -> A.inter (automaton r) (automaton s)
  | Compl r -> A.compl (automaton r)
  | Star r -> A.star (automaton r)

let rec delays = function
  | Letter _ -> DelaySet.empty
  | Tick n -> DelaySet.point (Rational.of_int n)
  | Frac q -> DelaySet.point q
  | Compare (c, q) -> DelaySet.compare_with c q
  | Any -> DelaySet.positive
  | Seq (r, s) -> DelaySet.sum (delays r) (delays s)
  | Union (r, s) -> DelaySet.union (delays r) (delays s)
  | Inter (r, s) -> DelaySet.inter (delays r) (delays s)
  | Compl r -> DelaySet.compl (delays r)
  | Star r -> DelaySet.star (delays r)

let unions = function
  | [] -> None
  | r :: rs -> Some (List.fold_left (fun r s -> Union (r, s)) r rs)

let of_class (c : A.Class.t) =
  match c.names with
  | SymbolicRegex.Letters.Only names ->
      Option.value
        (unions (List.map (fun n -> Letter n) names))
        ~default:(Compl (Star Any))
  | SymbolicRegex.Letters.Except names ->
      Inter
        ( Any,
          Compl
            (Option.get
               (unions
                  (Compare (Gt, Rational.zero)
                  :: List.map (fun n -> Letter n) names))) )

let of_word word =
  let atoms =
    List.filter_map
      (function
        | A.Delay d when Rational.sign d = 0 -> None
        | A.Delay d -> Some (rational_tick d)
        | A.Operation c -> Some (of_class c))
      word
  in
  match atoms with
  | [] -> Tick 0
  | r :: rs -> List.fold_left (fun r s -> Seq (r, s)) r rs
