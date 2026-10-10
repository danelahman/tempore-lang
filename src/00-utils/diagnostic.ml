type kind = Syntax | Typing | Runtime | Fatal
type label = { span : Location.t; text : string }

type t = {
  kind : kind;
  primary : Location.t option;
  message : string;
  labels : label list;
  notes : string list;
}

let kind_to_string = function
  | Syntax -> "Syntax error"
  | Typing -> "Typing error"
  | Runtime -> "Run-time error"
  | Fatal -> "Fatal error"

let lines text = String.split_on_char '\n' text
let place = "{here}"

let render_label_text ~place:shown text =
  let n = String.length place and len = String.length text in
  let buffer = Buffer.create len in
  let rec matches_at i k =
    k >= n || (text.[i + k] = place.[k] && matches_at i (k + 1))
  in
  let rec go i =
    if i >= len then ()
    else if i + n <= len && matches_at i 0 then (
      Buffer.add_string buffer shown;
      go (i + n))
    else (
      Buffer.add_char buffer text.[i];
      go (i + 1))
  in
  go 0;
  Buffer.contents buffer

(* Backticks alternate between prose and code, so the pieces a split yields do
   too. An odd count leaves a piece with no closing backtick: it is prose, and
   keeps the backtick it opened with, as that is what a terminal shows. *)
let segments text =
  let rec go acc code = function
    | [] -> List.rev acc
    | [ last ] ->
        let last = if code then "`" ^ last else last in
        List.rev (if last = "" then acc else `Text last :: acc)
    | piece :: rest ->
        let acc =
          if piece = "" then acc
          else (if code then `Code piece else `Text piece) :: acc
        in
        go acc (not code) rest
  in
  go [] false (String.split_on_char '`' text)

(* The number of characters of the UTF-8 encoded [text] in the bytes from [from]
   to [until], a byte that decodes to no character counted as one. *)
let characters text from until =
  let rec go i count =
    if i >= until then count
    else
      let length = Uchar.utf_decode_length (String.get_utf_8_uchar text i) in
      go (i + length) (count + 1)
  in
  go from 0

(* The span's first line with carets under it, from the start of the span to
   its end or to the end of the line, whichever comes first. A multi-line span
   is marked on its first line only, as the compiler does it. Columns are
   counted in characters, so that the carets align under UTF-8 text. *)
let print_excerpt ~source (loc : Location.t) ppf =
  match source loc.filename with
  | None -> ()
  | Some text -> (
      match List.nth_opt (lines text) (loc.start.line - 1) with
      | None -> ()
      | Some line ->
          let width = String.length line in
          let from = min (loc.start.column - 1) width in
          let until =
            if loc.stop.line = loc.start.line then
              min (loc.stop.column - 1) width
            else width
          in
          let indent = characters line 0 from in
          let carets = max 1 (characters line from until) in
          let number = string_of_int loc.start.line in
          Format.fprintf ppf "%s | %s@\n%s   %s%s@\n" number line
            (String.make (String.length number) ' ')
            (String.make indent ' ') (String.make carets '^'))

let print_located ~source ~indent loc text ppf =
  (* Location, excerpt and text are indented by [indent] and by nothing else,
     so that the carets still line up with the source line above them. *)
  Format.fprintf ppf "%s%t:@\n" indent (Location.print loc);
  Format.fprintf ppf "%t" (fun ppf ->
      let buffer = Buffer.create 64 in
      let inner = Format.formatter_of_buffer buffer in
      print_excerpt ~source loc inner;
      Format.pp_print_flush inner ();
      List.iter
        (fun line ->
          if line <> "" then Format.fprintf ppf "%s%s@\n" indent line)
        (lines (Buffer.contents buffer)));
  match text with "" -> () | text -> Format.fprintf ppf "%s%s@\n" indent text

let print ?(source = fun _ -> None) d ppf =
  (match d.primary with
  | Some loc ->
      Format.fprintf ppf "%t:@\n" (Location.print loc);
      print_excerpt ~source loc ppf
  | None -> ());
  Format.fprintf ppf "%s: %s@\n" (kind_to_string d.kind) d.message;
  List.iter
    (fun { span; text } ->
      (* The excerpt of the span follows the label, so it can say "here". *)
      print_located ~source ~indent:"  " span
        (render_label_text ~place:"here" text)
        ppf)
    d.labels;
  List.iter (fun note -> Format.fprintf ppf "  Note: %s@\n" note) d.notes
