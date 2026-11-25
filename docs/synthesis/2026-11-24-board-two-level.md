# Two-level board timing — 2026-11-24

Vivado 2024.1, Nexys A7-100T (xc7a100tcsg324-1), 100 MHz system clock,
25 MHz OV7670 clock model. Two ORB levels: 640x480 and 533x400, connected
through one image scaler, with three BRIEF engines per level (six total).
The board wrapper and board timing script now default to two levels.

| Routed resource | Used | Utilization |
|---|---:|---:|
| LUTs | 39,556 | 62.39% |
| Registers | 64,298 | 50.71% |
| DSPs | 124 | 51.67% |
| BRAM tiles | 27 | 20.00% |

Placement and routing passed. Final setup WNS **+0.003 ns**, TNS 0;
hold WHS **+0.007 ns**, THS 0. All user-specified timing constraints are met,
with no failing setup/hold endpoints. Margin is very small.

The flow includes post-route `phys_opt_design -directive AggressiveExplore`
and `route_design -directive Explore`. Intermediate routing results are not
the final result. The worst setup path runs from octave 1 descriptor-window
tag register bit 3 to orientation y-adder s18 register [5][12], with 10 logic
levels and 10.107 ns data-path delay (3.834 ns logic, 6.273 ns routing).

The OV7670 input-delay assumptions and reset CDC limitations documented in
[the board baseline](2026-11-24-board-orientation.md) still apply. This is
timing closure under those constraints, not full hardware validation.
Frame IDs remain fixed at zero. No simulation or hardware programming was run.

Reproduce with `check_board_timing.tcl`, final Tcl arguments `2 3`.
Checkpoint: `orb_test_output/board_2level_last3brief_20261124_170744/routed.dcp`.
Reports: [saved reports](2026-11-24-board-two-level-reports/).
