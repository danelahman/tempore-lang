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
    [0.6, 0.6],
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
  option '--package': 'm5-gyro' is not one of bala2-base, bala2-remote, esp-now, i2c, m5-display, m5-imu, m5-speaker, m5-touch.
  $ ../../tempore --grades time-interval --package m5-imu filter.tpe
  Error: The package `m5-imu` declares its operations under the grades `time-interval-rational`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `regex-timed-rigid-lower-bound-rational-symbolic`, `regex-timed-rigid-upper-bound-rational-symbolic`, `regex-timed-rigid-interval-rational-symbolic`, `event-separation`, `counts-upper-bound`, not `time-interval`
  [1]
  $ emit tilt --device packages/tilt.device.json --package m5-imu packages/tilt.tpe
  ../../tempore: option '--package' cannot be used with '--device'.
  [2]

The running-time bounds of the operations of a package on a board, given by
its descriptor, replace those of its declarations for --board, under the
interval grades and under the regular expressions of timed operations; a
board for which the package gives none keeps those of the declarations:

  $ cat > bounds.tpe <<'EOF'
  > let read () : imu # [0.55, 1.25] = perform ReadImu ()
  > EOF
  $ for b in m5stack-gray m5stack-cores3 m5stack-fire; do ../../tempore --grades time-interval-rational --package m5-imu --board $b --typecheck-only bounds.tpe > /dev/null 2>&1; echo "$b [$?]"; done
  m5stack-gray [0]
  m5stack-cores3 [1]
  m5stack-fire [1]
  $ ../../tempore --grades time-interval-rational --package m5-imu --typecheck-only bounds.tpe 2>&1 | grep error
  Typing error: This function's body has grade `[0.2, 1.5]`, which does not match its annotated grade `[0.55, 1.25]`
  $ cat > bounds.tpe <<'EOF'
  > let read () : imu # {[0, 1.3]} = perform ReadImu ()
  > EOF
  $ for b in m5stack-gray m5stack-cores3; do ../../tempore --grades regex-timed-interval-rational-symbolic --package m5-imu --board $b --typecheck-only bounds.tpe 2>&1 | grep error; done
  Typing error: This function's body has grade `[{ReadImu}, {ReadImu}]`, which does not match its annotated grade `[{[0, 1.3]}, {[0, 1.3]}]`

The default implementations take a time within the bounds of every board, so
that the declarations of each package load under each of its grade systems
on each board:

  $ touch empty.tpe
  $ for p in bala2-base esp-now i2c m5-display m5-imu; do for g in time-interval-rational regex-timed-lower-bound-rational-symbolic regex-timed-upper-bound-rational-symbolic regex-timed-interval-rational-symbolic event-separation counts-upper-bound; do for b in m5stack-gray m5stack-cores3 esp32-devkit; do ../../tempore --grades $g --package $p --board $b --typecheck-only empty.tpe || echo "$p $g $b"; done; done; done

The option --board needs --package and names a board profile:

  $ ../../tempore --grades time-interval-rational --board m5stack-gray filter.tpe
  ../../tempore: option '--board' requires '--package'.
  [2]
  $ ../../tempore --grades time-interval-rational --package m5-imu --board m5stack-grey filter.tpe 2>&1 | head -1 | sed 's/^.*tempore: //'
  option '--board': 'm5stack-grey' is not one of esp32-devkit, esp32s3-devkit, m5stack-core2, m5stack-cores3, m5stack-fire, m5stack-gray.

