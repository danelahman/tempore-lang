open Ast
open Exception
module Error = Utils.Error
module Symbol = Utils.Symbol

module type S = sig
  type var
  type grade
  type elapsed
  type 'a map_or_rho
  type 'a t

  val empty : 'a t
  val add_temp : elapsed -> 'a t -> 'a t
  val add_variable : var -> 'a -> 'a t -> 'a t
  val find_variable : var -> 'a t -> 'a
  val find_variable_opt : var -> 'a t -> 'a option
end

(** A context is a stack of variable bindings interleaved with the grades
    accumulated between them, which are grade expressions of [Elapsed.Grade].
    [Elapsed] is a payload the context stores as it is and only ever reads a
    grade out of. *)
module Make
    (Variable : Symbol.S)
    (VariableMap : Map.S with type key = Variable.t)
    (Elapsed : sig
      module Grade : sig
        type t

        val one : t
      end

      type t

      val grade : t -> Grade.t
    end) =
struct
  type var = Variable.t
  type grade = Elapsed.Grade.t
  type elapsed = Elapsed.t
  type 'a map_or_rho = (var, 'a VariableMap.t, elapsed) context_elem_ty
  type 'a t = (var, 'a VariableMap.t, elapsed) context

  let empty : 'a t = []

  (* The unit grade is not recorded. *)
  let add_temp (n : elapsed) (lst : 'a t) : 'a t =
    if Elapsed.grade n = Elapsed.Grade.one then lst else Rho n :: lst

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
          raise (VariableNotFound (Format.asprintf "%t" (Variable.print key)))
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
