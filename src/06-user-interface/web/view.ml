open Vdom
module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location

(* Auxiliary definitions *)
let panel = Widgets.panel
let panel_block = div ~a:[ class_ "panel-block" ]

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

(* The other page is reached from the side panel's heading. The mark stands on
   its own there, so the name it is given is the one read out. *)
let page_link target =
  let mark, label =
    match target with
    | Model.Docs -> (Icons.book, "Documentation")
    | Model.Editor -> (Icons.code, "Editor")
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

(* The source of a span outside the editor: the standard library, an input of
   a backend, or the file of declarations a backend loads before the
   program. *)
let source_name (loc : Location.t) =
  if loc.filename = Loader.stdlib_filename then "the standard library"
  else
    match BackendRegistry.input_of_file loc.filename with
    | Some input -> "the " ^ String.uncapitalize_ascii input.label
    | None -> loc.filename

(* The ids the error's spans are given in the editor, so that the message
   under it can link to them and the page can scroll to them. *)
let primary_id i = Printf.sprintf "error-primary-%d" i
let label_id i j = Printf.sprintf "error-label-%d-%d" i j
let error_id i = Printf.sprintf "editor-error-%d" i

(* The kind of error and where it points: an editor span by its line and
   characters, a standard-library span by its file as well. A warning is
   named by where it points alone. *)
let load_error_header (error : Model.load_error) =
  let kind = Diagnostic.kind_to_string error.diagnostic.kind in
  let warning = Model.is_warning error in
  match error.diagnostic.primary with
  | None -> if warning then "" else kind
  | Some loc when in_editor loc ->
      if warning then Format.asprintf "%t" (Location.print_short loc)
      else Format.asprintf "%s at %t" kind (Location.print_short loc)
  | Some loc ->
      if warning then
        Format.asprintf "in %s (%t)" (source_name loc) (Location.print loc)
      else
        Format.asprintf "%s in %s (%t)" kind (source_name loc)
          (Location.print loc)

(* The attribute of the classes [names], none if there are none. *)
let classes = function
  | [] -> []
  | names -> [ class_ (String.concat " " names) ]

(* The class of the marks of an error, [is-warning] for a warning. *)
let severity_classes (error : Model.load_error) =
  if Model.is_warning error then [ "is-warning" ] else []

(* The same, cut down for the side panel's list: no characters, no file. *)
let load_error_summary (error : Model.load_error) =
  let kind = Diagnostic.kind_to_string error.diagnostic.kind in
  match error.diagnostic.primary with
  | None -> kind
  | Some loc when in_editor loc ->
      Printf.sprintf "%s at line %d" kind loc.start.line
  | Some loc -> kind ^ " in " ^ source_name loc

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
  match model.popovers.popover with
  | Some { target; shown = true; _ } -> Some target
  | _ -> None

(* The line numbers of one error are separate elements, so they are lit as a
   block through the model: each reports the pointer entering or leaving, and
   wears [is-hover] while the model says this error is the one under it. They
   open the error's popover as well, by the pointer or the keyboard focus, and
   are described by it while it is open. *)
let error_number_attrs ~hovered ~described i (error : Model.load_error) =
  classes ((if hovered then [ "is-hover" ] else []) @ severity_classes error)
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
          (String.concat " "
             (("error-primary" :: (if hovered then [ "is-hover" ] else []))
             @ severity_classes error
             @ [ popover_classes (Model.Error_span i) ]))
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

(* Label [j] of the [i]th error. In the editor a label links to its span,
   which lights up while the pointer is on it; a standard-library span can only
   be named. No excerpt is shown here, so a label that says "here" is made to
   name the line instead, and needs no line reference after it. *)
let view_error_label ~stale i j ({ span; text = label_text } : Diagnostic.label)
    =
  let place =
    if in_editor span then Printf.sprintf "on line %d" span.start.line
    else Printf.sprintf "on line %d of %s" span.start.line (source_name span)
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
                 Printf.sprintf " (%s, line %d)" (source_name span)
                   span.start.line);
          ];
      ]
  in
  let content = rendered placed @ where in
  if in_editor span && not stale then
    elt "li"
      ~a:[ onmouseenter (fun _ -> Model.HoverLabel (Some (i, j))) ]
      [ elt "a" ~a:[ attr "href" ("#" ^ label_id i j) ] content ]
  else elt "li" content

(* The header of the message of the [i]th error: its number and where it
   points, and a link to its span in the editor, or a note that it is out of
   date under [stale]. *)
let view_error_header ~stale i (error : Model.load_error) =
  let aside =
    if stale then elt "span" ~a:[ class_ "stale-note" ] [ text "out of date" ]
    else
      match error.diagnostic.primary with
      | Some loc when in_editor loc ->
          elt "a"
            ~a:[ class_ "show-in-editor"; attr "href" ("#" ^ primary_id i) ]
            [ text "show in editor" ]
      | _ -> nil
  in
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
            (match (Model.is_warning error, load_error_header error) with
            | true, "" -> Printf.sprintf "Warning %d" (i + 1)
            | true, header -> Printf.sprintf "Warning %d — %s" (i + 1) header
            | false, header -> Printf.sprintf "Error %d — %s" (i + 1) header);
        ];
      aside;
    ]

(* One error's message. [active] is the error the caret sits in and [flashed]
   the error just gone to; under [stale] the editor marks nothing, so the
   links into it are left out. *)
let view_load_error ~stale ~active ~flashed i (error : Model.load_error) =
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
            (List.mapi (view_error_label ~stale i) labels);
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
  let classes =
    String.concat " "
      ([
         "message";
         (if Model.is_warning error then "is-warning" else "is-danger");
         "editor-error";
       ]
      @ (if active then [ "is-active" ] else [])
      @ (if flashed then [ "is-flashed" ] else [])
      @ if stale then [ "is-stale" ] else [])
  in
  elt "article"
    ~a:[ class_ classes; attr "id" (error_id i) ]
    [
      view_error_header ~stale i error;
      div
        ~a:[ class_ "message-body" ]
        ((elt "p" (rendered error.diagnostic.message) :: labels) @ notes);
    ]

(* The link whose name is under the pointer of a mouse [event], while the
   modifier of links is held. *)
