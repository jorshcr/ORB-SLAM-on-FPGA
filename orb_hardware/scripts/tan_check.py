"""Verify fixed-point tangent products with Vivado XSim."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    src = ROOT / "rtl/system_top/orb/orientation"
    vivado("xvlog", ["--sv", str(src / "tan_multiply.sv"),
                     str(src / "quadrant_angle_compute.sv"),
                     str(ROOT / "tb/tan_multiply_tb.sv")], work)
    vivado("xelab", ["tan_multiply_tb", "-s", "tan_test"], work)
    log = vivado("xsim", ["tan_test", "-runall"], work)
    if "PASS: tan_multiply" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: tan_multiply" in line))
