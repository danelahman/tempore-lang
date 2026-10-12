module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module Names = OpentronsNames
module Reach = OpentronsReach
module VariableSet = Reach.VariableSet

let runtime = Opentrons_runtime.contents

(* Python source: lines, and blocks of a header line and an indented body. *)
type stmt = Line of string | Block of string * stmt list

let rec lines indent = function
  | Line s -> [ indent ^ s ]
  | Block (header, body) ->
      (indent ^ header) :: List.concat_map (lines (indent ^ "    ")) body

let render stmts = String.concat "\n" (List.concat_map (lines "") stmts) ^ "\n"

(* Literals. *)

(* A Python string literal of the UTF-8 string [s], in ASCII: a byte that is
   not part of a well-formed UTF-8 sequence becomes the lone surrogate the
   runtime encodes back to it. *)
let python_string s =
  let char u =
    match Uchar.to_int u with
    | 0x22 -> "\\\""
    | 0x5C -> "\\\\"
    | c when c >= 0x20 && c < 0x7F -> String.make 1 (Char.chr c)
    | c when c < 0x100 -> Printf.sprintf "\\x%02x" c
    | c when c < 0x10000 -> Printf.sprintf "\\u%04x" c
    | c -> Printf.sprintf "\\U%08x" c
  in
  let rec escaped i acc =
    if i >= String.length s then String.concat "" (List.rev acc)
    else
      let d = String.get_utf_8_uchar s i in
      if Uchar.utf_decode_is_valid d then
        escaped
          (i + Uchar.utf_decode_length d)
          (char (Uchar.utf_decode_uchar d) :: acc)
      else escaped (i + 1) (Printf.sprintf "\\udc%02x" (Char.code s.[i]) :: acc)
  in
  "\"" ^ escaped 0 [] ^ "\""

let python_float f =
  match Float.classify_float f with
  | FP_nan -> "math.nan"
  | FP_infinite -> if f > 0. then "math.inf" else "-math.inf"
  | FP_normal | FP_subnormal | FP_zero ->
      let s = Printf.sprintf "%.17g" f in
      if String.exists (fun c -> c = '.' || c = 'e') s then s else s ^ ".0"

let constant = function
  | Const.Nat n -> Z.to_string n
  | Const.String s -> python_string s
  | Const.Boolean b -> if b then "True" else "False"
  | Const.Float f -> python_float f

let tuple = function
  | [] -> "()"
  | [ e ] -> "(" ^ e ^ ",)"
  | es -> "(" ^ String.concat ", " es ^ ")"

(* The runtime function of each primitive. *)
let primitive_function = function
  | Primitives.CompareEq -> "prim_compare_eq"
  | Primitives.CompareLt -> "prim_compare_lt"
  | Primitives.CompareGt -> "prim_compare_gt"
  | Primitives.CompareLe -> "prim_compare_le"
  | Primitives.CompareGe -> "prim_compare_ge"
  | Primitives.CompareNe -> "prim_compare_ne"
  | Primitives.NatAdd -> "prim_nat_add"
  | Primitives.NatMul -> "prim_nat_mul"
  | Primitives.NatSub -> "prim_nat_sub"
  | Primitives.NatDiv -> "prim_nat_div"
  | Primitives.NatMod -> "prim_nat_mod"
  | Primitives.FloatAdd -> "prim_float_add"
  | Primitives.FloatMul -> "prim_float_mul"
  | Primitives.FloatSub -> "prim_float_sub"
  | Primitives.FloatDiv -> "prim_float_div"
  | Primitives.FloatPow -> "prim_float_pow"
  | Primitives.FloatNeg -> "prim_float_neg"
  | Primitives.ToString -> "prim_to_string"

(* The emission context. Continuations and the computations bound by [do] are
   lifted out of the function they occur in to definitions at the level of
   its body, so that the nesting of the Python source follows the nesting of
   functions and cases rather than the length of sequences. A lifted
   definition takes as parameters the variables it uses that are bound in
   lifted definitions, [local]; the others it reads from the enclosing
   function. [in_lifted] is whether the code emitted is in a lifted
   definition. *)
type context = {
  names : Names.t;
  labels : Names.labels;
  local : VariableSet.t;
  in_lifted : bool;
}

(* The emission state: the supply of fresh names, which consist of a lowercase
   prefix and a number and so differ from the identifiers of variables, and
   the definitions lifted to the level of the current function's body, the
   last first. *)
type state = { next : int; lifted : stmt list }

let fresh prefix st =
  (prefix ^ string_of_int st.next, { st with next = st.next + 1 })

let lift def st = { st with lifted = def :: st.lifted }

(* [in_scope st body] is the body of a new function: the statements [body]
   emits, preceded by the definitions lifted out of them. *)
