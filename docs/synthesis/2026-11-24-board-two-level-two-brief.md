# Two levels, two BRIEF engines each — 2026-11-24

Vivado 2024.1, xc7a100tcsg324-1, 100 MHz system clock and the existing
25 MHz OV7670 model. Octaves are 640x480 and 533x400. The board wrapper now
defaults to two BRIEF engines per level, four total, with an explicit
BRIEF_ENGINES parameter forwarded to system_top. The last-level override remains.

| Routed resource | Previous 3 + 3 | Current 2 + 2 | Current utilization |
|---|---:|---:|---:|
| LUTs | 39,556 | 29,224 | 46.09% |
| Registers | 64,298 | 46,358 | 36.56% |
| DSPs | 124 | 108 | 45.00% |
| BRAM tiles | 27 | 27 | 20.00% |

Savings: 10,332 LUTs, 17,940 registers and 16 DSPs.
Final setup WNS **+0.019 ns**, TNS 0; hold WHS **+0.051 ns**, THS 0.
All user-specified timing constraints are met, with zero failing setup/hold
endpoints. Placement, routing and post-route physical optimization completed.
Timing margin remains small.

Orientation pass-through already exists and was inspected, not reimplemented:
BRIEF latches quadrant and local sector at keypoint acceptance, outputs the
reflected global 6-bit angle, and carries it through the ORB result arbiter,
system descriptor arbitration and 286-bit descriptor FIFO to out_angle.
The board wrapper includes the angle in its diagnostic checksum. It does not
yet transmit descriptor packets to a PC.

No simulation, hardware programming, throughput or descriptor-drop tests were
run. Two engines provide less burst capacity than three. Existing reset CDC
limitations and camera timing assumptions from the
[board baseline](2026-11-24-board-orientation.md) remain. Frame IDs are still zero.

Reproduce with check_board_timing.tcl and Tcl arguments `2 2 2`, ordered as
levels, last-level BRIEF count, other-level BRIEF count. The previous 3 + 3
configuration can be reproduced with `2 3 3` using this script version.

Checkpoint: `orb_test_output/board_2level_2brief_last2brief_20261124_224325/routed.dcp`.
Reports: [saved reports](2026-11-24-board-two-level-two-brief-reports/).
