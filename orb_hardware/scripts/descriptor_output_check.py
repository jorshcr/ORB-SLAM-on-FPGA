"""Verify configurable ORB stream collection, FIFO stalls, metadata and reset."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/common/round_robin_arbiter.sv"),
                     str(ROOT / "rtl/common/fifo_sync.sv"),
                     str(ROOT / "rtl/system_top/descriptor_output.sv"),
                     str(ROOT / "tb/descriptor_output_tb.sv")], work)
    for streams, depth in [(1, 16), (2, 16), (3, 16), (4, 16), (3, 256)]:
        vivado("xelab", ["descriptor_output_tb", "-L", "xpm", "-s", "output_test",
                         "--generic_top", f"STREAMS={streams}",
                         "--generic_top", f"DEPTH={depth}"], work)
        log = vivado("xsim", ["output_test", "-runall"], work)
        if "PASS: descriptor_output" not in log or "Fatal:" in log:
            raise RuntimeError(log)
        print(next(line for line in log.splitlines() if "PASS: descriptor_output" in line), flush=True)