let in_scope st body =
  let st', stmts = body { st with lifted = [] } in
  ({ st' with lifted = st.lifted }, List.rev st'.lifted @ stmts)

let variable ctx x =
  match Names.variable ctx.names x with
  | Some name -> name
  | None -> (
      match
        List.find_opt
          (fun p -> Primitives.primitive_name p = Ast.Variable.string_of x)
          Primitives.primitives
      with
      | Some p -> primitive_function p
      | None -> invalid_arg ("unbound variable " ^ Ast.Variable.string_of x))

let bind_local ctx p =
  if ctx.in_lifted then
    { ctx with local = VariableSet.union ctx.local (Reach.pattern_variables p) }
  else ctx

(* The variables of [free] a lifted definition takes as parameters. *)
let captured ctx free = VariableSet.elements (VariableSet.inter free ctx.local)

let rec strip_pattern (p : _ Ast.pattern) =
  match p.it with Ast.PAnnotated (p, _) -> strip_pattern p | _ -> p

let rec strip_expression (e : _ Ast.expression) =
  match e.it with Ast.Annotated (e, _) -> strip_expression e | _ -> e

let assign name e = if name = e then [] else [ Line (name ^ " = " ^ e) ]

(* Patterns: a match is a chain of tests of the subject, at the paths of the
   subterms the pattern constrains, followed by the bindings of its variables.
   A test of a subterm follows the tests that ensure the subterm exists. *)

let succ_path path k = Printf.sprintf "(%s - %s)" path (Z.to_string k)

let rec tests ctx path (p : _ Ast.pattern) acc =
  match p.it with
  | Ast.PVar _ | Ast.PNonbinding -> acc
  | Ast.PAnnotated (p, _) | Ast.PAs (p, _) -> tests ctx path p acc
  | Ast.PTuple ps ->
      List.fold_left
        (fun acc (i, p) -> tests ctx (Printf.sprintf "%s[%d]" path i) p acc)
        acc
        (List.mapi (fun i p -> (i, p)) ps)
  | Ast.PVariant (l, arg) ->
      let acc =
        Printf.sprintf "%s.tag == %d" path (Names.label_rank ctx.labels l)
        :: acc
      in
      Option.fold ~none:acc ~some:(fun p -> tests ctx (path ^ ".arg") p acc) arg
  | Ast.PConst (Const.Boolean true) -> path :: acc
  | Ast.PConst (Const.Boolean false) -> ("not " ^ path) :: acc
  | Ast.PConst (Const.Float f) ->
      Printf.sprintf "float_eq(%s, %s)" path (python_float f) :: acc
  | Ast.PConst c -> Printf.sprintf "%s == %s" path (constant c) :: acc
  | Ast.PSucc (p, k) ->
      tests ctx (succ_path path k) p
        (Printf.sprintf "%s >= %s" path (Z.to_string k) :: acc)

let rec bindings ctx path (p : _ Ast.pattern) acc =
  match p.it with
  | Ast.PVar x -> assign (variable ctx x) path @ acc
  | Ast.PAs (p, x) -> bindings ctx path p (assign (variable ctx x) path @ acc)
  | Ast.PAnnotated (p, _) -> bindings ctx path p acc
  | Ast.PTuple ps ->
      List.fold_left
        (fun acc (i, p) -> bindings ctx (Printf.sprintf "%s[%d]" path i) p acc)
        acc
        (List.mapi (fun i p -> (i, p)) ps)
  | Ast.PVariant (_, Some p) -> bindings ctx (path ^ ".arg") p acc
  | Ast.PSucc (p, k) -> bindings ctx (succ_path path k) p acc
  | Ast.PVariant (_, None) | Ast.PConst _ | Ast.PNonbinding -> acc

let pattern_tests ctx path p = List.rev (tests ctx path p [])
let pattern_bindings ctx path p = List.rev (bindings ctx path p [])

(* The parameter of a function of parameter pattern [p], and the bindings of
   the variables of [p]. *)
let parameter ctx st p =
  match (strip_pattern p).it with
  | Ast.PVar x -> (st, variable ctx x, [])
  | _ ->
      let a, st = fresh "a" st in
      (st, a, pattern_bindings ctx a p)

(* Values: each expression is a Python expression, preceded by the
   definitions of the functions and handlers in it. *)
let rec expression ctx st (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> (st, [], variable ctx x)
  | Ast.Const c -> (st, [], constant c)
  | Ast.Annotated (e, _) -> expression ctx st e
  | Ast.Tuple es ->
      let st, defs, es = expressions ctx st es in
      (st, defs, tuple es)
  | Ast.Variant (l, arg) ->
      let st, defs, arg =
        match arg with
        | None -> (st, [], "None")
        | Some e -> expression ctx st e
      in
      ( st,
        defs,
        Printf.sprintf "Con(%d, %s)" (Names.label_rank ctx.labels l) arg )
  | Ast.Lambda abs | Ast.PureLambda abs ->
      let name, st = fresh "f" st in
      let st, def = function_definition ctx st name abs in
      (st, [ def ], name)
  | Ast.RecLambda (f, _, abs) ->
      let name = variable ctx f in
      let st, def = function_definition ctx st name abs in
      (st, [ def ], name)
  | Ast.Handler (ret, ops) ->
      let name, st = fresh "h" st in
      let st, ret_def = function_definition ctx st name ret in
      let st, defs, clauses =
        List.fold_left
          (fun (st, defs, clauses) (op, abs) ->
            let clause, st = fresh "h" st in
            let st, def = function_definition ctx st clause abs in
            ( st,
              def :: defs,
              (python_string (Ast.OpName.string_of op) ^ ": " ^ clause)
              :: clauses ))
          (st, [ ret_def ], [])
          (Ast.OpNameMap.bindings ops)
      in
      ( st,
        List.rev defs,
        Printf.sprintf "Handler(%s, {%s})" name
          (String.concat ", " (List.rev clauses)) )

and expressions ctx st es =
  let st, defs, es =
    List.fold_left
      (fun (st, defs, es) e ->
        let st, defs', e = expression ctx st e in
        (st, defs @ defs', e :: es))
      (st, [], []) es
  in
  (st, defs, List.rev es)

(* A function, its body a new scope. *)
and function_definition ctx st name (p, c) =
  let st, param, binds = parameter ctx st p in
  let ctx = { ctx with local = VariableSet.empty; in_lifted = false } in
  let st, body = in_scope st (fun st -> computation ctx st c) in
  (st, Block (Printf.sprintf "def %s(%s):" name param, binds @ body))

(* Computations: each computation is a sequence of statements that returns its
   effect tree. *)
and computation ctx st (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e ->
      let st, defs, e = expression ctx st e in
      (st, defs @ [ Line (Printf.sprintf "return Ret(%s)" e) ])
  | Ast.Apply _ ->
      let st, defs, node = node ctx st c in
      (st, defs @ [ Line ("return " ^ node) ])
  | Ast.Do ({ it = Ast.Return e; _ }, (p, c))
  | Ast.Box (_, e, (p, c))
  | Ast.Unbox (e, (p, c)) ->
      let st, binds = let_binding ctx st p e in
      let st, rest = computation (bind_local ctx p) st c in
      (st, binds @ rest)
  | Ast.Do (c1, abs) ->
      let st, defs, node = node ctx st c1 in
      let st, k = continuation ctx st abs in
      (st, defs @ [ Line (Printf.sprintf "return Bind(%s, %s)" node k) ])
  | Ast.Match (e, cases) -> match_cases ctx st e cases
  | Ast.Delay (q, c) ->
      let st, defs, node = node ctx st c in
      ( st,
        defs
        @ [
            Line
              (Printf.sprintf "return Delay(Fraction(%s, %s), %s)"
                 (Z.to_string (Grades.Rational.num q))
                 (Z.to_string (Grades.Rational.den q))
                 node);
          ] )
  | Ast.Perform (op, e, abs) ->
      let st, defs, e = expression ctx st e in
      let st, k = continuation ctx st abs in
      ( st,
        defs
        @ [
            Line
              (Printf.sprintf "return Perform(%s, %s, %s)"
                 (python_string (Ast.OpName.string_of op))
                 e k);
          ] )
  | Ast.Handle (c, h) ->
      let st, defs, node = node ctx st c in
      let st, defs', h = expression ctx st h in
      ( st,
        defs @ defs' @ [ Line (Printf.sprintf "return Handle(%s, %s)" node h) ]
      )

(* The binding of the value of [e] to the pattern [p]. A function bound to a
   variable is defined under the variable's name. *)
and let_binding ctx st p e =
  match ((strip_pattern p).it, (strip_expression e).it) with
  | Ast.PVar x, (Ast.Lambda abs | Ast.PureLambda abs) ->
      let st, def = function_definition ctx st (variable ctx x) abs in
      (st, [ def ])
  | Ast.PVar x, Ast.RecLambda (f, _, abs) ->
      let st, def = function_definition ctx st (variable ctx f) abs in
      (st, def :: assign (variable ctx x) (variable ctx f))
  | Ast.PVar x, _ ->
      let st, defs, e = expression ctx st e in
      (st, defs @ assign (variable ctx x) e)
  | _ ->
      let st, defs, path = subject ctx st e in
      (st, defs @ pattern_bindings ctx path p)

(* The subject [e] of a match, named unless it is a variable. *)
and subject ctx st e =
  let st, defs, e' = expression ctx st e in
  match (strip_expression e).it with
  | Ast.Var _ -> (st, defs, e')
  | _ ->
      let s, st = fresh "s" st in
      (st, defs @ [ Line (s ^ " = " ^ e') ], s)

and match_cases ctx st e cases =
  let st, defs, path = subject ctx st e in
  let st, branches =
    List.fold_left
      (fun (st, branches) (p, c) ->
        let st, body = computation (bind_local ctx p) st c in
        ( st,
          (pattern_tests ctx path p, pattern_bindings ctx path p @ body)
          :: branches ))
      (st, []) cases
  in
  let rec chain first = function
    | [] -> [ Line "return match_failure()" ]
    | ([], body) :: _ -> if first then body else [ Block ("else:", body) ]
    | (tests, body) :: branches ->
        Block
          ( Printf.sprintf "%s %s:"
              (if first then "if" else "elif")
              (String.concat " and " tests),
            body )
        :: chain false branches
  in
  (st, defs @ chain true (List.rev branches))

(* The effect tree of [c] as a Python expression, preceded by the definitions
   of the functions and handlers in it: a [return] and an application
   directly, any other computation by a call of a lifted definition. *)
and node ctx st (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e ->
      let st, defs, e = expression ctx st e in
      (st, defs, Printf.sprintf "Ret(%s)" e)
  | Ast.Apply (e1, e2) ->
      let st, defs, es = expressions ctx st [ e1; e2 ] in
      (st, defs, Printf.sprintf "App(%s)" (String.concat ", " es))
  | _ ->
      let name, st = fresh "c" st in
      let params = captured ctx (Reach.free_in_computation c) in
      let ctx' =
        { ctx with local = VariableSet.of_list params; in_lifted = true }
      in
      let st, body = computation ctx' st c in
      let args = String.concat ", " (List.map (variable ctx) params) in
      ( lift (Block (Printf.sprintf "def %s(%s):" name args, body)) st,
        [],
        Printf.sprintf "%s(%s)" name args )

(* The continuation [(p, c)] as a Python function, lifted. *)
and continuation ctx st (p, c) =
  let name, st = fresh "k" st in
  let params = captured ctx (Reach.free_in_abstraction (p, c)) in
  let st, param, binds = parameter ctx st p in
  let ctx' =
    {
      ctx with
      local =
        VariableSet.union
          (VariableSet.of_list params)
          (Reach.pattern_variables p);
      in_lifted = true;
    }
  in
  let st, body = computation ctx' st c in
  let params = List.map (variable ctx) params in
  ( lift
      (Block
         ( Printf.sprintf "def %s(%s):" name
             (String.concat ", " (params @ [ param ])),
           binds @ body ))
      st,
    match params with
    | [] -> name
    | _ -> Printf.sprintf "partial(%s, %s)" name (String.concat ", " params) )

type compiled = { definitions : string; runs : string list }

let command ctx (st, stmts, runs) (cmd : _ Ast.command) =
  match cmd.it with
  | Ast.TyDef _ | Ast.OpSig _ | Ast.OpDefault _ -> (st, stmts, runs)
  | Ast.TopLet (x, e) ->
      let st, binds = let_binding ctx st (Ast.located cmd.at (Ast.PVar x)) e in
      (st, List.rev_append binds stmts, runs)
  | Ast.TopDo c ->
      let name, st = fresh "run" st in
      let st, body = in_scope st (fun st -> computation ctx st c) in
      (st, Block (Printf.sprintf "def %s():" name, body) :: stmts, name :: runs)

let compile commands =
  let commands = Reach.reachable commands in
  let labels = Names.labels_of_commands commands in
  let ctx =
    {
      names = Names.of_commands commands;
      labels;
      local = VariableSet.empty;
      in_lifted = false;
    }
  in
  let _, stmts, runs =
    List.fold_left (command ctx) ({ next = 0; lifted = [] }, [], []) commands
  in
  let declaration =
    Printf.sprintf "declare_labels(%s, %d, %d)"
      (tuple (List.map python_string (Names.label_names labels)))
      (Names.label_rank labels Ast.nil_label)
      (Names.label_rank labels Ast.cons_label)
  in
  {
    definitions = render (Line declaration :: List.rev stmts);
    runs = List.rev runs;
  }

let plain_program commands =
  let { definitions; runs } = compile commands in
  String.concat "\n"
    [
      runtime;
      "# The compiled program.";
      "";
      definitions;
      "if __name__ == \"__main__\":";
      "    run_plain(" ^ tuple runs ^ ")";
      "";
    ]
