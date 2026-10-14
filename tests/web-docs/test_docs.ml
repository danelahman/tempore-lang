(* Tests of the pages of the documentation view of the web interface: the
   normalisation of relative paths, the targets of the links of each page, the
   files of the pages and the links of the main README to the backend pages.
   Silent on success. *)

open WebDocPages

let fail = TestSupport.Failures.fail

let show = function
  | Anchor id -> "Anchor " ^ id
  | Page (p, None) -> "Page " ^ label p
  | Page (p, Some id) -> "Page " ^ label p ^ "#" ^ id
  | Repository path -> "Repository " ^ path
  | External url -> "External " ^ url

let check_normalise base dest expected =
  let got = normalise ~base dest in
  if got <> expected then
    fail "normalise %s %s: %s, expected %s" base dest got expected

let check_resolve from dest expected =
  let got = resolve ~from dest in
  if got <> expected then
    fail "resolve %s %s: %s, expected %s" (label from) dest (show got)
      (show expected)

(* The destinations of the inline links of a Markdown source, read off every
   "](" up to the next ")". *)
let destinations source =
  let n = String.length source in
  let rec scan i acc =
    if i + 1 >= n then List.rev acc
    else if source.[i] = ']' && source.[i + 1] = '(' then
      match String.index_from_opt source (i + 2) ')' with
      | Some j -> scan (j + 1) (String.sub source (i + 2) (j - i - 2) :: acc)
      | None -> List.rev acc
    else scan (i + 1) acc
  in
  scan 0 []

let read path = In_channel.with_open_bin path In_channel.input_all
let root = "../../"

let () =
  (* normalisation *)
  check_normalise "README.md" "examples/a.tpe" "examples/a.tpe";
  check_normalise "src/b/arduino/README.md" "../../../examples/a.tpe"
    "examples/a.tpe";
  check_normalise "src/b/arduino/README.md" "boards/" "src/b/arduino/boards/";
  check_normalise "src/b/arduino/README.md" "./libraries/x.h"
    "src/b/arduino/libraries/x.h";
  check_normalise "src/b/README.md" "../../../../a" "a";
  check_normalise "src/b/README.md" "/LICENSE" "LICENSE";
  check_normalise "README.md" "a//b/./c/../d" "a/b/d";
  (* targets on the main page *)
  check_resolve Main "#backends" (Anchor "backends");
  check_resolve Main "https://tempore-lang.ee/"
    (External "https://tempore-lang.ee/");
  check_resolve Main "mailto:a@b" (External "mailto:a@b");
  check_resolve Main "examples/opentrons/elisa.tpe"
    (Repository "examples/opentrons/elisa.tpe");
  check_resolve Main "src/05-backends/arduino/README.md" (Page (Arduino, None));
  check_resolve Main
    "src/05-backends/opentrons/README.md#monitors-and-the-time-unit"
    (Page (Opentrons, Some "monitors-and-the-time-unit"));
  check_resolve Main "README.md#recursion" (Anchor "recursion");
  check_resolve Main "README.md" (Page (Main, None));
  (* targets on the backend pages *)
  check_resolve Arduino "#monitors" (Anchor "monitors");
  check_resolve Arduino "../../../examples/arduino/tilt/tilt.tpe"
    (Repository "examples/arduino/tilt/tilt.tpe");
  check_resolve Arduino "boards/" (Repository "src/05-backends/arduino/boards/");
  check_resolve Arduino "../../../README.md#backends"
    (Page (Main, Some "backends"));
  check_resolve Arduino "../opentrons/README.md" (Page (Opentrons, None));
  check_resolve Opentrons "../../../tests/make/examples.t#x"
    (Repository "tests/make/examples.t#x");
  (* the pages *)
  if List.hd all <> Main || List.length all <> 3 then
    fail "the pages: Main first, three in all";
  List.iter
    (fun p ->
      if not (Sys.file_exists (root ^ path p)) then
        fail "page %s: no file %s" (label p) (path p))
    all;
  (* the links of the main README to the backend pages *)
  let targets =
    List.map (resolve ~from:Main) (destinations (read (root ^ path Main)))
  in
  List.iter
    (fun p ->
      if not (List.mem (Page (p, None)) targets) then
        fail "Tempore: no link to the page %s" (label p))
    [ Arduino; Opentrons ]

let () = TestSupport.Failures.finish ()
