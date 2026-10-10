open Ast
module Error = Utils.Error
module Symbol = Utils.Symbol

module type S = sig
  type var
  type elapsed
  type 'a t

  val empty : 'a t
  val add_temp : elapsed -> 'a t -> 'a t
  val add_variable : var -> 'a -> 'a t -> 'a t
  val find_variable : var -> 'a t -> 'a
  val find_variable_opt : var -> 'a t -> 'a option
end

(** The elapsed grades a context stores: a payload of which the context only
    tests whether it is the unit. *)
module type ELAPSED = sig
  type t

  val is_one : t -> bool
end

(** A context is a stack of variable bindings interleaved with the grades
    accumulated between them, which are grade expressions of [Elapsed.Grade].
    [Elapsed] is a payload the context stores as it is and only ever reads a
    grade out of. *)
module Make
    (Variable : Symbol.S)
    (VariableMap : Map.S with type key = Variable.t)
    (Elapsed : ELAPSED) :
  S
    with type var = Variable.t
     and type elapsed = Elapsed.t
     and type 'a t = (Variable.t, 'a VariableMap.t, Elapsed.t) Ast.context =
struct
  type var = Variable.t
  type elapsed = Elapsed.t
  type 'a t = (var, 'a VariableMap.t, elapsed) context

  let empty : 'a t = []

  (* The unit grade is not recorded. *)
  let add_temp (n : elapsed) (lst : 'a t) : 'a t =
    if Elapsed.is_one n then lst else Rho n :: lst

  let add_variable (key : var) (value : 'a) (lst : 'a t) : 'a t =
    match lst with
    | VarMap map :: rest ->
        let updated_map = VariableMap.add key value map in
        VarMap updated_map :: rest
    | _ ->
        let new_map = VariableMap.add key value VariableMap.empty in
        VarMap new_map :: lst

  let find_variable (key : var) (lst : 'a t) : 'a =
    let rec find = function
      | [] ->
          Error.fatal "Unbound variable %t in the context" (Variable.print key)
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some v -> v
          | None -> find rest)
      | Rho _ :: rest -> find rest
    in
    find lst

  let find_variable_opt (key : var) (lst : 'a t) : 'a option =
    let rec find = function
      | [] -> None
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some v -> Some v
          | None -> find rest)
      | Rho _ :: rest -> find rest
    in
    find lst
end
