# Binding functions of the operations of binding.tpe for the Opentrons Flex.
#
# The lysates, of 400 µL, are the first four wells of a deep-well plate on the
# deck, moved onto and off a magnetic block by the gripper. The reservoir
# holds the beads in their binding buffer (A1) and the ethanol (A2), and
# receives the liquid waste (A12); the ethanol of the washes is dispensed
# into the first four wells of a second deep-well plate, the wash plate. The
# beads, the mixes and the removal of the liquid use a new tip for each
# lysate, and the wash plate is filled with one tip. Each function declares
# the nominal duration of its action in seconds by tempore_elapse, the
# duration the virtual clock of a simulation advances by.

SAMPLES = ["A1", "B1", "C1", "D1"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_1000ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D1")
    plate = protocol.load_labware("nest_96_wellplate_2ml_deep", "D2")
    wash = protocol.load_labware("nest_96_wellplate_2ml_deep", "D3")
    magnet = protocol.load_module("magneticBlockV1", "C1")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {
        "protocol": protocol,
        "pipette": pipette,
        "reservoir": reservoir,
        "plate": plate,
        "magnet": magnet,
        "samples": [plate[well] for well in SAMPLES],
        "washes": [wash[well] for well in SAMPLES],
    }


def AddBeads(ctx, unit):
    ctx["pipette"].transfer(
        100, ctx["reservoir"]["A1"], ctx["samples"], mix_after=(5, 200), new_tip="always"
    )
    tempore_elapse(90)
    return ()


def Mix(ctx, unit):
    pipette = ctx["pipette"]
    for sample in ctx["samples"]:
        pipette.pick_up_tip()
        pipette.mix(10, 250, sample)
        pipette.drop_tip()
    tempore_elapse(90)
    return ()


def FillWashPlate(ctx, unit):
    ctx["pipette"].transfer(500, ctx["reservoir"]["A2"], ctx["washes"], new_tip="once")
    tempore_elapse(150)
    return ()


def MagnetOn(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], ctx["magnet"], use_gripper=True)
    tempore_elapse(30)
    return ()


def MagnetOff(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], "D2", use_gripper=True)
    tempore_elapse(30)
    return ()


def RemoveLiquid(ctx, unit):
    ctx["pipette"].transfer(500, ctx["samples"], ctx["reservoir"]["A12"], new_tip="always")
    tempore_elapse(90)
    return ()