let link_under (model : Model.model) event =
  if model.checked.links <> [] && EditorDom.modifier_held event then
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
         if
           key = "F12" && model.checked.links <> []
           && not model.error_view.stale_errors
         then
           map
             (fun offset ->
               match
                 Model.link_at model.checked.links
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
   before [≾], and a type before the arrows of a chain, a parenthesised
   codomain within its parentheses. Text is annotated by its class. *)
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
  let rec arrows
      ({ domains; codomain; grade } : string Language.PrettyPrint.arrows) =
    let codomain =
      match codomain with
      | Plain part -> ty part
      | Parenthesised inner -> Cat [ ty "("; arrows inner; ty ")" ]
    in
    let result =
      match grade with
      | None -> codomain
      | Some grade -> Cat [ codomain; ty (" # " ^ grade) ]
    in
    match domains with
    | [] -> result
    | first :: rest ->
        Group
          (Align
             (Cat
                (ty first
                 :: List.map (fun a -> Cat [ Line; ty ("→ " ^ a) ]) rest
                @ [ Line; ty "→ "; result ])))
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
    Nest
      ( 4,
        Cat
          [
            Line;
            (if qualifier = [] then Cat [] else dim "⇒ ");
            arrows d.scheme.arrows;
          ] )
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

(* The id of the definition of the declarations loaded before the program
   flashed after going to it. *)
let declaration_flash_id = "declaration-flash"

(* A definition of the declarations loaded before the program, that of the
   [k]th link: its package or file and line, its command, highlighted as the
   editor highlights, the scheme of a value, and a link going to it. *)
let view_declaration_entry ~columns k (entry : Model.declaration_entry) =
  let { WebDeclarations.filename; line; text = command; _ } = entry.place in
  let package = WebDeclarations.package filename in
  let place =
    if package = filename then Printf.sprintf "File %s, line %d" filename line
    else
      Printf.sprintf "Package %s, file %s, line %d" package
        (Filename.basename filename)
        line
  in
  [
    elt "p" ~a:[ class_ "code-popover-place" ] [ text place ];
    elt "pre"
      ~a:[ class_ "code-popover-source syn-ml" ]
      (SyntaxHighlight.highlight_text command);
  ]
  @ (match entry.defined with
    | Some d ->
        [ elt "p" ~a:[ class_ "code-popover-scheme" ] (view_scheme ~columns d) ]
    | None -> [])
  @ [
      elt "a"
        ~a:
          [
            class_ "code-popover-link";
            attr "href" ("#" ^ declaration_flash_id);
            onclick ~prevent_default:() (fun _ -> Model.Follow k);
          ]
        [ text "Show declaration" ];
    ]

(* The card of the [i]th error, of kind [is-label] for its label [label] and
   [is-error] otherwise: its kind and headline, then the label when there is
   one and otherwise the error's first note, and a link to its message. *)
let error_card i label (error : Model.load_error) =
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
           ~a:
             [
               class_
                 (String.concat " "
                    ("code-popover-kind" :: severity_classes error));
             ]
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
          [
            text
              (if Model.is_warning error then "Show full warning"
               else "Show full error");
          ];
      ] )

(* The kind and the body of the card of [target], among the errors [errors]
   and what the last check has found [checked], schemes laid out in [columns]
   characters: for a definition's name, its scheme; for a name defined in the
   standard library or in the declarations loaded before the program, its
   definition. *)
let card ~columns errors (checked : Model.checked) = function
  | Model.Error_span i -> Option.map (error_card i None) (List.nth_opt errors i)
  | Model.Error_label (i, j) ->
      Option.map (error_card i (Some j)) (List.nth_opt errors i)
  | Model.Definition k ->
      Option.map
        (fun d ->
          ( "is-type",
            [
              elt "p"
                ~a:[ class_ "code-popover-scheme" ]
                (view_scheme ~columns d);
            ] ))
        (List.nth_opt checked.definitions k)
  | Model.Reference k -> (
      match List.nth_opt checked.links k with
      | Some { destination = Model.In_library entry; _ } ->
          Some ("is-type", view_library_entry ~columns entry)
      | Some { destination = Model.In_declarations entry; _ } ->
          Some ("is-type", view_declaration_entry ~columns k entry)
      | Some { destination = Model.In_editor _; _ } | None -> None)

(* The open popover, its card that of [card]. It is drawn hidden until
   measured, and then placed under or above its span, a scheme laid out again
   first when the measured width differs. *)
let view_popover (model : Model.model) errors =
  let columns = Option.value ~default:default_columns model.popovers.columns in
  match model.popovers.popover with
  | Some ({ shown = true; _ } as popover) -> (
      match card ~columns errors model.checked popover.target with
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
        if pointer = model.popovers.pointer && link = model.popovers.link then
          None
        else Some (Model.Point (pointer, link, EditorDom.point event))
    | _ -> None)

(* The pointer leaving the editor, rather than moving between its layers. *)
let onpointer_leave (model : Model.model) =
  on_js "mouseleave" (function
    | Vdom_blit.Ojs event
      when (model.popovers.pointer <> Model.Nowhere
           || model.popovers.link <> None)
           && not (EditorDom.moves_within ".code-editor" event) ->
        Some (Model.Point (Model.Nowhere, None, EditorDom.point event))
    | _ -> None)

let onescape_popover (model : Model.model) =
  on "keydown"
    Vdom.Decoder.(
      map
        (fun key ->
          if key = "Escape" && model.popovers.popover <> None then
            Some Model.Conceal
          else None)
        (field "key" String))

