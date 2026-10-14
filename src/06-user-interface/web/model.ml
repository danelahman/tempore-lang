module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
include ModelTypes

let indentation = "  "

let byte_offset source offset =
  let length = String.length source in
  let rec go byte units =
    if units >= offset || byte >= length then byte
    else
      let lead = Char.code source.[byte] in
      let width =
        if lead < 0x80 then 1
        else if lead < 0xE0 then 2
        else if lead < 0xF0 then 3
        else 4
      in
      (* outside the basic plane: a surrogate pair, so two code units *)
      go (byte + width) (units + if width = 4 then 2 else 1)
  in
  go 0 0

let edit_update edit_model = function
  | UseStdlib use_stdlib -> { edit_model with use_stdlib }
  | ChangeSource input -> { edit_model with unparsed_code = input }
  | InsertIndent (source, start, stop) ->
      let start = byte_offset source start and stop = byte_offset source stop in
      let before = String.sub source 0 start
      and after = String.sub source stop (String.length source - stop) in
      { edit_model with unparsed_code = before ^ indentation ^ after }
  | LoadExample (group, e) ->
      (* Loading an example selects its grades and its backend, its settings
         replacing those of the backend. *)
      {
        edit_model with
        unparsed_code = e.source;
        selected_grades = e.grade;
        selected_example = Some (group, e.title);
        selected_backend = e.backend;
        backend_settings =
          (e.backend, e.settings)
          :: List.remove_assoc e.backend edit_model.backend_settings;
      }
  | SelectGrades name -> { edit_model with selected_grades = name }
  | SelectBackend key -> { edit_model with selected_backend = key }
  | SetInput (key, value) ->
      let backend = edit_model.selected_backend in
      let settings =
        Option.value ~default:[]
          (List.assoc_opt backend edit_model.backend_settings)
      in
      {
        edit_model with
        backend_settings =
          (backend, (key, value) :: List.remove_assoc key settings)
          :: List.remove_assoc backend edit_model.backend_settings;
      }

let backend edit_model =
  Option.value ~default:BackendRegistry.default
    (BackendRegistry.find edit_model.selected_backend)

let settings edit_model =
  Option.value ~default:[]
    (List.assoc_opt edit_model.selected_backend edit_model.backend_settings)

let example_of_path path =
  List.find_map
    (fun (g : Examples_tpe.group) ->
      Option.map
        (fun (e : Examples_tpe.example) -> (g.label, e))
        (List.find_opt
           (fun (e : Examples_tpe.example) -> e.path = path)
           g.examples))
    Examples_tpe.examples

(* The group label and the bundled example in the group of label [group] with
   title [title], if there is one. *)
let example_of_title group title =
  Option.bind
    (List.find_opt
       (fun (g : Examples_tpe.group) -> g.label = group)
       Examples_tpe.examples)
    (fun (g : Examples_tpe.group) ->
      Option.map
        (fun e -> (g.label, e))
        (List.find_opt
           (fun (e : Examples_tpe.example) -> e.title = title)
           g.examples))

(* The group label and the example the manifest names as the default of the
   backend [key], if it names one. *)
let default_example key =
  Option.bind (List.assoc_opt key Examples_tpe.defaults) example_of_path

(* The editor as the page opens: the manifest's default example loaded, its
   grades selected. *)
let edit_init =
  let empty =
    {
      use_stdlib = true;
      unparsed_code = "";
      selected_grades = Grades.GradeRegistry.default_name;
      selected_example = None;
      selected_backend = BackendRegistry.default.key;
      backend_settings = [];
    }
  in
  match example_of_path Examples_tpe.default with
  | Some (group, e) -> edit_update empty (LoadExample (group, e))
  | None -> empty

let choices edit_model =
  {
    WebChoices.use_stdlib = edit_model.use_stdlib;
    example =
      Option.map
        (fun (group, title) ->
          {
            WebChoices.path =
              Option.fold ~none:""
                ~some:(fun (_, (e : Examples_tpe.example)) -> e.path)
                (example_of_title group title);
            group;
            title;
          })
        edit_model.selected_example;
    grade = Some edit_model.selected_grades;
    backend = Some edit_model.selected_backend;
    settings = edit_model.backend_settings;
  }

