module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module F = ArduinoFragment
module Names = ArduinoNames

let runtime = Tempore_arduino_h.contents
let runtime_file = "tempore_arduino.h"
let header_file = "tempore_program.h"
let source_file = "tempore_program.cpp"
let host_main_file = "tempore_host_main.cpp"

module TyMap = Map.Make (struct
  type t = F.ty

  let compare = F.compare_ty
end)

(* An instance of a definition: the definition and the types of its
   quantified type variables. *)
module Key = struct
  type t = Ast.variable * F.ty list

  let compare (x1, tys1) (x2, tys2) =
    match Ast.Variable.compare x1 x2 with
    | 0 -> List.compare F.compare_ty tys1 tys2
    | c -> c
end

module KeyMap = Map.Make (Key)
module LabelMap = Map.Make (Ast.Label)
module VariableSet = Set.Make (Ast.Variable)

(* C++ source: lines, blocks of a header line, an indented body and a closing
   line, and chains of [if], [else if] and [else]. *)
type stmt =
  | Line of string
  | Block of string * stmt list * string
  | If of (string option * stmt list) list

let block header body = Block (header, body, "}")

let rec lines indent = function
  | Line s -> [ indent ^ s ]
  | Block (header, body, closing) ->
      ((indent ^ header ^ " {") :: List.concat_map (lines (indent ^ "  ")) body)
      @ [ indent ^ closing ]
  | If branches ->
      List.concat
        (List.mapi
           (fun i (condition, body) ->
             let opening =
               match (i, condition) with
               | 0, Some c -> "if (" ^ c ^ ") {"
               | _, Some c -> "} else if (" ^ c ^ ") {"
               | _, None -> "} else {"
             in
             (indent ^ opening) :: List.concat_map (lines (indent ^ "  ")) body)
           branches)
      @ [ indent ^ "}" ]

let render stmts = String.concat "\n" (List.concat_map (lines "") stmts) ^ "\n"

(* Types. *)

let rec value_types acc (v : F.value) =
  let acc = v.ty :: acc in
  match v.value with
  | F.Local _ | F.Constant _ | F.Global _ -> acc
  | F.Tuple_value vs -> List.fold_left value_types acc vs
  | F.Construct (_, arg) -> Option.fold ~none:acc ~some:(value_types acc) arg

let rec pattern_types acc (p : F.pattern) =
  let acc = p.pattern_ty :: acc in
  match p.pattern with
  | F.PVar _ | F.PConstant _ | F.PAny -> acc
  | F.PAs (p, _) | F.PSucc (p, _) | F.PConstruct (_, Some p) ->
      pattern_types acc p
  | F.PConstruct (_, None) -> acc
  | F.PTuple ps -> List.fold_left pattern_types acc ps

let rec computation_types acc (c : F.computation) =
  let acc = c.result :: acc in
  match c.computation with
  | F.Return v | F.Perform (_, v) -> value_types acc v
  | F.Bind (p, c1, c2) ->
      computation_types (computation_types (pattern_types acc p) c1) c2
  | F.Match (v, cases) ->
      List.fold_left
        (fun acc (p, c) -> computation_types (pattern_types acc p) c)
        (value_types acc v) cases
  | F.Call (_, vs) -> List.fold_left value_types acc vs
  | F.Delay (_, c) -> computation_types acc c
  | F.Handle (u, c) ->
      let acc = List.fold_left value_types acc u.arguments in
      let acc =
        match u.source with
        | F.Defined _ -> acc
        | F.Inline (_, h) -> handler_types acc ~return:true h
      in
      computation_types acc c

(* The types of the parameters and the operation cases of [h], and of its
   return case if [return]. *)
and handler_types acc ~return (h : F.handler) =
  let acc = List.fold_left pattern_types acc h.handler_parameters in
  let acc =
    List.fold_left
      (fun acc (oc : F.operation_case) ->
        computation_types (pattern_types acc oc.case_parameter) oc.case_body)
      acc h.operation_cases
  in
  if return then
    let p, c = h.return_case in
    computation_types (pattern_types acc p) c
  else acc

let body_types acc = function
  | F.Function_body { parameters; body; _ } ->
      computation_types (List.fold_left pattern_types acc parameters) body
  | F.Constant_body v -> value_types acc v
  | F.Handler_body _ -> acc

(* Instances. *)

(* The body of [d] at the types [instance] of its quantified variables, its
   other type variables the unit type. *)
let ground_body (d : F.definition) instance =
  let assoc = List.combine d.quantified instance in
  F.map_body
    (F.substitute (fun i ->
         Some (Option.value (List.assoc_opt i assoc) ~default:(F.Tuple []))))
    d.definition_body

let ground_computation =
  F.map_computation (F.substitute (fun _ -> Some (F.Tuple [])))

(* Handlers. A handler at a [handle] is named by two keys: its definition,
   or the variable of a handler written in a definition, with the types of
   its parameters and its operation cases, which names its cases, and with
   the types of its return case too, which names its return case; a handler
   at types that differ only in its return case thus has the same cases. A
   context is the handlers around a computation, the innermost first. An
   operation performed in a context calls the case of the innermost handler
   of the operation, which runs in the context of the handlers outside that
   one, or the external function of the operation if no handler of the
   context handles it. *)

module OpNameSet = Ast.OpNameSet

let handles (h : F.handler) op =
  List.exists
    (fun (oc : F.operation_case) -> Ast.OpName.equal oc.case_operation op)
    h.operation_cases

let case_of (h : F.handler) op =
  List.find
    (fun (oc : F.operation_case) -> Ast.OpName.equal oc.case_operation op)
    h.operation_cases

(* Whether the return case of [h] returns its input. *)
let returns_input (h : F.handler) =
  match h.return_case with
  | ( { pattern = F.PVar x; _ },
      { computation = F.Return { value = F.Local y; _ }; _ } ) ->
      Ast.Variable.equal x y
  | _ -> false

(* The operations that a computation may perform outside itself, from those
   [escaping] that each top-level function may perform outside itself, and
   the [definitions] of the program. *)
type operations = {
  escaping : OpNameSet.t Ast.VariableMap.t;
  definitions : F.definition Ast.VariableMap.t;
}

let handler_of_source ops = function
  | F.Defined g -> (
      match
        (Ast.VariableMap.find g.variable ops.definitions).definition_body
      with
      | F.Handler_body h -> h
      | F.Function_body _ | F.Constant_body _ -> invalid_arg "not a handler")
  | F.Inline (_, h) -> h

let rec computation_operations ops (c : F.computation) =
  match c.computation with
  | F.Return _ | F.Call ((F.Self | F.Primitive _), _) -> OpNameSet.empty
  | F.Perform (op, _) -> OpNameSet.singleton op
  | F.Call (F.Function g, _) ->
      Option.value
        (Ast.VariableMap.find_opt g.variable ops.escaping)
        ~default:OpNameSet.empty
  | F.Bind (_, c1, c2) ->
      OpNameSet.union
        (computation_operations ops c1)
        (computation_operations ops c2)
  | F.Match (_, cases) ->
      List.fold_left
        (fun acc (_, c) -> OpNameSet.union acc (computation_operations ops c))
        OpNameSet.empty cases
  | F.Delay (_, c) -> computation_operations ops c
  | F.Handle (u, c) ->
      handled_operations ops
        (handler_of_source ops u.source)
        (computation_operations ops c)

