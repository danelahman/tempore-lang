# Binding functions of the operations of elisa.tpe for the Opentrons Flex.
#
# The plate is a pre-coated 96-well flat plate; the samples, in the first
# column of a PCR plate, go to the wells of its first column. The reservoir
# holds the wash buffer (A2), the detection antibody concentrate and diluent
# (A3, A4), the substrate (A5) and the stop solution (A6), and receives the
# liquid waste (A12). Each
# function declares the nominal duration of its action in seconds by
# tempore_elapse, the duration the virtual clock of a simulation advances by.

WELLS = ["A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1"]


def setup(protocol):
    tips = protocol.load_labware("opentrons_flex_96_tiprack_1000ul", "B3")
    reservoir = protocol.load_labware("nest_12_reservoir_15ml", "D2")
    plate = protocol.load_labware("corning_96_wellplate_360ul_flat", "C2")
    samples = protocol.load_labware("nest_96_wellplate_100ul_pcr_full_skirt", "C1")
    protocol.load_trash_bin("A3")
    pipette = protocol.load_instrument("flex_1channel_1000", "left", tip_racks=[tips])
    return {
        "protocol": protocol,
        "pipette": pipette,
        "reservoir": reservoir,
        "samples": [samples[well] for well in WELLS],
        "wells": [plate[well] for well in WELLS],
    }


def dispense_to_samples(ctx, volume, source):
    ctx["pipette"].distribute(volume, ctx["reservoir"][source], ctx["wells"])


def AddSample(ctx, plate):
    ctx["pipette"].transfer(50, ctx["samples"], ctx["wells"], new_tip="always")
    tempore_elapse(120)
    return plate


def Wash(ctx, plate):
    pipette = ctx["pipette"]
    pipette.consolidate(300, ctx["wells"], ctx["reservoir"]["A12"])
    dispense_to_samples(ctx, 300, "A2")
    tempore_elapse(180)
    return plate


def Dilute(ctx, arg):
    ctx["pipette"].transfer(50, ctx["reservoir"]["A3"], ctx["reservoir"]["A4"], mix_after=(3, 500))
    tempore_elapse(90)
    return "detection antibody"


def Detect(ctx, arg):
    plate, antibody = arg
    dispense_to_samples(ctx, 50, "A4")
    tempore_elapse(120)
    return plate


def Develop(ctx, plate):
    dispense_to_samples(ctx, 100, "A5")
    tempore_elapse(60)
    return plate


def Stop(ctx, plate):
    dispense_to_samples(ctx, 100, "A6")
    tempore_elapse(45)
    return plate


def Read(ctx, plate):
    ctx["protocol"].comment("Read the absorbances of %s at 450 nm" % plate)
    tempore_elapse(90)
    return 0
