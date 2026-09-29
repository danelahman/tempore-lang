open Vdom
module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
module SyntaxHighlight = WebInterpreter.SyntaxHighlight

(* Auxiliary definitions *)
(* [action] is placed at the right of the heading, opposite its name. *)
let panel ?(a = []) ?action heading blocks =
  let named =
    match action with
    | None -> [ text heading ]
    | Some action -> [ elt "span" [ text heading ]; action ]
  in
  div ~a:(class_ "panel" :: a)
    (elt "p" ~a:[ class_ "panel-heading" ] named :: blocks)

let panel_block = div ~a:[ class_ "panel-block" ]

let button txt msg =
  input [] ~a:[ onclick (fun _ -> msg); type_button; value txt ]

let disabled_button txt = input [] ~a:[ type_button; value txt; disabled true ]

let select ?(a = []) empty_description msg describe_choice selected choices =
  let view_choice choice =
    elt "option"
      ~a:[ bool_prop "selected" (selected choice) ]
      [ text (describe_choice choice) ]
  in
  div ~a
    [
      (* index 0 is the placeholder below, and a browser may report it *)
      elt "select"
        ~a:
          [
            on "change"
              Vdom.Decoder.(
                map
                  (fun i -> Option.map msg (List.nth_opt choices (i - 1)))
                  (field "target.selectedIndex" Int));
          ]
        (elt "option"
           ~a:
             [
               disabled true;
               (* Hidden so a browser leaves it out of the opened list, but
                  still shown in the closed control while nothing else is
                  selected, since it stays index 0 of the same <select>. *)
               bool_prop "hidden" true;
               value "";
               bool_prop "selected"
                 (List.for_all (fun choice -> not (selected choice)) choices);
             ]
           [ text empty_description ]
        :: List.map view_choice choices);
    ]

(* The one-line label of a choice listed under [heading]: the heading and the
   choice, separated by a dot. The heading and the dot are kept whole, so
   that distinct headings always read differently; the choice ends in an
   ellipsis where the line is too short for it. *)
let view_choice_label ?(a = []) ?heading choice =
  elt "span"
    ~a:(class_ "choice-label" :: a)
    ((match heading with
       | None -> []
       | Some heading ->
           [
             elt "span" ~a:[ class_ "choice-heading" ] [ text heading ];
             elt "span"
               ~a:[ class_ "choice-separator"; attr "aria-hidden" "true" ]
               [ text "\xC2\xB7" ];
           ])
    @ [ elt "span" ~a:[ class_ "choice-name" ] [ text choice ] ])

(* As [select], but the choices are laid out under labelled <optgroup>s,
   each group given as its label, the label's short form and its choices;
   [describe_title] fills the option's hover tooltip. The closed control
   shows the selected choice after the short form of its group's label: the
   select's own text is transparent, and a [view_choice_label] is laid over
   it, hidden from assistive technology, which reads the select itself; the
   select's tooltip gives the full label. The change handler
   still indexes into the flat list of choices, since a browser counts every
   <option> of a <select> in document order for "selectedIndex" whatever
   <optgroup>s it is laid out under. *)
let grouped_select ?(a = []) ?id empty_description msg describe_choice
    describe_title selected groups =
  let view_choice choice =
    elt "option"
      ~a:
        [
          bool_prop "selected" (selected choice);
          attr "title" (describe_title choice);
        ]
      [ text (describe_choice choice) ]
  in
  let view_group (label, _, choices) =
    elt "optgroup" ~a:[ attr "label" label ] (List.map view_choice choices)
  in
  let choices = List.concat_map (fun (_, _, choices) -> choices) groups in
  let current =
    List.find_map
      (fun (label, short, choices) ->
        Option.map
          (fun choice -> (label, short, describe_choice choice))
          (List.find_opt selected choices))
      groups
  in
  let (label, short), name =
    match current with
    | Some (label, short, name) -> ((Some label, Some short), name)
    | None -> ((None, None), empty_description)
  in
  div ~a
    [
      (* index 0 is the placeholder below, and a browser may report it *)
      elt "select"
        ~a:
          ((match id with None -> [] | Some id -> [ attr "id" id ])
          @ [
              attr "title"
                (String.concat " \xC2\xB7 " (Option.to_list label @ [ name ]));
              on "change"
                Vdom.Decoder.(
                  map
                    (fun i -> Option.map msg (List.nth_opt choices (i - 1)))
                    (field "target.selectedIndex" Int));
            ])
        (elt "option"
           ~a:
             [
               disabled true;
               (* Hidden so a browser leaves it out of the opened list, but
                  still shown in the closed control while nothing else is
                  selected, since it stays index 0 of the same <select>. *)
               bool_prop "hidden" true;
               value "";
               bool_prop "selected" (current = None);
             ]
           [ text empty_description ]
        :: List.map view_group groups);
      view_choice_label ~a:[ attr "aria-hidden" "true" ] ?heading:short name;
    ]

let nil = text ""

(* Octicons (MIT licensed, Copyright (c) GitHub Inc.; see THIRD-PARTY.md),
   drawn in the current text colour so that they follow the hover styling of
   the link they sit in. *)
let octicon path =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "16";
        attr "height" "16";
        attr "aria-hidden" "true";
      ]
    [ svg_elt "path" ~a:[ attr "fill" "currentColor"; attr "d" path ] [] ]

let book_mark =
  octicon
    "M0 1.75A.75.75 0 0 1 .75 1h4.253c1.227 0 2.317.59 3 1.501A3.744 3.744 0 0 \
     1 11.006 1h4.245a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-4.507a2.25 \
     2.25 0 0 0-1.591.659l-.622.621a.75.75 0 0 1-1.06 0l-.622-.621A2.25 2.25 0 \
     0 0 5.258 13H.75a.75.75 0 0 1-.75-.75Zm7.251 \
     10.324.004-5.073-.002-2.253A2.25 2.25 0 0 0 5.003 2.5H1.5v9h3.757a3.75 \
     3.75 0 0 1 1.994.574ZM8.755 4.75l-.004 7.322a3.752 3.752 0 0 1 \
     1.992-.572H14.5v-9h-3.495a2.25 2.25 0 0 0-2.25 2.25Z"

let code_mark =
  octicon
    "m11.28 3.22 4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.749.749 0 0 \
     1-1.275-.326.749.749 0 0 1 .215-.734L13.94 8l-3.72-3.72a.749.749 0 0 1 \
     .326-1.275.749.749 0 0 1 .734.215Zm-6.56 0a.751.751 0 0 1 \
     1.042.018.751.751 0 0 1 .018 1.042L2.06 8l3.72 3.72a.749.749 0 0 1-.326 \
     1.275.749.749 0 0 1-.734-.215L.47 8.53a.75.75 0 0 1 0-1.06Z"

(* The other page is reached from the side panel's heading. The mark stands on
   its own there, so the name it is given is the one read out. *)
