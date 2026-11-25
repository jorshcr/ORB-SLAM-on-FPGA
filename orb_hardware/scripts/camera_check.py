"""Check YUV422 ordering, CDC, coordinates and frame markers with XSim."""
import tempfile
from fast_check import ROOT, RTL, VIVADO, vivado

with tempfile.TemporaryDirectory() as work:
    vivado("xvlog", ["--sv", *RTL, str(ROOT / "tb/camera_capture_tb.sv")], work)
    vivado("xvlog", [str(VIVADO.parent / "data/verilog/src/glbl.v")], work)
    for y_first in (0, 1):
        for swap_uv in (0, 1):
            vivado("xelab", ["camera_capture_tb", "glbl", "-L", "xpm", "-s", "camera_test",
                             "--generic_top", f"Y_FIRST={y_first}",
                             "--generic_top", f"SWAP_UV={swap_uv}"], work)
            log = vivado("xsim", ["camera_test", "-runall"], work)
            if "PASS: camera capture" not in log or "Fatal:" in log:
                raise RuntimeError(log)
            print(next(line for line in log.splitlines() if "PASS:" in line), flush=True)
    vivado("xelab", ["system_top", "glbl", "-L", "xpm", "-s", "system_compile"], work)
    print("PASS: system_top elaboration", flush=True)
