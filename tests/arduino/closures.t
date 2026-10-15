Closures are compiled by defunctionalisation: a value of a function type is a
struct with a tag, which names the function of the closure among the
functions of that type in the program, and the union of their environments;
an application calls the function of the tag. The runs of closures.tpe are
typed under the upper bounds of the regular expressions of timed operations,
under which a case of a handler need not perform its operation, so that the
handler device implements the operations of the runs on the host. Programs
compiled for the host print the results of their runs as the interpreter
prints them.

  $ . ../helpers.sh
  $ grades=regex-timed-upper-bound-symbolic
  $ parity () {
  >   ../../tempore --grades "$grades" "$1" 2>&1 | strip_state > interpreter.out
  >   ../../tempore --grades "$grades" --emit-arduino "${1%.tpe}" --host-runs "$1" > /dev/null &&
  >   c++ -std=c++17 -Wall -Wextra -Werror -O2 -ffp-contract=off -o "${1%.tpe}.host" \
  >     "_arduino/projects/${1%.tpe}/tempore_program.cpp" \
  >     "_arduino/projects/${1%.tpe}/tempore_host_main.cpp" &&
  >   "./${1%.tpe}.host" > cxx.out 2>&1
  >   diff interpreter.out cxx.out && cat cxx.out
  > }

The runs: a thunk in a nested box, a closure returned by a function, two
functions of one type chosen by a branch, a closure capturing a tuple, a
closure capturing another closure, closures passed to a top-level function,
and a closure created outside a handle and applied inside it, whose operation
the handler of the application handles.

  $ parity closures.tpe
  === Run 1 ===
  return 7
  
  === Run 2 ===
  return (6, 7)
  
  === Run 3 ===
  return (12, 7)
  
  === Run 4 ===
  return (7, 34)
  
  === Run 5 ===
  return 22
  
  === Run 6 ===
  return (12, 7)
  
  === Run 7 ===
  return (41, 2)
  
The thunk in a nested box under the intervals of the regular expressions of
timed operations. Boxes and unboxing generate no code, so the type
[{B}](unit -> [{C}]nat) is represented as unit -> nat, a struct whose
closure has the environment of the variable x:

  $ cat > staged.tpe <<'TPE'
  > operation A : unit ~> nat # {A} within [1, 2]
  > operation B : unit ~> unit # {B} within [1, 2]
  > operation C : unit ~> unit # {C} within [1, 2]
  > 
  > type staged = [{B}](unit -> [{C}]nat)
  > 
  > let stage (x : nat) : staged =
  >   box {B} (fun () -> box {C} x as inner in inner) as outer in
  >   outer
  > 
  > let f () : nat # {A; B; C} =
  >   let x = perform A () in
  >   let outer = stage x in
  >   perform B ();
  >   unbox outer as t in
  >   let inner = t () in
  >   perform C ();
  >   unbox inner as v in
  >   v
  > TPE
  $ ../../tempore --grades regex-timed-interval-rational-symbolic --emit-arduino staged staged.tpe > /dev/null
  $ c++ -std=c++17 -Wall -Wextra -Werror -c -o staged.o _arduino/projects/staged/tempore_program.cpp
  $ awk '/^\/\/ Comparisons/ { exit } /^\/\/ Types/ { on = 1 } on' _arduino/projects/staged/tempore_program.h
  // Types.
  struct tempore_tuple0 {
    uint32_t c0;
  };
  
  struct tempore_closure0 {
    uint8_t tag;
    union {
      tempore_tuple0 e0;
    } env;
    static tempore_closure0 make_e0(tempore_tuple0 a) {
      tempore_closure0 v{};
      v.tag = 0;
      v.env.e0 = a;
      return v;
    }
  };
  
  $ sed -n '/^\/\/ Functions/,$p' _arduino/projects/staged/tempore_program.cpp
  // Functions.
  static uint32_t lambda_1(uint32_t, tempore_unit);
  static uint32_t apply_2(tempore_closure0, tempore_unit);
  
  tempore_closure0 stage_0(uint32_t x_4) {
    return tempore_closure0::make_e0(tempore_tuple0{x_4});
  }
  
  static uint32_t lambda_1(uint32_t x_4, tempore_unit) {
    return x_4;
  }
  
  static uint32_t apply_2(tempore_closure0 tempore_f, tempore_unit tempore_x) {
    return lambda_1(tempore_f.env.e0.c0, tempore_x);
  }
  
  uint32_t f_3(tempore_unit) {
    const uint32_t x_5 = tempore_op_A(tempore_unit{});
    const tempore_closure0 outer_6 = stage_0(x_5);
    static_cast<void>(tempore_op_B(tempore_unit{}));
    const tempore_closure0 t_7 = outer_6;
    const uint32_t inner_8 = apply_2(t_7, tempore_unit{});
    static_cast<void>(tempore_op_C(tempore_unit{}));
    return inner_8;
  }
