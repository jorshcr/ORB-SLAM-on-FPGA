# Registered camera inputs and split BRIEF lookup — 2026-11-24

Vivado 2024.1, xc7a100tcsg324-1, out-of-context synthesis and routing of
system_top: one 640x480 octave, three BRIEF engines, 512-entry keypoint
FIFO, 256-entry descriptor FIFO. Same provisional constraints as the
single-octave baseline: 100 MHz system clock, 24 MHz PCLK, asynchronous
clock groups, 2 ns maximum/0 ns minimum I/O delays.

Changes: camera data, HREF and VSYNC are registered together on rising
PCLK before capture logic, adding one PCLK cycle. IOB placement is requested.
BRIEF column and row selection now occupy separate pipeline stages;
descriptor completion latency is 260 system clocks, verified in simulation.

| Routed metric | Previous | Updated |
|---|---:|---:|
| LUTs | 19,426 | 19,709 (31.09%) |
| Registers | 30,844 | 32,168 (25.37%) |
| DSPs | 60 | 60 (25.00%) |
| BRAM tiles | 15.5 | 15.5 (11.48%) |
| Setup WNS | +0.008 ns | +0.106 ns |
| Overall hold WHS | -0.751 ns | -0.502 ns |
| Camera-clock hold WHS | -0.751 ns | -0.441 ns |
| Route command elapsed time | 28 min 6 sec | approximately 1 min |

Internal register-to-register hold passes: worst reported slack +0.058 ns.
Overall timing is **not closed**: 1,602 hold endpoints fail, THS -132.412 ns.
The worst overall hold path starts at threshold[0][0]. The worst camera
hold path now ends at cam_data_delayed_reg[0], rather than FIFO BRAM.
The worst setup path is orientation out_tag through dispatch/window-enable
logic to a BRIEF window register CE, rather than BRIEF pixel selection.

Vivado warns that IOB=TRUE cannot be honored without IO elements in this
out-of-context run. Input registers remain fabric registers here. Real
I/O buffers, pin assignments, clock routing and sensor-specific delays are
required before calling the camera interface hold-clean. Do not relax
input-delay constraints solely to remove these failures.

The CDC summary reports four safe endpoints, zero unsafe/unknown endpoints.
Reported FIFO pointer bus skew is 0.806 ns and 0.942 ns. The generated XPM
bus-skew requirement is 1000 ns, so its reported pass is not meaningful
signoff at the actual clock rates. Establish clocks before XPM constraint
evaluation and review CDC exceptions in the board-level flow.

Validation: all four camera byte-order/chroma-order cases passed; system_top
elaboration passed. The BRIEF split separately passed five descriptors
(1,280 bits), latency/backpressure checks, and the three-case quick integrated
ORB regression before this camera-only edit. No physical hardware test.

Reports: [saved reports](2026-11-24-system-input-registered-reports/).
Run and routed checkpoint: `orb_test_output/system_single_20261124_161759`.
Script: `orb_hardware/scripts/check_system_timing.tcl`.
