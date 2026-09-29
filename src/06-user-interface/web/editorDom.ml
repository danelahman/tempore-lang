(* Measurements of the editor on the page: what the pointer is over, where a
   popover goes, which character a point of the displayed program is at. The
   text of the editor lies under a transparent textarea, which takes the
   pointer's events, so its spans are found by their rectangles rather than as
   the targets of events. *)

let get = Ojs.get_prop_ascii
let call obj name args = Ojs.call obj name (Array.of_list args)
let document = get Ojs.global "document"
let window = Ojs.global
let is_nothing obj = Ojs.is_null obj || obj = Ojs.unit_to_js ()
let number obj key = Ojs.float_of_js (get obj key)

(* The elements or rectangles of a DOM collection. *)
let items collection =
  Ojs.array_of_js Fun.id (call (get Ojs.global "Array") "from" [ collection ])
  |> Array.to_list

let query_all root selector =
  items (call root "querySelectorAll" [ Ojs.string_to_js selector ])

let closest element selector =
  if is_nothing element || is_nothing (get element "closest") then None
  else
    let found = call element "closest" [ Ojs.string_to_js selector ] in
    if is_nothing found then None else Some found

type rect = { left : float; top : float; right : float; bottom : float }

let rect_of obj =
  {
    left = number obj "left";
    top = number obj "top";
    right = number obj "right";
    bottom = number obj "bottom";
  }

let bounding element = rect_of (call element "getBoundingClientRect" [])

(* The rectangles of the lines an inline element runs over. *)
let line_rects element =
  List.map rect_of (items (call element "getClientRects" []))

let contains (x, y) r =
  r.left <= x && x <= r.right && r.top <= y && y <= r.bottom

(* The class an element carries with [prefix], without it. *)
let keys_of ~prefix element =
  String.split_on_char ' ' (Ojs.string_of_js (get element "className"))
  |> List.filter_map (fun cls ->
      if String.starts_with ~prefix cls then
        Some
          (String.sub cls (String.length prefix)
             (String.length cls - String.length prefix))
      else None)

(** The prefix of the class naming the popover target of a marked span. *)
let key_prefix = "pop-"

(** The viewport position of a mouse [event]. *)
let point event = (number event "clientX", number event "clientY")

(** What the pointer of a mouse [event] is over: [`Popover], a gutter marker or
    a marked span by the key of its target, the first of [precedence] among the
    keys of the spans at the point, or [`Nothing]. *)
let under ~precedence event =
  let target = get event "target" and point = point event in
  match closest target ".code-popover" with
  | Some _ -> `Popover
  | None -> (
      match closest target "[data-popover]" with
      | Some marker ->
          `Key
            (Ojs.string_of_js
               (call marker "getAttribute" [ Ojs.string_to_js "data-popover" ]))
      | None -> (
          let keys =
            List.concat_map
              (fun element ->
                if List.exists (contains point) (line_rects element) then
                  keys_of ~prefix:key_prefix element
                else [])
              (query_all document ".code-editor-display .has-popover")
          in
          match
            List.find_map (fun first -> List.find_opt first keys) precedence
          with
          | Some key -> `Key key
          | None -> `Nothing))

(** Whether the element a mouse [event] moves to, if any, lies in an element
    matching [selector]. *)
let moves_within selector event =
  Option.is_some (closest (get event "relatedTarget") selector)