(* The operations performed outside a [handle] of [h] whose body performs
   [performed]: those that [h] does not handle, and those of its return case
   and of its cases of the operations of [performed]. *)
and handled_operations ops h performed =
  OpNameSet.fold
    (fun op acc ->
      if handles h op then
        OpNameSet.union acc
          (computation_operations ops (case_of h op).case_body)
      else OpNameSet.add op acc)
    performed
    (computation_operations ops (snd h.return_case))

let operations (definitions : F.definition list) =
  let map =
    List.fold_left
      (fun map (d : F.definition) -> Ast.VariableMap.add d.variable d map)
      Ast.VariableMap.empty definitions
  in
  List.fold_left
    (fun ops (d : F.definition) ->
      match d.definition_body with
      | F.Function_body { body; _ } ->
          {
            ops with
            escaping =
              Ast.VariableMap.add d.variable
                (computation_operations ops body)
                ops.escaping;
          }
      | F.Constant_body _ | F.Handler_body _ -> ops)
    { escaping = Ast.VariableMap.empty; definitions = map }
    definitions

(* A handler of a context, with the C++ expressions of the values of its
   parameters. *)
type frame = {
  frame_key : Key.t;  (** the key of its cases *)
  return_key : Key.t;  (** the key of its return case *)
  code : F.handler;
  captured : string list;
}

(* The handlers of [frames] that a computation performing [performed] uses,
   in order: the innermost handler of each operation, and in turn the
   handlers of the operations of its cases, outside it. The other handlers do
   not affect the computation. *)
let rec relevant ops performed = function
  | [] -> []
  | frame :: rest ->
      let hit = OpNameSet.filter (handles frame.code) performed in
      if OpNameSet.is_empty hit then relevant ops performed rest
      else
        let outside =
          OpNameSet.fold
            (fun op acc ->
              OpNameSet.union acc
                (computation_operations ops (case_of frame.code op).case_body))
            hit
            (OpNameSet.diff performed
               (OpNameSet.of_list
                  (List.map
                     (fun (oc : F.operation_case) -> oc.case_operation)
                     frame.code.operation_cases)))
        in
        frame :: relevant ops outside rest

(* A unit of the compilation, a C++ function or constant: an instance of a
   definition in a context, the case of an operation of a handler and its
   return case, each in the context outside the handler. A context is given
   by the keys of its relevant handlers. *)
type unit_key =
  | Instance of Key.t * Key.t list
  | Case of Key.t * Ast.operation * Key.t list
  | Return_case of Key.t * Key.t list

module UnitKey = struct
  type t = unit_key

  let rank = function Instance _ -> 0 | Case _ -> 1 | Return_case _ -> 2
  let keys = List.compare Key.compare

  let compare u1 u2 =
    match (u1, u2) with
    | Instance (k1, c1), Instance (k2, c2) -> (
        match Key.compare k1 k2 with 0 -> keys c1 c2 | c -> c)
    | Case (k1, op1, c1), Case (k2, op2, c2) -> (
        match Key.compare k1 k2 with
        | 0 -> (
            match Ast.OpName.compare op1 op2 with 0 -> keys c1 c2 | c -> c)
        | c -> c)
    | Return_case (k1, c1), Return_case (k2, c2) -> (
        match Key.compare k1 k2 with 0 -> keys c1 c2 | c -> c)
    | _ -> Int.compare (rank u1) (rank u2)
end

module UnitMap = Map.Make (UnitKey)

let frame_keys frames = List.map (fun frame -> frame.frame_key) frames

(* The unit of a call of [g] in [frames], with the relevant handlers. *)
let call_unit ops frames (g : F.global) =
  let performed =
    Option.value
      (Ast.VariableMap.find_opt g.variable ops.escaping)
      ~default:OpNameSet.empty
  in
  let relevant = relevant ops performed frames in
  (Instance ((g.variable, g.instance), frame_keys relevant), relevant)

(* The unit of the case of [op] in [frames], with its handler and the
   relevant handlers outside it, if a handler of [frames] handles [op]. *)
let case_unit ops frames op =
  let rec innermost = function
    | [] -> None
    | frame :: rest when handles frame.code op -> Some (frame, rest)
    | _ :: rest -> innermost rest
  in
  Option.map
    (fun (frame, outside) ->
      let relevant =
        relevant ops
          (computation_operations ops (case_of frame.code op).case_body)
          outside
      in
      (Case (frame.frame_key, op, frame_keys relevant), frame, relevant))
    (innermost frames)

(* The unit of the return case of the handler of [frame] in [frames], with
   the relevant handlers. *)
let return_unit ops frames frame =
  let relevant =
    relevant ops
      (computation_operations ops (snd frame.code.return_case))
      frames
  in
  (Return_case (frame.return_key, frame_keys relevant), relevant)

(* The handler of [u] at a [handle], with the expressions [captured] of its
   arguments. *)
let handle_frame definitions (u : F.handler_use) captured =
  let x, code =
    match u.source with
    | F.Defined g -> (
        match
          ground_body (Ast.VariableMap.find g.variable definitions) g.instance
        with
        | F.Handler_body code -> (g.variable, code)
        | F.Function_body _ | F.Constant_body _ -> invalid_arg "not a handler")
    | F.Inline (x, code) -> (x, code)
  in
  {
    frame_key = (x, List.rev (handler_types [] ~return:false code));
    return_key = (x, List.rev (handler_types [] ~return:true code));
    code;
    captured;
  }

type instance = {
  key : unit_key;
  context : Key.t list;
  body : F.body;  (** at the types of the instance *)
  entry : bool;  (** whether the instance is an entry point *)
}

(* The parameters of the handlers of a context, after the parameters of the
   unit: the [i]-th parameter of the [j]-th handler is [tempore_cj_i]. *)
let context_frames handlers context =
  List.mapi
    (fun j key ->
      let code = KeyMap.find key handlers in
      {
        frame_key = key;
        return_key = key;
        code;
        captured =
          List.mapi
            (fun i _ -> Printf.sprintf "tempore_c%d_%d" j i)
            code.handler_parameters;
      })
    context

(* The units a computation in [frames] uses, in the order of their first use,
   prepended to [acc] in reverse, and the handlers of its [handle]s added to
   [handlers]. The operations it performs outside the handlers of [frames]
   are added to [external_ops]. *)
type uses = {
  used : unit_key list;
  handlers : F.handler KeyMap.t;
  external_ops : OpNameSet.t;
}

let rec value_uses acc (v : F.value) =
  match v.value with
  | F.Local _ | F.Constant _ -> acc
  | F.Global g ->
      { acc with used = Instance ((g.variable, g.instance), []) :: acc.used }
  | F.Tuple_value vs -> List.fold_left value_uses acc vs
  | F.Construct (_, arg) -> Option.fold ~none:acc ~some:(value_uses acc) arg

