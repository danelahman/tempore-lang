open Ast
open Exception
module Error = Utils.Error
module Symbol = Utils.Symbol

module type S = sig
  type var
  type grade
  type elapsed
  type barrier
  type 'a map_or_rho
  type 'a t

  val empty : 'a t
  val add_temp : elapsed -> 'a t -> 'a t
  val add_variable : var -> 'a -> 'a t -> 'a t
  val add_barrier : barrier -> 'a t -> 'a t
  val find_variable : var -> 'a t -> 'a
  val find_variable_opt : var -> 'a t -> 'a option
  val barrier_after : var -> 'a t -> barrier option
  val sum_grades_added_after : var -> 'a t -> grade
  val elapsed_after : var -> 'a t -> elapsed list
  val abstract_grade_sum : 'a t -> grade
end

(** A context is a stack of variable bindings interleaved with the grades
    accumulated between them, which are grade expressions of [Elapsed.Grade].
    [Elapsed] is a payload the context stores as it is and only ever reads a
    grade out of: the interpreter needs the grade alone, while the typechecker
    also remembers where it came from, so that an error can point at the
    [delay], [perform] or sequenced computation that spent it. [Barrier] is a
    payload of the same kind, stored at the point an operation case restricts
    the context and never read by the context itself. *)
module Make
    (Variable : Symbol.S)
    (VariableMap : Map.S with type key = Variable.t)
    (Elapsed : sig
      module Grade : sig
        type t

        val one : t
        val mul : t -> t -> t
      end

      type t

      val grade : t -> Grade.t
    end)
    (Barrier : sig
      type t
    end) =
struct
  type var = Variable.t
  type grade = Elapsed.Grade.t
  type elapsed = Elapsed.t
  type barrier = Barrier.t
  type 'a map_or_rho = (var, 'a VariableMap.t, elapsed, barrier) context_elem_ty
  type 'a t = (var, 'a VariableMap.t, elapsed, barrier) context

  let empty : 'a t = []

  (* The unit grade is not recorded. *)
  let add_temp (n : elapsed) (lst : 'a t) : 'a t =
    if Elapsed.grade n = Elapsed.Grade.one then lst else Rho n :: lst

  let add_barrier (b : barrier) (lst : 'a t) : 'a t = Barrier b :: lst

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
      | (Rho _ | Barrier _) :: rest -> find rest
    in
    find lst

  let find_variable_opt (key : var) (lst : 'a t) : 'a option =
    let rec find = function
      | [] -> None
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some v -> Some v
          | None -> find rest)
      | (Rho _ | Barrier _) :: rest -> find rest
    in
    find lst

  (** [barrier_after key lst] is the outermost barrier standing between the
      binding of [key] and the front of [lst], if any: walking front-to-binding
      meets it last. *)
  let barrier_after (key : var) (lst : 'a t) : barrier option =
    let rec go outermost = function
      | [] ->
          raise (VariableNotFound (Format.asprintf "%t" (Variable.print key)))
      | Barrier b :: rest -> go (Some b) rest
      | Rho _ :: rest -> go outermost rest
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some _ -> outermost
          | None -> go outermost rest)
    in
    go None lst

  (** [sum_grades_added_after key lst] is the sum of the grades recorded in
      [lst] since [key] was bound. The context is kept most-recent-first, so
      walking it from the front visits the grades newest-first and each one is
      added on the *left* of what has been accumulated so far: the sum reads
      chronologically, oldest first. This matters for the non-commutative
      (timed-trace) grades, where the order of the summands is the order the
      events happened in. *)
  let sum_grades_added_after (key : var) (lst : 'a t) : grade =
    let rec go acc = function
      | [] ->
          raise (VariableNotFound (Format.asprintf "%t" (Variable.print key)))
      | Rho t :: rest -> go (Elapsed.Grade.mul (Elapsed.grade t) acc) rest
      | Barrier _ :: rest -> go acc rest
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some _ -> acc
          | None -> go acc rest)
    in
    go Elapsed.Grade.one lst

  (** [elapsed_after key lst] are the entries recorded in [lst] since [key] was
      bound, oldest first: the summands of {!sum_grades_added_after} with
      whatever else the client stored alongside them still attached. *)
  let elapsed_after (key : var) (lst : 'a t) : elapsed list =
    let rec go acc = function
      | [] ->
          raise (VariableNotFound (Format.asprintf "%t" (Variable.print key)))
      | Rho t :: rest -> go (t :: acc) rest
      | Barrier _ :: rest -> go acc rest
      | VarMap map :: rest -> (
          match VariableMap.find_opt key map with
          | Some _ -> acc
          | None -> go acc rest)
    in
    go [] lst

  (** [abstract_grade_sum lst] is the sum of all the grades recorded in [lst],
      oldest first, for the same reason as in {!sum_grades_added_after}. *)
  let abstract_grade_sum (lst : 'a t) : grade =
    let rec sum acc = function
      | [] -> acc
      | Rho t :: rest -> sum (Elapsed.Grade.mul (Elapsed.grade t) acc) rest
      | (VarMap _ | Barrier _) :: rest -> sum acc rest
    in
    sum Elapsed.Grade.one lst
end