(* The gutter of a text of [lines] lines: a small inset, the line numbers
   (0.558rem a digit at the editor's 0.9rem) and a gap; in rem so the marker's
   smaller font can use it. *)
let gutter lines =
  Printf.sprintf "calc(0.36rem + %d * 0.558rem + 0.63rem)"
    (String.length (string_of_int lines))

(* The editor proper: the highlighted text, with the errors' spans and the
   definitions' names marked, the transparent textarea stretched over it, and
   the open popover. *)
let view_editor ~highlighted ~errors (model : Model.model) =
  let source = model.edit_model.unparsed_code in
  let lines =
    String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 1 source
  in
  let rows = max 10 lines in
  let gutter = gutter lines in
  let described =
    match (popover_target model, model.popovers.caret_target) with
    | Some target, Some target' when target = target' ->
        [ attr "aria-describedby" popover_id ]
    | _ -> []
  in
  div
    ~a:
      [
        class_
          (if model.popovers.link <> None then "code-editor is-linking"
           else "code-editor");
        style "--gutter" gutter;
        onpointer model;
        onpointer_leave model;
        onescape_popover model;
      ]
    [
      highlighted;
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

(* The link to the first of the [n] errors or warnings, named by [noun], whose
   first is reported in [run_model], under the class [cls]. *)
let view_go_to_first ~cls ~noun n run_model =
  let target =
    match run_model with
    | Error (first :: _) -> load_error_target 0 first
    | _ -> error_id 0
  in
  elt "a"
    ~a:
      [
        class_ cls;
        attr "href" ("#" ^ target);
        attr "title" ("Go to the first " ^ noun);
        onclick ~prevent_default:() (fun _ -> Model.GoToError 0);
      ]
    [
      text (count n noun);
      elt "span" ~a:[ class_ "is-sr-only" ] [ text ", go to the first" ];
    ]

(* The outcome of the last check of [model], if any: its mark and the parts of
   its text, dimmed while a check is under way. *)
let view_outcome (model : Model.model) =
  let outcome ?(clipped = true) mark parts =
    elt "span"
      ~a:
        [
          class_
            (if model.status.checking <> None then
               "check-status-outcome is-superseded"
             else "check-status-outcome");
        ]
      [ mark; view_status_text ~clipped parts ]
  in
  match model.status.last_check with
  | None -> []
  | Some { current = false; errors; _ } ->
      [
        outcome
          (if errors = 0 then Icons.tick "is-success is-dimmed"
           else Icons.cross "is-danger is-dimmed")
          [ [ text "Edited since the last check" ] ];
      ]
  | Some { errors = 0; warnings = 0; definitions; _ } ->
      [
        outcome (Icons.tick "is-success")
          [
            [ text "Checked \xE2\x80\x94 no errors" ];
            view_definitions definitions;
          ];
      ]
  | Some { errors = 0; warnings; definitions; _ } ->
      [
        outcome (Icons.tick "is-warning")
          [
            [
              text "Checked \xE2\x80\x94 ";
              view_go_to_first ~cls:"check-status-warnings" ~noun:"warning"
                warnings model.run_model;
            ];
            view_definitions definitions;
          ];
      ]
  | Some { errors; _ } ->
      [
        outcome ~clipped:false (Icons.cross "is-danger")
          [
            [
              view_go_to_first ~cls:"check-status-errors" ~noun:"error" errors
                model.run_model;
            ];
          ];
      ]

(* The note that a check is under way. *)
let view_progress =
  elt "span"
    ~a:[ class_ "check-status-progress" ]
    [
      elt "span" ~a:[ class_ "check-spinner"; attr "aria-hidden" "true" ] [];
      text "Checking\xE2\x80\xA6";
    ]

(* The line under the buttons stating the outcome of the last check, empty
   before any. While a check is under way, a note saying so takes its place
   once the check has lasted a moment (see the page's style). The line is a
   live region, present throughout so that its changes are announced. *)
let view_check_status (model : Model.model) =
  div
    ~a:
      [
        class_
          (if model.status.abbreviated then "check-status is-abbreviated"
           else "check-status");
        attr "id" status_id;
        attr "role" "status";
        attr "aria-live" "polite";
      ]
    (view_outcome model
    @ if model.status.checking = None then [] else [ view_progress ])

(* Backends *)

(* The control of an input of choices of the selected backend. *)
let view_choice_input ~value (input : BackendRegistry.input) choices =
  div
    ~a:[ class_ "field backend-choice" ]
    [
      elt "label" ~a:[ class_ "label is-small" ] [ text input.label ];
      select
        ~a:[ class_ "select is-small" ]
        input.label
        (fun choice -> Model.EditMsg (Model.SetInput (input.key, choice)))
        Fun.id
        (fun choice -> choice = value)
        choices;
    ]

(* A text input of the selected backend, folded under its label and its
   number of lines. *)
let view_text_input ~value (input : BackendRegistry.input) =
  let lines =
    if String.trim value = "" then "empty"
    else
      let n =
        String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 0 value
      in
      count (if String.ends_with ~suffix:"\n" value then n else n + 1) "line"
  in
  elt "details"
    ~a:[ class_ "backend-input" ]
    [
      elt "summary"
        [
          text input.label;
          elt "span" ~a:[ class_ "backend-input-size" ] [ text lines ];
        ];
      elt "textarea"
        ~a:
          [
            class_ "textarea backend-text";
            (* bound as a property, as the editor's text is, so that loading
               an example replaces it *)
            str_prop "value" value;
            oninput (fun text ->
                Model.EditMsg (Model.SetInput (input.key, text)));
            int_prop "rows" 14;
            attr "aria-label" input.label;
            attr "spellcheck" "false";
            attr "autocapitalize" "off";
            attr "autocorrect" "off";
          ]
        [];
    ]

(* The code of a compilation, highlighted in its language where a highlighter
   is known for it. *)
let view_code (output : BackendRegistry.compiled) =
  let code = Option.value output.code ~default:"" in
  elt "pre"
    ~a:[ class_ "syn-ml backend-code" ]
    (match output.language with
    | "python" -> PythonHighlight.highlight code
    | "cpp" -> CppHighlight.highlight code
    | _ -> [ text code ])

(* A message of a compilation, in the style of the errors of a check. *)
let view_compile_message ~backend ~stale i (message : BackendRegistry.message) =
  let kind, cls =
    match message.severity with
    | BackendRegistry.Error -> ("Error", "is-danger")
    | Warning -> ("Warning", "is-warning")
    | Note -> ("Note", "is-info")
  in
  elt "article"
    ~a:
      [
        class_
          (String.concat " "
             ([ "message"; cls; "editor-error"; "backend-message" ]
             @ if stale then [ "is-stale" ] else []));
      ]
    [
      div
        ~a:[ class_ "message-header" ]
        [
          elt "p" [ text (Printf.sprintf "%s %d — %s" kind (i + 1) backend) ];
          (if stale then
             elt "span" ~a:[ class_ "stale-note" ] [ text "out of date" ]
           else nil);
        ];
      div
        ~a:[ class_ "message-body" ]
        [
          (if String.contains message.text '\n' then
             elt "pre"
               ~a:[ class_ "backend-message-text" ]
               [ text message.text ]
           else elt "p" [ text message.text ]);
        ];
    ]

(* Code options *)

(* The choice of loading the standard library. *)
let view_use_stdlib (edit_model : Model.edit_model) =
  elt "label"
    ~a:[ class_ "panel-block" ]
    [
      input
        ~a:
          [
            type_ "checkbox";
            onchange_checked (fun use_stdlib ->
                Model.EditMsg (Model.UseStdlib use_stdlib));
            bool_prop "checked" edit_model.use_stdlib;
          ]
        [];
      text "Load standard library";
    ]

(* The notice shown under the example, if any. *)
let view_notice = function
  | None -> []
  | Some notice ->
      let colour, message =
        match notice with
        | Model.Ignored [ parameter ] ->
            ( "is-danger",
              Printf.sprintf
                "The parameter %s of the address was ignored: its value is \
                 malformed or names nothing known."
                (WebLink.name parameter) )
        | Model.Ignored parameters ->
            ( "is-danger",
              Printf.sprintf
                "The parameters %s of the address were ignored: their values \
                 are malformed or name nothing known."
                (String.concat ", " (List.map WebLink.name parameters)) )
        | Model.Link_copied -> ("is-success", "Link copied.")
        | Model.Copy_failed link ->
            ( "is-danger",
              "The link could not be copied to the clipboard: " ^ link )
      in
      [
        elt "p"
          ~a:[ class_ ("help link-notice " ^ colour); attr "role" "status" ]
          [ text message ];
      ]

(* The button opening the gallery, see [view_gallery], labelled by the example
   [selected] last loaded, after the short form of the label of the group it is
   listed under, the tooltip and the accessible name giving the full label. *)
let view_example_button selected =
  elt "button"
    ~a:
      ([
         class_ "button is-fullwidth example-button";
         type_button;
         onclick (fun _ -> Model.OpenGallery);
       ]
      @
      match selected with
      | Some (group, title) ->
          [
            attr "title" (group ^ " \xC2\xB7 " ^ title);
            attr "aria-label" ("Example: " ^ group ^ ", " ^ title);
          ]
      | None -> [])
    [
      (match selected with
      | Some (group, title) ->
          view_choice_label
            ~heading:
              (Option.fold ~none:group
                 ~some:(fun (g : Examples_tpe.group) -> g.short)
                 (Model.example_group group))
            title
      | None -> view_choice_label "Load example");
      elt "span" ~a:[ class_ "has-text-grey" ] [ text "\xE2\x80\xA6" ];
    ]

(* The example last loaded, under its label with the link copying the address
   naming the example, the grades and the backend selected at its right end,
   and the notice [notice]. *)
let view_example (edit_model : Model.edit_model) notice =
  div
    ~a:[ class_ "panel-block" ]
    [
      div
        ~a:[ class_ "field" ]
        ([
           div
             ~a:[ class_ "example-label" ]
             [
               elt "label" ~a:[ class_ "label" ] [ text "Example" ];
               elt "a"
                 ~a:
                   [
                     class_ "copy-link";
                     attr "href" "#";
                     attr "title" "Copy link";
                     attr "aria-label" "Copy link";
                     onclick ~prevent_default:() (fun _ -> Model.CopyLink);
                   ]
                 [ Icons.link ];
             ];
           div
             ~a:[ class_ "example-field" ]
             [
               div
                 ~a:[ class_ "control is-expanded" ]
                 [ view_example_button edit_model.selected_example ];
             ];
         ]
        @ view_notice notice);
    ]

(* The backends of {!BackendRegistry.entries} by name, the selected one with
   its description and the inputs of choices it has. *)
let view_backend (edit_model : Model.edit_model) =
  let selected = Model.backend edit_model in
  let settings = Model.settings edit_model in
  let choices =
    List.filter_map
      (fun (input : BackendRegistry.input) ->
        match input.kind with
        | Choice choices ->
            Some
              (view_choice_input
                 ~value:
                   (BackendRegistry.setting selected.inputs settings input.key)
                 input choices)
        | Text -> None)
      selected.inputs
  in
  div
    ~a:[ class_ "panel-block" ]
    [
      div
        ~a:[ class_ "field" ]
        ([
           elt "label" ~a:[ class_ "label" ] [ text "Backend" ];
           div
             ~a:[ class_ "control is-expanded" ]
             [
               select
                 ~a:[ class_ "select is-fullwidth backend-select" ]
                 "Select a backend"
                 (fun (entry : BackendRegistry.entry) ->
                   Model.EditMsg (Model.SelectBackend entry.key))
                 (fun (entry : BackendRegistry.entry) -> entry.name)
                 (fun (entry : BackendRegistry.entry) ->
                   entry.key = selected.key)
                 BackendRegistry.entries;
             ];
           elt "p" ~a:[ class_ "grades-summary" ] [ text selected.description ];
         ]
        @
        if choices = [] then []
        else [ div ~a:[ class_ "backend-choices" ] choices ]);
    ]

(* The description of the grades [name], the tooltip adding how a regular
   grade is decided and the command running them. *)
let view_grades_summary name =
  let description, implementation =
    match Grades.GradeRegistry.info name with
    | Some info ->
        ( info.description,
          Option.fold ~none:""
            ~some:(fun i -> Grades.GradeRegistry.implementation_text i ^ "\n")
            info.implementation )
    | None -> ("", "")
  in
  elt "p"
    ~a:
      [
        class_ "grades-summary";
        attr "title"
          (implementation ^ "./tempore --grades " ^ name ^ " file.tpe");
      ]
    [ text description ]

(* The grades, grouped as {!Grades.GradeRegistry.groups} groups them, without
   the grades offered by the CLI only, the option text its title and the
   tooltip its description, followed by how it is decided for a regular grade;
   then the description of the selected grades. *)
let view_grades (edit_model : Model.edit_model) =
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
              grouped_select
                ~a:[ class_ "select is-fullwidth choice-select" ]
                ~id:"grades-select" "Select grades"
                (fun (name, _) -> Model.EditMsg (Model.SelectGrades name))
                (fun (_, (info : Grades.GradeRegistry.info)) -> info.title)
                (fun (_, (info : Grades.GradeRegistry.info)) ->
                  match info.implementation with
                  | Some i ->
                      info.description ^ " "
                      ^ Grades.GradeRegistry.implementation_text i
                  | None -> info.description)
                (fun (name, _) -> name = edit_model.selected_grades)
                (List.map
                   (fun (g : Grades.GradeRegistry.group) ->
                     (g.label, g.short, Grades.GradeRegistry.listed g))
                   Grades.GradeRegistry.groups);
            ];
          view_grades_summary edit_model.selected_grades;
        ];
    ]

