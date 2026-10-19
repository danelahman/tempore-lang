# The targets of the examples of the Arduino and Opentrons backends, included
# by the Makefile; 'make examples-help' and 'make arduino-diagnostics-help'
# list them. Each example has a
# fragment of variables, found here by its path, from which a template of its
# backend defines its targets:
#
# - an Opentrons example examples/opentrons/NAME.tpe, with the binding file
#   examples/opentrons/NAME_bindings.py, has the fragment
#   examples/opentrons/NAME.mk, which sets EXAMPLE_GRADES, the grades of the
#   program, and EXAMPLE_TIME_UNIT, the value of --time-unit;
# - an Arduino example, the directory examples/arduino/NAME with one manifest
#   PROGRAM.device.json and its program PROGRAM.tpe, has the fragment
#   examples/arduino/NAME/example.mk, which sets EXAMPLE_GRADES, the grades of
#   the program, EXAMPLE_SIMULATE, the seconds of its host simulation, and
#   optionally EXAMPLE_BUILD_FLAGS, the build flags of all its device builds,
#   EXAMPLE_LOG_FLAGS, the build flags of its target -log, and
#   EXAMPLE_RECORD_FLAGS and EXAMPLE_RECORD_FILTER, the build flags of its
#   target -record and the awk program that extracts the recordings from the
#   serial output read by its target -capture, or, in place of the filter,
#   EXAMPLE_RECORD_TOOL, a Python script by which the targets -capture and
#   -erase read and erase the recordings kept on the device, and
#   EXAMPLE_LINK and EXAMPLE_LINK_ROLE, the name of the encrypted ESP-NOW
#   link of its device builds and the role of its board in the link, whose
#   peer and key, ESP_NOW_PEER and ESP_NOW_KEY, are printed by
#   scripts/link.sh from the link file. The board is that of the manifest, and its port variable PORT_BOARD, the
#   name of the board in upper case with '-' replaced by '_'. 'make
#   examples-help' and 'make arduino-diagnostics-help' group the Arduino
#   targets by board, named by the member "title" of the board profile.
#
# Each target builds tempore first, and a target that needs the Opentrons
# simulator or PlatformIO first installs it by opentrons-deps or
# arduino-deps. tests/make/examples.t checks that every example has its
# fragment.

# The serial ports of the boards: PORT, when set, is the port of every
# target that opens one, and else PORT_BOARD, the port of the board BOARD, if
# set; PORT_M5STACK_GRAY_RADIO and PORT_M5STACK_CORES3_RADIO default to the
# ports of the boards of their hardware. Without either, the port is found by
# scripts/port.sh, from the USB identifiers of the board profile, when the
# recipe runs. CAPTURE is the time, in
# seconds, for which the serial port is read after an upload that captures,
# and by a target -capture;
# SIMULATE, when set, the simulated time, in seconds, of every host
# simulation, by default that of the example; MONITOR, when set, the monitor
# policy, by default abort, and warn for the uploads that capture;
# BRIGHTNESS, when set, the brightness of the display, a percentage from 0 to
# 100, of every device build, by default 24; PAIR, when set, the pair of the
# boards of an ESP-NOW link, and REPLACE, when 1, the replacement of a board
# of the default pair, as in scripts/link.sh. Each can be set on the command
# line or in the environment.
PORT_M5STACK_GRAY_RADIO ?= $(PORT_M5STACK_GRAY)
PORT_M5STACK_CORES3_RADIO ?= $(PORT_M5STACK_CORES3)
PORT ?=
PAIR ?=
REPLACE ?=
CAPTURE ?= 30
SIMULATE ?=
MONITOR ?=
BRIGHTNESS ?=

TEMPORE = ./tempore

tempore-cli:
	dune build ./tempore

# The variables a fragment sets, emptied before each fragment is read.
EXAMPLE_FIELDS = EXAMPLE_GRADES EXAMPLE_TIME_UNIT EXAMPLE_SIMULATE \
  EXAMPLE_BUILD_FLAGS EXAMPLE_LOG_FLAGS EXAMPLE_RECORD_FLAGS \
  EXAMPLE_RECORD_FILTER EXAMPLE_RECORD_TOOL EXAMPLE_LINK EXAMPLE_LINK_ROLE

