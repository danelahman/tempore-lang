module C = DelayTimedClosure

type value = DelaySet.extremum = Finite of Rational.t * bool | Infinite

(* {1 Resources and demands} *)

(* A resource is a supremum, [Finite (a, false)] approached from below; a
   demand an infimum, [Finite (a, false)] approached from above. *)

let zero = Finite (Rational.zero, true)

let add x y =
  match (x, y) with
  | Finite (a, f), Finite (b, g) -> Finite (Rational.add a b, f && g)
  | Infinite, _ | _, Infinite -> Infinite

(* The order of resources: [a⁻ < a], infinity the greatest. *)
let compare_resource x y =
  match (x, y) with
  | Infinite, Infinite -> 0
  | Infinite, Finite _ -> 1
  | Finite _, Infinite -> -1
  | Finite (a, f), Finite (b, g) -> (
      match Rational.compare a b with 0 -> Bool.compare f g | c -> c)

(* [meets demand resource] is whether some value of [demand] is at most some
   value of [resource]. *)
let meets demand resource =
  match (demand, resource) with
  | _, Infinite -> true
  | Infinite, Finite _ -> false
  | Finite (d, f), Finite (r, g) ->
      let c = Rational.compare d r in
      c < 0 || (c = 0 && f && g)

(* [less resource demand] is the resource left of [resource] once [demand],
   which it meets, is met. *)
let less resource demand =
  match (resource, demand) with
  | Infinite, _ -> Infinite
  | Finite (r, g), Finite (d, f) -> Finite (Rational.sub r d, g && f)
  | Finite _, Infinite -> invalid_arg "JointWalk.less: an infinite demand"

(* [beyond demand resource] is the demand left of [demand] once [resource],
   which does not meet it, is spent on it. *)
let beyond demand resource =
  match (demand, resource) with
  | Finite (d, f), Finite (r, g) -> Finite (Rational.sub d r, f && g)
  | _ -> invalid_arg "JointWalk.beyond: an infinite demand or resource"

(* {1 States} *)

type pair = { slack : value; budget : value }
(* The slack of the coverage order and the budget of the allowance order. *)

let start = { slack = zero; budget = zero }
let total p = add p.slack p.budget

(* [below p p'] is whether [p'] is at least as good as [p]. *)
let below p p' =
  compare_resource p.budget p'.budget <= 0
  && compare_resource (total p) (total p') <= 0

(* [insert p ps] is the antichain [ps] with [p] added, if no pair of [ps] is
   at least as good. *)
let insert p ps =
  if List.exists (below p) ps then None
  else Some (p :: List.filter (fun p' -> not (below p' p)) ps)

let spend d p =
  if not (meets d (total p)) then None
  else if meets d p.slack then Some { p with slack = less p.slack d }
  else Some { slack = zero; budget = less p.budget (beyond d p.slack) }

let pay c p =
  if meets c p.budget then Some { slack = zero; budget = less p.budget c }
  else None

(* {1 The walk} *)

module Nodes = Map.Make (struct
  type t = int * int

  let compare (n, m) (n', m') =
    match Int.compare n n' with 0 -> Int.compare m m' | c -> c
end)

(* [antichain node table] is the antichain of [table] at [node]. *)
let antichain node table = Option.value (Nodes.find_opt node table) ~default:[]

(* [add_pair node p table] is [table] with [p] added at [node], if no pair
   there is at least as good. *)
let add_pair node p table =
  Option.map
    (fun ps -> Nodes.add node ps table)
    (insert p (antichain node table))

(* [merge (node, ps) table] is [table] with the pairs [ps] added at [node]. *)
let merge (node, ps) table =
  List.fold_left
    (fun table p -> Option.value (add_pair node p table) ~default:table)
    table ps

(* [record (node, ps) (found, fresh)] adds the pairs [ps] at [node] to
   [found], and those it keeps to [fresh]. *)
let record (node, ps) (found, fresh) =
  List.fold_left
    (fun (found, fresh) p ->
      match add_pair node p found with
      | None -> (found, fresh)
      | Some found -> (found, merge (node, [ p ]) fresh))
    (found, fresh) ps

