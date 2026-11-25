# Camera capture

`camera_capture_top` retains the original PCLK capture -> asynchronous FIFO ->
system-clock stream structure. It now transfers complete YUV422 pairs rather
than discarding chroma. The FIFO holds 512 pairs by default (34 bits per entry,
including start-of-frame and start-of-line markers).

- Default camera byte order: U, Y0, V, Y1. `Y_FIRST` selects Y0, U, Y1, V;
  `SWAP_UV` swaps the two chroma positions. These must match camera registers.
- Active-high HREF and VSYNC; capture starts only after observing VSYNC.
- Data, HREF and VSYNC are captured together in rising-edge PCLK input registers
  before byte assembly and FIFO writes. This adds one PCLK cycle. IOB placement
  is requested; verify placement and sensor setup/hold timing in the board build.
- Dimensions must match the sensor output: even width, 2..1024 pixels;
  height 1..512. FIFO depth must meet XPM requirements (power of two, >=16).
- Output has no backpressure. `out_valid` qualifies grayscale Y, U/V,
  coordinates, frame ID, and frame-start/end flags. Both pixels in a pair
  have the same U/V. No RGB conversion or extra pixel FIFO is present.
- Coordinates are generated after CDC. End-of-frame means the final expected
  pixel, not completion of ORB descriptors. Frame ID starts at zero and wraps
  after eight observed frames. Lines must contain the configured pixel count.
- Overflow is sticky until reset. Capture discards the remaining input frame
  and resumes at the next VSYNC. Already-emitted pixels cannot be retracted;
  consumers must treat an overflowed frame as incomplete.
- Both clocks must run during reset. Assert reset for at least five cycles
  of the slower clock. Reset release is synchronized into PCLK.

`system_top` connects camera Y and coordinates to octave 0 and exposes the
pixel stream for later color display or other consumers. External `in_*[0]`
is unused; higher octaves still use their external inputs pending scaler wiring.
Unused color outputs can be left unconnected.

Camera XCLK generation, SCCB register configuration, board pin constraints,
and VGA YUV-to-RGB conversion are not provided here. Descriptor frame IDs are
still zero until frame tags are carried through ORB; `pixel_frame_id` is valid
only for the capture stream.

Run `python orb_hardware/scripts/camera_check.py` for XSim byte-order, coordinate,
frame-boundary, startup-discard tests and full system-top elaboration.
