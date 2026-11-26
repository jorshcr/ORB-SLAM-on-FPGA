# UDP 2/2/1 clock-phase timing closure — 2026-11-25

Target xc7a100tcsg324-1, Vivado 2024.1. Three ORB levels, BRIEF counts 2/2/1,
including Ethernet. System clock 100 MHz, RMII 50 MHz.

The receive register was already in ILOGIC, so another data stage would not
repair the original input setup violation. Replace the fabric-derived Ethernet
clock with an MMCME2_BASE: 100 MHz input, 1 GHz VCO, two 50 MHz outputs.
The MAC uses 0 degrees; the forwarded PHY reference uses -18 degrees (-1 ns).
Network reset also depends on MMCM lock. Camera clocks are unchanged.

The advanced PHY launch edge requires selecting the following MAC capture
cycle for RX setup: 21 ns from launch to capture. A setup multicycle of two
selects this edge. No additional hold-cycle relaxation is applied: RX hold
checks the intervening edge with a 1 ns edge requirement. The existing
15 ns maximum and 1 ns minimum input delays remain unchanged.
PHY timing source: https://ww1.microchip.com/downloads/en/devicedoc/00002165b.pdf
(RMII REF_CLK input mode). Existing PCB skew assumptions remain.

Full synthesis, placement, routing and physical optimization completed.
After reopening the routed checkpoint with the strict hold constraint, one
internal BRIEF hold path required a hold-fix/preserve-routing pass. The normal
UDP build script now includes that pass.

Final setup WNS **+0.034 ns**, TNS 0; hold WHS **+0.018 ns**, THS 0.
All specified timing constraints are met. RX_ER setup **+0.712 ns**;
worst RMII RX hold **+0.893 ns**. Bus skew checks pass.

| Routed resource | Used | Utilization |
|---|---:|---:|
| LUTs | 41,456 | 65.39% |
| Registers | 63,006 | 49.69% |
| DSPs | 150 | 62.50% |
| BRAM tiles | 37 | 27.41% |

Final checkpoint: orb_test_output/udp_phase_repaired_20261125_094506/routed.dcp.
Reports: [saved reports](2026-11-25-udp-phase-closed-reports/).
Reproduce from source with check_udp_board.tcl --route (as final Tcl argument).
The phase implementation/hold scripts preserve the checkpoint-based experiment.
No simulation, programming or physical link validation was performed. Existing
reset/CDC review and hardware clock/board assumptions still require validation.
