let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt

let finish ?success () =
  match List.rev !failures with
  | [] -> Option.iter print_endline success
  | failures ->
      List.iter prerr_endline failures;
      exit 1
