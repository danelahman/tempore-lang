type page = Main | Arduino | Opentrons

let all = [ Main; Arduino; Opentrons ]

let label = function
  | Main -> "Tempore"
  | Arduino -> "Arduino"
  | Opentrons -> "Opentrons"

let title = function
  | Main -> "Tempore"
  | Arduino -> "Arduino backend"
  | Opentrons -> "Opentrons backend"

let path = function
  | Main -> "README.md"
  | Arduino -> "src/05-backends/arduino/README.md"
  | Opentrons -> "src/05-backends/opentrons/README.md"

(* The segments of the directory of a file path, outermost first. *)
let directory base =
  match List.rev (String.split_on_char '/' base) with
  | _ :: dir -> List.rev dir
  | [] -> []

(* Removal of dot segments (RFC 3986, 5.2.4) over a stack of segments, the
   innermost on top. *)
let step stack = function
  | "" | "." -> stack
  | ".." -> ( match stack with _ :: rest -> rest | [] -> [])
  | segment -> segment :: stack

let normalise ~base dest =
  let start =
    if String.starts_with ~prefix:"/" dest then [] else directory base
  in
  let stack =
    List.fold_left step (List.rev start) (String.split_on_char '/' dest)
  in
  let joined = String.concat "/" (List.rev stack) in
  if String.ends_with ~suffix:"/" dest && joined <> "" then joined ^ "/"
  else joined

type target =
  | Anchor of string
  | Page of page * string option
  | Repository of string
  | External of string

let is_absolute dest =
  List.exists
    (fun scheme -> String.starts_with ~prefix:scheme dest)
    [ "http://"; "https://"; "mailto:" ]

(* A destination split at its first [#] into its path and its fragment. *)
let split dest =
  match String.index_opt dest '#' with
  | Some i ->
      ( String.sub dest 0 i,
        Some (String.sub dest (i + 1) (String.length dest - i - 1)) )
  | None -> (dest, None)

let resolve ~from dest =
  if is_absolute dest then External dest
  else
    match split dest with
    | "", Some id -> Anchor id
    | relative, fragment -> (
        let resolved = normalise ~base:(path from) relative in
        match (List.find_opt (fun p -> path p = resolved) all, fragment) with
        | Some p, Some id when p = from -> Anchor id
        | Some p, _ -> Page (p, fragment)
        | None, Some id -> Repository (resolved ^ "#" ^ id)
        | None, None -> Repository resolved)
