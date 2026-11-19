"""Run the Gaussian blur simulation with Vivado XSim."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/gaussian_blur.sv"),
                     str(ROOT / "tb/gaussian_blur_tb.sv")], work)
    vivado("xelab", ["gaussian_blur_tb", "-s", "gaussian_test"], work)
    log = vivado("xsim", ["gaussian_test", "-runall"], work)
    if "PASS: gaussian_blur" not in log or "Fatal:" in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: gaussian_blur" in line))