let rec computation_uses ops frames acc (c : F.computation) =
  let uses = computation_uses ops frames in
  match c.computation with
  | F.Return v -> value_uses acc v
  | F.Perform (op, v) -> (
      let acc = value_uses acc v in
      match case_unit ops frames op with
      | Some (key, _, _) -> { acc with used = key :: acc.used }
      | None -> { acc with external_ops = OpNameSet.add op acc.external_ops })
  | F.Bind (_, c1, c2) -> uses (uses acc c1) c2
  | F.Match (v, cases) ->
      List.fold_left (fun acc (_, c) -> uses acc c) (value_uses acc v) cases
  | F.Call (callee, vs) ->
      let acc =
        match callee with
        | F.Function g ->
            { acc with used = fst (call_unit ops frames g) :: acc.used }
        | F.Self | F.Primitive _ -> acc
      in
      List.fold_left value_uses acc vs
  | F.Delay (_, c) -> uses acc c
  | F.Handle (u, c) ->
      let acc = List.fold_left value_uses acc u.arguments in
      let frame = handle_frame ops.definitions u [] in
      let acc =
        {
          acc with
          handlers =
            KeyMap.add frame.frame_key frame.code
              (KeyMap.add frame.return_key frame.code acc.handlers);
        }
      in
      let acc = computation_uses ops (frame :: frames) acc c in
      if returns_input frame.code then acc
      else { acc with used = fst (return_unit ops frames frame) :: acc.used }

let body_uses ops frames acc = function
  | F.Function_body { body; _ } -> computation_uses ops frames acc body
  | F.Constant_body v -> value_uses acc v
  | F.Handler_body _ -> acc

(* The unit of [key], with the handlers known so far. *)
let instance definitions handlers ~entries key =
  let unit_of_case hk context parameter body =
    let code : F.handler = KeyMap.find hk handlers in
    {
      key;
      context;
      body =
        F.Function_body
          {
            parameters = code.handler_parameters @ [ parameter ];
            body;
            recursive = false;
          };
      entry = false;
    }
  in
  match key with
  | Instance (((x, tys) as k), context) ->
      {
        key;
        context;
        body = ground_body (Ast.VariableMap.find x definitions) tys;
        entry = context = [] && List.mem k entries;
      }
  | Case (hk, op, context) ->
      let oc = case_of (KeyMap.find hk handlers) op in
      unit_of_case hk context oc.case_parameter oc.case_body
  | Return_case (hk, context) ->
      let p, c = (KeyMap.find hk handlers).return_case in
      unit_of_case hk context p c

(* The units of [roots] and of the units they use, each after the units it
   uses, the handlers of their contexts, and the operations performed outside
   all handlers. *)
let instances ops ~entries ~runs roots =
  let rec visit (seen, order, acc) key =
    if UnitMap.mem key seen then (seen, order, acc)
    else
      let inst = instance ops.definitions acc.handlers ~entries key in
      let frames = context_frames acc.handlers inst.context in
      let used = body_uses ops frames { acc with used = [] } inst.body in
      let seen = UnitMap.add key () seen in
      let seen, order, acc =
        List.fold_left visit
          (seen, order, { used with used = [] })
          (List.rev used.used)
      in
      (seen, inst :: order, acc)
  in
  let initial =
    { used = []; handlers = KeyMap.empty; external_ops = OpNameSet.empty }
  in
  let acc =
    List.fold_left (fun acc c -> computation_uses ops [] acc c) initial runs
  in
  let _, order, acc =
    List.fold_left visit
      (UnitMap.empty, [], { acc with used = [] })
      (roots @ List.rev acc.used)
  in
  (List.rev order, acc.handlers, acc.external_ops)

(* The types a struct of type [ty] has members of. *)
let components datatypes ty =
  match ty with
  | F.Tuple tys -> tys
  | F.Data n ->
      List.filter_map snd
        (Ast.TyNameMap.find n datatypes : F.datatype).constructors
  | F.Nat | F.Int | F.Float | F.Bool | F.String | F.Meta _ -> []

let is_struct = function
  | F.Tuple (_ :: _) | F.Data _ -> true
  | F.Tuple [] | F.Nat | F.Int | F.Float | F.Bool | F.String | F.Meta _ -> false

(* The struct types of [tys] and of their members, each after the types of
   its members. *)
let structs datatypes tys =
  let rec visit (seen, order) ty =
    if (not (is_struct ty)) || TyMap.mem ty seen then (seen, order)
    else
      let seen, order =
        List.fold_left visit (seen, order) (components datatypes ty)
      in
      (TyMap.add ty () seen, ty :: order)
  in
  List.rev (snd (List.fold_left visit (TyMap.empty, []) tys))

let rec has_string datatypes ty =
  match ty with
  | F.String -> true
  | _ -> List.exists (has_string datatypes) (components datatypes ty)

(* Names. *)

type names = {
  instance_names : string UnitMap.t;
  locals : string Ast.VariableMap.t;
  types : string TyMap.t;
  tags : string LabelMap.t;
  wrappers : Primitives.primitive UnitMap.t;
      (** the instances whose calls are applications of a primitive *)
}

let rec pattern_binders acc (p : F.pattern) =
  match p.pattern with
  | F.PVar x -> x :: acc
  | F.PAs (p, x) -> pattern_binders (x :: acc) p
  | F.PSucc (p, _) | F.PConstruct (_, Some p) -> pattern_binders acc p
  | F.PTuple ps -> List.fold_left pattern_binders acc ps
  | F.PConstruct (_, None) | F.PConstant _ | F.PAny -> acc

let rec computation_binders acc (c : F.computation) =
  match c.computation with
  | F.Return _ | F.Call _ | F.Perform _ -> acc
  | F.Bind (p, c1, c2) ->
      computation_binders (computation_binders (pattern_binders acc p) c1) c2
  | F.Match (_, cases) ->
      List.fold_left
        (fun acc (p, c) -> computation_binders (pattern_binders acc p) c)
        acc cases
  | F.Delay (_, c) | F.Handle (_, c) -> computation_binders acc c

let body_binders acc = function
  | F.Function_body { parameters; body; _ } ->
      computation_binders (List.fold_left pattern_binders acc parameters) body
  | F.Constant_body _ | F.Handler_body _ -> acc

(* A function of the standard library that applies a primitive to its
   parameters, in order: its calls are applications of the primitive. *)
let primitive_wrapper = function
  | F.Function_body
      {
        parameters;
        body = { computation = F.Call (F.Primitive p, [ v ]); _ };
        _;
      } ->
      let variables =
        List.map
          (fun (q : F.pattern) ->
            match q.pattern with F.PVar x -> Some x | _ -> None)
          parameters
      in
      let local (v : F.value) =
        match v.value with F.Local x -> Some x | _ -> None
      in
      let arguments =
        match v.value with
        | F.Tuple_value vs -> List.map local vs
        | _ -> [ local v ]
      in
      if
        List.for_all Option.is_some variables
        && List.equal (Option.equal Ast.Variable.equal) variables arguments
      then Some p
      else None
  | F.Function_body _ | F.Constant_body _ | F.Handler_body _ -> None

(* The name of the C++ function or constant of a unit, before its number. *)
let unit_name = function
  | Instance ((x, _), _) -> Ast.Variable.string_of x
  | Case ((x, _), op, _) ->
      Ast.Variable.string_of x ^ "_" ^ Ast.OpName.string_of op
  | Return_case ((x, _), _) -> Ast.Variable.string_of x ^ "_return"

(* What a name is given to. *)
type named =
  | Named_type of F.ty * string
  | Named_tag of Ast.label
  | Named_instance of unit_key
  | Named_local of Ast.variable

(* The names of the program: each name is numbered by its position among all
   the names, so that distinct names get distinct identifiers. *)
