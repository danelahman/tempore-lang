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
  | FP_nan -> "tempore_math.nan"
  | FP_infinite -> if f > 0. then "tempore_math.inf" else "-tempore_math.inf"
  | FP_normal | FP_subnormal | FP_zero ->
      let s = Printf.sprintf "%.17g" f in
      if String.exists (fun c -> c = '.' || c = 'e') s then s else s ^ ".0"

let constant = function
  | Const.Nat n -> Z.to_string n
  | Const.Int n -> Printf.sprintf "tempore_Int(%s)" (Z.to_string n)
  | Const.String s -> python_string s
  | Const.Boolean b -> if b then "True" else "False"
  | Const.Float f -> python_float f

(* An exact rational as a Python [Fraction]. *)
let fraction q =
  Printf.sprintf "tempore_Fraction(%s, %s)"
    (Z.to_string (Grades.Rational.num q))
    (Z.to_string (Grades.Rational.den q))

let tuple = function
  | [] -> "()"
  | [ e ] -> "(" ^ e ^ ",)"
  | es -> "(" ^ String.concat ", " es ^ ")"

(* The runtime function of each primitive. *)
let primitive_function = function
  | Primitives.CompareEq -> "tempore_prim_compare_eq"
  | Primitives.CompareLt -> "tempore_prim_compare_lt"
  | Primitives.CompareGt -> "tempore_prim_compare_gt"
  | Primitives.CompareLe -> "tempore_prim_compare_le"
  | Primitives.CompareGe -> "tempore_prim_compare_ge"
  | Primitives.CompareNe -> "tempore_prim_compare_ne"
  | Primitives.NatAdd -> "tempore_prim_nat_add"
  | Primitives.NatMul -> "tempore_prim_nat_mul"
  | Primitives.NatSub -> "tempore_prim_nat_sub"
  | Primitives.NatDiv -> "tempore_prim_nat_div"
  | Primitives.NatMod -> "tempore_prim_nat_mod"
  | Primitives.FloatAdd -> "tempore_prim_float_add"
  | Primitives.FloatMul -> "tempore_prim_float_mul"
  | Primitives.FloatSub -> "tempore_prim_float_sub"
  | Primitives.FloatDiv -> "tempore_prim_float_div"
  | Primitives.FloatPow -> "tempore_prim_float_pow"
  | Primitives.FloatNeg -> "tempore_prim_float_neg"
  | Primitives.FloatOfNat -> "tempore_prim_float_of_nat"
  | Primitives.NatOfFloat -> "tempore_prim_nat_of_float"
  | Primitives.FloatSqrt -> "tempore_prim_float_sqrt"
  | Primitives.FloatAtan -> "tempore_prim_float_atan"
  | Primitives.FloatAtan2 -> "tempore_prim_float_atan2"
  | Primitives.IntAdd -> "tempore_prim_int_add"
  | Primitives.IntMul -> "tempore_prim_int_mul"
  | Primitives.IntSub -> "tempore_prim_int_sub"
  | Primitives.IntDiv -> "tempore_prim_int_div"
  | Primitives.IntMod -> "tempore_prim_int_mod"
  | Primitives.IntNeg -> "tempore_prim_int_neg"
  | Primitives.IntOfNat -> "tempore_prim_int_of_nat"
  | Primitives.NatOfInt -> "tempore_prim_nat_of_int"
  | Primitives.FloatOfInt -> "tempore_prim_float_of_int"
  | Primitives.IntOfFloat -> "tempore_prim_int_of_float"
  | Primitives.ToString -> "tempore_prim_to_string"

(* The emission context. Continuations and the computations bound by [do] are
   lifted out of the function they occur in to definitions at the level of
   its body, so that the nesting of the Python source follows the nesting of
   functions and cases rather than the length of sequences. A lifted
   definition takes as parameters the variables it uses that are bound in
   lifted definitions, [local]; the others it reads from the enclosing
   function. [in_lifted] is whether the code emitted is in a lifted
   definition, and [top] whether it is at the top level of the module, where
   the names of the definitions it introduces bear the prefix [tempore_]. *)
type context = {
  names : Names.t;
  labels : Names.labels;
  local : VariableSet.t;
  in_lifted : bool;
  top : bool;
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
      match Primitives.of_name (Ast.Variable.string_of x) with
      | Some p -> primitive_function p
      | None -> invalid_arg ("unbound variable " ^ Ast.Variable.string_of x))

(* The prefix of a fresh name of a definition: [prefix] inside a function,
   with [tempore_] before it at the top level of the module. *)
