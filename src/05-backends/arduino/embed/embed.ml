(* The embedding of files in OCaml modules, as string literals.

   [embed value NAME FILE] prints the definition of [NAME] as the text of
   [FILE]; [embed files NAME PREFIX FILE...] prints the definition of [NAME]
   as the list of the paths of the files [FILE...], in order, each without the
   prefix [PREFIX] and with its text. *)

let read file = In_channel.with_open_bin file In_channel.input_all

let strip prefix path =
  if String.starts_with ~prefix path then
    String.sub path (String.length prefix)
      (String.length path - String.length prefix)
  else path

let () =
  match Array.to_list Sys.argv with
  | [ _; "value"; name; file ] -> Printf.printf "let %s = %S\n" name (read file)
  | _ :: "files" :: name :: prefix :: files ->
      Printf.printf "let %s =\n  [\n" name;
      List.iter
        (fun file ->
          Printf.printf "    (%S, %S);\n" (strip prefix file) (read file))
        (List.sort String.compare files);
      print_string "  ]\n"
  | _ ->
      prerr_endline
        "Usage: embed value NAME FILE | embed files NAME PREFIX FILE...";
      exit 2
