type t = Abort | Warn | Off

let name = function Abort -> "abort" | Warn -> "warn" | Off -> "off"

let policies =
  List.map (fun policy -> (name policy, policy)) [ Abort; Warn; Off ]

let of_name s = List.assoc_opt s policies
