(* The board profiles of the Arduino backend: the USB identifiers of each
   embedded profile, and the errors of a malformed member "usb". Each case
   prints its outcome, compared with test_board.expected. *)

module Board = ArduinoBackend.ArduinoBoard

let usb board =
  match board.Board.usb with [] -> "none" | ids -> String.concat " " ids

let embedded () =
  List.iter
    (fun name ->
      Printf.printf "%s: %s\n" name (usb (Option.get (Board.find name))))
    Board.names

(* A profile of the member "usb" [ids], or of none. *)
let profile ids =
  Printf.sprintf
    {|{ "title": "A board", "description": "A board", "platform": "p",
  "board": "b", "framework": "arduino", "lib_deps": [], "build_flags": [],
  "cores": 1, "m5unified": false, "capabilities": [], "serial_baud": 115200,
  %s"i2c": [], "includes": [], "init": [] }|}
    (match ids with None -> "" | Some ids -> {|"usb": |} ^ ids ^ ", ")

let malformed () =
  List.iter
    (fun ids ->
      Printf.printf "%s: %s\n"
        (Option.value ~default:"no member" ids)
        (match Board.parse "test" (profile ids) with
        | board -> usb board
        | exception Utils.Error.Error d ->
            "Error: " ^ d.Utils.Diagnostic.message))
    [
      None;
      Some {|[]|};
      Some {|["303a:1001", "10c4:ea60"]|};
      Some {|["303A:1001"]|};
      Some {|["303a1001"]|};
      Some {|["303a:100"]|};
      Some {|["303a:100g"]|};
      Some {|[4097]|};
      Some {|"303a:1001"|};
    ]

let () =
  embedded ();
  malformed ()
