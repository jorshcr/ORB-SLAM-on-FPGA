"""Check BRIEF rotation, descriptor assembly, freeze and refill in XSim."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/common/brief_pattern.sv"),
                     str(ROOT / "rtl/system_top/orb/brief/brief_engine.sv"),
                     str(ROOT / "tb/brief_engine_tb.sv")], work)
    vivado("xelab", ["brief_engine_tb", "-s", "brief_test"], work)
    log = vivado("xsim", ["brief_test", "-runall"], work)
    if "PASS: brief_engine" not in log:
        raise RuntimeError(log)
    print(next(line for line in log.splitlines() if "PASS: brief_engine" in line))
