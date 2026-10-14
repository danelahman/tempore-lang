(* Prints the options of the run command in the header of the file given, on
   one line; with -grades, only the name of its grades. *)

let () =
  match Array.to_list Sys.argv with
  | [ _; "-grades"; path ] -> print_endline (TestSupport.Header.grades path)
  | [ _; path ] ->
      print_endline (String.concat " " (TestSupport.Header.run_options path))
  | _ ->
      prerr_endline "usage: header_options [-grades] FILE";
      exit 2