The tilt display on an M5Stack Gray, with the packages m5-imu and m5-display:
the sources of the packages are copied to src/ and their host models to host/,
the binding functions of the operations performed are declared with the
types of their arguments and results, as are the initialisation functions of
the packages, and these are called by setup():

  $ emit tilt --device packages/tilt.device.json packages/tilt.tpe | grep -v 'host/\(tempore\|freertos\|[A-Z]\|esp\)'
  Wrote _arduino/projects/tilt/src/tempore_arduino.h
  Wrote _arduino/projects/tilt/src/tempore_program.h
  Wrote _arduino/projects/tilt/src/tempore_program.cpp
  Wrote _arduino/projects/tilt/platformio.ini
  Wrote _arduino/projects/tilt/src/main.cpp
  Wrote _arduino/projects/tilt/src/tempore_bindings.h
  Wrote _arduino/projects/tilt/src/tempore_operations.cpp
  Wrote _arduino/projects/tilt/src/tempore_m5_monitor.cpp
  Wrote _arduino/projects/tilt/src/tempore_i2c.h
  Wrote _arduino/projects/tilt/src/tempore_scaffold.cpp
  Wrote _arduino/projects/tilt/src/tempore_scaffold.h
  Wrote _arduino/projects/tilt/src/m5_imu.cpp
  Wrote _arduino/projects/tilt/host/m5_imu_model.cpp
  Wrote _arduino/projects/tilt/src/m5_display.cpp
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
  
  // The initialisation and safe-state functions of the packages.
  void m5_imu_init();
  void m5_display_init();
  
  #endif
  $ grep -B 1 -A 8 'The display of the events' src/main.cpp
  
  // The display of the events of the monitor on the screen.
  extern const tempore_monitor_display tempore_m5_monitor_display;
  
  void tempore_safe_state() {}
  
  // The periodic task step, of period 50000 us.
  static tempore_task_monitor tempore_task0_monitor("step", 50000);
  
  static void tempore_task0(void *) {
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

The monitors of the device check the running-time bounds of the board of
the manifest, those of ReadImu on the M5Stack Gray and, for the same
manifest on the M5Stack CoreS3, those on the CoreS3:

  $ grep 'bounds_ReadImu = ' _arduino/projects/tilt/src/tempore_operations.cpp
  static const tempore_bounds tempore_bounds_ReadImu = {550, false, 1250, false, true};
  $ sed 's/m5stack-gray/m5stack-cores3/' packages/tilt.device.json > cores3.device.json
  $ emit cores3 --device cores3.device.json packages/tilt.tpe > /dev/null
  $ grep 'bounds_ReadImu = ' _arduino/projects/cores3/src/tempore_operations.cpp
  static const tempore_bounds tempore_bounds_ReadImu = {200, false, 1500, false, true};

Its host simulation: the model of the unit reads the default world, a body
swinging about the x axis with an amplitude of 0.1 radians; the display writes
its lines to the log:

  $ simulate tilt tilt 0.3
  [0.000 ms] Release step
  [0.000 ms] Start title
  [0.603 ms] IMU accel 0.000 0.100 0.995 g, gyro -0.03 0.00 0.00 deg/s
  [0.603 ms] Operation ReadImu took 603 us
  [31.000 ms] Display cleared
  [31.000 ms] Operation ClearDisplay took 31000 us
  [32.000 ms] Display: Tilt (degrees)
  [32.000 ms] Operation ShowText took 1000 us
  [32.000 ms] End title
  [33.000 ms] Display: 0.571
  [33.000 ms] Operation ShowNumber took 32397 us
  [33.000 ms] Monitor: operation ShowNumber took 32397 us, outside its running-time bounds [50, 12500] us
  [33.000 ms] Safe state entered
  [45.288 ms] Display fill at (0, 72), 320 by 96: 0xc00000
  [46.728 ms] Display at (28, 84): Stopped by the monitor
  [48.228 ms] Display at (10, 112): ShowNumber took 32.397 ms
  [49.608 ms] Display at (46, 136): bounds 0.05-12.5 ms
  [49.608 ms] Task step stopped
  [300.000 ms] End of the simulation

A host model of the application that defines the world replaces the default
world:

  $ simulate still tilt 0.06
  [0.000 ms] Release step
  [0.000 ms] Start title
  [0.603 ms] IMU accel 0.000 0.479 0.878 g, gyro 0.00 0.00 0.00 deg/s
  [0.603 ms] Operation ReadImu took 603 us
  [31.000 ms] Display cleared
  [31.000 ms] Operation ClearDisplay took 31000 us
  [32.000 ms] Display: Tilt (degrees)
  [32.000 ms] Operation ShowText took 1000 us
  [32.000 ms] End title
  [33.000 ms] Display: 2.865
  [33.000 ms] Operation ShowNumber took 32397 us
  [33.000 ms] Monitor: operation ShowNumber took 32397 us, outside its running-time bounds [50, 12500] us
  [33.000 ms] Safe state entered
  [45.288 ms] Display fill at (0, 72), 320 by 96: 0xc00000
  [46.728 ms] Display at (28, 84): Stopped by the monitor
  [48.228 ms] Display at (10, 112): ShowNumber took 32.397 ms
  [49.608 ms] Display at (46, 136): bounds 0.05-12.5 ms
  [49.608 ms] Task step stopped
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
  [0.245 ms] Start drive
  [0.245 ms] I2C 0x3a write 10 00 00 00 00 00 00 00 00
  [0.580 ms] Operation ResetEncoders took 335 us
  [0.580 ms] I2C 0x3a write 00 02 00 ff 00
  [0.825 ms] Operation SetMotors took 245 us
  [0.825 ms] Delay 100000 us
  [100.825 ms] I2C 0x3a write 10
  [100.825 ms] I2C 0x3a read ff ff ff bd 00 00 00 22
  [101.293 ms] Operation ReadEncoders took 468 us
  [102.293 ms] Display: 67.000
  [102.293 ms] Operation ShowNumber took 1000 us
  [103.293 ms] Display: -34.000
  [103.293 ms] Operation ShowNumber took 1000 us
  [103.293 ms] Delay 300000 us
  [210.000 ms] I2C 0x3a write 00 00 00 00 00
  [210.245 ms] BALA2 base: no motor setpoint for 200 ms; motors stopped
  [403.293 ms] I2C 0x3a write 10
  [403.293 ms] I2C 0x3a read ff ff ff 74 00 00 00 47
  [403.761 ms] Operation ReadEncoders took 468 us
  [404.761 ms] Display: 140.000
  [404.761 ms] Operation ShowNumber took 1000 us
  [405.761 ms] Display: -71.000
  [405.761 ms] Operation ShowNumber took 1000 us
  [405.761 ms] End drive
  [500.000 ms] End of the simulation
  $ grep -A 3 'functions of the packages' _arduino/projects/drive/src/tempore_bindings.h
  // The initialisation and safe-state functions of the packages.
  void bala2_base_init();
  void m5_display_init();
  void bala2_base_safe_state();
  $ grep 'bala2_base_init' _arduino/projects/drive/src/main.cpp
    bala2_base_init();
  $ cd _arduino/projects/drive
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

A link over ESP-NOW with the package esp-now. LinkStart starts the radio,
which the host model starts in 100 ms, and logs the address of the station
and of the peer; Send logs its packet. Receive returns the latest packet of
the peer of the host model of the application, which sends one every 20 ms
until 160 ms, arriving 2 ms later, if it arrived at most 50 ms ago, and
otherwise nothing:

  $ simulate radio radio 0.35
  [0.000 ms] Start listen
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF
  [100.000 ms] Operation LinkStart took 100000 us
  [100.100 ms] ESP-NOW: sent tag 1, 0.500, -0.250
  [100.100 ms] Operation Send took 100 us
  [100.100 ms] Operation Receive took 0 us
  [101.100 ms] Display: None
  [101.100 ms] Operation ShowText took 1000 us
  [101.100 ms] Delay 60000 us
  [122.000 ms] ESP-NOW model: packet of tag 6 arrives
  [142.000 ms] ESP-NOW model: packet of tag 7 arrives
  [161.100 ms] Operation Receive took 0 us
  [162.000 ms] ESP-NOW model: packet of tag 8 arrives
  [162.100 ms] Display: 7.000
  [162.100 ms] Operation ShowNumber took 1000 us
  [162.100 ms] Delay 60000 us
  [222.100 ms] Operation Receive took 0 us
  [223.100 ms] Display: None
  [223.100 ms] Operation ShowText took 1000 us
  [223.100 ms] Delay 60000 us
  [283.100 ms] End listen
  [350.000 ms] End of the simulation
  $ grep -A 1 'tempore_argument_Receive;' _arduino/projects/radio/src/tempore_bindings.h
  typedef uint32_t tempore_argument_Receive;
  typedef tempore_tuple1 tempore_result_Receive;

The peer of the build flag ESP_NOW_PEER, and a model of the link that loses
every second packet:

  $ cd _arduino/projects/radio
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DESP_NOW_MODEL_LOSS=2 -DESP_NOW_PEER=0x24,0x0a,0xc4,0x00,0x00,0x07 -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 200000 | grep 'ESP-NOW\|Display'
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer 24:0A:C4:00:00:07
  [100.100 ms] ESP-NOW: sent tag 1, 0.500, -0.250
  [101.100 ms] Display: None
  [122.000 ms] ESP-NOW model: packet of tag 6 arrives
  [140.000 ms] ESP-NOW model: packet of tag 7 lost
  [162.000 ms] ESP-NOW model: packet of tag 8 arrives
  [162.100 ms] Display: 6.000
  $ cd ../../..

A Send before LinkStart is a run-time error:

  $ printf '{ "board": "m5stack-gray", "tasks": [ { "function": "early", "kind": "free" } ], "packages": ["esp-now", "m5-display"] }\n' > early.device.json
  $ emit early --device early.device.json packages/radio.tpe --host-simulate 0.01 | grep -v '^Wrote'
  [0.000 ms] Start early
  [0.000 ms] Run-time error: ESP-NOW: Send before LinkStart
  [0.000 ms] Safe state entered
  [0.000 ms] Task early stopped
  [10.000 ms] End of the simulation

The messages of the remote control of the BALA2, with the package
bala2-remote over esp-now: the initial function sends one message of each
kind, and the step shows the message received. The peer of the host model of
the application sends Arm, Drive (0.5, -0.25), a packet of the unknown tag 9,
Disarm and Beat, one every 20 ms, and then nothing; the unknown tag, and Beat
once older than 50 ms, decode to Nothing:

  $ simulate remote remote 0.3 | grep 'ESP-NOW\|Display'
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF
  [100.100 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [100.200 ms] ESP-NOW: sent tag 2, 0.500, -0.250
  [100.300 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [100.400 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [101.400 ms] Display: Nothing
  [121.000 ms] Display: Nothing
  [122.000 ms] ESP-NOW model: packet of tag 1 arrives
  [141.000 ms] Display: Arm
  [142.000 ms] ESP-NOW model: packet of tag 2 arrives
  [161.000 ms] Display: 0.500
  [162.000 ms] ESP-NOW model: packet of tag 9 arrives
  [181.000 ms] Display: Nothing
  [182.000 ms] ESP-NOW model: packet of tag 3 arrives
  [201.000 ms] Display: Disarm
  [202.000 ms] ESP-NOW model: packet of tag 4 arrives
  [221.000 ms] Display: Beat
  [241.000 ms] Display: Beat
  [261.000 ms] Display: Nothing
  [281.000 ms] Display: Nothing
  $ cd _arduino/projects/remote
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

A message received is used within 150 ms of its reception, under
time-interval-rational and the regular expressions of timed operations with
intervals or upper bounds:

  $ cat > window.tpe <<'EOF'
  > let soon () =
  >   let fresh = remote_receive () in
  >   remote_send Beat;
  >   delay 140;
  >   unbox fresh as r in
  >   r
  > let late () =
  >   let fresh = remote_receive () in
  >   remote_send Beat;
  >   delay 150;
  >   unbox fresh as r in
  >   r
  > EOF
  $ for g in time-interval-rational regex-timed-upper-bound-rational-symbolic regex-timed-interval-rational-symbolic; do ../../tempore --grades $g --package esp-now --package bala2-remote --typecheck-only window.tpe 2>&1 | grep error; done
  Typing error: Variable `fresh` is unboxed with grade `[150, 151]` accumulated since it was bound, which is not below its box grade `[0, 150)`
  Typing error: Variable `fresh` is unboxed with grade `{Send; 150}` accumulated since it was bound, which is not below its box grade `{[0, 150)}`
  Typing error: Variable `fresh` is unboxed with grade `[{Send; 150}, {Send; 150}]` accumulated since it was bound, which is not below its box grade `[{0}, {[0, 150)}]`

Under the rigid grades a message received comes in two boxes: the message,
its setpoints zero, usable while no further Receive has come, and its
setpoints, usable within 150 ms; a use after 150 ms fails the second, and a
use after a further Receive the first:

  $ cat > latest.tpe <<'EOF'
  > let soon () =
  >   let latest, fresh = remote_receive () in
  >   remote_send Beat;
  >   delay 140;
  >   unbox latest as r in
  >   unbox fresh as setpoints in
  >   (r, setpoints)
  > let late () =
  >   let latest, fresh = remote_receive () in
  >   remote_send Beat;
  >   delay 150;
  >   unbox latest as r in
  >   unbox fresh as setpoints in
  >   (r, setpoints)
  > let again () =
  >   let latest, fresh = remote_receive () in
  >   let _ = remote_receive () in
  >   unbox latest as r in
  >   unbox fresh as setpoints in
  >   (r, setpoints)
  > EOF
  $ for g in regex-timed-rigid-upper-bound-rational-symbolic regex-timed-rigid-interval-rational-symbolic; do ../../tempore --grades $g --package esp-now --package bala2-remote --typecheck-only latest.tpe 2>&1 | grep error; done
  Typing error: Variable `fresh` is unboxed with grade `{Send; !150}` accumulated since it was bound, which is not below its box grade `{[0, 150)}`
  Typing error: Variable `latest` is unboxed with grade `{Receive}` accumulated since it was bound, which is not below its box grade `{(!_ & ~Receive)*}`
  Typing error: Variable `fresh` is unboxed with grade `[{Send; !150}, {Send; !150}]` accumulated since it was bound, which is not below its box grade `[{0}, {[0, 150)}]`
  Typing error: Variable `latest` is unboxed with grade `[{Receive}, {Receive}]` accumulated since it was bound, which is not below its box grade `[{(!_ & ~Receive)*}, {(!_ & ~Receive)*}]`

Under the rigid grades, read_imu_boxed of the package m5-imu reads the unit
once and returns the reading as the latest and as recent: a use after a
further reading fails the first box, and a use after a display call of up to
33 ms the second:

  $ cat > boxed.tpe <<'EOF'
  > let at_once () =
  >   let latest, recent = read_imu_boxed () in
  >   unbox latest as a in
  >   unbox recent as b in
  >   (a, b)
  > let again () =
  >   let latest, _ = read_imu_boxed () in
  >   let _ = perform ReadImu () in
  >   unbox latest as a in
  >   a
  > let shown () =
  >   let _, recent = read_imu_boxed () in
  >   perform ShowTextAt (0, 0, 2, "Tilt");
  >   unbox recent as b in
  >   b
  > EOF
  $ for g in regex-timed-rigid-upper-bound-rational-symbolic regex-timed-rigid-interval-rational-symbolic; do ../../tempore --grades $g --package m5-imu --package m5-display --board m5stack-cores3 --typecheck-only boxed.tpe 2>&1 | grep error; done
  Typing error: Variable `latest` is unboxed with grade `{ReadImu}` accumulated since it was bound, which is not below its box grade `{(!_ & ~ReadImu)*}`
  Typing error: Variable `recent` is unboxed with grade `{ShowTextAt}` accumulated since it was bound, which is not below its box grade `{[0, 2]}`
  Typing error: Variable `latest` is unboxed with grade `[{ReadImu}, {ReadImu}]` accumulated since it was bound, which is not below its box grade `[{(!_ & ~ReadImu)*}, {(!_ & ~ReadImu)*}]`
  Typing error: Variable `recent` is unboxed with grade `[{ShowTextAt}, {ShowTextAt}]` accumulated since it was bound, which is not below its box grade `[{0}, {2}]`

The package needs esp-now, listed before it:

  $ ../../tempore --grades time-interval-rational --package bala2-remote --package esp-now --typecheck-only window.tpe
  Error: The package `bala2-remote` needs the package `esp-now`, listed before it
  [1]
  $ sed 's/"esp-now", "bala2-remote"/"bala2-remote", "esp-now"/' packages/remote.device.json > m.json
  $ ../../tempore --grades time-interval-rational --emit-arduino rejected --device m.json packages/remote.tpe
  File "m.json", line 8, characters 15-29:
  8 |   "packages": ["bala2-remote", "esp-now", "m5-display"]
                     ^^^^^^^^^^^^^^
  Compilation error: The package `bala2-remote` needs the package `esp-now`, listed before it
  [1]

Raw register transactions with the package i2c on a generic ESP32, against
the host model of the application, a memory at the address 0x50; a read from
an address without a device is a run-time error, which enters the safe state:

  $ simulate memory memory 0.01
  [0.000 ms] Start check
  [0.000 ms] I2C 0x50 write 10 12 34 56 78
  [0.245 ms] Operation I2cWrite32 took 245 us
  [0.245 ms] I2C 0x50 write 10
  [0.245 ms] I2C 0x50 read 12 34 56 78
  [0.623 ms] Operation I2cRead32 took 378 us
  [0.623 ms] Report 305419896
  [0.623 ms] Operation Report took 0 us
  [0.623 ms] I2C 0x50 write 12
  [0.623 ms] I2C 0x50 read 56 78
  [0.956 ms] Operation I2cRead16 took 333 us
  [0.956 ms] Report 22136
  [0.956 ms] Operation Report took 0 us
  [0.956 ms] I2C 0x50 write 11
  [0.956 ms] I2C 0x50 read 34
  [1.266 ms] Operation I2cRead8 took 310 us
  [1.266 ms] Report 52
  [1.266 ms] Operation Report took 0 us
  [1.266 ms] I2C 0x50 write 11 ff
  [1.444 ms] Operation I2cWrite8 took 178 us
  [1.444 ms] I2C 0x50 write 10
  [1.444 ms] I2C 0x50 read 12 ff
  [1.777 ms] Operation I2cRead16 took 333 us
  [1.777 ms] Report 4863
  [1.777 ms] Operation Report took 0 us
  [1.777 ms] I2C 0x50 write 11
  [1.777 ms] I2C 0x50 read ff
  [2.087 ms] Operation I2cReadInt8 took 310 us
  [2.087 ms] Report -1
  [2.087 ms] Operation ReportInt took 0 us
  [2.087 ms] I2C 0x50 write 11
  [2.087 ms] I2C 0x50 read ff 56
  [2.420 ms] Operation I2cReadInt16 took 333 us
  [2.420 ms] Report -170
  [2.420 ms] Operation ReportInt took 0 us
  [2.420 ms] I2C 0x50 write 10
  [2.420 ms] I2C 0x50 read 12 ff 56 78
  [2.798 ms] Operation I2cReadInt32 took 378 us
  [2.798 ms] Report 318723704
  [2.798 ms] Operation ReportInt took 0 us
  [2.798 ms] I2C 0x51 write 00: not acknowledged
  [2.931 ms] Memory check stopped
  [2.931 ms] Run-time error: I2C: read not acknowledged
  [2.931 ms] Safe state entered
  [2.931 ms] Task check stopped
  [10.000 ms] End of the simulation
  $ cd _arduino/projects/memory
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ cd ../../..

Two tasks share the bus: the second waits for the lock of the I2C buses until
the transaction of the first ends:

  $ simulate shared memory 0.01
  [0.000 ms] Start probe
  [0.000 ms] I2C 0x50 write 10
  [0.000 ms] I2C 0x50 read 00 00 00 00
  [0.000 ms] Start probe
  [0.378 ms] Operation I2cRead32 took 378 us
  [0.378 ms] Report 0
  [0.378 ms] Operation Report took 0 us
  [0.378 ms] End probe
  [0.378 ms] I2C 0x50 write 10
  [0.378 ms] I2C 0x50 read 00 00 00 00
  [0.756 ms] Operation I2cRead32 took 756 us
  [0.756 ms] Report 0
  [0.756 ms] Operation Report took 0 us
  [0.756 ms] End probe
  [10.000 ms] End of the simulation

A repeated free task calls its function again each time it returns, after a
wait of one tick:

  $ simulate tick tick 0.35
  [0.000 ms] Start tick
  [1.000 ms] Display: Tick
  [1.000 ms] Operation ShowText took 1000 us
  [1.000 ms] Delay 100000 us
  [101.000 ms] End tick
  [102.000 ms] Start tick
  [103.000 ms] Display: Tick
  [103.000 ms] Operation ShowText took 1000 us
  [103.000 ms] Delay 100000 us
  [203.000 ms] End tick
  [204.000 ms] Start tick
  [205.000 ms] Display: Tick
  [205.000 ms] Operation ShowText took 1000 us
  [205.000 ms] Delay 100000 us
  [305.000 ms] End tick
  [306.000 ms] Start tick
  [307.000 ms] Display: Tick
  [307.000 ms] Operation ShowText took 1000 us
  [307.000 ms] Delay 100000 us
  [350.000 ms] End of the simulation
  $ grep -A 9 'The repeated free task' _arduino/projects/tick/src/main.cpp
  // The repeated free task tick.
  static void tempore_task0(void *) {
    for (;;) {
      tempore_check_halt();
      tempore_trace("Start %s", "tick");
      tick_0(tempore_unit{});
      tempore_trace("End %s", "tick");
      vTaskDelay(1);
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
  Compilation error: The effect `[0, 0]` of the function `spin` of a repeated free task does not bound its durations below by a positive time, so that the task may never yield
  exit 1
  $ printf '{ "board": "m5stack-gray", "tasks": [ { "function": "tick", "kind": "periodic", "period": 200, "repeat": false } ], "packages": ["m5-display"] }\n' > m.json
  $ reject m.json packages/tick.tpe
  File "m.json", line 1, characters 105-110:
  1 | { "board": "m5stack-gray", "tasks": [ { "function": "tick", "kind": "periodic", "period": 200, "repeat": false } ], "packages": ["m5-display"] }
                                                                                                               ^^^^^
  Compilation error: A periodic task is repeated by its period; the member `repeat` is for free tasks
  exit 1
  $ sed 's/m5stack-gray/esp32-devkit/' packages/tilt.device.json > m.json
  $ reject m.json packages/tilt.tpe
  File "m.json", line 8, characters 15-23:
  8 |   "packages": ["m5-imu", "m5-display"]
                     ^^^^^^^^
  Compilation error: The package `m5-imu` requires the capability `m5unified`, which the board `esp32-devkit` lacks; its capabilities are: `i2c`
  exit 1
  $ sed 's/"m5-display"]/"m5-display", "m5-imu"]/' packages/tilt.device.json > m.json
  $ reject m.json packages/tilt.tpe
  File "m.json", line 8, characters 39-47:
  8 |   "packages": ["m5-imu", "m5-display", "m5-imu"]
                                             ^^^^^^^^
  Compilation error: The package `m5-imu` is listed twice
  exit 1
  $ cp packages/memory_model.cpp .
  $ sed 's|memory_bindings.cpp|bindings.cpp|' packages/memory.device.json > m.json
  $ (cat packages/memory_bindings.cpp; printf 'tempore_result_I2cRead8 binding_I2cRead8(tempore_argument_I2cRead8) { return 0; }\n') > bindings.cpp
  $ reject m.json packages/memory.tpe
  File "m.json", line 5, characters 14-28:
  5 |   "bindings": "bindings.cpp",
                    ^^^^^^^^^^^^^^
  Compilation error: The binding file `bindings.cpp` defines the function `binding_I2cRead8` of the operation `I2cRead8`, which the package `i2c` defines
  exit 1
  $ sed 's/"i2c"/"spi"/' packages/memory.device.json > m.json
  $ reject m.json packages/memory.tpe
  File "m.json", line 4, characters 15-20:
  4 |   "packages": ["spi"],
                     ^^^^^
  Compilation error: Unknown package `spi`; accepted: `bala2-base`, `bala2-remote`, `esp-now`, `i2c`, `m5-display`, `m5-imu`, `m5-speaker`, `m5-touch`
  exit 1
  $ reject packages/memory.device.json packages/memory.tpe time-interval
  File "packages/memory.device.json", line 4, characters 15-20:
  4 |   "packages": ["i2c"],
                     ^^^^^
  Compilation error: The package `i2c` declares its operations under the grades `time-interval-rational`, `regex-timed-lower-bound-rational-symbolic`, `regex-timed-upper-bound-rational-symbolic`, `regex-timed-interval-rational-symbolic`, `regex-timed-rigid-lower-bound-rational-symbolic`, `regex-timed-rigid-upper-bound-rational-symbolic`, `regex-timed-rigid-interval-rational-symbolic`, `event-separation`, `counts-upper-bound`, not `time-interval`
  exit 1
