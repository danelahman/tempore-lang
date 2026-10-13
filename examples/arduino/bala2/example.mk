# The make targets of the example: the grades of its program and the
# simulated time of its host simulation, in seconds.
EXAMPLE_GRADES = time-interval-rational
EXAMPLE_SIMULATE = 8

# The build flags of the target -log: the log of bindings.cpp, every
# BALANCE_LOG milliseconds.
BALANCE_LOG ?= 20
EXAMPLE_LOG_FLAGS = -DBALANCE_LOG=$(BALANCE_LOG)

# The build flags of the target -record: the recording of bindings.cpp, one
# sample every BALANCE_RECORD milliseconds; the awk program that extracts the
# recordings read by the target -capture.
BALANCE_RECORD ?= 20
EXAMPLE_RECORD_FLAGS = -DBALANCE_RECORD=$(BALANCE_RECORD)
EXAMPLE_RECORD_FILTER = examples/arduino/bala2/recordings.awk
