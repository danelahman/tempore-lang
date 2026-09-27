open Grade
module R = SymbolicRegex
module Letters = SymbolicRegex.Letters

type t = R.t

let name = "traces-regex-symbolic"
let tick = R.letters Letters.tick

let ticks n =
  List.fold_left (fun r _ -> R.concat tick r) R.eps (List.init n Fun.id)

let rec of_regex = function
  | Letter name -> R.letters (Letters.name name)
  | Tick n -> ticks n
  | Any -> R.letters Letters.any
  | Seq (r, s) -> R.concat (of_regex r) (of_regex s)
  | Union (r, s) -> R.union [ of_regex r; of_regex s ]
  | Inter (r, s) -> R.inter [ of_regex r; of_regex s ]
  | Star r -> R.star (of_regex r)
  | Compl r -> R.compl (of_regex r)

let one = R.eps
let mul = R.concat
let join rho rho' = R.union [ rho; rho' ]
let top = R.top
let leq _bounds = R.subset
let leq_symbol = "<="
let equal _bounds = R.equal
let of_nat n = ticks (check_nat "RegularTraceGradeDerivative" n)
let unit_least = false
let commutative = false
let needs_op_bounds = false
let implied_bounds _bounds _rho = None
let events = R.names

(* The delays of [lo] to [hi] time steps. *)
let of_bounds (lo, hi) =
  R.union (List.init (max 1 (hi - lo + 1)) (fun k -> ticks (lo + k)))

let is_atomic name rho = R.equal rho (R.letters (Letters.name name))

(** [representative m] is the least letter of the block [m] of minterms: [tick],
    else its least name, else the block itself, the names the grades compared do
    not mention. *)
let representative (m : Letters.t) =
  match m with
  | { tick = true; _ } -> Letters.tick
  | { names = Only (name :: _); _ } -> Letters.name name
  | m -> m

let counterexample _bounds rho rho' =
  Option.map
    (List.fold_left
       (fun r m -> R.concat r (R.letters (representative m)))
       R.eps)
    (R.shortest (R.inter [ rho; R.compl rho' ]))

let of_lit = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> of_nat n
  | Top -> top
  | Braces r as lit ->
      let rho = of_regex r in
      if R.is_empty rho then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else rho
  | lit ->
      invalid_lit lit
        "grades are regular expressions '{...}', plain integers or '⊤', not %s"
        (describe_lit lit)

(** {1 Printing} *)

(** The number of derivatives beyond which a grade is printed as its normal
    form, without building its automaton. *)
let derivatives_limit = 256

(* The printed grades, by the number of their normal forms. *)
let printed : (int, string) Hashtbl.t = Hashtbl.create 64

(** [print rho] is [rho] in the literal syntax. *)
let print rho =
  let normal_form = LetterRegex.of_symbolic rho in
  match SymbolicAutomaton.of_regex ~limit:derivatives_limit rho with
  | Some a -> SymbolicAutomaton.show ~others:[ normal_form ] a
  | None when R.is_empty (R.compl rho) -> "⊤"
  | None -> "{" ^ LetterRegex.to_string normal_form ^ "}"

let show rho =
  match Hashtbl.find_opt printed (R.hash rho) with
  | Some text -> text
  | None ->
      let text = print rho in
      Hashtbl.add printed (R.hash rho) text;
      text
