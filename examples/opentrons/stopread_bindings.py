# Binding functions of the operations of stopread.tpe for the Opentrons Flex.
#
# The plates are flat 96-well plates in C1 ("plate 1") and C2 ("plate 2"),
# their samples in the wells of the first column. The reservoir holds the
# stop solution (A1). Stop and Read are handled by the simulated reader of
# the program, which performs AddStop and Note. Each function declares the
# nominal duration of its action in seconds by tempore_elapse, the duration
# the virtual clock of a simulation advances by.

ROWS = ["A", "B", "C", "D", "E", "F", "G", "H"]
SLOTS = {"plate 1": "C1", "plate 2": "C2"}


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_1000ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D2")
    plates = {
        name: protocol.load_labware("corning_96_wellplate_360ul_flat", slot) for name, slot in SLOTS.items()
    }
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {"protocol": protocol, "pipette": pipette, "reservoir": reservoir, "plates": plates}


def AddStop(ctx, plate):
    wells = [ctx["plates"][plate]["%s1" % row] for row in ROWS]
    ctx["pipette"].distribute(50, ctx["reservoir"]["A1"], wells)
    tempore_elapse(60)
    return plate


def Note(ctx, plate):
    ctx["protocol"].comment("Simulated reading of %s at 450 nm" % plate)
    return ()
