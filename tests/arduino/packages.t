The peripheral packages of the Arduino backend: their declarations, loaded by
--package for runs of the interpreter and by the packages of a manifest, their
C++ sources and host models on the simulated I2C bus and world, and the
capabilities of the boards they require.

  $ emit () { ../../tempore --grades time-interval-rational --emit-arduino "$@"; }
  $ simulate () { emit "$1" --device "packages/$1.device.json" "packages/${2:-$1}.tpe" --host-simulate "$3" | grep -v '^Wrote'; }

An interpreter run with the declarations of a package, whose operations are
performed by their default implementations, and its attitude filter:

  $ cat > filter.tpe <<'EOF'
  > let read () =
  >   let r = perform ReadImu () in
  >   box [0, 2] r as fresh in
  >   unbox fresh as x in
  >   tilt_x 0.98 0.005 1.0 x
  > run read ()
  > run (tilt_x_of_accel (0.0, 1.0, -1.0), tilt_y_of_accel (-0.5, 0.0, 0.866025403784))
  > EOF
  $ ../../tempore --grades time-interval-rational --package m5-imu filter.tpe
  === Run 1 ===
  return 0.98
  State: [
    [0.5, 0.5],
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] }
  ]
  
  === Run 2 ===
  return (135., 30.)
  State: []
  



Without the package, its operations are unknown; an unknown package, a
package under other grades, and --package with --device are refused:

  $ ../../tempore --grades time-interval-rational filter.tpe 2>&1 | grep error
  Syntax error: Unknown name `ReadImu`
  $ ../../tempore --grades time-interval-rational --package m5-gyro filter.tpe 2>&1 | head -1 | sed 's/^.*tempore: //'
  option '--package': 'm5-gyro' is not one of bala2-base, i2c, m5-display, m5-imu.
  $ ../../tempore --grades time-interval --package m5-imu filter.tpe
  Error: The package m5-imu declares its operations under the grades time-interval-rational, regex-timed-lower-bound-rational-symbolic, regex-timed-upper-bound-rational-symbolic, regex-timed-interval-rational-symbolic, counts-upper-bound, not time-interval
  [1]
  $ emit tilt --device packages/tilt.device.json --package m5-imu packages/tilt.tpe
  ../../tempore: option '--package' cannot be used with '--device'.
  [2]

