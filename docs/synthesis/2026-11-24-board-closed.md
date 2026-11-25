# Single-octave board timing closure — 2026-11-24

Starting from the [board + orientation run](2026-11-24-board-orientation.md),
post-route `phys_opt_design -directive AggressiveExplore` followed by
`route_design -directive Explore` closes the existing 100 MHz constraints
without RTL or clock-period changes.

Final setup WNS **+0.055 ns**, TNS 0; hold WHS **+0.023 ns**, THS 0.
All user-specified timing constraints are met; no failing setup/hold endpoints.
The optimizer improved placement/clock skew on the orientation-tag to BRIEF
window-enable path. Margin remains small.

The OV7670 wiring-skew/VSYNC assumptions and reset-related CDC warnings from
the source report still apply. Timing closure is not full hardware signoff.
No simulations or hardware programming were performed.

Reproduce by passing `orb_test_output/board_20261124_163725/routed.dcp` to
`orb_hardware/scripts/refine_board_timing.tcl`.
Closed checkpoint: `orb_test_output/board_refined_20261124_164635/routed.dcp`.
Reports: [saved reports](2026-11-24-board-closed-reports/).

This closed checkpoint is the single-octave baseline before the subsequent
parameterized board wrapper/scaler integration for the three-level experiment.
