Opentrons protocols: with --bind, --emit-opentrons writes the program as a
protocol, its operations performed by the functions of the binding file. The
protocol is run here with the stub opentrons package of stub/, whose protocol
context prints the commands it is given, in simulation, on the virtual clock.

  $ simulate () {
  >   python3 protocol_driver.py "$1"
  > }
  $ examples=../../examples/opentrons

The ELISA example: the incubations and the development are delays of the
protocol, in minutes, and each call of a binding function is checked against
the running-time bounds its grade implies under time-interval and commented as
it completes.

  $ ../../tempore --grades time-interval --emit-opentrons elisa.py \
  >   --bind $examples/elisa_bindings.py --time-unit minutes $examples/elisa.tpe
  $ head -4 elisa.py
  # An Opentrons protocol compiled by Tempore from elisa.tpe.
  
  metadata = {"protocolName": "elisa", "description": "Compiled by Tempore from elisa.tpe"}
  requirements = {"robotType": "Flex", "apiLevel": "2.30"}
  $ simulate elisa.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_1000ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D2')
  load_labware('corning_96_wellplate_360ul_flat', 'C2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_1000ul in B3])
  comment: Tempore run 1
  pipette.distribute(100, A1 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 0 s: operation `Coat` took 120 s, within its running-time bounds [60, 180] s
  delay(seconds=3600.0)
  pipette.transfer(50, A3 of D2, A4 of D2, mix_after=(3, 500))
  comment: Tempore timeline: At 3720 s: operation `Dilute` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 3810 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 3990 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 4170 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.distribute(100, A4 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 4350 s: operation `Detect` took 120 s, within its running-time bounds [60, 180] s
  delay(seconds=3600.0)
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 8070 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 8250 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.consolidate(300, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2], A12 of D2)
  pipette.distribute(300, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 8430 s: operation `Wash` took 180 s, within its running-time bounds [120, 240] s
  pipette.distribute(100, A5 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 8610 s: operation `Develop` took 60 s, within its running-time bounds [60, 120] s
  delay(seconds=900.0)
  pipette.distribute(50, A6 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 9570 s: operation `Stop` took 45 s, within its running-time bounds [0, 60] s
  comment: Read the absorbances of plate at 450 nm
  comment: Tempore timeline: At 9615 s: operation `Read` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns 0

The bead clean-up example, its operations declaring their running times under
regex-timed-interval-symbolic, a time unit given in seconds.

  $ ../../tempore --grades regex-timed-interval-symbolic --emit-opentrons washes.py \
  >   --bind $examples/washes_bindings.py --time-unit 60 $examples/washes.tpe
  $ simulate washes.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D3')
  load_module('magneticBlockV1', 'C1')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  pipette.pick_up_tip()
  comment: Tempore run 1
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40), new_tip='never')
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=300.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 390 s: operation `Engage` took 30 s, within its running-time bounds [0, 60] s
  delay(seconds=180.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='never')
  comment: Tempore timeline: At 600 s: operation `RemoveSupernatant` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], new_tip='never')
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='never')
  comment: Tempore timeline: At 690 s: operation `Ethanol` took 90 s, within its running-time bounds [60, 120] s
  pipette.drop_tip()
  pipette.pick_up_tip()
  comment: Tempore timeline: At 780 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  pipette.transfer(150, A2 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], new_tip='never')
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1, new_tip='never')
  comment: Tempore timeline: At 795 s: operation `Ethanol` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=180.0)
  pipette.drop_tip()
  pipette.pick_up_tip()
  comment: Tempore timeline: At 1065 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 1080 s: operation `Disengage` took 30 s, within its running-time bounds [0, 60] s
  pipette.transfer(25, A3 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 20), new_tip='never')
  comment: Tempore timeline: At 1110 s: operation `Elute` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1320 s: operation `Engage` took 30 s, within its running-time bounds [0, 60] s
  delay(seconds=180.0)
  pipette.transfer(20, A1 of D2, A1 of D3, new_tip='never')
  pipette.transfer(20, B1 of D2, B1 of D3, new_tip='never')
  pipette.transfer(20, C1 of D2, C1 of D3, new_tip='never')
  pipette.transfer(20, D1 of D2, D1 of D3, new_tip='never')
  pipette.drop_tip()
  comment: Tempore timeline: At 1530 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()

