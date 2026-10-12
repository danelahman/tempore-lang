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

The options of PlatformIO need a project.

  $ $T toy toy/toy.tpe --build
  ../../tempore: option '--build' requires '--device'.
  [2]
  $ ../../tempore --grades time-interval-rational toy/toy.tpe --upload
  ../../tempore: option '--upload' requires '--device'.
  [2]
  $ $T toy --device toy/toy.device.json toy/toy.tpe --build --port /dev/ttyUSB0
  ../../tempore: option '--port' requires '--upload'.
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
