(** Contexts: stacks of variable bindings interleaved with the grades
    accumulated between them. *)

(** The elapsed grades a context stores: a payload of which the context only
    tests whether it is the unit. *)
module type ELAPSED = sig
  type t

  val is_one : t -> bool
end

module type S = sig
  type var
  type elapsed
  type 'a t

  val empty : 'a t
  (** The context with no bindings. *)

  val add_temp : elapsed -> 'a t -> 'a t
  (** [add_temp n ctx] records the elapsed grade [n] above the bindings of
      [ctx]; the unit grade is not recorded. *)

  val add_variable : var -> 'a -> 'a t -> 'a t
  (** [add_variable x v ctx] binds [x] to [v] in the topmost group of bindings
      of [ctx]. *)

  val find_variable : var -> 'a t -> 'a
  (** [find_variable x ctx] is the value bound to [x] in [ctx].

      @raise Utils.Error.Error if [x] is unbound. *)

  val find_variable_opt : var -> 'a t -> 'a option
  (** [find_variable_opt x ctx] is the value bound to [x] in [ctx], if any. *)
end

(** Contexts over the variables [Variable]. *)
module Make
    (Variable : Utils.Symbol.S)
    (VariableMap : Map.S with type key = Variable.t)
    (Elapsed : ELAPSED) :
  S
    with type var = Variable.t
     and type elapsed = Elapsed.t
     and type 'a t = (Variable.t, 'a VariableMap.t, Elapsed.t) Ast.context
