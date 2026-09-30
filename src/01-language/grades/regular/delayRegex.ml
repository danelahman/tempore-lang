open GradeLiteral
module A = DelayAutomaton

let any = A.union (A.delays DelaySet.positive) (A.operations A.Class.all)

(* [factors r] is the factors of the concatenations [r] is made of, in turn. *)
let rec factors = function Seq (r, s) -> factors r @ factors s | r -> [ r ]

let rec delays = function
  | Letter _ -> DelaySet.empty
  | Tick n -> DelaySet.point (Rational.of_int n)
  | Frac q -> DelaySet.point q
  | Delays (lo, hi) -> DelaySet.between lo hi
  | Any -> DelaySet.positive
  | Seq (r, s) -> DelaySet.sum (delays r) (delays s)
  | Union (r, s) -> DelaySet.union (delays r) (delays s)
  | Inter (r, s) -> DelaySet.inter (delays r) (delays s)
  | Compl r -> DelaySet.compl (delays r)
  | Star r -> DelaySet.star (delays r)

(* [letterless r] is whether [r] has no name, [_] or complement: its words are
   then single delays, those of [delays r]. *)
let rec letterless = function
  | Tick _ | Frac _ | Delays _ -> true
  | Seq (r, s) | Union (r, s) | Inter (r, s) -> letterless r && letterless s
  | Star r -> letterless r
  | Letter _ | Any | Compl _ -> false

(* A letterless expression is the single transition on its delays. *)
let rec automaton = function
  | Letter name -> A.operations (A.Class.name name)
  | Any -> any
  | (Tick _ | Frac _ | Delays _) as r -> A.delays (delays r)
  | Compl r -> A.compl (automaton r)
  | r when letterless r -> A.delays (delays r)
  | Seq _ as r -> A.concat_list (List.map automaton (factors r))
  | Union (r, s) -> A.union (automaton r) (automaton s)
  | Inter (r, s) -> A.inter (automaton r) (automaton s)
  | Star r -> A.star (automaton r)

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
                  (Delays (Open Rational.zero, Unbounded)
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
