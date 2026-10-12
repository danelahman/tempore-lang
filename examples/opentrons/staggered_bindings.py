# Binding functions of the operations of staggered.tpe for the Opentrons
# Flex.
#
# The cells grow in the first four wells of the columns of a flat plate. The
# reservoir holds the fixative (A1) and the rinse buffer (A2), and receives
# the liquid waste (A12). Each function declares the nominal duration of its
# action in seconds by tempore_elapse, the duration the virtual clock of a
# simulation advances by.

ROWS = ["A", "B", "C", "D"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_1000ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D2")
    plate = protocol.load_labware("corning_96_wellplate_360ul_flat", "C2")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {"pipette": pipette, "reservoir": reservoir, "plate": plate}


def column(ctx, number):
    return [ctx["plate"]["%s%d" % (row, number)] for row in ROWS]


def Fix(ctx, number):
    ctx["pipette"].distribute(100, ctx["reservoir"]["A1"], column(ctx, number))
    tempore_elapse(90)
    return number


def Rinse(ctx, number):
    pipette = ctx["pipette"]
    pipette.consolidate(100, column(ctx, number), ctx["reservoir"]["A12"])
    pipette.distribute(200, ctx["reservoir"]["A2"], column(ctx, number))
    tempore_elapse(90)
    return ()
