The make targets of the examples, defined by examples/examples.mk from the
fragment of each example, shown by dry runs, which need neither PlatformIO
nor Python. The variables of the targets are those of the Makefile.

  $ unset MAKEFLAGS MFLAGS MAKELEVEL PORT PORT_M5STACK_GRAY PORT_M5STACK_CORES3 \
  >   CAPTURE SIMULATE MONITOR BRIGHTNESS BALANCE_LOG BALANCE_RECORD STEPS_RECORD \
  >   PLATFORMIO_BUILD_FLAGS
  $ cd ../..
  $ dry () {
  >   make -s --no-print-directory -n "$@" |
  >     grep -E '^(PLATFORMIO_BUILD_FLAGS=[^ ]* )?\./tempore ' | tr -s ' '
  > }

Every Opentrons example, other than a rejected variant, and every Arduino
example has its fragment:

  $ for f in examples/opentrons/*.tpe; do
  >   n=$(basename "$f" .tpe)
  >   case $n in *_reject) ;; *)
  >     [ -f "examples/opentrons/$n.mk" ] || echo "$f: no fragment $n.mk";;
  >   esac
  > done
  $ for d in examples/arduino/*/; do
  >   [ -f "${d}example.mk" ] || echo "$d: no fragment example.mk"
  > done

The commands of a file, the headers of the examples or the README of the
Arduino backend, their lines joined:

  $ commands () {
  >   awk '!c && /^ *(PLATFORMIO_BUILD_FLAGS=[^ ]* \\$|\.\/tempore )/ { c = 1; s = "" }
  >        c { l = $0; sub(/\\$/, "", l); s = s " " l
  >            if ($0 !~ /\\$/) { c = 0; gsub(/ +/, " ", s); sub(/^ /, "", s); print s } }' "$1"
  > }

The target -simulate of an Opentrons example runs the command of its header
that simulates it:

  $ for f in examples/opentrons/*.mk; do
  >   n=$(basename "$f" .mk)
  >   header=$(commands "examples/opentrons/$n.tpe" | grep -e '--simulate')
  >   made=$(dry "opentrons-$n-simulate")
  >   [ "$header" = "$made" ] || printf '%s:\n  %s\n  %s\n' "$n" "$header" "$made"
  > done

The header of an Arduino example names its make targets instead of their
commands, which the README of the Arduino backend documents. Each target
that the header names is defined, and the header names the targets -simulate
and -upload of its example:

  $ for d in examples/arduino/*/; do
  >   n=$(basename "$d"); p=$(basename "$d"*.device.json .device.json)
  >   targets=$(awk '{ print } /\*\)$/ && ++c == 2 { exit }' "$d$p.tpe" |
  >     grep -o 'arduino-[a-z0-9-]*' | sort -u)
  >   for t in $targets; do
  >     make -s --no-print-directory -n "$t" > /dev/null 2>&1 ||
  >       echo "$n: no target $t"
  >   done
  >   for t in "arduino-$n-simulate" "arduino-$n-upload"; do
  >     echo "$targets" | grep -qx "$t" || echo "$n: the header does not name $t"
  >   done
  > done

The run command of the header of an Arduino example has the grades of its
target -simulate, and the packages and the board of its manifest:

  $ for d in examples/arduino/*/; do
  >   n=$(basename "$d"); p=$(basename "$d"*.device.json .device.json)
  >   header=$(commands "$d$p.tpe" | head -n 1)
  >   grades=$(dry "arduino-$n-simulate" | grep -o -e '--grades [^ ]*')
  >   packages=$(sed -n 's/.*"packages": *\[\(.*\)\].*/\1/p' "$d$p.device.json" |
  >     tr -d '" ' | tr ',' '\n' | sed 's/^/--package /' | tr '\n' ' ')
  >   board=$(sed -n 's/.*"board": *"\([^"]*\)".*/\1/p' "$d$p.device.json")
  >   expected="./tempore $grades ${packages}--board $board $d$p.tpe"
  >   [ "$header" = "$expected" ] ||
  >     printf '%s:\n  %s\n  %s\n' "$n" "$header" "$expected"
  > done

The commands of the README of the Arduino backend, their lines joined: the
target -simulate of bala2 runs the command of the README that simulates it on
the host, with the monitor policy abort, the default, given explicitly, and
the target -profile runs that of the README under CAPTURE=60:

  $ readme=$(commands src/05-backends/arduino/README.md |
  >   grep -e '--emit-arduino balance')
  $ echo "$readme" | wc -l | tr -d ' '
  2
  $ made=$(dry arduino-bala2-simulate | sed 's/ --monitor abort//')
  $ echo "$readme" | grep -qxF "$made" || echo "$made"
  $ made=$(dry arduino-bala2-profile CAPTURE=60)
  $ echo "$readme" | grep -qxF "$made" || echo "$made"

