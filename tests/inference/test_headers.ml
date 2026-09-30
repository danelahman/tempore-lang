(* Checks that every example under [examples/] opens with a header comment of
   the fixed shape:

     (* <summary of the example, on one or more lines>

        Run this example with the '<grade>' grading monoid, e.g.

          ./tempore --grades <grade> examples/<dir>/<file>.tpe

        Grades <form>: <meaning>
          - Unit <literal>: <meaning>
          - Top <literal>: <meaning>
          - Product: <formula or a few words> *)

   naming what the example is about, its grading monoid, the command that
   runs it, and its grades: what a grade denotes, and the unit, top and
   product of the monoid. Silent on success. *)

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

let ends_with ~suffix s = strip_suffix ~suffix s <> None

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

(* Checks that [line] is not [None], starts with [prefix], has non-empty
   content after it, does not end with " *)" unless [closing], and does not
   end with a period; [what] names the line in a failure. *)
let check_line name ~what ~prefix ?(closing = false) line =
  match line with
  | None -> fail "%s: is missing its %s" name what
  | Some line -> (
      match strip_prefix ~prefix line with
      | None -> fail "%s: expected %s to start with %S" name what prefix
      | Some rest ->
          let rest, is_closed =
            match strip_suffix ~suffix:" *)" rest with
            | Some rest -> (rest, true)
            | None -> (rest, false)
          in
          if String.trim rest = "" then
            fail "%s: its %s has no content after %S" name what prefix
          else if is_closed && not closing then
            fail "%s: its %s must not close the comment" name what
          else if (not is_closed) && closing then
            fail "%s: its %s must close the comment with \" *)\"" name what
          else if ends_with ~suffix:"." rest then
            fail "%s: its %s must not end with a period" name what)

(* Checks the header of the file at [path], displayed as [name] (its path
   relative to the project root, also the path the run command must show). *)
let check_header name path =
  let lines = In_channel.with_open_text path In_channel.input_lines in
  (* The number of lines continuing the line at [n], up to a blank line or a
     line satisfying [stop]. *)
  let rec continuation ?(stop = fun _ -> false) n =
    match List.nth_opt lines (n + 1) with
    | Some line when line <> "" && not (stop line) ->
        1 + continuation ~stop (n + 1)
    | _ -> 0
  in
  let summary = continuation 0 in
  let grades =
    continuation (6 + summary) ~stop:(String.starts_with ~prefix:"     - ")
  in
  let nth n =
    List.nth_opt lines
      (if n = 0 then 0 else if n <= 6 then n + summary else n + summary + grades)
  in
  (match nth 0 with
  | None -> fail "%s: is empty" name
  | Some line1 -> (
      match strip_prefix ~prefix:"(* " line1 with
      | None ->
          fail
            "%s: the header must start with \"(* \" followed by a summary of \
             the example"
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
      | Some grade ->
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
          | None -> fail "%s: is missing its grade description" name);
          (match nth 6 with
          | None -> fail "%s: is missing its \"Grades ...\" line" name
          | Some line7 -> (
              match strip_prefix ~prefix:"   Grades " line7 with
              | None ->
                  fail "%s: expected a \"   Grades <form>: ...\" line" name
              | Some rest ->
                  if not (String.length rest > 0 && String.contains rest ':')
                  then
                    fail
                      "%s: the \"Grades\" line needs a form and a meaning, \
                       separated by ':'"
                      name
                  else if ends_with ~suffix:" *)" rest then
                    fail
                      "%s: the \"Grades\" line must not close the comment; the \
                       unit, top and product bullets still follow"
                      name
                  else if ends_with ~suffix:"." rest then
                    fail "%s: the \"Grades\" line must not end with a period"
                      name));
          check_line name ~what:"'Unit' bullet" ~prefix:"     - Unit " (nth 7);
          check_line name ~what:"'Top' bullet" ~prefix:"     - Top " (nth 8);
          check_line name ~what:"'Product' bullet" ~prefix:"     - Product: "
            ~closing:true (nth 9))

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
