# The make targets of the example: the grades of its program and the
# simulated time of its host simulation, in seconds.
EXAMPLE_GRADES = regex-timed-rigid-interval-rational-symbolic
EXAMPLE_SIMULATE = 12

# The encrypted ESP-NOW link of its device builds, bala2-radio, in which
# its board has the role robot; the address of the controller and the key of
# the link are those of its link file, kept by scripts/link.sh.
EXAMPLE_LINK = bala2-radio
EXAMPLE_LINK_ROLE = robot

# The spread of the angular rate admitted by CheckAtRest in its device
# builds, 25 degrees per second, which admits the tremor of a hand that
# holds the robot still.
EXAMPLE_BUILD_FLAGS = -DTEMPORE_IMU_REST_SPREAD=25