The uploads go to the port of the board of the manifest, PORT_BOARD, or else
to PORT:

  $ for n in bala2 bala2-regex fall level peak tilt wheels; do
  >   dry "arduino-$n-upload" | grep -o -e '--port [^ ]*' | sed "s|^|$n: |"
  > done
  bala2: --port /dev/cu.usbserial-02012C91
  bala2-regex: --port /dev/cu.usbserial-02012C91
  fall: --port /dev/cu.usbmodem101
  level: --port /dev/cu.usbmodem101
  peak: --port /dev/cu.usbmodem101
  tilt: --port /dev/cu.usbmodem101
  wheels: --port /dev/cu.usbserial-02012C91
  $ dry arduino-tilt-upload PORT_M5STACK_CORES3=/dev/ttyACM0
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --upload --port /dev/ttyACM0 examples/arduino/tilt/tilt.tpe
  $ (export PORT_M5STACK_GRAY=/dev/ttyUSB1; dry arduino-wheels-upload)
  ./tempore --grades regex-timed-interval-rational-symbolic --emit-arduino wheels --device examples/arduino/wheels/wheels.device.json --monitor abort --upload --port /dev/ttyUSB1 examples/arduino/wheels/wheels.tpe
  $ dry arduino-bala2-upload PORT=/dev/ttyUSB0
  ./tempore --grades time-interval-rational --emit-arduino balance --device examples/arduino/bala2/balance.device.json --monitor abort --upload --port /dev/ttyUSB0 examples/arduino/bala2/balance.tpe

A board without a port is an error:

  $ make -s -n arduino-peak-upload PORT_M5STACK_CORES3= 2>&1 | grep -o 'No serial.*'
  No serial port is set for the board m5stack-cores3: set PORT or PORT_M5STACK_CORES3.  Stop.

Further targets, under variables set on the command line:

  $ dry arduino-bala2-profile
  ./tempore --grades time-interval-rational --emit-arduino balance-profile --device examples/arduino/bala2/balance.device.json --monitor warn --profile --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2/balance.tpe
  $ dry arduino-bala2-regex-log BALANCE_LOG=50 MONITOR=abort
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_LOG=50" ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino balance_regex-log --device examples/arduino/bala2-regex/balance_regex.device.json --monitor abort --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2-regex/balance_regex.tpe
  $ dry arduino-bala2-record BALANCE_RECORD=50
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_RECORD=50" ./tempore --grades time-interval-rational --emit-arduino balance-record --device examples/arduino/bala2/balance.device.json --monitor warn --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2/balance.tpe

BRIGHTNESS adds the flag TEMPORE_DISPLAY_BRIGHTNESS to the build flags of
every target that builds a device project, before those of the example:

  $ dry arduino-starter-build BRIGHTNESS=60
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60" ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino starter --device examples/arduino/starter/starter.device.json --monitor abort --build examples/arduino/starter/starter.tpe
  $ for t in starter-upload starter-profile bala2-log bala2-record steps-record; do
  >   make -s --no-print-directory -n "arduino-$t" BRIGHTNESS=60 |
  >     grep -o '^PLATFORMIO_BUILD_FLAGS="[^"]*"'
  > done
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60"
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60"
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60 -DBALANCE_LOG=20"
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60 -DBALANCE_RECORD=20"
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60 -DSTEPS_RECORD=600"

The target -capture reads the port without an upload, into a log under
_arduino/recordings, and extracts the recordings from the log:

  $ make -s --no-print-directory -n arduino-bala2-regex-capture CAPTURE=60 |
  >   grep -o -e '\./tempore .*tpe' -e 'awk -f [^ ]*'
  ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino balance_regex-record --device examples/arduino/bala2-regex/balance_regex.device.json --capture 60 --port /dev/cu.usbserial-02012C91 examples/arduino/bala2-regex/balance_regex.tpe
  awk -f examples/arduino/bala2/recordings.awk

