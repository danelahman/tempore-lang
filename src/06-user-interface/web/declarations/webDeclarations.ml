type source = { filename : string; text : string }
type place = { filename : string; span : int * int; line : int; text : string }

(* Whether [line] continues the command of the line before it: it is not
   blank and starts with a blank. *)
let continues line =
  String.trim line <> ""
  && String.length line > 0
  && (line.[0] = ' ' || line.[0] = '\t')

(* The lines from the [n]th of [lines], from 1: that line and, if [more], the
   lines continuing it. *)
let command_lines ~more lines n =
  let rec continuation = function
    | line :: rest when continues line -> line :: continuation rest
    | _ -> []
  in
  match List.drop (n - 1) lines with
  | [] -> None
  | line :: rest ->
      Some
        (String.concat "\n"
           (String.trim line
           :: (if more then List.map String.trim (continuation rest) else [])))

let place sources (sort : Desugarer.References.sort)
    (definition : Utils.Location.t) =
  List.find_map
    (fun (source : source) ->
      if source.filename <> definition.filename then None
      else
        let line = definition.start.line in
        Option.map
          (fun text ->
            {
              filename = source.filename;
              span = (definition.start.offset, definition.stop.offset);
              line;
              text;
            })
          (command_lines ~more:(sort = Operation)
             (String.split_on_char '\n' source.text)
             line))
    sources

let package filename =
  match String.split_on_char '/' filename with
  | [ "libraries"; name; _ ] -> name
  | _ -> filename

let title sources =
  let packages =
    List.fold_left
      (fun acc (s : source) ->
        let p = package s.filename in
        if List.mem p acc then acc else acc @ [ p ])
      [] sources
  in
  "Package declarations: " ^ String.concat ", " packages
