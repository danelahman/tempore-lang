let words line = List.filter (( <> ) "") (String.split_on_char ' ' line)

(* The lines of the leading comment of [lines]: none unless the first line
   opens a comment, up to the first line that closes one. *)
let leading_comment = function
  | first :: _ as lines when String.starts_with ~prefix:"(*" first ->
      let rec upto = function
        | [] -> []
        | line :: rest ->
            line
            ::
            (if String.ends_with ~suffix:"*)" (String.trim line) then []
             else upto rest)
      in
      upto lines
  | _ -> []

let rec values option = function
  | o :: value :: rest when o = option -> value :: values option rest
  | _ :: rest -> values option rest
  | [] -> []

let options path option =
  In_channel.with_open_text path In_channel.input_lines
  |> leading_comment |> List.concat_map words |> values option

let grades path =
  match options path "--grades" with
  | name :: _ -> name
  | [] -> Grades.GradeRegistry.default_name

let run_options path =
  let all option = List.concat_map (fun v -> [ option; v ]) in
  [ "--grades"; grades path ]
  @ all "--package" (options path "--package")
  @ all "--board" (options path "--board")