(* The gap between a span and its card, the margin kept from the viewport's
   edges, and the least distance of the arrow from the card's corners. *)
let gap = 8.
let margin = 8.
let arrow_inset = 14.

(** [placement ~key ~point] places the drawn popover by the first line of the
    span of target [key], or its line at [point] when there is one: centred
    under it, within the editor, and above it when the viewport has no room
    below and more above. [None] when the card or the span is not drawn. *)
let placement ~key ~point : Model.placement option =
  let card =
    call document "getElementById" [ Ojs.string_to_js "code-popover" ]
  in
  if is_nothing card then None
  else
    let editor = bounding (get card "parentElement") in
    let rects =
      List.concat_map line_rects
        (query_all document (".code-editor-display ." ^ key_prefix ^ key))
    in
    let at_point =
      Option.bind point (fun point -> List.find_opt (contains point) rects)
    in
    match (at_point, rects) with
    | None, [] -> None
    | Some anchor, _ | None, anchor :: _ ->
        let width = number card "offsetWidth"
        and height = number card "offsetHeight"
        and editor_width = editor.right -. editor.left
        and viewport = number window "innerHeight" in
        let centre = ((anchor.left +. anchor.right) /. 2.) -. editor.left in
        let left =
          Float.max 0.
            (Float.min (centre -. (width /. 2.)) (editor_width -. width))
        in
        let arrow =
          Float.max arrow_inset
            (Float.min (centre -. left) (width -. arrow_inset))
        in
        let room_below = viewport -. anchor.bottom -. gap -. margin
        and room_above = anchor.top -. gap -. margin in
        let above = height > room_below && room_above > room_below in
        let top =
          if above then anchor.top -. editor.top -. gap -. height
          else anchor.bottom -. editor.top +. gap
        in
        Some { left; top; width; arrow; above }

let display () =
  call document "querySelector" [ Ojs.string_to_js ".code-editor-display" ]

(* The nodes of the display that are not the program's text. *)
let decorations = ".line-number-anchor, .type-line"

(** The character of the displayed program at the viewport point [(x, y)]: its
    offset in UTF-16 code units, the index of its line, and the top of that line
    in the viewport, as the line's number is placed. *)
let character_at (x, y) =
  let pre = display () in
  let x = Ojs.float_to_js x and y = Ojs.float_to_js y in
  (* caretPositionFromPoint is the standard, caretRangeFromPoint the older
     WebKit form. *)
  let position =
    if not (is_nothing (get document "caretPositionFromPoint")) then
      let p = call document "caretPositionFromPoint" [ x; y ] in
      if is_nothing p then None else Some (get p "offsetNode", get p "offset")
    else if not (is_nothing (get document "caretRangeFromPoint")) then
      let r = call document "caretRangeFromPoint" [ x; y ] in
      if is_nothing r then None
      else Some (get r "startContainer", get r "startOffset")
    else None
  in
  match position with
  | Some (node, offset)
    when (not (is_nothing pre)) && Ojs.bool_of_js (call pre "contains" [ node ])
    ->
      let range = call document "createRange" [] in
      ignore (call range "setStart" [ pre; Ojs.int_to_js 0 ]);
      ignore (call range "setEnd" [ node; offset ]);
      let prefix = call range "cloneContents" [] in
      List.iter
        (fun element -> ignore (call element "remove" []))
        (query_all prefix decorations);
      let text = get prefix "textContent" in
      let line =
        String.fold_left
          (fun n c -> if c = '\n' then n + 1 else n)
          0 (Ojs.string_of_js text)
      in
      let anchors = query_all pre ".line-number-anchor" in
      let top =
        match List.nth_opt anchors line with
        | Some anchor -> (bounding anchor).top
        | None -> 0.
      in
      Some (Ojs.int_of_js (get text "length"), line, top)
  | _ -> None

let editor_input () =
  call document "querySelector" [ Ojs.string_to_js ".code-editor-input" ]

(** Put the focus in the editor, its caret at [offset] in UTF-16 code units,
    without scrolling the page. *)
let focus_editor offset =
  let input = editor_input () in
  if not (is_nothing input) then begin
    ignore
      (call input "focus"
         [ Ojs.obj [| ("preventScroll", Ojs.bool_to_js true) |] ]);
    ignore
      (call input "setSelectionRange"
         [ Ojs.int_to_js offset; Ojs.int_to_js offset ])
  end

(** Scroll the page so that line [line] of the display, whose number was at
    [top] in the viewport, is there again. *)
let keep_line line top =
  let pre = display () in
  if not (is_nothing pre) then
    match List.nth_opt (query_all pre ".line-number-anchor") line with
    | Some anchor ->
        let shift = (bounding anchor).top -. top in
        if Float.abs shift >= 1. then
          ignore
            (call window "scrollBy"
               [
                 Ojs.obj
                   [|
                     ("top", Ojs.float_to_js shift);
                     ("left", Ojs.float_to_js 0.);
                     ("behavior", Ojs.string_to_js "instant");
                   |];
               ])
    | None -> ()

(** Put [text] on the clipboard, where the browser offers one. *)
let copy text =
  try
    let clipboard = get (get window "navigator") "clipboard" in
    if not (is_nothing clipboard) then
      ignore (call clipboard "writeText" [ Ojs.string_to_js text ])
  with _ -> ()