(* The bundled examples, as the parameters of the page's address name them. *)
let catalogue =
  let entry (group, (e : Examples_tpe.example)) =
    {
      WebLink.example = { WebChoices.path = e.path; group; title = e.title };
      grade = e.grade;
      backend = e.backend;
    }
  in
  {
    WebLink.find = (fun path -> Option.map entry (example_of_path path));
    default_of = (fun key -> Option.map entry (default_example key));
  }

(* The query of the page's address naming the example, the grades and the
   backend of [edit_model], and the line [line] of the example. *)
let link ?line edit_model =
  WebLink.serialise
    { (WebLink.of_choices catalogue (choices edit_model)) with line }

(* Whether the editor's text is the example last loaded, unedited. *)
let unedited edit_model =
  match edit_model.selected_example with
  | Some (group, title) -> (
      match example_of_title group title with
      | Some (_, e) -> String.equal e.source edit_model.unparsed_code
      | None -> false)
  | None -> false

(* The editor as the page opens with the choices [c] restored: the example
   loaded first, as it sets the grades, the backend and its inputs, which the
   remembered ones then override. The backend is selected without its default
   example. *)
let restore_edit (c : WebChoices.t) =
  let c = WebChoices.sanitise c in
  let loaded =
    Option.fold ~none:edit_init
      ~some:(fun (group, e) -> edit_update edit_init (LoadExample (group, e)))
      (Option.bind c.example (fun (e : WebChoices.example) ->
           match example_of_path e.path with
           | Some found -> Some found
           | None -> example_of_title e.group e.title))
  in
  let edit_model =
    List.fold_left edit_update
      { loaded with use_stdlib = c.use_stdlib }
      (List.filter_map Fun.id
         [
           Option.map (fun g -> SelectGrades g) c.grade;
           Option.map (fun b -> SelectBackend b) c.backend;
         ])
  in
  {
    edit_model with
    backend_settings =
      c.settings
      @ List.filter
          (fun (b, _) -> not (List.mem_assoc b c.settings))
          edit_model.backend_settings;
  }

let run_init current =
  { current; history = []; selected_step_index = None; random_step_size = 1 }

let run_model_make_step (run_model : run_model) (step : concrete_step) =
  {
    run_model with
    current = step.next_state ();
    history = run_model.current :: run_model.history;
  }

let rec run_model_make_random_steps (run_model : run_model) num_steps =
  match (num_steps, run_model.current.steps) with
  | 0, _ | _, [] -> run_model
  | _, steps ->
      let i = Random.int (List.length steps) in
      let step = List.nth steps i in
      let run_model' = run_model_make_step run_model step in
      run_model_make_random_steps run_model' (num_steps - 1)

let run_update (run_model : run_model) = function
  | SelectStepIndex selected_step_index ->
      { run_model with selected_step_index }
  | MakeStep step -> run_model_make_step run_model step
  | RandomStep ->
      run_model_make_random_steps run_model run_model.random_step_size
  | Back -> (
      match run_model.history with
      | current' :: history' ->
          { run_model with current = current'; history = history' }
      | _ -> run_model)
  | ChangeRandomStepSize random_step_size -> { run_model with random_step_size }

(* The declarations the selected backend loads before the program under its
   inputs and the grades selected, or else why it cannot load them. *)
let declarations edit_model =
  (backend edit_model).declarations (settings edit_model)
    ~grades:edit_model.selected_grades

(* The declarations of [edit_model] shown above the program, none where they
   cannot be loaded; [shown] is kept while they equal it, so that their view
   is drawn again only when they change. *)
let shown_declarations ~shown edit_model =
  let sources =
    match declarations edit_model with
    | Ok sources ->
        List.map
          (fun (s : BackendRegistry.source) ->
            { WebDeclarations.filename = s.filename; text = s.text })
          sources
    | Error _ -> []
  in
  if sources = shown then shown else sources

let init =
  {
    edit_model = edit_init;
    run_model = Error [];
    error_view =
      { active_error = None; hovered_error = None; stale_errors = false };
    status = { checking = None; last_check = None; abbreviated = false };
    checked = { definitions = []; links = []; accepted = None; declared = [] };
    navigation =
      {
        page = Editor;
        docs_page = WebDocPages.Main;
        docs_heading = None;
        gallery = None;
        gallery_group = None;
      };
    popovers =
      {
        popover = None;
        columns = None;
        pointer = Nowhere;
        caret_target = None;
        timer = 0;
        closing = false;
        link = None;
      };
    compilation =
      {
        compiled = None;
        compile_serial = 0;
        reports_compilation = false;
        code_view = Source;
      };
    declarations =
      {
        shown_declarations = shown_declarations ~shown:[] edit_init;
        declarations_open = false;
      };
    notices =
      { flash = None; flash_serial = 0; notice = None; notice_serial = 0 };
  }

(* An error that is not a diagnostic of its own, such as an exception escaping
   the interpreter: there is nothing to point at, only what went wrong. *)
let fatal message =
  {
    diagnostic =
      {
        Diagnostic.kind = Fatal;
        primary = None;
        message;
        labels = [];
        notes = [];
      };
    hovered_label = None;
  }

(* Whether an edit moves the text that the reported errors point into. *)
let edits_source = function
  | ChangeSource _ | InsertIndent _ | LoadExample _ -> true
  | UseStdlib _ | SelectGrades _ | SelectBackend _ | SetInput _ -> false

(* Whether an edit changes the program or the options it is checked under. *)
let edits_program = function
  | ChangeSource _ | InsertIndent _ | LoadExample _ | UseStdlib _
  | SelectGrades _ ->
      true
  | SelectBackend _ | SetInput _ -> false

(* How long the inputs of a backend rest before the program is compiled with
   them, in milliseconds. *)
let compile_delay = 300

(* Whether the program, unchanged since its last check, was checked with
   other declarations than those the selected backend now loads, and must be
   checked again. *)
let declarations_changed model =
  (match model.status.last_check with
    | Some check -> check.current
    | None -> false)
  &&
  match declarations model.edit_model with
  | Ok sources -> sources <> model.checked.declared
  | Error _ -> true

(* The program as last accepted, compiled by the selected backend with its
   inputs; [None] without an accepted program or a compiler. An exception
   escaping the compiler is reported as its error. *)
let compile model =
  match (model.checked.accepted, (backend model.edit_model).compiler) with
  | Some accepted, Some compiler ->
      let refused text diagnostic =
        {
          BackendRegistry.code = None;
          language = "";
          messages = [ { severity = BackendRegistry.Error; text; diagnostic } ];
        }
      in
      let output =
        try accepted compiler (settings model.edit_model) with
        | Error.Error d ->
            refused
              (String.trim (Format.asprintf "%t" (Diagnostic.print d)))
              (Some d)
        | exn -> refused (Printexc.to_string exn) None
      in
      Some { output; up_to_date = true }
  | _ -> None

(* The errors and the warnings of a compilation, reported as those of a
   check: the diagnostic of each, or else a diagnostic of its text alone. *)
let compilation_errors = function
  | None -> []
  | Some { output; _ } ->
      List.filter_map
        (fun (m : BackendRegistry.message) ->
          let reported kind =
            let diagnostic =
              Option.value m.diagnostic
                ~default:
                  {
                    Diagnostic.kind;
                    primary = None;
                    message = m.text;
                    labels = [];
                    notes = [];
                  }
            in
            Some { diagnostic; hovered_label = None }
          in
          match m.severity with
          | BackendRegistry.Error -> reported Compilation
          | Warning -> reported Warning
          | Note -> None)
        output.messages

let is_warning (error : load_error) = error.diagnostic.kind = Diagnostic.Warning

(* The numbers of errors and of warnings of [reported]. *)
let counted reported =
  let warnings = List.length (List.filter is_warning reported) in
  (List.length reported - warnings, warnings)

(* The first error whose primary span covers [offset], a byte of the editor's
   text. A point span is widened as the editor widens it when marking it. *)
let error_at errors offset =
  let covers (error : load_error) =
    match error.diagnostic.primary with
    | Some { filename = ""; start; stop } ->
        start.offset <= offset && offset <= max stop.offset (start.offset + 1)
    | _ -> false
  in
  List.find_index covers errors

(* Whether a byte of the source falls in the bytes [start, stop), a point span
   widened to the byte it points at. *)
let within offset start stop = start <= offset && offset < max stop (start + 1)

(* The popover target at [offset], a byte of the editor's text: a label of an
   error, the primary span of one, the name of a definition, or a name defined
   in the declarations loaded before the program, in this order of
   precedence, the first found of each. *)
let target_at errors definitions links offset =
  let covers (loc : Location.t) =
    loc.filename = "" && within offset loc.start.offset loc.stop.offset
  in
  let label =
    List.find_map Fun.id
      (List.mapi
         (fun i (error : load_error) ->
           Option.map
             (fun j -> Error_label (i, j))
             (List.find_index
                (fun (label : Diagnostic.label) -> covers label.span)
                error.diagnostic.labels))
         errors)
  and primary =
    Option.map
      (fun i -> Error_span i)
      (List.find_index
         (fun (error : load_error) ->
           Option.fold ~none:false ~some:covers error.diagnostic.primary)
         errors)
  and definition =
    Option.map
      (fun k -> Definition k)
      (List.find_index
         (fun d ->
           match d.name_span with
           | Some (start, stop) -> within offset start stop
           | None -> false)
         definitions)
  and declared =
    Option.map
      (fun k -> Reference k)
      (List.find_index
         (fun { use = start, stop; destination } ->
           match destination with
           | In_declarations _ -> within offset start stop
           | In_editor _ | In_library _ -> false)
         links)
  in
  match (label, primary, definition) with
  | Some _, _, _ -> label
  | None, Some _, _ -> primary
  | None, None, Some _ -> definition
  | None, None, None -> declared

(* [one_line print] is the text [print] prints, each line break a space and no
   break made for the margin's sake. *)
let one_line print =
  let buffer = Buffer.create 64 in
  let ppf = Format.formatter_of_buffer buffer in
  Format.pp_set_formatter_out_functions ppf
    {
      (Format.pp_get_formatter_out_functions ppf ()) with
      out_newline = (fun () -> Buffer.add_char buffer ' ');
      out_indent = ignore;
    };
  Format.pp_set_geometry ppf ~max_indent:999_990 ~margin:1_000_000;
  print ppf;
  Format.pp_print_flush ppf ();
  Buffer.contents buffer

(* The bytes of [name] where the command at [offset] of [source] defines it:
   after [let] and an optional [rec], blanks and comments skipped. *)
let defined_name source offset name =
  let n = String.length source in
  let rec blank i =
    if i < n && String.contains " \t\r\n" source.[i] then blank (i + 1)
    else if i + 1 < n && source.[i] = '(' && source.[i + 1] = '*' then
      blank (comment (i + 2) 1)
    else i
  and comment i depth =
    if depth = 0 || i + 1 >= n then i
    else if source.[i] = '(' && source.[i + 1] = '*' then
      comment (i + 2) (depth + 1)
    else if source.[i] = '*' && source.[i + 1] = ')' then
      comment (i + 2) (depth - 1)
    else comment (i + 1) depth
  in
  let word w i =
    let stop = i + String.length w in
    let ident = function
      | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true
      | _ -> false
    in
    if
      stop <= n
      && String.sub source i (String.length w) = w
      && (stop = n || not (ident source.[stop]))
    then Some stop
    else None
  in
  Option.bind
    (word "let" (blank offset))
    (fun i ->
      let i = blank i in
      let i = Option.fold ~none:i ~some:blank (word "rec" i) in
      Option.map (fun stop -> (i, stop)) (word name i))

(* The popover closed, with no target under the pointer or the caret. *)
let without_popover model =
  let popovers = model.popovers in
  {
    model with
    popovers =
      {
        popovers with
        popover = None;
        pointer = Nowhere;
        caret_target = None;
        timer = popovers.timer + 1;
        closing = false;
      };
  }

(* The errors shown, none of them singled out by the caret or the pointer. *)
let unselected error_view =
  { error_view with active_error = None; hovered_error = None }

(* The notices, nothing highlighted. *)
let unflashed notices = { notices with flash = None }

(* The text of [scheme], split into its parts by [scheme_layout]. The printers
   name the unknowns as they meet them, so they are applied in order. *)
let scheme_text ~scheme_layout scheme =
  let ({ parameters; conjuncts; arrows } : Inference.Constraint.layout) =
    scheme_layout scheme
  in
  let parameters = Option.map one_line parameters in
  let conjuncts =
    List.map
      (function
        | Inference.Constraint.Formula part -> Formula (one_line part)
        | Inference.Constraint.Ordering { binder; left; right } ->
            let binder = Option.map one_line binder in
            let left = one_line left in
            let right = one_line right in
            Ordering { binder; left; right })
      conjuncts
  in
  let arrows = Language.PrettyPrint.map_arrows one_line arrows in
  { parameters; conjuncts; arrows }

(* The definitions of the editor's program among [definitions], each a
   variable, the location of its command and its scheme, with the text of the
   scheme and the place in [source] the command names it at. *)
let defined ~source ~name ~scheme_layout definitions =
  List.filter_map
    (fun (variable, (at : Location.t), scheme) ->
      if at.filename <> "" then None
      else
        let name = name variable in
        Some
          {
            name;
            scheme = scheme_text ~scheme_layout scheme;
            name_span = defined_name source at.start.offset name;
          })
    definitions

(* [within_span span loc] is whether the span [loc] lies in the span [span]. *)
let within_span (span : Location.t) (loc : Location.t) =
  span.filename = loc.filename
  && span.start.offset <= loc.start.offset
  && loc.stop.offset <= span.stop.offset

(* The links of the names of the editor's program among [links], each to a
   definition in the editor, in the standard library, whose source is
   [library] and whose top-level definitions are [library_definitions], or in
   the sources [declarations] loaded before the program, whose top-level
   definitions are among [definitions]; definitions are given as a variable,
   the location of its command and its scheme. *)
let linked ~library ~library_definitions ~declarations ~definitions ~name
    ~scheme_layout (links : Desugarer.References.link list) =
  let lines = lazy (String.split_on_char '\n' library) in
  (* the top-level value among [definitions] whose command covers
     [definition] *)
  let value definitions (definition : Location.t) = function
    | Desugarer.References.Value ->
        List.find_map
          (fun (variable, at, scheme) ->
            if within_span at definition then
              Some
                {
                  name = name variable;
                  scheme = scheme_text ~scheme_layout scheme;
                  name_span = None;
                }
            else None)
          definitions
    | Constructor | Type | Operation -> None
  in
  let entry (definition : Location.t) sort =
    let line = definition.start.line in
    Option.map
      (fun text ->
        In_library
          { line; text; value = value library_definitions definition sort })
      (List.nth_opt (Lazy.force lines) (line - 1))
  in
  let declared (definition : Location.t) sort =
    Option.map
      (fun place ->
        In_declarations { place; defined = value definitions definition sort })
      (WebDeclarations.place declarations sort definition)
  in
  List.filter_map
    (fun ({ use; definition; sort } : Desugarer.References.link) ->
      let destination =
        if use.filename <> "" then None
        else if definition.filename = "" then
          Some (In_editor (definition.start.offset, definition.stop.offset))
        else if definition.filename = Loader.stdlib_filename then
          entry definition sort
        else declared definition sort
      in
      Option.map
        (fun destination ->
          { use = (use.start.offset, use.stop.offset); destination })
        destination)
    links

let link_at links offset =
  List.find_index
    (fun { use = start, stop; _ } -> start <= offset && offset <= stop)
    links

(* [utf16_offset source byte] is the offset of the browser's UTF-16 code units
   at the byte [byte] of [source], the inverse of [byte_offset]. *)
let utf16_offset source byte =
  let rec go i units =
    if i >= byte || i >= String.length source then units
    else
      let lead = Char.code source.[i] in
      if lead < 0x80 then go (i + 1) (units + 1)
      else if lead < 0xE0 then go (i + 2) (units + 1)
      else if lead < 0xF0 then go (i + 3) (units + 1)
      else go (i + 4) (units + 2)
  in
  go 0 0

(* The model with the code [compiled]. Where the errors reported are those of
   the compilation, the errors of [compiled] replace them, unless they are the
   same, and the outcome of the check counts them. *)
let recompiled model compiled =
  let model =
    { model with compilation = { model.compilation with compiled } }
  in
  let errors = compilation_errors compiled in
  let diagnostics = List.map (fun (e : load_error) -> e.diagnostic) in
  match model.run_model with
  | Error reported
    when model.compilation.reports_compilation
         && diagnostics reported <> diagnostics errors ->
      let model = without_popover model in
      {
        model with
        run_model = Error errors;
        error_view = unselected model.error_view;
        notices = unflashed model.notices;
        status =
          {
            model.status with
            last_check =
              Option.map
                (fun check ->
                  let errors, warnings = counted errors in
                  { check with errors; warnings })
                model.status.last_check;
          };
      }
  | _ -> model

(* What the program was undergoing when an exception was raised. *)
type stage = Checking | Running

(* [errors_of_exception stage exn] is the errors reported for the exception
   [exn] raised at [stage]: the diagnostic of an error of the language, a
   run-time error among them, and a fatal error otherwise. *)
let errors_of_exception stage exn =
  match exn with
  | Error.Error diagnostic -> [ { diagnostic; hovered_label = None } ]
  | Invalid_argument message -> [ fatal message ]
  | Stack_overflow -> (
      match stage with
      | Checking ->
          [
            fatal
              "The available stack was exhausted while checking this program, \
               e.g. by a grade too large to decide under this grading monoid";
          ]
      | Running ->
          [
            fatal "The available stack was exhausted while running this program";
          ])
  | exn -> [ fatal (Printexc.to_string exn) ]

(* How long the confirmation of a copied link is shown, in milliseconds. *)
let notice_duration = 2000

(* The notice [notice] shown, replacing any earlier one; the confirmation of a
   copied link for a while only. *)
let notify model notice =
  let notice_serial = model.notices.notice_serial + 1 in
  ( {
      model with
      notices = { model.notices with notice = Some notice; notice_serial };
    },
    match notice with
    | Link_copied -> [ After (notice_duration, Unnotice notice_serial) ]
    | Ignored _ | Copy_failed _ -> [] )

(* How long the pointer rests on a span before its popover opens, and how long
   the popover outlasts the pointer's leaving, in milliseconds: the latter lets
   the pointer cross the gap to the card. *)
let open_delay = 250
let close_delay = 150

(* The popovers with [f] applied. *)
let map_popovers f model = { model with popovers = f model.popovers }

(* A new timer, superseding any other. *)
let arm ~closing delay model =
  let timer = model.popovers.timer + 1 in
  ( map_popovers (fun p -> { p with timer; closing }) model,
    [ After (delay, Elapsed timer) ] )

(* No timer. *)
let disarm =
  map_popovers (fun p -> { p with timer = p.timer + 1; closing = false })

(* The popover of [target] open without delay, to be measured once drawn. *)
let show ?point target model =
  ( map_popovers
      (fun p ->
        {
          p with
          popover = Some { target; point; shown = true; placement = None };
        })
      (disarm model),
    [ Measure_popover ] )

let close model =
  map_popovers (fun p -> { p with popover = None }) (disarm model)

(* How long what has been gone to stays highlighted, in milliseconds, as long
   as the page's highlight fades: a span of the editor, an error's message, or
   a line the page's address names. *)
let flash_duration = function
  | Span _ | Declaration _ -> 800
  | Message _ -> 900
  | Line _ -> 1500
  | Copied_line _ -> 600

(* [target] highlighted briefly, replacing any earlier flash. *)
let flash target model =
  let flash_serial = model.notices.flash_serial + 1 in
  ( {
      model with
      notices = { model.notices with flash = Some target; flash_serial };
    },
    [ After (flash_duration target, Unflash flash_serial) ] )

(* The model whose editor's box shows the program. *)
let showing_source model =
  { model with compilation = { model.compilation with code_view = Source } }

(* The definition of the [k]th link gone to: the caret placed at a definition
   in the editor, which flashes; the popover of a definition in the standard
   library opened at the name, the caret being there too; or a definition in
   the declarations loaded before the program unfolded, flashed and scrolled
   to. The editor's box shows the program. *)
let follow model k =
  let model = showing_source model in
  let unpointed caret_target =
    map_popovers (fun p -> { p with link = None; caret_target })
  in
  match List.nth_opt model.checked.links k with
  | Some { destination = In_editor (start, stop); _ } ->
      let model, effects =
        flash (Span (start, stop)) (unpointed None (close model))
      in
      ( model,
        Jump (utf16_offset model.edit_model.unparsed_code start) :: effects )
  | Some { destination = In_library _; _ } ->
      let target = Reference k in
      show target (unpointed (Some target) model)
  | Some { destination = In_declarations { place; _ }; _ } ->
      let start, stop = place.span in
      let model = unpointed None (close model) in
      let model, effects =
        flash
          (Declaration (place.filename, start, stop))
          {
            model with
            declarations = { model.declarations with declarations_open = true };
          }
      in
      (model, Scroll_to_declaration :: effects)
  | None -> (model, [])

(* The [i]th error gone to: its primary span in the editor while the errors
   hold of the source, or otherwise its message, highlighted briefly. A point
   span is widened to the byte it points at, as the editor marks it. The
   editor's box shows the program. *)
let go_to_error model i =
  let model = showing_source (close model) in
  let span =
    match model.run_model with
    | Error errors when not model.error_view.stale_errors -> (
        match List.nth_opt errors i with
        | Some
            {
              diagnostic = { primary = Some { filename = ""; start; stop }; _ };
              _;
            } ->
            Some (start.offset, max stop.offset (start.offset + 1))
        | _ -> None)
    | _ -> None
  in
  let target, scroll =
    match span with
    | Some (start, stop) -> (Span (start, stop), Scroll_to_span i)
    | None -> (Message i, Scroll_to_error i)
  in
  let model, effects = flash target model in
  (model, scroll :: effects)

let line_links model =
  model.compilation.code_view = Source && unedited model.edit_model

(* Checks and runs *)

(* The run model state of the run state [rs] of [B], after the runs
   [completed_runs] and observed by [observer], the types of the grades hidden
   in closures. The observer observes a step once it is taken. *)
let rec make_run_state : type run_state.
    (module WebBackend.S with type run_state = run_state) ->
    completed_runs:completed_run_view list ->
    observer:BackendRegistry.observer option ->
    run_state ->
    run_model_state =
 fun (module B) ~completed_runs ~observer rs ->
  let concrete (step : B.step) =
    let next_observer () =
      Option.map
        (fun (o : BackendRegistry.observer) ->
          List.fold_left
            (fun (o : BackendRegistry.observer) -> o.observe)
            o (B.observe rs step))
        observer
    in
    let next_completed_runs =
      if B.is_end_of_run_label step.label then
        completed_runs
        @ [ { view_completed = (fun () -> B.view_run_state rs None) } ]
      else completed_runs
    in
    {
      label_vdom = (B.view_step_label step.label : msg Vdom.vdom);
      view_highlighted = (fun () -> B.view_run_state rs (Some step.label));
      next_state =
        (fun () ->
          make_run_state
            (module B)
            ~completed_runs:next_completed_runs ~observer:(next_observer ())
            (step.next_state ()));
    }
  in
  {
    steps = List.map concrete (B.steps rs);
    view = (fun () -> B.view_run_state rs None);
    completed_runs;
    is_done = B.is_done rs;
    observer;
  }

(* The program of [edit_model] loaded under the grades [G] after the
   declarations [declared], and, under [run] and without errors, run: the run
   or the errors reported, and what the check has found. *)
let check_with (module G : Grades.Grade.S) ~run edit_model declared =
  let module B = WebInterpreter.Make (Grades.GradeSystem.Identity (G)) in
  let module L = Loader.Loader (B) in
  (* The standard library is loaded as a source of its own, so that an editor
     location is a location in what the user typed. *)
  let program =
    L.load_program ~use_stdlib:edit_model.use_stdlib
      (List.map
         (fun (d : BackendRegistry.source) ->
           L.parse_source ~filename:d.filename ~running_times:d.running_times
             d.text)
         declared
      @ [ L.parse_source edit_model.unparsed_code ])
  in
  let state = program.loaded in
  let scheme_layout = L.TC.scheme_layout state.typechecker in
  let triple (d : L.definition) = (d.variable, d.at, d.scheme) in
  let definitions =
    defined ~source:edit_model.unparsed_code
      ~name:Language.Ast.Variable.string_of ~scheme_layout
      (List.map triple program.definitions)
  and links =
    linked ~library:L.stdlib_source
      ~library_definitions:(List.map triple program.library_definitions)
      ~declarations:
        (List.map
           (fun (d : BackendRegistry.source) ->
             { WebDeclarations.filename = d.filename; text = d.text })
           declared)
      ~definitions:(List.map triple program.definitions)
      ~name:Language.Ast.Variable.string_of ~scheme_layout program.links
  in
  let effect_definitions =
    List.map
      (fun (d : L.definition) ->
        ( d.variable,
          match L.TC.function_effect state.typechecker d.scheme with
          | Typechecker.Not_a_function -> BackendRegistry.Not_a_function
          | Typechecker.Effect_variable -> Effect_variable
          | Typechecker.Effect { grade; durations } ->
              Effect { grade; durations } ))
      program.definitions
  in
  let accepted (compiler : BackendRegistry.compiler) settings =
    compiler.compile settings ~operations:program.operations
      ~compound:program.compound_operations ~definitions:effect_definitions
      program.commands
  in
  let checked accepted = { definitions; links; accepted; declared } in
  if program.diagnostics <> [] then
    ( Error
        (List.map
           (fun diagnostic -> { diagnostic; hovered_label = None })
           program.diagnostics),
      checked None )
  else if run then
    let observer =
      Option.map
        (fun observer -> observer (settings edit_model))
        (backend edit_model).observer
    in
    ( Ok
        (run_init
           (make_run_state
              (module B)
              ~completed_runs:[] ~observer (B.run state.backend))),
      checked (Some accepted) )
  else (Error [], checked (Some accepted))

(* The program of [edit_model] checked under the grades selected after the
   declarations of the selected backend, and run under [run]; an exception
   raised meanwhile is reported as an error. *)
let check_program ~run edit_model =
  let declared =
    match declarations edit_model with Ok sources -> sources | Error _ -> []
  in
  let failed errors =
    (Error errors, { definitions = []; links = []; accepted = None; declared })
  in
  try
    match
      ( List.assoc_opt edit_model.selected_grades
          Grades.GradeRegistry.grade_modules,
        declarations edit_model )
    with
    | None, _ ->
        failed
          [
            fatal
              (Printf.sprintf "Unknown grades `%s`" edit_model.selected_grades);
          ]
    | _, Error message -> failed [ fatal message ]
    | Some grades, Ok _ -> check_with grades ~run edit_model declared
  with exn -> failed (errors_of_exception Checking exn)

(* Updates of the model without effects *)

(* The code compiled, out of date. *)
let outdated compilation =
  {
    compilation with
    compiled =
      Option.map
        (fun compiled -> { compiled with up_to_date = false })
        compilation.compiled;
  }

(* The model after [edit_msg]. A backend is selected with its default
   example, loaded as from the gallery; otherwise the program stays checked
   under another backend, which compiles it at once, and under a changed input,
   compiled after a rest (see [edit]). Any other edit changes the program or
   the options it is checked under (see [edited_program]). *)
let rec edited model edit_msg =
  match edit_msg with
  | SelectBackend key -> (
      match default_example key with
      | Some (group, e) -> edited model (LoadExample (group, e))
      | None ->
          let model =
            { model with edit_model = edit_update model.edit_model edit_msg }
          in
          recompiled model (compile model))
  | SetInput _ ->
      {
        model with
        edit_model = edit_update model.edit_model edit_msg;
        compilation = outdated model.compilation;
      }
  | UseStdlib _ | ChangeSource _ | InsertIndent _ | LoadExample _
  | SelectGrades _ ->
      edited_program model edit_msg

(* The model after [edit_msg], which changes the program or its options. A
   loaded example replaces the program, so the errors of the old one go with
   it; an edit only makes them out of date. Examples are also linked from the
   documentation, where loading one is a request to go and look at it; an
   example picked in the gallery closes it. The schemes hold of the program and
   options they were inferred under only. *)
and edited_program model edit_msg =
  let loaded = match edit_msg with LoadExample _ -> true | _ -> false in
  let run_model, stale_errors =
    if loaded then (Error [], false)
    else
      (model.run_model, model.error_view.stale_errors || edits_source edit_msg)
  in
  let edited = edits_program edit_msg in
  let model = without_popover model in
  {
    edit_model = edit_update model.edit_model edit_msg;
    run_model;
    error_view = { active_error = None; hovered_error = None; stale_errors };
    navigation =
      (if loaded then { model.navigation with page = Editor; gallery = None }
       else model.navigation);
    checked =
      {
        model.checked with
        definitions = [];
        links = [];
        accepted = (if edited then None else model.checked.accepted);
      };
    popovers = { model.popovers with link = None };
    notices = unflashed model.notices;
    declarations =
      (if loaded then { model.declarations with declarations_open = false }
       else model.declarations);
    status =
      {
        model.status with
        last_check =
          (if loaded then None
           else
             Option.map
               (fun check -> { check with current = false })
               model.status.last_check);
      };
    compilation =
      (if loaded then
         {
           model.compilation with
           reports_compilation = false;
           code_view = Source;
           compiled = None;
         }
       else
         {
           (outdated model.compilation) with
           reports_compilation =
             model.compilation.reports_compilation && not edited;
         });
  }

(* The model after [run_msg] of the run; an exception raised by the step is
   reported as an error. *)
let stepped model run_msg =
  match model.run_model with
  | Ok run_model -> (
      match run_update run_model run_msg with
      | run_model -> { model with run_model = Ok run_model }
      | exception exn ->
          let model = without_popover model in
          {
            model with
            run_model = Error (errors_of_exception Running exn);
            error_view = unselected model.error_view;
            compilation = { model.compilation with reports_compilation = false };
          })
  | Error _ -> model

(* The model after the check [action] of the program. A program accepted by a
   check, not run, reports the errors of its compilation. *)
let performed model action =
  let run = action = Run in
  let run_model, checked = check_program ~run model.edit_model in
  let reports_compilation = (not run) && Option.is_some checked.accepted in
  let model = { model with checked } in
  let compiled = compile model in
  let run_model =
    if reports_compilation then Error (compilation_errors compiled)
    else run_model
  in
  let errors, warnings =
    match run_model with Error reported -> counted reported | Ok _ -> (0, 0)
  in
  let model = without_popover model in
  {
    model with
    run_model;
    compilation = { model.compilation with reports_compilation; compiled };
    error_view =
      { active_error = None; hovered_error = None; stale_errors = false };
    popovers = { model.popovers with link = None };
    notices = unflashed model.notices;
    status =
      {
        model.status with
        checking = None;
        last_check =
          Some
            {
              errors;
              warnings;
              definitions = List.length checked.definitions;
              current = true;
            };
      };
  }

(* The editor shown again after a run. *)
let edit_code model =
  let model = without_popover model in
  {
    model with
    run_model = Error [];
    compilation = { model.compilation with reports_compilation = false };
    error_view =
      { active_error = None; hovered_error = None; stale_errors = false };
  }

(* The label [j] of the [i]th error under the pointer, or none. *)
let hover_label model hovered =
  match model.run_model with
  | Error errors ->
      let errors =
        List.mapi
          (fun i error ->
            let hovered_label =
              match hovered with
              | Some (i', j) when i' = i -> Some j
              | _ -> None
            in
            { error with hovered_label })
          errors
      in
      { model with run_model = Error errors }
  | Ok _ -> model

let map_navigation f model = { model with navigation = f model.navigation }

(* The example gallery open with an empty search. *)
let open_gallery model =
  map_navigation
    (fun n -> { n with gallery = Some ""; gallery_group = None })
    (without_popover model)

(* Updates of the model with effects *)

(* The check [action] asked for, performed once the page shows it under way;
   ignored while one is under way. *)
let request action model =
  if model.status.checking <> None then (model, [])
  else
    ( { model with status = { model.status with checking = Some action } },
      [ Perform_after_paint action ] )

(* The model after [edit_msg]; a changed input is compiled after a rest. *)
let edit model edit_msg =
  match edit_msg with
  | SetInput _ ->
      let compile_serial = model.compilation.compile_serial + 1 in
      ( edited
          { model with compilation = { model.compilation with compile_serial } }
          edit_msg,
        [ After (compile_delay, Recompile compile_serial) ] )
  | UseStdlib _ | ChangeSource _ | InsertIndent _ | LoadExample _
  | SelectGrades _ | SelectBackend _ ->
      (edited model edit_msg, [])

(* The inputs of the backend at rest since the change of [serial], unless
   superseded. Inputs that change the declarations of the backend, such as the
   packages of a device manifest, change the program: it is checked again.
   Otherwise the program is compiled with them; a program edited since its
   check keeps its code, out of date. *)
let recompile model serial =
  if serial <> model.compilation.compile_serial then (model, [])
  else if model.status.checking = None && declarations_changed model then
    request Check model
  else
    match compile model with
    | Some compiled -> (recompiled model (Some compiled), [])
    | None -> (model, [])

(* The pointer moved onto [pointer] at [point] of the viewport, with the link
   [link] under it while the modifier of links is held. *)
let point model pointer link point =
  if pointer = model.popovers.pointer then
    ( (if link = model.popovers.link then model
       else map_popovers (fun p -> { p with link }) model),
      [] )
  else
    let model = map_popovers (fun p -> { p with pointer; link }) model in
    match (pointer, model.popovers.popover) with
    | Over_popover, _ ->
        ((if model.popovers.closing then disarm model else model), [])
    | Over_target t, Some p when p.target = t ->
        ((if p.shown then disarm model else model), [])
    (* from one target to another while a popover is open: no delay *)
    | Over_target t, Some { shown = true; _ } -> show ~point t model
    | Over_target t, _ ->
        let model, effects = arm ~closing:false open_delay model in
        ( map_popovers
            (fun p ->
              {
                p with
                popover =
                  Some
                    {
                      target = t;
                      point = Some point;
                      shown = false;
                      placement = None;
                    };
              })
            model,
          effects )
    | Nowhere, Some { shown = true; _ } ->
        if model.popovers.closing then (model, [])
        else arm ~closing:true close_delay model
    | Nowhere, Some _ -> (close model, [])
    | Nowhere, None -> (model, [])

(* The popover timer of [timer] run out, unless superseded. *)
let elapse model timer =
  if timer <> model.popovers.timer then (model, [])
  else
    match model.popovers.popover with
    | Some _ when model.popovers.closing -> (close model, [])
    | Some p when not p.shown ->
        ( map_popovers
            (fun ps -> { ps with popover = Some { p with shown = true } })
            model,
          [ Measure_popover ] )
    | _ -> (model, [])

(* The drawn popover of [target] measured as [placement]. A scheme laid out
   for another width is laid out again first. *)
let place model target (placement : placement option) =
  match (model.popovers.popover, placement) with
  | Some p, Some { columns = Some _ as columns; _ }
    when p.shown && p.target = target && columns <> model.popovers.columns ->
      (map_popovers (fun ps -> { ps with columns }) model, [ Measure_popover ])
  | Some p, Some _ when p.shown && p.target = target ->
      ( map_popovers
          (fun ps -> { ps with popover = Some { p with placement } })
          model,
        [] )
  | Some p, None when p.target = target -> (close model, [])
  | _ -> (model, [])

(* The caret placed at [offset] of the editor, in UTF-16 code units. Edited
   source: the spans no longer say where the caret is. The popover of the
   target the caret enters opens, and one it opened closes as the caret
   leaves; the caret staying within a target leaves it alone, so that Escape
   keeps the popover closed. *)
let caret_at model offset =
  match model.run_model with
  | Error errors when not model.error_view.stale_errors -> (
      let offset = byte_offset model.edit_model.unparsed_code offset in
      let target =
        target_at errors model.checked.definitions model.checked.links offset
      in
      let model =
        {
          model with
          error_view =
            { model.error_view with active_error = error_at errors offset };
        }
      in
      if target = model.popovers.caret_target then (model, [])
      else
        let model =
          map_popovers (fun p -> { p with caret_target = target }) model
        in
        match (target, model.popovers.popover) with
        | Some t, _ -> show t model
        | None, Some { point = None; _ } -> (close model, [])
        | None, _ -> (model, []))
  | _ -> (model, [])

(* The definition of the name at [offset] of the editor, in UTF-16 code units,
   gone to. *)
let follow_at model offset =
  match
    link_at model.checked.links
      (byte_offset model.edit_model.unparsed_code offset)
  with
  | Some k when not model.error_view.stale_errors -> follow model k
  | _ -> (model, [])

(* The page [docs_page] of the documentation shown at [heading]. *)
let show_docs model docs_page heading =
  ( map_navigation
      (fun n -> { n with page = Docs; docs_page; docs_heading = heading })
      (without_popover model),
    [ Scroll_to_heading heading ] )

(* The model after [msg] and the effects it asks for, except the remembering
   of the choices, which [update] adds. *)
let respond model msg =
  let pure model = (model, []) in
  match msg with
  | EditMsg edit_msg -> edit model edit_msg
  | RunMsg run_msg -> pure (stepped model run_msg)
  | CheckCode -> request Check model
  | RunCode -> request Run model
  | Perform action -> pure (performed model action)
  | EditCode -> pure (edit_code model)
  | Recompile serial -> recompile model serial
  | HoverLabel hovered -> pure (hover_label model hovered)
  | HoverError hovered_error ->
      pure { model with error_view = { model.error_view with hovered_error } }
  | GoToError i -> go_to_error model i
  | ShowFullError i ->
      let model, effects = flash (Message i) (close model) in
      (model, Scroll_to_error i :: effects)
  | Abbreviate abbreviated ->
      pure { model with status = { model.status with abbreviated } }
  | ShowPage page ->
      pure (map_navigation (fun n -> { n with page }) (without_popover model))
  | ShowDocs (docs_page, heading) -> show_docs model docs_page heading
  | ReachHeading id ->
      pure (map_navigation (fun n -> { n with docs_heading = Some id }) model)
  | OpenGallery ->
      ( open_gallery model,
        if model.edit_model.selected_example <> None then
          [ Focus_current_example ]
        else [] )
  | CloseGallery ->
      pure (map_navigation (fun n -> { n with gallery = None }) model)
  | SearchGallery query ->
      pure (map_navigation (fun n -> { n with gallery = Some query }) model)
  | ReachGroup id ->
      pure (map_navigation (fun n -> { n with gallery_group = Some id }) model)
  | Point (pointer, link, at) -> point model pointer link at
  | OverLink link -> pure (map_popovers (fun p -> { p with link }) model)
  | Reveal target -> show target model
  | Conceal -> pure (close model)
  | Elapsed timer -> elapse model timer
  | Place (target, placement) -> place model target placement
  | CaretAt offset -> caret_at model offset
  | Follow k -> follow model k
  | FollowAt offset -> follow_at model offset
  | Unflash serial when serial = model.notices.flash_serial ->
      pure { model with notices = unflashed model.notices }
  | Unflash _ -> pure model
  | ShowCode code_view ->
      pure
        (let model = without_popover model in
         { model with compilation = { model.compilation with code_view } })
  | ShowDeclarations declarations_open ->
      pure
        {
          model with
          declarations = { model.declarations with declarations_open };
        }
  | CopyLink -> (model, [ Copy_link (link model.edit_model) ])
  | CopyLineLink line when line_links model ->
      let model, effects = flash (Copied_line line) model in
      (model, Copy_link (link ~line model.edit_model) :: effects)
  | CopyLineLink _ -> pure model
  | Copied (url, copied) ->
      notify model (if copied then Link_copied else Copy_failed url)
  | Unnotice serial when serial = model.notices.notice_serial ->
      pure { model with notices = { model.notices with notice = None } }
  | Unnotice _ -> pure model

(* Whether a message changes the choices the browser remembers. *)
let changes_choices = function
  | EditMsg
      ( UseStdlib _ | LoadExample _ | SelectGrades _ | SelectBackend _
      | SetInput _ ) ->
      true
  | _ -> false

let update model msg =
  let model, effects = respond model msg in
  if changes_choices msg then
    ( {
        model with
        notices = { model.notices with notice = None };
        declarations =
          {
            model.declarations with
            shown_declarations =
              shown_declarations ~shown:model.declarations.shown_declarations
                model.edit_model;
          };
      },
      Remember (WebChoices.key, WebChoices.encode (choices model.edit_model))
      :: Replace_query (link model.edit_model)
      :: effects )
  else (model, effects)

(* The model opening with the editor [edit_model]. *)
let opening edit_model =
  {
    init with
    edit_model;
    declarations =
      {
        init.declarations with
        shown_declarations =
          shown_declarations ~shown:init.declarations.shown_declarations
            edit_model;
      };
  }

(* The model opening with the choices encoded by [stored] restored, or [init]
   without them. *)
let restored stored =
  Option.fold ~none:init
    ~some:(fun c -> opening (restore_edit c))
    (Option.bind stored WebChoices.decode)

let opened ~query stored =
  let parameters, malformed = WebLink.parse query in
  let model, unknown =
    if parameters = WebLink.empty then (restored stored, [])
    else
      let c, unknown =
        WebLink.resolve catalogue ~defaults:(choices edit_init)
          (Option.bind stored WebChoices.decode)
          parameters
      in
      (opening (restore_edit c), unknown)
  in
  (* the line named, within the example loaded, and the bytes it holds *)
  let line, out_of_range =
    match parameters.line with
    | Some n when not (List.mem WebLink.Line unknown) -> (
        match WebLink.line_bytes model.edit_model.unparsed_code n with
        | Some bytes -> (Some (n, bytes), [])
        | None -> (None, [ WebLink.Line ]))
    | _ -> (None, [])
  in
  let model =
    match List.sort compare (malformed @ unknown @ out_of_range) with
    | [] -> model
    | ignored -> fst (notify model (Ignored ignored))
  in
  (* the line scrolled to with the caret placed at it, and highlighted *)
  let model, shown =
    match line with
    | Some (n, (start, _)) ->
        let model, effects = flash (Line n) model in
        ( model,
          Jump (utf16_offset model.edit_model.unparsed_code start) :: effects )
    | None -> (model, [])
  in
  ( model,
    Replace_query (link ?line:(Option.map fst line) model.edit_model)
    ::
    (if parameters = WebLink.empty then []
     else
       [
         Remember (WebChoices.key, WebChoices.encode (choices model.edit_model));
       ])
    @ shown )