The ddPCR example, the time bound of each operation's grade under
time-upper-bound-levels its upper bound.

  $ ../../tempore --grades time-upper-bound-levels --emit-opentrons contamination.py \
  >   --bind $examples/contamination_bindings.py --time-unit minutes \
  >   --api-level 2.29 $examples/contamination.tpe
  $ simulate contamination.py | grep -v '^pipette'
  requirements: {'robotType': 'Flex', 'apiLevel': '2.29'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D1')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  comment: Tempore run 1
  comment: Tempore timeline: At 0 s: operation `PrepareMix` took 180 s, within its running-time bounds [0, 300] s
  comment: Tempore timeline: At 180 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 195 s: operation `AddBuffer` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 235 s: operation `AddBuffer` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 275 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 315 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 355 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 395 s: operation `AddMix` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 435 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 450 s: operation `AddArticle` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 490 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 505 s: operation `Dilute` took 90 s, within its running-time bounds [0, 120] s
  comment: Tempore timeline: At 595 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 610 s: operation `Dilute` took 90 s, within its running-time bounds [0, 120] s
  comment: Tempore timeline: At 700 s: operation `ChangeTip` took 15 s, within its running-time bounds [0, 60] s
  comment: Tempore timeline: At 715 s: operation `AddWater` took 40 s, within its running-time bounds [0, 60] s
  comment: Tempore run 1 returns ()

The examples whose boxes carry the specification, under time-interval: thawed
reagents dispensed within their window by a function polymorphic in it,
columns fixed at staggered times by a recursion that passes each box on, beads
boxed while they settle and while they air-dry, and plates boxed by the stop
solution in the case of a handler that simulates the reader.

  $ ../../tempore --grades time-interval --emit-opentrons reagents.py \
  >   --bind $examples/reagents_bindings.py --time-unit minutes $examples/reagents.tpe
  $ simulate reagents.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_200ul', 'B3')
  load_module('temperature module gen2', 'D1')
  temperature module gen2.load_labware('opentrons_24_aluminumblock_nest_1.5ml_snapcap')
  load_labware('nest_96_wellplate_100ul_pcr_full_skirt', 'D2')
  load_module('thermocyclerModuleV2', 'B1')
  thermocyclerModuleV2.load_labware('nest_96_wellplate_100ul_pcr_full_skirt')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_200ul in B3])
  thermocyclerModuleV2.open_lid()
  comment: Tempore run 1
  comment: Thaw the amplicon tagment mix
  pipette.pick_up_tip()
  pipette.mix(3, 20, A2 of temperature module gen2)
  pipette.drop_tip()
  comment: Tempore timeline: At 0 s: operation `Thaw` took 360 s, within its running-time bounds [300, 600] s
  pipette.transfer(5, A1 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 360 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(5, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], mix_after=(3, 10), new_tip='always')
  comment: Tempore timeline: At 450 s: operation `AddDNA` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(5, A2 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 540 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  comment: Thaw the neutralize tagment buffer
  pipette.pick_up_tip()
  pipette.mix(3, 20, A3 of temperature module gen2)
  pipette.drop_tip()
  comment: Tempore timeline: At 630 s: operation `Thaw` took 360 s, within its running-time bounds [300, 600] s
  thermocyclerModuleV2.close_lid()
  thermocyclerModuleV2.set_block_temperature(55, hold_time_minutes=5)
  thermocyclerModuleV2.set_block_temperature(10)
  thermocyclerModuleV2.open_lid()
  comment: Tempore timeline: At 990 s: operation `Tagment` took 360 s, within its running-time bounds [300, 420] s
  pipette.transfer(5, A3 of temperature module gen2, [A1 of thermocyclerModuleV2, B1 of thermocyclerModuleV2, C1 of thermocyclerModuleV2, D1 of thermocyclerModuleV2], new_tip='always')
  comment: Tempore timeline: At 1350 s: operation `Dispense` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons staggered.py \
  >   --bind $examples/staggered_bindings.py --time-unit minutes $examples/staggered.tpe
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
  delay(seconds=660.0)
  pipette.distribute(100, A1 of D2, [A2 of C2, B2 of C2, C2 of C2, D2 of C2])
  comment: Tempore timeline: At 750 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A1 of C2, B1 of C2, C1 of C2, D1 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2])
  comment: Tempore timeline: At 840 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=600.0)
  pipette.distribute(100, A1 of D2, [A3 of C2, B3 of C2, C3 of C2, D3 of C2])
  comment: Tempore timeline: At 1530 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A2 of C2, B2 of C2, C2 of C2, D2 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A2 of C2, B2 of C2, C2 of C2, D2 of C2])
  comment: Tempore timeline: At 1620 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=600.0)
  pipette.distribute(100, A1 of D2, [A4 of C2, B4 of C2, C4 of C2, D4 of C2])
  comment: Tempore timeline: At 2310 s: operation `Fix` took 90 s, within its running-time bounds [60, 120] s
  pipette.consolidate(100, [A3 of C2, B3 of C2, C3 of C2, D3 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A3 of C2, B3 of C2, C3 of C2, D3 of C2])
  comment: Tempore timeline: At 2400 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=660.0)
  pipette.consolidate(100, [A4 of C2, B4 of C2, C4 of C2, D4 of C2], A12 of D2)
  pipette.distribute(200, A2 of D2, [A4 of C2, B4 of C2, C4 of C2, D4 of C2])
  comment: Tempore timeline: At 3150 s: operation `Rinse` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons beads.py \
  >   --bind $examples/beads_bindings.py --time-unit minutes $examples/beads.tpe
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
  pipette.transfer(50, A1 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 40))
  comment: Tempore timeline: At 0 s: operation `AddBeads` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=300.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 390 s: operation `Engage` took 30 s, within its running-time bounds [0, 60] s
  delay(seconds=180.0)
  pipette.transfer(80, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1)
  comment: Tempore timeline: At 600 s: operation `RemoveSupernatant` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2])
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1)
  comment: Tempore timeline: At 690 s: operation `Ethanol` took 90 s, within its running-time bounds [60, 120] s
  pipette.transfer(150, A2 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2])
  pipette.transfer(150, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], A12 of D1)
  comment: Tempore timeline: At 780 s: operation `LastEthanol` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, 'D2', use_gripper=True)
  comment: Tempore timeline: At 990 s: operation `Disengage` took 30 s, within its running-time bounds [0, 60] s
  pipette.transfer(25, A3 of D1, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], mix_after=(5, 20))
  comment: Tempore timeline: At 1020 s: operation `Elute` took 90 s, within its running-time bounds [60, 120] s
  delay(seconds=120.0)
  move_labware(nest_96_wellplate_100ul_pcr_full_skirt in D2, magneticBlockV1, use_gripper=True)
  comment: Tempore timeline: At 1230 s: operation `Engage` took 30 s, within its running-time bounds [0, 60] s
  delay(seconds=180.0)
  pipette.transfer(20, [A1 of D2, B1 of D2, C1 of D2, D1 of D2], [A1 of D3, B1 of D3, C1 of D3, D1 of D3])
  comment: Tempore timeline: At 1440 s: operation `Transfer` took 90 s, within its running-time bounds [60, 120] s
  comment: Tempore run 1 returns ()
  $ ../../tempore --grades time-interval --emit-opentrons stopread.py \
  >   --bind $examples/stopread_bindings.py --time-unit minutes $examples/stopread.tpe
  $ simulate stopread.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  load_labware('opentrons_flex_96_tiprack_1000ul', 'B3')
  load_labware('nest_12_reservoir_15ml', 'D2')
  load_labware('corning_96_wellplate_360ul_flat', 'C1')
  load_labware('corning_96_wellplate_360ul_flat', 'C2')
  load_trash_bin('A3')
  load_instrument('flex_1channel_1000', 'left', tip_racks=[opentrons_flex_96_tiprack_1000ul in B3])
  comment: Tempore run 1
  pipette.distribute(50, A1 of D2, [A1 of C1, B1 of C1, C1 of C1, D1 of C1, E1 of C1, F1 of C1, G1 of C1, H1 of C1])
  comment: Tempore timeline: At 0 s: operation `AddStop` took 60 s, within its running-time bounds [60, 120] s
  pipette.distribute(50, A1 of D2, [A1 of C2, B1 of C2, C1 of C2, D1 of C2, E1 of C2, F1 of C2, G1 of C2, H1 of C2])
  comment: Tempore timeline: At 60 s: operation `AddStop` took 60 s, within its running-time bounds [60, 120] s
  comment: Simulated reading of plate 1 at 450 nm
  comment: Tempore timeline: At 120 s: operation `Note` took 0 s, within its running-time bounds [0, 60] s
  delay(seconds=60.0)
  comment: Simulated reading of plate 2 at 450 nm
  comment: Tempore timeline: At 180 s: operation `Note` took 0 s, within its running-time bounds [0, 60] s
  delay(seconds=60.0)
  comment: Tempore run 1 returns (0, 0)

