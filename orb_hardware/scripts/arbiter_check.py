"""Simulate local result arbitration without synthesis."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/common/round_robin_arbiter.sv"),
                     str(ROOT / "tb/round_robin_arbiter_tb.sv")], work)
    vivado("xelab", ["round_robin_arbiter_tb", "-s", "arbiter_test"], work)
    log = vivado("xsim", ["arbiter_test", "-runall"], work)
    if "PASS: round robin" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: round robin" in line))
