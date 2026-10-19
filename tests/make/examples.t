The make targets of the examples, defined by examples/examples.mk from the
fragment of each example, shown by dry runs, which need neither PlatformIO
nor Python. The variables of the targets are those of the Makefile.

  $ unset MAKEFLAGS MFLAGS MAKELEVEL PORT PORT_M5STACK_GRAY PORT_M5STACK_CORES3 \
  >   PORT_M5STACK_GRAY_RADIO PORT_M5STACK_CORES3_RADIO TEMPORE_DEVICE_LIST \
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
the target -profile runs that of the README under CAPTURE=60 and the port of
the README:

  $ readme=$(commands src/05-backends/arduino/README.md |
  >   grep -e '--emit-arduino balance')
  $ echo "$readme" | wc -l | tr -d ' '
  2
  $ made=$(dry arduino-bala2-simulate | sed 's/ --monitor abort//')
  $ echo "$readme" | grep -qxF "$made" || echo "$made"
  $ made=$(dry arduino-bala2-profile CAPTURE=60 PORT_M5STACK_GRAY=/dev/cu.usbserial-02012C91)
  $ echo "$readme" | grep -qxF "$made" || echo "$made"

Without PORT and PORT_BOARD, a target that opens the port of its board
first finds it by scripts/port.sh, when the recipe runs, and passes it
through the shell variable port; the board of a profile with the radio is
found by the identifiers of its hardware:

  $ make -s --no-print-directory -n arduino-tilt-upload | grep tempore' ' | tr -s ' '
  port=$(sh scripts/port.sh m5stack-cores3) || exit 1; ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --upload --port "$port" examples/arduino/tilt/tilt.tpe
  $ for t in bala2-upload bala2-regex-log bala2-record bala2-capture bala2-remote-upload \
  >   bala2-controller-profile steps-record steps-capture steps-erase wheels-upload; do
  >   make -s --no-print-directory -n "arduino-$t" |
  >     grep -o -e 'port\.sh [^)]*' -e 'link\.sh -p [^ ]*' -e '--port [^ ]*' | tr '\n' ' ' |
  >     sed "s|^|$t: |; s/ $//"; echo
  > done
  bala2-upload: port.sh m5stack-gray --port "$port"
  bala2-regex-log: port.sh m5stack-gray --port "$port"
  bala2-record: port.sh m5stack-gray --port "$port"
  bala2-capture: port.sh m5stack-gray --port "$port"
  bala2-remote-upload: port.sh m5stack-gray-radio link.sh -p "$port" --port "$port"
  bala2-controller-profile: port.sh m5stack-cores3-radio link.sh -p "$port" --port "$port"
  steps-record: port.sh m5stack-cores3 --port "$port"
  steps-capture: port.sh m5stack-cores3 --port "$port"
  steps-erase: port.sh m5stack-cores3 --port "$port"
  wheels-upload: port.sh m5stack-gray --port "$port"

