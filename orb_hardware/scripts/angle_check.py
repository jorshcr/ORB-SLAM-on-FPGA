"""Check the four-stage quadrant and tangent-threshold pipeline."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    src = ROOT / "rtl/system_top/orb/orientation"
    vivado("xvlog", ["--sv", str(src / "tan_multiply.sv"),
                     str(src / "quadrant_angle_compute.sv"),
                     str(ROOT / "tb/quadrant_angle_compute_tb.sv")], work)
    vivado("xelab", ["quadrant_angle_compute_tb", "-s", "angle_test"], work)
    log = vivado("xsim", ["angle_test", "-runall"], work)
    if "PASS: quadrant_angle_compute" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: quadrant_angle_compute" in line))
