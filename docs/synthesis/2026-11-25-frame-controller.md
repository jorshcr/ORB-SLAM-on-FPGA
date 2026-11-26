# Single-frame controller and Q8 orientation — 2026-11-25

Vivado 2024.1, xc7a100tcsg324-1, 100 MHz system clock and the existing
25 MHz OV7670 model. The design uses two ORB levels and two BRIEF engines per
level.

`system_top` now controls frame admission with `IDLE`, `CAPTURE` and `DRAIN`
states. Capture is enabled only in `IDLE`. After the last pixel, the controller
waits for both ORB levels and the descriptor output to remain idle for 16
clocks, asserts the held `frame_done` status, and returns to `IDLE`. The next
accepted frame clears `frame_done`. The synchronized capture-enable level is
sampled at camera VSYNC, so camera frames during capture or drain are ignored.
Frame IDs are not present in the camera, ORB or descriptor interfaces.

This build also uses fifteen Q5.8 tangent boundary coefficients instead of
sixteen Q5.16 sector-center coefficients. Product width is reduced from 43 to
35 bits while the four-stage angle pipeline latency remains unchanged.

| Routed resource | Used | Utilization |
|---|---:|---:|
| LUTs | 29,017 | 45.77% |
| Registers | 46,311 | 36.52% |
| DSPs | 104 | 43.33% |
| BRAM tiles | 27 | 20.00% |

Compared with the preceding two-level, two-BRIEF build, this uses 207 fewer
LUTs, 47 fewer registers and four fewer DSPs. Final setup WNS is **+0.138 ns**
with TNS 0; hold WHS is **+0.021 ns** with THS 0. All user-specified timing
constraints are met and all 58,718 routable nets are fully routed.

The existing reset-related CDC findings and camera timing assumptions still
apply. No simulation or hardware programming was run. `frame_done` is exposed
by `system_top`; a future PC transport must carry it as an interrupt/status.

Reproduce with `check_board_timing.tcl` and Tcl arguments `2 2 2`.
Checkpoint: `orb_test_output/board_2level_2brief_last2brief_20261125_000107/routed.dcp`.
Reports: [saved reports](2026-11-25-frame-controller-reports/).
