The files written by --emit-arduino: the runtime header, the header of the
program, with its types and entry points, and its source. A name without a
directory component names a directory in _arduino/projects.

  $ ../../tempore --emit-arduino controller controller.tpe
  Wrote _arduino/projects/controller/tempore_arduino.h
  Wrote _arduino/projects/controller/tempore_program.h
  Wrote _arduino/projects/controller/tempore_program.cpp
  $ cat _arduino/projects/controller/tempore_program.h
  // The program controller.tpe, compiled by Tempore.
  
  #ifndef TEMPORE_PROGRAM_H
  #define TEMPORE_PROGRAM_H
  
  #include "tempore_arduino.h"
  
  // Types.
  struct tempore_tuple0 {
    float c0;
    float c1;
  };
  
  struct tempore_tuple1 {
    const char * c0;
    float c1;
  };
  
  struct tempore_tuple2 {
    float c0;
    float c1;
    float c2;
  };
  
  struct gains_0 {
    enum class Tag : uint8_t { Gains_1 };
    Tag tag;
    union {
      tempore_tuple2 Gains_1;
    } arg;
    static gains_0 make_Gains_1(tempore_tuple2 a) {
      gains_0 v{};
      v.tag = Tag::Gains_1;
      v.arg.Gains_1 = a;
      return v;
    }
  };
  
  struct tempore_tuple3 {
    float c0;
    tempore_tuple0 c1;
  };
  
  // Comparisons.
  inline int tempore_compare(const tempore_tuple0 &a, const tempore_tuple0 &b) {
    const int c0 = tempore_compare_float(a.c0, b.c0);
    if (c0 != 0) return c0;
    return tempore_compare_float(a.c1, b.c1);
  }
  
  inline int tempore_compare(const tempore_tuple2 &a, const tempore_tuple2 &b) {
    const int c0 = tempore_compare_float(a.c0, b.c0);
    if (c0 != 0) return c0;
    const int c1 = tempore_compare_float(a.c1, b.c1);
    if (c1 != 0) return c1;
    return tempore_compare_float(a.c2, b.c2);
  }
  
  inline int tempore_compare(const gains_0 &a, const gains_0 &b) {
    if (a.tag != b.tag) return a.tag < b.tag ? -1 : 1;
    switch (a.tag) {
      case gains_0::Tag::Gains_1:
        return tempore_compare(a.arg.Gains_1, b.arg.Gains_1);
      default:
        return 0;
    }
  }
  
  inline int tempore_compare(const tempore_tuple3 &a, const tempore_tuple3 &b) {
    const int c0 = tempore_compare_float(a.c0, b.c0);
    if (c0 != 0) return c0;
    return tempore_compare(a.c1, b.c1);
  }
  
  // Operations, implemented outside the program.
  float tempore_op_ReadAngle(tempore_unit);
  tempore_unit tempore_op_Drive(tempore_tuple1);
  
  // Entry points.
  tempore_tuple3 pid_5(gains_0, tempore_tuple0, float);
  tempore_tuple0 step_7(tempore_tuple0);
  
  #endif
  $ cat _arduino/projects/controller/tempore_program.cpp
  // The program controller.tpe, compiled by Tempore.
  
  #include "tempore_program.h"
  
  // Constants.
  static const gains_0 gains_6 = gains_0::make_Gains_1(tempore_tuple2{20.0f, 0.5f, 0.8f});
  
  tempore_tuple3 pid_5(gains_0 tempore_a0, tempore_tuple0 tempore_a1, float error_19) {
    const float kp_14 = tempore_a0.arg.Gains_1.c0;
    const float ki_15 = tempore_a0.arg.Gains_1.c1;
    const float kd_16 = tempore_a0.arg.Gains_1.c2;
    const float integral_17 = tempore_a1.c0;
    const float previous_18 = tempore_a1.c1;
    const float integral_20 = (integral_17 + error_19);
    const float b_21 = (kp_14 * error_19);
    const float b_22 = (ki_15 * integral_20);
    const float b_23 = (b_21 + b_22);
    const float b_24 = (error_19 - previous_18);
    const float b_25 = (kd_16 * b_24);
    const float b_26 = (b_23 + b_25);
    return tempore_tuple3{b_26, tempore_tuple0{integral_20, error_19}};
  }
  
  tempore_tuple0 step_7(tempore_tuple0 state_27) {
    const float angle_28 = tempore_op_ReadAngle(tempore_unit{});
    const float b_29 = (0.0f - angle_28);
    const tempore_tuple3 tempore_t0 = pid_5(gains_6, state_27, b_29);
    const float u_30 = tempore_t0.c0;
    const tempore_tuple0 state_31 = tempore_t0.c1;
    tempore_delay(2u, 1u);
    static_cast<void>(tempore_op_Drive(tempore_tuple1{"motor", u_30}));
    return state_31;
  }

The program compiles without warnings, the operations and the time API being
implemented outside it.

  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -c \
  >   -o controller.o _arduino/projects/controller/tempore_program.cpp

A path with a directory component names the directory itself. With
--host-runs, the run commands are compiled too, with a main program for the
host, in which a delay returns at once and an operation call is a run-time
error.

  $ ../../tempore --emit-arduino out/controller --host-runs controller.tpe
  Wrote out/controller/tempore_arduino.h
  Wrote out/controller/tempore_program.h
  Wrote out/controller/tempore_program.cpp
  Wrote out/controller/tempore_host_main.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -o controller.host \
  >   out/controller/tempore_program.cpp out/controller/tempore_host_main.cpp
  $ ./controller.host
  === Run 1 ===
  return (10.6499996185, (0.5, 0.5))
  
  Run-time error: Unhandled operation ReadAngle
  [3]

The options of the Arduino backend are checked.

  $ ../../tempore --host-runs controller.tpe
  ../../tempore: option '--host-runs' requires '--emit-arduino'.
  [2]
  $ ../../tempore --emit-arduino controller --timeline controller.tpe
  ../../tempore: option '--timeline' cannot be used with '--emit-arduino'.
  [2]
  $ ../../tempore --emit-arduino controller --emit-opentrons controller.py controller.tpe
  ../../tempore: option '--emit-arduino' cannot be used with '--emit-opentrons'.
  [2]