The rejected variants of the examples.

  $ ../../tempore --grades time-interval --typecheck-only $examples/elisa_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `coated` is unboxed with grade `[30, 30]` accumulated since it was bound, which is not below its box grade `[60, ∞)`
  $ ../../tempore --grades regex-timed-interval-symbolic --typecheck-only $examples/washes_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `washed` is unboxed with grade `[{Ethanol; 3; ChangeTip}, {Ethanol; 3; ChangeTip}]` accumulated since it was bound, which is not below its box grade `[{Ethanol; ChangeTip; Ethanol; 2; (0 | 1; (0 | 1; (0 | 1))); ChangeTip}, {Ethanol; ChangeTip; Ethanol; 2; (0 | 1; (0 | 1; (0 | 1))); ChangeTip}]`
  $ ../../tempore --grades time-upper-bound-levels --typecheck-only $examples/contamination_reject.tpe 2>&1 | grep 'Typing error'
  Typing error: Variable `tip` is unboxed with grade `(1, High)` accumulated since it was bound, which is not below its box grade `(∞, Low)`
  $ for name in reagents staggered beads stopread; do
  >   ../../tempore --grades time-interval --typecheck-only $examples/${name}_reject.tpe 2>&1 | grep 'Typing error'
  > done
  Typing error: The resource inequality `[35, 37] <= [0, 30]` does not hold
  Typing error: Variable `fixing` is unboxed with grade `[7, 9]` accumulated since it was bound, which is not below its box grade `[12, 20]`
  Typing error: Variable `drying` is unboxed with grade `[6, 7]` accumulated since it was bound, which is not below its box grade `[2, 5]`
  Typing error: Variable `first` is unboxed with grade `[31, 32]` accumulated since it was bound, which is not below its box grade `[0, 30]`

