# The make targets of the example: the grades of its program and the
# simulated time of its host simulation, in seconds.
EXAMPLE_GRADES = operation-spacing
EXAMPLE_SIMULATE = 46

# The build flags of the target -record: the recording of bindings.cpp in
# flash memory, at most STEPS_RECORD seconds; the script with which the
# targets -capture and -erase read and erase the recordings.
STEPS_RECORD ?= 600
EXAMPLE_RECORD_FLAGS = -DSTEPS_RECORD=$(STEPS_RECORD)
EXAMPLE_RECORD_TOOL = scripts/steps-recording.py
