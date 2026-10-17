# The make targets of the example: the grades of its program and the
# simulated time of its host simulation, in seconds.
EXAMPLE_GRADES = regex-timed-rigid-interval-rational-symbolic
EXAMPLE_SIMULATE = 12

# The build flags of every device build: the address of the controller,
# REMOTE_PEER, six bytes in hexadecimal separated by colons, as the
# controller logs it at the start of its link, passed as the build flag
# ESP_NOW_PEER of the package esp-now; without it the robot sends to every
# device and receives from any (the broadcast address).
REMOTE_PEER ?=
EXAMPLE_BUILD_FLAGS = $(if $(REMOTE_PEER),-DESP_NOW_PEER=0x$(subst :,$(comma)0x,$(REMOTE_PEER)))
