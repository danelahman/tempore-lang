The make targets of the examples, defined by examples/examples.mk from the
fragment of each example, shown by dry runs, which need neither PlatformIO
nor Python. The variables of the targets are those of the Makefile.

  $ unset MAKEFLAGS MFLAGS MAKELEVEL PORT PORT_M5STACK_GRAY PORT_M5STACK_CORES3 \
  >   CAPTURE SIMULATE MONITOR BALANCE_LOG BALANCE_RECORD PLATFORMIO_BUILD_FLAGS
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

The commands of the headers of the examples, their lines joined:

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

The target -simulate of an Arduino example runs the command of its header
that simulates it on the host, with the monitor policy abort, the default,
given explicitly; the target -log of bala2 runs that of its header under
CAPTURE=60:

  $ for d in examples/arduino/*/; do
  >   n=$(basename "$d"); p=$(basename "$d"*.device.json .device.json)
  >   header=$(commands "$d$p.tpe" | grep -e '--host-simulate')
  >   made=$(dry "arduino-$n-simulate" | sed 's/ --monitor abort//')
  >   [ "$header" = "$made" ] || printf '%s:\n  %s\n  %s\n' "$n" "$header" "$made"
  > done
  $ header=$(commands examples/arduino/bala2/balance.tpe | grep -e '-log')
  $ made=$(dry arduino-bala2-log CAPTURE=60 | tr -d '"')
  $ [ "$header" = "$made" ] || printf '%s\n%s\n' "$header" "$made"

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
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_LOG=50" ./tempore --grades regex-timed-interval-rational-symbolic --emit-arduino balance_regex-log --device examples/arduino/bala2-regex/balance_regex.device.json --monitor abort --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2-regex/balance_regex.tpe
  $ dry arduino-bala2-record BALANCE_RECORD=50
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_RECORD=50" ./tempore --grades time-interval-rational --emit-arduino balance-record --device examples/arduino/bala2/balance.device.json --monitor warn --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2/balance.tpe

The target -capture reads the port without an upload, into a log under
_arduino/recordings, and extracts the recordings from the log:

  $ make -s --no-print-directory -n arduino-bala2-regex-capture CAPTURE=60 |
  >   grep -o -e '\./tempore .*tpe' -e 'awk -f [^ ]*'
  ./tempore --grades regex-timed-interval-rational-symbolic --emit-arduino balance_regex-record --device examples/arduino/bala2-regex/balance_regex.device.json --capture 60 --port /dev/cu.usbserial-02012C91 examples/arduino/bala2-regex/balance_regex.tpe
  awk -f examples/arduino/bala2/recordings.awk
  $ dry arduino-tilt-build SIMULATE=5
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --build examples/arduino/tilt/tilt.tpe
  $ dry arduino-tilt-simulate SIMULATE=5
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --host-simulate 5 examples/arduino/tilt/tilt.tpe
  $ dry opentrons-elisa-emit MONITOR=warn
  ./tempore --grades time-interval --emit-opentrons elisa.py --bind examples/opentrons/elisa_bindings.py --time-unit minutes --monitor warn examples/opentrons/elisa.tpe

The aggregate targets cover every example:

  $ dry opentrons-simulate-all | grep -c tempore
  8
  $ dry arduino-simulate-all | grep -c tempore
  7
  $ dry arduino-build-all | grep -c tempore
  7