The tilt display on an M5Stack Gray, with the packages m5-imu and m5-display:
the sources of the packages are copied to src/ and their host models to host/,
the binding functions of the operations performed are declared with the
types of their arguments and results, and the initialisation of the display
is called by setup():

  $ emit tilt --device packages/tilt.device.json packages/tilt.tpe | grep -v 'host/\(tempore\|freertos\|[A-Z]\|esp\)'
  Wrote _arduino/projects/tilt/src/tempore_arduino.h
  Wrote _arduino/projects/tilt/src/tempore_program.h
  Wrote _arduino/projects/tilt/src/tempore_program.cpp
  Wrote _arduino/projects/tilt/platformio.ini
  Wrote _arduino/projects/tilt/src/main.cpp
  Wrote _arduino/projects/tilt/src/tempore_bindings.h
  Wrote _arduino/projects/tilt/src/tempore_operations.cpp
  Wrote _arduino/projects/tilt/src/tempore_scaffold.h
  Wrote _arduino/projects/tilt/src/tempore_scaffold.cpp
  Wrote _arduino/projects/tilt/src/m5_imu.cpp
  Wrote _arduino/projects/tilt/host/m5_imu_model.cpp
  Wrote _arduino/projects/tilt/src/m5_display.cpp
  Wrote _arduino/projects/tilt/host/m5_display_model.cpp
  $ cd _arduino/projects/tilt
  $ sed -n '/The operations performed/,$p' src/tempore_bindings.h
  // The operations performed: the types of their arguments and results, and their binding functions.
  
  #define TEMPORE_PERFORMS_ReadImu
  typedef tempore_unit tempore_argument_ReadImu;
  typedef tempore_tuple2 tempore_result_ReadImu;
  tempore_tuple2 binding_ReadImu(tempore_unit);
  
  #define TEMPORE_PERFORMS_ShowText
  typedef const char * tempore_argument_ShowText;
  typedef tempore_unit tempore_result_ShowText;
  tempore_unit binding_ShowText(const char *);
  
  #define TEMPORE_PERFORMS_ShowNumber
  typedef float tempore_argument_ShowNumber;
  typedef tempore_unit tempore_result_ShowNumber;
  tempore_unit binding_ShowNumber(float);
  
  #define TEMPORE_PERFORMS_ClearDisplay
  typedef tempore_unit tempore_argument_ClearDisplay;
  typedef tempore_unit tempore_result_ClearDisplay;
  tempore_unit binding_ClearDisplay(tempore_unit);
  
  #endif
  $ grep -B 1 -A 12 'The hooks' src/main.cpp
  
  // The hooks of the packages.
  void m5_imu_init();
  void m5_display_init();
  
  void tempore_safe_state() {}
  
  // The periodic task step, of period 50000 us.
  static tempore_task_monitor tempore_task0_monitor("step", 50000);
  
  static void tempore_task0(void *) {
    tempore_check_halt();
    auto state = start_0(tempore_unit{});
    TickType_t release = xTaskGetTickCount();
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

Its host simulation: the model of the unit reads the default world, a body
swinging about the x axis with an amplitude of 0.1 radians; the display writes
its lines to the log:

  $ simulate tilt tilt 0.3
  [0.000 ms] Release step
  [0.000 ms] Start title
  [0.383 ms] IMU accel 0.000 0.100 0.995 g, gyro -0.02 0.00 0.00 deg/s
  [0.383 ms] Operation ReadImu took 383 us
  [1.383 ms] Display: 0.572
  [1.383 ms] Operation ShowNumber took 1000 us
  [31.000 ms] Display cleared
  [31.000 ms] Operation ClearDisplay took 31000 us
  [32.000 ms] Display: Tilt (degrees)
  [32.000 ms] Operation ShowText took 1000 us
  [32.000 ms] End title
  [50.000 ms] Release step
  [50.383 ms] IMU accel 0.000 0.099 0.995 g, gyro -2.83 0.00 0.00 deg/s
  [50.383 ms] Operation ReadImu took 383 us
  [100.000 ms] Release step
  [100.383 ms] IMU accel 0.000 0.095 0.995 g, gyro -5.58 0.00 0.00 deg/s
  [100.383 ms] Operation ReadImu took 383 us
  [150.000 ms] Release step
  [150.383 ms] IMU accel 0.000 0.089 0.996 g, gyro -8.19 0.00 0.00 deg/s
  [150.383 ms] Operation ReadImu took 383 us
  [200.000 ms] Release step
  [200.383 ms] IMU accel 0.000 0.081 0.997 g, gyro -10.59 0.00 0.00 deg/s
  [200.383 ms] Operation ReadImu took 383 us
  [250.000 ms] Release step
  [250.383 ms] IMU accel 0.000 0.071 0.998 g, gyro -12.74 0.00 0.00 deg/s
  [250.383 ms] Operation ReadImu took 383 us
  [251.383 ms] Display: 0.774
  [251.383 ms] Operation ShowNumber took 1000 us
  [300.000 ms] End of the simulation

A host model of the application that defines the world replaces the default
world:

  $ simulate still tilt 0.06
  [0.000 ms] Release step
  [0.000 ms] Start title
  [0.383 ms] IMU accel 0.000 0.479 0.878 g, gyro 0.00 0.00 0.00 deg/s
  [0.383 ms] Operation ReadImu took 383 us
  [1.383 ms] Display: 2.865
  [1.383 ms] Operation ShowNumber took 1000 us
  [31.000 ms] Display cleared
  [31.000 ms] Operation ClearDisplay took 31000 us
  [32.000 ms] Display: Tilt (degrees)
  [32.000 ms] Operation ShowText took 1000 us
  [32.000 ms] End title
  [50.000 ms] Release step
  [50.383 ms] IMU accel 0.000 0.479 0.878 g, gyro 0.00 0.00 0.00 deg/s
  [50.383 ms] Operation ReadImu took 383 us
  [60.000 ms] End of the simulation

The drive of the BALA2 base, with the packages bala2-base and m5-display: the
transactions with the base on the simulated I2C bus, the counts of its
encoders from the wheels of the world, which decrease in its registers as a
positive drive turns a wheel, as on the base, and increase as read by
ReadEncoders, and its watchdog, which stops the
motors 200 ms after the last setpoint (checked every 10 ms). The motors are
stopped by the initialisation of the package and in the safe state, before
the safe-state hook of the application:

  $ simulate drive drive 0.5
  [0.000 ms] I2C 0x3a write 00 00 00 00 00
  [0.135 ms] Start drive
  [0.135 ms] I2C 0x3a write 10 00 00 00 00 00 00 00 00
  [0.360 ms] Operation ResetEncoders took 225 us
  [0.360 ms] I2C 0x3a write 00 02 00 ff 00
  [0.495 ms] Operation SetMotors took 135 us
  [0.495 ms] Delay 100000 us
  [100.495 ms] I2C 0x3a write 10
  [100.495 ms] I2C 0x3a read ff ff ff be 00 00 00 22
  [100.743 ms] Operation ReadEncoders took 248 us
  [101.743 ms] Display: 66.000
  [101.743 ms] Operation ShowNumber took 1000 us
  [102.743 ms] Display: -34.000
  [102.743 ms] Operation ShowNumber took 1000 us
  [102.743 ms] Delay 300000 us
  [210.000 ms] BALA2 base: no motor setpoint for 200 ms; motors stopped
  [210.000 ms] I2C 0x3a write 00 00 00 00 00
  [402.743 ms] I2C 0x3a write 10
  [402.743 ms] I2C 0x3a read ff ff ff 74 00 00 00 47
  [402.991 ms] Operation ReadEncoders took 248 us
  [403.991 ms] Display: 140.000
  [403.991 ms] Operation ShowNumber took 1000 us
  [404.991 ms] Display: -71.000
  [404.991 ms] Operation ShowNumber took 1000 us
  [404.991 ms] End drive
  [500.000 ms] End of the simulation
  $ grep -A 6 'The hooks' _arduino/projects/drive/src/main.cpp
  // The hooks of the packages.
  void bala2_base_init();
  void m5_display_init();
  void bala2_base_safe_state();
  
  void tempore_safe_state() { bala2_base_safe_state(); }
  
  $ grep 'bala2_base_init' _arduino/projects/drive/src/main.cpp
  void bala2_base_init();
    bala2_base_init();
  $ cd _arduino/projects/drive
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

Raw register transactions with the package i2c on a generic ESP32, against
the host model of the application, a memory at the address 0x50; a read from
an address without a device is a run-time error, which enters the safe state:

  $ simulate memory memory 0.01
  [0.000 ms] Start check
  [0.000 ms] I2C 0x50 write 10 12 34 56 78
  [0.135 ms] Operation I2cWrite32 took 135 us
  [0.135 ms] I2C 0x50 write 10
  [0.135 ms] I2C 0x50 read 12 34 56 78
  [0.293 ms] Operation I2cRead32 took 158 us
  [0.293 ms] Report 305419896
  [0.293 ms] Operation Report took 0 us
  [0.293 ms] I2C 0x50 write 12
  [0.293 ms] I2C 0x50 read 56 78
  [0.406 ms] Operation I2cRead16 took 113 us
  [0.406 ms] Report 22136
  [0.406 ms] Operation Report took 0 us
  [0.406 ms] I2C 0x50 write 11
  [0.406 ms] I2C 0x50 read 34
  [0.496 ms] Operation I2cRead8 took 90 us
  [0.496 ms] Report 52
  [0.496 ms] Operation Report took 0 us
  [0.496 ms] I2C 0x50 write 11 ff
  [0.564 ms] Operation I2cWrite8 took 68 us
  [0.564 ms] I2C 0x50 write 10
  [0.564 ms] I2C 0x50 read 12 ff
  [0.677 ms] Operation I2cRead16 took 113 us
  [0.677 ms] Report 4863
  [0.677 ms] Operation Report took 0 us
  [0.677 ms] I2C 0x50 write 11
  [0.677 ms] I2C 0x50 read ff
  [0.767 ms] Operation I2cReadInt8 took 90 us
  [0.767 ms] Report -1
  [0.767 ms] Operation ReportInt took 0 us
  [0.767 ms] I2C 0x50 write 11
  [0.767 ms] I2C 0x50 read ff 56
  [0.880 ms] Operation I2cReadInt16 took 113 us
  [0.880 ms] Report -170
  [0.880 ms] Operation ReportInt took 0 us
  [0.880 ms] I2C 0x50 write 10
  [0.880 ms] I2C 0x50 read 12 ff 56 78
  [1.038 ms] Operation I2cReadInt32 took 158 us
  [1.038 ms] Report 318723704
  [1.038 ms] Operation ReportInt took 0 us
  [1.038 ms] I2C 0x51 write 00: not acknowledged
  [1.061 ms] Run-time error: I2C: read not acknowledged
  [1.061 ms] Safe state
  [1.061 ms] Memory check stopped
  [1.061 ms] Task check stopped
  [10.000 ms] End of the simulation
  $ cd _arduino/projects/memory
  $ c++ -std=c++17 -Wall -Wextra -Werror -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

Two tasks share the bus: the second waits for the lock of the I2C buses until
the transaction of the first ends:

  $ simulate shared memory 0.01
  [0.000 ms] Start probe
  [0.000 ms] I2C 0x50 write 10
  [0.000 ms] I2C 0x50 read 00 00 00 00
  [0.000 ms] Start probe
  [0.158 ms] Operation I2cRead32 took 158 us
  [0.158 ms] Report 0
  [0.158 ms] Operation Report took 0 us
  [0.158 ms] End probe
  [0.158 ms] I2C 0x50 write 10
  [0.158 ms] I2C 0x50 read 00 00 00 00
  [0.316 ms] Operation I2cRead32 took 316 us
  [0.316 ms] Report 0
  [0.316 ms] Operation Report took 0 us
  [0.316 ms] End probe
  [10.000 ms] End of the simulation

A repeated free task calls its function again each time it returns:

  $ simulate tick tick 0.35
  [0.000 ms] Start tick
  [1.000 ms] Display: Tick
  [1.000 ms] Operation ShowText took 1000 us
  [1.000 ms] Delay 100000 us
  [101.000 ms] End tick
  [101.000 ms] Start tick
  [102.000 ms] Display: Tick
  [102.000 ms] Operation ShowText took 1000 us
  [102.000 ms] Delay 100000 us
  [202.000 ms] End tick
  [202.000 ms] Start tick
  [203.000 ms] Display: Tick
  [203.000 ms] Operation ShowText took 1000 us
  [203.000 ms] Delay 100000 us
  [303.000 ms] End tick
  [303.000 ms] Start tick
  [304.000 ms] Display: Tick
  [304.000 ms] Operation ShowText took 1000 us
  [304.000 ms] Delay 100000 us
  [350.000 ms] End of the simulation
  $ grep -A 9 'The repeated free task' _arduino/projects/tick/src/main.cpp
  // The repeated free task tick.
  static void tempore_task0(void *) {
    for (;;) {
      tempore_check_halt();
      tempore_trace("Start %s", "tick");
      tick_0(tempore_unit{});
      tempore_trace("End %s", "tick");
    }
  }
  

A repeated free task whose function may take no time, a periodic task with
the member 'repeat', a package whose capability the board lacks, a package
listed twice, a binding file that defines a binding function of a package, an
unknown package and a package under other grades are refused:

  $ reject () { ../../tempore --grades "${3:-time-interval-rational}" --emit-arduino rejected --device "$1" "$2"; echo "exit $?"; test ! -e _arduino/projects/rejected; }
  $ sed 's/"tick"/"spin"/' packages/tick.device.json > m.json
  $ reject m.json packages/tick.tpe
  File "m.json", line 3, characters 27-33:
  3 |   "tasks": [ { "function": "spin", "kind": "free", "repeat": true } ],
                                 ^^^^^^
  Compilation error: The effect `[0, 0]` of the function 'spin' of a repeated free task does not bound its durations below by a positive time, so that the task may never yield
  exit 1
  $ printf '{ "board": "m5stack-gray", "tasks": [ { "function": "tick", "kind": "periodic", "period": 200, "repeat": false } ], "packages": ["m5-display"] }\n' > m.json
  $ reject m.json packages/tick.tpe
  File "m.json", line 1, characters 105-110:
  1 | { "board": "m5stack-gray", "tasks": [ { "function": "tick", "kind": "periodic", "period": 200, "repeat": false } ], "packages": ["m5-display"] }
                                                                                                               ^^^^^
  Compilation error: A periodic task is repeated by its period; the member 'repeat' is for free tasks
  exit 1
  $ sed 's/m5stack-gray/esp32-devkit/' packages/tilt.device.json > m.json
  $ reject m.json packages/tilt.tpe
  File "m.json", line 8, characters 15-23:
  8 |   "packages": ["m5-imu", "m5-display"]
                     ^^^^^^^^
  Compilation error: The package m5-imu requires the capability m5unified, which the board esp32-devkit lacks; its capabilities are: i2c
  exit 1
  $ sed 's/"m5-display"]/"m5-display", "m5-imu"]/' packages/tilt.device.json > m.json
  $ reject m.json packages/tilt.tpe
  File "m.json", line 8, characters 39-47:
  8 |   "packages": ["m5-imu", "m5-display", "m5-imu"]
                                             ^^^^^^^^
  Compilation error: The package 'm5-imu' is listed twice
  exit 1
  $ cp packages/memory_model.cpp .
  $ sed 's|memory_bindings.cpp|bindings.cpp|' packages/memory.device.json > m.json
  $ (cat packages/memory_bindings.cpp; printf 'tempore_result_I2cRead8 binding_I2cRead8(tempore_argument_I2cRead8) { return 0; }\n') > bindings.cpp
  $ reject m.json packages/memory.tpe
  File "m.json", line 5, characters 14-28:
  5 |   "bindings": "bindings.cpp",
                    ^^^^^^^^^^^^^^
  Compilation error: The binding file bindings.cpp defines the function binding_I2cRead8 of the operation I2cRead8, which the package i2c defines
  exit 1
  $ sed 's/"i2c"/"spi"/' packages/memory.device.json > m.json
  $ reject m.json packages/memory.tpe
  File "m.json", line 4, characters 15-20:
  4 |   "packages": ["spi"],
                     ^^^^^
  Compilation error: Unknown package 'spi'; accepted: bala2-base, i2c, m5-display, m5-imu
  exit 1
  $ reject packages/memory.device.json packages/memory.tpe time-interval
  File "packages/memory.device.json", line 4, characters 15-20:
  4 |   "packages": ["i2c"],
                     ^^^^^
  Compilation error: The package i2c declares its operations under the grades time-interval-rational, regex-timed-lower-bound-rational-symbolic, regex-timed-upper-bound-rational-symbolic, regex-timed-interval-rational-symbolic, counts-upper-bound, not time-interval
  exit 1
