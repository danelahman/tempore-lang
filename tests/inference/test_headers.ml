(* Checks that every example under [examples/] opens with a header comment of
   the fixed shape:

     (* <one-line summary of the example>

        Run this example with the '<grade>' grading monoid, e.g.

          ./tempore --grades <grade> examples/<dir>/<file>.tpe

        <one or two description lines>. *)

   naming what the example is about, its grading monoid, the command that
   runs it, and a one- or two-line description of its grades. Silent on
   success. *)

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt

(* The '.tpe' files under [dir], recursing into subdirectories, each paired
   with its path relative to the project root (e.g. "examples/basics/nat.tpe"),
   sorted within its own directory. *)
let rec tpe_files ~label dir =
  Sys.readdir dir |> Array.to_list |> List.sort String.compare
  |> List.concat_map (fun name ->
      let path = Filename.concat dir name in
      let label = label ^ "/" ^ name in
      if Sys.is_directory path then tpe_files ~label path
      else if Filename.check_suffix name ".tpe" then [ (label, path) ]
      else [])

let strip_prefix ~prefix s =
  if
    String.length s >= String.length prefix
    && String.sub s 0 (String.length prefix) = prefix
  then
    Some
      (String.sub s (String.length prefix)
         (String.length s - String.length prefix))
  else None

let strip_suffix ~suffix s =
  let n = String.length s and m = String.length suffix in
  if n >= m && String.sub s (n - m) m = suffix then
    Some (String.sub s 0 (n - m))
  else None

(* The grade named between the first pair of single quotes in [line], the
   "Run this example ..." introduction. *)
let grade_of_intro line =
  match strip_prefix ~prefix:"   Run this example with the '" line with
  | None -> None
  | Some rest -> (
      match String.index_opt rest '\'' with
      | None -> None
      | Some i ->
          let grade = String.sub rest 0 i in
          let tail = String.sub rest i (String.length rest - i) in
          if tail = "' grading monoid, e.g." then Some grade else None)

let missing_description name =
  fail
    "%s: the header comment needs one or two lines describing the grades after \
     the run command"
    name

(* Checks the header of the file at [path], displayed as [name] (its path
   relative to the project root, also the path the run command must show). *)
let check_header name path =
  let lines = In_channel.with_open_text path In_channel.input_lines in
  let nth n = List.nth_opt lines n in
  (match nth 0 with
  | None -> fail "%s: is empty" name
  | Some line1 -> (
      match strip_prefix ~prefix:"(* " line1 with
      | None ->
          fail
            "%s: the header must start with \"(* \" followed by a one-line \
             summary of the example"
            name
      | Some about when String.trim about = "" ->
          fail "%s: the header's opening line is missing its summary" name
      | Some about -> (
          (match strip_suffix ~suffix:"*)" about with
          | Some _ ->
              fail
                "%s: the header's summary line must not close the comment; the \
                 run instructions and grade description still follow"
                name
          | None -> ());
          match nth 1 with
          | Some "" -> ()
          | _ -> fail "%s: expected a blank line after the summary line" name)));
  match nth 2 with
  | None -> fail "%s: is missing the run command" name
  | Some line3 -> (
      match grade_of_intro line3 with
      | None ->
          fail
            "%s: expected \"   Run this example with the '<grade>' grading \
             monoid, e.g.\" after the summary"
            name
      | Some grade -> (
          (match nth 3 with
          | Some "" -> ()
          | _ ->
              fail
                "%s: expected a blank line after the run-command introduction"
                name);
          let expected_command =
            Printf.sprintf "     ./tempore --grades %s %s" grade name
          in
          (match nth 4 with
          | Some line5 when line5 = expected_command -> ()
          | Some line5 ->
              fail "%s: expected the line %S, found %S" name expected_command
                line5
          | None -> fail "%s: is missing the run command" name);
          (match nth 5 with
          | Some "" -> ()
          | Some _ ->
              fail "%s: expected a blank line before the grade description" name
          | None -> missing_description name);
          match nth 6 with
          | None -> missing_description name
          | Some "" -> missing_description name
          | Some line7 -> (
              match strip_suffix ~suffix:" *)" line7 with
              | Some rest when String.trim rest <> "" ->
                  (* A single description line, already closed. *)
                  ()
              | _ -> (
                  (* The first of two description lines: not yet closed. *)
                  match nth 7 with
                  | None -> missing_description name
                  | Some "" -> missing_description name
                  | Some line8 -> (
                      match strip_suffix ~suffix:" *)" line8 with
                      | Some rest when String.trim rest <> "" -> ()
                      | _ ->
                          fail
                            "%s: the header comment's description must close \
                             with \" *)\" after at most two lines"
                            name)))))

let () =
  let root = "../.." in
  List.iter
    (fun (name, path) -> check_header name path)
    (tpe_files ~label:"examples" (Filename.concat root "examples"));
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
