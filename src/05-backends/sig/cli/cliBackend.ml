module type S = sig
  include Backend.S

  val view_run_state : run_state -> run_num:int -> bool

  val observe : run_state -> step -> Backend.observation list
  (** [observe state step] is what [step] from [state] shows of the operations
      performed, the delays and the resources boxed and unboxed, in order. *)
end