let running_time world name =
  match List.assoc_opt name world with
  | Some c -> c
  | None ->
      invalid_arg
        ("JointWalk.running_time: the name " ^ name
       ^ " is not an operation of the world")

(* The nodes of a graph are its gap states [g], numbered [g], and its operation
   states [o], numbered [n + o], [n] the number of gap states. *)

(* [summaries ~lo u] is, for a node [m] of [u] and the antichain [ps] at it,
   the antichains of the pairs reached at each node of [u] by moves of [u]
   alone: with [B] the longest paths, delays weighing their suprema and
   operations [0], and [T] those with operations weighing their lower running
   times, the pairs [(k, b + B(m, m'))] and, for each transition
   [v -a-> v'] of an operation, [(k + b + T(m, v) + lo(a), B(v', m'))]. *)
let summaries ~lo (u : C.graph) =
  let ng = Array.length u.gaps in
  let nodes = ng + Array.length u.ops in
  let edges op =
    Array.append
      (Array.map
         (List.map (fun (s, o) ->
              (ng + o, Option.value (DelaySet.sup s) ~default:zero)))
         u.gaps)
      (Array.map (List.map (fun (name, g) -> (g, op name))) u.ops)
  in
  let lazily longest = Array.init nodes (fun m -> lazy (longest m)) in
  let bank = lazily (C.longest (edges (Fun.const zero)))
  and fill = lazily (C.longest (edges (running_time lo))) in
  let transitions =
    List.concat
      (List.mapi
         (fun o row -> List.map (fun (name, g) -> (ng + o, name, g)) row)
         (Array.to_list u.ops))
  in
  fun m ps ->
    let banked = Lazy.force bank.(m) and filled = Lazy.force fill.(m) in
    let most =
      List.fold_left
        (fun x p -> if compare_resource (total p) x > 0 then total p else x)
        zero ps
    in
    List.init nodes (fun m' ->
        let skipped =
          match banked.(m') with
          | Some w -> List.map (fun p -> { p with budget = add p.budget w }) ps
          | None -> []
        in
        let performed =
          List.filter_map
            (fun (v, name, v') ->
              match (filled.(v), (Lazy.force bank.(v')).(m')) with
              | Some t, Some w ->
                  Some
                    {
                      slack = add (add most t) (running_time lo name);
                      budget = w;
                    }
              | _ -> None)
            transitions
        in
        (m', skipped @ performed))

(* [moves ~hi l u (n, m) ps] is the antichains reached from the pairs [ps] at
   the node [n] of [l] and [m] of [u] by one move of [l]: a delay spent, an
   operation paid, or an operation matched. *)
let moves ~hi (l : C.graph) (u : C.graph) (n, m) ps =
  let nl = Array.length l.gaps and nu = Array.length u.gaps in
  if n < nl then
    List.filter_map
      (fun (s, o) ->
        Option.map
          (fun d -> ((nl + o, m), List.filter_map (spend d) ps))
          (DelaySet.inf s))
      l.gaps.(n)
  else
    List.concat_map
      (fun (name, g) ->
        ((g, m), List.filter_map (pay (running_time hi name)) ps)
        ::
        (if m < nu then []
         else
           List.filter_map
             (fun (name', g') ->
               if String.equal name name' then Some ((g, g'), [ start ])
               else None)
             u.ops.(m - nu)))
      l.ops.(n - nl)

let consistent ~lo ~hi (l : C.graph) (u : C.graph) =
  let nl = Array.length l.gaps in
  let final (n, _) = n >= nl && l.final.(n - nl) in
  let summary = summaries ~lo u in
  let rec rounds found entries =
    if Nodes.exists (fun node _ -> final node) entries then true
    else if Nodes.is_empty entries then false
    else
      let found, fresh =
        Nodes.fold
          (fun (n, m) ps acc ->
            List.fold_left
              (fun acc (m', ps') -> record ((n, m'), ps') acc)
              acc (summary m ps))
          entries (found, Nodes.empty)
      in
      let entries =
        Nodes.fold
          (fun node ps entries ->
            List.fold_left
              (fun entries step -> merge step entries)
              entries (moves ~hi l u node ps))
          fresh Nodes.empty
      in
      rounds found entries
  in
  l.live && u.live && rounds Nodes.empty (Nodes.singleton (0, 0) [ start ])
