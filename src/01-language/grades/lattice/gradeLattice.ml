module Location = Utils.Location

type t = {
  labels : string array;
  order : bool array array;  (** [order.(i).(j)] iff [i ≤ j] *)
  joins : int array array;
  bottom : int;
  top : int;
  chains : string list list;
  at : Location.t option;
}

let quote name = "`" ^ name ^ "`"

(* [conjunction names] lists [names] quoted, as in "`A`, `B` and `C`". *)
let conjunction names =
  match List.rev_map quote names with
  | [] -> ""
  | [ name ] -> name
  | last :: rest -> String.concat ", " (List.rev rest) ^ " and " ^ last

let fail ?loc fmt = Utils.Error.error ?loc Utils.Diagnostic.Syntax fmt
let show_chain chain = String.concat " < " chain
let range n = List.init n Fun.id

let capitalised name =
  String.length name > 0 && name.[0] >= 'A' && name.[0] <= 'Z'

(* The names of [chains] in the order of their first mention. *)
let mentioned chains =
  List.rev
    (List.fold_left
       (fun seen name -> if List.mem name seen then seen else name :: seen)
       [] (List.concat chains))

(* [pairs chain] is the consecutive pairs of [chain]. *)
let rec pairs = function
  | a :: (b :: _ as rest) -> (a, b) :: pairs rest
  | [ _ ] | [] -> []

(* The reflexive-transitive closure of [edges] over [0 .. n-1], by Warshall's
   algorithm. *)
let closure n edges =
  let direct =
    Array.init n (fun i ->
        Array.init n (fun j -> i = j || List.mem (i, j) edges))
  in
  List.fold_left
    (fun r k ->
      Array.init n (fun i ->
          Array.init n (fun j -> r.(i).(j) || (r.(i).(k) && r.(k).(j)))))
    direct (range n)

(* [check_chain at chain] fails at the first element of [chain] that is not a
   capitalised name or that occurs in it twice. *)
let check_chain at chain =
  ignore
    (List.fold_left
       (fun seen (name, loc) ->
         let loc = if Option.is_some loc then loc else at in
         if not (capitalised name) then
           fail ?loc "The element `%s` is not a capitalised name" name
         else if List.mem name seen then
           fail ?loc "The element `%s` occurs twice in the chain `%s`" name
             (show_chain (List.map fst chain))
         else name :: seen)
       [] chain)

(* The lattice of [chains], each name with its location if any, declared at
   [at]. *)
let build ?at chains =
  List.iter (check_chain at) chains;
  let declared = List.map (List.map fst) chains in
  let names = Array.of_list (mentioned declared) in
  let n = Array.length names in
  let position name =
    Option.get (List.find_opt (fun i -> names.(i) = name) (range n))
  in
  let edges =
    List.concat_map
      (fun chain ->
        List.map (fun (a, b) -> (position a, position b)) (pairs chain))
      declared
  in
  let reach = closure n edges in
  (match
     List.find_opt
       (fun i ->
         List.exists
           (fun j -> j <> i && reach.(i).(j) && reach.(j).(i))
           (range n))
       (range n)
   with
  | Some i ->
      fail ?loc:at "The declared grade lattice has a cycle through %s"
        (conjunction
           (List.filter_map
              (fun j ->
                if reach.(i).(j) && reach.(j).(i) then Some names.(j) else None)
              (range n)))
  | None -> ());
  (* An element has fewer elements below it than any element above it, so
     ordering by that number is a linear extension of the order. *)
  let below i = List.length (List.filter (fun j -> reach.(j).(i)) (range n)) in
  let numbering =
    Array.of_list
      (List.stable_sort (fun i j -> Int.compare (below i) (below j)) (range n))
  in
  let labels = Array.map (fun i -> names.(i)) numbering in
  let order =
    Array.init n (fun a ->
        Array.init n (fun b -> reach.(numbering.(a)).(numbering.(b))))
  in
  let leq a b = order.(a).(b) in
  let minimal elements =
    List.filter
      (fun a -> not (List.exists (fun b -> b <> a && leq b a) elements))
      elements
  in
  let label_list elements =
    conjunction (List.map (fun a -> labels.(a)) elements)
  in
  let bottom =
    match List.find_opt (fun a -> List.for_all (leq a) (range n)) (range n) with
    | Some a -> a
    | None ->
        fail ?loc:at
          "The declared grade lattice has no least element; the minimal \
           elements are %s"
          (label_list (minimal (range n)))
  in
  let join a b =
    let upper = List.filter (fun c -> leq a c && leq b c) (range n) in
    match List.find_opt (fun c -> List.for_all (leq c) upper) upper with
    | Some c -> c
    | None when upper = [] ->
        fail ?loc:at "The elements `%s` and `%s` have no upper bound" labels.(a)
          labels.(b)
    | None ->
        fail ?loc:at
          "The elements `%s` and `%s` have no least upper bound; their minimal \
           upper bounds are %s"
          labels.(a) labels.(b)
          (label_list (minimal upper))
  in
  let joins = Array.init n (fun a -> Array.init n (fun b -> join a b)) in
  let top = List.fold_left (fun t a -> joins.(t).(a)) bottom (range n) in
  { labels; order; joins; bottom; top; chains = declared; at }

let default = build [ [ ("Low", None); ("High", None) ] ]

let of_chains ~at chains =
  build ~at
    (List.map
       (List.map (fun (name : string Location.located) ->
            (name.it, Some name.at)))
       chains)

let size l = Array.length l.labels
let label l i = l.labels.(i)

let index l name =
  List.find_opt (fun i -> String.equal l.labels.(i) name) (range (size l))

let leq l i j = l.order.(i).(j)
let join l i j = l.joins.(i).(j)
let bottom l = l.bottom
let top l = l.top
let elements l = range (size l)

let equal l l' =
  size l = size l'
  && List.for_all
       (fun i ->
         match index l' l.labels.(i) with
         | None -> false
         | Some i' ->
             List.for_all
               (fun j ->
                 match index l' l.labels.(j) with
                 | None -> false
                 | Some j' -> leq l i j = leq l' i' j')
               (elements l))
       (elements l)

let declaration l = String.concat ", " (List.map show_chain l.chains)
let declared_at l = l.at
let few = 4

let its_elements l =
  match size l with
  | 1 -> "its only element is " ^ quote l.labels.(0)
  | n when n <= few ->
      "its elements are " ^ conjunction (Array.to_list l.labels)
  | n ->
      Printf.sprintf "its %d elements range from %s to %s" n
        (quote l.labels.(l.bottom))
        (quote l.labels.(l.top))

let the_elements l =
  match size l with
  | 1 -> "the element " ^ quote l.labels.(0)
  | n when n <= few -> "the elements " ^ conjunction (Array.to_list l.labels)
  | n ->
      Printf.sprintf "the %d elements from %s to %s" n
        (quote l.labels.(l.bottom))
        (quote l.labels.(l.top))