The targets that open no port find none, and neither the dry runs nor the
help run scripts/port.sh, which here would record its run:

  $ for d in examples/arduino/*/; do
  >   n=$(basename "$d")
  >   make -s --no-print-directory -n "arduino-$n-simulate" "arduino-$n-build" |
  >     grep -l 'port\.sh\|--port' > /dev/null && echo "$n"
  > done
  [1]
  $ export TEMPORE_DEVICE_LIST="touch $PWD/listed"
  $ make -s --no-print-directory -n arduino-bala2-upload arduino-steps-capture > /dev/null
  $ make -s examples-help > /dev/null; make -s arduino-diagnostics-help > /dev/null
  $ [ -e listed ] || echo "not run"
  not run
  $ unset TEMPORE_DEVICE_LIST

PORT_BOARD, set on the command line or in the environment, takes precedence
over the detection, and PORT over both; the port of a board of a profile
with the radio is by default that of its hardware:

  $ dry arduino-tilt-upload PORT_M5STACK_CORES3=/dev/ttyACM0
  ./tempore --grades time-interval-rational --emit-arduino tilt --device examples/arduino/tilt/tilt.device.json --monitor abort --upload --port /dev/ttyACM0 examples/arduino/tilt/tilt.tpe
  $ (export PORT_M5STACK_GRAY=/dev/ttyUSB1; dry arduino-wheels-upload)
  ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino wheels --device examples/arduino/wheels/wheels.device.json --monitor abort --upload --port /dev/ttyUSB1 examples/arduino/wheels/wheels.tpe
  $ dry arduino-bala2-upload PORT=/dev/ttyUSB0 PORT_M5STACK_GRAY=/dev/ttyUSB1
  ./tempore --grades time-interval-rational --emit-arduino balance --device examples/arduino/bala2/balance.device.json --monitor abort --upload --port /dev/ttyUSB0 examples/arduino/bala2/balance.tpe
  $ make -s --no-print-directory -n arduino-bala2-remote-upload PORT_M5STACK_GRAY=/dev/ttyUSB1 | grep -o 'port\.sh\|link\.sh -p [^ ]*\|--port [^ ]*'
  link.sh -p /dev/ttyUSB1
  --port /dev/ttyUSB1
  $ make -s --no-print-directory -n arduino-bala2-remote-upload PORT_M5STACK_GRAY=/dev/ttyUSB1 PORT_M5STACK_GRAY_RADIO=/dev/ttyUSB2 | grep -o -e '--port [^ ]*'
  --port /dev/ttyUSB2
  $ (export PORT_M5STACK_CORES3=/dev/ttyACM1
  >  make -s --no-print-directory -n arduino-steps-erase | grep -o 'port\.sh\|--port [^ ]*')
  --port /dev/ttyACM1

scripts/port.sh finds the port of a board in the serial ports listed by
PlatformIO, here by a fake list, TEMPORE_DEVICE_LIST, the command that prints
the file devices in the format of `pio device list --serial --json-output`.
The port whose identifier VID:PID, in either case, is one of those of the
profile is printed, and reported on standard error:

  $ mkdir ports
  $ export TEMPORE_DEVICE_LIST="cat $PWD/ports/devices"
  $ devices () {
  >   printf '['; sep=
  >   for d in "$@"; do printf '%s{"port": "%s", "description": "n/a", "hwid": "%s"}' "$sep" "${d%%=*}" "${d#*=}"; sep=', '; done
  >   printf ']\n'
  > } > ports/devices
  $ found () { sh scripts/port.sh "$@" 2>&1; echo "exit $?"; }
  $ gray='/dev/cu.usbserial-02012C5D=USB VID:PID=10C4:EA60 SER=02012C5D LOCATION=1-1.1'
  $ ch9102='/dev/cu.wchusbserial54790=USB VID:PID=1a86:55d4 SER=5479012345 LOCATION=1-1.2'
  $ cores3='/dev/cu.usbmodem1101=USB VID:PID=303A:1001 SER=F4:12:FA:00:00:01 LOCATION=1-1.3'
  $ linux='/dev/ttyACM0=USB VID:PID=303a:1001 SER=F4:12:FA:00:00:01 LOCATION=1-1:1.0'
  $ devices '/dev/cu.Bluetooth-Incoming-Port=n/a' "$gray" "$cores3"
  $ found m5stack-gray
  M5Stack Gray on /dev/cu.usbserial-02012C5D
  /dev/cu.usbserial-02012C5D
  exit 0
  $ found m5stack-cores3
  M5Stack CoreS3 on /dev/cu.usbmodem1101
  /dev/cu.usbmodem1101
  exit 0
  $ found m5stack-gray-radio
  M5Stack Gray with the radio on /dev/cu.usbserial-02012C5D
  /dev/cu.usbserial-02012C5D
  exit 0
  $ sh scripts/port.sh m5stack-cores3-radio 2> /dev/null
  /dev/cu.usbmodem1101

The later revision of the Gray, with a CH9102 bridge, and a board on Linux
are found likewise:

  $ devices "$ch9102" "$linux"
  $ found m5stack-gray
  M5Stack Gray on /dev/cu.wchusbserial54790
  /dev/cu.wchusbserial54790
  exit 0
  $ found m5stack-cores3
  M5Stack CoreS3 on /dev/ttyACM0
  /dev/ttyACM0
  exit 0

No match, several matches, a profile without USB identifiers, an unknown
board and a list that fails are errors:

  $ devices '/dev/cu.Bluetooth-Incoming-Port=n/a' "$cores3"
  $ found m5stack-gray
  Error: no M5Stack Gray is connected (USB 10c4:ea60 or 1a86:55d4); connect it, or set PORT or PORT_M5STACK_GRAY
  exit 1
  $ devices
  $ found m5stack-cores3-radio
  Error: no M5Stack CoreS3 with the radio is connected (USB 303a:1001); connect it, or set PORT or PORT_M5STACK_CORES3_RADIO
  exit 1
  $ devices "$gray" "$ch9102" "$cores3"
  $ found m5stack-gray
  Error: several ports match the M5Stack Gray: /dev/cu.usbserial-02012C5D, /dev/cu.wchusbserial54790; set PORT or PORT_M5STACK_GRAY to one of them
  exit 1
  $ found esp32-devkit
  Error: the profile esp32-devkit has no USB identifiers to find the port of the ESP32 DevKit by; set PORT or PORT_ESP32_DEVKIT
  exit 1
  $ found m5stack-grey
  Error: no board profile m5stack-grey
  exit 1
  $ found 'm5stack gray'
  Error: the board 'm5stack gray' is not a name
  exit 1
  $ TEMPORE_DEVICE_LIST="cat $PWD/ports/none" found m5stack-gray | sed "s|$PWD|.|g"
  cat: ./ports/none: No such file or directory
  Error: the serial ports were not listed by cat ./ports/none
  exit 1

A target runs the detection before its commands, which receive the port
found, and does not run them without one; here python3 is a fake that prints
its arguments:

  $ mkdir ports/bin
  $ printf '#!/bin/sh\necho python3 "$@"\n' > ports/bin/python3
  $ chmod +x ports/bin/python3
  $ devices "$linux"
  $ PATH="$PWD/ports/bin:$PATH" make -s --no-print-directory arduino-steps-erase
  M5Stack CoreS3 on /dev/ttyACM0
  python3 -I scripts/steps-recording.py erase --port /dev/ttyACM0 --wait 30
  $ devices "$gray"
  $ (PATH="$PWD/ports/bin:$PATH" make -s --no-print-directory arduino-steps-erase 2>&1
  >  echo "exit $?") | grep -v '^make: \*\*\*'
  Error: no M5Stack CoreS3 is connected (USB 303a:1001); connect it, or set PORT or PORT_M5STACK_CORES3
  exit 2
  $ unset TEMPORE_DEVICE_LIST
  $ rm -r ports

The remaining targets are shown under the ports of the boards of the
development machine:

  $ export PORT_M5STACK_GRAY=/dev/cu.usbserial-02012C91 PORT_M5STACK_CORES3=/dev/cu.usbmodem101

Further targets, under variables set on the command line:

  $ dry arduino-bala2-profile
  ./tempore --grades time-interval-rational --emit-arduino balance-profile --device examples/arduino/bala2/balance.device.json --monitor warn --profile --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2/balance.tpe
  $ dry arduino-bala2-regex-log BALANCE_LOG=50 MONITOR=abort
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_LOG=50" ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino balance_regex-log --device examples/arduino/bala2-regex/balance_regex.device.json --monitor abort --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2-regex/balance_regex.tpe
  $ dry arduino-bala2-record BALANCE_RECORD=50
  PLATFORMIO_BUILD_FLAGS="-DBALANCE_RECORD=50" ./tempore --grades time-interval-rational --emit-arduino balance-record --device examples/arduino/bala2/balance.device.json --monitor warn --upload --port /dev/cu.usbserial-02012C91 --capture 30 examples/arduino/bala2/balance.tpe

The examples of an encrypted ESP-NOW link, EXAMPLE_LINK, name the role of
their board in it, EXAMPLE_LINK_ROLE. Each device build of such an example
first runs scripts/link.sh with the link, the role, the other role of the
link and the upload target of its example, and the port of an upload, and
passes the peer and the key that it prints as the build flags ESP_NOW_PEER
and ESP_NOW_KEY through shell variables, so that the command does not show
the key; a build without an upload reads no port:

  $ make -s --no-print-directory -n arduino-bala2-remote-build | grep tempore' ' | tr -s ' '
  link=$(sh scripts/link.sh -t arduino-bala2-controller-upload bala2-remote robot controller) && eval "$link" && PLATFORMIO_BUILD_FLAGS="-DESP_NOW_PEER=$esp_now_peer -DESP_NOW_KEY=$esp_now_key" ./tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-arduino balance_remote --device examples/arduino/bala2-remote/balance_remote.device.json --monitor abort --build examples/arduino/bala2-remote/balance_remote.tpe
  $ make -s --no-print-directory -n arduino-bala2-remote-profile BRIGHTNESS=60 | grep -o '^link=[^&]*\|PLATFORMIO_BUILD_FLAGS="[^"]*"'
  link=$(sh scripts/link.sh -p /dev/cu.usbserial-02012C91 -t arduino-bala2-controller-upload bala2-remote robot controller) 
  PLATFORMIO_BUILD_FLAGS="-DTEMPORE_DISPLAY_BRIGHTNESS=60 -DESP_NOW_PEER=$esp_now_peer -DESP_NOW_KEY=$esp_now_key"
  $ make -s --no-print-directory -n arduino-bala2-controller-upload PORT_M5STACK_CORES3=/dev/ttyACM0 | grep -o '^link=[^&]*'
  link=$(sh scripts/link.sh -p /dev/ttyACM0 -t arduino-bala2-remote-upload bala2-remote controller robot) 

The other examples run no link:

  $ for d in examples/arduino/*/; do
  >   n=$(basename "$d")
  >   case $n in bala2-remote|bala2-controller) continue;; esac
  >   make -s --no-print-directory -n "arduino-$n-build" "arduino-$n-upload" |
  >     grep -l 'link\|ESP_NOW' > /dev/null && echo "$n"
  > done
  [1]