let page_link target =
  let mark, label =
    match target with
    | Model.Docs -> (book_mark, "Documentation")
    | Model.Editor -> (code_mark, "Editor")
  in
  elt "a"
    ~a:
      [
        class_ "panel-action";
        attr "href" "#";
        attr "title" label;
        attr "aria-label" label;
        onclick ~prevent_default:() (fun _ -> Model.ShowPage target);
      ]
    [ mark ]

let view_contents main aside =
  div
    ~a:[ class_ "contents columns" ]
    [
      div ~a:[ class_ "main column is-three-quarters" ] main;
      div ~a:[ class_ "aside column is-one-quarter" ] aside;
    ]

(* Edit view *)

(* An error that stopped the program from being loaded is highlighted in the
   editor and explained under it, in the colour of a Bulma "danger" message. *)

(* The standard library is loaded as a source of its own, under a file name,
   and is neither shown nor editable; only editor spans can be marked. *)
let in_editor (loc : Location.t) = loc.filename = ""

(* The ids the error's spans are given in the editor, so that the message
   under it can link to them and the page can scroll to them. *)
let primary_id i = Printf.sprintf "error-primary-%d" i
let label_id i j = Printf.sprintf "error-label-%d-%d" i j
let error_id i = Printf.sprintf "editor-error-%d" i

(* The kind of error and where it points: an editor span by its line and
   characters, a standard-library span by its file as well. *)
let load_error_header (error : Model.load_error) =
  let kind = Diagnostic.kind_to_string error.diagnostic.kind in
  match error.diagnostic.primary with
  | None -> kind
  | Some loc when in_editor loc ->
      Format.asprintf "%s at %t" kind (Location.print_short loc)
  | Some loc ->
      Format.asprintf "%s in the standard library (%t)" kind
        (Location.print loc)

