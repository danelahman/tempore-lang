open GradeLiteral

module type EXPRESSION = sig
  type t

  val eps : t
  val name : string -> t
  val operations : t
  val delay : t
  val positive : t
  val of_delays : regex -> t
  val nullable : t -> bool
  val concat : t -> t -> t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t
  val star : t -> t
  val repeat : t -> Count.t -> t
end

module Make (E : EXPRESSION) = struct
  let strict s =
    let encoded s =
      E.concat (E.name strict_opening) (E.concat s (E.name strict_closing))
    in
    if E.nullable s then
      E.union [ encoded (E.inter [ s; E.compl E.eps ]); E.eps ]
    else encoded s

  (* The one-symbol words of [!_]: operations and strict delays. *)
  let strict_any = E.union [ E.operations; strict E.positive ]
  let words = E.star (E.union [ E.delay; E.operations; strict E.positive ])

  let rec of_regex = function
    | Letter n -> E.name n
    | (Tick _ | Frac _ | Delays _) as r -> E.of_delays r
    | Any -> E.union [ E.delay; strict_any ]
    | Strict Any -> strict_any
    | Strict r -> strict (E.of_delays r)
    | Seq (r, s) -> E.concat (of_regex r) (of_regex s)
    | Union (r, s) -> E.union [ of_regex r; of_regex s ]
    | Inter (r, s) -> E.inter [ of_regex r; of_regex s ]
    | Star r -> E.star (of_regex r)
    | Repeat (r, c) -> E.repeat (of_regex r) c
    | Compl r -> E.inter [ words; E.compl (of_regex r) ]
    | (Below _ | Above _) as r -> one_sided_unsupported r
end

module type GRADE = sig
  type grade
  type delay

  val of_lit : lit -> grade
  val accepts : lit -> bool
  val of_delay : delay -> grade
  val top : grade
end

module Without (L : Grade.S) = struct
  type grade = L.t
  type delay = L.Delay.t

  let of_lit = L.of_lit
  let accepts = L.accepts
  let of_delay = L.of_delay
  let top = L.top
end

let has_markers = List.exists is_marker
let operations = List.filter (fun name -> not (is_marker name))
let markers = List.sort String.compare [ strict_opening; strict_closing ]
