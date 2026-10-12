# Binding functions of the operations of contamination.tpe for the Opentrons
# Flex.
#
# The plate is a 96-well PCR plate whose columns 1 to 4 are set up, each
# operation dispensing into the first four wells of a column. The reservoir
# holds the buffer (A1), the master mix components (A2, A3, mixed into A4),
# the test article (A5) and the water (A6). The pipette keeps its tip between
# operations; ChangeTip replaces it, picking up the first. A tip is passed to
# the functions as the Tempore value of type tip, which they ignore. Each
# function declares the nominal duration of its action in seconds by
# tempore_elapse, the duration the virtual clock of a simulation advances by.

ROWS = ["A", "B", "C", "D"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_200ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D1")
    plate = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D2")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {"pipette": pipette, "reservoir": reservoir, "plate": plate, "tip": False}


def column(ctx, number):
    return [ctx["plate"]["%s%d" % (row, number)] for row in ROWS]


def dispense(ctx, volume, source, number):
    ctx["pipette"].transfer(volume, ctx["reservoir"][source], column(ctx, number), new_tip="never")


def ChangeTip(ctx, arg):
    if ctx["tip"]:
        ctx["pipette"].drop_tip()
    ctx["pipette"].pick_up_tip()
    ctx["tip"] = True
    tempore_elapse(15)
    return ()


def AddBuffer(ctx, arg):
    dispense(ctx, 20, "A1", arg[1])
    tempore_elapse(40)
    return ()


def PrepareMix(ctx, arg):
    pipette = ctx["pipette"]
    pipette.pick_up_tip()
    pipette.transfer(100, ctx["reservoir"]["A2"], ctx["reservoir"]["A4"], new_tip="never")
    pipette.transfer(100, ctx["reservoir"]["A3"], ctx["reservoir"]["A4"], mix_after=(5, 150), new_tip="never")
    pipette.drop_tip()
    tempore_elapse(180)
    return ()


def AddMix(ctx, arg):
    dispense(ctx, 10, "A4", arg[1])
    tempore_elapse(40)
    return ()


def AddArticle(ctx, arg):
    dispense(ctx, 20, "A5", arg[1])
    tempore_elapse(40)
    return ()


def Dilute(ctx, arg):
    source, target = arg[1]
    pipette = ctx["pipette"]
    for row in ROWS:
        pipette.transfer(10, ctx["plate"]["%s%d" % (row, source)], ctx["plate"]["%s%d" % (row, target)], mix_after=(3, 20), new_tip="never")
    tempore_elapse(90)
    return ()


def AddWater(ctx, arg):
    dispense(ctx, 5, "A6", arg[1])
    ctx["pipette"].drop_tip()
    tempore_elapse(40)
    return ()
