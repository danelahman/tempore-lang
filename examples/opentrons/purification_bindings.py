# Binding functions of the operations of purification.tpe for the Opentrons
# Flex.
#
# The samples are the first four wells of a PCR plate on the deck, moved onto
# and off a magnetic block by the gripper. The reservoir holds the beads (A1),
# the ethanol (A2) and the elution buffer (A3), and receives the liquid waste
# (A12); the eluates go to a PCR plate on the aluminium block of the
# temperature module, held at 4 °C. The ethanol is added to every sample from
# above with one tip; every other liquid is moved with a new tip for each
# sample. Each function declares the nominal duration of its action in
# seconds by tempore_elapse, the duration the virtual clock of a simulation
# advances by.

SAMPLES = ["A1", "B1", "C1", "D1"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_200ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D1")
    plate = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D2")
    module = protocol.load_module("temperature module gen2", "D3")
    block = module.load_adapter("opentrons_96_well_aluminum_block")
    eluates = block.load_labware("opentrons_96_wellplate_200ul_pcr_full_skirt", label="eluates")
    module.set_temperature(4)
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
    }


def AddBeads(ctx, samples):
    ctx["pipette"].transfer(50, ctx["reservoir"]["A1"], ctx["samples"], mix_after=(5, 40), new_tip="always")
    tempore_elapse(90)
    return "beads"


def MagnetOn(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], ctx["magnet"], use_gripper=True)
    tempore_elapse(30)
    return ()


def MagnetOff(ctx, unit):
    ctx["protocol"].move_labware(ctx["plate"], "D2", use_gripper=True)
    tempore_elapse(30)
    return ()


def RemoveSupernatant(ctx, beads):
    ctx["pipette"].transfer(80, ctx["samples"], ctx["reservoir"]["A12"], new_tip="always")
    tempore_elapse(90)
    return ()


def AddEthanol(ctx, unit):
    ctx["pipette"].transfer(150, ctx["reservoir"]["A2"], [sample.top() for sample in ctx["samples"]], new_tip="once")
    tempore_elapse(45)
    return ()


def RemoveEthanol(ctx, unit):
    ctx["pipette"].transfer(150, ctx["samples"], ctx["reservoir"]["A12"], new_tip="always")
    tempore_elapse(90)
    return ()


def RemoveResidualEthanol(ctx, beads):
    ctx["pipette"].transfer(10, ctx["samples"], ctx["reservoir"]["A12"], new_tip="always")
    tempore_elapse(45)
    return ()


def EluteDNA(ctx, beads):
    ctx["pipette"].transfer(25, ctx["reservoir"]["A3"], ctx["samples"], mix_after=(5, 20), new_tip="always")
    tempore_elapse(90)
    return ()


def Transfer(ctx, beads_and_samples):
    ctx["pipette"].transfer(20, ctx["samples"], ctx["eluates"], new_tip="always")
    tempore_elapse(90)
    return ()
