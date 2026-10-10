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

val init : model
(** The model as the page opens. *)

val use_stdlib_key : string
(** The key the browser remembers whether to load the standard library under. *)

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
