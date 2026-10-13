# The make targets of the example: the grades of its program and the
# simulated time of its host simulation, in seconds.
EXAMPLE_GRADES = regex-timed-interval-rational-symbolic
EXAMPLE_SIMULATE = 8

# The build flags of the target -log: the log of ../bala2/bindings.cpp,
# every BALANCE_LOG milliseconds.
BALANCE_LOG ?= 20
EXAMPLE_LOG_FLAGS = -DBALANCE_LOG=$(BALANCE_LOG)