Run as a script, a protocol executes its program as the interpreter does,
without the binding file.

  $ python3 elisa.py
  === Run 1 ===
  return 0
  
  $ ../../tempore --grades time-interval $examples/elisa.tpe | head -2
  === Run 1 ===
  return 0

An operation that a handler in a run's code has a case for, but that has
neither a binding function nor a default implementation, is a warning. A
definition that no run uses is not compiled, nor are its operations checked.

  $ ../../tempore --grades time-interval --emit-opentrons ok.py \
  >   --bind protocol_bindings.py protocol_ok.tpe
  Warning: operation `Probe`, which run 2 may perform, has neither a binding function nor a default implementation; a handler in the run's code has a case for it, so the run fails only if it performs it outside every such handler
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
  delay(seconds=3.0)
  delay(seconds=1.0)
  comment: pipette 2
  comment: Tempore timeline: At 7 s: operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore warning: Operation `Pipette` took 3 s, outside its running-time bounds [1, 2] s
  comment: Tempore run 3 returns 3
  $ ../../tempore --grades time-interval --emit-opentrons ok_off.py --monitor off \
  >   --bind protocol_bindings.py protocol_ok.tpe 2> /dev/null
  $ PIPETTE_SECONDS=3 simulate ok_off.py
  requirements: {'robotType': 'Flex', 'apiLevel': '2.30'}
  comment: setup
  comment: Tempore run 1
  comment: pipette 1
  comment: Tempore run 1 returns 2
  comment: Tempore run 2
  comment: Tempore run 2 returns 7
  comment: Tempore run 3
  delay(seconds=3.0)
  delay(seconds=1.0)
  comment: pipette 2
  comment: Tempore run 3 returns 3

