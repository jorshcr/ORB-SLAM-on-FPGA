"""Check streaming moments against direct sums over 37 columns."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/system_top/orb/orientation/x_moment.sv"),
                     str(ROOT / "tb/x_moment_tb.sv")], work)
    vivado("xelab", ["x_moment_tb", "-s", "moment_test"], work)
    log = vivado("xsim", ["moment_test", "-runall"], work)
    if "PASS: x_moment" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: x_moment" in line))