let names datatypes instances runs structs =
  let data =
    List.filter_map
      (function F.Data n as ty -> Some (ty, n) | _ -> None)
      structs
  in
  let tuples = List.filter (function F.Data _ -> false | _ -> true) structs in
  let tags =
    List.concat_map
      (fun (_, n) ->
        List.map
          (fun (l, _) -> Named_tag l)
          (Ast.TyNameMap.find n datatypes : F.datatype).constructors)
      data
  in
  let binders =
    List.fold_left computation_binders
      (List.fold_left (fun acc inst -> body_binders acc inst.body) [] instances)
      runs
  in
  let locals =
    List.fold_left
      (fun acc x ->
        if List.exists (Ast.Variable.equal x) acc then acc else x :: acc)
      [] (List.rev binders)
  in
  let named =
    List.map (fun (ty, n) -> Named_type (ty, Ast.TyName.string_of n)) data
    @ tags
    @ List.map (fun inst -> Named_instance inst.key) instances
    @ List.rev_map (fun x -> Named_local x) locals
  in
  let initial =
    {
      instance_names = UnitMap.empty;
      locals = Ast.VariableMap.empty;
      types =
        List.fold_left
          (fun types (i, ty) ->
            TyMap.add ty (Printf.sprintf "tempore_tuple%d" i) types)
          TyMap.empty
          (List.mapi (fun i ty -> (i, ty)) tuples);
      tags = LabelMap.empty;
      wrappers =
        List.fold_left
          (fun wrappers inst ->
            match primitive_wrapper inst.body with
            | Some p when not inst.entry -> UnitMap.add inst.key p wrappers
            | _ -> wrappers)
          UnitMap.empty instances;
    }
  in
  List.fold_left
    (fun names (i, named) ->
      match named with
      | Named_type (ty, name) ->
          {
            names with
            types = TyMap.add ty (Names.identifier name i) names.types;
          }
      | Named_tag l ->
          {
            names with
            tags =
              LabelMap.add l
                (Names.identifier (Ast.Label.string_of l) i)
                names.tags;
          }
      | Named_instance key ->
          {
            names with
            instance_names =
              UnitMap.add key
                (Names.identifier (unit_name key) i)
                names.instance_names;
          }
      | Named_local x ->
          {
            names with
            locals =
              Ast.VariableMap.add x
                (Names.identifier (Ast.Variable.string_of x) i)
                names.locals;
          })
    initial
    (List.mapi (fun i named -> (i, named)) named)

let ty_name names = function
  | F.Nat -> "uint32_t"
  | F.Int -> "int32_t"
  | F.Float -> "float"
  | F.Bool -> "bool"
  | F.String -> "const char *"
  | F.Tuple [] -> "tempore_unit"
  | ty -> TyMap.find ty names.types

let operation_function op = Names.operation (Ast.OpName.string_of op)

(* Literals. *)

(* The single-precision float nearest to [f]. *)
let single f = Int32.float_of_bits (Int32.bits_of_float f)

(* A float literal of the single-precision float nearest to [f]: the decimal
   of fewest significant digits, at most nine and at least those of its
   integer part, that rounds to it. *)
let float_literal f =
  let f = single f in
  match Float.classify_float f with
  | FP_nan -> "NAN"
  | FP_infinite -> if f > 0. then "INFINITY" else "(-INFINITY)"
  | FP_normal | FP_subnormal | FP_zero ->
      let rec shortest digits =
        let s = Printf.sprintf "%.*g" digits f in
        if digits >= 9 || Float.equal (single (float_of_string s)) f then s
        else shortest (digits + 1)
      in
      let integer_digits =
        String.length (Printf.sprintf "%.0f" (Float.abs f))
      in
      let s = shortest (min 9 integer_digits) in
      let s =
        if String.exists (fun c -> c = '.' || c = 'e') s then s else s ^ ".0"
      in
      if s.[0] = '-' then "(" ^ s ^ "f)" else s ^ "f"

let constant = function
  | Const.Nat n -> Z.to_string n ^ "u"
  | Const.Int n when Z.equal n (Z.of_string "-2147483648") -> "INT32_MIN"
  | Const.Int n -> Printf.sprintf "INT32_C(%s)" (Z.to_string n)
  | Const.Float f -> float_literal f
  | Const.Boolean b -> if b then "true" else "false"
  | Const.String s -> Names.string_literal s

(* Values. *)

let local names x = Ast.VariableMap.find x names.locals
let instance_name names key = UnitMap.find key names.instance_names

let rec expression names (v : F.value) =
  match v.value with
  | F.Local x -> local names x
  | F.Global g -> instance_name names (Instance ((g.variable, g.instance), []))
  | F.Constant c -> constant c
  | F.Tuple_value [] -> "tempore_unit{}"
  | F.Tuple_value vs ->
      ty_name names v.ty ^ "{"
      ^ String.concat ", " (List.map (expression names) vs)
      ^ "}"
  | F.Construct (l, arg) ->
      Printf.sprintf "%s::make_%s(%s)" (ty_name names v.ty)
        (LabelMap.find l names.tags)
        (Option.fold ~none:"" ~some:(expression names) arg)

(* The [i]-th component of the tuple [v]. *)
let component names (v : F.value) i =
  match v.value with
  | F.Tuple_value vs -> expression names (List.nth vs i)
  | _ -> Printf.sprintf "%s.c%d" (expression names v) i

let compare_function = function
  | F.Nat -> "tempore_compare_nat"
  | F.Int -> "tempore_compare_int"
  | F.Float -> "tempore_compare_float"
  | F.Bool -> "tempore_compare_bool"
  | _ -> "tempore_compare"

let primitive names p (v : F.value) =
  let binary format = format (component names v 0) (component names v 1) in
  let comparison operator =
    match v.ty with
    | F.Tuple [ (F.Nat | F.Int | F.Bool); _ ] ->
        Printf.sprintf "(%s %s %s)" (component names v 0) operator
          (component names v 1)
    | F.Tuple [ ty; _ ] ->
        Printf.sprintf "(%s(%s, %s) %s 0)" (compare_function ty)
          (component names v 0) (component names v 1) operator
    | _ -> invalid_arg "comparison of a value that is not a pair"
  in
  match p with
  | Primitives.CompareEq -> comparison "=="
  | Primitives.CompareLt -> comparison "<"
  | Primitives.CompareGt -> comparison ">"
  | Primitives.CompareLe -> comparison "<="
  | Primitives.CompareGe -> comparison ">="
  | Primitives.CompareNe -> comparison "!="
  | Primitives.NatAdd | Primitives.FloatAdd ->
      binary (Printf.sprintf "(%s + %s)")
  | Primitives.NatMul | Primitives.FloatMul ->
      binary (Printf.sprintf "(%s * %s)")
  | Primitives.FloatSub -> binary (Printf.sprintf "(%s - %s)")
  | Primitives.FloatDiv -> binary (Printf.sprintf "(%s / %s)")
  | Primitives.NatSub -> binary (Printf.sprintf "tempore_nat_sub(%s, %s)")
  | Primitives.NatDiv -> binary (Printf.sprintf "tempore_nat_div(%s, %s)")
  | Primitives.NatMod -> binary (Printf.sprintf "tempore_nat_mod(%s, %s)")
  | Primitives.FloatPow -> binary (Printf.sprintf "tempore_float_pow(%s, %s)")
  | Primitives.FloatNeg -> Printf.sprintf "(-%s)" (expression names v)
  | Primitives.FloatOfNat ->
      Printf.sprintf "static_cast<float>(%s)" (expression names v)
  | Primitives.NatOfFloat ->
      Printf.sprintf "tempore_nat_of_float(%s)" (expression names v)
  | Primitives.FloatSqrt -> Printf.sprintf "sqrtf(%s)" (expression names v)
  | Primitives.FloatAtan -> Printf.sprintf "atanf(%s)" (expression names v)
  | Primitives.FloatAtan2 -> binary (Printf.sprintf "atan2f(%s, %s)")
  | Primitives.IntAdd -> binary (Printf.sprintf "tempore_int_add(%s, %s)")
  | Primitives.IntMul -> binary (Printf.sprintf "tempore_int_mul(%s, %s)")
  | Primitives.IntSub -> binary (Printf.sprintf "tempore_int_sub(%s, %s)")
  | Primitives.IntDiv -> binary (Printf.sprintf "tempore_int_div(%s, %s)")
  | Primitives.IntMod -> binary (Printf.sprintf "tempore_int_mod(%s, %s)")
  | Primitives.IntNeg ->
      Printf.sprintf "tempore_int_neg(%s)" (expression names v)
  | Primitives.IntOfNat ->
      Printf.sprintf "tempore_int_of_bits(%s)" (expression names v)
  | Primitives.NatOfInt ->
      Printf.sprintf "tempore_nat_of_int(%s)" (expression names v)
  | Primitives.FloatOfInt ->
      Printf.sprintf "static_cast<float>(%s)" (expression names v)
  | Primitives.IntOfFloat ->
      Printf.sprintf "tempore_int_of_float(%s)" (expression names v)
  | Primitives.ToString -> invalid_arg "to_string"

