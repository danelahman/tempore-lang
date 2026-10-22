Opentrons protocols: with --bind, --emit-opentrons writes the program as a
protocol, its operations performed by the functions of the binding file. The
protocol is run here with the stub opentrons package of stub/, whose protocol
context prints the commands it is given, in simulation, on the virtual clock.

  $ simulate () {
  >   python3 protocol_driver.py "_opentrons/protocols/$1"
  > }
  $ examples=../../examples/opentrons

The ELISA example: the incubations and the development are delays of the
protocol, in minutes, and each call of a binding function is checked against
the running-time bounds its grade implies under time-interval and commented as
it completes; each delay outside a default implementation is commented before
it waits.

  $ ../../tempore --grades time-interval --emit-opentrons elisa.py \
  >   --bind $examples/elisa_bindings.py --time-unit minutes $examples/elisa.tpe
  Wrote _opentrons/protocols/elisa.py
  $ head -4 _opentrons/protocols/elisa.py
  # An Opentrons protocol compiled by Tempore from elisa.tpe.
  
  metadata = {"protocolName": "elisa", "description": "Compiled by Tempore from elisa.tpe"}
  requirements = {"robotType": "Flex", "apiLevel": "2.30"}
  $ simulate elisa.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_1000ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D2')
  load_labware('corning_96_wellplate_360ul_flat', 'C2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_1000ul in B3])
  comment: Tempore run 1
  pipette.transfer(50, [A1 of C1, B1 of C1, C1 of C1, D1 of C1, E1 of C1, F1 of C1, G1 of C1, H1 of C1], [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], new_tip='always')
  comment: Tempore timeline: At 0 s: operation `AddSample` took 120 s, within its running-time bounds [60, 180] s
  pipette.transfer(50, A3 of D2, A4 of D2, mix_after=(3, 500))
  comment: Tempore timeline: At 120 s: operation `Dilute` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 210 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 390 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 570 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.distribute(50, A4 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 750 s: operation `Detect` took 120 s, within its running-time bounds [60, 180] s
  comment: Tempore timeline: At 870 s: delay of 3900 s
  delay(seconds=3900.0)
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 4770 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.distribute(100, A5 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 4950 s: operation `Develop` took 60 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 5010 s: delay of 1020 s
  delay(seconds=1020.0)
  pipette.distribute(100, A6 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 6030 s: operation `Stop` took 45 s, within its running-time bounds [0, 60] s
  comment: Read the absorbances of plate at 450 nm
  comment: Tempore timeline: At 6075 s: operation `Read` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns 0

The bead clean-up example, its operations declaring their running times under
regex-timed-rigid-interval-rational-symbolic, a time unit given in seconds.

  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-opentrons washes.py \
  >   --bind $examples/washes_bindings.py --time-unit 60 $examples/washes.tpe
  Wrote _opentrons/protocols/washes.py
  $ simulate washes.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D3')
  load_module('magneticBlockV1', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  comment: Tempore run 1
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40), new_tip='always')
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 90 s: delay of 420 s
  delay(seconds=420.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 510 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 540 s: delay of 180 s
  delay(seconds=180.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 720 s: operation `RemoveLiquid` took 90 s, within its running-time bounds [60, 120] s
  pipette.pick_up_tip()
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='never')
  pipette.transfer(150, A1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, B1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, C1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, D1 of D2, A12 of D1, new_tip='never')
  comment: Tempore timeline: At 810 s: operation `Wash` took 90 s, within its running-time bounds [60, 120] s
  pipette.drop_tip()
  pipette.pick_up_tip()
  comment: Tempore timeline: At 900 s: operation `ChangeTip` took 15 s, within its running-time bounds (0, 60] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='never')
  pipette.transfer(150, A1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, B1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, C1 of D2, A12 of D1, new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(150, D1 of D2, A12 of D1, new_tip='never')
  comment: Tempore timeline: At 915 s: operation `Wash` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1005 s: delay of 180 s
  delay(seconds=180.0)
  pipette.drop_tip()
  pipette.pick_up_tip()
  comment: Tempore timeline: At 1185 s: operation `ChangeTip` took 15 s, within its running-time bounds (0, 60] s
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 1200 s: operation `MagnetOff` took 30 s, within its running-time bounds (0, 60] s
  pipette.transfer(25, A3 of D1, A1 of D2, mix_after=(5, 20), new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(25, A3 of D1, B1 of D2, mix_after=(5, 20), new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(25, A3 of D1, C1 of D2, mix_after=(5, 20), new_tip='never')
  pipette.drop_tip()
  pipette.pick_up_tip()
  pipette.transfer(25, A3 of D1, D1 of D2, mix_after=(5, 20), new_tip='never')
  pipette.drop_tip()
  comment: Tempore timeline: At 1230 s: operation `EluteDNA` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1320 s: delay of 120 s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1440 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1470 s: delay of 180 s
  delay(seconds=180.0)
  pipette.transfer(20, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of D3, B1 of D3, C1 of D3, D1 of D3], new_tip='always')
  comment: Tempore timeline: At 1650 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()

The ddPCR example, the time bound of each operation's grade under
time-upper-bound-levels its upper bound.

  $ ../../tempore --grades time-upper-bound-levels --emit-opentrons contamination.py \
  >   --bind $examples/contamination_bindings.py --time-unit minutes \
  >   --api-level 2.29 $examples/contamination.tpe
  Wrote _opentrons/protocols/contamination.py
  $ simulate contamination.py | grep -v '^pipette'
  requirements: {'robotType': 'Flex', 'apiLevel': '2.29'}
  load_labware('opentrons_flex_96_filtertiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'C2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_filtertiprack_200ul in B3])
  comment: Tempore run 1
  comment: Tempore timeline: At 0 s: operation `PrepareMix` took 180 s, within its running-time bounds [0, 300] s
  comment: Tempore timeline: At 180 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 195 s: operation `AddBuffer` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 235 s: operation `AddBuffer` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 275 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 290 s: operation `AddArticle` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 330 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 345 s: operation `Dilute` took 90 s, within its running-time bounds [0, 120] s
  comment: Tempore timeline: At 435 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 450 s: operation `Dilute` took 90 s, within its running-time bounds [0, 120] s
  comment: Tempore timeline: At 540 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 555 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 595 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 635 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 675 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 715 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 730 s: operation `AddDilution` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 770 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 785 s: operation `AddDilution` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 825 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 840 s: operation `AddDilution` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 880 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 895 s: operation `AddWater` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore run 1 returns ()

The examples whose boxes carry the specification, under time-interval: thawed
reagents dispensed within their window by a function polymorphic in it,
columns fixed at staggered times by a recursion that passes each box on, beads
boxed while they settle and while they air-dry, and plates boxed by the stop
solution in the case of a handler that simulates the reader.

  $ ../../tempore --grades time-interval --emit-opentrons reagents.py \
  >   --bind $examples/reagents_bindings.py --time-unit minutes $examples/reagents.tpe
  Wrote _opentrons/protocols/reagents.py
  $ simulate reagents.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_module('temperature module gen2', 'D1')
  temperature module gen2.load_labware('opentrons_24_aluminumblock_nest_1.5ml_snapcap')
  temperature module gen2.set_temperature(4)
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_module('thermocyclerModuleV2', 'B1')
  thermocyclerModuleV2.load_labware('nest_96_wellplate_100ul_pcr_full_skirt')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  thermocyclerModuleV2.open_lid()
  comment: Tempore run 1
  comment: Thaw the amplicon tagment mix
  pipette.pick_up_tip()
  pipette.mix(3, 20, A1 of temperature module gen2)
  pipette.drop_tip()
  comment: Tempore timeline: At 0 s: operation `Thaw` took 360 s, within its running-time bounds [300, 600] s
  pipette.transfer(10, B1 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 360 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(5, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], mix_after=(3, 10), new_tip='always')
  comment: Tempore timeline: At 450 s: operation `AddDNA` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(5, A1 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 540 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  comment: Thaw the neutralize tagment buffer
  pipette.pick_up_tip()
  pipette.mix(3, 20, C1 of temperature module gen2)
  pipette.drop_tip()
  comment: Tempore timeline: At 630 s: operation `Thaw` took 360 s, within its running-time bounds [300, 600] s
  thermocyclerModuleV2.close_lid()
  thermocyclerModuleV2.set_block_temperature(55, hold_time_minutes=5)
  thermocyclerModuleV2.set_block_temperature(10)
  thermocyclerModuleV2.open_lid()
  comment: Tempore timeline: At 990 s: operation `Tagment` took 360 s, within its running-time bounds [300, 420] s
  pipette.transfer(5, C1 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 1350 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons staggered.py \
  >   --bind $examples/staggered_bindings.py --time-unit minutes $examples/staggered.tpe
  Wrote _opentrons/protocols/staggered.py
  $ simulate staggered.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_1000ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D2')
  load_labware('corning_96_wellplate_360ul_flat', 'C2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_1000ul in B3])
  comment: Tempore run 1
  pipette.distribute(100, A1 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2])
  comment: Tempore timeline: At 0 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 90 s: delay of 840 s
  delay(seconds=840.0)
  pipette.distribute(100, A1 of D2, [A2 of C2, B2 of C2, C2 of C2, D2 of C2])
  comment: Tempore timeline: At 930 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A1 of C2, B1 of C2, C1 of C2, D1 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2])
  comment: Tempore timeline: At 1020 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1110 s: delay of 780 s
  delay(seconds=780.0)
  pipette.distribute(100, A1 of D2, [A3 of C2, B3 of C2, C3 of C2, D3 of C2])
  comment: Tempore timeline: At 1890 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A2 of C2, B2 of C2, C2 of C2, D2 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A2 of C2, B2 of C2, C2 of C2, D2 of C2])
  comment: Tempore timeline: At 1980 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 2070 s: delay of 780 s
  delay(seconds=780.0)
  pipette.distribute(100, A1 of D2, [A4 of C2, B4 of C2, C4 of C2, D4 of C2])
  comment: Tempore timeline: At 2850 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A3 of C2, B3 of C2, C3 of C2, D3 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A3 of C2, B3 of C2, C3 of C2, D3 of C2])
  comment: Tempore timeline: At 2940 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 3030 s: delay of 840 s
  delay(seconds=840.0)
  pipette.consolidate(100, [A4 of C2, B4 of C2, C4 of C2, D4 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A4 of C2, B4 of C2, C4 of C2, D4 of C2])
  comment: Tempore timeline: At 3870 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons beads.py \
  >   --bind $examples/beads_bindings.py --time-unit minutes $examples/beads.tpe
  Wrote _opentrons/protocols/beads.py
  $ simulate beads.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D3')
  load_module('magneticBlockV1', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  comment: Tempore run 1
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40), new_tip='always')
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 90 s: delay of 300 s
  delay(seconds=300.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 390 s: operation `MagnetOn` took 30 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 420 s: delay of 240 s
  delay(seconds=240.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 660 s: operation `RemoveLiquid` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2])
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 750 s: operation `Wash` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2])
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 840 s: operation `FinalWash` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 930 s: delay of 120 s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 1050 s: operation `MagnetOff` took 30 s, within its running-time bounds [0, 60] s
  pipette.transfer(25, A3 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 20), new_tip='always')
  comment: Tempore timeline: At 1080 s: operation `EluteDNA` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1170 s: delay of 120 s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1290 s: operation `MagnetOn` took 30 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 1320 s: delay of 180 s
  delay(seconds=180.0)
  pipette.transfer(20, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of D3, B1 of D3, C1 of D3, D1 of D3], new_tip='always')
  comment: Tempore timeline: At 1500 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons stopread.py \
  >   --bind $examples/stopread_bindings.py --time-unit minutes $examples/stopread.tpe
  Wrote _opentrons/protocols/stopread.py
  $ simulate stopread.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_1000ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D2')
  load_labware('corning_96_wellplate_360ul_flat', 'C1')
  load_labware('corning_96_wellplate_360ul_flat', 'C2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_1000ul in B3])
  comment: Tempore run 1
  pipette.distribute(100, A12 of D2, [A1 of C1, B1 of C1, C1 of C1, D1 of C1, E1 of C1, F1 of C1, G1 of C1, H1 of C1])
  comment: Tempore timeline: At 0 s: operation `AddStop` took 60 s, within its running-time bounds [60, 120] s
  pipette.distribute(100, A12 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 60 s: operation `AddStop` took 60 s, within its running-time bounds [60, 120] s
  comment: Simulated reading of plate 1 at 450 nm
  comment: Tempore timeline: At 120 s: operation `Note` took 0 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 120 s: delay of 60 s
  delay(seconds=60.0)
  comment: Simulated reading of plate 2 at 450 nm
  comment: Tempore timeline: At 180 s: operation `Note` took 0 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 180 s: delay of 60 s
  delay(seconds=60.0)
  comment: Tempore run 1 returns (0, 0)

The bead clean-up by compound operations: the handler of the run performs each
compound operation by the atomic operations its grade names, so only the
atomic operations call binding functions and are commented. The compound
operations, which have neither binding functions nor defaults, are neither
errors nor warnings.

  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-opentrons cleanup.py \
  >   --bind $examples/cleanup_bindings.py --time-unit minutes $examples/cleanup.tpe
  Wrote _opentrons/protocols/cleanup.py
  $ simulate cleanup.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D3')
  load_module('magneticBlockV1', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  comment: Tempore run 1
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40), new_tip='always')
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 90 s: delay of 420 s
  delay(seconds=420.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 510 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 540 s: delay of 240 s
  delay(seconds=240.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 780 s: operation `RemoveLiquid` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='once')
  comment: Tempore timeline: At 870 s: operation `AddEthanol` took 45 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 915 s: delay of 60 s
  delay(seconds=60.0)
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 975 s: operation `RemoveEthanol` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='once')
  comment: Tempore timeline: At 1065 s: operation `AddEthanol` took 45 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1110 s: delay of 60 s
  delay(seconds=60.0)
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 1170 s: operation `RemoveEthanol` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1260 s: delay of 180 s
  delay(seconds=180.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 1440 s: operation `MagnetOff` took 30 s, within its running-time bounds (0, 60] s
  pipette.transfer(25, A3 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 20), new_tip='always')
  comment: Tempore timeline: At 1470 s: operation `AddBuffer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1560 s: delay of 180 s
  delay(seconds=180.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1740 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1770 s: delay of 240 s
  delay(seconds=240.0)
  pipette.transfer(20, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of D3, B1 of D3, C1 of D3, D1 of D3], new_tip='always')
  comment: Tempore timeline: At 2010 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns "beads"

The bead purification by steps that unbox and rebox the beads: boxes generate
no actions, so the protocol performs only the operations and the delays of
the steps, and the binding function of AddBeads returns the beads.

  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --emit-opentrons purification.py \
  >   --bind $examples/purification_bindings.py --time-unit minutes $examples/purification.tpe
  Wrote _opentrons/protocols/purification.py
  $ simulate purification.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_module('temperature module gen2', 'D3')
  temperature module gen2.load_adapter('opentrons_96_well_aluminum_block')
  opentrons_96_well_aluminum_block.load_labware('opentrons_96_wellplate_200ul_pcr_full_skirt', label='eluates')
  temperature module gen2.set_temperature(4)
  load_module('magneticBlockV1', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  comment: Tempore run 1
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40), new_tip='always')
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 90 s: delay of 450 s
  delay(seconds=450.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 540 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 570 s: delay of 240 s
  delay(seconds=240.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 810 s: operation `RemoveSupernatant` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='once')
  comment: Tempore timeline: At 900 s: operation `AddEthanol` took 45 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 945 s: delay of 60 s
  delay(seconds=60.0)
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 1005 s: operation `RemoveEthanol` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [top of A1 of D2, top of B1 of D2, top of C1 of D2, top of D1 of D2], new_tip='once')
  comment: Tempore timeline: At 1095 s: operation `AddEthanol` took 45 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1140 s: delay of 45 s
  delay(seconds=45.0)
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 1185 s: operation `RemoveEthanol` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(10, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='always')
  comment: Tempore timeline: At 1275 s: operation `RemoveResidualEthanol` took 45 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1320 s: delay of 210 s
  delay(seconds=210.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 1530 s: operation `MagnetOff` took 30 s, within its running-time bounds (0, 60] s
  pipette.transfer(25, A3 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 20), new_tip='always')
  comment: Tempore timeline: At 1560 s: operation `EluteDNA` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 1650 s: delay of 180 s
  delay(seconds=180.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1830 s: operation `MagnetOn` took 30 s, within its running-time bounds (0, 60] s
  comment: Tempore timeline: At 1860 s: delay of 150 s
  delay(seconds=150.0)
  pipette.transfer(20, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of opentrons_96_well_aluminum_block, B1 of opentrons_96_well_aluminum_block, C1 of opentrons_96_well_aluminum_block, D1 of opentrons_96_well_aluminum_block], new_tip='always')
  comment: Tempore timeline: At 2010 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore timeline: At 2100 s: delay of 210 s
  delay(seconds=210.0)
  pipette.transfer(25, A4 of D1, [A1 of opentrons_96_well_aluminum_block, B1 of opentrons_96_well_aluminum_block, C1 of opentrons_96_well_aluminum_block, D1 of opentrons_96_well_aluminum_block], mix_after=(3, 30), new_tip='always')
  comment: Tempore timeline: At 2310 s: operation `AddMasterMix` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()

The rejected variants of the examples.

  $ ../../tempore --grades time-interval --typecheck-only $examples/elisa_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `incubating` is unboxed with grade `[30, 30]` accumulated since it was bound, which is not below its box grade `[60, ∞)`
  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --typecheck-only $examples/washes_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: This function's body has grade `{(Wash; (Wash; ChangeTip)*)?}`, which does not match its annotated grade `{(Wash; ChangeTip)*}`
  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --typecheck-only $examples/cleanup_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `k` is unboxed with grade `{RemoveEthanol; idle 1; AddEthanol}` accumulated since it was bound, which is not below its box grade `{AddEthanol; 1; RemoveEthanol}`
  $ ../../tempore --grades regex-timed-rigid-interval-rational-symbolic --typecheck-only $examples/purification_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `warm` is unboxed with grade `{idle 10; MagnetOn; idle 5; RemoveSupernatant; AddEthanol; idle 1; RemoveEthanol; AddEthanol; idle 0.75; RemoveEthanol; RemoveResidualEthanol; idle 5; MagnetOff; EluteDNA; idle 3; MagnetOn; idle 2.5}` accumulated since it was bound, which is not below its box grade `{[0, 40]}`
  Typing error: The resource inequality `{AddEthanol; idle [0.5, 1.5]; RemoveEthanol} <= {AddEthanol; idle [0.5, 1.5]}` does not hold
  Typing error: Variable `soaking` is unboxed with grade `{AddEthanol; MagnetOff; idle 0.5}` accumulated since it was bound, which is not below its box grade `{AddEthanol; idle [0.5, 1.5]}`
  $ ../../tempore --grades time-upper-bound-levels --typecheck-only $examples/contamination_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `article_tip` is unboxed with grade `(1, High)` accumulated since it was bound, which is not below its box grade `(∞, Low)`
  $ for name in reagents staggered beads stopread; do
  >   ../../tempore --grades time-interval --typecheck-only $examples/${name}_reject.tpe 2>&1 | grep 'Typing error'
  > done
  Typing error: The resource inequality `[35, 37] <= [0, 30]` does not hold
  Typing error: Variable `fixing` is unboxed with grade `[7, 9]` accumulated since it was bound, which is not below its box grade `[12, 20]`
  Typing error: Variable `drying` is unboxed with grade `[4, 5]` accumulated since it was bound, which is not below its box grade `[2, 3]`
  Typing error: Variable `first` is unboxed with grade `[31, 32]` accumulated since it was bound, which is not below its box grade `[0, 30]`

Run as a script, a protocol executes its program as the interpreter does,
without the binding file.

  $ python3 _opentrons/protocols/elisa.py
  === Run 1 ===
  return 0
  
  $ ../../tempore --grades time-interval $examples/elisa.tpe | head -2
  === Run 1 ===
  return 0

Under a grading monoid with compound operations, an atomic operation that a
handler has a case for, with neither a binding function nor a default
implementation, is a warning, and such a compound operation is not.

  $ ../../tempore --grades regex-timed-interval-symbolic --emit-opentrons atomic_handled.py \
  >   --bind protocol_bindings.py protocol_atomic_handled.tpe
  Warning: Operation `Probe`, which run 1 may perform, has neither a binding function nor a default implementation; a handler in the run's code has a case for it, so the run fails only if it performs it outside every such handler
  Wrote _opentrons/protocols/atomic_handled.py

An atomic operation that a handler in a run's code has a case for, but that
has neither a binding function nor a default implementation, is a warning. A
definition that no run uses is not compiled, nor are its operations checked.

  $ ../../tempore --grades time-interval --emit-opentrons ok.py \
  >   --bind protocol_bindings.py protocol_ok.tpe
  Warning: Operation `Probe`, which run 2 may perform, has neither a binding function nor a default implementation; a handler in the run's code has a case for it, so the run fails only if it performs it outside every such handler
  Wrote _opentrons/protocols/ok.py
  $ simulate ok.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  comment: setup
  comment: Tempore run 1
  comment: pipette 1
  comment: Tempore timeline: At 0 s: operation `Pipette` took 1 s, within its running-time bounds [1, 2] s
  comment: Tempore run 1 returns 2
  comment: Tempore run 2
  comment: Tempore run 2 returns 7
  comment: Tempore run 3
  comment: Tempore timeline: At 1 s: delay of 3 s
  delay(seconds=3.0)
  delay(seconds=1.0)
  comment: pipette 2
  comment: Tempore timeline: At 5 s: operation `Pipette` took 1 s, within its running-time bounds [1, 2] s
  comment: Tempore run 3 returns 3

A binding function outside the bounds of its operation ends the protocol under
the policy abort, after the comment of the call; under warn it is
reported by a comment; under off it is neither checked nor recorded.

  $ PIPETTE_SECONDS=3 simulate ok.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  comment: setup
  comment: Tempore run 1
  comment: pipette 1
  comment: Tempore timeline: At 0 s: operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  error: tempore_BoundViolation: Operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  $ ../../tempore --grades time-interval --emit-opentrons ok_warn.py --monitor warn \
  >   --bind protocol_bindings.py protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/ok_warn.py
  $ PIPETTE_SECONDS=3 simulate ok_warn.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  comment: setup
  comment: Tempore run 1
  comment: pipette 1
  comment: Tempore timeline: At 0 s: operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore warning: Operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore run 1 returns 2
  comment: Tempore run 2
  comment: Tempore run 2 returns 7
  comment: Tempore run 3
  comment: Tempore timeline: At 3 s: delay of 3 s
  delay(seconds=3.0)
  delay(seconds=1.0)
  comment: pipette 2
  comment: Tempore timeline: At 7 s: operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore warning: Operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore run 3 returns 3
  $ ../../tempore --grades time-interval --emit-opentrons ok_off.py --monitor off \
  >   --bind protocol_bindings.py protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/ok_off.py
  $ PIPETTE_SECONDS=3 simulate ok_off.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  comment: setup
  comment: Tempore run 1
  comment: pipette 1
  comment: Tempore run 1 returns 2
  comment: Tempore run 2
  comment: Tempore run 2 returns 7
  comment: Tempore run 3
  comment: Tempore timeline: At 3 s: delay of 3 s
  delay(seconds=3.0)
  delay(seconds=1.0)
  comment: pipette 2
  comment: Tempore run 3 returns 3

An operation that a run may perform, directly or through a definition or a
default implementation, with neither a binding function nor a default
implementation declared above the run, refuses the protocol.

  $ ../../tempore --grades time-interval --emit-opentrons lost.py \
  >   --bind protocol_bindings.py protocol_lost.tpe
  Error: Operation `Lost`, which run 1 may perform, has neither a binding function nor a default implementation
  Error: Operation `Shake`, which run 1 may perform, has neither a binding function nor a default implementation
  [1]
  $ test -e _opentrons/protocols/lost.py
  [1]

A binding file may not define names with the prefixes of the runtime, the names
of the protocol or those of the compiled program, and must define setup.

  $ ../../tempore --grades time-interval --emit-opentrons bad.py \
  >   --bind protocol_bad_bindings.py protocol_ok.tpe
  Error: protocol_bad_bindings.py, line 4: the name `_tempore_os` begins with `tempore_` or `_tempore_`, which are reserved for the runtime and the compiled program
  Error: protocol_bad_bindings.py, line 5: the name `tempore_join` begins with `tempore_` or `_tempore_`, which are reserved for the runtime and the compiled program
  Error: protocol_bad_bindings.py, line 7: the name `tempore_count` begins with `tempore_` or `_tempore_`, which are reserved for the runtime and the compiled program
  Error: protocol_bad_bindings.py, line 8: the name `metadata` is defined by the protocol
  Error: protocol_bad_bindings.py, line 11: the name `run` is defined by the protocol
  Error: protocol_bad_bindings.py, line 15: the name `probe_0` is defined by the compiled program
  Error: protocol_bad_bindings.py: no function `setup` is defined
  Error: Operation `Pipette`, which run 1 may perform, has neither a binding function nor a default implementation
  Error: Operation `Pipette`, which run 3 may perform, has neither a binding function nor a default implementation
  [1]

The Flex is the only robot.

  $ ../../tempore --emit-opentrons ot2.py --robot ot2 \
  >   --bind protocol_bindings.py protocol_ok.tpe 2>&1 | head -1
  ../../tempore: option '--robot': 'ot2' is not one of flex.

The options of protocols require --bind, and --bind requires --emit-opentrons.

  $ ../../tempore --bind protocol_bindings.py protocol_ok.tpe
  ../../tempore: option '--bind' requires '--emit-opentrons'.
  [2]
  $ ../../tempore --emit-opentrons plain.py --robot flex protocol_ok.tpe
  ../../tempore: option '--robot' requires '--bind'.
  [2]
  $ ../../tempore --emit-opentrons plain.py --bind protocol_bindings.py --time-unit 0 protocol_ok.tpe 2>&1 | head -1
  ../../tempore: option '--time-unit': '0' is neither seconds, minutes, hours nor a positive number of seconds.
  $ ../../tempore --emit-opentrons plain.py --bind protocol_bindings.py --monitor stop protocol_ok.tpe 2>&1 | head -1
  ../../tempore: option '--monitor': 'stop' is not one of abort, warn, off.

A file name without a directory is that of a file in _opentrons/protocols of
the current directory, which is created with its missing ancestors; a name
with a directory is used as given. The path of the file written is printed.

  $ mkdir fresh && cd fresh
  $ ../../../tempore --grades time-interval --emit-opentrons plain.py ../protocol_ok.tpe
  Wrote _opentrons/protocols/plain.py
  $ ls _opentrons/protocols
  plain.py
  $ cd ..
  $ mkdir -p partial/_opentrons && cd partial
  $ ../../../tempore --grades time-interval --emit-opentrons plain.py ../protocol_ok.tpe
  Wrote _opentrons/protocols/plain.py
  $ ls _opentrons/protocols
  plain.py
  $ cd ..
  $ ../../tempore --grades time-interval --emit-opentrons ./plain.py protocol_ok.tpe
  Wrote ./plain.py
  $ mkdir out
  $ ../../tempore --grades time-interval --emit-opentrons out/plain.py protocol_ok.tpe
  Wrote out/plain.py
  $ ../../tempore --grades time-interval --emit-opentrons "$PWD/out/absolute.py" protocol_ok.tpe
  Wrote $TESTCASE_ROOT/out/absolute.py
  $ test -e plain.py && test -e out/plain.py && test -e out/absolute.py

A file that cannot be written, or a binding file that cannot be read, is an
error.

  $ ../../tempore --grades time-interval --emit-opentrons missing/plain.py protocol_ok.tpe
  Error: missing/plain.py: No such file or directory
  [1]
  $ ../../tempore --grades time-interval --emit-opentrons missing/ok.py --bind protocol_bindings.py protocol_ok.tpe 2> /dev/null
  [1]
  $ ../../tempore --grades time-interval --emit-opentrons ok.py --bind missing.py protocol_ok.tpe
  Error: missing.py: No such file or directory
  [1]

With --simulate, the protocol written is run by the Opentrons simulator,
opentrons_simulate on the PATH or the executable given by --simulator, whose
output is passed through and whose exit code is that of tempore. Here the
simulator is a script that prints a run log naming its argument; a second
one fails.

  $ mkdir bin
  $ cat > bin/opentrons_simulate <<'SCRIPT'
  > #!/bin/sh
  > echo "Simulated $1"
  > echo "Tempore run 1"
  > echo "a warning of the simulator" >&2
  > SCRIPT
  $ cat > failing_simulate <<'SCRIPT'
  > #!/bin/sh
  > echo "Simulating $1"
  > echo "Error: the protocol failed" >&2
  > exit 1
  > SCRIPT
  $ chmod +x bin/opentrons_simulate failing_simulate
  $ PATH="$PWD/bin:$PATH" ../../tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/sim.py
  Simulated _opentrons/protocols/sim.py
  Tempore run 1
  $ PATH="$PWD/bin:$PATH" ../../tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2>&1 >/dev/null | grep -v '^Warning'
  a warning of the simulator
  $ ../../tempore --grades time-interval --emit-opentrons sim.py --bind protocol_bindings.py \
  >   --simulate --simulator ./failing_simulate protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/sim.py
  Simulating _opentrons/protocols/sim.py
  [1]
  $ ../../tempore --grades time-interval --emit-opentrons sim.py --bind protocol_bindings.py \
  >   --simulate --simulator ./missing_simulate protocol_ok.tpe 2>&1 | grep -v '^Warning'
  Wrote _opentrons/protocols/sim.py
  Error: the Opentrons simulator './missing_simulate' was not found
  $ PATH=/nonexistent ../../tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2>&1 | grep -v '^Warning'
  Wrote _opentrons/protocols/sim.py
  Error: the Opentrons simulator opentrons_simulate was not found on the PATH or in _opentrons; 'make opentrons-deps' installs it with Python 3.10 or later

Without --simulator and opentrons_simulate on the PATH, the simulator is that
of the virtual environment _opentrons installed by 'make opentrons-deps', in
the directory of the executable or else in the current directory, run with
OT_API_CONFIG_DIR set to its directory config unless the environment sets it.
Here the simulator is a script that prints its argument and that variable;
opentrons_simulate on the PATH takes precedence over it.

  $ mkdir -p repo/_opentrons/bin
  $ cp ../../tempore repo/tempore
  $ cat > repo/_opentrons/bin/opentrons_simulate <<'SCRIPT'
  > #!/bin/sh
  > echo "Simulated $1"
  > echo "OT_API_CONFIG_DIR=${OT_API_CONFIG_DIR#$PWD/}"
  > SCRIPT
  $ chmod +x repo/_opentrons/bin/opentrons_simulate
  $ PATH=/usr/bin:/bin repo/tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/sim.py
  Simulated _opentrons/protocols/sim.py
  OT_API_CONFIG_DIR=repo/_opentrons/config
  $ PATH=/usr/bin:/bin OT_API_CONFIG_DIR=elsewhere repo/tempore --grades time-interval \
  >   --emit-opentrons sim.py --bind protocol_bindings.py --simulate protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/sim.py
  Simulated _opentrons/protocols/sim.py
  OT_API_CONFIG_DIR=elsewhere
  $ PATH="$PWD/bin:/usr/bin:/bin" repo/tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2> /dev/null
  Wrote _opentrons/protocols/sim.py
  Simulated _opentrons/protocols/sim.py
  Tempore run 1
  $ cd repo
  $ PATH=/usr/bin:/bin ../../../tempore --grades time-interval --emit-opentrons ../sim.py \
  >   --bind ../protocol_bindings.py --simulate ../protocol_ok.tpe 2> /dev/null
  Wrote ../sim.py
  Simulated ../sim.py
  OT_API_CONFIG_DIR=_opentrons/config
  $ cd ..

  $ ../../tempore --emit-opentrons sim.py --simulate protocol_ok.tpe
  ../../tempore: option '--simulate' requires '--bind'.
  [2]
  $ ../../tempore --emit-opentrons sim.py --simulator ./failing_simulate protocol_ok.tpe
  ../../tempore: option '--simulator' requires '--bind'.
  [2]