(* The button of the check [pressed], under the classes [cls] and the label
   [label], sending [msg]. While a check is under way, the button pressed shows
   a spinner and neither takes a press; they are marked disabled for assistive
   technology only, so that the focus stays on them. *)
let view_check_action ~checking cls label pressed msg =
  let state =
    match checking with
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
          @ if checking = None then [] else [ attr "aria-disabled" "true" ])
        [ elt "span" [ text label ] ];
    ]

(* Every error shown under the editor, which may be far below when the program
   is long; clicking one scrolls to its message. *)
let view_error_list (model : Model.model) =
  match model.run_model with
  | Error (_ :: _ as errors) ->
      let stale = model.error_view.stale_errors in
      let view_entry i error =
        elt "li"
          ~a:
            (classes
               ((if model.error_view.active_error = Some i then [ "is-active" ]
                 else [])
               @ severity_classes error)
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
                    ^ if stale then error_id i else load_error_target i error);
                  onclick ~prevent_default:() (fun _ -> Model.GoToError i);
                ]
              [ text (load_error_summary error) ];
          ]
      in
      elt "ol"
        ~a:[ class_ (if stale then "error-list is-stale" else "error-list") ]
        (List.mapi view_entry errors)
  | _ -> nil

(* Typecheck stays in the editor, and compiles the program it accepts under a
   backend with a compiler; Run typechecks and, without errors, runs the
   program. The status of the last check and the list of the errors follow. *)
