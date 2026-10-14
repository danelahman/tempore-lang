# Binding functions of the operations of enzyme.tpe for the Opentrons Flex.
#
# The enzyme mix is in the first column of a PCR plate on the aluminium block
# of the temperature module, held at 4 °C. The gripper moves it to D2 for a
# round, and back. The four plates of the reactions stand in C2, C3, B1 and
# B2; each is moved onto the block for its round, the enzyme mix dispensed
# into its twelve columns by the 8-channel pipette with one column of tips,
# and moved back. Each function declares the nominal duration of its action
# in seconds by tempore_elapse, the duration the virtual clock of a
# simulation advances by.

SLOTS = ["C2", "C3", "B1", "B2"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_50ul", "B3")
    module = protocol.load_module("temperature module gen2", "D1")
    block = module.load_adapter("opentrons_96_well_aluminum_block")
    enzyme = block.load_labware("opentrons_96_wellplate_200ul_pcr_full_skirt", label="enzyme mix")
    module.set_temperature(4)
    plates = [
        protocol.load_labware("opentrons_96_wellplate_200ul_pcr_full_skirt", slot, label="reactions %d" % (index + 1))
        for index, slot in enumerate(SLOTS)
    ]
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_8channel_50", "left", tip_racks=[tips])
    return {
        "protocol": protocol,
        "pipette": pipette,
        "block": block,
        "enzyme": enzyme,
        "plates": plates,
    }


def TakeOut(ctx, unit):
    ctx["protocol"].move_labware(ctx["enzyme"], "D2", use_gripper=True)
    tempore_elapse(30)
    return ()


def ReturnToCold(ctx, unit):
    ctx["protocol"].move_labware(ctx["enzyme"], ctx["block"], use_gripper=True)
    tempore_elapse(30)
    return ()


def LoadPlate(ctx, plate):
    ctx["protocol"].move_labware(ctx["plates"][plate - 1], ctx["block"], use_gripper=True)
    tempore_elapse(30)
    return ()


def Dispense(ctx, plate):
    columns = ctx["plates"][plate - 1].columns()
    ctx["pipette"].distribute(10, ctx["enzyme"]["A1"], [column[0] for column in columns], new_tip="once")
    tempore_elapse(210)
    return ()


def UnloadPlate(ctx, plate):
    ctx["protocol"].move_labware(ctx["plates"][plate - 1], SLOTS[plate - 1], use_gripper=True)
    tempore_elapse(30)
    return ()
