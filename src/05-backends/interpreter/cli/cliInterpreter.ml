module Make (GS : Grades.GradeSystem.S) = struct
  include Interpreter.Make (GS)
  module Ast = Language.Ast
  module PrettyPrint = Language.PrettyPrint

  (* A run is reported once its computation, decomposed with an empty
     context, is a [return] or an operation call. *)
  let view_run_state (run_state : run_state) ~run_num =
    match run_state with
    | {
     current = Some { frames = []; subject = { it = Ast.Return _; _ } as comp };
     environment;
     _;
    } ->
        Format.printf "=== Run %d ===@." run_num;
        Format.printf "%t@."
          (PrettyPrint.print_computation
             (module GS.R)
             (returned_value environment comp));
        print_string
          (PrettyPrint.string_of_interpreter_state
             (module GS.R)
             environment.state);
        print_newline ();
        true
    (* An operation with a default implementation is not stuck here: the
       default is about to fire, so there is nothing to report yet. *)
    | {
     current =
       Some
         { frames = []; subject = { it = Ast.Perform (op, _, _); _ } as comp };
     environment;
     _;
    }
      when not (Ast.OpNameMap.mem op environment.op_defaults) ->
        Format.printf "=== Run %d (unhandled operation) ===@." run_num;
        Format.printf "%t@." (PrettyPrint.print_computation (module GS.R) comp);
        print_newline ();
        true
    | _ -> false
end