let view_checks (model : Model.model) =
  let checking = model.status.checking in
  panel_block
    [
      view_check_action ~checking [ "is-outlined" ]
        (if Option.is_some (Model.backend model.edit_model).compiler then
           "Typecheck & Compile"
         else "Typecheck")
        Model.Check Model.CheckCode;
      view_check_action ~checking [] "Run Interpreter" Model.Run Model.RunCode;
      view_check_status model;
      view_error_list model;
    ]

(* The side panel of the editor. *)
let view_code_options (model : Model.model) =
  panel ~action:(page_link Model.Docs) "Code options"
    [
      view_backend model.edit_model;
      view_use_stdlib model.edit_model;
      view_example model.edit_model model.notices.notice;
      view_grades model.edit_model;
      view_checks model;
    ]

(* The note that the program has errors, shown with the program, unless the
   errors reported are those of the compilation. *)
let view_program_errors (model : Model.model) =
  match model.run_model with
  | Error (_ :: _ as errors) when not model.compilation.reports_compilation ->
      [
        elt "p"
          ~a:[ class_ "backend-note" ]
          [
            text
              (Printf.sprintf "The program has %s, shown with "
                 (count (List.length errors) "error"));
            elt "a"
              ~a:
                [
                  attr "href" "#";
                  onclick ~prevent_default:() (fun _ ->
                      Model.ShowCode Model.Source);
                ]
              [ text "the program" ];
            text ".";
          ];
      ]
  | _ -> []

(* The messages of the compilation [compiled] by the backend [backend] and the
   code compiled, or the note that the program is compiled once it
   typechecks. *)
let view_compilation ~backend (compiled : Model.compiled option) =
  match compiled with
  | None ->
      [
        elt "p"
          ~a:[ class_ "backend-note" ]
          [ text "The program is compiled once it typechecks." ];
      ]
  | Some { output; up_to_date } ->
      let stale = not up_to_date in
      List.mapi (view_compile_message ~backend ~stale) output.messages
      @ Option.fold ~none:[]
          ~some:(fun _ ->
            [
              elt "p"
                ~a:[ class_ "backend-code-heading" ]
                [
                  text "Compiled code";
                  elt "span"
                    ~a:[ class_ "backend-input-size" ]
                    [ text (if stale then "out of date" else output.language) ];
                ];
              (* rendered once per compilation *)
              Vdom.memo view_code output;
            ])
          output.code

(* The view of a backend with a compiler in the editor's place: the text
   inputs of the backend, the messages of the compilation and the code
   compiled. *)
let view_compiled (model : Model.model) (entry : BackendRegistry.entry)
    (compiler : BackendRegistry.compiler) =
  let settings = Model.settings model.edit_model in
  let texts =
    List.filter_map
      (fun (input : BackendRegistry.input) ->
        match input.kind with
        | Text ->
            Some
              (view_text_input
                 ~value:
                   (BackendRegistry.setting entry.inputs settings input.key)
                 input)
        | Choice _ -> None)
      entry.inputs
  in
  div
    ~a:[ class_ "backend-view" ]
    ((elt "p" ~a:[ class_ "backend-title" ] [ text compiler.code_name ] :: texts)
    @ view_program_errors model
    @ view_compilation ~backend:entry.name model.compilation.compiled)

(* An image as the mark of a view. *)
let image_mark src =
  elt "img" ~a:[ attr "src" src; attr "alt" ""; attr "aria-hidden" "true" ] []

(* The marks of the program and of the code compiled from it, on the switch
   between the two views. *)
let source_mark = image_mark "logo/tempore-logo.svg"

let compiled_mark = function
  | BackendRegistry.Chip -> Icons.chip
  | BackendRegistry.Pipette -> Icons.pipette

(* The switch in the top right corner of the editor's box, to the view not
   shown, named by its mark alone, as the link to the other page is. *)
let view_switch (compiler : BackendRegistry.compiler) code_view =
  let target, mark, label =
    match code_view with
    | Model.Source ->
        (Model.Compiled, compiled_mark compiler.mark, compiler.code_name)
    | Model.Compiled -> (Model.Source, source_mark, "Tempore program")
  in
  elt "a"
    ~a:
      [
        class_ "view-switch";
        attr "href" "#";
        attr "title" label;
        attr "aria-label" label;
        onclick ~prevent_default:() (fun _ -> Model.ShowCode target);
      ]
    [ mark ]

(* The report of the observer of a run, as a table and notes folded under its
   title, unfolded at first if [expanded]. *)
