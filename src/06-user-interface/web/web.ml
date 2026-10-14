(* Side effects on the page are commands: scrolling to an element and placing
   the caret, run once the view has been redrawn, when the element exists (see
   [update]); timers; measurements of the redrawn page; messages sent once the
   redrawn page has been painted; and effects run at once. *)
type 'msg Vdom.Cmd.t +=
  | Scroll_to of string  (** the id of an element *)
  | Set_caret of int  (** where the editor's caret goes after a redraw *)
  | Send_after of int * 'msg  (** send the message after so many milliseconds *)
  | After_redraw of (unit -> 'msg option)
        (** run after the next redraw, sending the message it yields *)
  | After_paint of 'msg
        (** send the message once the next redraw has been painted *)
  | Now of (unit -> unit)  (** run at once *)
  | Copy of string * (bool -> 'msg)
        (** copy the text to the clipboard, sending the message of whether it
            has been copied *)

(* The element of id [id] scrolled to the middle of the window. *)
let scroll_to id =
  Option.iter
    (fun element ->
      ignore
        (EditorDom.call element "scrollIntoView"
           [
             Ojs.obj
               [|
                 ( "behavior",
                   Ojs.string_to_js
                     (if EditorDom.reduced_motion () then "auto" else "smooth")
                 );
                 ("block", Ojs.string_to_js "center");
               |];
           ]))
    (EditorDom.by_id id)

(* The heading of identifier [id] at the top of the window, as following an
   anchor places it, or the page at its top without one. *)
let scroll_to_heading = function
  | Some id ->
      Option.iter
        (fun element ->
          ignore
            (EditorDom.call element "scrollIntoView" [ Ojs.bool_to_js true ]))
        (EditorDom.by_id id)
  | None ->
      ignore
        (EditorDom.call Ojs.global "scrollTo"
           [ Ojs.int_to_js 0; Ojs.int_to_js 0 ])

(* The card of the example last loaded, in the gallery just opened: focused
   without the browser's own scrolling, and centred at once in the gallery's
   list by scrolling the list alone, which leaves the page behind the gallery
   in place. *)
let focus_current_example () =
  Option.iter
    (fun card ->
      ignore
        (EditorDom.call card "focus"
           [ Ojs.obj [| ("preventScroll", Ojs.bool_to_js true) |] ]);
      Option.iter
        (fun list ->
          let middle (r : EditorDom.rect) = (r.top +. r.bottom) /. 2. in
          let offset =
            middle (EditorDom.bounding card) -. middle (EditorDom.bounding list)
          in
          Ojs.set_prop_ascii list "scrollTop"
            (Ojs.float_to_js (EditorDom.number list "scrollTop" +. offset)))
        (EditorDom.closest card ".example-gallery-list"))
    (EditorDom.by_id View.current_example_id)

(* Setting the editor's value from the model leaves the caret at the end; put
   it back where the edit happened. The position is counted in the browser's
   own UTF-16 code units, as the selection it sets is. *)
let set_caret position =
  match EditorDom.query_all EditorDom.document ".code-editor-input" with
  | [ editor ] ->
      Ojs.set_prop_ascii editor "selectionStart" (Ojs.int_to_js position);
      Ojs.set_prop_ascii editor "selectionEnd" (Ojs.int_to_js position)
  | _ -> ()

(* The property [key] of the page's location, as a string. *)
let location key =
  Ojs.string_of_js (EditorDom.get (EditorDom.get Ojs.global "location") key)

(* The page's address: its location without query and fragment, followed by
   [query]. *)
let address query =
  location "protocol" ^ "//" ^ location "host" ^ location "pathname" ^ query

(* The query of the page's address replaced, the fragment removed, without an
   entry of its own in the history. Some browsers refuse it for the address of
   a file, which is then left as it is. *)
let replace_query query =
  try
    ignore
      (EditorDom.call
         (EditorDom.get Ojs.global "history")
         "replaceState"
         [
           Ojs.null;
           Ojs.string_to_js "";
           Ojs.string_to_js (location "pathname" ^ query);
         ])
  with _ -> ()

(* [text] written to the clipboard, [reply] receiving whether it has been: the
   clipboard is missing outside a secure context, and may refuse the write. *)
let copy text reply =
  try
    let clipboard =
      EditorDom.get (EditorDom.get Ojs.global "navigator") "clipboard"
    in
    if EditorDom.is_nothing clipboard then reply false
    else
      let written =
        EditorDom.call clipboard "writeText" [ Ojs.string_to_js text ]
      in
      ignore
        (EditorDom.call written "then"
           [
             Ojs.fun_to_js 1 (fun _ -> reply true);
             Ojs.fun_to_js 1 (fun _ -> reply false);
           ])
  with _ -> reply false

let command_handler =
  {
    Vdom_blit.Cmd.f =
      (fun ctx cmd ->
        match cmd with
        | Scroll_to id ->
            Vdom_blit.Cmd.after_redraw ctx (fun () -> scroll_to id);
            true
        | Set_caret position ->
            Vdom_blit.Cmd.after_redraw ctx (fun () -> set_caret position);
            true
        | Send_after (delay, msg) ->
            EditorDom.set_timeout
              (fun () -> Vdom_blit.Cmd.send_msg ctx msg)
              delay;
            true
        | After_redraw f ->
            Vdom_blit.Cmd.after_redraw ctx (fun () ->
                Option.iter (Vdom_blit.Cmd.send_msg ctx) (f ()));
            true
        (* The redraw runs in an animation frame, which is painted before the
           tasks queued during it are run. *)
        | After_paint msg ->
            Vdom_blit.Cmd.after_redraw ctx (fun () ->
                EditorDom.set_timeout
                  (fun () -> Vdom_blit.Cmd.send_msg ctx msg)
                  0);
            true
        | Now f ->
            f ();
            true
        | Copy (text, msg) ->
            copy text (fun copied -> Vdom_blit.Cmd.send_msg ctx (msg copied));
            true
        | _ -> false);
  }

(* Values the browser's local storage keeps under a key. Storage may be missing
   or refuse access, as in a private window, or be full: nothing is then
   recalled or remembered. *)
let storage () =
  let storage = EditorDom.get Ojs.global "localStorage" in
  if EditorDom.is_nothing storage then None else Some storage

let recall key =
  try
    Option.bind (storage ()) (fun storage ->
        let value = EditorDom.call storage "getItem" [ Ojs.string_to_js key ] in
        if EditorDom.is_nothing value then None
        else Some (Ojs.string_of_js value))
  with _ -> None

let remember key value =
  try
    Option.iter
      (fun storage ->
        ignore
          (EditorDom.call storage "setItem"
             [ Ojs.string_to_js key; Ojs.string_to_js value ]))
      (storage ())
  with _ -> ()

(* The status line abbreviates the number of definitions where it cannot hold
   it in full. The width the line needs in full is measured on each change of
   its content, and compared with the line's width then and whenever that
   changes, as an observer set up by [run] reports. *)
let status_needed = ref None
let status_observer = ref None
let status_line () = EditorDom.by_id View.status_id

let abbreviates line =
  match !status_needed with
  | Some needed ->
      let { EditorDom.left; right; _ } = EditorDom.bounding line in
      needed > right -. left
  | None -> false

(* The width from the left edge of the line to the end of its text in full,
   the abbreviation undone while it is measured; [None] without a number of
   definitions. *)
let measure_status line =
  let select selector =
    let found =
      EditorDom.call line "querySelector" [ Ojs.string_to_js selector ]
    in
    if EditorDom.is_nothing found then None else Some found
  in
  match (select ".check-status-full", select ".check-status-text") with
  | Some _, Some text ->
      let measuring = Ojs.string_to_js "data-measuring" in
      ignore
        (EditorDom.call line "setAttribute" [ measuring; Ojs.string_to_js "" ]);
      let range = EditorDom.call EditorDom.document "createRange" [] in
      ignore (EditorDom.call range "selectNodeContents" [ text ]);
      let needed =
        (EditorDom.bounding range).right -. (EditorDom.bounding line).left
      in
      ignore (EditorDom.call line "removeAttribute" [ measuring ]);
      Some needed
  | _ -> None

(* The line measured anew and observed, and the message setting whether it
   abbreviates, when that changes. *)
let fit_status (model : Model.model) () =
  Option.bind (status_line ()) (fun line ->
      Option.iter
        (fun observer ->
          ignore (EditorDom.call observer "disconnect" []);
          ignore (EditorDom.call observer "observe" [ line ]))
        !status_observer;
      status_needed := measure_status line;
      let abbreviated = abbreviates line in
      if abbreviated <> model.status.abbreviated then
        Some (Model.Abbreviate abbreviated)
      else None)

(* The section scrolled to, in the documentation and in the example gallery
   (see [EditorDom.reached]), and the heading last followed by a link, which
   the end of a page lights when its last sections cannot reach the top. *)
let followed = ref None

let docs_heading_selector =
  Printf.sprintf ".%s h2[id], .%s h3[id]" Docs.readme_class Docs.readme_class

let gallery_list_selector = ".example-gallery-list"
let gallery_group_selector = gallery_list_selector ^ " > .example-group[id]"

(* The message of the section of the documentation scrolled to, when that has
   changed. *)
let reached_heading (model : Model.model) () =
  if model.navigation.page <> Model.Docs then None
  else
    match
      EditorDom.reached ~headings:docs_heading_selector ~area:None
        ~followed:!followed
    with
    | Some id when model.navigation.docs_heading <> Some id ->
        Some (Model.ReachHeading id)
    | _ -> None

(* The message of the group of the example gallery scrolled to, when that has
   changed. *)
let reached_group (model : Model.model) () =
  if model.navigation.gallery = None then None
  else
    match
      EditorDom.reached ~headings:gallery_group_selector
        ~area:(Some gallery_list_selector) ~followed:!followed
    with
    | Some id when model.navigation.gallery_group <> Some id ->
        Some (Model.ReachGroup id)
    | _ -> None

(* The command performing the side effect of [model]. *)
let command_of_effect (model : Model.model) = function
  | Model.After (delay, msg) -> Send_after (delay, msg)
  | Model.Measure_popover ->
      After_redraw
        (fun () ->
          Option.map
            (fun ({ target; point; _ } : Model.popover) ->
              Model.Place
                ( target,
                  EditorDom.placement ~key:(View.target_key target) ~point ))
            model.popovers.popover)
  | Model.Scroll_to_error i -> Scroll_to (View.error_id i)
  | Model.Scroll_to_span i -> Scroll_to (View.primary_id i)
  | Model.Scroll_to_declaration -> Scroll_to View.declaration_flash_id
  | Model.Scroll_to_heading heading ->
      After_redraw
        (fun () ->
          followed := heading;
          scroll_to_heading heading;
          None)
  | Model.Perform_after_paint action -> After_paint (Model.Perform action)
  | Model.Remember (key, value) -> Now (fun () -> remember key value)
  | Model.Focus_current_example ->
      After_redraw
        (fun () ->
          focus_current_example ();
          None)
  | Model.Jump offset ->
      After_redraw
        (fun () ->
          EditorDom.jump offset;
          None)
  | Model.Replace_query query -> Now (fun () -> replace_query query)
  | Model.Copy_link query ->
      let link = address query in
      Copy (link, fun copied -> Model.Copied (link, copied))

let update model msg =
  let model', side_effects = Model.update model msg in
  let cmd =
    match (msg, model'.Model.run_model) with
    | Model.Perform _, Error (error :: _) when not (Model.is_warning error) ->
        Scroll_to (View.load_error_target 0 error)
    | Model.EditMsg (Model.InsertIndent (_, start, _)), _ ->
        Set_caret (start + String.length Model.indentation)
    | _ -> Vdom.Cmd.batch []
  in
  (* the content of the status line changed, or the line drawn anew *)
  let status =
    if
      model.Model.status.last_check <> model'.status.last_check
      || model.navigation.page <> model'.navigation.page
      || Result.is_ok model.run_model <> Result.is_ok model'.run_model
    then [ After_redraw (fit_status model') ]
    else []
  in
  (* the documentation or the gallery drawn anew, unless scrolled to a heading,
     which the scrolling reports *)
  let reading =
    match msg with
    | Model.ShowDocs _ -> []
    | _ ->
        (if
           model.navigation.page <> model'.navigation.page
           || model.navigation.docs_page <> model'.navigation.docs_page
         then [ After_redraw (reached_heading model') ]
         else [])
        @
        if model.navigation.gallery <> model'.navigation.gallery then
          [ After_redraw (reached_group model') ]
        else []
  in
  ( model',
    Vdom.Cmd.batch
      ((cmd :: status) @ reading
      @ List.map (command_of_effect model') side_effects) )

let app =
  let query = try location "search" with _ -> "" in
  let model, side_effects = Model.opened ~query (recall WebChoices.key) in
  Vdom.app
    ~init:
      (model, Vdom.Cmd.batch (List.map (command_of_effect model) side_effects))
    ~view:View.view ~update ()

(* The modifier of links is watched on the whole page, the pointer resting on
   a name as it is pressed or released: its position is kept from the last
   move of the pointer. Leaving the window counts as releasing it, the release
   being reported to the window left. *)
let watch_modifier app =
  let point = ref None in
  let report link =
    if (Vdom_blit.get app).Model.popovers.link <> link then
      Vdom_blit.process app (Model.OverLink link)
  in
  let modifier event =
    EditorDom.is_modifier (Ojs.string_of_js (EditorDom.get event "key"))
  in
  EditorDom.listen ~capture:false "mousemove" (fun event ->
      point := Some (EditorDom.point event));
  EditorDom.listen ~capture:false "keydown" (fun event ->
      if modifier event && (Vdom_blit.get app).Model.checked.links <> [] then
        report (Option.bind !point EditorDom.link_at));
  EditorDom.listen ~capture:false "keyup" (fun event ->
      if modifier event then report None);
  EditorDom.listen ~capture:false "blur" (fun _ -> report None)

(* The observer of the width of the status line, where the browser has one. *)
let observe_status app =
  let constructor = EditorDom.get Ojs.global "ResizeObserver" in
  if not (EditorDom.is_nothing constructor) then
    status_observer :=
      Some
        (Ojs.new_obj constructor
           [|
             Ojs.fun_to_js 1 (fun _ ->
                 Option.iter
                   (fun line ->
                     let abbreviated = abbreviates line in
                     if
                       abbreviated
                       <> (Vdom_blit.get app).Model.status.abbreviated
                     then Vdom_blit.process app (Model.Abbreviate abbreviated))
                   (status_line ()));
           |])

(* The section scrolled to is found once per animation frame in which the
   window or an element of the page has scrolled, or the window has been
   resized, since scroll events do not bubble but are captured by the window. A
   link to a heading of the page clicked is the heading followed. *)
let watch_reading app =
  let scheduled = ref false in
  let reach () =
    scheduled := false;
    let model = Vdom_blit.get app in
    List.iter
      (fun reached -> Option.iter (Vdom_blit.process app) (reached model ()))
      [ reached_heading; reached_group ]
  in
  let schedule _ =
    if not !scheduled then begin
      scheduled := true;
      ignore
        (EditorDom.call Ojs.global "requestAnimationFrame"
           [ Ojs.fun_to_js 1 (fun _ -> reach ()) ])
    end
  in
  EditorDom.listen ~capture:true "scroll" schedule;
  EditorDom.listen ~capture:true "resize" schedule;
  EditorDom.listen ~capture:true "click" (fun event ->
      Option.iter
        (fun link ->
          let href =
            Ojs.string_of_js
              (EditorDom.call link "getAttribute" [ Ojs.string_to_js "href" ])
          in
          if String.length href > 1 then
            followed := Some (String.sub href 1 (String.length href - 1)))
        (EditorDom.closest (EditorDom.get event "target") "a[href^='#']"))

(* The page drawn into its container, or else into the document's root, and
   its watchers set up. *)
let run () =
  Random.self_init ();
  let app = Vdom_blit.run ~env:(Vdom_blit.cmd command_handler) app in
  watch_modifier app;
  watch_reading app;
  observe_status app;
  let container =
    match EditorDom.by_id "container" with
    | Some element -> element
    | None -> EditorDom.get EditorDom.document "documentElement"
  in
  ignore
    (EditorDom.call container "appendChild"
       [ Js_browser.Element.t_to_js (Vdom_blit.dom app) ])

let () =
  Ojs.set_prop_ascii Ojs.global "onload" (Ojs.fun_to_js 1 (fun _ -> run ()))
