# Binding functions of the operations of washes.tpe for the Opentrons Flex.
#
# The samples are the first four wells of a PCR plate on the deck, moved onto
# and off a magnetic block by the gripper. The reservoir holds the beads (A1),
# the ethanol (A2) and the elution buffer (A3), and receives the liquid waste
# (A12). The beads, the supernatant and the eluates are moved with a new tip
# for each sample. An ethanol wash adds the ethanol to every sample from above
# with the tip it finds on the pipette, or a new one, and removes it from each
# sample with a tip of its own, keeping the last; ChangeTip replaces the tip,
# and the elution buffer is added with the tip it leaves, then a new tip for
# each further sample. The context records whether the pipette holds a tip.
# Each function declares the nominal duration of its action in seconds by
# tempore_elapse, the duration the virtual clock of a simulation advances by.

SAMPLES = ["A1", "B1", "C1", "D1"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_200ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D1")
    plate = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D2")
    eluates = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D3")
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
        "eluates": [eluates[well] for well in SAMPLES],
        "tip": False,
    }


def AddBeads(ctx, unit):
    ctx["pipette"].transfer(50, ctx["reservoir"]["A1"], ctx["samples"], mix_after=(5, 40), new_tip="always")
    tempore_elapse(90)
    return ()


def Engage(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], ctx["magnet"], use_gripper=True)
    tempore_elapse(30)
    return ()


def Disengage(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], "D2", use_gripper=True)
    tempore_elapse(30)
    return ()


def RemoveSupernatant(ctx, unit):
    ctx["pipette"].transfer(80, ctx["samples"], ctx["reservoir"]["A12"], new_tip="always")
    tempore_elapse(90)
    return ()


def Ethanol(ctx, unit):
    pipette = ctx["pipette"]
    if not ctx["tip"]:
        pipette.pick_up_tip()
        ctx["tip"] = True
    pipette.transfer(150, ctx["reservoir"]["A2"], [sample.top() for sample in ctx["samples"]], new_tip="never")
    for index, sample in enumerate(ctx["samples"]):
        if index > 0:
            pipette.drop_tip()
            pipette.pick_up_tip()
        pipette.transfer(150, sample, ctx["reservoir"]["A12"], new_tip="never")
    tempore_elapse(90)
    return ()


def ChangeTip(ctx, unit):
    if ctx["tip"]:
        ctx["pipette"].drop_tip()
    ctx["pipette"].pick_up_tip()
    ctx["tip"] = True
    tempore_elapse(15)
    return ()


def Elute(ctx, unit):
    pipette = ctx["pipette"]
    for sample in ctx["samples"]:
        if not ctx["tip"]:
            pipette.pick_up_tip()
        pipette.transfer(25, ctx["reservoir"]["A3"], sample, mix_after=(5, 20), new_tip="never")
        pipette.drop_tip()
        ctx["tip"] = False
    tempore_elapse(90)
    return ()


def Transfer(ctx, unit):
    ctx["pipette"].transfer(20, ctx["samples"], ctx["eluates"], new_tip="always")
    tempore_elapse(90)
    return ()
