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
  | Repeat (r, c) -> DelaySet.repeat (delays r) c
  | Strict r -> DelaySet.inter (delays r) DelaySet.zero
  | (Below _ | Above _) as r -> one_sided_unsupported r

(* [letterless r] is whether [r] has no name, [_] or complement: its words are
   then single delays, those of [delays r]. *)
let rec letterless = function
  | Tick _ | Frac _ | Delays _ -> true
  | Seq (r, s) | Union (r, s) | Inter (r, s) -> letterless r && letterless s
  | Star r | Repeat (r, _) -> letterless r
  | Letter _ | Any | Compl _ | Strict _ | Below _ | Above _ -> false

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
  | Repeat (r, c) -> automaton (unrolled r c)
  | Strict _ as r -> strict_unsupported r
  | (Below _ | Above _) as r -> one_sided_unsupported r

let unions = function
  | [] -> None
  | r :: rs -> Some (List.fold_left (fun r s -> Union (r, s)) r rs)

(* [of_class c] is an expression of the one-operation words of [c]: a name, a
   union of names, or [_ & ~((0, ∞) | A | …)] for the names other than [A], …. *)
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

(* [is_name name c] is whether the class [c] is the one name [name]. *)
let is_name name (c : A.Class.t) =
  match c.names with
  | SymbolicRegex.Letters.Only [ n ] -> String.equal n name
  | _ -> false

let of_word word =
  let rec atoms = function
    | [] -> []
    | A.Operation c :: A.Delay d :: A.Operation c' :: word
      when is_name strict_opening c && is_name strict_closing c' ->
        Strict (rational_tick d) :: atoms word
    | A.Delay d :: word when Rational.sign d = 0 -> atoms word
    | A.Delay d :: word -> rational_tick d :: atoms word
    | A.Operation c :: word -> of_class c :: atoms word
  in
  sequence (atoms word)
