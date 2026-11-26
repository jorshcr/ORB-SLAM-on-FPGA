# OpenCV BRIEF pattern implementation — 2026-11-25

Vivado 2024.1, xc7a100tcsg324-1, orb_udp_board_top. Three pyramid levels,
2/2/1 BRIEF engines, 100 MHz system clock, phase-adjusted 50 MHz RMII clock.

Replaced the custom pattern with all 256 official OpenCV 4.13.0 bit_pattern_31_
pairs, preserving pair order and attribution/license. Coordinates span -13..12.
Rotation now rounds to the nearest pixel (half ties toward positive infinity)
instead of flooring, keeping all pattern coordinates within -18..18 for all
64 quantized orientations. Pipeline latency is unchanged. Comparison polarity
remains pixel_a > pixel_b; this change alone does not establish bit-for-bit
compatibility with standard OpenCV ORB.

All 1,024 table coordinates were checked against official source. All 64
rotations were bounds-checked. Focused BRIEF XSim passed five descriptors /
1,280 bits, including descriptor assembly, latency, freeze and refill.
The earlier full-frame UDP/software comparison used the former custom pattern
and was not rerun for this build.

Full synthesis, placement, routing, AggressiveExplore optimization and final
hold-fix/preserve routing completed. Final setup WNS **+0.011 ns**, TNS 0;
hold WHS **+0.017 ns**, THS 0. No failing setup or hold endpoints.

| Routed resource | Used | Utilization |
|---|---:|---:|
| LUTs | 41,461 | 65.40% |
| Registers | 63,066 | 49.74% |
| DSPs | 150 | 62.50% |
| BRAM tiles | 37 | 27.41% |

Reproduce: check_udp_board.tcl with final Tcl argument --route.
Checkpoint: orb_test_output/udp_board_20261125_162208/routed.dcp.
Reports: [saved reports](2026-11-25-opencv-pattern-reports/).
Existing reset/CDC review and PHY/PCB timing assumptions still apply.
No physical hardware test was performed; timing margin remains small.