let view_report ~expanded (report : BackendRegistry.report) =
  let row_class (row : BackendRegistry.row) =
    match (row.status, row.depth) with
    | Plain, 0 -> []
    | Pending, 0 -> [ class_ "is-pending" ]
    | Plain, _ -> [ class_ "is-sub" ]
    | Pending, _ -> [ class_ "is-pending is-sub" ]
  in
  (* A shortened cell shows its full text as a tooltip and, unfolded by a
     click, in place of the shortened one. *)
  let cell full short =
    if String.equal full short then elt "td" [ text full ]
    else
      elt "td"
        ~a:[ attr "title" full ]
        [
          elt "details"
            ~a:[ class_ "backend-cell" ]
            [
              elt "summary"
                [
                  elt "span" ~a:[ class_ "backend-cell-short" ] [ text short ];
                  elt "span" ~a:[ class_ "backend-cell-full" ] [ text full ];
                ];
            ];
        ]
  in
  elt "details"
    ~a:
      (class_ "box backend-box backend-report"
      :: (if expanded then [ attr "open" "" ] else []))
    ([
       elt "summary" ~a:[ class_ "backend-title" ] [ text report.title ];
       div
         ~a:[ class_ "table-container" ]
         [
           elt "table"
             ~a:[ class_ "table is-narrow is-fullwidth" ]
             [
               elt "thead"
                 [
                   elt "tr"
                     (List.map (fun c -> elt "th" [ text c ]) report.columns);
                 ];
               elt "tbody"
                 (List.map
                    (fun (row : BackendRegistry.row) ->
                      elt "tr" ~a:(row_class row)
                        (List.map2 cell row.cells row.short))
                    report.rows);
             ];
         ];
     ]
    @ List.map2
        (fun note full ->
          elt "p"
            ~a:
              (class_ "backend-note"
              :: (if String.equal note full then [] else [ attr "title" full ])
              )
            [ text note ])
        report.notes report.full_notes)

(* [view_report] with each folding, as functions of the report alone, which
   [Vdom.memo] compares. *)
let view_unfolded_report = view_report ~expanded:true
let view_folded_report = view_report ~expanded:false

(* What the editor's highlighted text depends on. *)
type editor_key = {
  source : string;
  errors : Model.load_error list;
  stale : bool;
  popover : Model.popover_target option;
  pointed : int option;
  hovered_error : int option;
  active_error : int option;
  definitions : Model.definition list;
  links : Model.link list;
  link : int option;
  flash : Model.flash option;
  line_links : bool;  (** whether the line numbers copy links to their lines *)
}

let editor_key (model : Model.model) =
  {
    source = model.edit_model.unparsed_code;
    errors = (match model.run_model with Error errors -> errors | Ok _ -> []);
    stale = model.error_view.stale_errors;
    popover = popover_target model;
    pointed =
      (match model.popovers.pointer with
      | Model.Over_target target -> target_error target
      | Model.Nowhere | Model.Over_popover -> None);
    hovered_error = model.error_view.hovered_error;
    active_error = model.error_view.active_error;
    definitions = model.checked.definitions;
    links = model.checked.links;
    link = model.popovers.link;
    flash = model.notices.flash;
    line_links = Model.line_links model;
  }

(* The lists are compared physically: a model keeps each list until it replaces
   it. *)
let equal_editor_key k k' =
  String.equal k.source k'.source
  && k.errors == k'.errors && k.stale = k'.stale && k.popover = k'.popover
  && k.pointed = k'.pointed
  && k.hovered_error = k'.hovered_error
  && k.active_error = k'.active_error
  && k.definitions == k'.definitions
  && k.links == k'.links && k.link = k'.link && k.flash = k'.flash
  && k.line_links = k'.line_links

(* [interned key] is the last key given if it equals [key], and [key]
   otherwise, so that [Vdom.memo], which compares its argument physically,
   keeps the highlighted text as long as what it depends on is unchanged. *)
let interned =
  let last = ref None in
  fun key ->
    match !last with
    | Some key' when equal_editor_key key key' -> key'
    | _ ->
        last := Some key;
        key

(* The marks of the errors of [key]. Labels of every error at once would only
   confuse; they show for the error the user is looking at, or when it is
   alone. *)
let error_marks
    ({ errors; popover; pointed; hovered_error; active_error; _ } : editor_key)
    =
  List.concat
    (List.mapi
       (fun i (error : Model.load_error) ->
         let with_labels =
           List.length errors = 1
           || hovered_error = Some i || active_error = Some i
           || error.hovered_label <> None
           || pointed = Some i
           || Option.bind popover target_error = Some i
         in
         marks_of_error ~hovered:(hovered_error = Some i) ~with_labels ~popover
           i error)
       errors)

(* The marks of the names the definitions are given, each described by its
   scheme. *)
let definition_marks ~popover definitions =
  List.concat
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
       definitions)

(* The marks of the names of the links, the [link]th underlined while the
   modifier of links is held with the pointer on it, those defined in the
   declarations loaded before the program described by popovers. *)
let link_marks ~popover ~link links =
  List.mapi
    (fun k ({ use = from, until; destination } : Model.link) ->
      {
        SyntaxHighlight.from;
        until;
        mark_cls =
          String.concat " "
            ([ "name-ref"; EditorDom.link_prefix ^ string_of_int k ]
            @ (if link = Some k then [ "is-link" ] else [])
            @ (if popover = Some (Model.Reference k) then [ "is-hover" ] else [])
            @
            match destination with
            | Model.In_declarations _ -> [ popover_classes (Model.Reference k) ]
            | Model.In_editor _ | Model.In_library _ ->
                if popover = Some (Model.Reference k) then
                  [ popover_classes (Model.Reference k) ]
                else []);
        id = None;
        marker = None;
      })
    links

(* The mark of the span of the editor just gone to, if any. *)
let flash_marks = function
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
  | Some
      ( Model.Message _ | Model.Declaration _ | Model.Line _
      | Model.Copied_line _ )
  | None ->
      []

(* The marks of the editor's text: the spans of the errors, the names of the
   definitions and links, and what has just been gone to. Edited source: the
   spans have moved, so only the messages remain. *)
let editor_marks (key : editor_key) =
  if key.stale then []
  else
    error_marks key
    @ definition_marks ~popover:key.popover key.definitions
    @ link_marks ~popover:key.popover ~link:key.link key.links
    @ flash_marks key.flash

(* The number [n] of a line, copying the link to the line when clicked. *)
let line_link n =
  [
    attr "title" (Printf.sprintf "Copy a link to line %d" n);
    onclick (fun _ -> Model.CopyLineLink n);
  ]

