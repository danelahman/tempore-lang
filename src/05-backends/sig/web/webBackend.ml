module type S = sig
  include Backend.S

  val view_step_label : step_label -> 'a Vdom.vdom
  val view_run_state : run_state -> step_label option -> 'a Vdom.vdom
  val is_end_of_run_label : step_label -> bool
  val is_done : run_state -> bool

  val observe : run_state -> step -> Backend.observation list
  (** [observe state step] is what [step] from [state] shows of the operations
      performed, the delays and the resources boxed and unboxed, in order. *)
end
