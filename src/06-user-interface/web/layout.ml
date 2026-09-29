(* Documents laid out within a width: Wadler's prettier printer (P. Wadler, "A
   prettier printer", 2003), in its strict form, with the alignment of Leijen's
   wl-pprint. Text is measured in characters, that is UTF-8 code points, each
   taken to fill one cell of a monospace font. *)

(** A document whose text is annotated by ['a]. *)
type 'a doc =
  | Text of 'a * string
  | Line  (** a space where its group is flat, a line break where it is not *)
  | Cat of 'a doc list
  | Nest of int * 'a doc  (** line breaks within indented further *)
  | Align of 'a doc  (** line breaks within indented to the current column *)
  | Group of 'a doc  (** flat where it fits on the rest of the line *)

type mode = Flat | Break

(* The number of characters of [s], its bytes other than continuation
   bytes. *)
let length s =
  String.fold_left
    (fun n c -> if Char.code c land 0xC0 = 0x80 then n else n + 1)
    0 s

(* Whether the items fit in [width] characters up to their first line
   break. *)
let rec fits width = function
  | _ when width < 0 -> false
  | [] -> true
  | (i, m, d) :: rest -> (
      match (d, m) with
      | Text (_, s), _ -> fits (width - length s) rest
      | Line, Flat -> fits (width - 1) rest
      | Line, Break -> true
      | Cat ds, _ -> fits width (List.map (fun d -> (i, m, d)) ds @ rest)
      | (Nest (_, d) | Align d), _ -> fits width ((i, m, d) :: rest)
      | Group d, _ -> fits width ((i, Flat, d) :: rest))

(** [layout ~width doc] is the lines of [doc] laid out within [width] characters
    where it can be, each a list of runs of text with their annotations, [None]
    for spaces and indentation. *)
let layout ~width doc =
  let finish line lines = List.rev line :: lines in
  let rec go column line lines = function
    | [] -> List.rev (finish line lines)
    | (i, m, d) :: rest -> (
        match (d, m) with
        | Text (a, s), _ ->
            go (column + length s) ((Some a, s) :: line) lines rest
        | Line, Flat -> go (column + 1) ((None, " ") :: line) lines rest
        | Line, Break ->
            go i [ (None, String.make i ' ') ] (finish line lines) rest
        | Cat ds, _ ->
            go column line lines (List.map (fun d -> (i, m, d)) ds @ rest)
        | Nest (j, d), _ -> go column line lines ((i + j, m, d) :: rest)
        | Align d, _ -> go column line lines ((column, m, d) :: rest)
        | Group d, Flat -> go column line lines ((i, Flat, d) :: rest)
        | Group d, Break ->
            let m' =
              if fits (width - column) ((i, Flat, d) :: rest) then Flat
              else Break
            in
            go column line lines ((i, m', d) :: rest))
  in
  go 0 [] [] [ (0, Break, doc) ]
