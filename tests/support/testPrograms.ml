let rec tpe_files ?(recursive = true) dir =
  Sys.readdir dir |> Array.to_list |> List.sort String.compare
  |> List.concat_map (fun name ->
      let path = Filename.concat dir name in
      if Sys.is_directory path then if recursive then tpe_files path else []
      else if Filename.check_suffix name ".tpe" then [ path ]
      else [])

let grade_module name =
  match List.assoc_opt name Grades.GradeRegistry.grade_modules with
  | Some g -> g
  | None -> failwith ("unknown grades " ^ name)

let packages ~grades path =
  let module Package = ArduinoBackend.ArduinoPackage in
  let board = List.nth_opt (TestSupport.Header.options path "--board") 0 in
  TestSupport.Header.options path "--package"
  |> List.concat_map (fun name ->
      match
        Option.map (Package.files_for ~grades ?board) (Package.find name)
      with
      | Some (Ok files) ->
          List.map
            (fun (f : Package.file) -> (f.filename, f.text, f.running_times))
            files
      | Some (Error message) -> failwith message
      | None -> failwith ("unknown package " ^ name))

let corpus root =
  let entry ~packaged path =
    let grades = TestSupport.Header.grades path in
    (path, grades, if packaged then packages ~grades path else [])
  in
  List.map (entry ~packaged:true) (tpe_files (Filename.concat root "examples"))
  @ List.map (entry ~packaged:false)
      (tpe_files ~recursive:false (Filename.concat root "tests"))
