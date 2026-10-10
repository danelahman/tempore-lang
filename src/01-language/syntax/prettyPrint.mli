(** Printing of types, terms and interpreter states. *)

(** {1 Names of grade and type parameters} *)

val type_symbol : int -> string
(** [type_symbol n] is the name of the [n]-th type parameter, from 0: the Greek
    letters in order, then [σ] with a subscript. *)

val rho_symbol : int -> string
(** [rho_symbol n] is the name of the [n]-th resource variable, [ρₙ]. *)

val eps_symbol : int -> string
(** [eps_symbol n] is the name of the [n]-th effect variable, [εₙ]. *)

val rigid_symbol : string -> string
(** [rigid_symbol op] is the name of an effect variable bound by a handler case
    for the operation [op], [ε_op]. *)

module MakeParamPrinter
    (ParamMap : Map.S)
    (SymbolGen : sig
      val symbol_for_index : int -> string
    end) : sig
  val create_with :
    named:(ParamMap.key -> string option) ->
    unit ->
    ParamMap.key ->
    Format.formatter ->
    unit
  (** [create_with ~named ()] names the parameters in the order they are first
      printed: by the next index, or by [base] where [named] gives [base], with
      as many primes [′] as parameters named [base] before it. *)

  val create : unit -> ParamMap.key -> Format.formatter -> unit
  (** [create ()] names every parameter by its index. *)
end

(** {1 Types} *)

type ('rho, 'eps) grade_printer = {
  rho : 'rho -> Format.formatter -> unit;
  eps : 'eps -> Format.formatter -> unit;
  pure : 'eps -> bool;
}
(** How the grades of a type are printed: its resource grades by [rho] and its
    effect grades by [eps]. A computation type whose effect grade is [pure], the
    unit, is printed without it. *)

type 'a arrows = {
  domains : 'a list;
  codomain : 'a codomain;
  grade : 'a option;
}
(** A type as printed, in parts around its arrows: the [domains] of its
    outermost chain of arrows, in order, the [codomain] of the last arrow, and
    the effect grade of the last arrow where it is printed; the other arrows of
    a chain are printed without one. A type other than a function type has no
    domains and no grade. *)

(** A codomain, printed as it is or in parentheses. *)
and 'a codomain = Plain of 'a | Parenthesised of 'a arrows

val map_arrows : ('a -> 'b) -> 'a arrows -> 'b arrows
(** [map_arrows f arrows] applies [f] to the parts of [arrows] in the order they
    are printed. *)

val print_ty :
  ?max_level:int ->
  ('rho, 'eps) grade_printer ->
  (Ast.ty_param -> Format.formatter -> unit) ->
  ('rho, 'eps) Ast.ty ->
  Format.formatter ->
  unit
(** [print_ty grades ty_print_param ty] prints [ty], its grades by [grades],
    with the parentheses the precedences of the types require: by decreasing
    precedence, application of a type constructor (level 1), the box (2),
    products (3), and arrows and handler types (4). *)

val arrow_parts :
  ('rho, 'eps) grade_printer ->
  (Ast.ty_param -> Format.formatter -> unit) ->
  ('rho, 'eps) Ast.ty ->
  (Format.formatter -> unit) arrows
(** [arrow_parts grades ty_print_param ty] is [ty] as
    [print_ty grades ty_print_param ty] prints it, in parts around its arrows.
*)

(** {1 Terms} *)

val print_rho :
  (module Grades.Grade.S with type t = 'a) ->
  'a Ast.rho ->
  Format.formatter ->
  unit
(** Prints a resource grade expression. *)

val print_pattern :
  ?max_level:int -> ('a Ast.rho, 'eps) Ast.pattern -> Format.formatter -> unit
(** Prints a pattern. *)

val print_expression :
  (module Grades.Grade.S with type t = 'a) ->
  ?max_level:int ->
  ('a Ast.rho, 'eps) Ast.expression ->
  Format.formatter ->
  unit
(** Prints an expression, its resource grades by the grade module. *)

val print_computation :
  (module Grades.Grade.S with type t = 'a) ->
  ?max_level:int ->
  ('a Ast.rho, 'eps) Ast.computation ->
  Format.formatter ->
  unit
(** Prints a computation, its resource grades by the grade module. *)

val string_of_expression :
  (module Grades.Grade.S with type t = 'a) ->
  ('a Ast.rho, 'eps) Ast.expression ->
  string
(** The text of {!print_expression}. *)

(** {1 Interpreter states} *)

val print_vars_and_exprs :
  (module Grades.Grade.S with type t = 'a) ->
  (Ast.VariableMap.key * 'b -> Format.formatter -> unit) ->
  ('var, 'b Ast.VariableMap.t, 'a Ast.rho) Ast.context_elem_ty list ->
  Format.formatter ->
  unit
(** [print_vars_and_exprs grade print_entry ctx] prints the bindings of the
    context [ctx], by [print_entry], with the resource grades between them. *)

val string_of_interpreter_state :
  (module Grades.Grade.S with type t = 'a) ->
  ( 'var,
    ('a Ast.rho * ('a Ast.rho, 'eps) Ast.expression) Ast.VariableMap.t,
    'a Ast.rho )
  Ast.context_elem_ty
  list ->
  string
(** The text of an interpreter state, whose resources are held with the grades
    they were boxed at. *)
