open Vdom

(* A panel of the side column. [action] is placed at the right of the heading,
   opposite its name. *)
let panel ?(a = []) ?action heading blocks =
  let named =
    match action with
    | None -> [ text heading ]
    | Some action -> [ elt "span" [ text heading ]; action ]
  in
  div ~a:(class_ "panel" :: a)
    (elt "p" ~a:[ class_ "panel-heading" ] named :: blocks)

(* Whether [sub] occurs in [s], by the Knuth-Morris-Pratt algorithm (D. E.
   Knuth, J. H. Morris and V. R. Pratt, "Fast pattern matching in strings",
   1977), in time linear in the lengths of both. Str is not available under
   js_of_ocaml. *)
let contains ~sub s =
  let m = String.length sub and n = String.length s in
  (* [border.(i)] is the length of the longest proper border of the first
     [i + 1] bytes of [sub]. *)
  let border = Array.make (max m 1) 0 in
  let rec fall k c =
    if k > 0 && sub.[k] <> c then fall border.(k - 1) c else k
  in
  for i = 1 to m - 1 do
    let k = fall border.(i - 1) sub.[i] in
    border.(i) <- (if sub.[k] = sub.[i] then k + 1 else k)
  done;
  (* [k] bytes of [sub] are matched before byte [i] of [s]. *)
  let rec scan i k =
    k = m
    || i < n
       &&
       let k = fall k s.[i] in
       scan (i + 1) (if sub.[k] = s.[i] then k + 1 else k)
  in
  scan 0 0