# A comma, for the fragments that write one in a function call.
comma := ,

# The build flags of a device build: PLATFORMIO_BUILD_FLAGS, the flag
# TEMPORE_DISPLAY_BRIGHTNESS under BRIGHTNESS, and the flags $(1); and the
# assignment of these flags, prefixed to the commands of the device builds,
# if BRIGHTNESS or $(1) is set.
device_flags = $(strip $(PLATFORMIO_BUILD_FLAGS) $(if \
  $(BRIGHTNESS),-DTEMPORE_DISPLAY_BRIGHTNESS=$(BRIGHTNESS)) $(1))
build_flags = $(if $(or $(BRIGHTNESS),$(strip $(1))),PLATFORMIO_BUILD_FLAGS="$(call \
  device_flags,$(1))" )

# The ESP-NOW link of the Arduino example $(1), the role of its board, the
# other role of the link, and the example of that role.
link_name = $(ARDUINO_LINK_$(1))
link_role = $(ARDUINO_LINK_ROLE_$(1))
link_peer = $(filter-out $(call link_role,$(1)),$(LINK_ROLES_$(call \
  link_name,$(1))))
link_peer_example = $(LINK_EXAMPLE_$(call link_name,$(1))_$(call \
  link_peer,$(1)))

# Under the ESP-NOW link of the Arduino example $(1), the command that sets
# the shell variables esp_now_peer and esp_now_key to the peer and the key of
# its board, printed by scripts/link.sh, which first records the address of
# the board on the port $(2) if given, with the pair PAIR and REPLACE=1
# passed as its options -P and -r; it is prefixed to the commands of the
# device builds. The build flags ESP_NOW_PEER and ESP_NOW_KEY of these
# variables, so that the commands do not show the key.
link_setup = $(if $(call link_name,$(1)),$(if $(filter-out 0 1,$(REPLACE)),$(error \
  REPLACE is 1 or 0, not $(REPLACE)))$(if $(filter 1,$(words $(call \
  link_peer,$(1)))),,$(error The ESP-NOW link $(call link_name,$(1)) of \
  $(1) has not exactly one other role: $(call link_peer,$(1))))link=$$(sh \
  scripts/link.sh $(if $(2),-p $(2) )$(if $(call \
  link_peer_example,$(1)),-t arduino-$(call \
  link_peer_example,$(1))-upload )$(if $(PAIR),-P '$(PAIR)' )$(if $(filter \
  1,$(REPLACE)),-r )$(call link_name,$(1)) $(call \
  link_role,$(1)) $(call link_peer,$(1))) && eval "$$link" && )
link_flags = $(if $(1),-DESP_NOW_PEER=$$esp_now_peer \
  -DESP_NOW_KEY=$$esp_now_key)

# The fragments of the Opentrons example $(1) and of the Arduino example $(1).
opentrons_fragment = examples/opentrons/$(1).mk
arduino_fragment = examples/arduino/$(1)/example.mk

# The names of the examples of the two backends, those of their fragments.
example_names = $(sort $(patsubst $(call $(1)_fragment,%),%,$(wildcard \
  $(call $(1)_fragment,*))))
OPENTRONS_EXAMPLES := $(call example_names,opentrons)
ARDUINO_EXAMPLES := $(call example_names,arduino)

# Reads the fragment of the example $(2) of the backend $(1) and defines its
# targets by the template $(1)_example, applied to the name and the
# directory of the example. Its expansion is passed to eval, since make 3.81
# rejects a multi-line expansion at the top level.
define load_example
$(foreach field,$(EXAMPLE_FIELDS),$(eval $(field) :=))
$(eval include $(call $(1)_fragment,$(2)))
$(eval $(call $(1)_example,$(2),$(patsubst %/,%,$(dir $(call \
  $(1)_fragment,$(2))))))
endef

