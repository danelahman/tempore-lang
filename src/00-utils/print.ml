(** Generic pretty-printing functions *)

let subscript n =
  let digits = [| "₀"; "₁"; "₂"; "₃"; "₄"; "₅"; "₆"; "₇"; "₈"; "₉" |] in
  string_of_int n |> String.to_seq
  |> Seq.map (fun d -> digits.(Char.code d - Char.code '0'))
  |> List.of_seq |> String.concat ""

let print ?(at_level = min_int) ?(max_level = max_int) ppf =
  if at_level <= max_level then Format.fprintf ppf
  else fun fmt -> Format.fprintf ppf ("(" ^^ fmt ^^ ")")

let rec print_sequence sep pp vs ppf =
  match vs with
  | [] -> ()
  | [ v ] -> pp v ppf
  | v :: vs ->
      Format.fprintf ppf "%t%s@,%t" (pp v) sep (print_sequence sep pp vs)

let print_tuple ?max_level pp lst ppf =
  match lst with
  | [] -> print ppf "()"
  | lst ->
      let print_elem x = pp ?max_level x in
      print ppf "(@[<hov>%t@])" (print_sequence ", " print_elem lst)