(* Free variables. *)

let rec value_free acc (v : F.value) =
  match v.value with
  | F.Local x -> VariableSet.add x acc
  | F.Global _ | F.Constant _ -> acc
  | F.Tuple_value vs -> List.fold_left value_free acc vs
  | F.Construct (_, arg) -> Option.fold ~none:acc ~some:(value_free acc) arg

let binds_used used p =
  List.exists (fun x -> VariableSet.mem x used) (pattern_binders [] p)

(* The variables free in [c] that its C++ statements refer to; bound variables
   are distinct, so that those a pattern binds are never free elsewhere. A
   returned value bound by a pattern whose variables are unused, as by an
   unboxing whose result is unused, generates no statement. *)
let rec computation_free acc (c : F.computation) =
  match c.computation with
  | F.Return v | F.Perform (_, v) -> value_free acc v
  | F.Bind (p, ({ computation = F.Return _; _ } as c1), c2) ->
      let acc = computation_free acc c2 in
      if binds_used acc p then computation_free acc c1 else acc
  | F.Bind (_, c1, c2) -> computation_free (computation_free acc c1) c2
  | F.Match (v, cases) ->
      List.fold_left
        (fun acc (_, c) -> computation_free acc c)
        (value_free acc v) cases
  | F.Call (_, vs) -> List.fold_left value_free acc vs
  | F.Delay (_, c) -> computation_free acc c
  | F.Handle (u, c) ->
      computation_free (List.fold_left value_free acc u.arguments) c

(* Patterns: a match is a chain of tests of the subject, at the paths of the
   subterms the pattern constrains, followed by the declarations of the
   variables it binds that are [used]. *)

let tag_test names path (ty : F.ty) l =
  let data = ty_name names ty in
  Printf.sprintf "%s.tag == %s::Tag::%s" path data (LabelMap.find l names.tags)

let rec tests names path (p : F.pattern) acc =
  match p.pattern with
  | F.PVar _ | F.PAny -> acc
  | F.PAs (p, _) -> tests names path p acc
  | F.PTuple ps ->
      List.fold_left
        (fun acc (i, p) -> tests names (Printf.sprintf "%s.c%d" path i) p acc)
        acc
        (List.mapi (fun i p -> (i, p)) ps)
  | F.PConstruct (l, arg) ->
      let acc = tag_test names path p.pattern_ty l :: acc in
      Option.fold ~none:acc
        ~some:(fun arg ->
          tests names
            (Printf.sprintf "%s.arg.%s" path (LabelMap.find l names.tags))
            arg acc)
        arg
  | F.PConstant (Const.Boolean true) -> path :: acc
  | F.PConstant (Const.Boolean false) -> ("!" ^ path) :: acc
  | F.PConstant (Const.Float f) ->
      Printf.sprintf "tempore_compare_float(%s, %s) == 0" path (float_literal f)
      :: acc
  | F.PConstant c -> Printf.sprintf "%s == %s" path (constant c) :: acc
  | F.PSucc (p, k) ->
      tests names
        (Printf.sprintf "(%s - %su)" path (Z.to_string k))
        p
        (Printf.sprintf "%s >= %su" path (Z.to_string k) :: acc)