# The Opentrons example $(1) of the directory $(2): -emit writes the protocol
# to _opentrons/protocols/$(1).py, and -simulate also runs it with the
# Opentrons simulator.
define opentrons_example
opentrons-$(1)-emit: tempore-cli
	$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-opentrons $(1).py \
	  --bind $(2)/$(1)_bindings.py \
	  --time-unit $(EXAMPLE_TIME_UNIT) \
	  $$(if $$(MONITOR),--monitor $$(MONITOR)) \
	  $(2)/$(1).tpe

opentrons-$(1)-simulate: tempore-cli opentrons-deps
	$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-opentrons $(1).py \
	  --bind $(2)/$(1)_bindings.py \
	  --time-unit $(EXAMPLE_TIME_UNIT) \
	  $$(if $$(MONITOR),--monitor $$(MONITOR)) \
	  --simulate \
	  $(2)/$(1).tpe

endef

# The program of the Arduino example of the directory $(1), the name of its
# manifest; the board of its manifest; the variable of the port of the board
# $(1).
arduino_program = $(basename $(basename $(notdir $(wildcard \
  $(1)/*.device.json))))
arduino_board = $(shell sed -n 's/.*"board": *"\([^"]*\)".*/\1/p' \
  $(1)/$(call arduino_program,$(1)).device.json)
port_variable = PORT_$(shell echo $(1) | tr a-z- A-Z_)

# The Arduino example $(1) of the directory $(2), whose program is $(3) and
# board $(4), uploaded through the port of the board, as in port. The project
# is written to _arduino/projects/$(3): -simulate simulates it on the host,
# -build builds it with PlatformIO, -upload builds and uploads it, and
# -profile builds and uploads the project _arduino/projects/$(3)-profile
# with the profile and reads the serial port for CAPTURE seconds; -log, under
# EXAMPLE_LOG_FLAGS, builds and uploads the project _arduino/projects/$(3)-log
# with these build flags and reads the serial port for CAPTURE seconds; -record
# and -capture, under EXAMPLE_RECORD_FLAGS, as in arduino_record.
define arduino_template
arduino-$(1)-simulate: tempore-cli
	$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3) \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),abort) \
	  --host-simulate $$(or $$(SIMULATE),$(EXAMPLE_SIMULATE)) \
	  $(2)/$(3).tpe

arduino-$(1)-build: tempore-cli arduino-deps
	$$(call link_setup,$(1))$$(call build_flags,$$(ARDUINO_BUILD_FLAGS_$(1)))$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3) \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),abort) \
	  --build \
	  $(2)/$(3).tpe

arduino-$(1)-upload: tempore-cli arduino-deps
	$$(call port_setup,$(4))$$(call link_setup,$(1),$$(call port,$(4)))$$(call build_flags,$$(ARDUINO_BUILD_FLAGS_$(1)))$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3) \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),abort) \
	  --upload --port $$(call port,$(4)) \
	  $(2)/$(3).tpe

arduino-$(1)-profile: tempore-cli arduino-deps
	$$(call port_setup,$(4))$$(call link_setup,$(1),$$(call port,$(4)))$$(call build_flags,$$(ARDUINO_BUILD_FLAGS_$(1)))$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3)-profile \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),warn) \
	  --profile --upload --port $$(call port,$(4)) \
	  --capture $$(CAPTURE) \
	  $(2)/$(3).tpe

ARDUINO_TARGETS += arduino-$(1)-simulate arduino-$(1)-build \
  arduino-$(1)-upload arduino-$(1)-profile
ARDUINO_BUILD_FLAGS_$(1) := $(EXAMPLE_BUILD_FLAGS) $$(call link_flags,$(EXAMPLE_LINK))
ARDUINO_LINK_$(1) := $(EXAMPLE_LINK)
ARDUINO_LINK_ROLE_$(1) := $(EXAMPLE_LINK_ROLE)
$(if $(EXAMPLE_LINK),ARDUINO_LINKS += $(EXAMPLE_LINK))
$(if $(EXAMPLE_LINK),LINK_ROLES_$(EXAMPLE_LINK) += $(EXAMPLE_LINK_ROLE))
$(if $(EXAMPLE_LINK),LINK_EXAMPLE_$(EXAMPLE_LINK)_$(EXAMPLE_LINK_ROLE) := $(1))
ARDUINO_BOARDS += $(4)
ARDUINO_EXAMPLES_$(4) += $(1)
$(if $(EXAMPLE_LOG_FLAGS),$(call arduino_log,$(1),$(2),$(3),$(4)))
$(if $(EXAMPLE_RECORD_FLAGS),$(call arduino_record,$(1),$(2),$(3),$(4)))
endef

