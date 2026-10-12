# Runs the Opentrons protocol given as the argument with the stub protocol
# context of stub/opentrons, which prints the commands the protocol gives.

import importlib.util
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "stub"))

from opentrons import protocol_api

spec = importlib.util.spec_from_file_location("protocol", sys.argv[1])
protocol = importlib.util.module_from_spec(spec)
spec.loader.exec_module(protocol)
print("requirements: %s" % protocol.requirements)
try:
    protocol.run(protocol_api.ProtocolContext(simulating=True))
except Exception as error:
    print("error: %s: %s" % (type(error).__name__, error))