An operation that a run may perform, directly or through a definition or a
default implementation, with neither a binding function nor a default
implementation declared above the run, refuses the protocol.

  $ ../../tempore --grades time-interval --emit-opentrons lost.py \
  >   --bind protocol_bindings.py protocol_lost.tpe
  Error: operation `Lost`, which run 1 may perform, has neither a binding function nor a default implementation
  Error: operation `Shake`, which run 1 may perform, has neither a binding function nor a default implementation
  [1]
  $ test -e lost.py
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
  Error: operation `Pipette`, which run 1 may perform, has neither a binding function nor a default implementation
  Error: operation `Pipette`, which run 3 may perform, has neither a binding function nor a default implementation
  [1]

A protocol for the OT-2 has its latest apiLevel by default.

  $ ../../tempore --grades time-interval --emit-opentrons ot2.py --robot ot2 \
  >   --bind protocol_bindings.py protocol_ok.tpe 2> /dev/null
  $ grep '^requirements' ot2.py
  requirements = {"robotType": "OT-2", "apiLevel": "2.28"}

The options of protocols require --bind, and --bind requires --emit-opentrons.

  $ ../../tempore --bind protocol_bindings.py protocol_ok.tpe
  ../../tempore: option '--bind' requires '--emit-opentrons'.
  [2]
  $ ../../tempore --emit-opentrons plain.py --robot ot2 protocol_ok.tpe
  ../../tempore: option '--robot' requires '--bind'.
  [2]
  $ ../../tempore --emit-opentrons plain.py --bind protocol_bindings.py --time-unit 0 protocol_ok.tpe 2>&1 | head -1
  ../../tempore: option '--time-unit': '0' is neither seconds, minutes, hours nor a positive number of seconds.
  $ ../../tempore --emit-opentrons plain.py --bind protocol_bindings.py --monitor stop protocol_ok.tpe 2>&1 | head -1
  ../../tempore: option '--monitor': 'stop' is not one of abort, warn, off.

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
  Simulated sim.py
  Tempore run 1
  $ PATH="$PWD/bin:$PATH" ../../tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2>&1 >/dev/null | grep -v '^Warning'
  a warning of the simulator
  $ ../../tempore --grades time-interval --emit-opentrons sim.py --bind protocol_bindings.py \
  >   --simulate --simulator ./failing_simulate protocol_ok.tpe 2> /dev/null
  Simulating sim.py
  [1]
  $ ../../tempore --grades time-interval --emit-opentrons sim.py --bind protocol_bindings.py \
  >   --simulate --simulator ./missing_simulate protocol_ok.tpe 2>&1 | grep -v '^Warning'
  Error: the Opentrons simulator './missing_simulate' was not found; it is installed with the Python package opentrons (Python 3.10 or later), e.g. by 'pip install opentrons'
  $ PATH=/nonexistent ../../tempore --grades time-interval --emit-opentrons sim.py \
  >   --bind protocol_bindings.py --simulate protocol_ok.tpe 2>&1 | grep -v '^Warning'
  Error: the Opentrons simulator opentrons_simulate was not found; it is installed with the Python package opentrons (Python 3.10 or later), e.g. by 'pip install opentrons'
  $ ../../tempore --emit-opentrons sim.py --simulate protocol_ok.tpe
  ../../tempore: option '--simulate' requires '--bind'.
  [2]
  $ ../../tempore --emit-opentrons sim.py --simulator ./failing_simulate protocol_ok.tpe
  ../../tempore: option '--simulator' requires '--bind'.
  [2]
