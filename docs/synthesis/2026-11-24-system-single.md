# Single-octave camera-to-descriptor system — 2026-11-24

Vivado 2024.1, xc7a100tcsg324-1, out-of-context synthesis and routing of
`system_top`, with ORB_LEVELS=1, 640x480 pixels, three DSP-enabled BRIEF
engines, 512-entry keypoint FIFO, 256-entry descriptor FIFO, and camera capture.
The system default is now one octave. No scaler is instantiated.

| Routed resource | Used | Device utilization |
|---|---:|---:|
| LUTs | 19,426 | 30.64% |
| Registers | 30,844 | 24.32% |
| DSPs | 60 | 25.00% |
| BRAM tiles (36 Kbit equivalents) | 15.5 | 11.48% |

System clock: 100 MHz. Camera PCLK: provisional 24 MHz (41.667 ns).
The clock groups are asynchronous. Input/output delays use provisional
2 ns maximum and 0 ns minimum constraints.

Final timing summary: setup WNS **+0.008 ns**, TNS 0; hold WHS
**-0.751 ns**, THS -153.172 ns, 1,651 failing hold endpoints.
Timing is **not closed**. The router's earlier estimate was +0.006 ns;
the final timing report supersedes that estimate.

The worst setup path runs from a BRIEF rotation DSP to its pixel-read
register. The reported worst hold paths start at camera data and threshold
input ports. Out-of-context port routing and clock insertion are incomplete;
real board pins, clock buffers and sensor timing must be constrained before
hardware signoff. Do not treat these hold failures as resolved or dismiss
them without a board-level implementation. Routing encountered congestion.

The CDC summary reports four safe endpoints and zero unsafe/unknown
endpoints for analyzed crossings. This is not complete CDC signoff: external
reset handling and XPM bus-skew constraints still need review; a separate
bus-skew report was not collected in this run.

Camera regression passed all four Y_FIRST/SWAP_UV configurations, and the
single-octave system elaborated successfully. No full camera-to-descriptor
image simulation or physical hardware test was performed in this run.

Reproduce with `orb_hardware/scripts/check_system_timing.tcl`.
Reports: [saved report folder](2026-11-24-system-single-reports/).
Original run: `orb_test_output/system_single_20261124_152851`.

Still needed for the first hardware count test: camera configuration/XCLK,
board wrapper and pin constraints, descriptor counter/readout, and single-frame
admission/drain control. Descriptor frame IDs remain fixed at zero.
