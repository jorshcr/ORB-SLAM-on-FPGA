# Nexys A7 / OV7670 board timing with descriptor orientation — 2026-11-24

Vivado 2024.1, xc7a100tcsg324-1. Full top-level synthesis, placement and
routing of orb_board_top, not out-of-context. One 640x480 ORB octave,
three BRIEF engines, registered camera inputs and split BRIEF pixel lookup.
No simulations were run for this change, as requested. Synthesis elaborated
the new orientation metadata path successfully; functional verification of
that new path remains pending.

The board wrapper reuses main's vga_test_top.v divide-by-four, BUFG and ODDR
XCLK generation and nexys_a7_vga_test.xdc camera/system/reset pin assignments.
System clock is 100 MHz; XCLK and assumed returned PCLK are 25 MHz.
Clock constraints are loaded before synthesis/XPM constraint evaluation.

| Routed metric | Result |
|---|---:|
| LUTs | 19,777 (31.19%) |
| Registers | 32,164 (25.37%) |
| DSPs | 60 (25.00%) |
| BRAM tiles | 15.5 (11.48%) |
| Overall setup WNS / TNS | -0.169 / -3.687 ns |
| Setup failing endpoints | 51 |
| Overall hold WHS / THS | +0.023 / 0 ns |
| Camera-clock setup / hold slack | +10.297 / +0.121 ns |
| ILOGIC input registers | 10 |

**Hold passes under these constraints; 100 MHz setup timing does not.**
The setup bottleneck is orientation out_tag_reg[11] through dispatch logic
to BRIEF engine 0 window register CE. Data delay is 9.698 ns, including
8.100 ns routing. This is not the new descriptor angle output path.
All nets routed; no DRC errors. The baseline differs in wrapper, I/O and
constraints, so resource/timing deltas are not solely orientation overhead.

## OV7670 timing model and limits

[OmniVision OV7670 datasheet](https://www.olimex.com/Products/Components/Camera/CAMERA-OV7670/resources/OV7670.pdf),
Table 4 / Figure 5, specifies 15 ns data setup and 8 ns hold, and HREF
transitions 0..5 ns after falling PCLK. The model assumes default PCLK
polarity, continuous PCLK and COM10[2]=0 (falling-edge VSYNC).

With an assumed +/-1 ns differential wiring skew, data input delays are
7 ns minimum and 26 ns maximum relative to rising PCLK at a 40 ns period.
HREF delays are -1..6 ns relative to falling PCLK. VSYNC uses the same
delay bounds as an explicit assumption; its edge is documented but that
propagation bound is not. The datasheet AC table uses 24 MHz test conditions;
25 MHz is retained from the existing board setup. These are design assumptions,
not measurements of the connected sensor, its programmed registers or wiring.

The previous raw-input-to-BRAM hold failure is absent; ten camera input
registers occupy ILOGIC. FIFO bus-skew checks pass with 10 ns requirements
(slack +8.934 and +8.985 ns), replacing the earlier OOC 1000 ns defaults.

The legacy raw reset-button distribution remains. Reset is false-pathed,
so the hold pass does not certify reset release. CDC reports critical
reset-related paths to sys_clk and camera_xclk; synchronized reset release
is still needed before hardware signoff. DRC also reports missing configuration
voltage properties, DSP pipeline recommendations and RAM async-control warnings.
No bitstream was generated or hardware programmed.

## Descriptor metadata and observation wrapper

BRIEF exports a 6-bit full-circle bin from its saved quadrant/sector.
Both arbiters and the descriptor FIFO carry the angle with the descriptor;
the record is now 286 bits. Decode degrees as `(out_angle+0.5)*5.625`.
Frame IDs remain zero; CPU transport and ORB-SLAM adaptation are not implemented.

The timing wrapper fixes FAST threshold at 20 and continuously drains output.
STATUS[15:8] is a modulo-256 cumulative descriptor count; STATUS[7:0] is a
rolling checksum consuming every descriptor bit and the angle. This prevents
the BRIEF/angle datapaths being optimized away. These use the old segment/digit
pins only as observation outputs, not a formatted display driver. Unused
position/octave/frame metadata can be optimized in this wrapper. Camera
configuration, per-frame count/drain logic and a host interface remain separate.

Script: `orb_hardware/scripts/check_board_timing.tcl`.
Constraints: `orb_hardware/constraints/orb_board.xdc`.
Run and checkpoints: `orb_test_output/board_20261124_163725`.
Reports: [saved reports](2026-11-24-board-orientation-reports/).
