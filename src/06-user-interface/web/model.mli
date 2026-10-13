(** The state of the web interface and its update by messages. *)

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
  | In_declarations of declaration_entry

and library_entry = {
  line : int;  (** the line of the standard library naming it, from 1 *)
  text : string;  (** the text of that line *)
  value : definition option;  (** the definition, when the name is a value's *)
}
(** A definition of the standard library, which the editor does not show. *)

and declaration_entry = {
  place : WebDeclarations.place;
      (** where it lies among the declarations the selected backend loads *)
  defined : definition option;  (** the definition, when the name is a value's *)
}
(** A definition of the declarations loaded before the program, which the editor
    shows above it. *)

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
      (** the name of the [k]th link, defined in the standard library or in the
          declarations loaded before the program *)

(** What a button of the code options asks for. *)
type action =
  | Check  (** typecheck the program *)
  | Run  (** typecheck the program and, without errors, run it *)

(** What is highlighted briefly, having just been gone to. *)
type flash =
  | Span of int * int
      (** the bytes of the editor's text from a start up to a stop *)
  | Message of int  (** the message of the [i]th error *)
  | Declaration of string * int * int
      (** the bytes of the declarations of the given file name from a start up
          to a stop *)

(** A notice shown under the example. *)
type notice =
  | Ignored of WebLink.parameter list
      (** the parameters of the page's address that name nothing known or are
          malformed *)
  | Link_copied
  | Copy_failed of string  (** the link the clipboard has refused *)

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
  observer : BackendRegistry.observer option;
      (** The operation model of the selected backend, having observed the steps
          taken so far, if the backend has one. *)
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
  | LoadExample of string * Examples_tpe.example
      (** Load a bundled example, given with the label of its group: its source,
          the grades it is meant to be run with, and its backend with the
          settings of its inputs. The group is carried along with the example
          because two examples of different groups may share a title. *)
  | SelectResource of string
      (** Select the grades to use (by name from [grade_modules]). *)
  | SelectBackend of string
      (** Select the backend (by key from {!BackendRegistry.entries}). *)
  | SetInput of string * string
      (** Set the input of the given key of the selected backend to a value. *)

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
  | Recompile of int
      (** The inputs of the backend have rested since the change of the given
          serial: compile the program with them, unless a later change has
          superseded it. *)
  | ShowCode of code_view
      (** Show the program or the code the selected backend has compiled it to
          in the editor's place. *)
  | CopyLink
      (** Copy the link to the example, the grades and the backend selected to
          the clipboard. *)
  | ShowDeclarations of bool
      (** The declarations shown above the program have been unfolded, or
          folded. *)
  | Copied of string * bool
      (** The given link has been copied to the clipboard, or the clipboard has
          refused it. *)
  | Unnotice of int  (** The notice of the given serial has run its course. *)

(* Which of the two top-level pages is showing. [Editor] covers both editing and
   running, which [run_model] distinguishes between. *)
and page = Editor | Docs

(* What the editor's box shows, under a backend with a compiler: the program,
   or the code compiled from it with the inputs of the backend. *)
and code_view = Source | Compiled

type edit_model = {
  use_stdlib : bool;
  unparsed_code : string;
  selected_resource : string;
      (** Name of the currently selected grades (key in [grade_modules]). *)
  selected_example : (string * string) option;
      (** Group and title of the bundled example last loaded; editing it keeps
          the selection, so the example button still says where the program came
          from. *)
  selected_backend : string;
      (** Key of the selected backend (in {!BackendRegistry.entries}). *)
  backend_settings : (string * BackendRegistry.settings) list;
      (** The values of the inputs set, by the key of their backend. *)
}

type run_model = {
  current : run_model_state;
  history : run_model_state list;
  selected_step_index : int option;
      (** The index of the step selected by the pointer over its button, kept in
          place of the step itself: a click on the button raises no event that
          would update the step. *)
  random_step_size : int;
}

type load_error = {
  diagnostic : Utils.Diagnostic.t;
      (** why the source could not be loaded and run *)
  hovered_label : int option;
      (** The label the pointer is over, whose span is brightened in the editor.
      *)
}
(** An error the edit view reports, or a warning, of the diagnostic kind
    [Warning], with the state of showing it. *)

type check = {
  errors : int;  (** the number of errors reported *)
  warnings : int;  (** the number of warnings reported *)
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

type compiled = {
  output : BackendRegistry.compiled;
  up_to_date : bool;
      (** whether neither the program nor the inputs have changed since *)
}
(** The code the selected backend has compiled the program to. *)

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
  accepted :
    (BackendRegistry.compiler ->
    BackendRegistry.settings ->
    BackendRegistry.compiled)
    option;
      (** The compilation of the program as last checked, while neither it nor
          the options have changed and it had no errors. *)
  declared : BackendRegistry.source list;
      (** The declarations of the selected backend loaded before the program as
          last checked. *)
  shown_declarations : WebDeclarations.source list;
      (** The declarations the selected backend loads before the program under
          its inputs and the grades selected, shown above the program. *)
  declarations_open : bool;
      (** Whether the declarations shown above the program are unfolded. *)
  compiled : compiled option;
      (** The code of the program as last compiled by the selected backend. *)
  compile_serial : int;
      (** The serial of the latest change of the inputs, which the debounce of
          the compilation awaits. *)
  reports_compilation : bool;
      (** Whether the errors reported are those of the compilation of the
          program as last checked, which a compilation with other inputs or by
          another backend replaces. *)
  code_view : code_view;
      (** What the editor's box shows while the selected backend has a compiler;
          the program otherwise. *)
  notice : notice option;
  notice_serial : int;
      (** The serial of the latest notice, which replaces any earlier one; the
          end of an earlier one is ignored. *)
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
  | Remember of string * string
      (** keep the value under the key in the browser's storage *)
  | Focus_current_example
      (** focus the card of the example last loaded in the gallery and centre it
          in the gallery's list *)
  | Scroll_to_declaration  (** scroll the flashed declaration into view *)
  | Jump of int
      (** place the editor's caret at the given offset, in UTF-16 code units,
          and scroll the flashed definition into view *)
  | Replace_query of string
      (** replace the query of the page's address by the given one, without an
          entry of its own in the history *)
  | Copy_link of string
      (** copy the page's address with the given query to the clipboard and send
          [Copied] *)

val is_warning : load_error -> bool
(** [is_warning e] is whether [e] is a warning rather than an error. *)

val backend : edit_model -> BackendRegistry.entry
(** [backend edit_model] is the selected backend, or the default one if the key
    selected names none. *)

val settings : edit_model -> BackendRegistry.settings
(** [settings edit_model] is the values of the inputs of the selected backend
    that have been set. *)

val init : model
(** The model as the page opens. *)

val choices : edit_model -> WebChoices.t
(** [choices edit_model] is the choices of [edit_model] the browser remembers.
*)

val restored : string option -> model
(** [restored stored] is the model as the page opens, with the choices encoded
    by [stored] ({!WebChoices.encode}) restored as far as they are still valid:
    the example, found by its path or else by its group and title, loaded as
    from the gallery, or else the default one; then the grades and the backend
    selected, if known, the latter without loading its default example; then the
    inputs set. Without [stored], or if it encodes no choices, {!init}. *)

val opened : query:string -> string option -> model * side_effect list
(** [opened ~query stored] is the model as the page opens at an address of query
    [query] ({!WebLink}), with the choices encoded by [stored], and the effects
    it asks for: the query replaced by the one naming the resulting choices,
    which are remembered if [query] has parameters. Without parameters,
    [restored stored]; with them, the choices {!WebLink.resolve} yields,
    restored as [restored] restores them, with a notice of the parameters
    ignored. *)

val indentation : string
(** What a Tab in the editor inserts; the editor's [tab-size] matches. *)

val byte_offset : string -> int -> int
(** [byte_offset source offset] is the byte of [source] the browser's [offset]
    points at: a selection counts UTF-16 code units, an OCaml string UTF-8
    bytes, and the two part company outside ASCII. *)

val example_of_path : string -> (string * Examples_tpe.example) option
(** [example_of_path path] is the group label and the bundled example at [path],
    relative to the project root, if there is one. *)

val link_at : link list -> int -> int option
(** [link_at links offset] is the index of the first of [links] whose name
    covers the byte [offset] of the editor's text, its end included. *)

val update : model -> msg -> model * side_effect list
(** [update model msg] is the model after [msg] and the effects it asks for. *)