(* The editor's text, highlighted with its marks, and a newline the source has
   not got, so that a last empty line keeps its height. The line numbers copy
   links to their lines while [key.line_links] holds; the line whose link has
   just been copied, or that the page's address names, is lit across the
   editor, the latter scrolled to. *)
let view_highlighted (key : editor_key) =
  elt "pre"
    ~a:[ class_ "code-editor-display syn-ml" ]
    (SyntaxHighlight.highlight_with_marks ~line_numbers:true
       ?line_link:(if key.line_links then Some line_link else None)
       ?lit_line:
         (match key.flash with
         | Some (Model.Copied_line n) -> Some (n, "is-copied", None)
         | Some (Model.Line n) -> Some (n, "is-opened", Some EditorDom.flash_id)
         | _ -> None)
       ~marks:(editor_marks key) (key.source ^ "\n"))

(* Declarations loaded before the program *)

(* A source of the declarations loaded before the program, under its file
   name, highlighted as the editor highlights, with line numbers; [flash] is
   the bytes of it just gone to, if any. *)
let view_declaration_source ?flash (source : WebDeclarations.source) =
  let code =
    if String.ends_with ~suffix:"\n" source.text then
      String.sub source.text 0 (String.length source.text - 1)
    else source.text
  in
  let lines =
    String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 1 code
  in
  let marks =
    Option.fold ~none:[]
      ~some:(fun (from, until) ->
        [
          {
            SyntaxHighlight.from;
            until = max until (from + 1);
            mark_cls = "goto-flash";
            id = Some declaration_flash_id;
            marker = None;
          };
        ])
      flash
  in
  div
    ~a:[ class_ "declarations-file" ]
    [
      elt "p" ~a:[ class_ "declarations-filename" ] [ text source.filename ];
      elt "pre"
        ~a:
          [
            class_ "declarations-source syn-ml"; style "--gutter" (gutter lines);
          ]
        (SyntaxHighlight.highlight_with_marks ~line_numbers:true ~marks code);
    ]

(* [view_declaration_source] without a flash, as a function of the source
   alone, which [Vdom.memo] compares. *)
let view_unflashed_declaration_source source = view_declaration_source source

(* The declarations the selected backend loads before the program, folded
   above it under their packages, read-only; a container without them, so
   that the editor keeps its place among the children of the box. *)
let view_declarations (model : Model.model) =
  div
    ~a:[ class_ "editor-declarations" ]
    (match model.declarations.shown_declarations with
    | [] -> []
    | sources ->
        [
          elt "details"
            ~a:
              [
                class_ "declarations";
                bool_prop "open" model.declarations.declarations_open;
                on "toggle"
                  Vdom.Decoder.(
                    map
                      (fun shown ->
                        if shown = model.declarations.declarations_open then
                          None
                        else Some (Model.ShowDeclarations shown))
                      (field "target.open" Bool));
              ]
            (elt "summary"
               ~a:[ class_ "declarations-title" ]
               [ text (WebDeclarations.title sources) ]
            :: List.map
                 (fun (source : WebDeclarations.source) ->
                   match model.notices.flash with
                   | Some (Model.Declaration (filename, start, stop))
                     when filename = source.filename ->
                       view_declaration_source ~flash:(start, stop) source
                   | _ -> Vdom.memo view_unflashed_declaration_source source)
                 sources);
        ])

(* The editor's box: the program, with the errors of its check, or, under a
   backend with a compiler, the view of the code compiled, with the switch
   between the two last, so that the editor keeps its place among the
   children of the box. *)
let edit_view (model : Model.model) =
  let entry = Model.backend model.edit_model in
  let content =
    match (entry.compiler, model.compilation.code_view) with
    | Some compiler, Model.Compiled -> [ view_compiled model entry compiler ]
    | _ ->
        let key = interned (editor_key model) in
        let errors = key.errors and stale = key.stale in
        view_declarations model
        :: view_editor
             ~highlighted:(Vdom.memo view_highlighted key)
             ~errors model
        :: List.mapi
             (fun i error ->
               view_load_error ~stale
                 ~active:(model.error_view.active_error = Some i)
                 ~flashed:(model.notices.flash = Some (Model.Message i))
                 i error)
             errors
  and switch =
    Option.fold ~none:[]
      ~some:(fun compiler ->
        [ view_switch compiler model.compilation.code_view ])
      entry.compiler
  in
  view_contents
    [ div ~a:[ class_ "box editor-box" ] (content @ switch) ]
    [ view_code_options model ]

(* Example gallery *)

(* A layer over the page listing the examples of Examples_tpe, generated from
   examples/index (see the dune file), by group, with a search over them. *)

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
  Widgets.contains
    ~sub:(String.lowercase_ascii (String.trim query))
    (String.lowercase_ascii
       (String.concat " "
          [ group; e.title; e.grade; e.description; example_path e ]))

let example_group_id k = Printf.sprintf "example-group-%d" k

(* The id of the card of the example last loaded, which the page focuses
   when the gallery opens. *)
let current_example_id = "current-example"

(* An example's card, which loads it; [current] marks the example last
   loaded. *)
