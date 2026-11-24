# Image scaler: DSP versus LUT, 2026-11-24

One standalone `image_scaler` was implemented with the same seven-stage pipeline
in both configurations. It contains its own line buffer and 2x2 window and can
feed an ORB level and another scaler. No system-top wiring was changed.

## Configuration

- Vivado 2024.1, xc7a100tcsg324-1, out-of-context synthesis and routing.
- Input 640x480, output 533x400, 8-bit grayscale, origin-aligned bilinear 5/6 scaling.
- Clock 10 ns (100 MHz); input/output delays max 2 ns, min 0 ns.
- Constraints loaded before synthesis; default optimization/place/route flow.
- `DSP_MODE="yes"`: four pixel-weight DSP multipliers. `"no"`: LUT arithmetic.
- Identical stages: row read, window, operands/weights, products, pair sums,
  total sum, normalization. Integer divide by 25 truncates the result.
- Default mode is LUT. See the RTL-adjacent `image_scaler.md` for the stream contract,
  sampling phase and cascading dimensions.

## Routed results

| Metric | LUT | DSP |
|---|---:|---:|
| Slice LUTs (including distributed storage) | 390 | 253 |
| Slice registers | 263 | 159 |
| DSP48E1 | 0 | 4 |
| RAMB18E1 | 1 | 1 |
| BRAM36-equivalent tiles | 0.5 | 0.5 |
| Setup WNS | +0.017 ns | +0.058 ns |
| Setup TNS | 0 ns | 0 ns |
| Hold WHS | -0.502 ns | -0.502 ns |
| Hold THS | -19.019 ns | -19.520 ns |
| Failing hold endpoints | 81 | 81 |
| Latency | 7 cycles | 7 cycles |

DSP mapping saves 137 LUTs and 104 slice registers; some pipeline registers move
inside the DSP blocks. Setup timing is effectively similar in this experiment.
Both critical paths run from `total_reg` to `out_gray_reg` through divide-by-25
normalization. Data-path delay is 9.928 ns for LUT and 9.890 ns for DSP. A future
timing iteration should examine normalization before changing the product stages.

Both runs have positive setup slack but very little margin and failing hold paths.
Neither is a timing-closed integrated design. Vivado warns that no `HD.CLK_SRC`
or port `HD.PARTPIN_LOCS` is specified; clock/boundary timing is approximate in
this isolated flow. Full-system clocking and routing must be checked separately.
These results do not establish a maximum frequency.

## Verification

XSim passed both modes at 67x49 and 640x480, with zero, maximum intensity, gradient,
checkerboard and random images. Checks cover integer bilinear reference pixels,
raster coordinates, exact seven-cycle valid alignment, input gaps, reset,
DSP/LUT equivalence and a second cascaded scaler. `git diff --check` passed.

## Reproduction and reports

From the repository root:

```powershell
python -B orb_hardware/scripts/scaler_check.py
& 'C:/Xilinx/Vivado/2024.1/bin/vivado.bat' -mode batch -nolog -nojournal -source orb_hardware/scripts/check_scaler_timing.tcl -tclargs no
& 'C:/Xilinx/Vivado/2024.1/bin/vivado.bat' -mode batch -nolog -nojournal -source orb_hardware/scripts/check_scaler_timing.tcl -tclargs yes
```

The timing script asserts zero or four DSPs after synthesis. Earlier inference
attempts with a conflicting module-wide LUT attribute are excluded; all results
above use the final source and the same pipeline architecture.

- LUT run: `orb_test_output/scaler_no_20261124_145735`.
- DSP run: `orb_test_output/scaler_yes_20261124_145547`.
- Preserved reports: [LUT](2026-11-24-image-scaler-reports/lut/timing_routed.rpt),
  [DSP](2026-11-24-image-scaler-reports/dsp/timing_routed.rpt).
- Working-tree base HEAD: `3a5336e9891c7908e595f33cb6c6e442468475b7`.
- RTL SHA256: `8E0F5719A22BB3BAA0CF097B6D9E7885C43F0690AEEF1FDF93DFFC22400C7333`.

The scaler is uncommitted; the base commit alone does not reproduce this result.
Keep this snapshot with the corresponding source, testbench and scripts.
