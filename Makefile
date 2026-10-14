default: format
	dune build

format:
	dune build @fmt --auto-promote

check-format:
	dune build @fmt

release:
	dune build --profile release

test: default
	dune test

clean:
	dune clean

tempore-deps:
	opam install --deps-only --with-dev-setup .

# The Opentrons simulator, opentrons_simulate of the Python package opentrons
# 10.0.0, in the virtual environment _opentrons, created with the first of the
# interpreters below of version 3.10 or later; an error if there is none.
# Optional: only --simulate needs it. clean-opentrons removes it, together with the protocols written by
# --emit-opentrons to _opentrons/protocols.
OPENTRONS_VENV = _opentrons
OPENTRONS_PYTHONS = python3.13 python3.12 python3.11 python3.10 python3

opentrons-deps:
	@if [ -x $(OPENTRONS_VENV)/bin/opentrons_simulate ]; then \
	  echo "The Opentrons simulator is installed in $(OPENTRONS_VENV)."; \
	  exit 0; \
	fi; \
	for python in $(OPENTRONS_PYTHONS); do \
	  if command -v $$python > /dev/null 2>&1 && \
	     $$python -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then \
	    echo "Installing the Opentrons simulator in $(OPENTRONS_VENV) with $$python."; \
	    $$python -m venv $(OPENTRONS_VENV) && \
	    $(OPENTRONS_VENV)/bin/pip install --quiet --disable-pip-version-check opentrons==10.0.0 && \
	    mkdir -p $(OPENTRONS_VENV)/config; \
	    exit $$?; \
	  fi; \
	done; \
	echo "Error: Python 3.10 or later was not found; the Opentrons simulator is not installed." >&2; \
	exit 1

clean-opentrons:
	rm -rf $(OPENTRONS_VENV)

# PlatformIO Core 6.2.0, the build tool of --build and --upload, in the
# virtual environment _arduino/venv, created with the first of the interpreters
# below of version 3.10 or later; an error if there is none. PlatformIO keeps
# its platforms, toolchains and libraries in _arduino/platformio, set by the
# executable as PLATFORMIO_CORE_DIR. Optional: only --build and --upload need
# it. clean-arduino removes _arduino, together with the projects written by
# --emit-arduino to _arduino/projects.
ARDUINO_DIR = _arduino
ARDUINO_VENV = $(ARDUINO_DIR)/venv
ARDUINO_PYTHONS = $(OPENTRONS_PYTHONS)

arduino-deps:
	@if [ -x $(ARDUINO_VENV)/bin/pio ]; then \
	  echo "PlatformIO is installed in $(ARDUINO_VENV)."; \
	  exit 0; \
	fi; \
	for python in $(ARDUINO_PYTHONS); do \
	  if command -v $$python > /dev/null 2>&1 && \
	     $$python -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then \
	    echo "Installing PlatformIO in $(ARDUINO_VENV) with $$python."; \
	    $$python -m venv $(ARDUINO_VENV) && \
	    $(ARDUINO_VENV)/bin/pip install --quiet --disable-pip-version-check platformio==6.2.0 && \
	    mkdir -p $(ARDUINO_DIR)/platformio $(ARDUINO_DIR)/projects; \
	    exit $$?; \
	  fi; \
	done; \
	echo "Error: Python 3.10 or later was not found; PlatformIO is not installed." >&2; \
	exit 1

clean-arduino:
	rm -rf $(ARDUINO_DIR)

vscode-extension:
	cd editors/vscode && \
	  rm -f vscode-tempore-*.vsix && \
	  npx --yes @vscode/vsce package && \
	  code --install-extension vscode-tempore-*.vsix --force

.PHONY: default format check-format release test clean tempore-deps \
  opentrons-deps clean-opentrons arduino-deps clean-arduino vscode-extension

# The targets of the examples of the Arduino and Opentrons backends, listed by
# 'make examples-help'.
include examples/examples.mk