let rec bindings names used path (p : F.pattern) acc =
  let declare x acc =
    if VariableSet.mem x used then
      Line
        (Printf.sprintf "const %s %s = %s;"
           (ty_name names p.pattern_ty)
           (local names x) path)
      :: acc
    else acc
  in
  match p.pattern with
  | F.PVar x -> declare x acc
  | F.PAs (p', x) -> bindings names used path p' (declare x acc)
  | F.PTuple ps ->
      List.fold_left
        (fun acc (i, p) ->
          bindings names used (Printf.sprintf "%s.c%d" path i) p acc)
        acc
        (List.mapi (fun i p -> (i, p)) ps)
  | F.PConstruct (l, Some p) ->
      bindings names used
        (Printf.sprintf "%s.arg.%s" path (LabelMap.find l names.tags))
        p acc
  | F.PSucc (p, k) ->
      bindings names used
        (Printf.sprintf "(%s - %su)" path (Z.to_string k))
        p acc
  | F.PConstruct (_, None) | F.PConstant _ | F.PAny -> acc

let pattern_tests names path p = List.rev (tests names path p [])

let pattern_bindings names used path p =
  List.rev (bindings names used path p [])

(* Computations. A computation is a sequence of statements that delivers its
   result to a destination: [Tail] returns it from the function, [Assign x]
   assigns it to the variable [x] and [Discard] drops it. *)

type destination = Tail | Assign of string | Discard

(* The emission context: the names, the function being defined, if it calls
   itself, with the names of its parameters, [None] for those unused, the
   operations of the program, and the handlers around the computation. *)
type context = {
  names : names;
  self : string option list option;
  ops : operations;
  frames : frame list;
}

(* The fresh names of temporaries, which start with [tempore_]. *)
let fresh prefix next = (Printf.sprintf "tempore_%s%d" prefix next, next + 1)
let captured frames = List.concat_map (fun frame -> frame.captured) frames

let unit_call names key arguments =
  Printf.sprintf "%s(%s)" (instance_name names key)
    (String.concat ", " arguments)

let call ctx callee vs =
  let names = ctx.names in
  match callee with
  | F.Function g -> (
      let key, relevant = call_unit ctx.ops ctx.frames g in
      match (UnitMap.find_opt key names.wrappers, vs) with
      | Some p, [ v ] -> primitive names p v
      | Some p, _ ->
          primitive names p
            {
              value = F.Tuple_value vs;
              ty = F.Tuple (List.map (fun (v : F.value) -> v.ty) vs);
            }
      | None, _ ->
          unit_call names key
            (List.map (expression names) vs @ captured relevant))
  | F.Primitive p -> primitive names p (List.hd vs)
  | F.Self -> invalid_arg "a recursive call outside tail position"

(* An operation call: a call of the case of the innermost handler of the
   operation, with the values of the parameters of the handler and of the
   relevant handlers outside it, or of the external function. *)
let perform ctx op v =
  let names = ctx.names in
  match case_unit ctx.ops ctx.frames op with
  | Some (key, frame, relevant) ->
      unit_call names key
        ((frame.captured @ [ expression names v ]) @ captured relevant)
  | None -> Printf.sprintf "%s(%s)" (operation_function op) (expression names v)

(* The C++ expression of [c], if [c] is one. *)
let expression_of ctx (c : F.computation) =
  match c.computation with
  | F.Return v -> Some (expression ctx.names v)
  | F.Call (((F.Function _ | F.Primitive _) as callee), vs) ->
      Some (call ctx callee vs)
  | F.Perform (op, v) -> Some (perform ctx op v)
  | F.Call (F.Self, _) | F.Bind _ | F.Match _ | F.Delay _ | F.Handle _ -> None

let deliver destination ~pure e =
  match destination with
  | Tail -> [ Line ("return " ^ e ^ ";") ]
  | Assign x -> [ Line (x ^ " = " ^ e ^ ";") ]
  | Discard -> if pure then [] else [ Line ("static_cast<void>(" ^ e ^ ");") ]

let rec statements ctx next destination (c : F.computation) =
  match (c.computation, expression_of ctx c) with
  | F.Return _, Some e -> (next, deliver destination ~pure:true e)
  | _, Some e -> (next, deliver destination ~pure:false e)
  | F.Call (F.Self, vs), None -> (next, tail_call ctx vs)
  | F.Bind (p, c1, c2), None ->
      let used = computation_free VariableSet.empty c2 in
      let next, bound = bind ctx next used p c1 in
      let next, rest = statements ctx next destination c2 in
      (next, bound @ rest)
  | F.Match (v, cases), None -> match_cases ctx next destination v cases
  | F.Delay (q, c), None ->
      let next, rest = statements ctx next destination c in
      ( next,
        Line
          (Printf.sprintf "tempore_delay(%su, %su);"
             (Z.to_string (Grades.Rational.num q))
             (Z.to_string (Grades.Rational.den q)))
        :: rest )
  | F.Handle (u, body), None -> handle ctx next destination u body
  | (F.Return _ | F.Call _ | F.Perform _), None -> assert false

(* The binding of the result of [c1] to [p], of which [used] are used. *)
and bind ctx next used (p : F.pattern) c1 =
  let names = ctx.names in
  let ty = ty_name names c1.result in
  match (expression_of ctx c1, p.pattern, binds_used used p) with
  | Some e, _, false ->
      ( next,
        deliver Discard
          ~pure:(match c1.computation with F.Return _ -> true | _ -> false)
          e )
  | Some e, F.PVar x, true ->
      (next, [ Line (Printf.sprintf "const %s %s = %s;" ty (local names x) e) ])
  | Some e, _, true ->
      let t, next = fresh "t" next in
      ( next,
        Line (Printf.sprintf "const %s %s = %s;" ty t e)
        :: pattern_bindings names used t p )
  | None, _, false -> statements ctx next Discard c1
  | None, F.PVar x, true ->
      let x = local names x in
      let next, stmts = statements ctx next (Assign x) c1 in
      (next, Line (Printf.sprintf "%s %s{};" ty x) :: stmts)
  | None, _, true ->
      let t, next = fresh "t" next in
      let next, stmts = statements ctx next (Assign t) c1 in
      ( next,
        (Line (Printf.sprintf "%s %s{};" ty t) :: stmts)
        @ pattern_bindings names used t p )

and match_cases ctx next destination (v : F.value) cases =
  let names = ctx.names in
  let next, subject, path =
    match v.value with
    | F.Local _ | F.Global _ | F.Constant _ -> (next, [], expression names v)
    | F.Tuple_value _ | F.Construct _ ->
        let s, next = fresh "s" next in
        ( next,
          [
            Line
              (Printf.sprintf "const %s %s = %s;" (ty_name names v.ty) s
                 (expression names v));
          ],
          s )
  in
  (* The cases up to the first without tests; the last is taken when no case
     before it applies. *)
  let rec branches next = function
    | [] -> (next, [])
    | (p, c) :: rest ->
        let used = computation_free VariableSet.empty c in
        let next, body = statements ctx next destination c in
        let body = pattern_bindings names used path p @ body in
        let condition =
          match (rest, pattern_tests names path p) with
          | [], _ | _, [] -> None
          | _, tests -> Some (String.concat " && " tests)
        in
        if condition = None then (next, [ (None, body) ])
        else
          let next, rest = branches next rest in
          (next, (condition, body) :: rest)
  in
  let next, chain = branches next cases in
  match chain with
  | [ (None, body) ] -> (next, subject @ body)
  | _ -> (next, subject @ [ If chain ])

(* A [handle]: the body in the context extended by the handler, its result
   passed to the return case, unless the return case returns its input. *)
and handle ctx next destination (u : F.handler_use) body =
  let names = ctx.names in
  let frame =
    handle_frame ctx.ops.definitions u (List.map (expression names) u.arguments)
  in
  let inner = { ctx with frames = frame :: ctx.frames } in
  if returns_input frame.code then statements inner next destination body
  else
    let t, next = fresh "t" next in
    let next, stmts = statements inner next (Assign t) body in
    let key, relevant = return_unit ctx.ops ctx.frames frame in
    ( next,
      (Line (Printf.sprintf "%s %s{};" (ty_name names body.result) t) :: stmts)
      @ deliver destination ~pure:false
          (unit_call names key ((frame.captured @ [ t ]) @ captured relevant))
    )

(* A recursive call in tail position: the parameters that are used take the
   arguments, through temporaries if there are several, and the loop of the
   function's body continues. *)
and tail_call ctx vs =
  let names = ctx.names in
  let parameters =
    match ctx.self with
    | Some parameters -> parameters
    | None -> invalid_arg "a recursive call outside a recursive function"
  in
  let assigned =
    List.filter_map
      (fun (parameter, (v : F.value)) -> Option.map (fun p -> (p, v)) parameter)
      (List.combine parameters vs)
  in
  let assignments =
    match assigned with
    | [ (p, v) ] -> [ Line (Printf.sprintf "%s = %s;" p (expression names v)) ]
    | _ ->
        let temporaries =
          List.map
            (fun (p, (v : F.value)) ->
              ( Line
                  (Printf.sprintf "const %s tempore_next_%s = %s;"
                     (ty_name names v.ty) p (expression names v)),
                Line (Printf.sprintf "%s = tempore_next_%s;" p p) ))
            assigned
        in
        List.map fst temporaries @ List.map snd temporaries
  in
  assignments @ [ Line "continue;" ]

(* Functions: the parameters of a function are named by their variables, or
   by [tempore_a] and their position when they are patterns whose variables
   are then declared, or left unnamed when their variables are unused; the
   values of the parameters of the handlers of its context follow. A function
   that calls itself runs its body in a loop. *)
let function_definition ctx ~static ~name (parameters : F.pattern list) body
    ~recursive =
  let names = ctx.names in
  let used = computation_free VariableSet.empty body in
  let parameters =
    List.mapi
      (fun i (p : F.pattern) ->
        let ty = ty_name names p.pattern_ty in
        match p.pattern with
        | F.PVar x when VariableSet.mem x used -> (ty, Some (local names x), [])
        | _ when binds_used used p ->
            let a = Printf.sprintf "tempore_a%d" i in
            (ty, Some a, pattern_bindings names used a p)
        | _ -> (ty, None, []))
      parameters
  in
  let context =
    List.concat_map
      (fun frame ->
        List.map2
          (fun (p : F.pattern) name ->
            (ty_name names p.pattern_ty, Some name, []))
          frame.code.handler_parameters frame.captured)
      ctx.frames
  in
  let signature =
    Printf.sprintf "%s%s %s(%s)"
      (if static then "static " else "")
      (ty_name names body.F.result)
      name
      (String.concat ", "
         (List.map
            (fun (ty, name, _) ->
              Option.fold ~none:ty ~some:(fun name -> ty ^ " " ^ name) name)
            (parameters @ context)))
  in
  let prototype =
    Printf.sprintf "%s%s %s(%s);"
      (if static then "static " else "")
      (ty_name names body.F.result)
      name
      (String.concat ", "
         (List.map (fun (ty, _, _) -> ty) (parameters @ context)))
  in
  let ctx =
    {
      ctx with
      self =
        (if recursive then Some (List.map (fun (_, name, _) -> name) parameters)
         else None);
    }
  in
  let _, stmts = statements ctx 0 Tail body in
  let stmts = List.concat_map (fun (_, _, binds) -> binds) parameters @ stmts in
  ( prototype,
    block signature (if recursive then [ block "for (;;)" stmts ] else stmts) )

(* Structs: a tuple has the members [c0], [c1], ...; a datatype has a tag, the
   enumeration of its constructors in the order of their labels, the union
   [arg] of the arguments of its constructors, and a function [make_] for
   each constructor. *)
let struct_definition names datatypes ty =
  let name = ty_name names ty in
  match ty with
  | F.Data n ->
      let constructors =
        List.map
          (fun (l, arg) -> (LabelMap.find l names.tags, arg))
          (Ast.TyNameMap.find n datatypes : F.datatype).constructors
      in
      let arguments =
        List.filter_map
          (fun (tag, arg) ->
            Option.map
              (fun ty -> Line (Printf.sprintf "%s %s;" (ty_name names ty) tag))
              arg)
          constructors
      in
      let make (tag, arg) =
        block
          (Printf.sprintf "static %s make_%s(%s)" name tag
             (Option.fold ~none:""
                ~some:(fun ty -> ty_name names ty ^ " a")
                arg))
          ([
             Line (Printf.sprintf "%s v{};" name);
             Line (Printf.sprintf "v.tag = Tag::%s;" tag);
           ]
          @ (match arg with
            | Some _ -> [ Line (Printf.sprintf "v.arg.%s = a;" tag) ]
            | None -> [])
          @ [ Line "return v;" ])
      in
      Block
        ( "struct " ^ name,
          [
            Line
              (Printf.sprintf "enum class Tag : uint8_t { %s };"
                 (String.concat ", " (List.map fst constructors)));
            Line "Tag tag;";
          ]
          @ (match arguments with
            | [] -> []
            | _ -> [ Block ("union", arguments, "} arg;") ])
          @ List.map make constructors,
          "};" )
  | _ ->
      Block
        ( "struct " ^ name,
          List.mapi
            (fun i ty -> Line (Printf.sprintf "%s c%d;" (ty_name names ty) i))
            (components datatypes ty),
          "};" )

(* The comparison of a struct, in the order of the comparison primitives:
   tuples lexicographically, values of a datatype by the order of their
   constructors and then of their arguments. *)
let compare_definition names datatypes ty =
  let name = ty_name names ty in
  let header =
    Printf.sprintf "inline int tempore_compare(const %s &a, const %s &b)" name
      name
  in
  let compare ty a b = Printf.sprintf "%s(%s, %s)" (compare_function ty) a b in
  match ty with
  | F.Data n -> (
      let constructors =
        List.filter_map
          (fun (l, arg) ->
            Option.map (fun ty -> (LabelMap.find l names.tags, ty)) arg)
          (Ast.TyNameMap.find n datatypes : F.datatype).constructors
      in
      let tag_order = "a.tag < b.tag ? -1 : 1" in
      match constructors with
      | [] ->
          block header
            [
              Line
                (Printf.sprintf "return a.tag == b.tag ? 0 : (%s);" tag_order);
            ]
      | _ ->
          block header
            [
              Line (Printf.sprintf "if (a.tag != b.tag) return %s;" tag_order);
              block "switch (a.tag)"
                (List.concat_map
                   (fun (tag, ty) ->
                     [
                       Line (Printf.sprintf "case %s::Tag::%s:" name tag);
                       Line
                         (Printf.sprintf "  return %s;"
                            (compare ty ("a.arg." ^ tag) ("b.arg." ^ tag)));
                     ])
                   constructors
                @ [ Line "default:"; Line "  return 0;" ]);
            ])
  | _ ->
      let members = List.mapi (fun i ty -> (i, ty)) (components datatypes ty) in
      let last = List.length members - 1 in
      block header
        (List.concat_map
           (fun (i, ty) ->
             let c =
               compare ty (Printf.sprintf "a.c%d" i) (Printf.sprintf "b.c%d" i)
             in
             if i = last then [ Line (Printf.sprintf "return %s;" c) ]
             else
               [
                 Line (Printf.sprintf "const int c%d = %s;" i c);
                 Line (Printf.sprintf "if (c%d != 0) return c%d;" i i);
               ])
           members)

(* Printing, in the format of the interpreter: [parenthesised] is whether a
   constructor applied to an argument is printed in parentheses. *)

let printer = function
  | F.Nat -> "tempore_print_nat"
  | F.Int -> "tempore_print_int"
  | F.Float -> "tempore_print_float"
  | F.Bool -> "tempore_print_bool"
  | _ -> "tempore_print"

let print_definition names datatypes ty =
  let name = ty_name names ty in
  let header =
    Printf.sprintf "inline void tempore_print(const %s &v, bool parenthesised)"
      name
  in
  let print_string s =
    Line (Printf.sprintf "printf(\"%%s\", %s);" (Names.string_literal s))
  in
  match ty with
  | F.Data n ->
      let constructors =
        (Ast.TyNameMap.find n datatypes : F.datatype).constructors
      in
      let uses_parentheses =
        List.exists (fun (_, arg) -> arg <> None) constructors
      in
      block
        (if uses_parentheses then header
         else Printf.sprintf "inline void tempore_print(const %s &v, bool)" name)
        [
          block "switch (v.tag)"
            (List.concat_map
               (fun (l, arg) ->
                 let tag = LabelMap.find l names.tags in
                 Line (Printf.sprintf "case %s::Tag::%s:" name tag)
                 ::
                 (match arg with
                 | None -> [ print_string (Ast.Label.string_of l) ]
                 | Some ty ->
                     [
                       Line "if (parenthesised) printf(\"(\");";
                       print_string (Ast.Label.string_of l ^ " ");
                       Line
                         (Printf.sprintf "%s(v.arg.%s, true);" (printer ty) tag);
                       Line "if (parenthesised) printf(\")\");";
                     ])
                 @ [ Line "return;" ])
               constructors);
        ]
  | _ ->
      let members = List.mapi (fun i ty -> (i, ty)) (components datatypes ty) in
      block
        (Printf.sprintf "inline void tempore_print(const %s &v, bool)" name)
        (Line "printf(\"(\");"
         :: List.concat_map
              (fun (i, ty) ->
                (if i > 0 then [ Line "printf(\", \");" ] else [])
                @ [ Line (Printf.sprintf "%s(v.c%d, false);" (printer ty) i) ])
              members
        @ [ Line "printf(\")\");" ])

let host_prelude =
  {|#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void tempore_fault(const char *message) {
  fflush(stdout);
  fprintf(stderr, "Run-time error: %s\n", message);
  exit(1);
}

void tempore_delay(uint32_t, uint32_t) {}

inline void tempore_print_nat(uint32_t v, bool) {
  printf("%lu", static_cast<unsigned long>(v));
}

inline void tempore_print_int(int32_t v, bool) {
  printf("%ldi", static_cast<long>(v));
}

inline void tempore_print_bool(bool v, bool) { printf("%s", v ? "true" : "false"); }

// A float as OCaml's format %F prints it.
inline void tempore_print_float(float v, bool) {
  const double d = v;
  if (isnan(d)) {
    printf("nan");
  } else if (isinf(d)) {
    printf("%s", d > 0 ? "infinity" : "neg_infinity");
  } else {
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%.12g", d);
    printf("%s%s", buffer, strpbrk(buffer, ".e") ? "" : ".");
  }
}

inline void tempore_print(tempore_unit, bool) { printf("()"); }
|}

(* Files. *)

type compiled = {
  files : (string * string) list;
  entries : (Ast.variable * string) list;
  operation_types : (Ast.operation * (string * string)) list;
}

let compile ?(host_runs = false) ~source (program : F.program) =
  let datatypes =
    List.fold_left
      (fun map (d : F.datatype) -> Ast.TyNameMap.add d.type_name d map)
      Ast.TyNameMap.empty program.datatypes
  in
  let ops = operations program.definitions in
  let entries =
    List.filter_map
      (fun (d : F.definition) ->
        match (d.in_sources, d.quantified, d.definition_body) with
        | true, [], F.Function_body _ -> Some (d.variable, [])
        | _ -> None)
      program.definitions
  in
  let runs =
    if host_runs then List.map ground_computation program.runs else []
  in
  let instances, handlers, external_ops =
    instances ops ~entries ~runs
      (List.map (fun key -> Instance (key, [])) entries)
  in
  (* The operations performed outside all handlers. *)
  let performed =
    List.filter
      (fun (op : F.operation) -> OpNameSet.mem op.operation external_ops)
      program.operations
  in
  let structs =
    structs datatypes
      (List.fold_left computation_types
         (List.fold_left
            (fun acc inst -> body_types acc inst.body)
            [] instances)
         runs
      @ List.concat_map
          (fun (op : F.operation) -> [ op.argument; op.result_ty ])
          performed)
  in
  let names = names datatypes instances runs structs in
  let context frames = { names; self = None; ops; frames } in
  let comparable =
    List.filter (fun ty -> not (has_string datatypes ty)) structs
  in
  let operations =
    List.map
      (fun (op : F.operation) ->
        Printf.sprintf "%s %s(%s)"
          (ty_name names op.result_ty)
          (operation_function op.operation)
          (ty_name names op.argument))
      performed
  in
  let functions =
    List.filter_map
      (fun inst ->
        match inst.body with
        | F.Function_body _ when UnitMap.mem inst.key names.wrappers -> None
        | F.Function_body { parameters; body; recursive } ->
            Some
              ( inst.entry,
                function_definition
                  (context (context_frames handlers inst.context))
                  ~static:(not inst.entry)
                  ~name:(instance_name names inst.key)
                  parameters body ~recursive )
        | F.Constant_body _ | F.Handler_body _ -> None)
      instances
  in
  let constants =
    List.filter_map
      (fun inst ->
        match inst.body with
        | F.Constant_body v ->
            Some
              (Line
                 (Printf.sprintf "static const %s %s = %s;" (ty_name names v.ty)
                    (instance_name names inst.key)
                    (expression names v)))
        | F.Function_body _ | F.Handler_body _ -> None)
      instances
  in
  let run_functions =
    List.mapi
      (fun i c ->
        function_definition (context []) ~static:false
          ~name:(Printf.sprintf "tempore_run%d" (i + 1))
          [] c ~recursive:false)
      runs
  in
  let separated stmts =
    List.concat
      (List.mapi (fun i s -> if i = 0 then [ s ] else [ Line ""; s ]) stmts)
  in
  let section comment stmts =
    match stmts with
    | [] -> []
    | _ -> Line "" :: Line ("// " ^ comment) :: stmts
  in
  let header =
    [
      Line ("// The program " ^ source ^ ", compiled by Tempore.");
      Line "";
      Line "#ifndef TEMPORE_PROGRAM_H";
      Line "#define TEMPORE_PROGRAM_H";
      Line "";
      Line ("#include \"" ^ runtime_file ^ "\"");
    ]
    @ section "Types."
        (separated (List.map (struct_definition names datatypes) structs))
    @ section "Comparisons."
        (separated (List.map (compare_definition names datatypes) comparable))
    @ section "Operations, implemented outside the program."
        (List.map (fun s -> Line (s ^ ";")) operations)
    @ section "Entry points."
        (List.filter_map
           (fun (entry, (prototype, _)) ->
             if entry then Some (Line prototype) else None)
           functions)
    @ section "Runs."
        (List.map (fun (prototype, _) -> Line prototype) run_functions)
    @ [ Line ""; Line "#endif" ]
  in
  let source_stmts =
    [
      Line ("// The program " ^ source ^ ", compiled by Tempore.");
      Line "";
      Line ("#include \"" ^ header_file ^ "\"");
    ]
    @ section "Constants." constants
    @ section "Functions."
        (List.filter_map
           (fun (entry, (prototype, _)) ->
             if entry then None else Some (Line prototype))
           functions)
    @ List.concat_map (fun (_, (_, def)) -> [ Line ""; def ]) functions
    @ List.concat_map (fun (_, def) -> [ Line ""; def ]) run_functions
  in
  let host_main =
    [
      Line
        ("// The runs of the program " ^ source
       ^ ", compiled by Tempore, on the host.");
      Line "";
      Line ("#include \"" ^ header_file ^ "\"");
      Line "";
      Line host_prelude;
    ]
    @ List.concat_map
        (fun ((op : F.operation), signature) ->
          [
            block signature
              [
                Line
                  (Printf.sprintf "tempore_fault(%s);"
                     (Names.string_literal
                        ("Unhandled operation "
                        ^ Ast.OpName.string_of op.operation)));
              ];
            Line "";
          ])
        (List.combine performed operations)
    @ List.concat_map
        (fun ty -> [ print_definition names datatypes ty; Line "" ])
        comparable
    @ [
        block "int main()"
          (List.concat
             (List.mapi
                (fun i (c : F.computation) ->
                  [
                    block ""
                      [
                        Line
                          (Printf.sprintf "const %s r = tempore_run%d();"
                             (ty_name names c.result) (i + 1));
                        Line
                          (Printf.sprintf
                             "printf(\"=== Run %d ===\\nreturn \");" (i + 1));
                        Line (Printf.sprintf "%s(r, true);" (printer c.result));
                        Line "printf(\"\\n\\n\");";
                      ];
                  ])
                runs)
          @ [ Line "return 0;" ]);
      ]
  in
  {
    files =
      ([
         (runtime_file, runtime);
         (header_file, render header);
         (source_file, render source_stmts);
       ]
      @ if host_runs then [ (host_main_file, render host_main) ] else []);
    entries =
      List.map
        (fun key -> (fst key, instance_name names (Instance (key, []))))
        entries;
    operation_types =
      List.map
        (fun (op : F.operation) ->
          (op.operation, (ty_name names op.argument, ty_name names op.result_ty)))
        performed;
  }
