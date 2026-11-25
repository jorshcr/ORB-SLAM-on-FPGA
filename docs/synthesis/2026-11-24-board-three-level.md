# Three connected ORB levels — 2026-11-24

After [single-octave timing closed](2026-11-24-board-closed.md), the board
wrapper was parameterized and connected to two cascaded 5/6 image scalers:
640x480 -> 533x400 -> 444x333. Each level has three BRIEF engines (nine total).
Descriptor angle and octave flow into the shared descriptor FIFO and observation
checksum. The scalers use their current DSP-enabled default.

Vivado 2024.1, xc7a100tcsg324-1, 100 MHz system / 25 MHz OV7670 clocks.
Same board pin assignments and sensor/wiring assumptions as the single-level
board timing run. No simulation or hardware tests were run.

| Synthesis resource | Used | Device utilization |
|---|---:|---:|
| LUTs | 60,349 | 95.19% |
| Registers | 96,399 | 76.02% |
| DSPs | 188 | 78.33% |
| BRAM tiles | 33.5 | 24.81% |

Synthesis and opt_design completed, but placement failed at initialization:
`Place 30-4: Design utilization is very high` and `Place 30-99`.
Vivado also warned that register utilization forces up to eight registers per
slice. Nominal resource counts below device capacity do not guarantee legal
packing of LUTs, registers, control sets and routing.

**No placed or routed timing result exists for this three-level run.**
The utilization guard was not bypassed. This default implementation attempt
failed; it does not prove every possible placement strategy would fail.
Reducing BRIEF replication or running two levels are the next practical options.

The board wrapper still defaults to ORB_LEVELS=1. Three levels are selected
only by passing `3` as the final Tcl argument to check_board_timing.tcl.
The script now includes the post-route physical optimization used to close
the single-level baseline. The parameterized wrapper supports 1..4 levels;
only the three-level configuration was synthesized after this integration.

Run/checkpoint: `orb_test_output/board_3level_20261124_164929/synthesized.dcp`.
Reports: [saved synthesis report and placement failure](2026-11-24-board-three-level-reports/).
Single-level closed checkpoint remains preserved separately.
