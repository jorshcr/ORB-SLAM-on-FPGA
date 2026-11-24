# ORB synthesis and timing snapshot - 2026-11-24, registered BRIEF lookup

Synthesis, placement, and routing completed successfully. **Setup meets 100 MHz with +0.305 ns slack**, improving from -1.028 ns before the added register stage. Hold violations remain; this is not full timing closure.

## Change and configuration

BRIEF now has four registered stages: load pair coordinates, rotate coordinates, read pixels, compare. Valid and pair indices travel through the extra stage. Descriptor completion is 259 clocks after acceptance instead of 258; throughput remains one pair per clock.

- Vivado 2024.1, build 5076996; `xc7a100tcsg324-1`.
- Top `orb_pyramid_level`: 640x480, three BRIEF engines, keypoint FIFO depth 512.
- Same out-of-context flow and constraints as the [earlier run](2026-11-24-orb.md): 10 ns clock, max 2 ns/min 0 ns I/O delays. Constraints are applied after synthesis, before implementation.
- Run: `orb_test_output/orb_20261124_015819`.
- Branch `orb-slam-rebuild`, base HEAD `038fc9968ae7fffb4f1a342d6a6fd4f13c87244a`, plus uncommitted changes. Save these reports with the matching RTL commit.

## Routed comparison

| Metric | Before | Registered lookup |
|---|---:|---:|
| Slice LUTs | 20,070 (31.66%) | 20,017 (31.57%) |
| Slice registers | 30,676 (24.19%) | 30,736 (24.24%) |
| BRAM tiles | 11 (8.15%) | 11 (8.15%) |
| DSPs | 36 (15.00%) | 36 (15.00%) |
| Setup slack | -1.028 ns | +0.305 ns |
| Total setup violation | -88.852 ns | 0.000 ns |
| Setup-failing endpoints | 550 | 0 |
| Hold slack | -0.444 ns | -0.502 ns |
| Total hold violation | -151.712 ns | -160.567 ns |
| Hold-failing endpoints | 1,646 | 1,673 |

Setup margin improves by 1.333 ns. Routed utilization changes by -53 LUTs and +60 registers; physical optimization means this is not simply the number of registers added in RTL. BRAM remains 10 RAMB36 and 2 RAMB18 blocks.

## Critical paths and limitations

The worst setup path is now from `keypoint_fifo/storage/xpm_fifo_base_inst/rst_d1_inst/d_out_int_reg/C` to `g_brief[1].brief/window_reg[5][9][4]/CE`, through FIFO availability/dispatch and window-enable control.

- Data path: 9.406 ns; logic 1.386 ns, routing 8.020 ns (85.265%).
- Pattern lookup plus rotation is no longer the worst setup path.
- Worst hold path: `in_x[4]` to `pixel_window/col_delayed_reg[4]/D`.

The design is fully routed with no routing errors. `HD.CLK_SRC` and boundary `HD.PARTPIN_LOCS` remain unset, so clock skew/insertion and interface timing are not fully modeled. Positive setup slack does not resolve the hold failures or establish board-level timing closure.

## Validation and artifacts

The modified BRIEF passed `python -B orb_hardware/scripts/brief_check.py`: five descriptors / 1,280 bits, signed rotations, exact 259-clock completion, freeze/refill behavior and reset. The integration testbench's expected latency was updated to 259; the complete integration regression was not rerun after this stage addition. The prior three-stage version passed the full quick integration regression.

- [Timing summary](2026-11-24-orb-pipelined-reports/timing_routed.rpt)
- [Utilization](2026-11-24-orb-pipelined-reports/utilization_routed.rpt)
- [Hierarchy](2026-11-24-orb-pipelined-reports/hierarchy_routed.rpt)
- [Register paths](2026-11-24-orb-pipelined-reports/register_paths.rpt)
- [Route status](2026-11-24-orb-pipelined-reports/route_status.rpt)
- [Source SHA-256 manifest](2026-11-24-orb-pipelined-reports/source-sha256.txt)

Synthesis-stage reports are also preserved. Copies were byte-verified and source hashes confirmed unchanged during the run. The earlier snapshot is retained.

## Reproduce

```powershell
& 'C:/Xilinx/Vivado/2024.1/bin/vivado.bat' -mode batch -source orb_hardware/scripts/check_orb_timing.tcl -nojournal -log orb_test_output/orb_2026-11-24-pipelined.log
```

No bitstream was generated or FPGA programmed.