let view_example_card ~current group (e : Examples_tpe.example) =
  elt "button"
    ~a:
      ([
         class_ (if current then "example-card is-current" else "example-card");
         type_button;
         onclick (fun _ -> Model.EditMsg (Model.LoadExample (group, e)));
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

(* The groups of examples of the backend [backend] with an example matching
   [query], each by its index, with the examples matching. *)
let gallery_groups ~backend query =
  List.filter_map
    (fun (k, (g : Examples_tpe.group)) ->
      match
        List.filter
          (fun (e : Examples_tpe.example) ->
            e.backend = backend && matches query g.label e)
          g.examples
      with
      | [] -> None
      | examples -> Some (k, g, examples))
    (List.mapi (fun k g -> (k, g)) Examples_tpe.examples)

(* The entry of a group in the side column of the gallery, lit when its id is
   [current]. *)
let view_toc_entry ~current (k, (g : Examples_tpe.group), examples) =
  let id = example_group_id k in
  elt "a"
    ~a:
      (attr "href" ("#" ^ id)
      :: (if id = current then [ class_ "is-active" ] else []))
    [
      text (g.label ^ " ");
      elt "span" [ text (Printf.sprintf "(%d)" (List.length examples)) ];
    ]

(* The section of the cards of a group, the example [selected] last loaded
   marked. *)
let view_gallery_group ~selected (k, (g : Examples_tpe.group), examples) =
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

(* The head of the gallery: its title, the search field with the search
   [query], focused when no example has been loaded, and the close button. *)
let view_gallery_head ~selected query =
  div
    ~a:[ class_ "example-gallery-head" ]
    [
      elt "h2" [ text "Examples" ];
      input
        ~a:
          ([
             class_ "example-gallery-search";
             attr "placeholder"
               "Search examples, e.g. release, levels, handlers, regex";
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
    ]

(* The gallery with the search [query]: the groups with an example matching
   it, each listed in the side column, the group scrolled to [current] or
   else the first lit, and as a section of cards. Esc closes it, the layer
   taking the focus from a click inside the panel, and so does a click on the
   backdrop beside the panel. The search field takes the focus when the
   gallery opens with no example loaded; otherwise the page focuses the card of
   the example last loaded. *)
let view_gallery ~selected ~backend ~current query =
  let groups = gallery_groups ~backend query in
  let current =
    match (current, groups) with
    | Some id, _ -> id
    | None, (k, _, _) :: _ -> example_group_id k
    | None, [] -> ""
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
          view_gallery_head ~selected query;
          div
            ~a:[ class_ "example-gallery-body" ]
            [
              elt "nav"
                ~a:[ class_ "example-gallery-toc" ]
                (List.map (view_toc_entry ~current) groups);
              div
                ~a:[ class_ "example-gallery-list" ]
                (match groups with
                | [] ->
                    [
                      elt "p"
                        ~a:[ class_ "example-gallery-empty" ]
                        [ text "No example matches." ];
                    ]
                | _ -> List.map (view_gallery_group ~selected) groups);
            ];
        ];
    ]

(* Run view *)

(* The button returning to the editor, which aborts the run. *)
let view_edit_source () =
  panel_block
    [
      elt "button"
        ~a:
          [
            class_ "button is-outlined is-fullwidth is-danger";
            onclick (fun _ -> Model.EditCode);
            attr "title" "Re-editing source code will abort current evaluation";
          ]
        [ text "Re-edit source code" ];
    ]

(* The button undoing the last step, disabled before any. *)
let view_undo_last_step (run_model : Model.run_model) =
  panel_block
    [
      elt "button"
        ~a:
          [
            class_ "button is-outlined is-fullwidth";
            onclick (fun _ -> Model.RunMsg Model.Back);
            disabled (List.is_empty run_model.history);
          ]
        [ text "Undo last step" ];
    ]

(* The button of the [i]th step, which takes it. *)
let view_step i (step : Model.concrete_step) =
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
        [ step.label_vdom ];
    ]

(* The choice of the number of random steps and the button taking them, or
   the note that the computation has terminated, without [steps]. *)
let view_random_steps (run_model : Model.run_model) steps =
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
                    disabled (List.is_empty steps);
                  ]
                [ text "next steps" ];
            ];
        ];
      (if List.is_empty steps then
         elt "p"
           ~a:[ class_ "terminated-note" ]
           [ text "Computation has terminated" ]
       else text "");
    ]

(* The side panel of a run, with the steps [steps] that can be taken. *)
let view_steps (run_model : Model.run_model) steps =
  panel ~action:(page_link Model.Docs) "Interaction"
    ~a:[ onmouseleave (fun _ -> Model.RunMsg (Model.SelectStepIndex None)) ]
    (view_edit_source ()
    :: view_undo_last_step run_model
    :: view_random_steps run_model steps
    :: List.mapi view_step steps)

let run_view (run_model : Model.run_model) =
  let steps = run_model.current.steps in
  (* The index outlives the step list it points into: taking the last step
     empties the list while the pointer is still on the button. *)
  let selected_step =
    Option.bind run_model.selected_step_index (List.nth_opt steps)
  in
  let active_view =
    if
      run_model.current.is_done
      && not (List.is_empty run_model.current.completed_runs)
    then []
    else
      (* The views of a state are closures stored in the model, so [Vdom.memo]
         renders each of them once while it stays in place. *)
      let state_view =
        match selected_step with
        | None -> Vdom.memo run_model.current.view ()
        | Some step -> Vdom.memo step.view_highlighted ()
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
          Vdom.memo cr.view_completed ();
        ])
      run_model.current.completed_runs
  in
  let report =
    Option.fold ~none:[]
      ~some:(fun (o : BackendRegistry.observer) ->
        [
          Vdom.memo
            (if o.expanded then view_unfolded_report else view_folded_report)
            (Lazy.force o.report);
        ])
      run_model.current.observer
  in
  view_contents
    (report @ active_view @ completed_views)
    [ view_steps run_model steps ]

let view_navbar =
  let view_title =
    div
      ~a:[ class_ "navbar-brand" ]
      [
        div
          ~a:[ class_ "navbar-item brand-title" ]
          [
            (* A link to the page's own address, which loads the page anew. *)
            elt "a"
              ~a:
                [
                  class_ "brand-home";
                  attr "href" "";
                  attr "title" "Reload the page";
                ]
              [
                elt "img"
                  ~a:
                    [
                      class_ "brand-logo";
                      attr "src" "logo/tempore-logo.svg";
                      attr "alt" "Reload the page";
                      attr "width" "56";
                      attr "height" "56";
                    ]
                  [];
              ];
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
            attr "href" Docs.repository;
            attr "target" "_blank";
            attr "rel" "noopener";
            attr "title" "Source code on GitHub";
          ]
        [
          elt "span" ~a:[ class_ "icon" ] [ Icons.github ];
          elt "span" [ text "Source on GitHub" ];
        ];
      view_footer_separator;
      view_footer_link
        ~href:(Docs.repository_file "LICENSE")
        ~title:"Tempore is MIT licensed" "MIT license";
    ]

let view (model : Model.model) =
  div
    [
      view_navbar;
      (match model.navigation.page with
      | Model.Docs ->
          let main, aside =
            Docs.view model.navigation.docs_page
              ~current:model.navigation.docs_heading (page_link Model.Editor)
          in
          view_contents main aside
      | Model.Editor -> (
          match model.run_model with
          | Error _ -> edit_view model
          | Ok run_model -> run_view run_model));
      view_footer;
      (match model.navigation.gallery with
      | Some query ->
          view_gallery ~selected:model.edit_model.selected_example
            ~backend:(Model.backend model.edit_model).key
            ~current:model.navigation.gallery_group query
      | None -> nil);
    ]
