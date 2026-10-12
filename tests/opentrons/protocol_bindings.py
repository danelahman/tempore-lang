# Binding functions of the operations of protocol_ok.tpe: Pipette takes the
# number of seconds given by the environment variable PIPETTE_SECONDS, or 1.

import os

PIPETTE_SECONDS = int(os.environ.get("PIPETTE_SECONDS", "1"))


def setup(protocol):
    protocol.comment("setup")
    return {"protocol": protocol}


def Pipette(ctx, volume):
    ctx["protocol"].comment("pipette %d" % volume)
    tempore_elapse(PIPETTE_SECONDS)
    return volume + 1
