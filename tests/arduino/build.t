With --build, the project written with --device is built by PlatformIO, pio
on the PATH or the executable given by --pio, run as 'pio run -d DIRECTORY',
whose output is passed through and whose exit code is that of tempore; with
--upload it is built and uploaded, 'pio run -d DIRECTORY -t upload', through
the serial port of --port if given. Here pio is a script that prints its
arguments; a second one fails. The lines of the files written are left out.

  $ run () { env "$@" > out.txt 2>&1; s=$?; grep -v '^Wrote' out.txt; return $s; }
  $ T="../../tempore --grades time-interval-rational --emit-arduino"
  $ mkdir bin
  $ cat > bin/pio <<'SCRIPT'
  > #!/bin/sh
  > echo "pio $*"
  > echo "a warning of PlatformIO" >&2
  > SCRIPT
  $ cat > failing_pio <<'SCRIPT'
  > #!/bin/sh
  > echo "pio $*"
  > echo "Error: the build failed" >&2
  > exit 3
  > SCRIPT
  $ chmod +x bin/pio failing_pio
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --build
  pio run -d _arduino/projects/toy
  a warning of PlatformIO
  $ run PATH="$PWD/bin:$PATH" $T out/toy --device toy/toy.device.json toy/toy.tpe --upload
  pio run -d out/toy -t upload
  a warning of PlatformIO
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --upload \
  >   --port /dev/ttyUSB0
  pio run -d _arduino/projects/toy -t upload --upload-port /dev/ttyUSB0
  a warning of PlatformIO
  $ run $T toy --device toy/toy.device.json toy/toy.tpe --build --pio ./failing_pio
  pio run -d _arduino/projects/toy
  Error: the build failed
  [3]
  $ run $T toy --device toy/toy.device.json toy/toy.tpe --build --pio ./missing_pio
  Error: PlatformIO './missing_pio' was not found
  [1]
  $ run PATH=/nonexistent $T toy --device toy/toy.device.json toy/toy.tpe --build
  Error: PlatformIO pio was not found on the PATH or in _arduino/venv; 'make arduino-deps' installs it with Python 3.10 or later
  [1]

A fault of the project is reported before PlatformIO runs.

  $ sed 's/"step"/"missing"/' toy/toy.device.json > toy/missing.device.json
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/missing.device.json toy/toy.tpe --build \
  >   > /dev/null
  [1]
  $ grep -c '^pio' out.txt
  0
  [1]

Without --pio and pio on the PATH, PlatformIO is that of the installation
_arduino of 'make arduino-deps', _arduino/venv/bin/pio in the directory of the
executable or else in the current directory, run with PLATFORMIO_CORE_DIR set
to _arduino/platformio unless the environment sets it. Here it is a script
that prints its arguments and that variable; pio on the PATH takes precedence
over it.

  $ mkdir -p repo/_arduino/venv/bin
  $ cp ../../tempore repo/tempore
  $ cat > repo/_arduino/venv/bin/pio <<'SCRIPT'
  > #!/bin/sh
  > echo "pio $*"
  > echo "PLATFORMIO_CORE_DIR=${PLATFORMIO_CORE_DIR#$PWD/}"
  > SCRIPT
  $ chmod +x repo/_arduino/venv/bin/pio
  $ R="repo/tempore --grades time-interval-rational --emit-arduino"
  $ run PATH=/usr/bin:/bin $R toy --device toy/toy.device.json toy/toy.tpe --build
  pio run -d _arduino/projects/toy
  PLATFORMIO_CORE_DIR=repo/_arduino/platformio
  $ run PATH=/usr/bin:/bin PLATFORMIO_CORE_DIR=elsewhere $R toy --device toy/toy.device.json \
  >   toy/toy.tpe --upload
  pio run -d _arduino/projects/toy -t upload
  PLATFORMIO_CORE_DIR=elsewhere
  $ run PATH="$PWD/bin:/usr/bin:/bin" $R toy --device toy/toy.device.json toy/toy.tpe --build
  pio run -d _arduino/projects/toy
  a warning of PlatformIO
  $ cd repo
  $ run PATH=/usr/bin:/bin ../../../tempore --grades time-interval-rational --emit-arduino ../toy \
  >   --device ../toy/toy.device.json ../toy/toy.tpe --build
  pio run -d ../toy
  PLATFORMIO_CORE_DIR=_arduino/platformio
  $ cd ..

