(* Measurements of the editor on the page: what the pointer is over and where
   a popover goes. The text of the editor lies under a transparent textarea, which takes the
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
   edges, the least distance of the card from the editor's sides, and the
   least distance of the arrow from the card's corners. *)
let gap = 8.
let margin = 8.
let inset = 24.
let arrow_inset = 14.

(** [placement ~key ~point] places the drawn popover by the first line of the
    span of target [key], or its line at [point] when there is one: centred
    under it, within the editor and away from its sides, and above it when the
    viewport has no room below and more above. [None] when the card or the span
    is not drawn. *)
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
          Float.max inset
            (Float.min
               (centre -. (width /. 2.))
               (editor_width -. width -. inset))
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
