# Descriptor output record

Each valid/ready transfer carries a 256-bit descriptor, 19-bit position
`{x[9:0], y[8:0]}`, 6-bit full-circle angle index, 2-bit octave.
The FIFO record is 283 bits, packed from MSB to LSB as:

`{octave, pos, angle, descriptor}`

`out_angle` is a bin index from 0 to 63. The representative angle in degrees
is `(out_angle + 0.5) * 5.625`. This is the quantized orientation used to
select BRIEF's sine/cosine approximations, not a full-precision atan2 result.
Image y increases downward; preserve this image-coordinate convention when
constructing the software keypoint angle.

The internal orientation sector is magnitude-based. For quadrant q and
sector s, the full-circle bin is `{q, q[0] ? (15-s) : s}`. BRIEF captures
q and s on keypoint acceptance and retains them until its descriptor is
consumed. Both arbiters and the FIFO transfer angle and descriptor together.
No extra pipeline cycle is added by this metadata path.

Descriptor records omit frame IDs for single-frame operation. Capture control
must wait for all processing and buffered outputs to drain before accepting
the next frame. The CPU identifies frames using the frame-complete protocol;
an empty descriptor FIFO alone does not indicate completion.

`system_top` uses `IDLE`, `CAPTURE` and `DRAIN` states. It accepts a camera
frame only in `IDLE`, enters `DRAIN` after the last pixel, and asserts the held
`frame_done` status after every ORB and the descriptor output report idle for
16 consecutive clocks. The next accepted frame clears `frame_done`.