With --capture, after a successful upload the serial port of --port is read
at the baud rate of the board for the given number of seconds, or until its
end, and its lines are printed without their carriage returns; with
--profile, the last complete profile among them follows. A terminal is read
as raw input, its modem control lines left as opening it sets them; here the
port is a file of a log with two profiles, the line of another task within
the second, and the start of a third profile:

  $ printf '[0.1 ms] Start\r\n[5000.0 ms] Profile since start-up, times in microseconds\r\n  operation calls\r\n  Show 500\r\n[5000.1 ms] End of the profile\r\n' > serial.log
  $ printf '[10000.0 ms] Profile since start-up, times in microseconds\r\n  operation calls\r\n[10000.0 ms] Display: 1\r\n  Show 1000\r\n[10000.1 ms] End of the profile\r\n' >> serial.log
  $ printf '[15000.0 ms] Profile since start-up, times in microseconds\r\n  operation' >> serial.log
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --upload \
  >   --port serial.log --capture 2 --profile
  pio run -d _arduino/projects/toy -t upload --upload-port serial.log
  a warning of PlatformIO
  [0.1 ms] Start
  [5000.0 ms] Profile since start-up, times in microseconds
    operation calls
    Show 500
  [5000.1 ms] End of the profile
  [10000.0 ms] Profile since start-up, times in microseconds
    operation calls
  [10000.0 ms] Display: 1
    Show 1000
  [10000.1 ms] End of the profile
  [15000.0 ms] Profile since start-up, times in microseconds
    operation
  The last profile read:
  [10000.0 ms] Profile since start-up, times in microseconds
    operation calls
    Show 1000
  [10000.1 ms] End of the profile
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --upload \
  >   --port serial.log --capture 2 | tail -n 2
  [15000.0 ms] Profile since start-up, times in microseconds
    operation
  $ head -c 10 serial.log > short.log
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --upload \
  >   --port short.log --capture 2 --profile
  pio run -d _arduino/projects/toy -t upload --upload-port short.log
  a warning of PlatformIO
  [0.1 ms] S
  No complete profile was read.

Without --upload, the project is written and the port read without
PlatformIO, as to read the output of a board already programmed:

  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe \
  >   --port serial.log --capture 2 | grep -v '^Wrote' | head -n 2
  [0.1 ms] Start
  [5000.0 ms] Profile since start-up, times in microseconds

A failed upload is not followed by the capture, and a port that does not
appear within the capture is an error:

  $ run $T toy --device toy/toy.device.json toy/toy.tpe --upload --pio ./failing_pio \
  >   --port serial.log --capture 2
  pio run -d _arduino/projects/toy -t upload --upload-port serial.log
  Error: the build failed
  [3]
  $ run PATH="$PWD/bin:$PATH" $T toy --device toy/toy.device.json toy/toy.tpe --upload \
  >   --port missing.log --capture 0.2
  pio run -d _arduino/projects/toy -t upload --upload-port missing.log
  a warning of PlatformIO
  Error: the serial port missing.log: No such file or directory
  [1]

The options of PlatformIO need a project.

  $ $T toy toy/toy.tpe --build
  ../../tempore: option '--build' requires '--device'.
  [2]
  $ ../../tempore --grades time-interval-rational toy/toy.tpe --upload
  ../../tempore: option '--upload' requires '--device'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --port /dev/ttyUSB0
  ../../tempore: option '--port' requires '--upload' or '--capture'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --pio ./failing_pio
  ../../tempore: option '--pio' requires '--build' or '--upload'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --upload
  ../../tempore: option '--build' cannot be used with '--upload'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --host-simulate 1
  ../../tempore: option '--build' cannot be used with '--host-simulate'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --upload --capture 1
  ../../tempore: option '--capture' requires '--port'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --capture 1
  ../../tempore: option '--capture' requires '--port'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --port p --capture 1
  ../../tempore: option '--capture' cannot be used with '--build'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --host-simulate 1 --port p --capture 1
  ../../tempore: option '--capture' cannot be used with '--host-simulate'.
  [2]
  $ $T toy toy/toy.tpe --port p --capture 1
  ../../tempore: option '--capture' requires '--device'.
  [2]
  $ $T toy toy/toy.tpe --profile
  ../../tempore: option '--profile' requires '--device'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --upload --port p --capture 0 2>&1 | head -n 1
  ../../tempore: option '--capture': '0' is not a positive number of seconds of at most 10^6.