The targets -capture and -erase of steps ask the device for its recordings
and to erase them through the script of its fragment:

  $ make -s --no-print-directory -n arduino-steps-capture arduino-steps-erase CAPTURE=60 |
  >   grep -o 'python3 .*--wait 60'
  python3 -I scripts/steps-recording.py capture --port /dev/cu.usbmodem101 --wait 60
  python3 -I scripts/steps-recording.py erase --port /dev/cu.usbmodem101 --wait 60
  $ dry arduino-steps-record STEPS_RECORD=60
  PLATFORMIO_BUILD_FLAGS="-DSTEPS_RECORD=60" ./tempore --grades event-separation --emit-arduino steps-record --device examples/arduino/steps/steps.device.json --monitor warn --upload --port /dev/cu.usbmodem101 --capture 30 examples/arduino/steps/steps.tpe
  $ dry arduino-tilt-build SIMULATE=5
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --build examples/arduino/tilt/tilt.tpe
  $ dry arduino-tilt-simulate SIMULATE=5
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --host-simulate 5 examples/arduino/tilt/tilt.tpe
  $ dry opentrons-elisa-emit MONITOR=warn
  ./tempore --grades time-interval --emit-opentrons elisa.py --bind examples/opentrons/elisa_bindings.py --time-unit minutes --monitor warn examples/opentrons/elisa.tpe

The aggregate targets cover every example:

  $ dry opentrons-simulate-all | grep -c tempore
  11
  $ dry arduino-simulate-all | grep -c tempore
  10
  $ dry arduino-build-all | grep -c tempore
  10

The help of the examples and that of the diagnostic targets, which are
listed apart:

  $ make -s examples-help
  Arduino examples, by board:
  M5Stack CoreS3, port PORT_M5STACK_CORES3 = /dev/cu.usbmodem101:
    NAME one of: calibrated fall level peak starter steps tilt
    arduino-NAME-simulate         simulates the project on the host
    arduino-NAME-build            builds the project with PlatformIO
    arduino-NAME-upload           builds the project and uploads it to the board
  M5Stack Gray, port PORT_M5STACK_GRAY = /dev/cu.usbserial-02012C91:
    NAME one of: bala2 bala2-regex wheels
    arduino-NAME-simulate         simulates the project on the host
    arduino-NAME-build            builds the project with PlatformIO
    arduino-NAME-upload           builds the project and uploads it to the board
  All Arduino examples:
    arduino-simulate-all          arduino-NAME-simulate for every example
    arduino-build-all             arduino-NAME-build for every example
  Opentrons examples, NAME one of: beads binding cleanup contamination elisa enzyme purification reagents staggered stopread washes
    opentrons-NAME-emit           writes the protocol to _opentrons/protocols/NAME.py
    opentrons-NAME-simulate       writes the protocol and runs the Opentrons simulator
    opentrons-simulate-all        opentrons-NAME-simulate for every example
  Variables, with their values:
    PORT=                                        when set, the port of every upload
    SIMULATE=                                    when set, the simulated seconds of every example
    MONITOR=                                     when set, the monitor policy of every target
    BRIGHTNESS=                                  when set, the display brightness, 0 to 100 % (default 24), of every build
  Diagnostic targets (profiles, logs and recordings): make arduino-diagnostics-help
  $ make -s arduino-diagnostics-help
  Arduino diagnostic targets, by board:
  M5Stack CoreS3, port PORT_M5STACK_CORES3 = /dev/cu.usbmodem101:
    NAME one of: calibrated fall level peak starter steps tilt
    arduino-NAME-profile          uploads the project with the profile and reads the port
    arduino-steps-record          uploads the project with -DSTEPS_RECORD=600 and reads the port
    arduino-steps-capture         reads the recordings from the port into _arduino/recordings/steps-TIME-N.csv
    arduino-steps-erase           erases the recordings on the device
  M5Stack Gray, port PORT_M5STACK_GRAY = /dev/cu.usbserial-02012C91:
    NAME one of: bala2 bala2-regex wheels
    arduino-NAME-profile          uploads the project with the profile and reads the port
    arduino-bala2-log             uploads the project with -DBALANCE_LOG=20 and reads the port
    arduino-bala2-regex-log       uploads the project with -DBALANCE_LOG=20 and reads the port
    arduino-bala2-record          uploads the project with -DBALANCE_RECORD=20 and reads the port
    arduino-bala2-capture         reads the recordings from the port into _arduino/recordings/bala2-TIME.csv
    arduino-bala2-regex-record    uploads the project with -DBALANCE_RECORD=20 and reads the port
    arduino-bala2-regex-capture   reads the recordings from the port into _arduino/recordings/bala2-regex-TIME.csv
  Variables, with their values:
    PORT=                                        when set, the port of every upload
    CAPTURE=30                                   the seconds for which the port is read
    MONITOR=                                     when set, the monitor policy of every target
    BRIGHTNESS=                                  when set, the display brightness, 0 to 100 % (default 24), of every build