let definition_prefix ctx prefix =
  if ctx.top then "tempore_" ^ prefix else prefix

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
      Printf.sprintf "tempore_float_eq(%s, %s)" path (python_float f) :: acc
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

(* The greatest nesting of parentheses of the Python expression of a tuple or a
   constructor value; the components of a value nested deeper are bound to
   temporaries. CPython accepts at most 200 nested parentheses. *)
let max_nesting = 40

(* Values: each expression is a Python expression, preceded by the
   definitions of the functions, handlers and temporaries in it. *)
let rec expression ctx st e =
  let st, defs, e, _ = nested_expression ctx st e in
  (st, defs, e)

(* The Python expression of [e] and the nesting of the parentheses of its
   tuples and constructors. *)
and nested_expression ctx st (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> (st, [], variable ctx x, 0)
  | Ast.Const c -> (st, [], constant c, 0)
  | Ast.Annotated (e, _) -> nested_expression ctx st e
  | Ast.Tuple es ->
      let st, defs, es, nesting = components ctx st es in
      (st, defs, tuple es, nesting + 1)
  | Ast.Variant (l, arg) ->
      let st, defs, arg, nesting =
        match arg with
        | None -> (st, [], "None", 0)
        | Some e ->
            let st, defs, args, nesting = components ctx st [ e ] in
            (st, defs, String.concat "" args, nesting)
      in
      ( st,
        defs,
        Printf.sprintf "tempore_Con(%d, %s)" (Names.label_rank ctx.labels l) arg,
        nesting + 1 )
  | Ast.Lambda abs | Ast.PureLambda abs ->
      let name, st = fresh (definition_prefix ctx "f") st in
      let st, def = function_definition ctx st name abs in
      (st, [ def ], name, 0)
  | Ast.RecLambda (f, _, abs) ->
      let name = variable ctx f in
      let st, def = function_definition ctx st name abs in
      (st, [ def ], name, 0)
  | Ast.Handler (ret, ops) ->
      let name, st = fresh (definition_prefix ctx "h") st in
      let st, ret_def = function_definition ctx st name ret in
      let st, defs, clauses =
        List.fold_left
          (fun (st, defs, clauses) (op, abs) ->
            let clause, st = fresh (definition_prefix ctx "h") st in
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
        Printf.sprintf "tempore_Handler(%s, {%s})" name
          (String.concat ", " (List.rev clauses)),
        0 )

(* The components [es] of a value, each nested at most [max_nesting] deep or
   else bound to a temporary, and the greatest of their nestings. *)
and components ctx st es =
  let st, defs, es, nesting =
    List.fold_left
      (fun (st, defs, es, nesting) e ->
        let st, defs', e, nesting' = nested_expression ctx st e in
        if nesting' > max_nesting then
          let v, st = fresh (definition_prefix ctx "v") st in
          (st, defs @ defs' @ [ Line (v ^ " = " ^ e) ], v :: es, nesting)
        else (st, defs @ defs', e :: es, max nesting nesting'))
      (st, [], [], 0) es
  in
  (st, defs, List.rev es, nesting)

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
  let ctx =
    { ctx with local = VariableSet.empty; in_lifted = false; top = false }
  in
  let st, body = in_scope st (fun st -> computation ctx st c) in
  (st, Block (Printf.sprintf "def %s(%s):" name param, binds @ body))

(* Computations: each computation is a sequence of statements that returns its
   effect tree. *)
and computation ctx st (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e ->
      let st, defs, e = expression ctx st e in
      (st, defs @ [ Line (Printf.sprintf "return tempore_Ret(%s)" e) ])
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
      (st, defs @ [ Line (Printf.sprintf "return tempore_Bind(%s, %s)" node k) ])
  | Ast.Match (e, cases) -> match_cases ctx st e cases
  | Ast.Delay (q, c) ->
      let st, defs, node = node ctx st c in
      ( st,
        defs
        @ [
            Line
              (Printf.sprintf "return tempore_Delay(%s, %s)" (fraction q) node);
          ] )
  | Ast.Perform (op, e, abs) ->
      let st, defs, e = expression ctx st e in
      let st, k = continuation ctx st abs in
      ( st,
        defs
        @ [
            Line
              (Printf.sprintf "return tempore_Perform(%s, %s, %s)"
                 (python_string (Ast.OpName.string_of op))
                 e k);
          ] )
  | Ast.Handle (c, h) ->
      let st, defs, node = node ctx st c in
      let st, defs', h = expression ctx st h in
      ( st,
        defs @ defs'
        @ [ Line (Printf.sprintf "return tempore_Handle(%s, %s)" node h) ] )

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
    | [] -> [ Line "return tempore_match_failure()" ]
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
      (st, defs, Printf.sprintf "tempore_Ret(%s)" e)
  | Ast.Apply (e1, e2) ->
      let st, defs, es = expressions ctx st [ e1; e2 ] in
      (st, defs, Printf.sprintf "tempore_App(%s)" (String.concat ", " es))
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
    | _ ->
        Printf.sprintf "tempore_partial(%s, %s)" name
          (String.concat ", " params) )

(* The bounds of the running time of an operation as a runtime [Bounds]
   value, an infinite upper end as [None]. *)
let bounds ((lo, hi) : Grades.Rational.t Grades.Grade.bound * _) =
  let value_end = function
    | Grades.Grade.Closed q -> (fraction q, "True")
    | Grades.Grade.Open q -> (fraction q, "False")
    | Grades.Grade.Unbounded -> ("None", "False")
  in
  let lo, lo_closed = value_end lo and hi, hi_closed = value_end hi in
  Printf.sprintf "tempore_Bounds(%s, %s, %s, %s)" lo lo_closed hi hi_closed

(* Whether the bounds [b] constrain the running time: they are not [\[0, ∞)]. *)
let constraining = function
  | Grades.Grade.Closed q, Grades.Grade.Unbounded -> Grades.Rational.sign q <> 0
  | _ -> true

let dictionary entries =
  "{"
  ^ String.concat ", "
      (List.map (fun (key, value) -> python_string key ^ ": " ^ value) entries)
  ^ "}"

(* The emission of the commands: the statements, the last first, the [tempore_Run]
   values of the [run] commands, the last first, and the default
   implementations declared so far. *)
type commands = {
  stmts : stmt list;
  runs : string list;
  defaults : string Ast.OpNameMap.t;
}

let command ctx (st, acc) (cmd : _ Ast.command) =
  match cmd.it with
  | Ast.TyDef _ | Ast.OpSig _ -> (st, acc)
  | Ast.TopLet (x, e) ->
      let st, binds = let_binding ctx st (Ast.located cmd.at (Ast.PVar x)) e in
      (st, { acc with stmts = List.rev_append binds acc.stmts })
  | Ast.OpDefault (op, abs) ->
      let name, st = fresh "tempore_d" st in
      let st, def = function_definition ctx st name abs in
      ( st,
        {
          acc with
          stmts = def :: acc.stmts;
          defaults = Ast.OpNameMap.add op name acc.defaults;
        } )
  | Ast.TopDo c ->
      let name, st = fresh "tempore_run" st in
      let st, body =
        in_scope st (fun st -> computation { ctx with top = false } st c)
      in
      let defaults =
        List.map
          (fun (op, name) -> (Ast.OpName.string_of op, name))
          (Ast.OpNameMap.bindings acc.defaults)
      in
      ( st,
        {
          acc with
          stmts = Block (Printf.sprintf "def %s():" name, body) :: acc.stmts;
          runs =
            Printf.sprintf "tempore_Run(%s, %s)" name (dictionary defaults)
            :: acc.runs;
        } )

let compile ~operations commands =
  let commands = Reach.reachable commands in
  let labels = Names.labels_of_commands commands in
  let ctx =
    {
      names = Names.of_commands commands;
      labels;
      local = VariableSet.empty;
      in_lifted = false;
      top = true;
    }
  in
  let _, { stmts; runs; _ } =
    List.fold_left (command ctx)
      ( { next = 0; lifted = [] },
        { stmts = []; runs = []; defaults = Ast.OpNameMap.empty } )
      commands
  in
  let labels =
    Printf.sprintf "tempore_declare_labels(%s, %d, %d)"
      (tuple (List.map python_string (Names.label_names labels)))
      (Names.label_rank labels Ast.nil_label)
      (Names.label_rank labels Ast.cons_label)
  and operations =
    Printf.sprintf "tempore_declare_operations(%s)"
      (dictionary
         (List.filter_map
            (fun (op, b) ->
              match b with
              | Some b when constraining b ->
                  Some (Ast.OpName.string_of op, bounds b)
              | _ -> None)
            operations))
  in
  render
    ((Line labels :: Line operations :: List.rev stmts)
    @ [
        Block
          ("tempore_RUNS = (", List.rev_map (fun run -> Line (run ^ ",")) runs);
        Line ")";
      ])

let plain_program ~operations commands =
  String.concat "\n"
    [
      runtime;
      "# The compiled program.";
      "";
      compile ~operations commands;
      "if __name__ == \"__main__\":";
      "    tempore_run_plain(tempore_RUNS)";
      "";
    ]
