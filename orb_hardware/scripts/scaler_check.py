"""Check scaler pixels, coordinates, latency and cascading in both mapping modes."""
import tempfile
from fast_check import ROOT, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", str(ROOT / "rtl/system_top/image_scaler.sv"),
                     str(ROOT / "tb/image_scaler_tb.sv")], work)
    for width, height in [(67, 49), (640, 480)]:
        vivado("xelab", ["image_scaler_tb", "-s", "scaler_test",
                         "-generic_top", f"W={width}", "-generic_top", f"H={height}"], work)
        log = vivado("xsim", ["scaler_test", "-runall"], work)
        if "PASS: image_scaler" not in log:
            raise RuntimeError(log)
        print(f"{width}x{height}: " + next(line for line in log.splitlines() if "PASS: image_scaler" in line))
