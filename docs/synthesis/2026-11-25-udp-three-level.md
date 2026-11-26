# Three ORB levels with UDP — 2026-11-25

Vivado 2024.1, xc7a100tcsg324-1. Target orb_udp_board_top, three octaves
(640x480, 533x400, 444x333), two BRIEF engines each, including Ethernet UDP.
The UDP board top now defaults to three levels.

| Synthesis resource | Used | Utilization |
|---|---:|---:|
| LUTs | 47,146 | 74.36% |
| Registers | 72,288 | 57.01% |
| DSPs | 158 | 65.83% |
| BRAM tiles | 37 | 27.41% |

Synthesis passed. Implementation failed during detailed placement, Place 30-487:
the unplaced instances require 14,623 slices, but 13,404 slices are available
at that stage (15,850 total device slices). Vivado reports 374 control sets.
Aggregate resource percentages therefore do not establish legal packing.
No routed timing result exists for this configuration.

Reproduce with check_udp_board.tcl and final Tcl argument --route.
Run: orb_test_output/udp_board_20261125_004821.
Log: orb_test_output/udp_three_levels.log.
The synthesized checkpoint remains in the run directory.
No simulation or hardware test was run.
