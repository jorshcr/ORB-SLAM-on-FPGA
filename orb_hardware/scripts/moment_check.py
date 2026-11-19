"""Verify the integrated moment paths against direct 37x37 sums."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    rtl = sorted(str(p) for p in (ROOT / "rtl/orb/orientation").glob("*.sv"))
    vivado("xvlog", ["--sv", *rtl, str(ROOT / "tb/moment_compute_tb.sv")], work)
    vivado("xelab", ["moment_compute_tb", "-s", "moments_test"], work)
    log = vivado("xsim", ["moments_test", "-runall"], work)
    if "PASS: moment_compute" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: moment_compute" in line))
