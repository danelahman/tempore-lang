module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location

(** A conjunct of the qualifier of a scheme, as text. *)
type conjunct_text =
  | Formula of string
  | Ordering of { binder : string option; left : string; right : string }
      (** [left ≾ right], or [(∀ε_Op. left ≾ right)] with the rigid variable
          [binder] *)

type scheme_text = {
  parameters : string option;  (** [α ρ₀ ε₀], bound by the quantifier *)
  conjuncts : conjunct_text list;  (** those of the qualifier [Q ∧ R] *)
  arrows : string Language.PrettyPrint.arrows;
      (** the type, in parts around its arrows *)
}
(** The text of an inferred scheme [∀ α ρ₀ ε₀. Q ∧ R ⇒ A], by parts, each on one
    line. *)

type definition = {
  name : string;
  scheme : scheme_text;
  name_span : (int * int) option;
      (** the bytes of the source where the command names the definition *)
}
(** A top-level definition of the program in the editor, with its inferred
    scheme. *)

(** Where a name is defined. *)
type destination =
  | In_editor of int * int  (** the bytes of the editor's text naming it *)
  | In_library of library_entry

and library_entry = {
  line : int;  (** the line of the standard library naming it, from 1 *)
  text : string;  (** the text of that line *)
  value : definition option;  (** the definition, when the name is a value's *)
}
(** A definition of the standard library, which the editor does not show. *)

type link = {
  use : int * int;  (** the bytes of the editor's text where the name occurs *)
  destination : destination;
}
(** An occurrence of a name in the editor and its definition. *)

(** What a popover describes. *)
type popover_target =
  | Error_span of int  (** the primary span of the [i]th error *)
  | Error_label of int * int  (** the span of label [j] of the [i]th error *)
  | Definition of int  (** the name of the [k]th definition *)
  | Reference of int
      (** the name of the [k]th link, defined in the standard library *)

(** What a button of the code options asks for. *)
type action =
  | Check  (** typecheck the program *)
  | Run  (** typecheck the program and, without errors, run it *)

(** What is highlighted briefly, having just been gone to. *)
type flash =
  | Span of int * int
      (** the bytes of the editor's text from a start up to a stop *)
  | Message of int  (** the message of the [i]th error *)

(** What the pointer is over in the editor. *)
type pointer = Nowhere | Over_target of popover_target | Over_popover

type placement = {
  left : float;
  top : float;
  width : float;
  arrow : float;  (** the arrow's offset from the left edge of the card *)
  above : bool;  (** whether the card is above its span rather than under it *)
  columns : int option;
      (** the characters a line of the scheme the card shows holds at most *)
}
(** Where a popover is drawn, in pixels from the top-left corner of the editor.
*)

(* Abstract representation of a single reduction step, with all resource-grade-specific
   types captured in closures. This allows the model to work with any resource grade
   without fixing the type at module-definition time. *)
type concrete_step = {
  label_vdom : msg Vdom.vdom;
      (** Pre-rendered step label. Produces [msg] events (in practice none,
          since [view_step_label] is parametrically polymorphic and event-free).
      *)
  view_highlighted : 'a. unit -> 'a Vdom.vdom;
      (** Render the current run state with this step's redex highlighted. *)
  next_state : unit -> run_model_state;
      (** Advance to the next run state by performing this step. *)
}

and completed_run_view = { view_completed : 'a. unit -> 'a Vdom.vdom }

and run_model_state = {
  steps : concrete_step list;
  view : 'a. unit -> 'a Vdom.vdom;
      (** Render the current run state with no redex highlighted. *)
  completed_runs : completed_run_view list;
      (** Snapshots of previously finished [run] blocks, in chronological order.
          Each snapshot is the view of the run-state at the moment its final
          step, at a returned value or an unhandled operation call, was about to
          be taken. *)
  is_done : bool;
      (** True when there are no computations left to run (i.e. all [run] blocks
          have completed and their snapshots are in [completed_runs]). *)
}
(** A snapshot of an interpreter run state together with its available steps,
    all resource-grade types hidden behind closures. *)

and edit_msg =
  | UseStdlib of bool
  | ChangeSource of string
  | InsertIndent of string * int * int
      (** Tab pressed in the editor: the source as the browser has it, and the
          selection to replace with an indentation, in the UTF-16 code units the
          browser counts selections in. *)
  | LoadExample of string * string * string * string
      (** Load a bundled example: its group, its title, the name of the resource
          grade it is meant to be run with, and its source. The group is carried
          along with the title because two examples of different groups may
          share a title. *)
  | SelectResource of string
      (** Select the grades to use (by name from [grade_modules]). *)

and run_msg =
  | SelectStepIndex of int option
  | MakeStep of concrete_step
  | RandomStep
  | ChangeRandomStepSize of int
  | Back

and msg =
  | EditMsg of edit_msg
  | CheckCode  (** Typecheck the program, staying in the editor. *)
  | RunCode  (** Typecheck the program and, if it has no errors, run it. *)
  | Perform of action
      (** Perform the check asked for, the page having been drawn since. *)
  | GoToError of int
      (** Scroll to the given error, its span in the editor or, when it has none
          there or the source has been edited since, its message, and highlight
          what is scrolled to briefly. *)
  | Abbreviate of bool
      (** The status line has been measured to hold the number of definitions in
          full, or not. *)
  | RunMsg of run_msg
  | EditCode
  | ShowPage of page
      (** Switch between the editor and the documentation. The rest of the model
          is left alone, so the source and any run survive the detour. *)
  | HoverLabel of (int * int) option
      (** The pointer has entered label [j] of reported error [i], or left the
          labels. Top-level, since the error display belongs to neither the
          editor nor the run. *)
  | HoverError of int option
      (** The pointer has entered the given reported error — any of its line
          numbers in the editor, its entry in the side panel, or the header of
          its message — or left it. *)
  | CaretAt of int
      (** The caret has been placed at the given offset of the editor, in UTF-16
          code units: the error whose span it lands in, if any, becomes the
          active one. *)
  | OpenGallery  (** Show the example gallery, with an empty search. *)
  | CloseGallery  (** Hide the example gallery without loading an example. *)
  | SearchGallery of string
      (** The text of the gallery's search field has changed. *)
  | Point of pointer * int option * (float * float)
      (** The pointer, at the given position of the viewport, has moved onto a
          popover target, onto the popover or off both, or onto or off the name
          of a link while ⌘ (Ctrl) is held. *)
  | OverLink of int option
      (** ⌘ (Ctrl) has been pressed with the pointer on the name of the given
          link, or released. *)
  | Follow of int  (** Go to the definition of the given link. *)
  | FollowAt of int
      (** Go to the definition of the name at the given offset of the editor, in
          UTF-16 code units. *)
  | Unflash of int  (** The flash of the given serial has run its course. *)
  | Reveal of popover_target
      (** Open the popover without delay, a marker having the keyboard focus. *)
  | Conceal  (** Close the popover without delay. *)
  | Elapsed of int  (** The popover timer of the given serial has run out. *)
  | Place of popover_target * placement option
      (** The drawn popover of the target has been measured against its span, or
          the span has not been found. *)
  | ShowFullError of int
      (** Scroll to the message of the given error and highlight it briefly. *)

(* Which of the two top-level pages is showing. [Editor] covers both editing and
   running, which [run_model] distinguishes between. *)
and page = Editor | Docs

type edit_model = {
  use_stdlib : bool;
  unparsed_code : string;
  selected_resource : string;
      (** Name of the currently selected grades (key in [grade_modules]). *)
  selected_example : (string * string) option;
      (** Group and title of the bundled example last loaded; editing it keeps
          the selection, so the example button still says where the program came
          from. *)
}

(** The key the browser remembers whether to load the standard library under. *)
let use_stdlib_key = "tempore.use-stdlib"

(** What a Tab in the editor inserts; the editor's [tab-size] matches. *)
let indentation = "  "

(** [byte_offset source offset] is the byte of [source] the browser's [offset]
    points at: a selection counts UTF-16 code units, an OCaml string UTF-8
    bytes, and the two part company outside ASCII. *)
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
  | LoadExample (group, title, resource_name, source) ->
      (* An example is written for a particular resource grade, so loading one
         switches to that grade. The user remains free to change it afterwards. *)
      {
        edit_model with
        unparsed_code = source;
        selected_resource = resource_name;
        selected_example = Some (group, title);
      }
  | SelectResource name -> { edit_model with selected_resource = name }

(** [example_of_path path] is the group label and the bundled example at [path],
    relative to the project root, if there is one. *)
let example_of_path path =
  List.find_map
    (fun (g : Examples_tpe.group) ->
      Option.map
        (fun (e : Examples_tpe.example) -> (g.label, e))
        (List.find_opt
           (fun (e : Examples_tpe.example) -> e.path = path)
           g.examples))
    Examples_tpe.examples

(** The editor as the page opens: the manifest's default example loaded, its
    grades selected. *)
let edit_init =
  let empty =
    {
      use_stdlib = true;
      unparsed_code = "";
      selected_resource = Grades.GradeRegistry.default_name;
      selected_example = None;
    }
  in
  match example_of_path Examples_tpe.default with
  | Some (group, e) ->
      edit_update empty (LoadExample (group, e.title, e.grade, e.source))
  | None -> empty

type run_model = {
  current : run_model_state;
  history : run_model_state list;
  selected_step_index : int option;
  (* You may be wondering why we keep an index rather than the selected step itself.
     The selected step is displayed when the user moves the mouse over the step button,
     so on a onmouseover event. However, in the common case, when the user is on the button
     and is clicking it to proceed, this event is not triggered and so the step is not updated.
     For that reason, it is easiest to keep track of the selected button index, which does not
     change when the user clicks the button. *)
  random_step_size : int;
}

let run_init current =
  { current; history = []; selected_step_index = None; random_step_size = 1 }

let run_model_make_step run_model (step : concrete_step) =
  {
    run_model with
    current = step.next_state ();
    history = run_model.current :: run_model.history;
  }

let rec run_model_make_random_steps run_model num_steps =
  match (num_steps, run_model.current.steps) with
  | 0, _ | _, [] -> run_model
  | _, steps ->
      let i = Random.int (List.length steps) in
      let step = List.nth steps i in
      let run_model' = run_model_make_step run_model step in
      run_model_make_random_steps run_model' (num_steps - 1)

let run_update run_model = function
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

type load_error = {
  diagnostic : Diagnostic.t;  (** why the source could not be loaded and run *)
  hovered_label : int option;
      (** The label the pointer is over, whose span is brightened in the editor.
      *)
}
(** An error the edit view reports, with the state of showing it. *)

type check = {
  errors : int;  (** the number of errors reported *)
  definitions : int;  (** the number of top-level definitions of the program *)
  current : bool;
      (** whether neither the program nor the options have changed since *)
}
(** The outcome of a check of the program. *)

type popover = {
  target : popover_target;
  point : (float * float) option;
      (** where the pointer was in the viewport when it opened the popover,
          which picks the line of a span that runs over several *)
  shown : bool;  (** false while the opening delay runs *)
  placement : placement option;  (** set once the drawn card is measured *)
}
(** The card describing an error's span or a definition's name. *)

type model = {
  edit_model : edit_model;
  run_model : (run_model, load_error list) result;
      (** [Error []] is the edit view with nothing to report. *)
  active_error : int option;
      (** The error the caret sits in, singled out among the messages. *)
  hovered_error : int option;
      (** The error the pointer is on, all of whose line numbers light up
          together. Kept here rather than left to CSS, the numbers of one error
          being separate elements with no parent of their own. *)
  stale_errors : bool;
      (** Whether the source has been edited since the errors were reported, so
          that their spans point at bytes that have moved. *)
  page : page;
  gallery : string option;
      (** The search of the example gallery while it is open, [None] while it is
          closed. *)
  definitions : definition list;
      (** The definitions of the program as last checked, those accepted before
          its first error; none once the source or the options change. *)
  links : link list;
      (** The names of the program as last checked with the definitions they
          refer to; none once the source or the options change. *)
  link : int option;
      (** The link whose name is under the pointer while ⌘ (Ctrl) is held. *)
  flash : flash option;  (** What has just been gone to, highlighted briefly. *)
  flash_serial : int;
      (** The serial of the latest flash, which replaces any earlier one; the
          end of an earlier one is ignored. *)
  checking : action option;
      (** The check asked for and not yet performed, which awaits the drawing of
          the page. *)
  last_check : check option;
      (** The outcome of the last check, [None] before any and once an example
          is loaded. *)
  abbreviated : bool;
      (** Whether the status line abbreviates the number of definitions, not
          holding it in full. *)
  popover : popover option;
  columns : int option;
      (** the characters a line of the scheme a card shows holds at most, as
          last measured *)
  pointer : pointer;
      (** What the pointer is over, so that only a change is reported. *)
  caret_target : popover_target option;  (** the target the caret is in *)
  timer : int;
      (** The serial of the timer the popover awaits; a timer of another serial
          has been superseded. *)
  closing : bool;  (** whether that timer closes the popover *)
}

let init =
  {
    edit_model = edit_init;
    run_model = Error [];
    active_error = None;
    hovered_error = None;
    stale_errors = false;
    page = Editor;
    gallery = None;
    definitions = [];
    links = [];
    link = None;
    flash = None;
    flash_serial = 0;
    checking = None;
    last_check = None;
    abbreviated = false;
    popover = None;
    columns = None;
    pointer = Nowhere;
    caret_target = None;
    timer = 0;
    closing = false;
  }

(** A side effect the update asks for, performed by the page. *)
type side_effect =
  | After of int * msg  (** send the message after so many milliseconds *)
  | Measure_popover  (** measure the drawn popover and send [Place] *)
  | Scroll_to_error of int  (** scroll to the message of the given error *)
  | Scroll_to_span of int
      (** scroll to the primary span of the given error in the editor *)
  | Perform_after_paint of action
      (** send [Perform] once the page has been drawn *)
  | Remember of string * bool  (** keep a setting in the browser *)
  | Focus_current_example
      (** focus the card of the example last loaded in the gallery and centre it
          in the gallery's list *)
  | Jump of int
      (** place the editor's caret at the given offset, in UTF-16 code units,
          and scroll the flashed definition into view *)

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
  | UseStdlib _ | SelectResource _ -> false

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
   error, the primary span of one, or the name of a definition, in this order
   of precedence, the first found of each. *)
let target_at errors definitions offset =
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
  in
  match (label, primary) with
  | Some _, _ -> label
  | None, Some _ -> primary
  | None, None -> definition

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
  {
    model with
    popover = None;
    pointer = Nowhere;
    caret_target = None;
    timer = model.timer + 1;
    closing = false;
  }

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
   definition in the editor or in the standard library, whose source is
   [library] and whose top-level definitions are [library_definitions], each
   a variable, the location of its command and its scheme. *)
let linked ~library ~library_definitions ~name ~scheme_layout
    (links : Desugarer.References.link list) =
  let lines = lazy (String.split_on_char '\n' library) in
  let entry (definition : Location.t) sort =
    let line = definition.start.line in
    let value =
      match (sort : Desugarer.References.sort) with
      | Value ->
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
            library_definitions
      | Constructor | Type | Operation -> None
    in
    Option.map
      (fun text -> In_library { line; text; value })
      (List.nth_opt (Lazy.force lines) (line - 1))
  in
  List.filter_map
    (fun ({ use; definition; sort } : Desugarer.References.link) ->
      let destination =
        if use.filename <> "" then None
        else if definition.filename = "" then
          Some (In_editor (definition.start.offset, definition.stop.offset))
        else if definition.filename = Loader.stdlib_filename then
          entry definition sort
        else None
      in
      Option.map
        (fun destination ->
          { use = (use.start.offset, use.stop.offset); destination })
        destination)
    links

(** [link_at links offset] is the first of [links] whose name covers the byte
    [offset] of the editor's text, its end included. *)
let link_at links offset =
  List.find_index
    (fun { use = start, stop; _ } -> start <= offset && offset <= stop)
    links

(** [utf16_offset source byte] is the offset of the browser's UTF-16 code units
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

(** What the program was undergoing when an exception was raised. *)
type stage = Checking | Running

(** [errors_of_exception stage exn] is the errors reported for the exception
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

(* The update of the model proper; [update] adds the effects. *)
let update_model model = function
  | EditMsg edit_msg ->
      (* A loaded example replaces the program, so the errors of the old one
         go with it; an edit only makes them out of date. *)
      let run_model, stale_errors =
        match edit_msg with
        | LoadExample _ -> (Error [], false)
        | _ -> (model.run_model, model.stale_errors || edits_source edit_msg)
      in
      (* Examples are also linked from the documentation, where loading one is a
         request to go and look at it. *)
      let page =
        match edit_msg with LoadExample _ -> Editor | _ -> model.page
      in
      (* An example picked in the gallery closes it. *)
      let gallery =
        match edit_msg with LoadExample _ -> None | _ -> model.gallery
      in
      (* The schemes hold of the program and options they were inferred
         under only. *)
      {
        (without_popover model) with
        edit_model = edit_update model.edit_model edit_msg;
        run_model;
        active_error = None;
        hovered_error = None;
        stale_errors;
        page;
        gallery;
        definitions = [];
        links = [];
        link = None;
        flash = None;
        last_check =
          (match edit_msg with
          | LoadExample _ -> None
          | _ ->
              Option.map
                (fun check -> { check with current = false })
                model.last_check);
      }
  | RunMsg run_msg -> (
      match model.run_model with
      | Ok run_model -> (
          match run_update run_model run_msg with
          | run_model -> { model with run_model = Ok run_model }
          | exception exn ->
              {
                (without_popover model) with
                run_model = Error (errors_of_exception Running exn);
                active_error = None;
                hovered_error = None;
              })
      | Error _ -> model)
  | Perform action ->
      let run = action = Run in
      let run_model, definitions, links =
        try
          match
            List.assoc_opt model.edit_model.selected_resource
              Grades.GradeRegistry.grade_modules
          with
          | None ->
              ( Error
                  [
                    fatal
                      (Printf.sprintf "Unknown grades '%s'"
                         model.edit_model.selected_resource);
                  ],
                [],
                [] )
          | Some (module G : Grades.Grade.S) ->
              let module B = WebInterpreter.Make (Grades.GradeSystem.Identity (G)) in
              let module L = Loader.Loader (B) in
              (* The standard library is loaded as a source of its own, so
                 that an editor location is a location in what the user
                 typed. *)
              let program =
                L.load_program ~use_stdlib:model.edit_model.use_stdlib
                  [ L.parse_source model.edit_model.unparsed_code ]
              in
              let state = program.loaded
              and diagnostics = program.diagnostics
              and accepted = program.definitions
              and library_definitions = program.library_definitions
              and references = program.links in
              let triple (d : L.definition) = (d.variable, d.at, d.scheme) in
              let definitions =
                defined ~source:model.edit_model.unparsed_code
                  ~name:Language.Ast.Variable.string_of
                  ~scheme_layout:(L.TC.scheme_layout state.typechecker)
                  (List.map triple accepted)
              and links =
                linked ~library:L.stdlib_source
                  ~library_definitions:(List.map triple library_definitions)
                  ~name:Language.Ast.Variable.string_of
                  ~scheme_layout:(L.TC.scheme_layout state.typechecker)
                  references
              in
              (* Build a run_model_state from a B.run_state, capturing all
                 resource-grade-specific types in closures so the rest of the
                 application is independent of the chosen resource grade. *)
              let rec make_run_state ~completed_runs (rs : B.run_state) :
                  run_model_state =
                {
                  steps =
                    List.map
                      (fun (step : B.step) ->
                        let next_completed_runs =
                          if B.is_end_of_run_label step.label then
                            completed_runs
                            @ [
                                {
                                  view_completed =
                                    (fun () -> B.view_run_state rs None);
                                };
                              ]
                          else completed_runs
                        in
                        {
                          label_vdom =
                            (B.view_step_label step.label : msg Vdom.vdom);
                          view_highlighted =
                            (fun () -> B.view_run_state rs (Some step.label));
                          next_state =
                            (fun () ->
                              make_run_state ~completed_runs:next_completed_runs
                                (step.next_state ()));
                        })
                      (B.steps rs);
                  view = (fun () -> B.view_run_state rs None);
                  completed_runs;
                  is_done = B.is_done rs;
                }
              in
              if diagnostics <> [] then
                ( Error
                    (List.map
                       (fun diagnostic -> { diagnostic; hovered_label = None })
                       diagnostics),
                  definitions,
                  links )
              else if run then
                ( Ok
                    (run_init
                       (make_run_state ~completed_runs:[] (B.run state.backend))),
                  definitions,
                  links )
              else (Error [], definitions, links)
        with exn -> (Error (errors_of_exception Checking exn), [], [])
      in
      {
        (without_popover model) with
        run_model;
        active_error = None;
        hovered_error = None;
        stale_errors = false;
        definitions;
        links;
        link = None;
        flash = None;
        checking = None;
        last_check =
          Some
            {
              errors =
                (match run_model with
                | Error errors -> List.length errors
                | Ok _ -> 0);
              definitions = List.length definitions;
              current = true;
            };
      }
  | EditCode ->
      {
        (without_popover model) with
        run_model = Error [];
        active_error = None;
        hovered_error = None;
        stale_errors = false;
      }
  | HoverLabel hovered -> (
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
      | Ok _ -> model)
  | ShowPage page -> { (without_popover model) with page }
  | HoverError hovered_error -> { model with hovered_error }
  | OpenGallery -> { (without_popover model) with gallery = Some "" }
  | CloseGallery -> { model with gallery = None }
  | SearchGallery query -> { model with gallery = Some query }
  | OverLink link -> { model with link }
  | Abbreviate abbreviated -> { model with abbreviated }
  | Unflash serial when serial = model.flash_serial ->
      { model with flash = None }
  | CaretAt _ | Point _ | Reveal _ | Conceal | Elapsed _ | Place _
  | ShowFullError _ | Follow _ | FollowAt _ | Unflash _ | CheckCode | RunCode
  | GoToError _ ->
      model

(* How long the pointer rests on a span before its popover opens, and how long
   the popover outlasts the pointer's leaving, in milliseconds: the latter lets
   the pointer cross the gap to the card. *)
let open_delay = 250
let close_delay = 150

(* A new timer, superseding any other. *)
let arm ~closing delay model =
  let timer = model.timer + 1 in
  ({ model with timer; closing }, [ After (delay, Elapsed timer) ])

(* No timer. *)
let disarm model = { model with timer = model.timer + 1; closing = false }

(* The popover of [target] open without delay, to be measured once drawn. *)
let show ?point target model =
  ( {
      (disarm model) with
      popover = Some { target; point; shown = true; placement = None };
    },
    [ Measure_popover ] )

let close model = { (disarm model) with popover = None }

(* How long what has been gone to stays highlighted, in milliseconds, as long
   as the page's highlight fades: a span of the editor, or an error's
   message. *)
let flash_duration = function Span _ -> 800 | Message _ -> 900

(* [target] highlighted briefly, replacing any earlier flash. *)
let flash target model =
  let flash_serial = model.flash_serial + 1 in
  ( { model with flash = Some target; flash_serial },
    [ After (flash_duration target, Unflash flash_serial) ] )

(* The definition of the [k]th link gone to: the caret placed at a definition
   in the editor, which flashes, or the popover of a definition in the
   standard library opened at the name, the caret being there too. *)
let follow model k =
  match List.nth_opt model.links k with
  | Some { destination = In_editor (start, stop); _ } ->
      let model, effects =
        flash
          (Span (start, stop))
          { (close model) with link = None; caret_target = None }
      in
      ( model,
        Jump (utf16_offset model.edit_model.unparsed_code start) :: effects )
  | Some { destination = In_library _; _ } ->
      let target = Reference k in
      show target { model with link = None; caret_target = Some target }
  | None -> (model, [])

(* The [i]th error gone to: its primary span in the editor while the errors
   hold of the source, or otherwise its message, highlighted briefly. A point
   span is widened to the byte it points at, as the editor marks it. *)
let go_to_error model i =
  let model = close model in
  let span =
    match model.run_model with
    | Error errors when not model.stale_errors -> (
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

(** [update model msg] is the model after [msg] and the effects it asks for. *)
let update model msg =
  match msg with
  | Point (pointer, link, _) when pointer = model.pointer ->
      ((if link = model.link then model else { model with link }), [])
  | Point (pointer, link, point) -> (
      let model = { model with pointer; link } in
      match (pointer, model.popover) with
      | Over_popover, _ -> ((if model.closing then disarm model else model), [])
      | Over_target t, Some p when p.target = t ->
          ((if p.shown then disarm model else model), [])
      (* from one target to another while a popover is open: no delay *)
      | Over_target t, Some { shown = true; _ } -> show ~point t model
      | Over_target t, _ ->
          let model, effects = arm ~closing:false open_delay model in
          ( {
              model with
              popover =
                Some
                  {
                    target = t;
                    point = Some point;
                    shown = false;
                    placement = None;
                  };
            },
            effects )
      | Nowhere, Some { shown = true; _ } ->
          if model.closing then (model, [])
          else arm ~closing:true close_delay model
      | Nowhere, Some _ -> (close model, [])
      | Nowhere, None -> (model, []))
  | Reveal target -> show target model
  | Conceal -> (close model, [])
  | Elapsed timer when timer = model.timer -> (
      match model.popover with
      | Some _ when model.closing -> (close model, [])
      | Some p when not p.shown ->
          ( { model with popover = Some { p with shown = true } },
            [ Measure_popover ] )
      | _ -> (model, []))
  | Elapsed _ -> (model, [])
  | Place (target, placement) -> (
      match (model.popover, placement) with
      (* a scheme laid out for another width is laid out again first *)
      | Some p, Some { columns = Some _ as columns; _ }
        when p.shown && p.target = target && columns <> model.columns ->
          ({ model with columns }, [ Measure_popover ])
      | Some p, Some _ when p.shown && p.target = target ->
          ({ model with popover = Some { p with placement } }, [])
      | Some p, None when p.target = target -> (close model, [])
      | _ -> (model, []))
  | ShowFullError i ->
      let model, effects = flash (Message i) (close model) in
      (model, Scroll_to_error i :: effects)
  | GoToError i -> go_to_error model i
  (* The check is performed once the page shows it under way; a press while
     one is under way is ignored. *)
  | (CheckCode | RunCode) when model.checking <> None -> (model, [])
  | CheckCode | RunCode ->
      let action = match msg with RunCode -> Run | _ -> Check in
      ({ model with checking = Some action }, [ Perform_after_paint action ])
  | CaretAt offset -> (
      (* Edited source: the spans no longer say where the caret is. The popover
         of the target the caret enters opens, and one it opened closes as the
         caret leaves; the caret staying within a target leaves it alone, so
         that Escape keeps the popover closed. *)
      match model.run_model with
      | Error errors when not model.stale_errors -> (
          let offset = byte_offset model.edit_model.unparsed_code offset in
          let target = target_at errors model.definitions offset in
          let model = { model with active_error = error_at errors offset } in
          if target = model.caret_target then (model, [])
          else
            let model = { model with caret_target = target } in
            match (target, model.popover) with
            | Some t, _ -> show t model
            | None, Some { point = None; _ } -> (close model, [])
            | None, _ -> (model, []))
      | _ -> (model, []))
  | Follow k -> follow model k
  | FollowAt offset -> (
      match
        link_at model.links (byte_offset model.edit_model.unparsed_code offset)
      with
      | Some k when not model.stale_errors -> follow model k
      | _ -> (model, []))
  | EditMsg (UseStdlib use_stdlib) ->
      (update_model model msg, [ Remember (use_stdlib_key, use_stdlib) ])
  | OpenGallery when model.edit_model.selected_example <> None ->
      (update_model model msg, [ Focus_current_example ])
  | _ -> (update_model model msg, [])
