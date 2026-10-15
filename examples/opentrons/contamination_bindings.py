# Binding functions of the operations of contamination.tpe for the Opentrons
# Flex.
#
# The preparation plate and the final plate are 96-well PCR plates, each
# operation dispensing into the first four wells of a column. The reservoir
# holds the buffer (A1), the master mix components (A2, A3, mixed into A4),
# the test article (A5) and the water (A6). The tips are filter tips. The
# pipette keeps its tip between operations; ChangeTip replaces it, picking up
# the first, PrepareMix uses a tip of its own and AddWater drops the tip after
# the water. The entry "has_tip" of the context records whether the pipette
# holds a tip. A tip and the master mix are passed to the functions as the
# Tempore values of types tip and reagent, which they ignore. Each function
# declares the nominal duration of its action in seconds by tempore_elapse,
# the duration the virtual clock of a simulation advances by.

ROWS = ["A", "B", "C", "D"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_filtertiprack_200ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D1")
    preparation = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D2")
    final = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "C2")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {
        "pipette": pipette,
        "reservoir": reservoir,
        "preparation": preparation,
        "final": final,
        "has_tip": False,
    }


def pick_up_tip(ctx):
    if ctx["has_tip"]:
        ctx["pipette"].drop_tip()
    ctx["pipette"].pick_up_tip()
    ctx["has_tip"] = True


def drop_tip(ctx):
    if ctx["has_tip"]:
        ctx["pipette"].drop_tip()
    ctx["has_tip"] = False


def column(ctx, plate, number):
    return [ctx[plate]["%s%d" % (row, number)] for row in ROWS]


def dispense(ctx, volume, source, plate, number):
    ctx["pipette"].transfer(volume, ctx["reservoir"][source], column(ctx, plate, number), new_tip="never")


def transfer_column(ctx, volume, source, target, mix_after):
    for well, destination in zip(column(ctx, *source), column(ctx, *target)):
        ctx["pipette"].transfer(volume, well, destination, mix_after=mix_after, new_tip="never")


def ChangeTip(ctx, unit):
    pick_up_tip(ctx)
    tempore_elapse(15)
    return ()


def AddBuffer(ctx, tip_and_column):
    _, number = tip_and_column
    dispense(ctx, 20, "A1", "preparation", number)
    tempore_elapse(40)
    return ()


def PrepareMix(ctx, unit):
    pipette = ctx["pipette"]
    pick_up_tip(ctx)
    pipette.transfer(100, ctx["reservoir"]["A2"], ctx["reservoir"]["A4"], new_tip="never")
    pipette.transfer(100, ctx["reservoir"]["A3"], ctx["reservoir"]["A4"], mix_after=(5, 150), new_tip="never")
    drop_tip(ctx)
    tempore_elapse(180)
    return "master mix"


def AddMix(ctx, tip_and_mix_and_column):
    _, (_, number) = tip_and_mix_and_column
    dispense(ctx, 20, "A4", "final", number)
    tempore_elapse(40)
    return ()


def AddArticle(ctx, tip_and_column):
    _, number = tip_and_column
    dispense(ctx, 20, "A5", "preparation", number)
    tempore_elapse(40)
    return ()


def Dilute(ctx, tip_and_columns):
    _, (source, target) = tip_and_columns
    transfer_column(ctx, 10, ("preparation", source), ("preparation", target), (3, 20))
    tempore_elapse(90)
    return ()


def AddDilution(ctx, tip_and_columns):
    _, (source, target) = tip_and_columns
    transfer_column(ctx, 5, ("preparation", source), ("final", target), (3, 15))
    tempore_elapse(40)
    return ()


def AddWater(ctx, tip_and_column):
    _, number = tip_and_column
    dispense(ctx, 5, "A6", "final", number)
    drop_tip(ctx)
    tempore_elapse(40)
    return ()