(* The same, cut down for the side panel's list: no characters, no file. *)
let load_error_summary (error : Model.load_error) =
  let kind = Diagnostic.kind_to_string error.diagnostic.kind in
  match error.diagnostic.primary with
  | None -> kind
  | Some loc when in_editor loc ->
      Printf.sprintf "%s at line %d" kind loc.start.line
  | Some _ -> kind ^ " in the standard library"

(* Text with each rigid variable [ε_Op] set as [ε] with the operation [Op] as
   a subscript, followed by its primes. *)
let with_rigids s =
  let n = String.length s in
  let at i w = i + String.length w <= n && String.sub s i (String.length w) = w
  and is_name i =
    i < n
    &&
    match s.[i] with
    | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  let rec names i = if is_name i then names (i + 1) else i in
  let rec primes i = if at i "′" then primes (i + String.length "′") else i in
  let piece start stop acc =
    if stop > start then text (String.sub s start (stop - start)) :: acc
    else acc
  in
  let rec go start i acc =
    if i >= n then List.rev (piece start n acc)
    else if at i "ε_" && is_name (i + String.length "ε_") then
      let first = i + String.length "ε_" in
      let stop = names first in
      let stop' = primes stop in
      let rigid =
        elt "span"
          ~a:[ class_ "rigid" ]
          [
            text "ε";
            elt "sub" [ text (String.sub s first (stop - first)) ];
            text (String.sub s stop (stop' - stop));
          ]
      in
      go stop' stop' (rigid :: piece start i acc)
    else go start (i + 1) acc
  in
  go 0 0 []

(* The backticks a diagnostic marks its code fragments with are not shown, as
   they are in a terminal; the fragments are set in a monospace font. *)
let rendered message =
  List.concat_map
    (function
      | `Text prose -> with_rigids prose
      | `Code fragment ->
          [ elt "code" ~a:[ class_ "diag-code" ] (with_rigids fragment) ])
    (Diagnostic.segments message)

(* Popovers *)

(* The key of a popover target, which the spans it describes carry in their
   classes, after [EditorDom.key_prefix], and a gutter marker in its
   [data-popover] attribute. *)
let target_key = function
  | Model.Error_span i -> Printf.sprintf "e%d" i
  | Model.Error_label (i, j) -> Printf.sprintf "l%d-%d" i j
  | Model.Definition k -> Printf.sprintf "d%d" k
  | Model.Reference k -> Printf.sprintf "r%d" k

let target_of_key key =
  let parse fmt f = try Some (Scanf.sscanf key fmt f) with _ -> None in
  match key.[0] with
  | 'e' -> parse "e%d%!" (fun i -> Model.Error_span i)
  | 'l' -> parse "l%d-%d%!" (fun i j -> Model.Error_label (i, j))
  | 'd' -> parse "d%d%!" (fun k -> Model.Definition k)
  | 'r' -> parse "r%d%!" (fun k -> Model.Reference k)
  | _ | (exception Invalid_argument _) -> None

(* The classes of a span described by a popover. *)
let popover_classes target =
  "has-popover " ^ EditorDom.key_prefix ^ target_key target

(* Of the spans at one point, a label is described before the error it belongs
   to, and an error before the definition or name it lies in. *)
let key_precedence =
  List.map (fun prefix -> String.starts_with ~prefix) [ "l"; "e"; "d"; "r" ]

let popover_id = "code-popover"

(* The error a popover target belongs to. *)
let target_error = function
  | Model.Error_span i | Model.Error_label (i, _) -> Some i
  | Model.Definition _ | Model.Reference _ -> None

let popover_target (model : Model.model) =
  match model.popover with
  | Some { target; shown = true; _ } -> Some target
  | _ -> None

(* The line numbers of one error are separate elements, so they are lit as a
   block through the model: each reports the pointer entering or leaving, and
   wears [is-hover] while the model says this error is the one under it. They
   open the error's popover as well, by the pointer or the keyboard focus, and
   are described by it while it is open. *)
let error_number_attrs ~hovered ~described i (error : Model.load_error) =
  (if hovered then [ class_ "is-hover" ] else [])
  @ (if described then [ attr "aria-describedby" popover_id ] else [])
  @ [
      attr "aria-label"
        (Diagnostic.kind_to_string error.diagnostic.kind
        ^ ": " ^ error.diagnostic.message);
      attr "data-popover" (target_key (Model.Error_span i));
      onmouseenter (fun _ -> Model.HoverError (Some i));
      onmouseleave (fun _ -> Model.HoverError None);
      onfocus (Model.Reveal (Model.Error_span i));
      onblur Model.Conceal;
    ]

(* What the [i]th error marks in the editor: its primary span, whose lines the
   gutter numbers in red, and, under [with_labels], each of its labels, the
   hovered one brightened. Standard-library spans mark nothing. [popover] is
   the target of the open popover. *)
let marks_of_error ~hovered ~with_labels ~popover i (error : Model.load_error) =
  let mark ?marker mark_cls id (loc : Location.t) =
    if in_editor loc then
      [
        {
          SyntaxHighlight.from = loc.start.offset;
          until = loc.stop.offset;
          mark_cls;
          id = Some id;
          marker;
        };
      ]
    else []
  in
  (match error.diagnostic.primary with
    | Some loc ->
        mark
          ((if hovered then "error-primary is-hover" else "error-primary")
          ^ " "
          ^ popover_classes (Model.Error_span i))
          (primary_id i) loc
          ~marker:
            {
              SyntaxHighlight.href = "#" ^ error_id i;
              attrs =
                error_number_attrs ~hovered
                  ~described:(popover = Some (Model.Error_span i))
                  i error;
            }
    | None -> [])
  @
  if not with_labels then []
  else
    List.concat
      (List.mapi
         (fun j ({ span; _ } : Diagnostic.label) ->
           let mark_cls =
             (if
                error.hovered_label = Some j
                || popover = Some (Model.Error_label (i, j))
              then "error-related error-hover"
              else "error-related")
             ^ " "
             ^ popover_classes (Model.Error_label (i, j))
           in
           mark mark_cls (label_id i j) span)
         error.diagnostic.labels)

(* What to scroll to for an error: its highlighted primary span when it has
   one in the editor, otherwise the message block under the editor. *)
let load_error_target i (error : Model.load_error) =
  match error.diagnostic.primary with
  | Some loc when in_editor loc -> primary_id i
  | _ -> error_id i

(* One error's message. [active] is the error the caret sits in and [flashed]
   the error just gone to; under [stale] the editor marks nothing, so the
   links into it are left out. *)
let view_load_error ~stale ~active ~flashed i (error : Model.load_error) =
  (* In the editor a label links to its span, which lights up while the
     pointer is on it; a standard-library span can only be named. *)
  let view_label j ({ span; text = label_text } : Diagnostic.label) =
    (* No excerpt is shown here, so a label that says "here" is made to name
       the line instead, and needs no line reference after it. *)
    let place =
      if in_editor span then Printf.sprintf "on line %d" span.start.line
      else Printf.sprintf "on line %d of the standard library" span.start.line
    in
    let placed = Diagnostic.render_label_text ~place label_text in
    let where =
      if placed <> label_text then []
      else
        [
          elt "span"
            ~a:[ class_ "error-line-ref" ]
            [
              text
                (if in_editor span then
                   Printf.sprintf " (line %d)" span.start.line
                 else
                   Printf.sprintf " (standard library, line %d)" span.start.line);
            ];
        ]
    in
    let content = rendered placed @ where in
    if in_editor span && not stale then
      elt "li"
        ~a:[ onmouseenter (fun _ -> Model.HoverLabel (Some (i, j))) ]
        [ elt "a" ~a:[ attr "href" ("#" ^ label_id i j) ] content ]
    else elt "li" content
  in
  let labels =
    match error.diagnostic.labels with
    | [] -> []
    | labels ->
        [
          elt "ul"
            ~a:
              [
                class_ "error-labels";
                onmouseleave (fun _ -> Model.HoverLabel None);
              ]
            (List.mapi view_label labels);
        ]
  and notes =
    match error.diagnostic.notes with
    | [] -> []
    | notes ->
        [
          elt "ul"
            ~a:[ class_ "error-notes" ]
            (List.map (fun note -> elt "li" (rendered note)) notes);
        ]
  in
  let header_aside =
    if stale then elt "span" ~a:[ class_ "stale-note" ] [ text "out of date" ]
    else
      match error.diagnostic.primary with
      | Some loc when in_editor loc ->
          elt "a"
            ~a:[ class_ "show-in-editor"; attr "href" ("#" ^ primary_id i) ]
            [ text "show in editor" ]
      | _ -> nil
  in
  let classes =
    String.concat " "
      ([ "message"; "is-danger"; "editor-error" ]
      @ (if active then [ "is-active" ] else [])
      @ (if flashed then [ "is-flashed" ] else [])
      @ if stale then [ "is-stale" ] else [])
  in
  elt "article"
    ~a:[ class_ classes; attr "id" (error_id i) ]
    [
      div
        ~a:
          [
            class_ "message-header";
            onmouseenter (fun _ -> Model.HoverError (Some i));
            onmouseleave (fun _ -> Model.HoverError None);
          ]
        [
          elt "p"
            [
              text
                (Printf.sprintf "Error %d — %s" (i + 1)
                   (load_error_header error));
            ];
          header_aside;
        ];
      div
        ~a:[ class_ "message-body" ]
        ((elt "p" (rendered error.diagnostic.message) :: labels) @ notes);
    ]

(* The link whose name is under the pointer of a mouse [event], while the
   modifier of links is held. *)
let link_under (model : Model.model) event =
  if model.links <> [] && EditorDom.modifier_held event then
    EditorDom.link_at (EditorDom.point event)
  else None

(* Tab inside the editor inserts an indentation instead of moving the focus
   to the next control; Shift+Tab is left alone, so the keyboard can still
   leave the editor backwards. The browser's own value and selection are read
   off the event, since the model may lag behind a fast typist. F12 goes to
   the definition of the name at the caret, when it has a known one. *)
let oneditor_keys (model : Model.model) =
  let open Vdom.Decoder in
  let target d = field "target" d in
  let ignored =
    { Vdom.msg = None; prevent_default = false; stop_propagation = false }
  in
  on_with_options "keydown"
    (bind
       (fun (key, shift) ->
         if key = "F12" && model.links <> [] && not model.stale_errors then
           map
             (fun offset ->
               match
                 Model.link_at model.links
                   (Model.byte_offset model.edit_model.unparsed_code offset)
               with
               | Some _ ->
                   {
                     Vdom.msg = Some (Model.FollowAt offset);
                     prevent_default = true;
                     stop_propagation = false;
                   }
               | None -> ignored)
             (target (field "selectionStart" Int))
         else if key = "Tab" && not shift then
           app
             (app
                (app
                   (const (fun source start stop ->
                        {
                          Vdom.msg =
                            Some
                              (Model.EditMsg
                                 (Model.InsertIndent (source, start, stop)));
                          prevent_default = true;
                          stop_propagation = false;
                        }))
                   (target (field "value" String)))
                (target (field "selectionStart" Int)))
             (target (field "selectionEnd" Int))
         else const ignored)
       (app
          (app (const (fun k s -> (k, s))) (field "key" String))
          (field "shiftKey" Bool)))

(* Clicking in the editor moves the caret, and so do the keys that move it
   without editing; the error whose span it lands in becomes the active one,
   and the popover of the span or name it lands in opens. Where the caret ends
   up is read off the event, the model not tracking it. A click with the
   modifier of links held on the name of a link goes to its definition. *)
let oncaret_at (model : Model.model) =
  on_js "click" (function
    | Vdom_blit.Ojs event -> (
        match link_under model event with
        | Some k -> Some (Model.Follow k)
        | None ->
            Some
              (Model.CaretAt
                 (Ojs.int_of_js
                    (Ojs.get_prop_ascii
                       (Ojs.get_prop_ascii event "target")
                       "selectionStart"))))
    | _ -> None)

let caret_keys =
  [
    "ArrowLeft";
    "ArrowRight";
    "ArrowUp";
    "ArrowDown";
    "Home";
    "End";
    "PageUp";
    "PageDown";
  ]

let oncaret_keys =
  let open Vdom.Decoder in
  on "keyup"
    (app
       (app
          (const (fun key offset ->
               if List.mem key caret_keys then Some (Model.CaretAt offset)
               else None))
          (field "key" String))
       (field "target" (field "selectionStart" Int)))

(* A scheme as [name : ∀ α. Q ⇒ A], on one line where it fits and otherwise
   the name, the quantifier, each conjunct of the qualifier and the type on
   lines of their own, aligned; an ordering too long for its line is broken
   before [≾], and a type before its outermost arrows. Text is annotated by
   its class. *)
let scheme_doc (d : Model.definition) =
  let open Layout in
  let name t = Text ("scheme-name", t)
  and plain t = Text ("", t)
  and dim t = Text ("scheme-qualifier", t)
  and ty t = Text ("scheme-type", t) in
  let conjunct = function
    | Model.Formula f -> dim f
    | Model.Ordering { binder; left; right } -> (
        let sides = Align (Cat [ dim left; Line; dim ("≾ " ^ right) ]) in
        match binder with
        | None -> Group sides
        | Some b -> Group (Cat [ dim ("(∀" ^ b ^ ". "); sides; dim ")" ]))
  in
  let arrows =
    match d.scheme.arrows with
    | [] -> Cat []
    | first :: rest ->
        Group
          (Align
             (Cat
                (ty first
                :: List.map (fun a -> Cat [ Line; ty ("→ " ^ a) ]) rest)))
  in
  let quantifier =
    Option.map
      (fun p -> Nest (2, Cat [ Line; dim ("∀ " ^ p ^ ".") ]))
      d.scheme.parameters
  and qualifier =
    match d.scheme.conjuncts with
    | [] -> []
    | c :: cs ->
        Nest (6, Cat [ Line; conjunct c ])
        :: List.map (fun c -> Nest (4, Cat [ Line; dim "∧ "; conjunct c ])) cs
  in
  let typed =
    Nest (4, Cat [ Line; (if qualifier = [] then Cat [] else dim "⇒ "); arrows ])
  in
  Group
    (Cat
       ([ name d.name; plain " :" ]
       @ Option.to_list quantifier @ qualifier @ [ typed ]))

(* The width a scheme is laid out in before its card is measured. *)
let default_columns = 100

(* A scheme laid out in [columns] characters, its quantifier and qualifier
   dimmed. *)
let view_scheme ~columns (d : Model.definition) =
  let run (cls, s) =
    match cls with
    | None | Some "" -> [ text s ]
    | Some cls -> [ elt "span" ~a:[ class_ cls ] (with_rigids s) ]
  in
  List.concat
    (List.mapi
       (fun k line ->
         (if k > 0 then [ text "\n" ] else []) @ List.concat_map run line)
       (Layout.layout ~width:columns (scheme_doc d)))

let px x = Printf.sprintf "%.2fpx" x

(* A definition of the standard library: where it is, its line, highlighted as
   the editor highlights, and the scheme of a value. *)
let view_library_entry ~columns (entry : Model.library_entry) =
  [
    elt "p"
      ~a:[ class_ "code-popover-place" ]
      [ text (Printf.sprintf "Standard library, line %d" entry.line) ];
    elt "pre"
      ~a:[ class_ "code-popover-source syn-ml" ]
      (SyntaxHighlight.highlight_text (String.trim entry.text));
  ]
  @
  match entry.value with
  | Some d ->
      [ elt "p" ~a:[ class_ "code-popover-scheme" ] (view_scheme ~columns d) ]
  | None -> []

(* The open popover: for an error's span, its kind and headline, then the
   label of the span when it is one of the error's labels and otherwise the
   error's first note, and a link to its message; for a definition's name, its
   scheme; for a name defined in the standard library, its definition. It is
   drawn hidden until measured, and then placed under or above its span, a
   scheme laid out again first when the measured width differs. *)
let view_popover (model : Model.model) errors =
  let columns = Option.value ~default:default_columns model.columns in
  let error_card i label =
    Option.map
      (fun (error : Model.load_error) ->
        let d = error.diagnostic in
        let label =
          Option.bind label (List.nth_opt d.labels)
          |> Option.map (fun (l : Diagnostic.label) ->
              elt "p"
                ~a:[ class_ "code-popover-label" ]
                (rendered (Diagnostic.render_label_text ~place:"here" l.text)))
        in
        let note =
          match (label, d.notes) with
          | None, note :: _ ->
              [ elt "p" ~a:[ class_ "code-popover-note" ] (rendered note) ]
          | Some _, _ | None, [] -> []
        in
        ( (if Option.is_some label then "is-label" else "is-error"),
          [
            elt "p"
              ~a:[ class_ "code-popover-title" ]
              (elt "span"
                 ~a:[ class_ "code-popover-kind" ]
                 [ text (Diagnostic.kind_to_string d.kind ^ ":") ]
              :: text " " :: rendered d.message);
          ]
          @ Option.to_list label @ note
          @ [
              elt "a"
                ~a:
                  [
                    class_ "code-popover-link";
                    attr "href" ("#" ^ error_id i);
                    onclick ~prevent_default:() (fun _ -> Model.ShowFullError i);
                  ]
                [ text "Show full error" ];
            ] ))
      (List.nth_opt errors i)
  in
  let card target =
    match target with
    | Model.Error_span i -> error_card i None
    | Model.Error_label (i, j) -> error_card i (Some j)
    | Model.Definition k ->
        Option.map
          (fun d ->
            ( "is-type",
              [
                elt "p"
                  ~a:[ class_ "code-popover-scheme" ]
                  (view_scheme ~columns d);
              ] ))
          (List.nth_opt model.definitions k)
    | Model.Reference k -> (
        match List.nth_opt model.links k with
        | Some { destination = Model.In_library entry; _ } ->
            Some ("is-type", view_library_entry ~columns entry)
        | Some { destination = Model.In_editor _; _ } | None -> None)
  in
  match model.popover with
  | Some ({ shown = true; _ } as popover) -> (
      match card popover.target with
      | None -> nil
      | Some (kind, body) ->
          let placed, arrow =
            match popover.placement with
            | None -> ([ class_ ("code-popover " ^ kind) ], [])
            | Some p ->
                ( [
                    class_
                      (String.concat " "
                         ([ "code-popover"; kind; "is-placed" ]
                         @ if p.above then [ "is-above" ] else []));
                    style "left" (px p.left);
                    style "top" (px p.top);
                    style "width" (px p.width);
                  ],
                  [ style "left" (px p.arrow) ] )
          in
          div
            ~a:(attr "id" popover_id :: attr "role" "tooltip" :: placed)
            (elt "span"
               ~a:
                 (class_ "code-popover-arrow"
                 :: attr "aria-hidden" "true" :: arrow)
               []
            :: body))
  | _ -> nil

(* What the pointer is over in the editor, reported when it changes. *)
let onpointer (model : Model.model) =
  on_js "mousemove" (function
    | Vdom_blit.Ojs event ->
        let pointer =
          match EditorDom.under ~precedence:key_precedence event with
          | `Popover -> Model.Over_popover
          | `Key key -> (
              match target_of_key key with
              | Some target -> Model.Over_target target
              | None -> Model.Nowhere)
          | `Nothing -> Model.Nowhere
        and link = link_under model event in
        if pointer = model.pointer && link = model.link then None
        else Some (Model.Point (pointer, link, EditorDom.point event))
    | _ -> None)

(* The pointer leaving the editor, rather than moving between its layers. *)
let onpointer_leave (model : Model.model) =
  on_js "mouseleave" (function
    | Vdom_blit.Ojs event
      when (model.pointer <> Model.Nowhere || model.link <> None)
           && not (EditorDom.moves_within ".code-editor" event) ->
        Some (Model.Point (Model.Nowhere, None, EditorDom.point event))
    | _ -> None)

let onescape_popover (model : Model.model) =
  on "keydown"
    Vdom.Decoder.(
      map
        (fun key ->
          if key = "Escape" && model.popover <> None then Some Model.Conceal
          else None)
        (field "key" String))

(* The editor proper: the highlighted text, with the errors' spans and the
   definitions' names marked, the transparent textarea stretched over it, and
   the open popover. *)
let view_editor ~marks ~errors (model : Model.model) =
  let source = model.edit_model.unparsed_code in
  let lines = String.split_on_char '\n' source |> List.length in
  let rows = max 10 lines in
  let highlighted =
    SyntaxHighlight.highlight_with_marks ~line_numbers:true ~marks
      (source ^ "\n")
  in
  (* The gutter is a small inset, the line numbers (0.558rem a digit at the
     editor's 0.9rem) and a gap; in rem so the marker's smaller font can use it. *)
  let gutter =
    Printf.sprintf "calc(0.36rem + %d * 0.558rem + 0.63rem)"
      (String.length (string_of_int lines))
  in
  let described =
    match (popover_target model, model.caret_target) with
    | Some target, Some target' when target = target' ->
        [ attr "aria-describedby" popover_id ]
    | _ -> []
  in
  div
    ~a:
      [
        class_
          (if model.link <> None then "code-editor is-linking"
           else "code-editor");
        style "--gutter" gutter;
        onpointer model;
        onpointer_leave model;
        onescape_popover model;
      ]
    [
      elt "pre" ~a:[ class_ "code-editor-display syn-ml" ] highlighted;
      elt "textarea"
        ~a:
          ([
             class_ "code-editor-input";
             (* bound as a property, so that loading an example replaces
                what the user has typed; a text child would only set the
                default value, which the browser ignores once the textarea
                has been edited *)
             str_prop "value" source;
             oninput (fun input -> Model.EditMsg (Model.ChangeSource input));
             oneditor_keys model;
             oncaret_at model;
             oncaret_keys;
             int_prop "rows" rows;
             attr "placeholder" "Type a program, or load an example";
             attr "aria-label" "Program";
             attr "spellcheck" "false";
             attr "autocapitalize" "off";
             attr "autocorrect" "off";
           ]
          @ described)
        [];
      view_popover model errors;
    ]

(* let _view (model : Model.model) =
   match model.loaded_code with
   | Ok code ->
       div
         [
           input ~a:[type_ "range"; int_attr "min" 0; int_attr "max" 10; int_attr "step" 2; onmousedown (fun event -> Model.ParseInterrupt (string_of_int event.x))] [];
           (* elt "progress" ~a:[type_ "range"; value (string_of_int model.random_step_size); int_attr "max" 10; oninput (fun input -> Model.ChangeStepSize input)] []; *)
           editor model;
           actions model code;
           view_operations code.snapshot.operations;
           view_process code.snapshot.process;
         ]
   | Error msg -> div [ editor model; text msg ] *)

(* The mark of the outcome of a check, a stroke drawn in the current text
   colour. *)
let check_mark cls path =
  svg_elt "svg"
    ~a:
      [
        class_ ("check-status-mark " ^ cls);
        attr "viewBox" "0 0 16 16";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "path"
        ~a:
          [
            attr "d" path;
            attr "fill" "none";
            attr "stroke" "currentColor";
            attr "stroke-width" "2.2";
            attr "stroke-linecap" "round";
            attr "stroke-linejoin" "round";
          ]
        [];
    ]

let tick cls = check_mark cls "M3 8.6l3.3 3.2L13 4.6"
let cross cls = check_mark cls "M4.5 4.5l7 7M11.5 4.5l-7 7"

(* [count n noun] is [n] followed by [noun], in the plural unless [n] is 1. *)
let count n noun = Printf.sprintf "%d %s%s" n noun (if n = 1 then "" else "s")

(* The parts of the text of the status, separated by dots. Under [clipped],
   text that overflows the line ends in an ellipsis. *)
let view_status_text ~clipped parts =
  elt "span"
    ~a:
      [
        class_
          (if clipped then "check-status-text is-clipped"
           else "check-status-text");
      ]
    (List.concat
       (List.mapi
          (fun k part -> if k = 0 then part else text " \xC2\xB7 " :: part)
          parts))

(* The number of definitions, in full and abbreviated; the page shows the
   abbreviation where it has measured that the line cannot hold the full
   text, which assistive technology reads throughout. *)
let view_definitions n =
  [
    elt "span" ~a:[ class_ "check-status-full" ] [ text (count n "definition") ];
    elt "span"
      ~a:[ class_ "check-status-abbreviated"; attr "aria-hidden" "true" ]
      [ text (Printf.sprintf "%d %s" n (if n = 1 then "def." else "defs.")) ];
  ]

let status_id = "check-status"

(* The line under the buttons stating the outcome of the last check, empty
   before any. While a check is under way, a note saying so takes its place
   once the check has lasted a moment (see the page's style). The line is a
   live region, present throughout so that its changes are announced. *)
let view_check_status (model : Model.model) =
  let outcome ?(clipped = true) mark parts =
    elt "span"
      ~a:
        [
          class_
            (if model.checking <> None then "check-status-outcome is-superseded"
             else "check-status-outcome");
        ]
      [ mark; view_status_text ~clipped parts ]
  in
  let outcome =
    match model.last_check with
    | None -> []
    | Some { current = false; errors; _ } ->
        [
          outcome
            (if errors = 0 then tick "is-success is-dimmed"
             else cross "is-danger is-dimmed")
            [ [ text "Edited since the last check" ] ];
        ]
    | Some { errors = 0; definitions; _ } ->
        [
          outcome (tick "is-success")
            [
              [ text "Checked \xE2\x80\x94 no errors" ];
              view_definitions definitions;
            ];
        ]
    | Some { errors; _ } ->
        let target =
          match model.run_model with
          | Error (error :: _) -> load_error_target 0 error
          | _ -> error_id 0
        in
        [
          outcome ~clipped:false (cross "is-danger")
            [
              [
                elt "a"
                  ~a:
                    [
                      class_ "check-status-errors";
                      attr "href" ("#" ^ target);
                      attr "title" "Go to the first error";
                      onclick ~prevent_default:() (fun _ -> Model.GoToError 0);
                    ]
                  [
                    text (count errors "error");
                    elt "span"
                      ~a:[ class_ "is-sr-only" ]
                      [ text ", go to the first" ];
                  ];
              ];
            ];
        ]
  and progress =
    if model.checking = None then []
    else
      [
        elt "span"
          ~a:[ class_ "check-status-progress" ]
          [
            elt "span"
              ~a:[ class_ "check-spinner"; attr "aria-hidden" "true" ]
              [];
            text "Checking\xE2\x80\xA6";
          ];
      ]
  in
  div
    ~a:
      [
        class_
          (if model.abbreviated then "check-status is-abbreviated"
           else "check-status");
        attr "id" status_id;
        attr "role" "status";
        attr "aria-live" "polite";
      ]
    (outcome @ progress)

let view_compiler (model : Model.model) =
  let use_stdlib =
    elt "label"
      ~a:[ class_ "panel-block" ]
      [
        input
          ~a:
            [
              type_ "checkbox";
              onchange_checked (fun use_stdlib ->
                  Model.EditMsg (Model.UseStdlib use_stdlib));
              bool_prop "checked" model.edit_model.use_stdlib;
            ]
          [];
        text "Load standard library";
      ]
  in
  let load_example =
    div
      ~a:[ class_ "panel-block" ]
      [
        div
          ~a:[ class_ "field" ]
          [
            elt "label" ~a:[ class_ "label" ] [ text "Example" ];
            div
              ~a:[ class_ "control is-expanded" ]
              [
                (* opens the gallery, see [view_gallery]; labelled by the
                   example last loaded, after the short form of the label of
                   the group it is listed under, the tooltip and the
                   accessible name giving the full label *)
                elt "button"
                  ~a:
                    ([
                       class_ "button is-fullwidth example-button";
                       type_button;
                       onclick (fun _ -> Model.OpenGallery);
                     ]
                    @
                    match model.edit_model.selected_example with
                    | Some (group, title) ->
                        [
                          attr "title" (group ^ " \xC2\xB7 " ^ title);
                          attr "aria-label" ("Example: " ^ group ^ ", " ^ title);
                        ]
                    | None -> [])
                  [
                    (match model.edit_model.selected_example with
                    | Some (group, title) ->
                        view_choice_label
                          ~heading:
                            (List.find_map
                               (fun (g : Examples_tpe.group) ->
                                 if g.label = group then Some g.short else None)
                               Examples_tpe.examples
                            |> Option.value ~default:group)
                          title
                    | None -> view_choice_label "Load example");
                    elt "span"
                      ~a:[ class_ "has-text-grey" ]
                      [ text "\xE2\x80\xA6" ];
                  ];
              ];
          ];
      ]
  and select_resource =
    div
      ~a:[ class_ "panel-block" ]
      [
        div
          ~a:[ class_ "field" ]
          [
            elt "label"
              ~a:[ class_ "label"; attr "for" "grades-select" ]
              [ text "Grades" ];
            div
              ~a:[ class_ "control is-expanded" ]
              [
                (* Grouped as {!Grades.GradeRegistry.groups} groups them,
                   without the grades offered by the CLI only, the option text
                   its title and the tooltip its description. *)
                grouped_select
                  ~a:[ class_ "select is-fullwidth choice-select" ]
                  ~id:"grades-select" "Select grades"
                  (fun (name, _) -> Model.EditMsg (Model.SelectResource name))
                  (fun (_, (info : Grades.GradeRegistry.info)) -> info.title)
                  (fun (_, (info : Grades.GradeRegistry.info)) ->
                    info.description)
                  (fun (name, _) -> name = model.edit_model.selected_resource)
                  (List.map
                     (fun (g : Grades.GradeRegistry.group) ->
                       ( g.label,
                         g.short,
                         List.filter
                           (fun (_, (info : Grades.GradeRegistry.info)) ->
                             info.visibility = Everywhere)
                           g.grades ))
                     Grades.GradeRegistry.groups);
              ];
            elt "p"
              ~a:
                [
                  class_ "grades-command";
                  attr "title"
                    ("./tempore --grades " ^ model.edit_model.selected_resource
                   ^ " file.tpe");
                ]
              [ text model.edit_model.selected_resource ];
          ];
      ]
  and run_process =
    (* Typecheck stays in the editor; Run typechecks and, without errors, runs
       the program. While a check is under way, the button pressed shows a
       spinner and neither takes a press; they are marked disabled for
       assistive technology only, so that the focus stays on them. *)
    let action cls label pressed msg =
      let state =
        match model.checking with
        | None -> []
        | Some action when action = pressed -> [ "is-checking" ]
        | Some _ -> [ "is-waiting" ]
      in
      div
        ~a:[ class_ "field" ]
        [
          elt "button"
            ~a:
              ([
                 class_
                   (String.concat " "
                      ([ "button"; "is-info"; "is-fullwidth"; "check-action" ]
                      @ cls @ state));
                 type_button;
                 onclick (fun _ -> msg);
               ]
              @
              if model.checking = None then []
              else [ attr "aria-disabled" "true" ])
            [ elt "span" [ text label ] ];
        ]
    in
    panel_block
      [
        action [ "is-outlined" ] "Typecheck" Model.Check Model.CheckCode;
        action [] "Run" Model.Run Model.RunCode;
        view_check_status model;
        (* every error shown under the editor, which may be far below when the
           program is long; clicking one scrolls to its message *)
        (match model.run_model with
        | Error (_ :: _ as errors) ->
            let view_entry i error =
              elt "li"
                ~a:
                  ((if model.active_error = Some i then [ class_ "is-active" ]
                    else [])
                  @ [
                      onmouseenter (fun _ -> Model.HoverError (Some i));
                      onmouseleave (fun _ -> Model.HoverError None);
                    ])
                [
                  elt "a"
                    ~a:
                      [
                        attr "href"
                          ("#"
                          ^
                          if model.stale_errors then error_id i
                          else load_error_target i error);
                        onclick ~prevent_default:() (fun _ -> Model.GoToError i);
                      ]
                    [ text (load_error_summary error) ];
                ]
            in
            elt "ol"
              ~a:
                [
                  class_
                    (if model.stale_errors then "error-list is-stale"
                     else "error-list");
                ]
              (List.mapi view_entry errors)
        | _ -> nil);
      ]
  in
  panel ~action:(page_link Model.Docs) "Code options"
    [ use_stdlib; load_example; select_resource; run_process ]

let edit_view (model : Model.model) =
  let errors =
    match model.run_model with Error errors -> errors | Ok _ -> []
  in
  let stale = model.stale_errors in
  let popover = popover_target model in
  let pointed =
    match model.pointer with
    | Model.Over_target target -> target_error target
    | Model.Nowhere | Model.Over_popover -> None
  in
  (* Edited source: the spans have moved, so only the messages remain. *)
  let marks =
    if stale then []
    else
      List.concat
        (List.mapi
           (fun i (error : Model.load_error) ->
             (* Labels of every error at once would only confuse; they show
                for the error the user is looking at, or when it is alone. *)
             let with_labels =
               List.length errors = 1
               || model.hovered_error = Some i
               || model.active_error = Some i
               || error.hovered_label <> None
               || pointed = Some i
               || Option.bind popover target_error = Some i
             in
             marks_of_error
               ~hovered:(model.hovered_error = Some i)
               ~with_labels ~popover i error)
           errors)
      (* the names the definitions are given, each described by its scheme *)
      @ List.concat
          (List.mapi
             (fun k (d : Model.definition) ->
               match d.name_span with
               | Some (from, until) ->
                   [
                     {
                       SyntaxHighlight.from;
                       until;
                       mark_cls =
                         (if popover = Some (Model.Definition k) then
                            "def-name is-hover "
                          else "def-name ")
                         ^ popover_classes (Model.Definition k);
                       id = None;
                       marker = None;
                     };
                   ]
               | None -> [])
             model.definitions)
      (* the names of the links, one of them underlined while the modifier of
         links is held with the pointer on it *)
      @ List.mapi
          (fun k ({ use = from, until; _ } : Model.link) ->
            {
              SyntaxHighlight.from;
              until;
              mark_cls =
                String.concat " "
                  ([ "name-ref"; EditorDom.link_prefix ^ string_of_int k ]
                  @ (if model.link = Some k then [ "is-link" ] else [])
                  @
                  if popover = Some (Model.Reference k) then
                    [ "is-hover"; popover_classes (Model.Reference k) ]
                  else []);
              id = None;
              marker = None;
            })
          model.links
      @
      match model.flash with
      | Some (Model.Span (from, until)) ->
          [
            {
              SyntaxHighlight.from;
              until;
              mark_cls = "goto-flash";
              id = Some EditorDom.flash_id;
              marker = None;
            };
          ]
      | Some (Model.Message _) | None -> []
  in
  view_contents
    [
      div
        ~a:[ class_ "box editor-box" ]
        (view_editor ~marks ~errors model
        :: List.mapi
             (fun i error ->
               view_load_error ~stale
                 ~active:(model.active_error = Some i)
                 ~flashed:(model.flash = Some (Model.Message i))
                 i error)
             errors);
    ]
    [ view_compiler model ]

(* Example gallery *)

(* A layer over the page listing the examples of Examples_tpe, generated from
   examples/index (see the dune file), by group, with a search over them. *)

(* Whether [sub] occurs in [s]. *)
let contains ~sub s =
  let sub_len = String.length sub and s_len = String.length s in
  let rec at i =
    i + sub_len <= s_len && (String.sub s i sub_len = sub || at (i + 1))
  in
  at 0

(* The path under examples/, the directory every example lives in. *)
let example_path (e : Examples_tpe.example) =
  let prefix = "examples/" in
  if String.starts_with ~prefix e.path then
    String.sub e.path (String.length prefix)
      (String.length e.path - String.length prefix)
  else e.path

(* Whether [query], trimmed, occurs in the group, title, grade, description or
   path under examples/ of an example, ignoring case. *)
let matches query group (e : Examples_tpe.example) =
  contains
    ~sub:(String.lowercase_ascii (String.trim query))
    (String.lowercase_ascii
       (String.concat " "
          [ group; e.title; e.grade; e.description; example_path e ]))

let example_group_id k = Printf.sprintf "example-group-%d" k

(* An example's card, which loads it; [current] marks the example last
   loaded. *)
(* The id of the card of the example last loaded, which the page focuses
   when the gallery opens. *)
let current_example_id = "current-example"

let view_example_card ~current group (e : Examples_tpe.example) =
  elt "button"
    ~a:
      ([
         class_ (if current then "example-card is-current" else "example-card");
         type_button;
         onclick (fun _ ->
             Model.EditMsg
               (Model.LoadExample (group, e.title, e.grade, e.source)));
       ]
      @
      if current then
        [ attr "id" current_example_id; attr "aria-current" "true" ]
      else [])
    [
      elt "span" ~a:[ class_ "example-card-title" ] [ text e.title ];
      elt "span" ~a:[ class_ "example-card-description" ] [ text e.description ];
      elt "span"
        ~a:[ class_ "example-card-meta" ]
        [
          elt "span" ~a:[ class_ "example-card-grade" ] [ text e.grade ];
          elt "span" ~a:[ class_ "example-card-path" ] [ text (example_path e) ];
        ];
    ]

let onescape msg =
  on "keydown"
    Vdom.Decoder.(
      map
        (fun key -> if key = "Escape" then Some msg else None)
        (field "key" String))

(* The gallery with the search [query]: the groups with an example matching
   it, each listed in the side column and as a section of cards. Esc closes
   it, the layer taking the focus from a click inside the panel, and so does a
   click on the backdrop beside the panel. The search field takes the focus
   when the gallery opens with no example loaded; otherwise the page focuses
   the card of the example last loaded. *)
let view_gallery ~selected query =
  let groups =
    List.filter_map
      (fun (k, (g : Examples_tpe.group)) ->
        match List.filter (matches query g.label) g.examples with
        | [] -> None
        | examples -> Some (k, g, examples))
      (List.mapi (fun k g -> (k, g)) Examples_tpe.examples)
  in
  let view_toc_entry (k, (g : Examples_tpe.group), examples) =
    elt "a"
      ~a:[ attr "href" ("#" ^ example_group_id k) ]
      [
        text (g.label ^ " ");
        elt "span" [ text (Printf.sprintf "(%d)" (List.length examples)) ];
      ]
  in
  let view_group (k, (g : Examples_tpe.group), examples) =
    elt "section"
      ~a:[ class_ "example-group"; attr "id" (example_group_id k) ]
      [
        elt "header" [ elt "h3" [ text g.label ]; elt "p" [ text g.summary ] ];
        div
          ~a:[ class_ "example-cards" ]
          (List.map
             (fun (e : Examples_tpe.example) ->
               view_example_card
                 ~current:(selected = Some (g.label, e.title))
                 g.label e)
             examples);
      ]
  in
  div
    ~a:
      [
        class_ "example-gallery";
        attr "tabindex" "-1";
        onescape Model.CloseGallery;
      ]
    [
      div
        ~a:
          [
            class_ "example-gallery-backdrop";
            onclick (fun _ -> Model.CloseGallery);
          ]
        [];
      div
        ~a:
          [
            class_ "example-gallery-panel";
            attr "role" "dialog";
            attr "aria-modal" "true";
            attr "aria-label" "Examples";
          ]
        [
          div
            ~a:[ class_ "example-gallery-head" ]
            [
              elt "h2" [ text "Examples" ];
              input
                ~a:
                  ([
                     class_ "example-gallery-search";
                     attr "placeholder"
                       "Search examples, e.g. rollout, levels, handlers, regex";
                     attr "aria-label" "Search examples";
                     str_prop "value" query;
                     oninput (fun query -> Model.SearchGallery query);
                   ]
                  @ if selected = None then [ autofocus ] else [])
                [];
              elt "button"
                ~a:
                  [
                    class_ "example-gallery-close";
                    type_button;
                    attr "aria-label" "Close";
                    onclick (fun _ -> Model.CloseGallery);
                  ]
                [ text "\xC3\x97" ];
            ];
          div
            ~a:[ class_ "example-gallery-body" ]
            [
              elt "nav"
                ~a:[ class_ "example-gallery-toc" ]
                (List.map view_toc_entry groups);
              div
                ~a:[ class_ "example-gallery-list" ]
                (match groups with
                | [] ->
                    [
                      elt "p"
                        ~a:[ class_ "example-gallery-empty" ]
                        [ text "No example matches." ];
                    ]
                | _ -> List.map view_group groups);
            ];
        ];
    ]

(* Run view *)

let view_steps (run_model : Model.run_model) steps =
  let view_edit_source =
    panel_block
      [
        elt "button"
          ~a:
            [
              class_ "button is-outlined is-fullwidth is-danger";
              onclick (fun _ -> Model.EditCode);
              attr "title"
                "Re-editing source code will abort current evaluation";
            ]
          [ text "Re-edit source code" ];
      ]
  and view_undo_last_step =
    panel_block
      [
        elt "button"
          ~a:
            [
              class_ "button is-outlined is-fullwidth";
              onclick (fun _ -> Model.RunMsg Model.Back);
              disabled (run_model.history = []);
            ]
          [ text "Undo last step" ];
      ]
  and view_step i step =
    panel_block
      [
        elt "button"
          ~a:
            [
              class_ "button is-outlined is-fullwidth";
              onclick (fun _ -> Model.RunMsg (Model.MakeStep step));
              onmouseenter (fun _ ->
                  Model.RunMsg (Model.SelectStepIndex (Some i)));
            ]
          [ step.Model.label_vdom ];
      ]
  and view_random_steps steps =
    div
      ~a:[ class_ "panel-block" ]
      [
        div
          ~a:[ class_ "field has-addons" ]
          [
            div
              ~a:[ class_ "control" ]
              [
                select
                  ~a:[ class_ "select is-info" ]
                  "Step size"
                  (fun step_size ->
                    Model.RunMsg (Model.ChangeRandomStepSize step_size))
                  string_of_int
                  (fun step_size -> step_size = run_model.random_step_size)
                  [ 1; 2; 4; 8; 16; 32; 64; 128; 256; 512; 1024 ];
              ];
            div
              ~a:[ class_ "control is-expanded" ]
              [
                elt "button"
                  ~a:
                    [
                      class_ "button is-info is-fullwidth";
                      onclick (fun _ -> Model.RunMsg Model.RandomStep);
                      disabled (steps = []);
                    ]
                  [ text "next steps" ];
              ];
          ];
        (if steps = [] then
           elt "p"
             ~a:[ class_ "terminated-note" ]
             [ text "Computation has terminated" ]
         else text "");
      ]
  in
  panel ~action:(page_link Model.Docs) "Interaction"
    ~a:[ onmouseleave (fun _ -> Model.RunMsg (Model.SelectStepIndex None)) ]
    (view_edit_source :: view_undo_last_step :: view_random_steps steps
   :: List.mapi view_step steps)

let run_view (run_model : Model.run_model) =
  let steps = run_model.current.steps in
  (* The index outlives the step list it points into: taking the last step
     empties the list while the pointer is still on the button. *)
  let selected_step =
    Option.bind run_model.selected_step_index (List.nth_opt steps)
  in
  let active_view =
    if run_model.current.is_done && run_model.current.completed_runs <> [] then
      []
    else
      let state_view =
        match selected_step with
        | None -> run_model.current.view ()
        | Some step -> step.view_highlighted ()
      in
      [ state_view ]
  in
  let completed_views =
    List.concat_map
      (fun (cr : Model.completed_run_view) ->
        [
          div
            ~a:[ class_ "completed-run-separator" ]
            [ elt "span" [ text "previous run" ] ];
          cr.view_completed ();
        ])
      run_model.current.completed_runs
  in
  view_contents (active_view @ completed_views) [ view_steps run_model steps ]

let github_url = "https://github.com/danelahman/tempore-lang"

(* A file at the tip of main in the public repository. *)
let github_blob name = github_url ^ "/blob/main/" ^ name

(* The GitHub mark, as in GitHub's Octicons (MIT licensed, Copyright (c)
   GitHub Inc.; see THIRD-PARTY.md), drawn in the current text colour so
   that it follows the link's hover styling. *)
let github_mark =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "20";
        attr "height" "20";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "path"
        ~a:
          [
            attr "fill" "currentColor";
            attr "d"
              "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 \
               7.59.4.07.55-.17.55-.38 \
               0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 \
               1.08.58 1.23.82.72 1.21 1.87.87 \
               2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 \
               0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 \
               2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 \
               2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 \
               3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 \
               1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 \
               8c0-4.42-3.58-8-8-8z";
          ]
        [];
    ]

let view_navbar =
  let view_title =
    div
      ~a:[ class_ "navbar-brand" ]
      [
        div
          ~a:[ class_ "navbar-item brand-title" ]
          [
            elt "img"
              ~a:
                [
                  class_ "brand-logo";
                  attr "src" "logo/tempore-logo.svg";
                  attr "alt" "";
                  attr "width" "56";
                  attr "height" "56";
                ]
              [];
            div
              ~a:[ class_ "brand-text" ]
              [
                elt "p" ~a:[ class_ "title" ] [ text "Tempore Language" ];
                elt "p"
                  ~a:[ class_ "brand-tagline" ]
                  [
                    text
                      "A language for programming with temporal resources, \
                       using modal types and graded effects";
                  ];
              ];
          ];
      ]
  in

  elt "navbar" ~a:[ class_ "navbar" ] [ view_title ]

(* A muted footer link, styled the same as the GitHub link beside it. *)
let view_footer_link ~href ~title label =
  elt "a"
    ~a:
      [
        class_ "footer-link";
        attr "href" href;
        attr "target" "_blank";
        attr "rel" "noopener";
        attr "title" title;
      ]
    [ text label ]

(* A decorative separator between footer links; it carries no content of its
   own, so it is hidden from screen readers. *)
let view_footer_separator =
  elt "span"
    ~a:[ class_ "footer-separator"; attr "aria-hidden" "true" ]
    [ text "\xC2\xB7" ]

(* The web interface is served with the program compiled into it, so the
   license it is served under is kept within reach of every page. *)
let view_footer =
  elt "footer"
    ~a:[ class_ "site-footer" ]
    [
      elt "a"
        ~a:
          [
            class_ "footer-link github-link";
            attr "href" github_url;
            attr "target" "_blank";
            attr "rel" "noopener";
            attr "title" "Source code on GitHub";
          ]
        [
          elt "span" ~a:[ class_ "icon" ] [ github_mark ];
          elt "span" [ text "Source on GitHub" ];
        ];
      view_footer_separator;
      view_footer_link ~href:(github_blob "LICENSE")
        ~title:"Tempore is MIT licensed" "MIT license";
    ]

let view (model : Model.model) =
  div
    [
      view_navbar;
      (match model.page with
      | Model.Docs ->
          let main, aside = Docs.view (page_link Model.Editor) in
          view_contents main aside
      | Model.Editor -> (
          match model.run_model with
          | Error _ -> edit_view model
          | Ok run_model -> run_view run_model));
      view_footer;
      (match model.gallery with
      | Some query ->
          view_gallery ~selected:model.edit_model.selected_example query
      | None -> nil);
    ]
