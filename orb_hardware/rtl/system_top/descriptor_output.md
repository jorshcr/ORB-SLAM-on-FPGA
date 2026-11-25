# Descriptor output record

Each valid/ready transfer carries a 256-bit descriptor, 19-bit position
`{x[9:0], y[8:0]}`, 6-bit full-circle angle index, 2-bit octave and 3-bit
frame ID. The FIFO record is 286 bits, packed from MSB to LSB as:

`{frame_id, octave, pos, angle, descriptor}`

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

The system currently fixes descriptor frame IDs at zero. Multi-frame tagging
and the CPU transport/ORB-SLAM adapter remain separate work.