# The target -log of the Arduino example $(1), as in arduino_template.
define arduino_log
arduino-$(1)-log: tempore-cli arduino-deps
	$$(call port_setup,$(4))$$(call link_setup,$(1),$$(call port,$(4)))PLATFORMIO_BUILD_FLAGS="$$(call device_flags,$$(ARDUINO_BUILD_FLAGS_$(1)) $(EXAMPLE_LOG_FLAGS))" \
	  $$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3)-log \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),warn) \
	  --upload --port $$(call port,$(4)) \
	  --capture $$(CAPTURE) \
	  $(2)/$(3).tpe

ARDUINO_LOGS += $(1)
ARDUINO_LOGS_$(4) += $(1)
ARDUINO_TARGETS += arduino-$(1)-log
ARDUINO_LOG_FLAGS_$(1) = $(EXAMPLE_LOG_FLAGS)
endef

# The targets -record and -capture of the Arduino example $(1), as in
# arduino_template: -record builds and uploads the project
# _arduino/projects/$(3)-record with the build flags EXAMPLE_RECORD_FLAGS and
# reads the serial port for CAPTURE seconds; -capture, without an upload,
# as in arduino_record_tool under EXAMPLE_RECORD_TOOL, and otherwise reads
# the serial port for CAPTURE seconds into
# _arduino/recordings/$(1)-TIME.log, TIME the date and time of the capture,
# and writes the recordings extracted from it by the awk program
# EXAMPLE_RECORD_FILTER, run under the locale C, to
# _arduino/recordings/$(1)-TIME.csv, or reports that no recording was read in
# full.
define arduino_record
arduino-$(1)-record: tempore-cli arduino-deps
	$$(call port_setup,$(4))$$(call link_setup,$(1),$$(call port,$(4)))PLATFORMIO_BUILD_FLAGS="$$(call device_flags,$$(ARDUINO_BUILD_FLAGS_$(1)) $(EXAMPLE_RECORD_FLAGS))" \
	  $$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3)-record \
	  --device $(2)/$(3).device.json \
	  --monitor $$(or $$(MONITOR),warn) \
	  --upload --port $$(call port,$(4)) \
	  --capture $$(CAPTURE) \
	  $(2)/$(3).tpe

$(if $(EXAMPLE_RECORD_TOOL),$(call arduino_record_tool,$(1),$(4)),$(call \
  arduino_record_filter,$(1),$(2),$(3),$(4)))
ARDUINO_RECORDS_$(4) += $(1)
ARDUINO_TARGETS += arduino-$(1)-record arduino-$(1)-capture
ARDUINO_RECORD_FLAGS_$(1) = $(EXAMPLE_RECORD_FLAGS)
endef

# The target -capture of the Arduino example $(1) under
# EXAMPLE_RECORD_FILTER, as in arduino_record.
define arduino_record_filter
arduino-$(1)-capture: tempore-cli
	mkdir -p _arduino/recordings
	$$(call port_setup,$(4))name=_arduino/recordings/$(1)-$$$$(date +%Y%m%d-%H%M%S); \
	$$(TEMPORE) --grades $(EXAMPLE_GRADES) \
	  --emit-arduino $(3)-record \
	  --device $(2)/$(3).device.json \
	  --capture $$(CAPTURE) --port $$(call port,$(4)) \
	  $(2)/$(3).tpe | tee "$$$$name.log"; \
	LC_ALL=C awk -f $(EXAMPLE_RECORD_FILTER) "$$$$name.log" > "$$$$name.csv"; \
	if [ -s "$$$$name.csv" ]; then echo "Wrote $$$$name.csv"; \
	else rm -f "$$$$name.csv"; \
	  echo "No complete recording was read; the serial output is in $$$$name.log."; \
	  exit 1; fi

