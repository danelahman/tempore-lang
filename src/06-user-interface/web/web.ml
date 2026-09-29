(* Side effects on the page are commands: scrolling to an element and placing
   the caret, run once the view has been redrawn, when the element exists (see
   [update]); timers; measurements of the redrawn page; and effects run at
   once. *)
type 'msg Vdom.Cmd.t +=
  | Scroll_to of string  (** the id of an element *)
  | Set_caret of int  (** where the editor's caret goes after a redraw *)
  | Send_after of int * 'msg  (** send the message after so many milliseconds *)
  | After_redraw of (unit -> 'msg option)
        (** run after the next redraw, sending the message it yields *)
  | Now of (unit -> unit)  (** run at once *)

let scroll_to id =
  match Js_browser.Document.get_element_by_id Js_browser.document id with
  | Some element ->
      ignore
        (Ojs.call
           (Js_browser.Element.t_to_js element)
           "scrollIntoView"
           [|
             Ojs.obj
               [|
                 ("behavior", Ojs.string_to_js "smooth");
                 ("block", Ojs.string_to_js "center");
               |];
           |])
  | None -> ()

(* Setting the editor's value from the model leaves the caret at the end; put
   it back where the edit happened. The position is counted in the browser's
   own UTF-16 code units, as the selection it sets is. *)
let set_caret position =
  match
    Js_browser.Document.query_selector_all Js_browser.document
      ".code-editor-input"
  with
  | [ editor ] ->
      Js_browser.Element.set_selection_start editor position;
      Js_browser.Element.set_selection_end editor position
  | _ -> ()

let scroll_handler =
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
            ignore
              (Js_browser.Window.set_timeout Js_browser.window
                 (fun () -> Vdom_blit.Cmd.send_msg ctx msg)
                 delay);
            true
        | After_redraw f ->
            Vdom_blit.Cmd.after_redraw ctx (fun () ->
                Option.iter (Vdom_blit.Cmd.send_msg ctx) (f ()));
            true
        | Now f ->
            f ();
            true
        | _ -> false);
  }

(* Settings the browser remembers, as "true" or "false" under a key. Storage
   may be missing or refuse access, as in a private window: the default then
   holds and nothing is remembered. *)
let recall key default =
  try
    match Js_browser.Window.local_storage Js_browser.window with
    | Some storage -> (
        match Js_browser.Storage.get_item storage key with
        | Some "true" -> true
        | Some "false" -> false
        | _ -> default)
    | None -> default
  with _ -> default

let remember key value =
  try
    Option.iter
      (fun storage ->
        Js_browser.Storage.set_item storage key (string_of_bool value))
      (Js_browser.Window.local_storage Js_browser.window)
  with _ -> ()

let command (model : Model.model) = function
  | Model.After (delay, msg) -> Send_after (delay, msg)
  | Model.Measure_popover ->
      After_redraw
        (fun () ->
          Option.map
            (fun ({ target; point; _ } : Model.popover) ->
              Model.Place
                ( target,
                  EditorDom.placement ~key:(View.target_key target) ~point ))
            model.popover)
  | Model.Scroll_to_error i -> Scroll_to (View.error_id i)
  | Model.Remember (key, value) -> Now (fun () -> remember key value)
  | Model.Copy text -> Now (fun () -> EditorDom.copy text)
  | Model.Enter_editor (offset, line, top) ->
      Vdom.Cmd.batch
        [
          Now (fun () -> EditorDom.focus_editor offset);
          After_redraw
            (fun () ->
              EditorDom.keep_line line top;
              Some (Model.CaretAt offset));
        ]

let update model msg =
  let model', side_effects = Model.update model msg in
  let cmd =
    match (msg, model'.Model.run_model) with
    | Model.RunCode, Error (error :: _) ->
        Scroll_to (View.load_error_target 0 error)
    | Model.EditMsg (Model.InsertIndent (_, start, _)), _ ->
        Set_caret (start + String.length Model.indentation)
    | _ -> Vdom.Cmd.batch []
  in
  (model', Vdom.Cmd.batch (cmd :: List.map (command model') side_effects))

let init =
  {
    Model.init with
    edit_model =
      {
        Model.init.edit_model with
        use_stdlib =
          recall Model.use_stdlib_key Model.init.edit_model.use_stdlib;
      };
    show_types = recall Model.show_types_key Model.init.show_types;
  }

let app = Vdom.app ~init:(init, Vdom.Cmd.batch []) ~view:View.view ~update ()

let run () =
  Vdom_blit.run ~env:(Vdom_blit.cmd scroll_handler) app
  |> Vdom_blit.dom
  |> Js_browser.Element.append_child
       (match
          Js_browser.Document.get_element_by_id Js_browser.document "container"
        with
       | Some element -> element
       | None -> Js_browser.Document.document_element Js_browser.document)

let () = Js_browser.Window.set_onload Js_browser.window run
