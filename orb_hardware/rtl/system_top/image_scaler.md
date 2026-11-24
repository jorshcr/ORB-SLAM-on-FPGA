# Image scaler interface

`image_scaler.sv` is one standalone module with an internal synchronous line buffer,
2x2 sliding window and bilinear arithmetic. It instantiates no submodules.

Supply 8-bit grayscale pixels in row-major order with zero-based `in_x`, `in_y`
and `in_valid`. Gaps are supported; do not omit pixels from the raster. There is
no backpressure. Coordinates restart at (0,0) for each frame. Reset clears the
valid pipeline; the line buffer does not need clearing because first-row samples
use the current row. Coordinate ports support up to 1024 columns and 512 rows.

Each output dimension is `floor(input_dimension * 5 / 6)`. The output at (x,y)
samples input (6*x/5,6*y/5). Four integer bilinear weights sum to 25; division by
25 truncates once, after summation. Source pixels remain 8-bit.

The paper describes 25 phase combinations and dropping every sixth row/column.
This implementation makes the pixel-center convention explicit: the window ends
at the ceiling of the sampling location. Consequently input phase 1 modulo 6 is
skipped, rather than copying the paper's phase-5 wording literally. Phase 0 uses
the newest pixel exactly. This is origin-aligned bilinear resampling, not the
half-pixel mapping used by some software resize functions.

The latency is seven registered stages from the newest required source pixel:

1. Read previous row and register input.
2. Update the 2x2 window.
3. Register the four pixels, weights and scaled coordinates.
4. Compute four parallel pixel-weight products.
5. Sum pairs of products.
6. Sum the two pairs.
7. Divide by 25 and output.

`out_valid` and output coordinates follow the same latency. Arithmetic advances
every clock; the line buffer and window advance only with their respective valid
signals. `DSP_MODE="yes"` (default) maps the four products to DSPs; `"no"` uses LUTs.
Other arithmetic stays in logic. There is one `always_ff` block.

To cascade, connect one instance's `out_gray/out_x/out_y/out_valid` to the next
instance's corresponding inputs, setting its frame dimensions to the preceding
output dimensions. Fan out the same stream to that pyramid level's ORB input.
For four levels: 640x480 (original), 533x400, 444x333, 370x277.
No changes to `system_top.sv` are included in this standalone experiment.

Run simulation with `python -B orb_hardware/scripts/scaler_check.py` from the
repository root. Timing uses `check_scaler_timing.tcl` with `yes` or `no` as its
Tcl argument. The script verifies the actual DSP count before implementation.