ARDUINO_CAPTURED_$(1) = _arduino/recordings/$(1)-TIME.csv
endef

# The targets -capture and -erase of the Arduino example $(1) of the board
# $(2) under EXAMPLE_RECORD_TOOL: -capture asks the device for its
# recordings, waiting CAPTURE seconds for the answer, and writes the lines
# read to _arduino/recordings/$(1)-TIME.log and each recording N to
# _arduino/recordings/$(1)-TIME-N.csv; -erase asks the device to erase them.
define arduino_record_tool
arduino-$(1)-capture:
	mkdir -p _arduino/recordings
	$$(call port_setup,$(2))python3 -I $(EXAMPLE_RECORD_TOOL) capture --port $$(call port,$(2)) \
	  --wait $$(CAPTURE) _arduino/recordings/$(1)-$$$$(date +%Y%m%d-%H%M%S)

arduino-$(1)-erase:
	$$(call port_setup,$(2))python3 -I $(EXAMPLE_RECORD_TOOL) erase --port $$(call port,$(2)) \
	  --wait $$(CAPTURE)

ARDUINO_CAPTURED_$(1) = _arduino/recordings/$(1)-TIME-N.csv
ARDUINO_ERASES_$(2) += $(1)
ARDUINO_TARGETS += arduino-$(1)-erase
endef

arduino_example = $(call arduino_template,$(1),$(2),$(call \
  arduino_program,$(2)),$(call arduino_board,$(2)))

# The port of the board $(1): PORT, or else PORT_BOARD, or else the shell
# variable port, set by the command port_setup, prefixed to the commands that
# open the port, to the port found by scripts/port.sh.
port_set = $(or $(PORT),$($(call port_variable,$(1))))
port = $(or $(call port_set,$(1)),"$$port")
port_setup = $(if $(call port_set,$(1)),,port=$$(sh scripts/port.sh $(1)) \
  || exit 1; )

$(foreach name,$(OPENTRONS_EXAMPLES),$(eval $(call \
  load_example,opentrons,$(name))))
$(foreach name,$(ARDUINO_EXAMPLES),$(eval $(call \
  load_example,arduino,$(name))))

opentrons-simulate-all: $(OPENTRONS_EXAMPLES:%=opentrons-%-simulate)
arduino-simulate-all: $(ARDUINO_EXAMPLES:%=arduino-%-simulate)
arduino-build-all: $(ARDUINO_EXAMPLES:%=arduino-%-build)

# The title of the board $(1), the member "title" of its profile, and its
# USB identifiers, the member "usb", separated by ' or '.
board_title = $(shell sed -n 's/^ *"title": *"\([^"]*\)".*/\1/p' \
  src/05-backends/arduino/boards/$(1).json)
board_usb = $(shell sed -n 's/^ *"usb": *\[\(.*\)\].*/\1/p' \
  src/05-backends/arduino/boards/$(1).json | tr -d '" ' | sed 's/,/ or /g')

# The port of the board $(1) in the help: PORT_BOARD if set, and else how it
# is found.
board_port_help = $(or $($(call port_variable,$(1))),$(if $(call \
  board_usb,$(1)),found by USB $(call board_usb,$(1)),not set))

# A newline, which ends the lines of the recipe of each board below.
define newline


endef

# The help of the Arduino examples of the board $(1): its title, port
# variable and port, and the targets of its examples.
define arduino_board_help
	@echo "$(call board_title,$(1)), port $(call port_variable,$(1)) = $(call board_port_help,$(1)):"
	@echo "  NAME one of: $(ARDUINO_EXAMPLES_$(1))"
	@echo "  arduino-NAME-simulate         simulates the project on the host"
	@echo "  arduino-NAME-build            builds the project with PlatformIO"
	@echo "  arduino-NAME-upload           builds the project and uploads it to the board"
endef