The link file of a link holds its key and the address of the board of each
role. A fake esptool, TEMPORE_ESPTOOL, prints the address held by the file
named as its port; HOME and the link file are in the test directory:

  $ mkdir link
  $ cat > link/esptool <<'EOF'
  > #!/bin/sh
  > while [ $# -gt 0 ]; do case $1 in --port) port=$2; shift;; esac; shift; done
  > [ -f "$port" ] || { echo "Could not open $port"; exit 2; }
  > echo "esptool.py v4.11.0"
  > echo "MAC: $(cat "$port")"
  > EOF
  $ chmod +x link/esptool
  $ echo 24:0a:c4:12:34:56 > link/robot
  $ echo 24:0a:c4:12:34:57 > link/controller
  $ export HOME="$PWD/link/home" TEMPORE_ESPTOOL="$PWD/link/esptool"
  $ export REMOTE_LINK_FILE="$PWD/link/links/bala2-remote"
  $ unset REMOTE_KEY REMOTE_PEER
  $ link () { sh scripts/link.sh "$@" 2>&1 | sed -e "s|$PWD|.|g" -e 's/esp_now_key=.*/esp_now_key=(the key)/'; }

The first upload, to the robot, generates the key, records the address of
the robot, and stops, the controller not yet recorded; the upload to the
controller records it and builds; the robot is then built with its address:

  $ link -p link/robot -t arduino-bala2-controller-upload bala2-remote robot controller
  ESP-NOW link bala2-remote: key generated in ./link/links/bala2-remote
  ESP-NOW link bala2-remote: the robot 24:0A:C4:12:34:56 recorded in ./link/links/bala2-remote
  Error: the link file ./link/links/bala2-remote has no address of the controller: connect the controller and upload to it first (make arduino-bala2-controller-upload), or set REMOTE_PEER
  $ link -p link/controller bala2-remote controller robot
  ESP-NOW link bala2-remote: key of ./link/links/bala2-remote
  ESP-NOW link bala2-remote: the controller 24:0A:C4:12:34:57 recorded in ./link/links/bala2-remote
  ESP-NOW link bala2-remote: peer 24:0A:C4:12:34:56, the robot
  esp_now_peer=0x24,0x0A,0xC4,0x12,0x34,0x56
  esp_now_key=(the key)
  $ link -p link/robot bala2-remote robot controller
  ESP-NOW link bala2-remote: key of ./link/links/bala2-remote
  ESP-NOW link bala2-remote: peer 24:0A:C4:12:34:57, the controller
  esp_now_peer=0x24,0x0A,0xC4,0x12,0x34,0x57
  esp_now_key=(the key)
  $ sed 's/^key=.*/key=(the key)/' link/links/bala2-remote
  # The ESP-NOW link bala2-remote: its key and the address of the board of each role.
  key=(the key)
  robot=24:0A:C4:12:34:56
  controller=24:0A:C4:12:34:57
  $ ls -ld link/links link/links/bala2-remote | cut -c 1-10
  drwx------
  -rw-------
  $ ls -A link/links
  bala2-remote

The key printed is that of the file, and no build without an upload reads
a port:

  $ key=$(sed -n 's/^key=//p' link/links/bala2-remote)
  $ sh scripts/link.sh bala2-remote robot controller 2> /dev/null | grep -c "^esp_now_key=$key$"
  1

A replaced board is recorded under its role, with the change reported; the
board of the other role, under a role, is an error, as is a port that
esptool does not read:

  $ echo 24:0A:C4:12:34:58 > link/robot
  $ link -p link/robot bala2-remote robot controller | grep -v esp_now
  ESP-NOW link bala2-remote: key of ./link/links/bala2-remote
  ESP-NOW link bala2-remote: the robot changed from 24:0A:C4:12:34:56 to 24:0A:C4:12:34:58 in ./link/links/bala2-remote
  ESP-NOW link bala2-remote: peer 24:0A:C4:12:34:57, the controller
  $ link -p link/controller bala2-remote robot controller
  ESP-NOW link bala2-remote: key of ./link/links/bala2-remote
  Error: the board on link/controller, 24:0A:C4:12:34:57, is recorded as the controller in ./link/links/bala2-remote
  $ link -p link/none bala2-remote robot controller
  Could not open link/none
  Error: the address of the board on link/none was not read by ./link/esptool

REMOTE_PEER and REMOTE_KEY, here a fake key, take precedence over the link
file; a malformed one is an error:

  $ REMOTE_PEER=24:0a:c4:00:00:09 REMOTE_KEY=000102030405060708090a0b0c0d0e0f sh scripts/link.sh bala2-remote robot controller
  ESP-NOW link bala2-remote: key of REMOTE_KEY
  ESP-NOW link bala2-remote: peer 24:0A:C4:00:00:09 of REMOTE_PEER
  esp_now_peer=0x24,0x0A,0xC4,0x00,0x00,0x09
  esp_now_key=000102030405060708090a0b0c0d0e0f
  $ (export REMOTE_PEER=24:0a:c4:00:00; link bala2-remote robot controller)
  Error: REMOTE_PEER is not six bytes in hexadecimal separated by colons
  $ (export REMOTE_KEY=000102030405060708090a0b0c0d0e0g; link bala2-remote robot controller)
  Error: REMOTE_KEY is not 32 hexadecimal digits

A malformed link file is an error, at its first malformed line; comments,
empty lines, spaces, carriage returns, '-' in addresses and lower case are
read:

  $ printf '# A link\r\n\n key = 000102030405060708090A0B0C0D0E0F \r\nrobot=24-0a-c4-12-34-56\ncontroller=24:0A:C4:12:34:57\n' > link/links/bala2-remote
  $ sh scripts/link.sh bala2-remote controller robot 2> /dev/null
  esp_now_peer=0x24,0x0A,0xC4,0x12,0x34,0x56
  esp_now_key=000102030405060708090A0B0C0D0E0F
  $ for content in 'key=0001' 'key 000102030405060708090a0b0c0d0e0f' 'robot=24:0a:c4:12:34' 'robot=24:0a:c4:12:34:5g' 'robot=24:0a:c4:12:34:56\nrobot=24:0a:c4:12:34:57' '2robot=24:0a:c4:12:34:56'; do
  >   printf "$content\n" > link/links/bala2-remote; link bala2-remote controller robot
  > done
  Error: the link file ./link/links/bala2-remote, line 1: the key is not 32 hexadecimal digits
  Error: the link file ./link/links/bala2-remote, line 1: not NAME=VALUE
  Error: the link file ./link/links/bala2-remote, line 1: the address of robot is not six bytes in hexadecimal separated by colons
  Error: the link file ./link/links/bala2-remote, line 1: the address of robot is not six bytes in hexadecimal separated by colons
  Error: the link file ./link/links/bala2-remote, line 2: the name robot is repeated
  Error: the link file ./link/links/bala2-remote, line 1: the name "2robot" is not a name

Concurrent builds agree on one key, generated once:

  $ rm -r link/links
  $ export REMOTE_PEER=24:0a:c4:12:34:57
  $ for i in 1 2 3 4; do sh scripts/link.sh -p link/robot bala2-remote robot controller > printed$i 2> log$i & done; wait
  $ unset REMOTE_PEER
  $ cat log* | grep -c generated
  1
  $ grep -h esp_now_key printed* | wc -l | tr -d ' '
  4
  $ grep -h esp_now_key printed* | sort -u | wc -l | tr -d ' '
  1
  $ grep -h esp_now_key printed1 | grep -c "=$(sed -n 's/^key=//p' link/links/bala2-remote)$"
  1
  $ ls -A link/links
  bala2-remote
  $ rm -r link printed* log*

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
  12
  $ make -s --no-print-directory -n arduino-build-all | grep -c '\./tempore '
  12

The help of the examples and that of the diagnostic targets, which are
listed apart:

  $ unset PORT_M5STACK_GRAY PORT_M5STACK_CORES3
  $ make -s examples-help
  Arduino examples, by board:
  M5Stack CoreS3, port PORT_M5STACK_CORES3 = found by USB 303a:1001:
    NAME one of: calibrated fall level peak starter steps tilt
    arduino-NAME-simulate         simulates the project on the host
    arduino-NAME-build            builds the project with PlatformIO
    arduino-NAME-upload           builds the project and uploads it to the board
  M5Stack CoreS3 with the radio, port PORT_M5STACK_CORES3_RADIO = found by USB 303a:1001:
    NAME one of: bala2-controller
    arduino-NAME-simulate         simulates the project on the host
    arduino-NAME-build            builds the project with PlatformIO
    arduino-NAME-upload           builds the project and uploads it to the board
  M5Stack Gray, port PORT_M5STACK_GRAY = found by USB 10c4:ea60 or 1a86:55d4:
    NAME one of: bala2 bala2-regex wheels
    arduino-NAME-simulate         simulates the project on the host
    arduino-NAME-build            builds the project with PlatformIO
    arduino-NAME-upload           builds the project and uploads it to the board
  M5Stack Gray with the radio, port PORT_M5STACK_GRAY_RADIO = found by USB 10c4:ea60 or 1a86:55d4:
    NAME one of: bala2-remote
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
    PORT=                                        when set, the port of every board
    SIMULATE=                                    when set, the simulated seconds of every example
    MONITOR=                                     when set, the monitor policy of every target
    BRIGHTNESS=                                  when set, the display brightness, 0 to 100 % (default 24), of every build
  ESP-NOW link bala2-remote, roles controller robot: paired by the link file ~/.config/tempore/links/bala2-remote,
    or REMOTE_LINK_FILE; REMOTE_PEER and REMOTE_KEY override its address and key
  Diagnostic targets (profiles, logs and recordings): make arduino-diagnostics-help
  $ make -s arduino-diagnostics-help
  Arduino diagnostic targets, by board:
  M5Stack CoreS3, port PORT_M5STACK_CORES3 = found by USB 303a:1001:
    NAME one of: calibrated fall level peak starter steps tilt
    arduino-NAME-profile          uploads the project with the profile and reads the port
    arduino-steps-record          uploads the project with -DSTEPS_RECORD=600 and reads the port
    arduino-steps-capture         reads the recordings from the port into _arduino/recordings/steps-TIME-N.csv
    arduino-steps-erase           erases the recordings on the device
  M5Stack CoreS3 with the radio, port PORT_M5STACK_CORES3_RADIO = found by USB 303a:1001:
    NAME one of: bala2-controller
    arduino-NAME-profile          uploads the project with the profile and reads the port
  M5Stack Gray, port PORT_M5STACK_GRAY = found by USB 10c4:ea60 or 1a86:55d4:
    NAME one of: bala2 bala2-regex wheels
    arduino-NAME-profile          uploads the project with the profile and reads the port
    arduino-bala2-log             uploads the project with -DBALANCE_LOG=20 and reads the port
    arduino-bala2-regex-log       uploads the project with -DBALANCE_LOG=20 and reads the port
    arduino-bala2-record          uploads the project with -DBALANCE_RECORD=20 and reads the port
    arduino-bala2-capture         reads the recordings from the port into _arduino/recordings/bala2-TIME.csv
    arduino-bala2-regex-record    uploads the project with -DBALANCE_RECORD=20 and reads the port
    arduino-bala2-regex-capture   reads the recordings from the port into _arduino/recordings/bala2-regex-TIME.csv
  M5Stack Gray with the radio, port PORT_M5STACK_GRAY_RADIO = found by USB 10c4:ea60 or 1a86:55d4:
    NAME one of: bala2-remote
    arduino-NAME-profile          uploads the project with the profile and reads the port
  Variables, with their values:
    PORT=                                        when set, the port of every board
    CAPTURE=30                                   the seconds for which the port is read
    MONITOR=                                     when set, the monitor policy of every target
    BRIGHTNESS=                                  when set, the display brightness, 0 to 100 % (default 24), of every build
