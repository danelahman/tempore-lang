module Make (GS : Language.GradeSystem.S) = struct
  include Interpreter.Make (GS)
  module Ast = Language.Ast
  module PrettyPrint = Language.PrettyPrint

  let view_run_state (run_state : run_state) ~run_num =
    match run_state with
    | { computations = ({ it = Ast.Return _; _ } as comp) :: _; environment } ->
        Format.printf "=== Run %d ===@." run_num;
        Format.printf "%t@." (PrettyPrint.print_computation (module GS.R) comp);
        print_string
          (PrettyPrint.string_of_interpreter_state
             (module GS.R)
             environment.state);
        print_newline ();
        true
    (* An operation with a default implementation is not stuck here: the
       default is about to fire, so there is nothing to report yet. *)
    | {
     computations = ({ it = Ast.Perform (op, _, _); _ } as comp) :: _;
     environment;
    }
      when not (Ast.OpNameMap.mem op environment.op_defaults) ->
        Format.printf "=== Run %d (unhandled operation) ===@." run_num;
        Format.printf "%t@." (PrettyPrint.print_computation (module GS.R) comp);
        print_newline ();
        true
    | _ -> false
end