# The help of the diagnostic targets of the Arduino examples of the board
# $(1): its title, port variable and port, and the targets of its examples.
define arduino_diagnostics_board_help
	@echo "$(call board_title,$(1)), port $(call port_variable,$(1)) = $(call board_port_help,$(1)):"
	@echo "  NAME one of: $(ARDUINO_EXAMPLES_$(1))"
	@echo "  arduino-NAME-profile          uploads the project with the profile and reads the port"
	@$(foreach name,$(ARDUINO_LOGS_$(1)),printf '  %-29s %s\n' \
	  "arduino-$(name)-log" \
	  "uploads the project with $(ARDUINO_LOG_FLAGS_$(name)) and reads the port";)
	@$(foreach name,$(ARDUINO_RECORDS_$(1)),printf '  %-29s %s\n' \
	  "arduino-$(name)-record" \
	  "uploads the project with $(ARDUINO_RECORD_FLAGS_$(name)) and reads the port" \
	  "arduino-$(name)-capture" \
	  "reads the recordings from the port into $(ARDUINO_CAPTURED_$(name))" \
	  $(if $(filter $(name),$(ARDUINO_ERASES_$(1))),"arduino-$(name)-erase" \
	  "erases the recordings on the device");)
endef

examples-help:
	@echo "Arduino examples, by board:"
	$(foreach board,$(sort $(ARDUINO_BOARDS)),$(call arduino_board_help,$(board))$(newline))
	@echo "All Arduino examples:"
	@echo "  arduino-simulate-all          arduino-NAME-simulate for every example"
	@echo "  arduino-build-all             arduino-NAME-build for every example"
	@echo "Opentrons examples, NAME one of: $(OPENTRONS_EXAMPLES)"
	@echo "  opentrons-NAME-emit           writes the protocol to _opentrons/protocols/NAME.py"
	@echo "  opentrons-NAME-simulate       writes the protocol and runs the Opentrons simulator"
	@echo "  opentrons-simulate-all        opentrons-NAME-simulate for every example"
	@echo "Variables, with their values:"
	@printf '  %-44s %s\n' \
	  "PORT=$(PORT)" "when set, the port of every board" \
	  "SIMULATE=$(SIMULATE)" "when set, the simulated seconds of every example" \
	  "MONITOR=$(MONITOR)" "when set, the monitor policy of every target" \
	  "BRIGHTNESS=$(BRIGHTNESS)" "when set, the display brightness, 0 to 100 % (default 24), of every build"
	@$(foreach link,$(sort $(ARDUINO_LINKS)),echo "ESP-NOW link $(link), roles $(LINK_ROLES_$(link)): paired by the link files $(link) and $(link)-PAIR"; \
	  echo "  in ~/.config/tempore/links or REMOTE_LINK_DIR, each board found by its address, or REMOTE_LINK_FILE;"; \
	  echo "  REMOTE_PEER and REMOTE_KEY override its address and key";)
	@printf '  %-44s %s\n' \
	  "PAIR=$(PAIR)" "when set, the pair of the board, by the link file LINK-PAIR" \
	  "REPLACE=$(REPLACE)" "when 1, a new board replaces that of its role in the default pair"
	@echo "Diagnostic targets (profiles, logs and recordings): make arduino-diagnostics-help"

arduino-diagnostics-help:
	@echo "Arduino diagnostic targets, by board:"
	$(foreach board,$(sort $(ARDUINO_BOARDS)),$(call arduino_diagnostics_board_help,$(board))$(newline))
	@echo "Variables, with their values:"
	@printf '  %-44s %s\n' \
	  "PORT=$(PORT)" "when set, the port of every board" \
	  "CAPTURE=$(CAPTURE)" "the seconds for which the port is read" \
	  "MONITOR=$(MONITOR)" "when set, the monitor policy of every target" \
	  "BRIGHTNESS=$(BRIGHTNESS)" "when set, the display brightness, 0 to 100 % (default 24), of every build"

.PHONY: tempore-cli opentrons-simulate-all arduino-simulate-all \
  arduino-build-all examples-help arduino-diagnostics-help \
  $(ARDUINO_TARGETS) \
  $(OPENTRONS_EXAMPLES:%=opentrons-%-emit) \
  $(OPENTRONS_EXAMPLES:%=opentrons-%-simulate)
