# Binding functions of the operations of reagents.tpe for the Opentrons Flex.
#
# The reagent tubes stand in an aluminium block on the temperature module,
# held at 4 °C: the amplicon tagment mix (A1), the tagment DNA buffer (B1) and
# the neutralize tagment buffer (C1), dispensed at 5, 10 and 5 µL. The DNA
# samples are in the first wells of the columns of a PCR plate in D2, and the
# tagmentation takes place in the first four wells of the columns of a PCR
# plate on the thermocycler. A reagent is passed as the Tempore value
# Reagent name, a tempore_Con whose argument is its name; Thaw returns the
# value it is given. Each function declares the nominal duration of its action
# in seconds by tempore_elapse, the duration the virtual clock of a simulation
# advances by.

ROWS = ["A", "B", "C", "D"]
TUBES = {
    "amplicon tagment mix": "A1",
    "tagment DNA buffer": "B1",
    "neutralize tagment buffer": "C1",
}
VOLUMES = {
    "amplicon tagment mix": 5,
    "tagment DNA buffer": 10,
    "neutralize tagment buffer": 5,
}


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_200ul", "B3")
    block = protocol.load_module("temperature module gen2", "D1")
    tubes = block.load_labware("opentrons_24_aluminumblock_nest_1.5ml_snapcap")
    block.set_temperature(4)
    samples = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "D2")
    cycler = protocol.load_module("thermocyclerModuleV2", "B1")
    plate = cycler.load_labware("nest_96_wellplate_100ul_pcr_full_skirt")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    cycler.open_lid()
    return {
        "protocol": protocol,
        "pipette": pipette,
        "tubes": tubes,
        "samples": samples,
        "cycler": cycler,
        "plate": plate,
    }


def column(ctx, labware, number):
    return [ctx[labware]["%s%d" % (row, number)] for row in ROWS]


def Thaw(ctx, reagent):
    name = reagent.arg
    pipette = ctx["pipette"]
    ctx["protocol"].comment("Thaw the %s" % name)
    pipette.pick_up_tip()
    pipette.mix(3, 20, ctx["tubes"][TUBES[name]])
    pipette.drop_tip()
    tempore_elapse(360)
    return reagent


def Dispense(ctx, reagent_and_column):
    reagent, number = reagent_and_column
    name = reagent.arg
    ctx["pipette"].transfer(VOLUMES[name], ctx["tubes"][TUBES[name]], column(ctx, "plate", number), new_tip="always")
    tempore_elapse(90)
    return ()


def AddDNA(ctx, number):
    ctx["pipette"].transfer(
        5, column(ctx, "samples", number), column(ctx, "plate", number), mix_after=(3, 10), new_tip="always"
    )
    tempore_elapse(90)
    return ()


def Tagment(ctx, number):
    cycler = ctx["cycler"]
    cycler.close_lid()
    cycler.set_block_temperature(55, hold_time_minutes=5)
    cycler.set_block_temperature(10)
    cycler.open_lid()
    tempore_elapse(360)
    return ()
